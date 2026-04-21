# Beat 3a — Aura Well Discovery (Design)

> **Status:** Spec only. No implementation yet.
> **Source:** [FOUNDATION_PLAYTHROUGH.md §Beat 3a](../../progression/FOUNDATION_PLAYTHROUGH.md)
> **Scope:** Beat 3a only. Beat 3b (Second Keystone) is out of scope — it gets its own spec once 3a lands.

---

## 1. Goal

During a `shallow_woods` adventure, the player can encounter an **Aura Well** special tile. The tile serves as a rest stop (restores vitals) and — the first time it's visited — offers a "Mark down the location" choice that unlocks an **Aura Well** training zone action back in Zone 1. The training action already exists in code (as `spirit_well_training_action.tres`) and gets renamed as part of this work.

This delivers the Beat 3a unlock moment (Basic Training / passive resource income via the Aura Well) while keeping the encounter useful on repeat visits as a rest stop.

---

## 2. Player flow

1. Player starts a `shallow_woods` adventure.
2. The map generator places 1–2 special tiles, one of which **may** be the Aura Well (it's one entry in `special_encounter_pool` alongside other specials; not every run has one).
3. Player walks to the Aura Well tile. Encounter panel opens with two choices:
   - **"Rest"** — applies the Rest effect. Always visible.
   - **"Mark down the location"** — applies the Rest effect **and** fires the `aura_well_discovered` event. Visible only while the Aura Well training action is still locked. Hidden via a new `negate` flag on `UnlockConditionData` after first discovery.
4. Firing `aura_well_discovered` satisfies the `aura_well_discovered` unlock condition, which is in `aura_well_training_action.unlock_conditions`. `ZoneManager.get_available_actions()` now returns the action; the Zone 1 view shows an **"Aura Well"** zone-action button.
5. Selecting the Aura Well zone action enters the existing TrainingActionData loop: 1s ticks, `+1.5 madra/tick` passive, `+1 Spirit` awarded at each level threshold (`ticks_per_level = [60, 300, 600, 1200]`, `tail_growth_multiplier = 2.0`).

### Rest effect formula

- **HP restored:** `5 × CharacterManager.get_attribute(BODY)`
- **Madra restored:** `2 × CharacterManager.get_attribute(FOUNDATION)`
- Stronger characters get a bigger rest payoff. Attribute scaling keeps the encounter relevant as the player grows.

---

## 3. Schema changes

### 3.1 `UnlockConditionData.negate`

File: `scripts/resource_definitions/unlocks/unlock_condition_data.gd`

Add:

```gdscript
@export var negate: bool = false
```

The current `evaluate()` uses early-return inside a `match`. Refactor so inversion happens once at the end:

```gdscript
func evaluate() -> bool:
    var result: bool = _evaluate_raw()
    return not result if negate else result

func _evaluate_raw() -> bool:
    # existing match/return logic, unchanged
```

Default `negate = false` leaves every existing resource's behavior unchanged.

Used here to express "this choice is available **only while** the Aura Well has not yet been discovered" — i.e., a `UnlockConditionData` for the `aura_well_discovered` event with `negate = true`.

### 3.2 `ChangeVitalsEffectData` attribute scaling

File: `scripts/resource_definitions/effects/change_vitals_effect_data.gd`

Add:

```gdscript
@export var body_hp_multiplier: float = 0.0
@export var foundation_madra_multiplier: float = 0.0
```

Modify `process()` so the final values applied are:

- `health_change_final = health_change + body_hp_multiplier * CharacterManager.get_attribute(BODY)`
- `madra_change_final  = madra_change  + foundation_madra_multiplier * CharacterManager.get_attribute(FOUNDATION)`
- `stamina_change` unchanged.

Both multipliers default to `0.0`, so every existing resource (`test_rest_encounter`, etc.) continues to apply flat values. The Aura Well Rest effect uses multipliers with `health_change = 0` and `madra_change = 0`.

---

## 4. File changes

### 4.1 Renames (spirit_well → aura_well)

| Old | New |
|---|---|
| `resources/zones/spirit_valley_zone/zone_actions/spirit_well_training_action.tres` | `.../aura_well_training_action.tres` |
| `.../spirit_well_madra_trickle_effect.tres` | `.../aura_well_madra_trickle_effect.tres` |
| `.../spirit_well_spirit_award_effect.tres` | `.../aura_well_spirit_award_effect.tres` |

Inside `aura_well_training_action.tres`:
- `action_id = "aura_well_training"`
- `action_name = "Aura Well"`
- `description` updated to Aura-Well flavor (draft: *"Sit at the Aura Well. Let the valley's aura steep into your bones."* — unchanged from current copy is acceptable).
- `ExtResource` paths for the two effect files updated to the new filenames.
- `unlock_conditions = [aura_well_discovered.tres]` (added — currently `[]`).

Known cascade — update these files to reference the renamed `.tres`:
- `resources/zones/spirit_valley_zone/spirit_valley_zone.tres` — references `spirit_well_training_action.tres` in its `all_actions` array.
- `tests/unit/test_zone_progression_data.gd` — references `spirit_well` strings.

Grep the repo for `spirit_well` after renaming to confirm no references are left.

### 4.2 New resources

**`resources/unlocks/aura_well_discovered.tres`**
- Script: `unlock_condition_data.gd`
- `condition_id = "aura_well_discovered"`
- `condition_type = EVENT_TRIGGERED`
- `target_value = "aura_well_discovered"` (the field is `Variant`; a String is fine — `EventManager.has_event_triggered` already accepts it)
- `negate = false`

**`resources/unlocks/aura_well_not_yet_discovered.tres`**
- Same fields as above, but `negate = true`.
- Used by the "Mark down the location" choice to gate visibility.
- (Alternative: inline the negated variant as a sub-resource inside `aura_well_encounter.tres`. Pick whichever feels cleanest at implementation time.)

**`resources/adventure/encounters/special_encounters/aura_well_encounter.tres`**
- Script: `adventure_encounter.gd`
- `encounter_id = "aura_well"`
- `encounter_name = "Aura Well"`
- `description` (draft): *"A spring of pale light wells up between the roots. The air here is thick with aura."*
- `text_description_completed` (draft): *"The aura here still thrums. You could rest, or continue on."*
- `encounter_type = REST_SITE` (reuses existing icon; a dedicated `AURA_WELL` icon type can be added later if desired)
- `choices = [rest_choice, mark_choice]` (see 4.3)

**Rest effect resource(s).** Two reasonable patterns — pick one during implementation:
- **Inline sub-resources** inside `aura_well_encounter.tres` (matches the `test_rest_encounter.tres` pattern). Cheapest.
- **Standalone `.tres`** at `resources/effects/rest/aura_well_rest_effect.tres` if we expect reuse.

Default to inline sub-resources for the Aura Well unless reuse becomes obvious.

### 4.3 Encounter choices

Inline as sub-resources inside `aura_well_encounter.tres`.

**"Rest" choice:**
- `label = "Rest"`
- `requirements = []`
- `success_effects = [rest_effect]` — `ChangeVitalsEffectData` with `body_hp_multiplier = 5.0, foundation_madra_multiplier = 2.0` (and flat fields `= 0`).
- `failure_effects = []`

**"Mark down the location" choice:**
- `label = "Mark down the location"`
- `requirements = [aura_well_not_yet_discovered.tres]` — the negated condition from §4.2. Evaluates as available only while the event has **not** been triggered.
- `success_effects = [rest_effect, trigger_event("aura_well_discovered")]` — same Rest payload plus a `TriggerEventEffectData` with `event_id = "aura_well_discovered"`.
- `failure_effects = []`

**Visibility vs. availability.** `EncounterChoice.evaluate_requirements()` currently governs whether the choice button is enabled (unmet → grayed). For this beat, a grayed "Mark down the location" button on repeat visits is acceptable. If designer prefers full hiding later, add a `hide_when_unavailable: bool` to `EncounterChoice` — out of scope here.

### 4.4 Map wiring

`resources/adventure/data/shallow_woods.tres`:
- `num_special_tiles = 1` (starting value; tune via playtest)
- `special_encounter_pool = [aura_well_encounter.tres]` (grows over time as Refugee Camp, Elite, etc. are added)

---

## 5. Testing

### Unit

- **`tests/unit/test_unlock_condition_negate.gd`** — confirm `evaluate()` returns inverted result when `negate = true`, unchanged when `negate = false`.
- **`tests/unit/test_change_vitals_effect_data.gd`** (new or extend existing) — given mock `CharacterManager` with `BODY = 10, FOUNDATION = 10`, `body_hp_multiplier = 5, foundation_madra_multiplier = 2`, assert final changes `+50` HP and `+20` madra. Confirm zero-attribute and zero-multiplier edge cases behave.
- **`tests/unit/test_encounter_choice.gd`** — negated requirement makes choice unavailable once the event has fired; available before.

### Integration

- **`tests/integration/test_aura_well_discovery.gd`** — start with training action locked, fire `aura_well_discovered` event, confirm `ZoneManager.get_available_actions("spirit_valley")` now includes `aura_well_training`.

### Manual playtest (non-gating)

- Enter `shallow_woods` adventure several times until the Aura Well appears.
- Confirm both choices visible and enabled on first visit.
- Confirm "Mark" is grayed on second visit after unlock.
- Confirm zone action appears in Zone 1 main view after discovery.
- Confirm training loop runs and levels produce Spirit attribute increments.

---

## 6. Out of scope / follow-ups

- **Beat 3b (Second Keystone)** — deferred to its own spec. Will add a second keystone-tier node to the existing Pure Madra tree (not a new path tree) and finalize `q_reach_core_density_10` completion effects.
- **`docs/progression/FOUNDATION_PLAYTHROUGH.md` corrections** needed in a separate pass:
  - The line *"Keystones are the first node of each path"* under §Framing notes is incorrect — Keystone #2 lives on the Pure Madra tree.
  - Beat 3b should document the planned NPC-return step: completing `q_reach_core_density_10` has the player return to the Celestial Intervener, who hands over a **map**. The map starts Beat 4's quest and unlocks the Merchant zone action.
- **Dedicated `AURA_WELL` encounter icon type** — reuse `REST_SITE` for now. Adding a unique glyph is a polish task.
- **Choice full-hide flag** (`hide_when_unavailable: bool` on `EncounterChoice`) — only add if graying feels wrong during playtest.
