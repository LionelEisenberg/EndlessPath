# Adventuring System

## Overview

Adventuring is a timed exploration run on a procedurally generated hex map. The player spends Madra to enter, walks tile by tile (5 Stamina per step) through fog of war, and resolves encounters through the choice drawers in the chest: fights hand off to the real-time combat view, while rest sites and special tiles apply effects directly. Defeating the boss ends the run as a victory. Losing a fight or running out of time ends it as a defeat. A scroll-themed end card then summarises the run.

The map and the frame around it (vitals cabinet, chest, technique dock) are in the zone view's "Lacquer and brass" look ([STYLE_GUIDE.md](../STYLE_GUIDE.md)). The fight view and the end card still have the older look (see [Work Remaining](#work-remaining)).

Each map comes from `AdventureMapGenerator`, a quota-based generator. Anchor encounters are scattered first, then connected by a minimum spanning tree plus a few extra edges, and filler encounters are dropped onto the connecting path tiles. All placement rules are data on the encounter resources.

One adventure ships today: **The Shallow Woods** in Spirit Valley. It unlocks during Foundation once the Awaken Your Core quest (`q_fill_core`) is complete. The GDD placed adventuring at Iron stage. See [Work Remaining](#work-remaining) for how the build differs from the GDD.

## Player Experience

1. In Spirit Valley, once event `q_fill_core_completed` has fired, the zone chest shows **The Shallow Woods** under Venture, on a normal 72 px card measured against the adventure capacity:
   - Below half the capacity, its detail row is a Madra rod with `<madra> / <threshold>` after it, and a cream `~N s` at the right while a Madra action runs. Clicking shakes the row softly (`MapGlyph.SOFT_SHAKE_KEYFRAMES`, 4 px at most) and logs "Not enough Madra! Need X, have Y"; the running idle action keeps going.
   - At half the capacity or more, a brass frame holds steady around the card, it reads "<minutes> min run · carries <capacity> Madra", and its tag reads ENTER.
2. On click, the zone view locks input and the map's plates hide. Between 8 and 25 Madra pellets fly in 2 px steps from the cultivator cabinet's Madra orb to the character while the budget (`min(capacity, current Madra)`) is spent. The camera then zooms to 3× over 0.5 s and the adventure view opens.
3. A new map is generated (about 25 tiles for Shallow Woods; see [Typical Shallow Woods Map](#typical-shallow-woods-map)). HP and Stamina refill to max, and in-adventure Madra is set to the budget. Stamina regenerates at 1/s. The adventure view keeps the zone view's frame:
   - The vitals cabinet (top left) shows Health and Madra on orbs and Stamina on a rod, each with `current / max`. In a fight, up to three buff sockets sit beside the Health figures.
   - The chest (top right) is titled with the adventure's name. It holds the run clock (`M:SS`, counting down from the time limit. The seconds are cut, not rounded: a 300 s run reads `4:59` through its first second (`5:00` only on its very first frame) and `0:00` through its last. The clock's recess becomes a vermilion seal for the last 30 seconds), the Here tray for the tile the player stands on, the tile's lore and choice drawers, and the Run ledger (the fights fought of the map's fights, gold earned, tiles explored, and the run's loot). Nothing in the frame is cut off: a long name, line or hint wraps, and the tray, the drawers and the chest grow with it.
   - The technique dock (bottom centre) previews the equipped loadout on the map (hover a slot to read the technique and see its cost).
   - The log and the Goals board stay where the zone view puts them: the log at the bottom left, Goals under the cabinet with its cords showing.
4. The player starts on the origin tile:
   - The screen is fog in three tiers, darker the farther a cell lies from the tiles the player sees (the zone map's fog). It reaches well past the map, so the map's shape stays hidden.
   - Adjacent map tiles are revealed as veiled tiles (dark, with a dotted tan rim), each under a carved coin with a tan "?", so their type stays hidden. An empty tile shows the same coin.
   - The boss is the exception: once revealed, its coin (a brass rim with a vermilion inner ring, and its animated skull glyph) shows through the fog.
   - The player's hex wears a heavy brass rim (four px of brass where the zone map's rim has two), and the character stands on it at 2× with the kit's shadow, drawn in front of the coins. The camera keeps the current hex's centre at screen (960, 470) at every zoom. The wheel zooms the map from 1 to 2, and every run opens at 1.
5. Hovering a visited or revealed tile shows a hover rim on it and the route to it as lit dots, hex to hex.
   - Clicking commits to that destination: the rim and dots lock on, and the character walks the A* route one tile at a time in even-pixel steps. Each step costs 5 Stamina, and longer routes move faster.
   - The dots behind the character hide one at a time as it walks.
   - Clicks are ignored while the character is moving.
   - The hover goes when the pointer leaves the map, onto a board or out of the window, and comes back with the pointer: the rim and the dots of a committed walk stay.
   - When a walk ends (it reached its destination, an encounter stopped it, or the Stamina ran out), its rim and dots go, and the hover shows what a fresh move of the pointer onto the cell it rests over would: the camera has followed the character, so that is usually another tile than the one the pointer was on, with the route to it from where the walk ended. Nothing hovers while a choice waits, or when the pointer is off the map or over no tile.
6. Arriving on a new tile marks it visited: its veil lifts into forest art and new neighbours are revealed. The first time the boss is revealed, time slows to 25% for 0.15 s, the boss coin appears and shakes in even-pixel steps, and the view is pushed 45% of the way toward the boss and back (74 px on screen for a boss one hex away, at every zoom). Nothing flashes.
7. Stepping onto an unvisited encounter tile stops the trip:
   - The Here tray names the tile: its glyph, its name, a tag (FIGHT, ELITE, BOSS, REST, TREASURE or TRAP) and one line, such as "Fight · Amorphous Spirit" (no enemy Health). A long name or line wraps and the tray grows. Under it come the encounter's lore, the line that says the encounter holds the player, a divider and one drawer per choice.
   - Each drawer says what its choice does with the choice's authored tooltip ("Draw on the well's aura to restore yourself."). A choice without one shows only its name, centred: that is every fight's drawer today, with its FIGHT tag and no list of techniques or gold. A choice whose requirements fail shows tan text and the LOCKED seal; a completed one shows its completed label in tan. A drawer grows with a long name or tooltip.
   - Movement stays locked until a choice resolves the tile, and a line above the drawers says so: "Choose what to do here before you walk on". A click on the map meanwhile shakes the Here tray softly, turns that line warm red (the Health text colour) for the shake, and logs "Choose what to do here first".
   - The tile's coin rides above its hex, clear of the character's head (64 px up at zoom 1, 88 at zoom 2). A tile with nothing on it reads "Open ground".
8. **Fight** choices switch to the combat view (see [COMBAT.md](../combat/COMBAT.md)); the cabinet, the chest and the dock stay up.
   - A win awards gold and the choice's success effects, then marks the tile complete.
   - A loss ends the adventure.
   - Other choices resolve immediately. For example, the Aura Well's Rest restores HP and Madra, and "Mark down the location" fires an unlock event.
9. A resolved tile's coin turns carved, with its glyph in the kit's locked veil, and the Here tray reads CLEARED with a one-line summary: "Won · 15 gold" for a fight, what the effects say ("+10 Health") for other choices, or "Done". The lore switches to the completed text, the drawers go, and a walk hint ("Click a hex to walk · 5 Stamina a step · 16 steps left") shows. Walking back onto the tile shows the same. Gold, items and events are banked the moment they are earned and are kept even if the run is lost.
10. With less than 5 Stamina, a click starts nothing and says so: the log reads "Too tired to walk · 5 Stamina a step" and the cabinet's Stamina row shakes softly. A route that runs dry partway stops at the tile reached, with the same line and shake, and the hover follows the rule above.
11. The run ends when:
    - the boss is defeated (VICTORY),
    - HP reaches 0 in combat (DEFEAT), or
    - the timer expires (DEFEAT).

    There is no retreat button, by design (see [FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md)).
12. A scroll end card unrolls over a grey background. It shows a VICTORY/DEFEAT title with icons, the defeat reason, six stats (Combat, Gold, Time, Health, Tiles Explored, Madra Spent) and a loot tray. **RETURN** rolls the scroll up and goes back to the zone view, where the camera zoom is restored.

**Controls:** left-click a tile to move, hover to preview the route, left-click choice drawers, and **RETURN** on the end card. The wheel over the map zooms it from 1 to 2; over a board, or during a fight, it does nothing. `AdventureViewState` and `AdventureEndCardState` handle no keyboard input, so hotkeys such as `open_inventory` do nothing during a run. Q/W/E/R work inside combat, where the technique dock reads them (see [COMBAT.md](../combat/COMBAT.md)).

## Architecture

```
AdventureView (Control)                              — adventure_view.gd (instanced in main_game.tscn, visible = false)
├── ZoneViewBackground                               — parallax backdrop (scenes/zones/zone_view_background), LAYER_SCALE 3.5; shows behind fights only, the map's ground covers it
├── TilemapView (Control)
│   └── TilemapSubviewportContainer (SubViewportContainer, 1920×1080)
│       └── SubViewport (transparent_bg, nearest filter)
│           └── AdventureTilemap                     — adventure_tilemap.tscn (tree below)
├── CombatView (Control, hidden)
│   └── CombatSubviewportContainer
│       └── SubViewport (1920×1080)
│           └── AdventureCombat                      — adventure_combat.gd (see COMBAT.md)
├── VitalsPlate (Control, (24, 24), 440×252)         — vitals_plate.gd: Health and Madra orbs, Stamina rod, 3 buff sockets, BuffTooltip
├── AdventureChest (Control, (1456, 24), 440 wide)   — adventure_chest.gd: hugs its visible page
│   ├── ChestFrame → ChestTop, ChestMid (tiled), ChestBottom
│   ├── TitleLabel (LabelLacquerZoneName)            — the adventure's name, wrapping in 312 px (the page stands 44 px lower per extra line)
│   ├── RunClock                                     — run_clock.gd, at (336, 22): recess or seal, hourglass, "M:SS"
│   └── PageSlot → ExpeditionPage                    — expedition_page.gd (extends AdventureChestPage)
│       ├── HereTray                                 — a 9-slice tray, 88 tall at least, that grows: plate "Here", glyph socket, name, tag or BOSS seal, one line
│       └── Flow (VBox)                              — lore, hint row (lock line or walk hint), divider, ChoiceDrawer ×3 (408 wide, 72 tall at least), Run ledger
├── TechniqueDock (Control, (722, 920), 476×136)     — technique_dock.gd: 4 TechniqueSlots, CastTray, TechniqueTooltip (see COMBAT.md)
└── RunTimer (Timer, one shot)                       — the run's time limit; RunClock reads it and its timeout ends the run

AdventureTilemap (Node2D)                            — adventure_tilemap.gd
├── MapGround (CanvasLayer −1) → GroundRect          — the map ground #090E0E
├── AdventureFogMap (HexagonTileMapLayer)            — fog_tileset.tres, tiers 1–3 around the tiles the player sees
├── AdventureFullMap (HexagonTileMapLayer)           — every map tile, transparent variant; hex math for the generator
├── AdventureVisibleMap (HexagonTileMapLayer)        — visited tiles (forest atlas) and revealed tiles (veil atlas); click/hover; A* pathfinding
├── RimLayer (Node2D)
│   ├── CurrentRim (Sprite2D)                        — the heavy brass rim on the player's hex
│   └── HoverRim (Sprite2D)                          — the hover rim
├── AdventureRoute (Node2D)                          — adventure_route.gd
├── CharacterBody2D (scale 2, z 100)                 — character_body_2d.gd (8-direction walk, whole-px steps of 2)
│   ├── CharacterShadow (Sprite2D, z 99)             — map/lacquer_char_shadow_ai.png
│   └── Camera2D                                     — zoom 1 to 2 (opens at 1), offset (0, 70) / zoom: the current hex's centre at screen (960, 470)
│       ├── CameraZoomController                     — zoom_min 1, zoom_max 2, zoom_default 1: the wheel
│       └── CameraClampController                    — use_boundaries = false (no-op here)
└── AdventureMapMarkers (Node2D, z 50)               — adventure_map_markers.gd: an EncounterCoin per seen tile that needs one, under the character

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
| `EncounterCoin` (`scenes/adventure/adventure_map_markers/encounter_coin/`) | `Control`, 54×54, mouse ignored | One coin: a frame of `lacquer_marker_tokens_ai.png` (a 52 px coin and its 2 px shadow) with the glyph at 32×32 at (10, 10). `Face` is the token frame: GLYPH 0, UNKNOWN 1, CLEARED 2, BOSS 3. Statics decide what a tile gets (`needs_coin()`, `face_for()`, `glyph_for()`, `glyph_frame_size_for()`, `glyph_frames_for()`, `frame_seconds_for()`) and `setup()` applies it. The boss and rest strips step in `_process`. `shake()` moves the token and the glyph together on `MapGlyph.shake_offset_at()`. |
| `AdventureMapMarkers` (`scenes/adventure/adventure_map_markers/`) | `Node2D`, z index 50 | The coin layer. It is a node of the map's own canvas, not a `CanvasLayer`, so the character (z 100) draws over the coins; it stands in screen space all the same, like `MapMarkers`, by setting its `global_transform` to the inverse of the camera's canvas transform in every placement pass. `@export var map: AdventureTilemap`; `rebuild()`, `get_coin(coord)`, `get_coin_count()`, the static `rise_for(zoom, on_the_players_hex)`. It instances one `EncounterCoin` scene per coin, the only scene the adventure instances from code (the count depends on the generated map). |
| `CameraZoomController` (`scenes/camera/camera_zoom_controller/`) | `Node` | The wheel zoom, shared with the zone map; here `zoom_min` 1, `zoom_max` 2, `zoom_default` 1, 10% a tick, eased. `zoom_applied(zoom)` fires after every eased step and the final snap with the zoom the camera has now (`zoom_changed` only carries the target); `AdventureTilemap` follows it to keep its camera offset and hover right. |
| `AdventureRoute` (`scenes/adventure/adventure_route/`) | `Node2D` | The route's lit dots (`map/lacquer_route_dot_lit_ai.png`), six per hop through `ZoneRoute.dot_positions()`. `set_route(centres)`, `clear()`, `hide_passed(character_position)` (the first hop's passed dots hide one at a time), `get_dot_positions()`, `get_visible_dot_count()`. |
| `EncounterIcon` (`scenes/adventure/encounter_icon/`) | `@tool` Node2D | `Dimmable/Glyph` sprite plus a `Checkmark` badge at (20, 20). Every glyph is scaled to 84 px. Boss (7 frames, 1.4 s cycle) and rest (5 frames, 2.0 s cycle) glyphs are looping spritesheets. `set_completed(true)` sets Dimmable alpha to 0.90 and shows the checkmark. The map no longer uses it (coins replaced it); the editor map preview and `test_encounter_icon_config.gd` still do. |
| `VitalsPlate`, `AdventureChest`, `AdventureChestPage`, `ExpeditionPage`, `ChoiceDrawer`, `RunClock`, `BuffTooltip` | `Control`s | The boards of the adventure's frame; see [The Frame](#the-frame-cabinet-chest-and-dock). |
| `TechniqueDock`, `TechniqueSlot`, `CastTray`, `TechniqueTooltip` | `Control`s | The technique bar; see [COMBAT.md](../combat/COMBAT.md#technique-dock). |
| `HexagonTileMapLayer` (`scenes/tilemaps/hexagon_tile_map_layer.gd`) | Extends the addon's layer | Emits `tile_clicked(Vector2i)`, `tile_hovered(Vector2i)` and `tile_unhovered()` from `_input`, but only for painted cells. Also provides `cube_pathfind()` (A* id path → cube coords) and `set_cell_with_source_and_variant()`. |
| `HexForestAtlas` (`scripts/utils/hex_forest_atlas.gd`) | Static helper | `pick(cube)` returns `posmod(hash(cube), 23)` mapped to a 6-column atlas cell, so each tile always shows the same forest variant. The veil atlas keeps the forest atlas's layout, so the same cell works on both. |
| `Atmosphere` (`scenes/atmosphere/`) | CanvasLayer 5 | Vignette, three drifting mist sprites and two mote emitters. It is tuned per instance. The map no longer has one; adventure combat still creates its own copy in code, until the fight is reworked. |

### Tilemap Layers and Tileset

`AdventureFullMap` and `AdventureVisibleMap` share `scenes/tilemaps/tilemap_tileset.tres` (164×190 hex tiles). The fog layer has `scenes/tilemaps/fog_tileset.tres`, the zone map's.

| Layer | Source / variant | Purpose |
|-------|------------------|---------|
| `AdventureFogMap` | `fog_tileset.tres` sources 1–3 (the tiers), atlas cell `ZoneMapMath.fog_art_index(cell)` | Fog on every cell near the map that the player doesn't see. Drawn under the other layers. |
| `AdventureFullMap` | source 0 `base_tile`, alt 4 (alpha 0) | Holds every generated tile; the generator uses it for `cube_distance` and `cube_linedraw`. |
| `AdventureVisibleMap` | source 8 `forest_atlas` (visited tiles, and every tile under the dev override) or source 9 `forest_veil_atlas` (revealed tiles), cell from `HexForestAtlas.pick()` | Paints the tiles the player sees. It is the click/hover target and the A* graph, so routes can only use painted tiles. |

Source 0's alt 5 (the old grey overlay for resolved tiles) is unused now, since a resolved tile is marked by its carved coin. It stays in the shared tileset.

### Encounter Glyphs

`encounter_glyphs/` below is `assets/sprites/adventure/encounter_glyphs/`. `EncounterCoin.glyph_for(type, cleared)` picks the glyph for a coin and for the Here tray (the same art `EncounterIcon` uses). A coin shows it at 32×32, so a 64 px frame is halved and the trap's 32 px frame shows at file size.

| Encounter type | Glyph | Cleared (the kit's locked veil, lighter steps) | Notes |
|----------------|-------|------------------------------------------------|-------|
| `COMBAT_REGULAR`, `COMBAT_AMBUSH` | `assets/sprites/ui/stat_icons/combat_icon.png` | `encounter_glyphs/adv_glyph_combat_spent_light_ai.png` | Ambush looks the same as regular combat. |
| `COMBAT_ELITE` | `encounter_glyphs/elite.png` | `adv_glyph_elite_spent_light_ai.png` | |
| `COMBAT_BOSS` | `encounter_glyphs/boss_spritesheet.png` | `adv_glyph_boss_spent_light_ai.png` | 448×64 strip, 7 frames (0.2 s each). Off the 2x grid at 32, so halving it drops some detail; it stands in until an `_ai` redraw. |
| `REST_SITE` | `encounter_glyphs/rest-sheet.png` | `adv_glyph_rest_spent_light_ai.png` | 320×64 strip, 5 frames (0.4 s each) |
| `TREASURE` | `encounter_glyphs/treasure.png` | `adv_glyph_treasure_spent_light_ai.png` | |
| `TRAP` | `encounter_glyphs/trap.png` | `adv_glyph_trap_spent_light_ai.png` | 32×32 native art. No shipped adventure uses it |
| `NONE` | none | none | `glyph_for()` returns null. (`EncounterIcon.configure_for_type()` returns false and hides the icon.) |

`EncounterIcon` also falls back to `encounter_glyphs/question_mark.png` for an unknown value. The coin has no such fallback: its "?" is the carved token's own face.

## Data Model

### AdventureActionData (`extends ZoneActionData`)

This is the zone action that launches an adventure. It inherits `action_id`, `action_name`, `description`, `unlock_conditions`, `max_completions`, `success_effects` and `failure_effects` (see [ZONES.md](../zones/ZONES.md)).

| Field | Type | Default | Used by |
|-------|------|---------|---------|
| `adventure_data` | `AdventureData` | — | `AdventureTilemap.start_adventure()` |
| `experience_multiplier` | `float` | 1.0 | **Unused** |
| `gold_multiplier` | `float` | 1.0 | `AdventureCombat.gold_reward_for()` (so the gold a won fight pays; the fight drawer no longer shows the figure) |
| `difficulty_modifier` | `float` | 1.0 | **Unused** |
| `completion_time_modifier` | `float` | 1.0 | **Unused** |
| `time_limit_seconds` | `int` | 10 | `AdventureView.start_adventure()` (values ≤ 0 fall back to 10) |
| `stamina_regen_modifier` | `float` | 1.0 | `AdventureView`, when it sets the run's Stamina regen → `stamina_regen = 1.0 × modifier` |
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
| `encounter_name` | `String` | "" | The Here tray's name |
| `description` | `String` (multiline) | "" | Lore under the Here tray before resolution |
| `text_description_completed` | `String` (multiline) | "" | Lore after resolution; falls back to "Encounter completed." |
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
| `label` | `String` | Drawer title |
| `tooltip` | `String` (multiline) | The drawer's detail line. A choice without one has no detail line (a fight's drawer shows only its name and tag) |
| `requirements` | `Dictionary[UnlockConditionData, bool]` | `evaluate_requirements()` is true when every entry matches. Otherwise the drawer is locked (tan title, the LOCKED seal, no press). |
| `success_effects` / `failure_effects` | `Array[EffectData]` | Failure effects only run after a lost `CombatChoice` fight. The `describe()` of each success effect also forms the tile's summary line. |
| `completed_label` | `String` | Shown in tan instead of `label` when `is_completed()` is true and this is non-empty. |
| `completion_condition` | `UnlockConditionData` | When set and true, `is_completed()` returns true and the drawer takes no press. This is separate from eligibility. |

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

This is a plain `Resource` with no exports. `AdventureView` builds it inside `stop_adventure()`.

| Field | Type | Source |
|-------|------|--------|
| `is_victory` | `bool` | `_pending_victory`, set by `AdventureTilemap.boss_defeated` |
| `defeat_reason` | `String` | "Your health reached zero", "Time ran out" or "You retreated from the adventure" |
| `combats_fought` | `int` | Incremented each time `AdventureView` ends a fight |
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
    → runs the adventure action
    → adventure_start_requested(action)
        ├→ ZoneViewState: add full-rect input blocker
        ├→ MapMarkers: hide until the zone view returns
        └→ ZoneTransition
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
           VitalsPlate.setup_vitals(vitals); TechniqueDock.show_loadout()
           stamina_regen = 1.0 × stamina_regen_modifier
           AdventureChest.set_title(action_name)
           RunTimer.start(time_limit_seconds); RunClock.bind_timer(RunTimer)
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
1. **Scatter anchors.**
   - For each eligible `ANCHOR` quota, it places `count` instances.
   - Candidate coordinates are random with `q, r ∈ [-max, max]`. A candidate is rejected if it is farther than `max_distance_from_start`, closer than the encounter's `min_distance_from_origin`, or violates `sparse_factor` (too close to the origin or to any placed tile).
   - Each instance gets up to 100 attempts, then is skipped with a warning.
   - The boss comes last: from 100 random samples, the farthest valid one wins. If none is valid, the boss is skipped with a warning.
2. **Connect.**
   - Prim's MST over the origin plus all anchors, by `cube_distance`.
   - Then the `num_extra_edges` shortest non-MST pairs, which can include the origin.
   - Every edge is stamped with `cube_linedraw`; any empty coordinate on the line becomes a `NoOpEncounter`.
3. **Place fillers.** For each eligible `FILLER` quota, it picks random NoOp tiles (never the origin). If NoOps run out, it stops early with a warning.
4. **Critical-path check.**
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

- **`AdventureTilemap.start_adventure()`** generates the map and calls `start_adventure_on_map(action, encounters)`, which tests also call with a fixture map. That plays on a copy of the dictionary, drops any fight or talk left in flight, paints every generated tile on `AdventureFullMap` with the transparent variant and visits the origin (`Vector3i.ZERO`).
- **Marking a tile visited:**
  - adds the tile to `_visited_tile_dictionary`;
  - rebuilds `_highlight_tile_dictionary` from map tiles adjacent to any visited tile (`HighlightType.VISIBLE_NEIGHBOUR`);
  - repaints the map (below), then checks the tiles that just came into view for the boss (see Boss reveal).
- **The repaint** redraws the layers, then announces `map_changed`:
  - Visited tiles take their forest atlas cell (source 8). Revealed tiles take the same cell from the veil atlas (source 9, `hex_forest_veil_atlas_ai.png`: the 23 variants in the kit's uncharted-veil colours, with the dotted tan rim baked in). Under the dev override every tile takes the forest cell.
  - The fog pass clears `AdventureFogMap` and fills every cell within `max_distance_from_start + FOG_MARGIN` (8) of the origin that the player doesn't see (`get_seen_tiles()`). The tier is `ZoneMapMath.fog_tier()` (hex distance to the nearest seen tile, capped at 3) and the art `ZoneMapMath.fog_art_index()`, as `ZoneTilemap` fills its fog. Unrevealed map tiles look like any other fog, so the map's shape stays hidden. Stopping leaves the layer empty.
  - `CurrentRim` moves onto the current tile.
- **Coins.** `AdventureMapMarkers`, a `Node2D` child of the tilemap at z index 50 (under the character at 100, over the tiles, rims, fog and route at 0) that stands in screen space, redraws on `map_changed` and `encounter_resolved`. It keeps an `EncounterCoin` on every seen tile that `EncounterCoin.needs_coin()` wants, in the face `face_for()` gives:

  | Tile | Face (token frame) | Glyph |
  |------|--------------------|-------|
  | Revealed (an empty tile too) | UNKNOWN (1): carved, a tan "?" | none |
  | Revealed boss | BOSS (3): brass rim, vermilion inner ring | the boss strip, 7 frames at 0.2 s |
  | Visited, not resolved | GLYPH (0): brass rim over lacquer | the encounter's glyph (the rest strip: 5 frames at 0.4 s) |
  | Visited, resolved | CLEARED (2): carved | the glyph in the kit's locked veil (`adv_glyph_<kind>_spent_light_ai.png`) |
  | Visited NoOp | no coin | |

  At zoom 1 a coin's centre sits 8 px above its hex's centre, and 64 px above on the hex the player stands on, clear of the character's head (`COIN_RISE`, `COIN_RISE_HERE`: 26 for the disc's half height, 24 for the head of the character in its wuxia robes, 14 clear). `rise_for(zoom, on_the_players_hex)` scales them with the zoom (8 × zoom, and 26 + 24 × zoom + 14: 16 and 88 px at zoom 2), and the coins keep their size. Each placement pass first sets the layer's transform to the inverse of the camera's, so the coins draw in the viewport's own px. It runs every frame and again just before the frame is drawn (`RenderingServer.frame_pre_draw`), so the coins never trail the boss push or a zoom, and they show and go outright. No coin takes the pointer: a hover, a press and the wheel go through it to the hex. A redraw keeps the coins still wanted, so a shake or an animated glyph is never cut off. Under the dev override every unvisited encounter tile shows its glyph coin (the boss its boss coin) and NoOp tiles none.
- **Boss reveal** (once per run, after the redraw): `boss_revealed(coord)` makes the boss coin shake on `MapGlyph.SHAKE_KEYFRAMES`, and `AdventureTilemap` runs
  - `Engine.time_scale = 0.25 * GameSpeed.base_scale` for 0.15 s of real time, then back to `GameSpeed.base_scale` (1 unless a dev time speed is set);
  - the camera push: a tween of `_camera_push` to 45% of the way toward the boss (0.5 s, cubic) and back to zero (0.7 s). `_camera_push` is in screen px, and the tilemap sets `Camera2D.offset` to `camera_offset_for(zoom) + _camera_push / zoom`, so the view moves 74 px for a boss one hex away at every zoom (twice that at zoom 2 if the push were in world px), and a zoom that starts or eases meanwhile neither cancels the push nor is undone by it. The offset moves, not the camera's position, so the camera stays on the character if the walk goes on. `stop_adventure()` ends the push at once.
- **Camera and zoom.** The camera follows the character with `camera_offset_for(zoom)` = `CAMERA_OFFSET` (0, 70) / zoom, which keeps the current hex's centre at screen (960, 470) at every zoom. A `CameraZoomController` on the camera takes the wheel (1 to 2, 10% a tick, eased). `AdventureTilemap` follows the controller's `zoom_applied`, so the offset changes in the same frame as each eased step, and lays the hover again while a run is on, because the wheel leaves the pointer still over moving hexes. `start_adventure_on_map()` puts the camera back at the controller's default zoom, so a run opens at 1 whatever zoom the last one ended at. A wheel over a board does nothing (the boards are `MOUSE_FILTER_STOP`, and the map hears the pointer only through its container), and neither does one during a fight (the map is hidden). The fog reaches `max_distance_from_start + FOG_MARGIN` cells, sized for zoom 1, the widest view, so it covers the screen at every zoom; a `zoom_min` below 1 would need a bigger margin. `CameraClampController` stays, inert.

### Movement, Stamina and the Committed Path

```
tile_hovered(coord) — ignored while a destination is committed
  movement locked, the current tile, or a tile the player doesn't see → hide the hover rim, clear the route
  else → HoverRim on the tile (the bright rim over a visited tile, the inner rim over a revealed one);
         AdventureRoute.set_route(cube_pathfind(current, target))

the map's SubViewportContainer: mouse_exited (the pointer went onto a board, or out of the window)
  — the map's viewport hears nothing from a board, so the hex layer cannot report it —
  hover rim hidden and route cleared, unless a destination is committed (its rim and route stay);
  the hex layer forgets its last cell, so coming back onto it hovers it again
  mouse_entered → the pointer is on the map again

tile_clicked(coord)
  movement locked → log "Choose what to do here first"; walk_refused(&"encounter")
  queue non-empty or character moving → ignore, silently
  stamina < MOVEMENT_STAMINA_COST (5) → log "Too tired to walk · 5 Stamina a step"; walk_refused(&"stamina")
  _visitation_queue = cube_pathfind(current, target)[1:]
  commit: _committed_destination = target; HoverRim on the target; route laid along the whole walk
  start the next hop

each hop
  stamina ≥ 5 → spend 5, pop next tile, move_to_position(tile, 150 × (1 + 0.2 × (remaining + 1)) px/s)
  stamina < 5 → clear queue, release commitment, same log line, walk_refused(&"stamina")

_process() each frame → AdventureRoute.hide_passed(character position) while committed

movement_completed → visit the tile
  first visit → mark it visited; revisit → repaint the map only
  arrival at destination → release commitment (route cleared); part-way → route laid again from the tile reached
  tile_entered(coord, encounter, first_visit, summary) — every arrival, once the tile counts as visited
  NoOp / no choices → continue the queue
  encounter → unvisited: lock movement, clear queue, release commitment (trip hijacked)
              revisited: queue continues (the Here tray shows the tile's summary)
  hop handled and the character is not walking on (destination reached, trip hijacked, Stamina out)
    → lay the hover again: the hover as a fresh pointer move onto the pointer's cell would give it —
      HoverRim on that tile and the route to it from the tile reached; nothing while movement is locked,
      if the pointer is off the map or over no tile. A hop that walks on, the run's start and a stop's
      teardown lay no hover.

CameraZoomController.zoom_applied (every eased step of a wheel zoom)
  → set the camera offset again; while a run is on, lay the hover again — the zoom moved the hexes under a still pointer
```

Routes come from A* over `AdventureVisibleMap`. They can pass through revealed but unvisited tiles, and an unvisited encounter on the route stops the trip there. The character is drawn at scale 2 with the kit's shadow, in front of the coins, and walks in whole-pixel steps on the 2 px grid (`snap_walk_to_whole_px`, `walk_snap_px = 2.0`). Every refusal writes the log line and emits `walk_refused(reason)`; `AdventureView` turns it into a shake (see [The Frame](#the-frame-cabinet-chest-and-dock)). `stop_adventure()` ends the run first (it clears `current_adventure_action_data`), then clears the queue and releases the destination before it stops the character. A hop in flight cannot restart during the teardown, and the hop it cuts short arrives nowhere: `AdventureTilemap` ignores a hop that ends with no run on, so the teardown visits no tile, reveals no boss (no hit-stop, no coin shake), announces no arrival, and tells the boards only of the redraw that clears the map.

### Resolving Encounters and Combat Hand-off

```
ExpeditionPage.choice_selected(choice)
  → AdventureTilemap.select_choice(choice)       — ignored while a fight or talk is under way, or once the tile is resolved
  CombatChoice   → AdventureTilemap.start_combat(choice)
                   → AdventureView: combat.initialize_combat(choice, action);
                     combat.start(); TechniqueDock.bind(); VitalsPlate.bind_buffs(); hide tilemap view, fade in combat view;
                     log "Encounter: <label>"
  DialogueChoice → DialogueManager.start_timeline(); dialogue_ended → success_effects → complete the tile (summary)
  EncounterChoice→ success_effects → complete the tile (summary_for(choice, 0))

AdventureCombat.trigger_combat_end(is_successful, gold)
  → AdventureView: combats_fought += 1; gold tally; run_stats_changed;
                   dock and cabinet let go (TechniqueDock.reset(), VitalsPlate.unbind_buffs());
                   show tilemap view; is_in_combat = false; combat.stop()
    → AdventureTilemap.handle_combat_result(successful, gold)
        win:  ResourceManager.add_gold(gold); apply success_effects
              is_boss → boss_defeated → _pending_victory; ActionManager.stop_action(true)
              else    → complete the tile (summary_for(choice, gold))
        loss: apply failure_effects
    → loss → ActionManager.stop_action(false)
```

- **Ending the fight first:** when a fight ends, `AdventureView` clears `is_in_combat` before it hands the result to the tilemap. A boss win ends the whole adventure synchronously inside `handle_combat_result()`, and `stop_adventure()` only force-ends a fight that is still running, so the win is handled once. The tilemap also lets go of a fight's choice once its win is handled (the boss's before the win ends the run), so when `AdventureCombat` reports a win again, as it does for every write to its enemy's Health at 0, the repeat finds no fight pending and runs no effects or boss win a second time. A repeat that arrives after the run is over resolves no tile on the cleared map.
- **Gold:** the static `AdventureCombat.gold_reward_for(choice, action)` gives `floor(base_gold_drop × CombatChoice.gold_multiplier × AdventureActionData.gold_multiplier × CharacterManager.get_gold_multiplier())` for the first enemy of the pool (0 for an empty pool; the action's multiplier counts 1 with no action). The last multiplier is a stub that returns 1.0. `AdventureCombat` pays it for a won fight and writes the log line. The fight drawer used to show the same figure as "<gold> gold if you win" and no longer does, so the function serves the log line today and will serve the opponent page's reward row (PR 2).
- **`q_first_steps_enemy_defeated`:** every combat win fires this event (deduplicated by `EventManager`).
- **Completing a tile** (with its summary): `AdventureTilemap` unlocks movement, stores the summary for the tile, adds the tile to `_completed_encounter_tiles` (its coin turns carved), re-renders (`map_changed`) and emits `encounter_resolved(coord, summary)`.
- **`summary_for(choice, gold)`** (static): a `CombatChoice` reads "Won · <gold> gold", or "Won" when it paid nothing. Any other choice joins the `describe()` of its success effects with " · ", leaving out an effect whose text is empty or only its debug string, and reads "Done" when nothing is left. A dialogue passes its choice's summary once `dialogue_ended` fires.
- **The pick guard:** `select_choice()` ignores a pick (with a `Log.info`) while `_current_combat_choice` or `_current_dialogue_choice` is set, or once the current tile is resolved: the chest stays up through a fight, so a second press on a drawer must not start a second one. `start_adventure_on_map()` clears both, so a new run never starts with a fight or a talk under way, whatever the last one ended in.

### The Frame: Cabinet, Chest and Dock

`AdventureView` holds three boards that stand where the zone view keeps its cabinet, chest and dock, and passes them the map's news. They come after `CombatView` in the scene and keep their roots' `mouse_filter` STOP: the map lives in a `SubViewport` that hears the pointer only through its container, so a press on a board never reaches the hexes under it.

| Signal | Emitted by | Effect |
|--------|------------|--------|
| `tile_entered(coord, encounter, first_visit, summary)` | `AdventureTilemap` | `AdventureView` calls `ExpeditionPage.show_tile(encounter, summary, action)` |
| `encounter_resolved(coord, summary)` | `AdventureTilemap` | `show_resolved(summary)` when `coord` is the current tile; the coin turns carved |
| `map_changed` | `AdventureTilemap` | `AdventureMapMarkers` redraws; `AdventureView` announces `run_stats_changed` |
| `walk_refused(reason)` | `AdventureTilemap` | `&"stamina"` shakes the cabinet's Stamina row (`VitalsPlate.shake_stamina()`); `&"encounter"` shakes the Here tray (`ExpeditionPage.shake_here()`) |
| `boss_revealed(coord)` | `AdventureTilemap` | `AdventureMapMarkers` shakes the boss coin |
| `choice_selected(choice)` | `ExpeditionPage` | `AdventureTilemap.select_choice(choice)` |
| `run_stats_changed` | `AdventureView` | `ExpeditionPage.set_run_stats(...)`. Fires after `map_changed`, a fight's end and an item award, while a run is on |
| `ability_selected(instance)` | `TechniqueDock` | `AdventureCombat.on_player_ability_selected`, connected for each fight (see [COMBAT.md](../combat/COMBAT.md)) |

- **Vitals cabinet** (`VitalsPlate`, at (24, 24), 440×252, `lacquer_cult_ai.png`). The Health and Madra orbs are the kit's orb frame under `lacquer_madra_orb.gdshader` (Health sets the crimson ramp `#FFD9D2 #E8737A #B8304A` on its own material, Madra keeps the shader's Madra colours), each with `current / max` beside it; Health shows `ceili(current)`, the others `floori(current)`. The Stamina row is a mini bolt, a `LacquerRod` (119 steps) and `current / max`. `setup_vitals(vitals_manager)` runs at every run's start and follows the three vitals signals. `bind_buffs(buff_manager)` and `unbind_buffs()` bracket a fight: up to three buff sockets (at (294, 52), (338, 52), (382, 52)) fill from the left, each with the buff's icon, a count seal while it stacks and a brass flash when it lands. Hovering one opens a `BuffTooltip` at the cabinet's right: the name, whole seconds left, stacks and `BuffEffectData.describe()`, on a board 304 wide whose height is rounded up to an even number, so its bottom edge stays on the 2 px grid. The plate hides the tooltip when its buff ends.
- **Chest** (`AdventureChest`, at (1456, 24), 440 wide). The zone chest's frame (a 128 px top, a tiled middle, a 48 px bottom), the title (the adventure's name in `LabelLacquerZoneName`, wrapping in 312 px; each extra line, 44 px, stands the page slot lower), the run clock and a page slot (408 wide at chest-local (16, 82) plus the title's extra lines) holding the visible `AdventureChestPage`. The chest is `max(176, 82 + the title's extra lines + the page's content height + 24)` tall, rounded to an even number, and lays itself out again when the page emits `content_resized` or is shown or hidden. The expedition page is the only page today.
- **Run clock** (`RunClock`, 88×36 at chest-local (336, 22)). `M:SS` from the run's Timer (`format_time()` cuts to whole seconds). `bind_timer()` paints it at once, so a new run's first frame never shows the last one's end (after a timeout, `0:00` on the seal); then it is read every frame while the Timer runs. At 30 s or less the carved recess becomes the vermilion seal, with the same cream text; nothing flashes. A stopped Timer leaves the last time showing.
- **Expedition page** (`ExpeditionPage`). The Here tray names the tile, and a flow under it holds the lore, the walk hint, a divider, the choice drawers and the Run ledger:

  | Standing on | Name | Tag | Line |
  |-------------|------|-----|------|
  | An unresolved fight | its `encounter_name` | FIGHT (regular, ambush), ELITE, or BOSS (a vermilion seal) | `<Kind> · <enemy>`, e.g. "Fight · Amorphous Spirit" |
  | Another unresolved encounter | its `encounter_name` | REST, TREASURE or TRAP | its kind word |
  | A resolved encounter | its `encounter_name` | CLEARED | the tile's summary |
  | A NoOp tile, or an encounter with no choices | "Open ground" (tan) | none | "Click a hex to walk · 5 Stamina a step" |

  - The glyph is the encounter's own, frame 0 (`EncounterCoin.glyph_for()`). The enemy named is the first of the first combat choice's pool, the one `AdventureCombat` fights. The line carries no Health (it may come back as an unlockable, and `VitalsManager.max_health_for()` stays for it).
  - An unresolved tile shows its `description` as lore, the lock line ("Choose what to do here before you walk on"), a divider and one `ChoiceDrawer` per choice (at most three; more are left out with a `Log.warn`). A resolved tile shows `text_description_completed` ("Encounter completed." when empty), the walk hint ("Click a hex to walk · 5 Stamina a step · <n> steps left", from the current Stamina, kept current as it changes) in the lock line's place, and no drawers. Open ground shows neither.
  - A drawer (`ChoiceDrawer`, 408 wide and 72 tall at least, on `lacquer_drawer9_ai.png`, a 9-slice, with the zone card's carved socket as a piece of its own) shows the choice's glyph (the story icon for a `DialogueChoice`), its `label` at x 64, a tag (FIGHT for a `CombatChoice`, TALK for a `DialogueChoice`) at x 320 and a detail line: the choice's `tooltip` and nothing else. A choice without one has no detail line, and its label centres on the face. It is available, locked (`not evaluate_requirements()`: tan title, the LOCKED seal, no press) or completed (`is_completed()`: the `completed_label` in tan, no press). Completed outranks locked, because a choice such as the Aura Well's "Mark down the location" fails its own requirement the moment it is done. Hovering an available drawer frames it; pressing it emits `choice_selected`.
  - The Run ledger shows the fights fought of the map's fights (every fight that ends counts, and a lost one ends the run), gold earned this run, tiles explored of the map's tiles (each with its icon), and a "Loot" row of six sockets with the run's latest item awards, newest last. All six sockets are always there; empty ones are carved recesses.
  - `shake_here()` shakes the Here tray in the soft shake's steps (`MapGlyph.SOFT_SHAKE_KEYFRAMES`, the lock shake at half its travel) and turns the lock line to the warning colour (`ThemeConstants.LACQUER_HEALTH`, `#E8737A`: vermilion is 2.8:1 on the board, under the text floor) until the shake ends.
  - **No text in the page is cut off.** The Here tray's name (250 px wide, 238 beside the BOSS seal) and line (332), the lore (408), the walk hint and lock line (408), and a drawer's label (250, 238 beside the LOCKED seal) and detail (332) wrap by word. The tray is as tall as its text column asks (88 at least, an even height) and the flow stands 16 px under its bottom; a drawer is 72 tall at least and grows by a line (20 px for the label, 18 for the detail, padded 1 px by `wrap_pad.tres`); the Run ledger moves down with them, and the page emits `content_resized` for the chest to hug. The socket, glyph, plate, tag and seal stay at the top. Of the shipped names only "Ravenous Dreadbeast Attacks!" needs a second line in the tray (110 tall); the boss's "Manifested Spirit Encounter" fits beside its seal with about 2 px to spare. The tray and the drawers share their columns (socket at x 8, glyph 16, text 64, the line and the detail to x 396, tag 320, seal 308), the tray's socket being `lacquer_socket_glyph_ai.png` and a drawer's `lacquer_socket_drawer_ai.png`.
- **Technique dock** (`TechniqueDock`, at (722, 920)). On the map it previews the equipped loadout; in a fight it is the player's technique bar, and a refused press shakes the slot's socket softly (`MapGlyph.SOFT_SHAKE_KEYFRAMES`: the lock shake at half its travel, since a slot is pressed again and again; the Here tray and the Stamina row shake by it too). See [COMBAT.md](../combat/COMBAT.md#technique-dock).

### Timer and End Conditions

`RunTimer.timeout` → `AdventureView` → `ActionManager.stop_action(false)`. The timer keeps running during combat. The chest's `RunClock` reads it; at 30 seconds or less the clock's recess becomes the vermilion seal and nothing flashes or ticks. The timer is `one_shot`, so once it fires it reads as stopped, which is how `stop_adventure()` recognises a timeout.

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
2. Builds `AdventureResultData`, disconnects `item_awarded`, clears `current_action_data` (so the teardown below changes none of the run's figures and ends no run again), and calls `AdventureTilemap.stop_adventure()`. That call drops the walk (the queue and the committed destination first, then `stop_moving()`), clears the layers, the fog and the dictionaries, ends the boss push, announces `map_changed` (so the coins go) and resets the character to the origin, so the end card overlays an empty map.
3. Stops the run's timer and sets stamina regen to 0. If still in combat, it ends the fight as a lost one. Then the dock and the cabinet let go of the fight. The Run ledger keeps the run's last figures under the end card.
4. Emits `adventure_completed(result_data)`.

After that:
- On `adventure_completed`, `AdventureViewState` pushes `AdventureEndCardState` and calls `AdventureEndCard.show_results()`. That populates the card, plays `scroll_animation` backwards to unroll it, then sets content alpha to 1.
- **RETURN** plays the animation forwards and emits `return_requested` (connected one-shot). `AdventureViewState` then pops the overlay and changes to `ZoneViewState`, whose `enter()` calls `ZoneTransition.reset_camera()`.

Other ways a run stops: a `ZoneManager.zone_changed` signal stops the current action (successful = true), and `select_action()` stops the current action first. The zone view is hidden and input-blocked during a run, so the player cannot reach either path.

### Dev Hooks

The dev panel's Adventure tab acts on a run through `DevCommands`, which call two `AdventureView` methods, and through one toggle on the view; see [DEV_TOOLS.md](../tooling/DEV_TOOLS.md):
- `force_win_combat()` wins the fight that is on by taking all of the enemy's Health (`apply_vitals_change(-max_health)`), so the fight ends through the real death path: `AdventureCombat` fires `q_first_steps_enemy_defeated` and `trigger_combat_end(true, gold)`, and the map pays the gold and resolves the tile. It does nothing outside a fight, or when the enemy is gone or already down. `DevCommands.force_win_fight()` calls it.
- `force_end_adventure(victory)` ends the run at once as a victory (the boss-win path) or a defeat. `DevCommands.exit_adventure()` calls it.
- `set_show_whole_map(enabled)` → `AdventureTilemap.set_dev_reveal_all()` lifts the fog off every map tile, paints every tile in forest art (no veils) and gives every unvisited encounter tile its glyph coin (the boss its boss coin). Visited and highlight state are untouched, and toggling it off puts the normal coins and fog back.

The editor-only map preview (`scenes/tools/map_preview.tscn`, `scripts/tools/map_preview.gd`) renders `AdventureMapGenerator` output for any `AdventureData`, with an optional seed. It is also documented in [DEV_TOOLS.md](../tooling/DEV_TOOLS.md).

## Integration Points

| System | Connection |
|--------|------------|
| `ActionManager` | `adventure_start_requested(action)`, `confirm_adventure_start(action, budget)` → `start_adventure(action, budget)`, `stop_action(successful)` → `stop_adventure` plus the action's completion effects |
| `ResourceManager` | `get_adventure_madra_capacity/budget/threshold()`, `can_start_adventure()`, `spend_madra()` during the drain, `add_gold()` on combat wins |
| Zones (`ZoneTransition`, `ZoneViewState`, `AdventurePresenter`, `MapMarkers`) | Madra pellet drain and camera zoom, input blocker, the adventure card's Madra line and reject shake, hiding the map markers ([ZONES.md](../zones/ZONES.md)) |
| `MainView` state machine | `AdventureViewState` (`change_state` on `start_adventure`, pushes the end card on `adventure_completed`; the log and Goals boards stay where the zone view puts them); `AdventureEndCardState` (grey background) |
| `PlayerManager.vitals_manager` | `initialize_current_values(budget)`, `stamina_regen`, Stamina deducted per step, `ChangeVitalsEffectData`, HP for end conditions and the end card. `VitalsPlate` follows its three signals, and the Here tray's walk hint follows `stamina_changed` |
| Combat (`AdventureCombat`) | `initialize_combat(choice, action)`, `start()`, `stop()`, `trigger_combat_end(is_successful, gold)`, the static `gold_reward_for()`; `TechniqueDock.bind()` and `VitalsPlate.bind_buffs()` take the player's combatant for a fight ([COMBAT.md](../combat/COMBAT.md)) |
| `InventoryManager` | `item_awarded(item, quantity)` feeds end-card loot; loot effects call `award_items()`; `ITEM_OWNED` conditions call `has_item()` |
| `EventManager` / `UnlockConditionData` | Encounter `unlock_conditions` (at generation), choice `requirements` / `completion_condition` (when a tile's drawers are set up), events fired by choice effects ([UNLOCKS.md](../infrastructure/UNLOCKS.md)) |
| `DialogueManager` | `DialogueChoice` → `start_timeline()` / `dialogue_ended` ([DIALOGUE.md](../infrastructure/DIALOGUE.md)) |
| `ZoneManager` | `zone_changed` stops the current action; zone progression is incremented on every adventure stop |
| `PathManager` | **Not wired:** `adventure_madra_return_pct` (Madra Reclamation) and `stamina_recovery_mult` (Iron Will) are computed but nothing in adventure code reads them |
| `LogManager` | "Adventure Started/Ended", "Encounter: <label>", "Combat Victory!" / "Combat Defeat...", gold gains, and the refused-walk lines "Too tired to walk · 5 Stamina a step" and "Choose what to do here first" |

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
| `aura_well` (`special_encounters/`) | Aura Well | `REST_SITE` | ANCHOR | 3 | 1 | "Rest" → +5 × BODY HP, +2 × FOUNDATION Madra. "Mark down the location" (requires `aura_well_discovered` = false) → same restore plus fires `aura_well_discovered`; once the event has fired the drawer reads "✓ Location noted" in tan and takes no press (see the ✓ item under Work Remaining). | Unlocks the Aura Well training zone action |
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
| Total tiles | median 25–26; p10–p90 is 19–33; max about 44 |
| NoOp walk-through tiles (including origin) | median 11 |
| Combat tiles (including boss) | median 13 (range 8–17) |
| Starving Dreadbeasts | quota 3; above quota in about 72% of maps because of Phase 4 promotions (median 4, max 8) |
| Shortest path to boss | at least 5 steps (median 5) |
| Regeneration | about 25% of maps need two or more attempts; about 0.05–0.1% use all 5 and ship a map that breaks a `min_fillers_on_path` rule. Most failures come from an elite placed next to the origin. |

## Key Files

| File | Purpose |
|------|---------|
| `scenes/adventure/adventure_view/adventure_view.gd` / `.tscn` | Top-level controller: start/stop, tilemap/combat view switching, the run's `Timer`, the wiring of the three boards, stat tracking, result building, dev hooks |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` / `.tscn` | Map state, reveal and fog, movement and Stamina, committed path, encounter resolution, boss reveal, and the signals and getters the boards use |
| `scenes/adventure/adventure_tilemap/adventure_map_generator.gd` | Quota-based 4-phase generator (`@tool`) |
| `scenes/adventure/adventure_map_markers/adventure_map_markers.gd` / `.tscn`, `encounter_coin/encounter_coin.gd` / `.tscn` | The coin layer (screen space) and the coin |
| `scenes/adventure/adventure_route/adventure_route.gd` / `.tscn` | The walk's route dots |
| `scenes/adventure/vitals_plate/vitals_plate.gd` / `.tscn`, `scenes/ui/combat/buff_tooltip/` | The vitals cabinet and its buff tooltip |
| `scenes/adventure/adventure_chest/adventure_chest.gd` / `.tscn`, `adventure_chest_page.gd` | The chest (frame, title, page slot) and the page base class |
| `scenes/adventure/adventure_chest/expedition_page/`, `choice_drawer/` | The Here tray, the tile's lore and drawers, and the Run ledger |
| `scenes/adventure/run_clock/run_clock.gd` / `.tscn` | The run clock |
| `scenes/ui/combat/technique_dock/` | The technique dock: slots, cast tray, tooltip (see [COMBAT.md](../combat/COMBAT.md)) |
| `scenes/adventure/encounter_icon/encounter_icon.gd` / `.tscn` | Per-type glyph, spritesheet animation, completed state. Only the editor map preview uses it now |
| `scenes/adventure/adventure_end_card/adventure_end_card.gd` / `.tscn` | Scroll end card |
| `scenes/adventure/scripts/pack_smoke_spritesheet.py` | Builds `assets/sprites/atmosphere/smoke_veil_spritesheet.png` (unused since the smoke veils went) |
| `scenes/tilemaps/hexagon_tile_map_layer.gd` / `.tscn` | Project hex layer: click/hover signals, `cube_pathfind`, `set_cell_with_source_and_variant` |
| `scenes/tilemaps/tilemap_tileset.tres` | Shared TileSet: source 0 `base_tile` (alt 4 transparent; alt 5, the old grey overlay, is unused), source 8 forest atlas, source 9 forest veil atlas |
| `scenes/tilemaps/fog_tileset.tres` | The fog tiers 1–3, shared with the zone map |
| `scenes/tilemaps/scripts/pack_hex_atlas.py`, `resize_forest_variants.py` | Build `hex_forest_atlas.png` |
| `scripts/utils/hex_forest_atlas.gd` | `HexForestAtlas.pick()` |
| `scripts/utils/zone_map_math.gd`, `scenes/zones/zone_route/zone_route.gd`, `scenes/zones/map_markers/map_glyph/map_glyph.gd` | Shared with the zone map: `fog_tier()` and `fog_art_index()`, `ZoneRoute.dot_positions()`, `MapGlyph.shake_offset_at()` (over the lock shake's `SHAKE_KEYFRAMES` for the boss coin; the technique slots, the Here tray and the Stamina row pass `SOFT_SHAKE_KEYFRAMES`) |
| `scenes/camera/camera_clamp_controller/`, `scenes/camera/camera_zoom_controller/` | The camera clamp (inert on this map) and the wheel zoom (1 to 2 here; `zoom_applied` follows the camera's real zoom) |
| `assets/shaders/lacquer_madra_orb.gdshader`, `lacquer_cooldown_sweep.gdshader` | The cabinet's orbs (Health sets the crimson ramp) and the dock's cooldown sweep |
| `assets/ui/lacquer/`, `assets/ui/lacquer/map/`, `assets/sprites/tilemap/hex_tiles/forest/hex_forest_veil_atlas_ai.png`, `assets/sprites/adventure/encounter_glyphs/adv_glyph_*_spent_light_ai.png` | The new art, made by `docs/superpowers/mockups/adventure-view-lacquer/gen/` (`python build_all.py`, which includes `hex_rim.py`'s heavy current rim, then `python import_adventure_kit.py`; `python kit_chest9.py` stands alone and draws the 9-slice drawer face, its socket and the Now strip's rod) |
| `assets/styleboxes/lacquer/wrap_pad.tres` | The 1 px bottom pad of a wrapped Label (see [UI_STYLING.md](../UI_STYLING.md)) |
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

Tests: `tests/unit/test_adventure_*.gd` and `tests/integration/test_adventure_*.gd`, among others named after what they check; [TESTING.md](../testing/TESTING.md#coverage-gaps) lists what they do not cover.

### Related Design Docs

| Spec / plan | Status |
|-------------|--------|
| [2026-04-10 adventure end card](../superpowers/specs/2026-04-10-adventure-end-card-design.md) | Shipped. The spec's "manual exit" trigger has no UI (no retreat, by design). |
| [2026-04-13 tilemap visual overhaul](../superpowers/specs/2026-04-13-tilemap-visual-overhaul-design.md) | Partial, and superseded for the map by the lacquer rework below. Shipped, then removed: atmosphere on the map, the fog shader, `PathPreview`, the reveal stagger, the boss flash and the hover ring. Kept: `EncounterIcon` (the map preview tool uses it), the boss hit-stop and the camera push. Not built: 5-state `TileStateOverlay` (dropped), boss ornamental ring, treasure sparkle, hidden-until-visited traps, player glow orb, click ring burst, hover scale, `PanelStamina` restyle, gradient background. |
| [2026-04-15 fog-of-war redesign](../superpowers/specs/2026-04-15-fog-of-war-redesign-design.md) | Shipped and iterated, then superseded for the map by the lacquer rework below: the fog shader, smoke veils, grey overlay, map-pin marker and 0.25 s veil fade-out are gone. A tile still counts as completed when it is resolved, not when the player walks away. |
| [2026-04-21 map generation rework](../superpowers/specs/2026-04-21-map-generation-rework-design.md) | Shipped. Shallow Woods was retuned in May (radius 5, sparse 1, 4 extra edges, 4 elite anchors). Not done: a boss with its own stats, the anchor-density warning, logging of skipped ineligible encounters. |
| [2026-04-23 map preview tool](../superpowers/specs/2026-04-23-map-preview-tool-design.md) | Shipped ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md)). |
| [2026-10-22 adventure view in lacquer and brass](../superpowers/specs/2026-10-22-adventure-view-lacquer-design.md) (plans: [PR 1](../superpowers/plans/2026-10-22-adventure-view-lacquer-pr1-map-and-frame.md), [PR 2](../superpowers/plans/2026-10-22-adventure-view-lacquer-pr2-fight.md)) | PR 1 (the map and the frame) merged as PR #58; this doc describes it, and the plan's "As built" section lists the deviations, review round 1 (2026-10-23: wheel zoom, no cut-off text, a leaner chest, a heavier rim, the character over the coins) included. PR 2 (the fight) is not built. |

## Work Remaining

### Bugs

- `[LOW]` **Deaths outside combat are handled inconsistently.**
  - `AdventureCombat`'s handler for the player's Health changes is connected to the persistent player `VitalsManager` in the first `initialize_combat()` and is never disconnected.
  - After a session's first fight, HP reaching 0 outside combat (for example from a future trap effect) emits `trigger_combat_end(false, 0)` and counts as a lost combat.
  - Before the first fight, HP 0 outside combat does not end the run at all.
  - No shipped encounter deals damage outside combat.
- `[LOW]` **An encounter can soft-lock the player.** An unvisited encounter locks movement until a choice resolves it, and there is no built-in "leave" option. If every drawer is locked or completed, the player is stuck until the timer runs out. Every shipped encounter has a drawer that is always available.
- `[LOW]` **Loot ignores quantities.** `AdventureView` adds one entry per `item_awarded` emission and ignores the quantity, and duplicate items are not stacked. The end card and the Run ledger's loot sockets show that list.

### Missing Functionality

- `[HIGH]` **Nothing records a completed adventure.**
  - A boss win only calls `ActionManager.stop_action(true)`. Shallow Woods has no `success_effects` and no event fires on boss defeat.
  - `UnlockConditionData.ConditionType.ADVENTURE_COMPLETED` logs "not yet implemented" and returns false.
  - As a result, no quest, zone or Foundation beat can be gated on clearing an adventure.
- `[HIGH]` **Path perks that target adventures do nothing.**
  - Madra Reclamation (`ADVENTURE_MADRA_RETURN_PCT`, +10% per purchase, up to 5) and Iron Will (`STAMINA_RECOVERY_MULT`, ×1.2) can be bought, and `PathManager` computes their values.
  - But `AdventureView.stop_adventure()` never refunds unspent Madra, and the run's Stamina regen reads only `stamina_regen_modifier`. Players spend path points for no effect.
- `[MEDIUM]` **There are no "seen" or "reached" hooks on encounters.** Effects only run when a choice resolves; nothing fires when a tile is revealed or first entered. [FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md) needs one: Beat 5's `q_first_elite` starts when the elite is first seen.
- `[MEDIUM]` **No difficulty scaling.** `difficulty_modifier` and `experience_multiplier` on `AdventureActionData` are never read, and nothing scales by distance from the origin. Both are needed before Copper-tier adventures.
- `[MEDIUM]` **Fights always use the first enemy.** `AdventureCombat` uses `enemy_pool[0]` (TODO at `adventure_combat.gd:144`), so every encounter authors a single enemy (see [COMBAT.md](../combat/COMBAT.md)).
- `[LOW]` **Movement cost is fixed.** `MOVEMENT_STAMINA_COST` is the constant 5.0 (TODO at `adventure_tilemap.gd:83`), with no terrain or stat scaling.
- `[LOW]` **No seeded generation in-game.** The generator uses the global RNG, so a bad map reported by a player cannot be reproduced. Only the map preview accepts a seed.
- `[LOW]` **Ambush and trap types have no behaviour.** `COMBAT_AMBUSH` and `TRAP` only change the glyph; ambush renders as regular combat.
- `[LOW]` **No fixed-position encounters.** Every anchor position is re-rolled each run, so nothing can be pinned to a coordinate. FOUNDATION_PLAYTHROUGH Beat 5 refers to the elite's "fixed adventure tile".
- `[LOW]` **Generator logging gaps.** `AdventureData.validate()` has no anchor-density warning (the spec's non-fatal check), and Phases 1 and 3 skip ineligible quotas without logging.

### Content

- `[HIGH]` **The boss reuses a regular enemy.** `manifested_spirit_encounter` fights `amorphous_spirit.tres`, the same `CombatantData` as `amorphous_spirit_encounter` (same name, stats and 15 gold). The map-generation spec called for boss-appropriate stats.
- `[HIGH]` **Only one adventure exists.** `shallow_woods` is the only adventure, in the only zone, with no Zone 2 or Copper adventure. Encounter folders are already organised per adventure (`resources/adventure/encounters/<adventure>/`).
- `[MEDIUM]` **No treasure, trap or generic rest encounters.** None appear in any adventure; the three `test_*_encounter.tres` placeholders are unreferenced and incomplete. Run rewards are combat gold plus one 25% necklace drop.
- `[MEDIUM]` **Elite rewards are thin.** Coalescing Spirit gives 0 gold (`coalescing_spirit.tres` has no `base_gold_drop`) and has no success effects. Elite rewards do not yet match Beat 5's "equipment tier bump".
- `[LOW]` **No `DialogueChoice` content.** The flow exists but no encounter uses it.
- `[LOW]` **GDD node types and resources are mostly missing.** The GDD's Madra Well exists only as the Aura Well rest site. There are no Sacred Resources (Remnants, Beast Parts), Manuals/Recipes/Schematics or Fame drops.
- `[LOW]` **Text polish.** The `ravenous_dreadbeast_encounter` description has a typo ("This putrid's dreadbeasts muscles…"), and the boss's Here tray name reads "Manifested Spirit Encounter".

### UI

- `[MEDIUM]` **The fight keeps its old look.** The enemy's floating plate, the painted fighters, the parallax forest behind them, the `Atmosphere` layer and the 0.25 s fade into the fight are unchanged, and the plate's right end runs under the chest. The opponent page, the combat stage, the new fighters and the dither dissolve are PR 2 of the lacquer rework (see [Related Design Docs](#related-design-docs)).
- `[MEDIUM]` **Text is still cut off elsewhere.** The adventure frame, the Goals board and the Now strip wrap and grow, but the log board's five lines (on this screen, at the bottom left), the zone chest's title, the zone cards, the map plates and popovers and the Abilities view still end in an ellipsis. [STYLE_GUIDE.md](../STYLE_GUIDE.md#5-type) (Where text still trims) lists them and the tests that pin them, and `KNOWN_TRIMMERS` in `test_boards_never_trim_text.gd` pins the list of their files.
- `[LOW]` **No enemy Health before a fight.** The Here tray's line used to carry the enemy's Health, and a fight's drawer its techniques and gold; neither does now. Health may come back as an unlockable; `VitalsManager.max_health_for()` and `AdventureCombat.gold_reward_for()` stay, tested.
- `[LOW]` **Two socket textures.** The Here tray's glyph socket is `lacquer_socket_glyph_ai.png`, a drawer's is `lacquer_socket_drawer_ai.png`: the same size in the same column, in two textures.
- `[MEDIUM]` **BM Euljiro has no ✓ glyph.** The Aura Well's `completed_label` is "✓ Location noted". A drawer draws the ✓ through a system-font fallback; on a machine with no font that has U+2713, Godot draws a hex-code box ("2713") instead. Drop the ✓ from `aura_well_encounter.tres`, or draw the tick as a kit glyph beside the label.
- `[LOW]` **Clicks are ignored while walking.** `AdventureTilemap` ignores a click while the queue is non-empty or `is_moving`, so the player cannot change destination mid-route.
- `[LOW]` **The end card has no keyboard dismiss** (`AdventureEndCardState.handle_input()` is empty), and it opens over an already-cleared map rather than the final explored state.

### Tech Debt

#### Dead Code
- `[LOW]` Unused `AdventureActionData` members: `completion_time_modifier`, `cooldown_seconds`, `daily_limit` (mobile-style pacing gates), and `is_valid()`.
- `[LOW]` `AdventureData.adventure_id`, `adventure_name` and `adventure_description` are never read at runtime.
- `[LOW]` `AdventureTilemap.HighlightType` is a one-value enum.
- `[LOW]` The three `test_*_encounter.tres` placeholders (see Content).

#### Code Quality
- `[MEDIUM]` **Hex layers skip the addon's own setup.**
  - `scenes/tilemaps/hexagon_tile_map_layer.gd` overrides `_ready()` without calling `super()`, so the addon's `_ready()` never runs. That `_ready()` is what sets up the cube↔map conversion methods and pathfinding.
  - A layer only gets its conversions when the shared `tilemap_tileset.tres` emits `changed`, which happens once after the tileset first loads. A launch works because its single zone and adventure maps exist at that moment.
  - Any hex layer created later (a second adventure view, a new map scene, a test that builds the view twice, the main scene a dev session switch loads again) fails `cube_to_map()` with "conversion method was not properly set up". After a session switch an adventure therefore draws no map and cannot be walked ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md#work-remaining)). `test_adventure_end_flow.gd` re-emits the tileset's `changed` to work around it.
  - Fix: call `super()` in that `_ready()`, then check both maps in play.
- `[LOW]` `HexagonTileMapLayer.set_cell_with_source_and_variant()` rebuilds the whole A* graph (`pathfinding_generate_points()`) and debug drawing for every cell set. The map's repaint redraws every visible tile on each arrival, so each refresh is O(N²). `AdventureFullMap` also has `pathfinding_enabled = true`, although only the visible map pathfinds. This is negligible at about 25 tiles.
- `[LOW]` Stale `ext_resource` UIDs:
  - `hexagon_tile_map_layer.tscn` references the tileset as `uid://eptmap1q2w3e4`, but `tilemap_tileset.tres` is now `uid://ufqon4iip7nd`.
  - Godot falls back to the text path with a warning.
  - The tileset's `base_tile` source also uses an inline `CompressedTexture2D` pointing into `.godot/imported/` instead of an `ext_resource` to `assets/sprites/tilemap/tile_horizontal.png`.
- `[LOW]` `AdventureTilemap` creates `AdventureMapGenerator` (a `Node`) with `.new()` and never adds it to the tree or frees it, so it leaks one node per view (`test_adventure_end_flow.gd` and `test_adventure_view_frame.gd` free it by hand). It could be a `RefCounted`.
- `[LOW]` "Show Whole Map" is not purely visual: dev-revealed tiles are painted on `AdventureVisibleMap`, so they become clickable and pathable (and a hover shows the route to them).
- `[LOW]` `EffectData.EffectType` is not used for dispatch. The `AwardResource`, `AwardItem`, `AwardLootTable` and `TriggerEvent` effect classes don't set it in `_init()`, so it stays `NONE` unless the `.tres` sets it, and none of the adventure encounter effects do.
- `[LOW]` Open TODOs: where `AdventureTilemap` applies a choice's effects (`# TODO: Pass context if needed`) and where `AdventureView` sets the Stamina regen (`# TODO: ... more complex calculation logic`).

#### Tests
- `[MEDIUM]` `test_min_fillers_on_path_guaranteed` counts NoOp tiles as fillers (they inherit `placement = FILLER`), so it passes even if Phase 4 is broken.
- `[MEDIUM]` **Some scene logic is untested.** There are no tests for:
  - `AdventureView` beyond the frame wiring in `test_adventure_view_frame.gd` and the timeout and boss-win paths in `test_adventure_end_flow.gd` (death, result building);
  - `AdventureEndCard`;
  - the `ActionManager` adventure start/stop path.
