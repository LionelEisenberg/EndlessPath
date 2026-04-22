# Adventuring System

## Overview

Adventuring is a roguelite-style exploration mode where the player navigates a procedurally generated hex grid map. The grid contains encounter nodes connected by walkable paths, with fog-of-war revealing tiles as the player moves. Each encounter presents choices (fight, rest, collect treasure, dialogue). A countdown timer limits the run, movement costs Stamina, and defeating the boss at the furthest node completes the adventure.

## Player Experience

1. Player selects an Adventure action from a zone
2. Adventure view replaces the zone view; a hex map generates procedurally
3. Player starts at the origin tile, with only immediate neighbors visible
4. Clicking a revealed tile pathfinds and moves the character (costs 5 Stamina per step)
5. Reaching an encounter tile opens the `EncounterInfoPanel` with choices
6. Choosing combat switches to the combat view; other choices apply effects immediately
7. Completed tiles show their post-completion text; player can move through freely
8. Defeating the boss tile triggers `ActionManager.stop_action(true)` — adventure success
9. Running out of stamina, losing combat, or timer expiry ends the run as a failure
10. A scroll-themed end card overlays the adventure view showing victory/defeat, stats, and loot
11. Player clicks RETURN — scroll closes and returns to zone view

## Architecture

```
AdventureView (Control)                         — adventure_view.gd
  TilemapView (Control)
    SubViewportContainer (1920x1080)
      Background (Sprite2D)
      SubViewport
        AdventureTilemap (Node2D)               — adventure_tilemap.gd
          AdventureFullMap (HexagonTileMapLayer)    — structural ghost tiles
          AdventureVisibleMap (HexagonTileMapLayer) — fog-of-war revealed + click/hover signals
          AdventureHighlightMap (HexagonTileMapLayer) — gray overlay on completed tiles
          PathPreview (Line2D)                  — path_preview.gd, tiled-texture route line
          HoverSelector (AnimatedSprite2D)      — hex_hover_selector.gd, shared ring
          CharacterBody2D + Camera2D
            CameraClampController
            CameraZoomController
          Atmosphere                            — vignette + mist + motes (PR #23)
          FogVeilContainer (Node2D, z=4)        — holds FogVeilSprite instances
          EncounterIconContainer (Node2D, z=6)  — holds EncounterIcon instances
          AdventureMarker (z=15)                — floating pin above current tile
          FogLayer (CanvasLayer=4)
            FogOfWarRect (ColorRect + shader)   — full-screen fog with per-tile clear zones
          BossFlashLayer (CanvasLayer=10)
            BossFlashRect (ColorRect)           — white flash on boss reveal
          CanvasLayer (layer=100)
            EncounterInfoPanel                  — encounter_info_panel.gd (fade in/out)
  CombatView (Control, hidden)
    SubViewport
      AdventureCombat                           — adventure_combat.gd
  PlayerInfoPanel (CombatantInfoPanel)
  TimerPanel                                    — timer_panel.gd

AdventureEndCard (Control)                      — adventure_end_card.gd
  ContentContainer (Control)                    — scroll textures + content
    UpperRoll / LowerRoll (TextureRect)         — scroll roll assets
    PaperSection (TextureRect)                  — paper body with stats grid
      StatsGrid (GridContainer)                 — 3x2 stat display
      LootSection (VBoxContainer)               — ItemDisplaySlot instances
    ReturnButton (Button)                       — ButtonEndCard theme variant
  AnimationPlayer                               — single reversible scroll_animation
```

### Three-Layer Tilemap

| Layer | Node | Purpose |
|-------|------|---------|
| `full_map` | AdventureFullMap | All tiles as transparent ghosts (structural, pathfinding reference) |
| `visible_map` | AdventureVisibleMap | Fog-of-war revealed tiles rendered as random forest variants from `hex_forest_atlas.png`; emits `tile_clicked`/`tile_hovered`/`tile_unhovered` signals |
| `highlight_map` | AdventureHighlightMap | Gray overlay on completed encounter tiles (variant ID 5 with ~35% alpha dark modulate) |

