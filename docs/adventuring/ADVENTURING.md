# Adventuring System

Last updated: 2026-10-22

## Overview

Adventuring is a timed exploration run on a procedurally generated hex map. The player spends Madra to enter, walks tile by tile (5 Stamina per step) through fog of war, and resolves encounters through choice cards: fights hand off to the real-time combat view, while rest sites and special tiles apply effects directly. Defeating the boss ends the run as a victory. Losing a fight or running out of time ends it as a defeat. A scroll-themed end card then summarises the run.

Each map comes from `AdventureMapGenerator`, a quota-based generator. Anchor encounters are scattered first, then connected by a minimum spanning tree plus a few extra edges, and filler encounters are dropped onto the connecting path tiles. All placement rules are data on the encounter resources.

One adventure ships today: **The Shallow Woods** in Spirit Valley. It unlocks during Foundation once the Awaken Your Core quest (`q_fill_core`) is complete. The GDD placed adventuring at Iron stage. See [Work Remaining](#work-remaining) for how the build differs from the GDD.

## Player Experience

1. In Spirit Valley, once event `q_fill_core_completed` has fired, the zone chest shows **The Shallow Woods** under Venture, on a normal 72 px card measured against the adventure capacity:
   - Below half the capacity, its detail row is a Madra rod with `<madra> / <threshold>` after it, and a cream `~N s` at the right while a Madra action runs. Clicking shakes the row and logs "Not enough Madra! Need X, have Y"; the running idle action keeps going.
   - At half the capacity or more, a brass frame holds steady around the card, it reads "<minutes> min run · carries <capacity> Madra", and its tag reads ENTER.
2. On click, the zone view locks input and the map's plates hide. Between 8 and 25 Madra pellets fly in 2 px steps from the cultivator cabinet's Madra orb to the character while the budget (`min(capacity, current Madra)`) is spent. The camera then zooms to 3× over 0.5 s and the adventure view opens.
3. A new map is generated (about 25 tiles for Shallow Woods; see [Typical Shallow Woods Map](#typical-shallow-woods-map)). HP and Stamina refill to max, and in-adventure Madra is set to the budget. Stamina regenerates at 1/s, and a `5:00` timer pill (hourglass icon) starts at top-centre; it turns red and ticks for the last 30 seconds. The adventure dock sits bottom-centre: Health and Madra orbs, the Stamina bar, and the four technique slots previewing the equipped loadout (hover a slot to read the technique and see its cost). The log board moves to the top-left and the Goals board to the top-right (cords hidden) for the adventure, clear of the dock and the encounter panel, and both go back afterwards.
4. The player starts on the origin tile:
   - Adjacent map tiles are revealed as forest tiles under a swirling smoke veil with a "?", so their type stays hidden.
   - The boss is the exception: once revealed it shows its animated skull glyph through the fog.
   - Everything else is darkened by a screen-space fog shader. Non-map hexes are never painted.
5. Hovering a visited or revealed tile shows an animated hex ring and a textured route line.
   - Clicking commits to that destination: the ring and line lock on, and the character walks the A* route one tile at a time. Each step costs 5 Stamina, and longer routes move faster.
   - The line fades out behind the character as it walks.
   - The mouse wheel zooms from 0.3 to 1.3.
   - Clicks are ignored while the character is moving.
6. Arriving on a new tile marks it visited: its veil dissolves and new neighbours are revealed. The first time the boss is revealed, time slows to 25% for 0.15 s, the screen flashes pale blue, and the camera pushes 45% of the way toward the boss and back.
7. Stepping onto an unvisited encounter tile stops the trip:
   - The encounter panel fades in on the left with the title, description and choice cards. Unavailable or already-completed choices are greyed out.
   - Movement stays locked until a choice resolves the tile.
   - A map-pin marker above the player shows the current tile's encounter glyph.
8. **Fight** choices switch to the combat view (see [COMBAT.md](../combat/COMBAT.md)).
   - A win awards gold and the choice's success effects, then marks the tile complete.
   - A loss ends the adventure.
   - Other choices resolve immediately. For example, the Aura Well's Rest restores HP and Madra, and "Mark down the location" fires an unlock event.
9. A completed tile gets a grey overlay, a slightly dimmed glyph and a green checkmark. Walking back over it shows its completed text. Gold, items and events are banked the moment they are earned and are kept even if the run is lost.
10. With less than 5 Stamina, clicks do nothing and a route in progress stops. No message is shown; only the Stamina bar hints at why.
11. The run ends when:
    - the boss is defeated (VICTORY),
    - HP reaches 0 in combat (DEFEAT), or
    - the timer expires (DEFEAT).

    There is no retreat button, by design (see [FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md)).
12. A scroll end card unrolls over a grey background. It shows a VICTORY/DEFEAT title with icons, the defeat reason, six stats (Combat, Gold, Time, Health, Tiles Explored, Madra Spent) and a loot tray. **RETURN** rolls the scroll up and goes back to the zone view, where the camera zoom is restored.

**Controls:** left-click a tile to move, hover to preview the route, mouse wheel to zoom, left-click choice cards, and **RETURN** on the end card. `AdventureViewState` and `AdventureEndCardState` handle no keyboard input, so hotkeys such as `open_inventory` do nothing during a run. Q/W/E/R work inside combat (see [COMBAT.md](../combat/COMBAT.md)).

## Architecture

```
AdventureView (Control)                              — adventure_view.gd (instanced in main_game.tscn, visible = false)
├── ZoneViewBackground                               — parallax backdrop (scenes/zones/zone_view_background), LAYER_SCALE 3.5
├── TilemapView (Control)
│   └── TilemapSubviewportContainer (SubViewportContainer, 1920×1080)
│       └── SubViewport (transparent_bg)
│           └── AdventureTilemap                     — adventure_tilemap.tscn (tree below)
├── CombatView (Control, hidden)
│   └── CombatSubviewportContainer
│       └── SubViewport (1920×1080)
│           └── AdventureCombat                      — adventure_combat.gd (see COMBAT.md)
├── PlayerHud                                        — player_hud.gd, bottom-centre dock: orbs, Stamina bar, technique slots (see COMBAT.md)
└── TimerPanel (PanelContainer)                      — timer_panel.gd, top-centre, panel_timer.tres
    ├── Row → TimeIcon (hourglass), TimerLabel (Label, LabelValueMedium) — "M:SS"
    └── Timer

AdventureTilemap (Node2D)                            — adventure_tilemap.gd
├── AdventureFullMap (HexagonTileMapLayer)           — every map tile, transparent variant; hex math for the generator
├── AdventureVisibleMap (HexagonTileMapLayer)        — visited + revealed tiles as forest atlas cells; click/hover; A* pathfinding
├── AdventureHighlightMap (HexagonTileMapLayer)      — grey overlay on resolved encounter tiles
├── PathPreview (Line2D)                             — path_preview.gd
├── HoverSelector (HexHoverSelector, Sprite2D, z 5)  — hex_hover_selector.gd
├── CharacterBody2D (scale 2.5)                      — character_body_2d.gd (8-direction walk)
│   └── Camera2D
│       ├── CameraClampController                    — use_boundaries = false (no-op here)
│       └── CameraZoomController                     — zoom 0.3–1.3, default 1.0, speed 100
├── Atmosphere (CanvasLayer 5)                       — atmosphere.gd (vignette 0.5/0.35, 25 cyan + 8 warm motes)
├── FogVeilContainer (Node2D, z 4)                   — FogVeilSprite instances
├── EncounterIconContainer (Node2D, z 6)             — EncounterIcon instances
├── AdventureMarker (Node2D, z 15)                   — adventure_marker.gd
├── FogLayer (CanvasLayer 4)
│   └── FogOfWarRect (ColorRect, fog_of_war.gdshader)
├── BossFlashLayer (CanvasLayer 10)
│   └── BossFlashRect (ColorRect)
└── CanvasLayer (layer 100)
    └── EncounterInfoPanel (PanelContainer)          — encounter_info_panel.gd, panel_encounter.tres
        └── TitleLabel / DescriptionLabel / ChoicesContainer (EncounterChoiceButton instances)

AdventureEndCard (Control)                           — adventure_end_card.gd (child of MainView, z_index 3)
├── ContentContainer (scale 0.85)
│   ├── UpperRoll (+ Ribbon) / LowerRoll (TextureRect)
│   └── PaperSection → PaperMargin → VBoxContainer
│       ├── TitleSection: LeftIcon, TitleLabel (LabelEndCardTitle), RightIcon
│       ├── DefeatReasonLabel (LabelEndCardDefeatReason)
│       ├── StatsGrid (GridContainer, 3 columns): Combat, Gold, Time / Health, Tiles Explored, Madra Spent
│       ├── LootSection: LOOT label, LootTray (PanelLootTray) → LootContainer (ItemDisplaySlot ×N), LootEmptyLabel
│       └── ReturnButton (ButtonEndCard)
└── AnimationPlayer                                  — "scroll_animation" (0.4 s) + RESET
```

The main view state machine ([MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md)) has two states for this system:
- `AdventureViewState` is the base state while a run is active.
- `AdventureEndCardState` is pushed on top of it as a modal overlay; its `enter()` shows `GreyBackground`.

### Supporting Scenes

| Scene / Class | Type | Details |
|---------------|------|---------|
| `EncounterIcon` (`scenes/adventure/encounter_icon/`) | `@tool` Node2D | `Dimmable/Glyph` sprite plus a `Checkmark` badge at (20, 20). Every glyph is scaled to 84 px. Boss (7 frames, 1.4 s cycle) and rest (5 frames, 2.0 s cycle) glyphs are looping spritesheets. `set_completed(true)` sets Dimmable alpha to 0.90 and shows the checkmark. |
| `AdventureMarker` (`scenes/adventure/adventure_marker/`) | Node2D, z 15 | A pin sprite (scale 0.5) holding an `InnerEncounterIcon` at scale 0.7. It floats `TILE_OFFSET_Y = -35` above the current tile. The glyph is only reconfigured when the encounter type changes, so the boss animation does not restart. |
| `FogVeilSprite` (`scenes/adventure/fog_veil_sprite.*`) | Sprite2D | Smoke spritesheet (5×5 frames, 0.5 fps scene override, scale 1.5, alpha 0.92) with a `QuestionMark` child sprite. Each instance starts on a random frame. `fade_and_free(0.25)` tweens `self_modulate:a` to 0, then frees the node. |
| `PathPreview` (`scenes/adventure/path_preview/`) | Line2D | Width 20 with `LINE_TEXTURE_TILE` and `path_line_texture.png`. `show_path()` and `clear_path()` set the points. `set_fade_behind(pos)` moves a two-stop gradient (transparent → opaque, 18 px band) to the closest point on the line. |
| `HexHoverSelector` (`scenes/tilemaps/`) | Sprite2D, z 5 | 8-frame `hex_selector_spritesheet.png` at 8 fps. `show_at(world_pos)` snaps the ring to the tile and restarts at frame 0 if it was hidden. Only the adventure map uses it now; the zone map swaps hex rims instead. |
| `HexagonTileMapLayer` (`scenes/tilemaps/hexagon_tile_map_layer.gd`) | Extends the addon's layer | Emits `tile_clicked(Vector2i)`, `tile_hovered(Vector2i)` and `tile_unhovered()` from `_input`, but only for painted cells. Also provides `cube_pathfind()` (A* id path → cube coords) and `set_cell_with_source_and_variant()`. |
| `HexForestAtlas` (`scripts/utils/hex_forest_atlas.gd`) | Static helper | `pick(cube)` returns `posmod(hash(cube), 23)` mapped to a 6-column atlas cell, so each tile always shows the same forest variant. |
| `Atmosphere` (`scenes/atmosphere/`) | CanvasLayer 5 | Vignette, three drifting mist sprites and two mote emitters. It is tuned per instance; adventure combat creates its own copy in code. |

### Tilemap Layers and Tileset

All three layers share `scenes/tilemaps/tilemap_tileset.tres` (164×190 hex tiles):

| Layer | Source / variant | Purpose |
|-------|------------------|---------|
| `AdventureFullMap` | source 0 `base_tile`, alt 4 (alpha 0) | Holds every generated tile; the generator uses it for `cube_distance` and `cube_linedraw`. |
| `AdventureVisibleMap` | source 8 `forest_atlas`, cell from `HexForestAtlas.pick()` | Paints visited and revealed tiles. It is the click/hover target and the A* graph, so routes can only use painted tiles. |
| `AdventureHighlightMap` | source 0 `base_tile`, alt 5 (modulate `(0.08, 0.08, 0.08, 0.35)`) | Grey overlay on tiles in `_completed_encounter_tiles`. |

### Encounter Glyphs

`encounter_glyphs/` below is `assets/sprites/adventure/encounter_glyphs/`.

| Encounter type | Glyph | Notes |
|----------------|-------|-------|
| `COMBAT_REGULAR`, `COMBAT_AMBUSH` | `assets/sprites/ui/stat_icons/combat_icon.png` | Ambush looks the same as regular combat. |
| `COMBAT_ELITE` | `encounter_glyphs/elite.png` | |
| `COMBAT_BOSS` | `encounter_glyphs/boss_spritesheet.png` | 448×64 strip, 7 frames |
| `REST_SITE` | `encounter_glyphs/rest-sheet.png` | 320×64 strip, 5 frames |
| `TREASURE` | `encounter_glyphs/treasure.png` | |
| `TRAP` | `encounter_glyphs/trap.png` | |
| `NONE` | none | `configure_for_type()` returns false and the icon is hidden. |
| any other value | `encounter_glyphs/question_mark.png` | Fallback only; all current enum values are handled above. |

## Data Model

### AdventureActionData (`extends ZoneActionData`)

This is the zone action that launches an adventure. It inherits `action_id`, `action_name`, `description`, `unlock_conditions`, `max_completions`, `success_effects` and `failure_effects` (see [ZONES.md](../zones/ZONES.md)).

| Field | Type | Default | Used by |
|-------|------|---------|---------|
| `adventure_data` | `AdventureData` | — | `AdventureTilemap.start_adventure()` |
| `experience_multiplier` | `float` | 1.0 | **Unused** |
| `gold_multiplier` | `float` | 1.0 | `AdventureCombat._calculate_gold_reward()` |
| `difficulty_modifier` | `float` | 1.0 | **Unused** |
| `completion_time_modifier` | `float` | 1.0 | **Unused** |
| `time_limit_seconds` | `int` | 10 | `AdventureView.start_adventure()` (values ≤ 0 fall back to 10) |
| `stamina_regen_modifier` | `float` | 1.0 | `AdventureView._update_stamina_regen()` → `stamina_regen = 1.0 × modifier` |
| `cooldown_seconds` | `float` | 0.0 | **Unused** |
| `daily_limit` | `int` | 0 | **Unused** |

`is_valid()` exists but nothing calls it.

### AdventureData (`@tool`)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `adventure_id` / `adventure_name` / `adventure_description` | `String` | "" | Never read at runtime; the UI uses `AdventureActionData.action_name`. |
| `max_distance_from_start` | `int` | 6 | Hex radius for anchor placement |
| `sparse_factor` | `int` | 2 | Anchors must be at least this distance from the origin and from each other |
| `num_extra_edges` | `int` | 2 | Number of shortest non-MST anchor pairs to connect (0 = pure MST) |
| `encounter_quotas` | `Array[EncounterQuota]` | [] | All non-boss encounters |
| `boss_encounter` | `AdventureEncounter` | — | Placed last, at the farthest valid coordinate sampled |

`validate() -> Array[String]` returns config errors; an empty array means valid. It reports:
- `boss_encounter` is null, is not `ANCHOR`, or has a `min_distance_from_origin` larger than `max_distance_from_start`;
- a quota with a null encounter or `count <= 0`;
- any quota encounter with `min_distance_from_origin > max_distance_from_start`;
- a quota encounter with `min_fillers_on_path > 0` when there are no FILLER quotas, or when total FILLER counts are lower than its requirement.

The boss's own `min_fillers_on_path` is not validated.

### EncounterQuota (`@tool`)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `encounter` | `AdventureEncounter` | — | Encounter to place |
| `count` | `int` | 1 | Instances to place. For FILLERs this acts as a minimum, because Phase 4 promotions can exceed it. |

### AdventureEncounter (`@tool`)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `encounter_id` | `String` | "" | Identifier; shown in logs and the map preview |
| `encounter_name` | `String` | "" | Panel title |
| `description` | `String` (multiline) | "" | Panel text before resolution |
| `text_description_completed` | `String` (multiline) | "" | Panel text after resolution; falls back to "Encounter completed." |
| `choices` | `Array[EncounterChoice]` | [] | An empty array makes the tile auto-continue, like a NoOp |
| `encounter_type` | `EncounterType` | `NONE` | Drives the glyph, combat counting and the boss exception |
| `unlock_conditions` | `Dictionary[UnlockConditionData, bool]` | {} | Checked once at generation by `is_eligible()`; an ineligible encounter's quota places nothing |
| `placement` | `Placement` | `FILLER` | `ANCHOR` = scattered in Phase 1; `FILLER` = placed on NoOp path tiles in Phase 3 |
| `min_distance_from_origin` | `int` | 0 | Minimum hex distance from the origin (anchors and boss) |
| `min_fillers_on_path` | `int` | 0 | Minimum number of FILLER encounters on the shortest path from the origin (checked in Phase 4) |

- **`EncounterType` values:** `COMBAT_REGULAR` (0), `COMBAT_AMBUSH` (1), `COMBAT_BOSS` (2), `COMBAT_ELITE` (3), `REST_SITE` (4), `TRAP` (5), `TREASURE` (6), `NONE` (7).
- **`Placement` values:** `ANCHOR` (0), `FILLER` (1). The integers are stored in `.tres` files.
- **`is_eligible()`:** returns true when every condition's `evaluate()` matches its expected bool. In the editor (`Engine.is_editor_hint()`) it always returns true so the map preview shows the full map.
- **`NoOpEncounter`:** extends `AdventureEncounter` with no choices; the generator uses it for origin and path tiles. It inherits `placement = FILLER`.

### Choices

| Class | Extra fields | On select |
|-------|--------------|-----------|
| `EncounterChoice` | — | Applies `success_effects`, then completes the tile. |
| `CombatChoice` | `enemy_pool: Array[CombatantData]`, `is_boss: bool`, `gold_multiplier: float` (1.0) | Emits `start_combat`; the tile is resolved by the combat result. |
| `DialogueChoice` | `timeline_name: String` | Calls `DialogueManager.start_timeline()`. On `dialogue_ended` (one-shot) it applies `success_effects` and completes the tile. No content uses it yet. |

`EncounterChoice` base fields:

| Field | Type | Description |
|-------|------|-------------|
| `label` | `String` | Card text |
| `tooltip` | `String` (multiline) | Authored but **never displayed** |
| `requirements` | `Dictionary[UnlockConditionData, bool]` | `evaluate_requirements()` is true when every entry matches. Otherwise the card is disabled (label at 40% alpha, no hover, no click). |
| `success_effects` / `failure_effects` | `Array[EffectData]` | Failure effects only run after a lost `CombatChoice` fight. |
| `completed_label` | `String` | Shown instead of `label` when `is_completed()` is true and this is non-empty. |
| `completion_condition` | `UnlockConditionData` | When set and true, `is_completed()` returns true and the card renders disabled. This is separate from eligibility. |

### Effects Used by Choices

Choices accept any `EffectData` subclass; [EFFECTS.md](../infrastructure/EFFECTS.md) covers the full effect system. Dispatch uses the polymorphic `process()`, not `EffectData.EffectType`.

| Class | Calls | Used in shipped encounters |
|-------|-------|----------------------------|
| `ChangeVitalsEffectData` | `PlayerManager.vitals_manager.apply_vitals_change()`; health += `body_hp_multiplier × BODY`, Madra += `foundation_madra_multiplier × FOUNDATION` | Aura Well (both choices) |
| `TriggerEventEffectData` | `EventManager.trigger_event(event_id)` ([EVENTS.md](../infrastructure/EVENTS.md)) | Aura Well "Mark", Refugee Camp |
| `AwardLootTableEffectData` | `loot_table.roll_loot()` → `InventoryManager.award_items()` | Ravenous Dreadbeast |
| `AwardItemEffectData` | `InventoryManager.award_items()` | — |
| `AwardResourceEffectData` | `ResourceManager.award_resource()` | — |
| `AwardAttributeEffectData` | `CharacterManager.add_base_attribute()` | — |
| `AwardPathPointEffectData` | `PathManager.add_points()` | — |
| `StartQuestEffectData` | `QuestManager.start_quest()` | — |

### AdventureResultData

This is a plain `Resource` with no exports. `AdventureView._build_result_data()` builds it inside `stop_adventure()`.

| Field | Type | Source |
|-------|------|--------|
| `is_victory` | `bool` | `_pending_victory`, set by `AdventureTilemap.boss_defeated` |
| `defeat_reason` | `String` | "Your health reached zero", "Time ran out" or "You retreated from the adventure" |
| `combats_fought` | `int` | Incremented in every `_on_stop_combat()` call |
| `combats_total` | `int` | `AdventureTilemap.get_total_combat_count()`: tiles typed REGULAR, AMBUSH, ELITE or BOSS |
| `gold_earned` | `int` | Sum of gold from won combats |
| `time_elapsed` | `float` | `Time.get_ticks_msec()` delta |
| `health_remaining` / `health_max` | `float` | Player `VitalsManager` |
| `tiles_explored` / `tiles_total` | `int` | Visited tile count (includes origin) / all generated tiles |
| `madra_spent` | `float` | The full budget drained at start; unspent Madra is not refunded |
| `loot_items` | `Array[Resource]` | One `ItemDefinitionData` per `InventoryManager.item_awarded` emission (quantity ignored) |

## Core Systems / Flows

### Starting an Adventure

```
ZoneActionButton click
  → AdventurePresenter.can_activate()                         — ResourceManager.can_start_adventure()
    (false → on_activation_rejected(): Madra line shake + "Not enough Madra!" log)
  → ActionManager.select_action(action)                       — re-checks can_start_adventure() first (refused: nothing stops),
                                                                then stops any current action (successful = true)
    → _execute_adventure_action()
    → adventure_start_requested(action)
        ├→ ZoneViewState: add full-rect input blocker
        ├→ MapMarkers: hide until the zone view returns
        └→ ZoneTransition._on_adventure_start_requested()
             budget = ResourceManager.get_adventure_madra_budget()
             pellets = lerp(8, 25, budget / capacity); each spends floor(budget / n) Madra,
             plus one extra pellet carrying the remainder (MadraPellet, from the cabinet's Madra orb)
             → camera zoom to 3.0 over 0.5 s
             → ActionManager.confirm_adventure_start(action, budget)
  → start_adventure(action, budget)
      ├→ AdventureViewState: change_state(adventure_view_state)
      └→ AdventureView.start_adventure()
           reset stats; connect InventoryManager.item_awarded
           vitals.initialize_current_values(budget)              — HP = max, Stamina = max, Madra = budget
           stamina_regen = 1.0 × stamina_regen_modifier
           TimerPanel.start(time_limit_seconds)
           AdventureTilemap.start_adventure(action)              — generate map, visit origin
```

Madra numbers (`ResourceManager`):

| Value | Formula | Default character (FOUNDATION 10) |
|-------|---------|-----------------------------------|
| Capacity | `CharacterManager.get_total_attributes_data().get_max_madra()` = total FOUNDATION × 10 | 100 |
| Threshold to start | capacity × 0.5 | 50 |
| Budget spent | `min(capacity, current Madra)` | up to 100 |

The capacity uses total attributes, so equipment bonuses count. The path tree's `madra_capacity_bonus` does not count, because nothing consumes it. Vitals use BODY: max HP = BODY × 10 and max Stamina = BODY × 5, so a default character has 100 HP and 50 Stamina, or 10 steps before relying on regeneration.

### Map Generation

`AdventureMapGenerator` (`scenes/adventure/adventure_tilemap/adventure_map_generator.gd`) is a `@tool` `Node` that `AdventureTilemap` creates with `.new()`. It uses `AdventureFullMap` only for hex math.

`generate_adventure_map() -> Dictionary[Vector3i, AdventureEncounter]` runs these steps:

0. **Validate.** If `adventure_data.validate()` returns errors, each is sent to `push_error` and an empty map is returned.
1. **Scatter anchors** (`_place_anchors`).
   - For each eligible `ANCHOR` quota, it places `count` instances.
   - Candidate coordinates are random with `q, r ∈ [-max, max]`. A candidate is rejected if it is farther than `max_distance_from_start`, closer than the encounter's `min_distance_from_origin`, or violates `sparse_factor` (too close to the origin or to any placed tile).
   - Each instance gets up to 100 attempts, then is skipped with a warning.
   - The boss comes last: from 100 random samples, the farthest valid one wins. If none is valid, the boss is skipped with a warning.
2. **Connect** (`_generate_paths`).
   - Prim's MST over the origin plus all anchors, by `cube_distance`.
   - Then the `num_extra_edges` shortest non-MST pairs, which can include the origin.
   - Every edge is stamped with `cube_linedraw`; any empty coordinate on the line becomes a `NoOpEncounter`.
3. **Place fillers** (`_place_fillers`). For each eligible `FILLER` quota, it picks random NoOp tiles (never the origin). If NoOps run out, it stops early with a warning.
4. **Critical-path check** (`_validate_critical_paths`).
   - For each tile whose encounter has `min_fillers_on_path > 0`, it runs a BFS over all generated tiles using 6-neighbour adjacency, not just the stamped edges.
   - It counts the FILLER (non-NoOp) encounters strictly between the origin and the target.
   - If there are too few, the NoOps nearest the origin on that path are promoted to the first eligible `COMBAT_REGULAR` filler in quota order (falling back to any eligible filler). In Shallow Woods that is the Starving Dreadbeast.
   - The step fails if the path is unreachable, has too few NoOps, or no filler is eligible.

A failed Phase 4 restarts the whole run, up to `MAX_REGENERATION_ATTEMPTS = 5`. After that, the last map is returned with a `push_error`.

Other notes:
- The generator uses the global RNG with no seed.
- It has no autoload dependencies and logs with `push_error`/`push_warning`, so the editor map preview can run it.
- `test_shipped_adventures_validate` validates every `.tres` in `resources/adventure/data/`.

### Visiting Tiles, Fog of War and Reveal

- **`AdventureTilemap.start_adventure()`** paints every generated tile on `AdventureFullMap` with the transparent variant and calls `_visit(Vector3i.ZERO)`.
- **`_mark_tile_visited(coord)`:**
  - adds the tile to `_visited_tile_dictionary`;
  - rebuilds `_highlight_tile_dictionary` from map tiles adjacent to any visited tile (`HighlightType.VISIBLE_NEIGHBOUR`);
  - calls `_update_visible_map()` and `_update_fog_uniforms()`;
  - staggers the reveal of newly revealed tiles: icons scale 0.3 → 1 (0.3 s, back-ease) and fade in, 0.05 s apart.
- **`_update_visible_map()`** repaints the visible and highlight layers, then updates the overlay nodes:
  - Every visited or revealed tile gets its forest atlas cell.
  - Resolved tiles get the grey overlay.
  - Visited encounter tiles, except the current one, get a flat `EncounterIcon` with completed state set from `_completed_encounter_tiles`.
  - Revealed non-boss tiles get a `FogVeilSprite`, which covers NoOp tiles too so they look like encounters. A revealed boss tile gets its icon instead (the boss exception).
  - Stale veils fade out over `FOG_VEIL_FADE_OUT_SECONDS = 0.25` and stale icons are freed.
  - `AdventureMarker` shows the current tile's glyph, or hides on NoOp tiles.
- **The fog shader** (`fog_of_war.gdshader`) is a full-screen `ColorRect` with fog colour `(0.02, 0.03, 0.08, 0.85)`.
  - Every frame, `_update_fog_uniforms()` converts each visited and revealed tile to a screen position. The cap is `FOG_MAX_CLEAR_POSITIONS = 64`, with a warning when reached.
  - It sets `clear_radius = 180 × camera.zoom.x`, so the cleared world area stays the same at every zoom level.
  - The shader fades from clear to fog between `clear_radius` and `clear_radius × 1.5` (`clear_softness = 0.5`).
- **Boss reveal** (`_play_boss_reveal`, once per run):
  - `Engine.time_scale = 0.25` for 0.15 s of real time;
  - `BossFlashRect` flashes `(0.55, 0.78, 1.0, 0.6)`, fading over 0.4 s;
  - the camera tweens 45% toward the boss (0.5 s, cubic) and back (0.7 s).

### Movement, Stamina and the Committed Path

```
tile_hovered(coord) — ignored while movement is locked or a destination is committed
  fogged (not visited/revealed) → hide ring, clear line
  else → HoverSelector.show_at(tile); PathPreview.show_path(cube_pathfind(current, target))

tile_clicked(coord)
  movement locked → log "Movement locked"; queue non-empty or character moving → ignore
  stamina < MOVEMENT_STAMINA_COST (5) → silent return (TODO: UI feedback)
  _visitation_queue = cube_pathfind(current, target)[1:]
  commit: _committed_destination = target; ring snapped; line seeded with full route
  _process_next_visitation()

_process_next_visitation()
  stamina ≥ 5 → spend 5, pop next tile, move_to_position(tile, 150 × (1 + 0.2 × (remaining + 1)) px/s)
  stamina < 5 → clear queue, release commitment (silent stop)

_process() each frame → PathPreview.set_fade_behind(character position) while committed

movement_completed → _visit(tile)
  first visit → _mark_tile_visited; revisit → _update_visible_map only
  arrival at destination → release commitment (line cleared)
  NoOp / no choices → hide panel, continue queue
  encounter → panel.setup(encounter, was_already_visited); show_panel()
    unvisited → lock movement, clear queue, release commitment (trip hijacked)
    revisited → completed text shown, queue continues
```

Routes come from A* over `AdventureVisibleMap`. They can pass through revealed but unvisited tiles, and an unvisited encounter on the route stops the trip there.

### Resolving Encounters and Combat Hand-off

```
EncounterInfoPanel.choice_selected(choice)
  CombatChoice   → AdventureTilemap.start_combat(choice)
                   → AdventureView._on_start_combat(): combat.initialize_combat(choice, action);
                     combat.start(); PlayerHud.setup_combatant(); hide tilemap view, fade in combat view;
                     log "Encounter: <label>"
  DialogueChoice → DialogueManager.start_timeline(); dialogue_ended → success_effects → _complete_current_tile()
  EncounterChoice→ success_effects → _complete_current_tile()

AdventureCombat.trigger_combat_end(is_successful, gold)
  → AdventureView._on_stop_combat(): combats_fought += 1; gold tally; show tilemap view;
                                     is_in_combat = false; combat.stop()
    → AdventureTilemap.handle_combat_result(successful, gold)
        win:  ResourceManager.add_gold(gold); apply success_effects
              is_boss → boss_defeated → _pending_victory; ActionManager.stop_action(true)
              else    → _complete_current_tile()
        loss: apply failure_effects
    → loss → ActionManager.stop_action(false)
```

- **Ending the fight first:** `_on_stop_combat()` clears `is_in_combat` before it hands the result to the tilemap. A boss win ends the whole adventure synchronously inside `handle_combat_result()`, and `stop_adventure()` only force-ends a fight that is still running, so the win is handled once.
- **Gold:** `floor(base_gold_drop × CombatChoice.gold_multiplier × AdventureActionData.gold_multiplier × CharacterManager.get_gold_multiplier())`. The last multiplier is a stub that returns 1.0.
- **`q_first_steps_enemy_defeated`:** every combat win fires this event (deduplicated by `EventManager`).
- **`_complete_current_tile()`:** unlocks movement, switches the panel to its completed text (choices hidden), adds the tile to `_completed_encounter_tiles`, and re-renders.

### Timer and End Conditions

`TimerPanel.timer.timeout` → `AdventureView._on_adventure_timer_timeout()` → `ActionManager.stop_action(false)`. The timer keeps running during combat. In the last 30 seconds the pill's time turns red and the pill ticks once a second. It is `one_shot`, so once it fires it reads as stopped, which is how `stop_adventure()` recognises a timeout.

`ActionManager.stop_action(successful)` then runs these steps:
- `ZoneManager.increment_zone_progression_for_action(action_id)`, on every stop;
- `stop_adventure` signal;
- the action's `success_effects` or `failure_effects` (none authored for Shallow Woods);
- `clear_current_action()`;
- the zone's idle action resumes ("Resumed <name>"), so it is already running when the player returns from the end card.

`AdventureView.stop_adventure()`:
1. Picks the end reason:
   - `_pending_victory` → victory;
   - HP ≤ 0 → "Your health reached zero";
   - otherwise, timer stopped or `time_left <= 0` → "Time ran out";
   - otherwise → "You retreated from the adventure".
2. Builds `AdventureResultData`, disconnects `item_awarded`, and calls `AdventureTilemap.stop_adventure()`. That call clears all layers, icons, veils and dictionaries and resets the character to the origin, so the end card overlays an empty map.
3. Stops and hides the timer and sets stamina regen to 0. If still in combat, it calls `_on_stop_combat()`.
4. Emits `adventure_completed(result_data)`.

After that:
- `AdventureViewState._on_adventure_completed()` pushes `AdventureEndCardState` and calls `AdventureEndCard.show_results()`. That populates the card, plays `scroll_animation` backwards to unroll it, then sets content alpha to 1.
- **RETURN** plays the animation forwards and emits `return_requested` (connected one-shot). `AdventureViewState` then pops the overlay and changes to `ZoneViewState`, whose `enter()` calls `ZoneTransition.reset_camera()`.

Other ways a run stops: a `ZoneManager.zone_changed` signal stops the current action (successful = true), and `select_action()` stops the current action first. The zone view is hidden and input-blocked during a run, so the player cannot reach either path.

### Dev Hooks

The dev panel calls two `AdventureView` methods; see [DEV_TOOLS.md](../tooling/DEV_TOOLS.md):
- `force_win_combat()` emits `trigger_combat_end(true, 0)`.
- `set_show_whole_map(enabled)` → `AdventureTilemap.set_dev_reveal_all()` paints every tile with its icon, hides the fog rect and suppresses veils.

The editor-only map preview (`scenes/tools/map_preview.tscn`, `scripts/tools/map_preview.gd`) renders `AdventureMapGenerator` output for any `AdventureData`, with an optional seed. It is also documented in [DEV_TOOLS.md](../tooling/DEV_TOOLS.md).

## Integration Points

| System | Connection |
|--------|------------|
| `ActionManager` | `adventure_start_requested(action)`, `confirm_adventure_start(action, budget)` → `start_adventure(action, budget)`, `stop_action(successful)` → `stop_adventure` plus the action's completion effects |
| `ResourceManager` | `get_adventure_madra_capacity/budget/threshold()`, `can_start_adventure()`, `spend_madra()` during the drain, `add_gold()` on combat wins |
| Zones (`ZoneTransition`, `ZoneViewState`, `AdventurePresenter`, `MapMarkers`) | Madra pellet drain and camera zoom, input blocker, the adventure card's Madra line and reject shake, hiding the map markers ([ZONES.md](../zones/ZONES.md)) |
| `MainView` state machine | `AdventureViewState` (`change_state` on `start_adventure`, pushes the end card on `adventure_completed`, moves `MainView.log_window` to the top-left on enter and restores it on exit); `AdventureEndCardState` (grey background) |
| `PlayerManager.vitals_manager` | `initialize_current_values(budget)`, `stamina_regen`, Stamina deducted per step, `ChangeVitalsEffectData`, HP for end conditions and the end card |
| Combat (`AdventureCombat`) | `initialize_combat(choice, action)`, `start()`, `stop()`, `trigger_combat_end(is_successful, gold)` ([COMBAT.md](../combat/COMBAT.md)) |
| `InventoryManager` | `item_awarded(item, quantity)` feeds end-card loot; loot effects call `award_items()`; `ITEM_OWNED` conditions call `has_item()` |
| `EventManager` / `UnlockConditionData` | Encounter `unlock_conditions` (at generation), choice `requirements` / `completion_condition` (when the panel opens), events fired by choice effects ([UNLOCKS.md](../infrastructure/UNLOCKS.md)) |
| `DialogueManager` | `DialogueChoice` → `start_timeline()` / `dialogue_ended` ([DIALOGUE.md](../infrastructure/DIALOGUE.md)) |
| `ZoneManager` | `zone_changed` stops the current action; zone progression is incremented on every adventure stop |
| `PathManager` | **Not wired:** `adventure_madra_return_pct` (Madra Reclamation) and `stamina_recovery_mult` (Iron Will) are computed but nothing in adventure code reads them |
| `LogManager` | "Adventure Started/Ended", "Encounter: <label>", "Combat Victory!" / "Combat Defeat...", gold gains |

## Existing Content

### Adventures

| Zone action | `action_id` | Zone | Unlock | Time limit | Gold mult | Stamina regen mod | AdventureData |
|-------------|-------------|------|--------|------------|-----------|-------------------|---------------|
| The Shallow Woods | `shallow_woods_adventure_action` | Spirit Valley | `q_fill_core_completed` (EVENT_TRIGGERED) | 300 s | 1.0 | 1.0 | `resources/adventure/data/shallow_woods.tres` |

`shallow_woods.tres`: `adventure_id = "shallow_woods"`, `max_distance_from_start = 5`, `sparse_factor = 1` (anchors only need to avoid occupied tiles), `num_extra_edges = 4`, and `boss_encounter = manifested_spirit_encounter`. `adventure_description` is empty.

| Quota | Encounter | Count |
|-------|-----------|-------|
| 1 | `aura_well` | 1 |
| 2 | `refugee_camp` (conditional) | 1 |
| 3 | `starving_dreadbeast_encounter` | 3 |
| 4 | `amorphous_spirit_encounter` | 4 |
| 5 | `coalescing_spirit_encounter` | 2 |
| 6 | `ravenous_dreadbeast_encounter` | 2 |

### Shallow Woods Encounters (`resources/adventure/encounters/shallow_woods/`)

| `encounter_id` (file) | Name | Type | Placement | Min dist | Min fillers | Choice → result | Reward |
|-----------------------|------|------|-----------|----------|-------------|-----------------|--------|
| `manifested_spirit_encounter` (`combat_encounters/`) | Manifested Spirit Encounter | `COMBAT_BOSS` | ANCHOR | 5 | 0 | "Confront the Boss" → fights `amorphous_spirit` (`is_boss = true`) | 15 gold; win ends the run as a victory |
| `amorphous_spirit_encounter` (`combat_encounters/regular/`) | Amorphous Spirit Attacks! | `COMBAT_REGULAR` | FILLER | 0 | 0 | "Attack the Spirit" → `amorphous_spirit` | 15 gold |
| `starving_dreadbeast_encounter` (`combat_encounters/regular/`) | Starving Dreadbeast Attacks! | `COMBAT_REGULAR` | FILLER | 0 | 0 | "Attack the Dreadbeast" → `starving_dreadbeast` | 20 gold |
| `coalescing_spirit_encounter` (`combat_encounters/elite/`) | Coalescing Spirit Attacks! | `COMBAT_ELITE` | ANCHOR | 0 | 1 | "Attack the Spirit" → `coalescing_spirit` | 0 gold (no `base_gold_drop`) |
| `ravenous_dreadbeast_encounter` (`combat_encounters/elite/`) | Ravenous Dreadbeast Attacks! | `COMBAT_ELITE` | ANCHOR | 0 | 1 | "Attack the Dreadbeast" → `ravenous_dreadbeast` | 20 gold + 25% Dreadbeast Tooth Necklace (inline loot table) |
| `aura_well` (`special_encounters/`) | Aura Well | `REST_SITE` | ANCHOR | 3 | 1 | "Rest" → +5 × BODY HP, +2 × FOUNDATION Madra. "Mark down the location" (requires `aura_well_discovered` = false) → same restore plus fires `aura_well_discovered`; once the event has fired the card reads "✓ Location noted" and is disabled. | Unlocks the Aura Well training zone action |
| `refugee_camp` (`special_encounters/`) | Refugee Camp | `REST_SITE` | ANCHOR | 3 | 1 | "Approach the camp" → fires `merchant_discovered` | Unlocks the Merchant zone action and its shop. Only eligible while `refugee_camp_map` is owned (ITEM_OWNED) and `merchant_discovered` has not fired. |

Enemy stats and abilities are in [COMBAT.md](../combat/COMBAT.md). All gold values assume the 1.0 multipliers above. With default attributes (BODY 10, FOUNDATION 10), the Aura Well restores 50 HP and 20 Madra.

### Placeholder Encounters (not used by any adventure)

| File | Type | Content |
|------|------|---------|
| `resources/adventure/encounters/test_rest_encounter.tres` | `REST_SITE` | No id, name or description; choice "REST" → +10 Madra |
| `resources/adventure/encounters/test_trap_encounter.tres` | `TRAP` | No id, name or description. Two unlabelled choices: −10 HP; −10 Stamina (requires `test_attribute_requirement_unlock_data`, BODY ≥ 20) |
| `resources/adventure/encounters/test_treasure_encounter.tres` | `TREASURE` | id `"Treasure!"`; choice "TREASURE!" → rolls `test_loot_table_weapon` (makeshift dagger / iron shortsword) |

### Typical Shallow Woods Map

These figures are estimates from an offline Python port of `AdventureMapGenerator`, run 20,000 times each with and without the refugee camp eligible. They were not measured in-engine.

| Metric | Estimate |
|--------|----------|
| Total tiles | median 25–26; p10–p90 is 19–33; max about 44 (the 64-position fog cap is never reached) |
| NoOp walk-through tiles (including origin) | median 11 |
| Combat tiles (including boss) | median 13 (range 8–17) |
| Starving Dreadbeasts | quota 3; above quota in about 72% of maps because of Phase 4 promotions (median 4, max 8) |
| Shortest path to boss | at least 5 steps (median 5) |
| Regeneration | about 25% of maps need two or more attempts; about 0.05–0.1% use all 5 and ship a map that breaks a `min_fillers_on_path` rule. Most failures come from an elite placed next to the origin. |

## Key Files

| File | Purpose |
|------|---------|
| `scenes/adventure/adventure_view/adventure_view.gd` / `.tscn` | Top-level controller: start/stop, tilemap/combat view switching, timer, stat tracking, result building, dev hooks |
| `scenes/adventure/adventure_view/timer_panel.gd` | Countdown pill (red and ticking in the last 30 s) |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` / `.tscn` | Map state, reveal and fog, movement and Stamina, committed path, encounter resolution, boss reveal |
| `scenes/adventure/adventure_tilemap/adventure_map_generator.gd` | Quota-based 4-phase generator (`@tool`) |
| `scenes/adventure/adventure_tilemap/encounter_info_panel.gd` / `.tscn` | Encounter panel: fade, choice cards, completed text |
| `scenes/adventure/adventure_tilemap/encounter_choice_button.gd` / `.tscn` | Card-style choice button (`action_card_normal/hover.tres`) |
| `scenes/adventure/encounter_icon/encounter_icon.gd` / `.tscn` | Per-type glyph, spritesheet animation, completed state |
| `scenes/adventure/adventure_marker/adventure_marker.gd` / `.tscn` | Pin above the current tile with an embedded `EncounterIcon` |
| `scenes/adventure/fog_veil_sprite.gd` / `.tscn` | Smoke veil + "?" on revealed tiles |
| `scenes/adventure/path_preview/path_preview.gd` / `.tscn` | Tiled route line with fade-behind gradient |
| `scenes/adventure/adventure_end_card/adventure_end_card.gd` / `.tscn` | Scroll end card |
| `scenes/adventure/scripts/pack_smoke_spritesheet.py` | Builds `assets/sprites/atmosphere/smoke_veil_spritesheet.png` |
| `scenes/tilemaps/hexagon_tile_map_layer.gd` / `.tscn` | Project hex layer: click/hover signals, `cube_pathfind`, `set_cell_with_source_and_variant` |
| `scenes/tilemaps/hex_hover_selector.gd` / `.tscn` | Shared hover ring |
| `scenes/tilemaps/tilemap_tileset.tres` | Shared TileSet: source 0 `base_tile` (alt 4 transparent, alt 5 grey), source 8 forest atlas |
| `scenes/tilemaps/scripts/pack_hex_atlas.py`, `resize_forest_variants.py` | Build `hex_forest_atlas.png` |
| `scripts/utils/hex_forest_atlas.gd` | `HexForestAtlas.pick()` |
| `scenes/atmosphere/atmosphere.gd` / `.tscn` | Shared atmosphere layer |
| `scenes/camera/camera_zoom_controller/`, `scenes/camera/camera_clamp_controller/` | Adventure camera controllers |
| `assets/shaders/fog_of_war.gdshader` | Screen-space fog with up to 64 clear positions |
| `scenes/ui/main_view/states/adventure_view_state.gd`, `adventure_end_card_state.gd` | View states |
| `singletons/action_manager/action_manager.gd` | Adventure start/stop routing |
| `scenes/zones/zone_transition/zone_transition.gd` | Madra drain and camera zoom before start |
| `scenes/zones/zone_action_button/presenters/adventure_presenter.gd` | The adventure card's Madra line, rod, ready state and affordability gate |
| `scripts/resource_definitions/adventure/adventure_data.gd` | `AdventureData` + `validate()` |
| `scripts/resource_definitions/adventure/encounter_quota.gd` | `EncounterQuota` |
| `scripts/resource_definitions/adventure/encounters/adventure_encounter.gd`, `no_op_encounter.gd` | Encounter base (+ enums, `is_eligible()`) and NoOp |
| `scripts/resource_definitions/adventure/choices/encounter_choice.gd`, `combat_choice.gd`, `dialogue_choice.gd` | Choice classes |
| `scripts/resource_definitions/adventure/adventure_result_data.gd` | End-card stats |
| `scripts/resource_definitions/zones/zone_action_data/adventure_action_data/adventure_action_data.gd` | `AdventureActionData` |
| `resources/adventure/data/shallow_woods.tres` | The Shallow Woods |
| `resources/adventure/encounters/shallow_woods/` | Shallow Woods encounters (`combat_encounters/{regular,elite}/`, `special_encounters/`) |
| `resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres` | Zone action that launches The Shallow Woods |
| `scripts/tools/map_preview.gd`, `scenes/tools/map_preview.tscn` | Editor map preview ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md)) |

### Tests

| File | Tests | Covers |
|------|-------|--------|
| `tests/unit/test_adventure_map_generator.gd` | 9 | Generator: invalid config, anchor distance, sparse factor, boss farthest, branching, quota counts, ineligible skip, termination, filler-on-path |
| `tests/unit/test_adventure_data.gd` | 9 | Each `validate()` branch; every shipped adventure validates |
| `tests/unit/test_adventure_encounter.gd` | 5 | Defaults, `is_eligible()` |
| `tests/unit/test_encounter_quota.gd` | 2 | Defaults |
| `tests/unit/test_encounter_choice.gd` | 7 | `evaluate_requirements()`, `is_completed()` |
| `tests/unit/test_encounter_icon_config.gd` | 10 | `configure_for_type()` per type, `set_completed()` |
| `tests/unit/test_hex_forest_atlas.gd` | 4 | `pick()` determinism and bounds |
| `tests/unit/test_adventure_result_data.gd` | 12 | Field defaults and assignment |
| `tests/unit/test_adventure_combat_count.gd` | 12 | Re-implements the combat-type filter; never calls `get_total_combat_count()` |
| `tests/unit/test_adventure_combat_victory_event.gd` | 2 | Fires the event itself; never exercises `AdventureCombat` |
| `tests/integration/test_adventure_flow.gd` | 17 | Re-implements the Madra math with a stale `50 + FOUNDATION × 10` capacity; never calls `ResourceManager` |
| `tests/integration/test_aura_well_discovery_unlock.gd` | 2 | `aura_well_discovered` gates the Aura Well zone action |
| `tests/integration/test_beat_3b_merchant_unlock.gd` | 1 | Refugee camp eligibility before and after `merchant_discovered` |
| `tests/integration/test_adventure_end_flow.gd` | 2 | The real `AdventureView`, started through `ActionManager`: a timeout ends the run with "Time ran out"; a boss win ends it once, as a victory, without the boss choice's failure effects |

### Related Design Docs

| Spec / plan | Status |
|-------------|--------|
| [2026-04-10 adventure end card](../superpowers/specs/2026-04-10-adventure-end-card-design.md) | Shipped. The spec's "manual exit" trigger has no UI (no retreat, by design). |
| [2026-04-13 tilemap visual overhaul](../superpowers/specs/2026-04-13-tilemap-visual-overhaul-design.md) | Partial. Shipped: atmosphere, fog shader, `EncounterIcon`, `PathPreview` (tiled texture instead of a flowing shader), reveal stagger, boss hit-stop/flash/push, hover ring. Not built: 5-state `TileStateOverlay` (dropped), boss ornamental ring, treasure sparkle, hidden-until-visited traps, player glow orb, click ring burst, hover scale, `PanelStamina` restyle, gradient background. |
| [2026-04-15 fog-of-war redesign](../superpowers/specs/2026-04-15-fog-of-war-redesign-design.md) | Shipped and iterated. A tile now counts as completed when it is resolved (not when the player walks away); the grey overlay, map-pin marker and 0.25 s veil fade-out were added. |
| [2026-04-21 map generation rework](../superpowers/specs/2026-04-21-map-generation-rework-design.md) | Shipped. Shallow Woods was retuned in May (radius 5, sparse 1, 4 extra edges, 4 elite anchors). Not done: a boss with its own stats, the anchor-density warning, logging of skipped ineligible encounters. |
| [2026-04-23 map preview tool](../superpowers/specs/2026-04-23-map-preview-tool-design.md) | Shipped ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md)). |

## Work Remaining

### Bugs

- `[LOW]` **Deaths outside combat are handled inconsistently.**
  - `AdventureCombat._on_player_health_changed` is connected to the persistent player `VitalsManager` in the first `initialize_combat()` and is never disconnected.
  - After a session's first fight, HP reaching 0 outside combat (for example from a future trap effect) emits `trigger_combat_end(false, 0)` and counts as a lost combat.
  - Before the first fight, HP 0 outside combat does not end the run at all.
  - No shipped encounter deals damage outside combat.
- `[LOW]` **An encounter can soft-lock the player.** An unvisited encounter locks movement until a choice resolves it, and there is no built-in "leave" option. If every card is disabled (requirements unmet or already completed), the player is stuck until the timer runs out. Every shipped encounter has a card that is always available.
- `[LOW]` **The boss-reveal camera push can leave the camera offset.** `AdventureTilemap._play_boss_reveal()` tweens `Camera2D.global_position` back to the position captured when the tween started. The camera is a child of `CharacterBody2D`, so if the character keeps walking during the 1.2 s tween, the camera ends up offset from the player and nothing resets it. This only happens when the boss is revealed mid-route; not verified in play.
- `[LOW]` **End-card loot ignores quantities.** `AdventureView._on_item_awarded(item, _quantity)` adds one entry per award and ignores the quantity, and duplicate items are not stacked.

### Missing Functionality

- `[HIGH]` **Nothing records a completed adventure.**
  - A boss win only calls `ActionManager.stop_action(true)`. Shallow Woods has no `success_effects` and no event fires on boss defeat.
  - `UnlockConditionData.ConditionType.ADVENTURE_COMPLETED` logs "not yet implemented" and returns false.
  - As a result, no quest, zone or Foundation beat (such as Beat 7's Tribulation Guardian → Advancement Zone) can be gated on clearing an adventure.
- `[HIGH]` **Path perks that target adventures do nothing.**
  - Madra Reclamation (`ADVENTURE_MADRA_RETURN_PCT`, +10% per purchase, up to 5) and Iron Will (`STAMINA_RECOVERY_MULT`, ×1.2) can be bought, and `PathManager` computes their values.
  - But `AdventureView.stop_adventure()` never refunds unspent Madra, and `_update_stamina_regen()` reads only `stamina_regen_modifier`. Players spend path points for no effect.
- `[MEDIUM]` **There are no "seen" or "reached" hooks on encounters.** Effects only run when a choice resolves; nothing fires when a tile is revealed or first entered. [FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md) needs both: Beat 5's `q_first_elite` starts when the elite is first seen, and Beat 7's quest starts when the player first reaches the Guardian tile.
- `[MEDIUM]` **No difficulty scaling.** `difficulty_modifier` and `experience_multiplier` on `AdventureActionData` are never read, and nothing scales by distance from the origin. Both are needed before Copper-tier adventures.
- `[MEDIUM]` **Fights always use the first enemy.** `AdventureCombat._create_enemy_combatant()` uses `enemy_pool[0]` (TODO at `adventure_combat.gd:132`), so every encounter authors a single enemy (see [COMBAT.md](../combat/COMBAT.md)).
- `[LOW]` **Movement cost is fixed.** `MOVEMENT_STAMINA_COST` is the constant 5.0 (TODO at `adventure_tilemap.gd:45`), with no terrain or stat scaling.
- `[LOW]` **No seeded generation in-game.** The generator uses the global RNG, so a bad map reported by a player cannot be reproduced. Only the map preview accepts a seed.
- `[LOW]` **Ambush and trap types have no behaviour.** `COMBAT_AMBUSH` and `TRAP` only change the glyph; ambush renders as regular combat.
- `[LOW]` **No fixed-position encounters.** Every anchor position is re-rolled each run, so nothing can be pinned to a coordinate. FOUNDATION_PLAYTHROUGH Beat 5 refers to the elite's "fixed adventure tile".
- `[LOW]` **Generator logging gaps.** `AdventureData.validate()` has no anchor-density warning (the spec's non-fatal check), and Phases 1 and 3 skip ineligible quotas without logging.

### Content

- `[HIGH]` **The boss reuses a regular enemy.** `manifested_spirit_encounter` fights `amorphous_spirit.tres`, the same `CombatantData` as `amorphous_spirit_encounter` (same name, stats and 15 gold). The map-generation spec called for boss-appropriate stats, and the Foundation plan calls for a Tribulation Guardian boss.
- `[HIGH]` **Only one adventure exists.** `shallow_woods` is the only adventure, in the only zone, with no Zone 2 or Copper adventure. Encounter folders are already organised per adventure (`resources/adventure/encounters/<adventure>/`).
- `[MEDIUM]` **No treasure, trap or generic rest encounters.** None appear in any adventure; the three `test_*_encounter.tres` placeholders are unreferenced and incomplete. Run rewards are combat gold plus one 25% necklace drop.
- `[MEDIUM]` **Elite rewards are thin.** Coalescing Spirit gives 0 gold (`coalescing_spirit.tres` has no `base_gold_drop`) and has no success effects. Elite rewards do not yet match Beat 5's "equipment tier bump".
- `[LOW]` **No `DialogueChoice` content.** The flow exists but no encounter uses it.
- `[LOW]` **GDD node types and resources are mostly missing.** The GDD's Madra Well exists only as the Aura Well rest site. There are no Sacred Resources (Remnants, Beast Parts), Manuals/Recipes/Schematics or Fame drops.
- `[LOW]` **Text polish.** The `ravenous_dreadbeast_encounter` description has a typo ("This putrid's dreadbeasts muscles…"), and the boss panel title reads "Manifested Spirit Encounter".

### UI

- `[MEDIUM]` **No feedback when Stamina blocks movement.** `_on_tile_clicked()` returns silently (`# TODO: Show UI feedback`, `adventure_tilemap.gd:396`), and `_process_next_visitation()` silently drops the rest of a route. Only the Stamina bar shows why.
- `[LOW]` **Clicks are ignored while walking.** `_on_tile_clicked()` returns while the queue is non-empty or `is_moving`, so the player cannot change destination mid-route.
- `[LOW]` **Choice cards drop authored detail.** `EncounterChoice.tooltip` is authored (Aura Well, Refugee Camp) but never shown. `EncounterChoiceButton.setup()` ignores its texture and fill-colour parameters, so the `Color.DARK_RED` computed for combat choices is thrown away.
- `[LOW]` **Animated glyphs restart on every map refresh.** `_update_cell_highlight()` runs `configure_for_type()` twice (via `set_visited()`), so flat boss and rest icons restart their spritesheet on each tile arrival. `AdventureMarker` avoids this by caching `_last_type`.
- `[LOW]` **The fog veil's "?" pops instead of fading.** `FogVeilSprite.fade_and_free()` fades `self_modulate`, which does not reach the `QuestionMark` child.
- `[LOW]` **The end card has no keyboard dismiss** (`AdventureEndCardState.handle_input()` is empty), and it opens over an already-cleared map rather than the final explored state.

### Tech Debt

#### Dead Code
- `[LOW]` Unused `AdventureActionData` members: `completion_time_modifier`, `cooldown_seconds`, `daily_limit` (mobile-style pacing gates), and `is_valid()`.
- `[LOW]` `AdventureData.adventure_id`, `adventure_name` and `adventure_description` are never read at runtime.
- `[LOW]` Unused members in adventure scripts:
  - `AdventureTilemap.INSTANT_MOVE_SPEED`, the `_total_cost` local in `_on_tile_clicked()`, and the one-value `HighlightType` enum;
  - `AdventureView.current_encounter`;
  - `EncounterIcon._is_visited` and `set_visited()`, which no longer have a visual effect. Their doc comments still describe trap reveal and a 0.45 completed alpha; the code uses 0.90.
- `[LOW]` `AdventureCombat.enable_ai` debug export with `# TODO: DELETE DEBUG` (`adventure_combat.gd:33-36`) is still present.
- `[LOW]` Unreferenced scenes: `scenes/tilemaps/pulse_node.gd` / `.tscn` and `scenes/tilemaps/tile_map_layer.tscn` (legacy layer with an inline script).
- `[LOW]` The three `test_*_encounter.tres` placeholders (see Content).

#### Code Quality
- `[MEDIUM]` **Hex layers skip the addon's own setup.**
  - `scenes/tilemaps/hexagon_tile_map_layer.gd` overrides `_ready()` without calling `super()`, so the addon's `_ready()` never runs. That `_ready()` is what sets up the cube↔map conversion methods and pathfinding.
  - A layer only gets its conversions when the shared `tilemap_tileset.tres` emits `changed`, which happens once after the tileset first loads. The game works because its single zone and adventure maps exist at that moment.
  - Any hex layer created later (a second adventure view, a new map scene, a test that builds the view twice) fails `cube_to_map()` with "conversion method was not properly set up". `test_adventure_end_flow.gd` re-emits the tileset's `changed` to work around it.
  - Fix: call `super()` in that `_ready()`, then check both maps in play.
- `[LOW]` `HexagonTileMapLayer.set_cell_with_source_and_variant()` rebuilds the whole A* graph (`pathfinding_generate_points()`) and debug drawing for every cell set. `_update_visible_map()` repaints every visible tile on each arrival, so each refresh is O(N²). `AdventureFullMap` and `AdventureHighlightMap` also have `pathfinding_enabled = true`, although only the visible map pathfinds. This is negligible at about 25 tiles.
- `[LOW]` Fog clear positions are capped at 64 (`FOG_MAX_CLEAR_POSITIONS` and the shader's `MAX_CLEAR_POSITIONS`). Tiles past the cap stay fogged, with a warning. Shallow Woods never reaches it; larger adventures will.
- `[LOW]` Stale `ext_resource` UIDs:
  - `adventure_tilemap.tscn` references PathPreview as `uid://b387ck3lm5j3y`, but `path_preview.tscn` declares `uid://cpathpreview01`.
  - `hexagon_tile_map_layer.tscn` references the tileset as `uid://eptmap1q2w3e4`, but `tilemap_tileset.tres` is now `uid://ufqon4iip7nd`.
  - Godot falls back to the text path with a warning.
  - The tileset's `base_tile` source also uses an inline `CompressedTexture2D` pointing into `.godot/imported/` instead of an `ext_resource` to `assets/sprites/tilemap/tile_horizontal.png`.
- `[LOW]` `AdventureTilemap` creates `AdventureMapGenerator` (a `Node`) with `.new()` and never adds it to the tree or frees it, so it leaks one node per view (`test_adventure_end_flow.gd` frees it by hand). It could be a `RefCounted`.
- `[LOW]` "Show Whole Map" is not purely visual: dev-revealed tiles are painted on `AdventureVisibleMap`, so they become clickable and pathable, while hover previews still ignore them.
- `[LOW]` `EffectData.EffectType` is not used for dispatch. The `AwardResource`, `AwardItem`, `AwardLootTable` and `TriggerEvent` effect classes don't set it in `_init()`, so it stays `NONE` unless the `.tres` sets it, and none of the adventure encounter effects do.
- `[LOW]` Open TODOs: `_apply_effects()` (`# TODO: Pass context if needed`) and `_update_stamina_regen()` (`# TODO: ... more complex calculation logic`).

#### Tests
- `[MEDIUM]` **Several tests check their own copies of the logic, not production code.**
  - `test_adventure_combat_count.gd` re-implements the combat filter instead of calling `AdventureTilemap.get_total_combat_count()`.
  - `test_adventure_combat_victory_event.gd` fires the event itself.
  - `tests/integration/test_adventure_flow.gd` (and the adventure cases in `test_resource_manager.gd`) use a `50 + FOUNDATION × 10` capacity that production no longer uses. Production is `FOUNDATION × 10`, and none of these tests call `ResourceManager`.
  - `test_min_fillers_on_path_guaranteed` counts NoOp tiles as fillers (they inherit `placement = FILLER`), so it passes even if Phase 4 is broken.
- `[MEDIUM]` **Core scene logic is untested.** There are no tests for:
  - `AdventureTilemap` (visit/complete, Stamina gating, committed path);
  - `AdventureView` beyond the timeout and boss-win paths in `test_adventure_end_flow.gd` (death, result building);
  - `EncounterInfoPanel` (disabled and completed card states);
  - `AdventureEndCard`;
  - `PathPreview.set_fade_behind()`;
  - the `ActionManager` adventure start/stop path.
