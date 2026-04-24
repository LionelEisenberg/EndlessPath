# Map Generation Rework (Design)

> **Status:** Spec only. No implementation yet.
> **Scope:** `AdventureMapGenerator` + its input schemas (`AdventureData`, `AdventureEncounter`) + the single shipped adventure (`shallow_woods.tres`). Combat, encounter resolution, and fog-of-war are unchanged.

---

## 1. Goal

Replace the current procedural map generator so it:

1. **Specifies encounter counts explicitly** (quotas) rather than random-picking from typed pools.
2. **Keeps rest/treasure tiles away from origin** and **guarantees a filler encounter on the path** between origin and any tile that needs one.
3. **Branches meaningfully** — the current pure MST gives no route choice; add a small number of extra edges.
4. **Cannot crash** from over-specified path encounters — the current `_assign_path_tiles` loop has no exit when requested counts exceed available NoOp tiles.
5. **Validates config up front** so misconfigured `.tres` adventures fail loudly at generation time, not mid-loop.

All design intent lives in `.tres` files; the generator only reads fields and runs the algorithm.

---

## 2. Problems in the current generator

File: `scenes/adventure/adventure_tilemap/adventure_map_generator.gd`

| Problem | Where | Symptom |
|---------|-------|---------|
| Infinite loop on over-specified path encounters | `_assign_path_tiles` (lines 177-188) | Game freezes when `num_path_encounters` > available NoOp tiles |
| No type distribution control | `_assign_special_tiles` (line 94) | `special_encounter_pool` random-picks; Shallow Woods pool of `[aura_well, refugee_camp]` yields 4 rest-like encounters across 4 non-boss specials |
| No distance constraint per encounter type | Phase 1 placement | Rest sites can spawn adjacent to origin |
| No "earned reward" guarantee | No path-level validation | Paths from origin to rest can contain zero combats |
| Pure MST — no choice paths | `_generate_mst_paths` | Every node is reachable by exactly one route |
| Dead field | Generator line 12 | `num_combats_in_map` declared, never used |
| Pool split doesn't reflect anything the player sees | `AdventureData` pool fields | `special_encounter_pool` vs `path_encounter_pool` encodes *placement strategy*, not content type |

---

## 3. Schema changes

### 3.1 `AdventureEncounter` additions

File: `scripts/resource_definitions/adventure/encounters/adventure_encounter.gd`

Add:

```gdscript
enum Placement { ANCHOR, FILLER }

## Minimum hex distance from origin for placement. 0 = no constraint.
@export var min_distance_from_origin: int = 0

## Minimum number of FILLER-placement encounters that must sit on the
## shortest path from origin to this encounter's tile. 0 = no constraint.
@export var min_fillers_on_path: int = 0

## Placement strategy used by the generator.
##   ANCHOR — scattered first with sparse_factor + min_distance_from_origin
##   FILLER — placed on NoOp path tiles after MST is built
@export var placement: Placement = Placement.FILLER
```

Existing `unlock_conditions: Dictionary[UnlockConditionData, bool]` is reused unchanged for eligibility — no new `fallback` or `completion_event` fields.

### 3.2 `AdventureData` replacement

File: `scripts/resource_definitions/adventure/adventure_data.gd`

Remove:

```
num_special_tiles
num_path_encounters
special_encounter_pool
path_encounter_pool
```

Add:

```gdscript
## Number of non-MST edges added to the graph for path branching. 0 = pure MST.
@export var num_extra_edges: int = 2

## Explicit boss (always placed at the farthest anchor tile, always count 1).
@export var boss_encounter: AdventureEncounter

## Per-encounter instance counts. Keys are AdventureEncounter resources;
## values are the number of instances to place in the map.
## Authored as Array[EncounterQuota] for Godot editor UX (see 3.3).
@export var encounter_quotas: Array[EncounterQuota] = []
```

Kept: `max_distance_from_start`, `sparse_factor`.

Dead field `num_combats_in_map` is removed from `AdventureMapGenerator`.

### 3.3 New `EncounterQuota` resource

File: `scripts/resource_definitions/adventure/encounter_quota.gd`

```gdscript
class_name EncounterQuota
extends Resource

@export var encounter: AdventureEncounter
@export var count: int = 1
```

Rationale: Godot 4's inspector handles `Array[Resource]` well. `Dictionary[Resource, int]` is functional but awkward in the editor.

### 3.4 Validation

File: `scripts/resource_definitions/adventure/adventure_data.gd`

Add:

```gdscript
## Returns a list of error strings. Empty array = valid.
func validate() -> Array[String]:
    var errors: Array[String] = []
    # See Section 5 for the full check list.
    return errors
```

Called at the top of `AdventureMapGenerator.generate_adventure_map()`. If `errors.size() > 0`, log each error via `Log.error` and return an empty map — generation refuses to run.

---

## 4. Algorithm

Replaces the existing 4-phase generation. All phase names below refer to methods on `AdventureMapGenerator`.

### Phase 0 — Validate

```
errors = adventure_data.validate()
if errors not empty:
    log all, return {}
```