Encounter type visuals are handled by `EncounterIcon` instances in a separate `EncounterIconContainer` (Node2D at z=6), not by the tilemap highlight layer. Pathfinding runs on `AdventureVisibleMap` — players can only click revealed tiles.

## Map Generation

File: `scenes/adventure/adventure_tilemap/adventure_map_generator.gd`

Generation runs in 4 phases:

### Phase 1 — Place Special Tiles
- Scatters `num_special_tiles` coordinates using random cube coords `(q, r, s=-q-r)`
- Rejects tiles outside `max_distance_from_start` or too close to existing tiles (`sparse_factor`)
- Up to 100 attempts per tile placement

### Phase 2 — Assign Encounters
- Each special tile gets a random encounter from `special_encounter_pool`
- The tile **furthest from origin** becomes the boss encounter

### Phase 3 — Generate MST Paths (Prim's Algorithm)
- Connects all special tiles via Minimum Spanning Tree
- Draws hex lines (`cube_linedraw`) between connected nodes
- Intermediate tiles become `NoOpEncounter` walk-through paths
- Guarantees all special nodes are reachable from start

### Phase 4 — Assign Path Encounters
- Promotes `num_path_encounters` random NoOp path tiles to encounters from `path_encounter_pool`

## Data Model

### AdventureData (map configuration)
| Field | Type | Description |
|-------|------|-------------|
| `adventure_id` | `String` | Unique identifier |
| `num_special_tiles` | `int` | Encounter nodes to scatter |
| `max_distance_from_start` | `int` | Bounding hex radius |
| `sparse_factor` | `int` | Minimum spacing between special tiles |
| `num_path_encounters` | `int` | NoOp tiles promoted to encounters |
| `boss_encounter` | `AdventureEncounter` | Placed at furthest tile |
| `special_encounter_pool` | `Array[AdventureEncounter]` | Pool for special tiles |
| `path_encounter_pool` | `Array[AdventureEncounter]` | Pool for promoted path tiles |

### AdventureActionData (extends ZoneActionData)
| Field | Type | Description |
|-------|------|-------------|
| `adventure_data` | `AdventureData` | Map config |
| `time_limit_seconds` | `int` | Run timer (default 10, test uses 300) |
| `gold_multiplier` | `float` | Multiplier for combat gold rewards |
| `stamina_regen_modifier` | `float` | Stamina regen rate multiplier |
| `experience_multiplier` | `float` | **Defined but unused** |
| `difficulty_modifier` | `float` | **Defined but unused** |
| `cooldown_seconds` | `float` | **Defined but unenforced** |
| `daily_limit` | `int` | **Defined but unenforced** |

### AdventureEncounter
| Field | Type | Description |
|-------|------|-------------|
| `encounter_id` | `String` | Unique ID |
| `encounter_name` | `String` | Display name |
| `description` | `String` | Shown before completion |
| `text_description_completed` | `String` | Shown after completion |
| `choices` | `Array[EncounterChoice]` | Available player choices |
| `encounter_type` | `EncounterType` | Visual overlay category |
| `unlock_conditions` | `Dictionary[UnlockConditionData, bool]` | Map-generation-time gate (PR #41). Each key's `evaluate()` must match its expected bool for the encounter to be eligible for placement; otherwise it's filtered out of the pool before generation — the player never sees it |

**EncounterType enum:** `COMBAT_REGULAR`, `COMBAT_AMBUSH`, `COMBAT_BOSS`, `COMBAT_ELITE`, `REST_SITE`, `TRAP`, `TREASURE`, `NONE`

### Choice Types

| Class | Extra Fields | Behavior |
|-------|-------------|----------|
| `EncounterChoice` (base) | `requirements`, `success_effects`, `failure_effects`, `completed_label`, `completion_condition` | Applies effects directly. See below for the schema additions from PR #36 |
| `CombatChoice` | `enemy_pool`, `is_boss`, `gold_multiplier` | Triggers combat view |
| `DialogueChoice` | `timeline_name` | Starts Dialogic timeline |

**EncounterChoice schema (PR #36):**

- `requirements: Dictionary[UnlockConditionData, bool]` — each key is an `UnlockConditionData`; the value is the expected `evaluate()` result. The choice is eligible when every entry matches. Empty dict → always eligible. Replaces the older `Array[UnlockConditionData]` (+ `negate` flag) schema.
- `completion_condition: UnlockConditionData` (optional) — when set and evaluates true, the choice renders as completed (grayed, using `completed_label` if non-empty; falls back to `label`). Independent of `requirements` so eligibility and completion are orthogonal — used by the Aura Well "Mark" choice to show "✓ Location noted" on sibling tiles post-discovery.
- `completed_label: String` — the text shown when `completion_condition` is satisfied.
- Helpers: `evaluate_requirements()` and `is_completed()`.

### World Effect System (separate from Combat effects)

Base class: `EffectData` (abstract Resource) — defines an `EffectType` enum and an abstract `process()` method. Each subclass implements `process()` to apply its effect. Effects are attached to encounter choices via `success_effects` and `failure_effects` arrays, and are executed by `_apply_effects()` when a choice resolves.

| Class | EffectType | Action |
|-------|------------|--------|
| `AwardResourceEffectData` | `AWARD_RESOURCE` | Calls `ResourceManager.award_resource()` |
| `AwardItemEffectData` | `AWARD_ITEM` | Calls `InventoryManager.award_items()` |
| `AwardLootTableEffectData` | `AWARD_LOOT_TABLE` | Rolls loot table, awards items |
| `AwardAttributeEffectData` | `AWARD_ATTRIBUTE` | Grants attribute points via CharacterManager |
| `AwardPathPointEffectData` | `AWARD_PATH_POINT` | Grants path points via `PathManager.add_points()` (PR #32) |
| `StartQuestEffectData` | `START_QUEST` | Starts a quest via `QuestManager.start_quest()` |
| `ChangeVitalsEffectData` | *(not in enum)* | Modifies health/stamina/madra via PlayerManager. Includes `body_hp_multiplier` / `foundation_madra_multiplier` for attribute-scaled vitals changes (PR #36) — final values via `get_final_health_change()` / `get_final_madra_change()` / `get_final_stamina_change()` |
| `TriggerEventEffectData` | `TRIGGER_EVENT` | Fires a narrative event via EventManager |

### AdventureResultData (end card stats)
| Field | Type | Description |
|-------|------|-------------|
| `is_victory` | `bool` | Boss defeated = true |
| `defeat_reason` | `String` | Human-readable reason (empty on victory) |
| `combats_fought` | `int` | Combats entered (win or lose) |
| `combats_total` | `int` | Total combat encounters on the map |
| `gold_earned` | `int` | Gold from successful combats |
| `time_elapsed` | `float` | Seconds from start to end |
| `health_remaining` | `float` | Player HP at end |
| `health_max` | `float` | Player max HP |
| `tiles_explored` | `int` | Unique tiles visited |
| `tiles_total` | `int` | Total tiles on map |
| `madra_spent` | `float` | Madra budget consumed |
| `loot_items` | `Array[Resource]` | Items awarded during adventure |

## UI Style (PR #15)

The adventure UI was restyled in PR #15 to match the dark floating panel aesthetic used across the game:

- **`EncounterInfoPanel`** — dark floating stylebox background, gold title label, card-style choice buttons with hover states
- **`TimerPanel`** — repositioned to top-center of the screen, using the same dark floating style
- **`PlayerInfoPanel` / `CombatantInfoPanel`** — rebuilt with container-based layout and integer vitals display (see [COMBAT.md](../combat/COMBAT.md) for full details)
- **Log window** — made draggable, repositioned to avoid overlapping the hex map

## Adventure End Card (PR #19)

When an adventure ends (victory, death, timeout, or retreat), a scroll-themed overlay displays results before returning to the zone view.

- **State machine integration:** `AdventureViewState` pushes `AdventureEndCardState` as a modal overlay via `push_state`/`pop_state`. The adventure view remains visible behind the grey background.
- **Stat tracking:** `AdventureView` accumulates stats during the run (`_combats_fought`, `_gold_earned`, `_loot_items`, `_adventure_start_time`) and builds `AdventureResultData` in `stop_adventure()`.
- **Victory detection:** `AdventureTilemap` emits `boss_defeated` signal → `AdventureView` sets `_pending_victory` flag before `stop_adventure()` is called.
- **Loot tracking:** `InventoryManager.item_awarded` signal connected during adventure, items collected into `_loot_items`.
- **Animation:** Single `scroll_animation` played backwards to open (unroll) and forwards to close (roll up).
- **Loot display:** Uses reusable `ItemDisplaySlot` components (in `scenes/common/`) with hover tooltips via shared `ItemDescriptionPanel`.
- **Theme variants:** Title, DefeatReason, StatName, StatValue, Section, Muted labels; ButtonEndCard; PanelLootTray — all in `pixel_theme.tres`.

## Encounter Flow

```
1. Tile hovered → show HexHoverSelector ring + PathPreview line (hover preview, full opacity)
2. Tile clicked → commit destination:
   a. HexagonTileMapLayer.tile_clicked(coord)
   b. Pathfind from current to target → cube_pathfind via addon
   c. Set _committed_destination, freeze hover selector + path preview
   d. Seed static PathPreview line with full route
3. Move character step by step (5 stamina per step, speed scales with queue length)
   - Per frame: gradient fade slides to hide the path section behind the player
   - Hover events blocked while committed — selector and path locked to destination
4. On arrival at each intermediate tile:
   - _check_committed_arrival() — no-op for intermediate tiles
   - NoOpEncounter → auto-continue to next tile in queue
   - Unvisited encounter with choices → lock movement, release committed destination,
     show EncounterInfoPanel (fade in), clear path preview
5. Player selects choice:
   - CombatChoice → emit start_combat, switch to combat view
   - DialogueChoice → start Dialogic timeline, complete on end
   - Base choice → apply success_effects, complete tile
6. Tile completed → gray overlay + dimmed icon + checkmark, unlock movement
7. On arrival at committed destination:
   - _check_committed_arrival() → release committed state, clear path
   - Encounter panel shows if tile has encounter; otherwise player is free to click again
```

## Fog-of-War (PR #23)

The adventure map uses a multi-layer fog-of-war system:

**Shader fog** — A full-screen `ColorRect` on `FogLayer` (CanvasLayer=4) runs `fog_of_war.gdshader`. The shader maintains a fixed-size array of up to 64 clear positions (screen-space) with soft-edged circles. `_update_fog_uniforms()` runs every frame to convert visited + highlighted tile world positions to screen coordinates, accounting for camera pan/zoom. The clear radius is `FOG_CLEAR_WORLD_RADIUS * camera.zoom.x` so cleared world area stays constant across zoom levels.

**FogVeilSprite** — Revealed-but-unvisited neighbor tiles get a swirling smoke overlay (`FogVeilSprite` in `FogVeilContainer`, z=4). Each veil is an animated spritesheet that randomizes its start frame so adjacent veils don't sync. When a tile transitions to visited, the veil fades out over `FOG_VEIL_FADE_OUT_SECONDS` (0.25s) and frees itself.

**Encounter icons** — Visited tiles with encounters get an `EncounterIcon` in `EncounterIconContainer` (z=6). Icons configure per encounter type (combat, elite, boss, rest, treasure, trap). Completed encounters show dimmed icon + checkmark badge. The current tile's encounter renders inside the floating `AdventureMarker` pin instead of as a flat icon. Boss tiles are revealed through fog as an exception (visible while still fogged).

**Stagger reveal** — Newly revealed neighbor tiles animate in with a scale bounce + alpha fade, staggered by 50ms per tile. Boss tile reveals trigger a dramatic sequence: Engine time_scale → 0.25 for 150ms, screen flash, and camera push toward the boss.

`_update_visible_map()` diffs the icon and veil dictionaries rather than clearing them — visited icons persist across frames, and stale veils/icons are despawned individually.

## Timer

`TimerPanel` wraps a `Timer` + `RichTextLabel` showing `"Time Left: MM:SS"`. Timer timeout triggers `ActionManager.stop_action(false)` — treated as failed adventure. If `time_limit_seconds` is 0 in the data, it defaults to 10 seconds.

## Madra Cost System (PR #16)

Adventures now consume Madra from the zone's pool on start.

- **Minimum threshold:** The player must have at least **50% of the zone's Madra pool** remaining to start an adventure. The adventure button is disabled and shows a badge if this threshold is not met.
- **Madra badge:** Adventure buttons in the zone view display the Madra cost alongside the action name.
- **Two-phase start flow:**
  1. `adventure_start_requested` signal fires when the player clicks the adventure button — begins ZoneTransition (drain animation + camera zoom).
  2. `confirm_adventure_start` fires after the transition completes — actually starts the adventure and deducts Madra.
- **`madra_budget` parameter:** The `start_adventure` signal now carries a `madra_budget: float` parameter representing the Madra drawn from the zone pool. This value flows through `AdventureView.start_adventure()` and is accessible during the run.
- **Deficit particle drain (Foundation Beat 2):** On adventure start, the Madra bar drains by exactly the computed `madra_budget` — the particle animation stops at the precise deficit rather than always animating to zero.

## Integration Points

| System | Connection |
|--------|------------|
| Combat | `CombatChoice` triggers combat; result feeds back for loot/gold |
| ActionManager | `start_adventure(madra_budget: float)` / `stop_adventure` signals control lifecycle |
| ResourceManager | Gold awarded on combat victory; zone Madra pool drained on adventure start |
| PlayerManager | VitalsManager tracks health/stamina; stamina regen set on start |
| InventoryManager | Loot tables rolled on encounter success effects; `item_awarded` signal tracked for end card loot |
| DialogueManager | `DialogueChoice` starts timelines |
| ZoneManager | Zone change cancels active adventure |
| MainView state machine | `AdventureEndCardState` pushed as modal overlay on adventure end |

## Existing Content

One adventure exists: **The Shallow Woods** (`shallow_woods.tres`), reached from Spirit Valley once `q_fill_core_completed` is triggered. 300-second time limit, 8 path encounters, uses the `amorphous_spirit` combat encounter pool (`amorphous_spirit_encounter.tres`).

**Special encounter pool:**
- `aura_well_encounter` (PR #36) — Rest + "Mark down the location" choice that fires `aura_well_discovered` and unlocks the Aura Well zone action in Zone 1.
- `refugee_camp_encounter` (PR #41) — gated behind `unlock_conditions = {refugee_camp_map_owned: true, merchant_discovered: false}` (only shows up once the player has the map and hasn't already visited the camp). Approaching fires `merchant_discovered` and unlocks the Merchant zone action stub.

**Encounters in rotation:** combat (amorphous spirit variants), boss, treasure (rolls weapon loot table), rest, trap, plus the special encounters above when eligible.

## Key Files

| File | Purpose |
|------|---------|
| `scenes/adventure/adventure_view/adventure_view.gd` | Top-level controller, view switching, timer, stat tracking |
| `scenes/adventure/adventure_end_card/adventure_end_card.gd` | End card overlay — populates from AdventureResultData, drives scroll animation |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` | Map state, movement, encounter logic, tile/combat counts |
| `scripts/resource_definitions/adventure/adventure_result_data.gd` | End-of-adventure stats bundle |
| `scenes/ui/main_view/states/adventure_end_card_state.gd` | Modal overlay state for end card |
| `scenes/common/item_display_slot/item_display_slot.gd` | Reusable item icon with hover tooltip |
| `scenes/common/item_description_panel/item_description_panel.gd` | Shared item detail panel (inventory + end card) |
| `scenes/adventure/adventure_tilemap/adventure_map_generator.gd` | Procedural hex map generation |
| `scenes/adventure/adventure_tilemap/encounter_info_panel.gd` | Encounter UI display (fade in/out) |
| `scenes/adventure/adventure_tilemap/encounter_choice_button.gd` | Choice button with requirements |
| `scenes/adventure/encounter_icon/encounter_icon.gd` | Per-type glyph renderer with visited/completed states (PR #23) |
| `scenes/adventure/adventure_marker/adventure_marker.gd` | Floating pin above current tile, embeds EncounterIcon (PR #23) |
| `scenes/adventure/fog_veil_sprite.gd` | Animated smoke overlay for revealed-but-unvisited tiles (PR #23) |
| `scenes/adventure/path_preview/path_preview.gd` | Tiled-texture route line with gradient-based fade (PR #23) |
| `scenes/tilemaps/hex_hover_selector.gd` | Animated hex selector ring, shared with zone map (PR #23) |
| `scenes/atmosphere/atmosphere.gd` | Vignette + mist + motes, shared with zone map (PR #23) |
| `scenes/adventure/adventure_view/timer_panel.gd` | Countdown timer |
| `scripts/resource_definitions/adventure/adventure_data.gd` | Map generation parameters |
| `scripts/resource_definitions/adventure/encounters/adventure_encounter.gd` | Encounter base class |
| `scripts/resource_definitions/adventure/choices/combat_choice.gd` | Combat initiator |
| `scripts/resource_definitions/adventure/choices/dialogue_choice.gd` | Dialogue initiator |
| `scenes/tilemaps/hexagon_tile_map_layer.gd` | Project hex extension (click/hover handling) |
| `assets/shaders/fog_of_war.gdshader` | Full-screen fog with per-tile clear zones (PR #23) |

## Work Remaining

### Bugs

No known bugs in the Adventuring system.

### Missing Functionality

- `[MEDIUM]` `experience_multiplier` and `difficulty_modifier` on AdventureActionData are defined but never applied — all adventures have identical difficulty regardless of these values
- `[LOW]` `MOVEMENT_STAMINA_COST` is a constant (5.0) — no per-tile or stat-based variation for movement cost

### Content

- `[HIGH]` Only 1 adventure config exists (`test_adventure_data.tres`) — needs multiple adventures with varied parameters, encounter pools, and difficulty
- `[MEDIUM]` Only 1 enemy type in combat encounters — no variety in what the player fights
- `[MEDIUM]` No Madra Well encounter type — GDD describes this but it doesn't exist
- `[LOW]` `TRAP` encounter type has no unique handling, content, or overlay icon — exists as an enum value but falls through to unknown overlay and has no authored encounters
- `[LOW]` No home/retreat encounter type — player has no way to voluntarily end an adventure early; timer handles the exit case but a map-based retreat option would be better design
- `[LOW]` Run variety — author additional adventure configs per zone with different map sizes, encounter pools, time limits, and gold multipliers to create risk/reward tiers. Systems already support this, just needs content
- `[LOW]` Non-combat encounters need richer content — rest/treasure/trap encounters exist but have minimal authored choices and effects. Rest should offer meaningful stamina/health recovery tradeoffs, treasure should be worth detouring for, traps should create real danger (stamina drain, debuffs before combat)

### UI

- `[HIGH]` No stamina UI feedback when movement is blocked — silent return with a TODO comment (`adventure_tilemap.gd:256`)
- ~~`[MEDIUM]` Player info panel and log overlap the adventure area — lower them to improve visibility of the hex map~~ *(Fixed in PR #15 — draggable log window + repositioned panels)*
- ~~`[LOW]` Timer label ("Time Left: MM:SS") should be repositioned above the encounter choice info panel~~ *(Fixed in PR #15 — moved to top-center with dark floating style)*
- ~~`[MEDIUM]` No adventure results screen — adventure ends with an instant snap back to zone view. Needs a summary modal showing success/failure, gold earned, items found, and encounters cleared~~ *(Fixed in PR #19 — scroll-themed end card with stats, loot, and victory/defeat display)*

### Tech Debt

#### Dead Code
- ~~`[MEDIUM]` Two debug buttons in `adventure_view.tscn` — one with `TODO: Remove this temporary debug button`~~ *(Removed in PR #15)*
- `[LOW]` `num_combats_in_map` declared in `adventure_map_generator.gd:12` but never read or written
- `[LOW]` `enable_ai: bool` debug export still present on `adventure_combat.gd`
- `[LOW]` `cooldown_seconds` and `daily_limit` on `AdventureActionData` — mobile-style pacing gates, not a fit for this game. Remove the fields

#### Code Quality
- `[LOW]` `EffectData.EffectType` enum is unused for dispatch — behavior routes through polymorphic `process()` overrides, making the enum redundant. `ChangeVitalsEffectData` isn't even in the enum and works fine. Consider removing the enum or using it consistently
- `[LOW]` `AdventureView` defaults to visible in the scene — managed by state transitions but can briefly show on startup before state management is ready