### Phase 1 — Scatter anchors (`_place_anchors`)

Iterate `encounter_quotas`. For each `(encounter, count)` where `encounter.placement == ANCHOR` **and** `encounter.is_eligible()`:

```
for i in count:
    for attempt in MAX_PLACEMENT_ATTEMPTS:
        coord = random cube coord within max_distance_from_start
        if cube_distance(origin, coord) < sparse_factor: retry
        if cube_distance(origin, coord) < encounter.min_distance_from_origin: retry
        if any existing anchor within sparse_factor: retry
        place encounter at coord; break
    if exhausted: warn, skip this instance
```

Then place `boss_encounter` at the farthest-from-origin candidate coord using the same constraints.

### Phase 2 — Build connection graph (`_generate_paths`)

- Build MST over `[origin] + all anchor coords` using hex distance (existing Prim's logic).
- Add `num_extra_edges` shortest **non-tree** edges. Skip duplicate edges.
- For every edge, walk `cube_linedraw` and mark intermediate tiles as `NoOpEncounter`.

### Phase 3 — Place fillers (`_place_fillers`)

Iterate `encounter_quotas` again. For each `(encounter, count)` where `encounter.placement == FILLER` **and** `encounter.is_eligible()`:

```
for i in count:
    noop_tiles = [coord for coord in map if map[coord] is NoOpEncounter]
    if noop_tiles is empty:
        warn "quota exceeds available NoOp tiles", break
    pick random coord from noop_tiles
    place encounter at coord
```

Bounded by NoOp availability — **fixes the infinite loop**.

### Phase 4 — Critical-path filler check (`_validate_critical_paths`)

For every placed tile where `encounter.min_fillers_on_path > 0`:

```
path = shortest path from origin to this tile (BFS on the graph)
fillers_on_path = count of tiles on path (excluding endpoints) whose encounter.placement == FILLER
if fillers_on_path < encounter.min_fillers_on_path:
    deficit = required - actual
    noops_on_path = tiles on path that are still NoOp
    if deficit <= noops_on_path.size():
        for i in deficit:
            pick a NoOp tile from this path
            assign it an eligible FILLER encounter from encounter_quotas,
            preferring one whose encounter_type is COMBAT_REGULAR.
            Fall back to any eligible FILLER if no combat quota has room.
    else:
        mark this run as failed-to-satisfy; trigger regeneration
```

Regeneration retries the full algorithm up to `MAX_REGENERATION_ATTEMPTS = 5`. After 5 failures, log `Log.error` and return the 5th attempt's map unchanged (the game continues with a sub-optimal map rather than blocking the player).

---

## 5. Validation checks (`AdventureData.validate`)

Each check appends a human-readable error string. Non-fatal warnings (e.g., anchor density) use `Log.warn` but do not block generation.

**Fatal (appended to errors):**

- `boss_encounter == null` → `"boss_encounter is not set"`
- `boss_encounter.placement != ANCHOR` → `"boss_encounter must have placement = ANCHOR"`
- Any `EncounterQuota` with `encounter == null` → `"encounter_quotas[i] has null encounter"`
- Any `EncounterQuota` with `count <= 0` → `"encounter_quotas[i] has non-positive count"`
- Any encounter's `min_distance_from_origin > max_distance_from_start` → `"<id>.min_distance_from_origin exceeds max_distance_from_start"`
- If any encounter in quotas has `min_fillers_on_path > 0` and no quota entry has `placement == FILLER`: `"encounter <id> requires fillers on path but quotas contain no FILLER entries"`
- For each encounter with `min_fillers_on_path = N`, total `count` across FILLER quotas < N: `"encounter <id> requires N fillers on path but only M are quota'd"`

**Warnings (logged but not fatal):**

- Sum of anchor counts > estimated tiles available within `max_distance_from_start` after applying `sparse_factor`: `"anchor density may be too high for map size"`

### Test coverage

New test: `tests/unit/test_adventure_data.gd`

```
func test_shipped_adventures_validate():
    for tres_path in list all files under res://resources/adventure/data/:
        var data: AdventureData = load(tres_path)
        var errors = data.validate()
        assert_eq(errors, [], "%s: %s" % [tres_path, errors])
```

Guarantees every shipped `.tres` stays valid.

---

## 6. Shallow Woods migration

File: `resources/adventure/data/shallow_woods.tres`

### Before (current)

```
num_special_tiles = 5          (default)
max_distance_from_start = 6    (default)
sparse_factor = 2              (default)
num_path_encounters = 8
boss_encounter = amorphous_spirit_encounter
special_encounter_pool = [aura_well, refugee_camp]
path_encounter_pool = [dreadbeast, amorphous_spirit]
```

### After

The current `amorphous_spirit_encounter.tres` is used both as the boss and as a filler combat. These need distinct `.tres` files after the rework — a new `amorphous_spirit_boss.tres` for the boss role, and the existing resource reconfigured as a filler.

```
max_distance_from_start = 6
sparse_factor = 2
num_extra_edges = 2
boss_encounter = amorphous_spirit_boss        # ANCHOR, min_distance = 5
encounter_quotas = [
    { encounter: aura_well,         count: 1 },    # ANCHOR, min_distance = 3, min_fillers_on_path = 1
    { encounter: refugee_camp,      count: 1 },    # ANCHOR, min_distance = 3, min_fillers_on_path = 1
    { encounter: dreadbeast,        count: 3 },    # FILLER
    { encounter: amorphous_spirit,  count: 4 },    # FILLER
]
```

Per-encounter `.tres` edits:

- `amorphous_spirit_boss.tres` (new): boss-appropriate stats, `placement = ANCHOR`, `min_distance_from_origin = 5`
- `amorphous_spirit_encounter.tres`: `placement = FILLER`, `min_distance_from_origin = 0`
- `starving_dreadbeast_encounter.tres`: `placement = FILLER`, defaults otherwise
- `aura_well_encounter.tres`: `placement = ANCHOR`, `min_distance_from_origin = 3`, `min_fillers_on_path = 1`
- `refugee_camp_encounter.tres`: `placement = ANCHOR`, `min_distance_from_origin = 3`, `min_fillers_on_path = 1`

**Net composition per run:** 1 boss + 2 rest-type anchors + 7 filler combats = 10 encounters, plus NoOp walk-through tiles.

---

## 7. Eligibility behavior

`AdventureEncounter` reuses existing `unlock_conditions: Dictionary[UnlockConditionData, bool]`. A new `is_eligible() -> bool` method (on `AdventureEncounter`) wraps the existing filter logic from `_build_eligible_special_pool`:

```gdscript
func is_eligible() -> bool:
    for condition in unlock_conditions:
        if condition.evaluate() != unlock_conditions[condition]:
            return false
    return true
```

`_build_eligible_special_pool` is removed (its logic now lives on the encounter).

**Behavior:** if an encounter in `encounter_quotas` is ineligible, its quota entry contributes 0 instances. Log `Log.info("Skipping <id> — unlock conditions not met")`. No substitution, no fallback chain.

Authors handle alternative content by using `unlock_conditions` patterns (e.g., two sibling encounters with inverted conditions for "before vs after" states — the `negate` flag on `UnlockConditionData` added in PR 2026-04-20 enables this).

---

## 8. Out of scope

- **Seeded generation** (deterministic reproducibility). Easy to add later as a `seed: int` field if bad maps become hard to reproduce.
- **Per-run content variety within a type** (e.g., "pick 2 of 5 possible rests per run"). Current design places every encounter listed in `encounter_quotas`. Variety comes from spatial RNG, not pool RNG. Can be added later via a "pick-one-of" wrapper encounter if needed.
- **Completion-gated encounters** (one-time narrative tiles that should not repeat). Handled by `unlock_conditions` today if authors use `EVENT_TRIGGERED`; no new field needed.
- **Difficulty scaling by distance from origin.** Combats at far-ring vs near-ring tiles are indistinguishable under this design. Future work.

---

## 9. Test plan

New tests under `tests/unit/test_adventure_map_generator.gd`:

1. **Validates config** — passing invalid `AdventureData` returns empty map, logs errors.
2. **Respects anchor `min_distance_from_origin`** — place a rest with `min_distance = 3`; run 100 times; assert no rest placed inside distance 3.
3. **Respects `sparse_factor`** — anchors are never within `sparse_factor` of each other or origin.
4. **Critical-path filler guarantee** — place a rest with `min_fillers_on_path = 1`; run 100 times; assert every generated map has ≥1 filler on shortest path from origin to rest.
5. **Quota fulfillment** — all eligible quota counts are placed exactly.
6. **Ineligible encounters skipped** — an encounter with failing `unlock_conditions` is not placed.
7. **No infinite loop on over-specified fillers** — ask for 50 filler combats in a tiny map; generator terminates within `MAX_PLACEMENT_ATTEMPTS`, logs warning.
8. **Boss at farthest tile** — boss coord has the maximum hex distance from origin among all anchors.
9. **Branching** — with `num_extra_edges = 2`, at least one anchor has graph degree ≥ 2 via non-tree edges.
10. **Shipped content validates** — `test_adventure_data.gd` loads every `resources/adventure/data/*.tres` and asserts `validate().is_empty()`.

---

## 10. Files touched

### Modified
- `scripts/resource_definitions/adventure/adventure_data.gd` — schema changes, `validate()`
- `scripts/resource_definitions/adventure/encounters/adventure_encounter.gd` — new fields, `is_eligible()`
- `scenes/adventure/adventure_tilemap/adventure_map_generator.gd` — algorithm rewrite
- `resources/adventure/data/shallow_woods.tres` — migrate to new schema
- `resources/adventure/encounters/**/*.tres` — set `placement` + per-encounter fields

### New
- `scripts/resource_definitions/adventure/encounter_quota.gd` — `EncounterQuota` resource
- `resources/adventure/encounters/combat_encounters/amorphous_spirit_boss.tres` — boss variant
- `tests/unit/test_adventure_data.gd` — schema validation test
- `tests/unit/test_adventure_map_generator.gd` — algorithm tests

### Deleted
- (none)
