# Zones & Actions

Last updated: 2026-10-19

## Overview

The zone view is the home base and the initial `MainView` state. A 2D hex map (`ZoneTilemap`) draws each zone as a forest hex, and the player character stands on the selected zone. The right-hand `ZoneInfoPanel` lists the selected zone's available **zone actions** as cards grouped by type. Clicking a card hands its `ZoneActionData` to `ActionManager`, which runs exactly one action at a time:

- Timer-driven actions (foraging, training) run in place on the zone view.
- Cycling, adventure and NPC dialogue hand off to their own views or to Dialogic.

`ZoneManager` owns the selected zone and per-zone progression (completion counts, training ticks). Zones and actions are gated by `UnlockConditionData` ids that `UnlockManager` latches.

There are two zones today:

- **Spirit Valley** is playable and has 9 actions.
- **Test Zone** is a placeholder with no actions.

## Player Experience

1. A fresh save opens on the zone view with Spirit Valley selected and 25 Madra. The only card is `Talk to the [INTERVENER]`. The neighbouring Test Zone hex shows a grey overlay with a lock icon.
2. Hovering an unlocked hex shows an animated selector ring. Locked hexes and empty cells show nothing. Dark "ghost" hexes frame the edge of the map.
3. Clicking an unlocked hex does three things:
   - The character walks there at 150 px/s.
   - The camera glides to the hex (0.65 s cubic ease).
   - The header and action list switch to the new zone.

   Changing zone stops the running action. Clicking a locked hex shakes its lock icon. Clicking the current hex does nothing.
4. Cards sit under category headers that each have a coloured dot. Clicking a card starts that action, and the active card gets a border tinted with its category colour. Clicking the active card again does nothing. An action ends only when another action starts, the zone changes, or the action finishes on its own.
5. **Foraging:** a sweep fills the card every 5 s. Each fill:
   - rolls the loot table and awards the items;
   - flashes the card and floats `+N Item` text next to the panel;
   - makes the character wander within 32 px of the hex centre.
6. **Training (Aura Well):** a sweep fills on every 1 s tick. Each tick awards 1.5 Madra and flies a Madra particle to the Madra orb. A footer bar counts ticks toward the next level (`34 / 60`) and flashes on level-up. An inline badge shows the attribute earned so far (`+ 1 / 4 Spirit`).
7. **Adventure:** the card shows a Madra badge measured against the **adventure capacity**: total FOUNDATION × 10, from `CharacterAttributesData.get_max_madra()` on the total attributes, so equipment counts. This is not the Madra pool cap shown on the Madra orb.
   - When Madra is at least 50% of the adventure capacity, the badge reads `current / capacity` in gold.
   - Otherwise it reads `current / threshold` in red (threshold = 50% of the adventure capacity) and the card text is dimmed. An unaffordable click shakes the badge and logs `Not enough Madra! Need X, have Y`.
   - An affordable click starts the transition. Zone input is blocked and the budget (`min(adventure capacity, current Madra)`) drains from the Madra orb to the character as a stream of particles. The camera then zooms ×3 onto the character and the adventure view opens. Leaving the end card restores the camera. See [ADVENTURING.md § Starting an Adventure](../adventuring/ADVENTURING.md#starting-an-adventure) for the drain details.
8. The remaining action types:
   - **Cycling** opens the cycling view. Escape closes it and ends the action.
   - **Dialogue** plays a Dialogic timeline over the zone view. These cards are one-time: the card disappears when the timeline ends.
   - **Traveling Merchant** only logs `The merchant nods at you. (Shop coming soon.)`.
9. New cards and newly unlocked hexes appear as soon as a condition unlocks, with no notification.
10. Around the map:
    - Right-drag pans the camera and the mouse wheel zooms.
    - The left panel shows the Madra and Core Density orbs.
    - The top-left header shows the zone name and description.
    - The bottom toolbar opens Inventory, Abilities, Character and Path, and shows gold.

Foraging and training keep running while the Inventory, Path, Abilities or Character overlays are open. Starting cycling, an adventure or a dialogue stops them, and they do not resume afterwards.

### Controls

| Input | Effect | Handled by |
|---|---|---|
| Left-click unlocked hex | Travel to that zone | `ZoneTilemap._on_zone_tile_clicked()` |
| Left-click locked hex | Lock icon shakes | `LockedZoneOverlay.shake()` |
| Left-click action card | Start the action | `zone_action_button.gd` `_on_card_input()` |
| Right-drag | Pan the camera | `CameraPanController` |
| Mouse wheel | Zoom 0.65–1.35 (default 0.729, 10% per tick) | `CameraZoomController` |
| I / A / C / P, or toolbar buttons | Open Inventory / Abilities / Character / Path | `ZoneViewState.handle_input()`; see [MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md) |
| Escape (in the cycling view) | Close cycling and stop the action | `CyclingViewState.handle_input()` |
| Space (`center_zone_map_camera`) | Bound in `project.godot`, but no handler exists | — |

## Architecture

### Scene tree

`ZoneView` lives in `scenes/main/main_game/main_game.tscn`:

```
MainView/ZoneView (Control, %ZoneView)        shown/hidden by ZoneViewState
├── ZoneTransition (Node)                     zone_transition.gd — adventure start: Madra drain + camera zoom
├── SubViewportContainer (1920×1080)
│   └── SubViewport (transparent_bg)
│       ├── ZoneViewBackground (Node2D)       zone_view_background.gd — 12 Parallax2D layers built in _ready()
│       └── ZoneTilemap (Node2D)              zone_tilemap.tscn (below)
├── ZoneInfoPanel (PanelContainer)            zone_info_panel.gd — right edge, 450 px wide
├── ZoneResourcePanel (PanelContainer)        zone_resource_panel.gd — left edge, Madra + Core Density orbs
├── ZoneHeader (PanelContainer)               zone_header.gd — top-left, zone name + description
└── Toolbar (PanelContainer)                  scenes/ui/toolbar/toolbar.gd — bottom bar: 4 SystemMenuButtons + gold
```

`scenes/zones/zone_tilemap/zone_tilemap.tscn`:

```
ZoneTilemap (Node2D)                          zone_tilemap.gd (class ZoneTilemap)
├── MainZoneTileMapLayer (%)                  scenes/tilemaps/hexagon_tile_map_layer.tscn — tile_clicked / tile_hovered / tile_unhovered
├── Atmosphere                                scenes/atmosphere/atmosphere.tscn — vignette, mist, motes (default exports)
├── HoverSelector (%)                         HexHoverSelector (Sprite2D spritesheet, hover_fps 8)
├── GhostNeighborContainer (%)                Polygon2D hexes, rebuilt in code
├── LockedOverlayContainer (%, z_index 3)     one LockedZoneOverlay per locked zone
├── GlowingPathContainer (%, z_index 1)       one GlowingPath per adjacent unlocked pair
├── PlayerCharacter (%)                       scenes/characters/main_character/character_body_2d.tscn, scale 2.5
└── Camera2D (%)                              plain Camera2D, offset (100, 50)
    ├── CameraZoomController                  zoom_min 0.65, zoom_max 1.35, zoom_default 0.729
    ├── CameraPanController                   right-mouse drag
    └── CameraClampController                 use_boundaries, (-2000, -1250) to (2000, 1250)
```

Zone action UI:

```
ZoneInfoPanel (PanelContainer)                zone_info_panel.gd
└── ZoneInfoContent (VBox)
    ├── ActionsTitle "ZONE ACTIONS" (LabelTitleSmall)
    └── ActionsScrollContainer
        └── ActionsContent (%)                one section per ActionType that has an available action
            └── ZoneActionTypeSection (VBox)  zone_action_type_section.gd
                ├── CategoryHeader            CategoryDot (8×8 ColorRect) + CategoryLabel + HSeparator
                └── ZoneActionButtonSection (%)
                    └── ZoneActionButtonContainer (MarginContainer)   zone_action_button.gd
                        ├── ActionCard (PanelContainer, %)
                        │   ├── OverlaySlot (Control, %)              full rect, mouse ignored: sweeps
                        │   └── ContentMargin > VBoxContainer
                        │       ├── TopRow: TextSection (ActionNameLabel %, ActionDescLabel %) + InlineSlot (HBox, %): badges
                        │       └── FooterSlot (VBox, %)              progress bars
                        └── <presenter> (Node)                        added at runtime; its children are reparented into the slots
```

`zone_info_panel.gd`, `zone_action_type_section.gd`, `zone_action_button.gd` and `zone_header.gd` have no `class_name`, so this doc refers to them by scene name (for example, "ZoneActionButton").

### Singletons

| Singleton | File | Owns |
|---|---|---|
| `ZoneManager` | `singletons/zone_manager/zone_manager.gd` | Zone catalog (`ZoneDataList`), selected zone id, per-zone `ZoneProgressionData`, action availability |
| `ActionManager` | `singletons/action_manager/action_manager.gd` | The single `current_action`, routing by `ActionType`, the shared `action_timer`, foraging and training tick handlers |

`ActionManager` has no queue. It holds one `current_action`, and selecting another action stops the current one.

`ZoneManager` public API:

| Method | Returns | Notes |
|---|---|---|
| `get_current_zone()` | `ZoneData` | Writes `list[0].zone_id` into the save if `current_selected_zone_id` is empty |
| `set_current_zone(zone_data)`, `set_current_zone_by_id(zone_id)` | `void` | Stores the id in `SaveGameData`, then emits `zone_changed` |
| `has_zone(zone_id)` | `bool` | Used by save validation |
| `get_zone_progression(zone_id = current)` | `ZoneProgressionData` | Created on demand |
| `increment_zone_progression_for_action(action_id, zone_id = current, quantity = 1)` | `void` | Emits `action_completed(action_id)` when `max_completions > 0` and count ≥ max |
| `get_training_ticks(action_id, zone_id = current)` | `int` | 0 if never trained |
| `increment_training_ticks(action_id, zone_id = current, amount = 1)` | `int` | New total |
| `get_available_actions(zone_id = current)` | `Array[ZoneActionData]` | See [Unlock gating](#unlock-gating) |
| `get_action_by_id(action_id)` | `ZoneActionData` | Searches every zone |
| `get_zone_by_id(zone_id)`, `get_all_zones()` | `ZoneData`, `Array[ZoneData]` | |
| `get_unlocked_zones()` | `Array[ZoneData]` | Stub that always returns `[]`; no callers |

`ActionManager` public API: `select_action(action_data)`, `stop_action(successful = true)`, `confirm_adventure_start(action_data, madra_budget)`, `get_current_action()`, `clear_current_action()`, plus the public vars `current_action` and `action_timer` (a `Timer` child that foraging and training reuse; the presenters poll it).

### Zone map rendering

- **Tiles.** `ZoneTilemap.set_all_zones_in_tile_map()` places every zone in the catalog, locked or unlocked, at its `ZoneData.tilemap_location`, using forest atlas source 8. Selected and unselected hexes look the same; the character sprite is the only "you are here" marker.
- **Ghost neighbours.** `_refresh_ghost_neighbors()` draws a hex `Polygon2D` on every empty cell next to a zone, found with `TileMapLayer.get_surrounding_cells()`. The fill is `ghost_neighbor_color`, a near-black at 74% alpha.
- **Locked overlays.** `_refresh_locked_overlays()` places a `LockedZoneOverlay` on each zone whose `zone_unlock_conditions` are not met. The forest art stays visible underneath.
- **Glowing paths.** `_refresh_glowing_paths()` adds one `GlowingPath` for each pair of adjacent unlocked zones.
- **Hover.** `_on_zone_tile_hovered()` calls `HexHoverSelector.show_at()` for unlocked zones only.
- **Refresh.** Tiles, overlays and paths all rebuild on every `UnlockManager.condition_unlocked`.

#### Tile Variants

`ZoneData.tile_variant_index` picks one cell of the forest atlas:

- Atlas image: `assets/sprites/tilemap/hex_tiles/forest/hex_forest_atlas.png`.
- TileSet: `scenes/tilemaps/tilemap_tileset.tres`, source 8, 164×190 cells, alternative 0 only.
- `ZoneTilemap._get_zone_tile_atlas_coords()` maps index N to atlas cell `(N % 6, N / 6)`. An out-of-range index logs a warning and falls back to 0.

`scenes/tilemaps/scripts/pack_hex_atlas.py` generates the atlas. `FOREST_ATLAS_COLS` (6) and `FOREST_VARIANT_COUNT` (23) must match the script. The adventure map uses the same atlas through `HexForestAtlas.pick()` (`scripts/utils/hex_forest_atlas.gd`).

| Index | File | Index | File |
|---|---|---|---|
| 0 | `Hex_Forest_00_Basic` | 12 | `Hex_Forest_12_Lake2` |
| 1 | `Hex_Forest_01_Town1` | 13 | `Hex_Forest_13_Castle1` |
| 2 | `Hex_Forest_02_Town2` | 14 | `Hex_Forest_14_Castle2` |
| 3 | `Hex_Forest_03_City1` | 15 | `Hex_Forest_15_Ruin1` |
| 4 | `Hex_Forest_04_City2` | 16 | `Hex_Forest_16_Ruin2` |
| 5 | `Hex_Forest_05_Farms` | 17 | `Hex_Forest_17_Tower` |
| 6 | `Hex_Forest_06_River` | 18 | `Hex_Forest_18_Hole` |
| 7 | `Hex_Forest_07_Mountains1` | 19 | `Hex_Forest_19_Dead` |
| 8 | `Hex_Forest_08_Mountains2` | 20 | `Hex_Forest_20_Stones` |
| 9 | `Hex_Forest_09_Clearing1` | 21 | `Hex_Forest_21_Ravine` |
| 10 | `Hex_Forest_10_Clearing2` | 22 | `Hex_Forest_22_Cave` |
| 11 | `Hex_Forest_11_Lake1` | | |

To add a variant:

1. Add `Hex_Forest_NN_<label>.png` to the forest folder.
2. Re-run the packer.
3. Add the new atlas cell to source 8 in the TileSet.
4. Bump `FOREST_VARIANT_COUNT` in both `zone_tilemap.gd` and `hex_forest_atlas.gd`.

#### Visual components

| Component | Script / asset | Details |
|---|---|---|
| `GlowingPath` | `scenes/zones/glowing_path/glowing_path.gd` (`Line2D`) | `setup(from, to)` sets the two end points. The scene uses width 6, round caps, a gradient with alpha 0 → 1 → 0, and `assets/shaders/flowing_path.gdshader` (`stroke_color` (0.55, 0.78, 1, 0.85), `scroll_speed` 0.7, `pulse_strength` 0.35). The shader runs a brightness wave along `UV.x` |
| `LockedZoneOverlay` | `scenes/zones/locked_zone_overlay/locked_zone_overlay.gd` (`Node2D`, z_index 3) | A `GreyBackground` hex `Polygon2D` (`Color(0.12, 0.13, 0.18, 0.6)`) plus a `LockIcon` sprite (`assets/sprites/ui/lock_icon.png`, scale 1.5). `shake()` tweens the icon ±8, ±5, ±3 px over 0.44 s |
| `HexHoverSelector` | `scenes/tilemaps/hex_hover_selector.gd` (`Sprite2D`) | Shared with the adventure map; steps through spritesheet frames at `hover_fps` |
| `Atmosphere` | `scenes/atmosphere/atmosphere.gd` | Shared with the adventure map |
| `ZoneViewBackground` | `scenes/zones/zone_view_background/zone_view_background.gd` | Loads `layer_00.png`–`layer_11.png` from `assets/sprites/zones/backgrounds/spirit_valley/`. Layer i gets `scroll_scale = i / 11 × 0.2` (`MAX_SCROLL_SCALE`). The sky layer is scaled 15×; the others use `LAYER_SCALE` (6×). Nearest filtering. It always shows Spirit Valley, whatever zone is selected |
| `tile_aura.gdshader` | `assets/shaders/tile_aura.gdshader` | A pulsing tint shader that no scene references |

### Camera

The zone camera is a plain `Camera2D` with the three shared controllers from `scenes/camera/`.

- Clamping runs only when the pan or zoom controller emits `position_changed` or `zoom_changed`.
- `ZoneTilemap._ease_camera_to()` tweens the camera to a newly selected zone over `camera_ease_duration` (0.65 s, `TRANS_CUBIC` / `EASE_IN_OUT`).
- `ZoneTransition` zooms to 3.0 when an adventure starts. `ZoneTransition.reset_camera()` restores the saved zoom and position over 0.3 s when `ZoneViewState.enter()` runs.

### Zone Info Panel

`setup_zone_actions()` rebuilds the list in four steps:

1. Free all existing sections.
2. Call `ZoneManager.get_available_actions()` for the current zone.
3. Add one `ZoneActionTypeSection` for each `ActionType`, in enum order, that has at least one available action.
4. Each section adds one card per matching action, in `ZoneData.all_actions` order.

Section order is therefore FORAGE, ADVENTURE, NPC_DIALOGUE, MERCHANT, TRAIN_STATS, CYCLING.

| Rebuild trigger | Handler | Notes |
|---|---|---|
| `ZoneManager.zone_changed` | `_on_zone_changed()` | Only if the zone differs from the cached one |
| `ZoneManager.action_completed` | `_on_action_completed()` | Removes actions that reached `max_completions` |
| `UnlockManager.condition_unlocked` | `_on_condition_unlocked()` | Adds newly unlocked actions; also fires with `""` on save reset |

`ZoneActionTypeSection._populate_header()` hard-codes the header labels and dot colours:

| ActionType | Label | Dot colour |
|---|---|---|
| FORAGE | FORAGING | (0.42, 0.67, 0.37) green |
| ADVENTURE | ADVENTURE | (0.61, 0.25, 0.25) red |
| NPC_DIALOGUE | DIALOGUE | (0.83, 0.66, 0.29) gold |
| CYCLING | CYCLING | (0.37, 0.66, 0.62) teal |
| Any other type (TRAIN_STATS, MERCHANT, ZONE_EVENT) | ACTIONS | (0.5, 0.5, 0.5) grey |

### Action buttons and presenters

`zone_action_button.gd` is a shell that knows nothing about action types. It owns:

- the card styleboxes (`assets/styleboxes/zones/action_card_normal.tres`, `action_card_hover.tres`, `action_card_selected.tres`);
- the name and description labels;
- click routing;
- the three slots (overlay, inline, footer).

Type-specific visuals come from a presenter, picked from `PRESENTER_SCENES` by `action_type`. Types not in that dictionary use `DEFAULT_PRESENTER_SCENE`.

Shell behaviour:

- **Click.** A left-click on `ActionCard` is ignored if the action is already current. If `presenter.can_activate()` returns false, the shell calls `presenter.on_activation_rejected()`. Otherwise it calls `ActionManager.select_action(action_data)`.
- **Hover.** Uses `CARD_HOVER` (gold border), except on the current card or when the presenter vetoes activation.
- **Selected.** Uses a duplicate of `CARD_SELECTED` (3 px left border) with every border set to the category colour at 40% alpha.
- **Current state.** `is_current_action` is recomputed on every `ActionManager.current_action_changed` and passed to `presenter.set_is_current()`.
- **Helpers for presenters.** `get_category_color()`, `get_madra_target_global_position()` (the Madra orb centre), `set_text_dimmed()` and `get_action_card()`.

`CATEGORY_COLORS` in `zone_action_button.gd`:

| ActionType | Colour |
|---|---|
| FORAGE | green (0.42, 0.67, 0.37) |
| CYCLING | teal (0.37, 0.66, 0.62) |
| ADVENTURE | red (0.61, 0.25, 0.25) |
| NPC_DIALOGUE | gold (0.83, 0.66, 0.29) |
| TRAIN_STATS | purple (0.55, 0.45, 0.75) |
| Others | `DEFAULT_CATEGORY_COLOR`, grey (0.5, 0.5, 0.5) |

`ZoneActionPresenter` (`scripts/ui/zone_action_presenter.gd`) is an `@abstract` `Node`:

- Abstract methods: `setup(data, owner_button, overlay_slot, inline_slot, footer_slot)` and `teardown()`.
- Overridable hooks: `set_is_current()`, `can_activate()` (default `true`) and `on_activation_rejected()`.

| Presenter | Scene | Action types | Slots | Behaviour |
|---|---|---|---|---|
| `ForagingPresenter` | `presenters/foraging_presenter.tscn` | FORAGE | Overlay | `ProgressFill` ColorRect with `assets/shaders/action_card_sweep.gdshader`. `_process` sets `fill_amount = 1 − time_left / wait_time` from `ActionManager.action_timer`. On `foraging_completed` for the current action it flashes, fades (0.3 s), restarts, and spawns a `FloatingText` such as `+3 Dewdrop Tear, +4 Spirit Fern` |
| `AdventurePresenter` | `presenters/adventure_presenter.tscn` | ADVENTURE | Inline | `MadraBadge` plus a Madra icon. Capacity = `ResourceManager.get_adventure_madra_capacity()` (total FOUNDATION × 10) and threshold = `get_adventure_madra_threshold()` (capacity × 0.5). Shows `current / capacity` in `#D4A84A` when current Madra ≥ threshold, otherwise `current / threshold` in `#E06060`, and dims the card text while unaffordable. `can_activate()` returns a cached `ResourceManager.can_start_adventure()` that refreshes on `madra_changed`. A rejected click shakes the badge and logs `Not enough Madra!` |
| `TrainingPresenter` | `presenters/training_presenter.tscn` | TRAIN_STATS | Overlay, Inline, Footer | Per-tick sweep (same shader, also follows `action_timer`). `AttributeBadge` shows `+ current / max Attr`, built from the first `AwardAttributeEffectData` in `effects_on_level`, where max = `ticks_per_level.size() × amount`. `TickProgressBar` shows ticks in the current level over ticks needed for the next level. Each tick sends a `FlyingParticle` (0.5 s, size 4) from the card centre to the Madra orb. Each level-up calls `flash_and_reset()` (0.3 s) |
| `DefaultZoneActionPresenter` | `presenters/default_presenter.tscn` | CYCLING and NPC_DIALOGUE (mapped explicitly); MERCHANT and ZONE_EVENT (fallback) | None | No-op |

`TickProgressBar` (`scenes/ui/tick_progress_bar/`) is a 2 px bar with gradation marks at 10–90% and a counter label to its right. Its API:

- `set_progress(current, total)`: a total of 0 or less clears the bar.
- `set_fill_color(color)`.
- `flash_and_reset(color, duration)`.

### ZoneResourcePanel, ZoneHeader, Toolbar

- **`ZoneResourcePanel`** (`class_name ZoneResourcePanel`):
  - `MadraCircle` (`ProgressShaderRect` with the `liquid_wave` shader) fills to `madra / cap` with a `current / cap` label. The cap is `AdvancementStageResource.get_max_madra(core_density_level)`, which at Foundation is 100 + 5 × level.
  - `CoreDensityRect` (`core_density_fill` shader) fills to `level / 100`, labelled with the stage name and `Lvl N`.
  - The panel refreshes on `ResourceManager.madra_changed`, `CultivationManager.core_density_level_updated` and `CultivationManager.advancement_stage_changed`.
  - `get_madra_orb_global_position()` is the particle target for `ZoneTransition` and `TrainingPresenter`.
- **`ZoneHeader`** shows the current zone's name (`LabelTitleSmall`) and BBCode description, refreshed on `zone_changed`.
- **`Toolbar`** (`scenes/ui/toolbar/toolbar.tscn`, a child of `ZoneView`) holds four `SystemMenuButton`s (INVENTORY, ABILITIES, CHARACTER, PATH) and a gold label. The button script still lives at `scenes/zones/zone_resource_panel/system_menu/system_menu_button.gd`. Navigation behaviour is documented in [MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md).

## Data Model

### ZoneData

`scripts/resource_definitions/zones/zone_data/zone_data.gd`

| Field | Type | Default | Notes |
|---|---|---|---|
| `zone_name` | `String` | `""` | Header title |
| `zone_id` | `String` | `""` | Key for save data and lookups |
| `description` | `String` (multiline) | `""` | Header body (BBCode) |
| `icon` | `Texture2D` | `null` | No code reads it |
| `zone_unlock_conditions` | `Array[UnlockConditionData]` | `[]` | Every condition must be latched for the zone to unlock |
| `all_actions` | `Array[ZoneActionData]` | `[]` | Also sets card order within a section |
| `tilemap_location` | `Vector2i` | `(0, 0)` | Hex cell |
| `tile_variant_index` | `int` | `0` | Forest atlas variant (see [Tile Variants](#tile-variants)) |

`ZoneDataList` (`zone_data_list.gd`) has `list: Array[ZoneData]` and `get_zone_data_by_id(zone_id) -> ZoneData`. `ZoneManager._all_zone_data` preloads the catalog from `resources/zones/zone_data_list.tres`. `list[0]` is the starting zone.

### ZoneActionData

`scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd`

| Field | Type | Default | Notes |
|---|---|---|---|
| `action_id` | `String` | `""` | Key for completion counts and training ticks |
| `action_name` | `String` | `""` | Card title (plain `Label`) |
| `action_type` | `ActionType` | `FORAGE` | Selects the handler, presenter and colour |
| `description` | `String` (multiline) | `""` | Card body (`RichTextLabel`, BBCode); hidden when empty |
| `icon` | `Texture2D` | `null` | No code reads it |
| `unlock_conditions` | `Array[UnlockConditionData]` | `[]` | Every condition must be latched |
| `max_completions` | `int` | `0` | 0 = unlimited. N = the action is hidden once `action_completion_count >= N` |
| `success_effects` | `Array[EffectData]` | `[]` | Run by `stop_action(true)`, and when another action replaces this one |
| `failure_effects` | `Array[EffectData]` | `[]` | Run by `stop_action(false)` |

### ActionType

| Value | Enum | Data class | Handler | Presenter | Status |
|---|---|---|---|---|---|
| 0 | `FORAGE` | `ForageActionData` | `_execute_forage_action`: repeating timer, loot roll | `ForagingPresenter` | Implemented |
| 1 | `ADVENTURE` | `AdventureActionData` | `_execute_adventure_action`: Madra check, then `adventure_start_requested` | `AdventurePresenter` | Implemented |
| 2 | `NPC_DIALOGUE` | `NpcDialogueActionData` | `_execute_dialogue_action`: Dialogic timeline | Default | Implemented |
| 3 | `MERCHANT` | `ZoneActionData` (no subclass) | `_execute_merchant_action`: log line, then immediate `stop_action()` | Default (fallback) | Stub |
| 4 | `TRAIN_STATS` | `TrainingActionData` | `_execute_train_action`: repeating tick timer | `TrainingPresenter` | Implemented |
| 5 | `CYCLING` | `CyclingActionData` | `_execute_cycling_action`: `start_cycling` | Default | Implemented |
| 6 | `ZONE_EVENT` | — | None. `_execute_action()` logs "Unknown action type" | Default (fallback) | Not implemented |

If the data class doesn't match the type (for example `action_type = FORAGE` on a resource that isn't a `ForageActionData`), the handler logs an error and does nothing. Only `AdventureActionData._init()` and `TrainingActionData._init()` set `action_type`; the other subclasses rely on the value saved in the `.tres`.

### Subclasses

| Class | Field | Type | Default | Read by |
|---|---|---|---|---|
| `ForageActionData` | `loot_table` | `LootTable` | `null` | `ActionManager._on_forage_timer_finished()` |
| | `madra_cost_per_second` | `float` | `0.0` | Nothing; foraging costs no Madra |
| | `foraging_interval_in_sec` | `float` | `5.0` | `action_timer.wait_time` |
| `CyclingActionData` | `madra_multiplier`, `cycle_duration_modifier`, `xp_multiplier` | `float` | `1.0` | Nothing. `CyclingView.initialize_cycling_action_data()` is never called ([CYCLING.md](../cycling/CYCLING.md)) |
| | `madra_cost_per_cycle` | `float` | `0.0` | Nothing |
| `AdventureActionData` | `adventure_data` | `AdventureData` | `null` | `AdventureTilemap.start_adventure()` |
| | `time_limit_seconds` | `int` | `10` | `AdventureView.start_adventure()`; a value ≤ 0 falls back to 10 |
| | `gold_multiplier` | `float` | `1.0` | `AdventureCombat` gold formula |
| | `stamina_regen_modifier` | `float` | `1.0` | `AdventureView._update_stamina_regen()` (stamina regen = 1.0 × modifier) |
| | `experience_multiplier`, `difficulty_modifier`, `completion_time_modifier` | `float` | `1.0` | Nothing |
| | `cooldown_seconds` | `float` | `0.0` | Nothing |
| | `daily_limit` | `int` | `0` | Nothing |
| `NpcDialogueActionData` | `dialogue_timeline_name` | `String` | `""` | `DialogueManager.start_timeline()` |
| | `dialogue_timeline_label_jump` | `String` | `""` | Label passed to `Dialogic.start()` |
| `TrainingActionData` | `tick_interval_seconds` | `float` | `1.0` | `action_timer.wait_time` |
| | `ticks_per_level` | `Array[int]` | `[60, 300, 600, 1200]` | Incremental tick cost of levels 1..N |
| | `tail_growth_multiplier` | `float` | `2.0` | A level N beyond the array costs `last × mult^(N − size)` |
| | `effects_per_tick` | `Array[EffectData]` | `[]` | Run on every tick |
| | `effects_on_level` | `Array[EffectData]` | `[]` | Run once per level crossed |

`AdventureActionData.is_valid()` exists but nothing calls it.

`TrainingActionData` pure functions (unit-tested):

| Method | Returns |
|---|---|
| `get_ticks_required_for_level(level)` | Incremental cost of `level`. Returns 0 for level ≤ 0 or an empty array; uses the rounded tail formula beyond the array |
| `get_current_level(accumulated_ticks)` | Highest level whose cumulative cost ≤ the ticks (always 0 for an empty array) |
| `get_progress_within_level(accumulated_ticks)` | Progress toward the next level, 0.0–1.0 |

### Save data

`ZoneProgressionData` (`singletons/persistence_manager/zone_progression_data.gd`) is stored once per zone id in `SaveGameData.zone_progression_data`.

| Field | Type | Notes |
|---|---|---|
| `zone_id` | `String` | |
| `action_completion_count` | `Dictionary[String, int]` | `action_id` → number of times the action was stopped (see [Action lifecycle](#action-lifecycle)) |
| `training_tick_progress` | `Dictionary[String, int]` | `action_id` → accumulated training ticks |
| `forage_active` | `bool` | Never set; only printed by `_to_string()` |
| `forage_start_time` | `float` | Never set; only printed by `_to_string()` |

`SaveGameData` zone fields and helpers:

- `current_selected_zone_id: String`. The empty default resolves to `list[0]`.
- `zone_progression_data: Dictionary[String, ZoneProgressionData]`.
- `get_zone_progression_data(zone_id)` creates the entry on demand.
- `increment_zone_progression_for_action(action_id, zone_id, quantity) -> int`.

On load, `PersistenceManager._ready()` calls `SaveGameData.verify()`, which fails if `current_selected_zone_id` names a zone that `ZoneManager.has_zone()` doesn't know. A failed check resets the whole save. The current action is not saved, so nothing is running after a reload. `SaveTimer` autosaves every 5 s. See [PERSISTENCE.md](../infrastructure/PERSISTENCE.md).

## Core Systems / Flows

### Action lifecycle

```
Card click
  └─ ActionManager.select_action(action)
       ├─ _stop_executing_current_action(true)           # only if something is running
       │     ├─ ZoneManager.increment_zone_progression_for_action(old.action_id)   # uses the zone current at that moment
       │     │     └─ action_completed(action_id)         # if max_completions > 0 and count >= max
       │     └─ _stop_<type>_action(true): stop_* signal, timer reset, success_effects
       ├─ _set_current_action(action) → current_action_changed
       └─ _execute_action(action) → per-type handler

ActionManager.stop_action(successful = true)
  ├─ _stop_executing_current_action(successful): count +1, stop_* signal, success_ or failure_effects
  └─ clear_current_action() → current_action_changed(null)
```

What ends an action:

| Caller | When | `successful` |
|---|---|---|
| `ActionManager.select_action()` | Another action starts (stops the old one without clearing) | `true` |
| `ActionManager._on_zone_changed()` | `ZoneManager.zone_changed` | `true` |
| `DialogueManager.dialogue_ended` (one-shot, connected in `_execute_dialogue_action`) | The Dialogic timeline ends | `true` |
| `CyclingViewState.handle_input()` | `close_cycling_view` (Escape) | `true` |
| `AdventureTilemap.handle_combat_result()` | Boss combat won | `true` |
| `AdventureView._on_stop_combat()` | Combat lost | `false` |
| `AdventureView._on_adventure_timer_timeout()` | Time limit reached | `false` |
| `ActionManager._execute_merchant_action()` | Right after the log line | `true` |

Every stop adds 1 to `action_completion_count`, under the zone that is current at that moment. This happens whether the action succeeded, failed or was replaced, so `max_completions` counts attempts, not successes.

### Signals

`ZoneManager`:

| Signal | Emitted by | Listeners |
|---|---|---|
| `zone_changed(zone_data)` | `set_current_zone_by_id()`; `_initialize_from_save()` on save reset | `ActionManager._on_zone_changed` (stops the action), `ZoneInfoPanel`, `ZoneHeader` |
| `action_completed` (declared without parameters, emitted with `action_id`) | `increment_zone_progression_for_action()` | `ZoneInfoPanel` |

`ActionManager`:

| Signal | Emitted by | Listeners |
|---|---|---|
| `current_action_changed(action_data)` | `_set_current_action()` | Every action card |
| `start_foraging(action_data)` (emitted with no argument) | `_execute_forage_action()` | `ZoneTilemap._on_start_foraging` (character wanders) |
| `foraging_completed(items: Dictionary)` | Every forage timeout | `ZoneTilemap` (wander), `ForagingPresenter` |
| `stop_foraging()` | `_stop_forage_action()` | `ZoneTilemap` (character returns to the hex centre) |
| `start_cycling(action_data)` | `_execute_cycling_action()` | `CyclingViewState` (pushes the cycling view) |
| `stop_cycling()` | `_stop_cycling_action()` | `CyclingViewState` (pops), `CyclingView` |
| `adventure_start_requested(action_data)` | `_execute_adventure_action()` when affordable | `ZoneViewState` (input blocker), `ZoneTransition` |
| `start_adventure(action_data, madra_budget)` | `confirm_adventure_start()` | `AdventureViewState` (change state), `AdventureView.start_adventure` |
| `stop_adventure()` | `_stop_adventure_action()` | `AdventureView.stop_adventure` (→ `adventure_completed` → end card), `AdventureViewState` (no-op) |
| `start_training(action_data)`, `stop_training()` | Training start / stop | None |
| `training_tick_processed(action_data, new_tick_count)` | Every training tick | `TrainingPresenter` |
| `training_level_gained(action_data, new_level)` | Once per level crossed | `TrainingPresenter` |

Other signals the zone code consumes:

- `UnlockManager.condition_unlocked` (`ZoneInfoPanel`, `ZoneTilemap`).
- `tile_clicked`, `tile_hovered` and `tile_unhovered` from `scenes/tilemaps/hexagon_tile_map_layer.gd` (`ZoneTilemap`).
- `ResourceManager.madra_changed` (`AdventurePresenter`, `ZoneResourcePanel`).

`ZoneTilemap.zone_selected(zone_data, tile_coord)` is emitted on travel, but nothing listens to it.

### Zone selection

```
hexagon_tile_map_layer.gd _input (left click on a cell that has a tile)
  └─ tile_clicked(coord) → ZoneTilemap._on_zone_tile_clicked
       ├─ no zone, or the current zone → return
       ├─ locked → LockedZoneOverlay.shake(), return
       ├─ zone_selected.emit (no listeners); update_zone_tile_state → selected_zone setter
       │     └─ ZoneManager.set_current_zone → stores current_selected_zone_id → zone_changed
       │           ├─ ActionManager.stop_action()
       │           ├─ ZoneInfoPanel.setup_zone_actions()
       │           └─ ZoneHeader refresh
       ├─ PlayerCharacter.move_to_position(hex centre, 150 px/s)
       └─ camera tween to the hex (0.65 s)
```

`current_selected_zone_id` changes before `zone_changed` fires, so the stopped action's completion is counted under the destination zone.

### Foraging

1. `_execute_forage_action()` emits `start_foraging` and connects `action_timer.timeout` to `_on_forage_timer_finished`. It sets `wait_time = foraging_interval_in_sec` and starts the repeating timer.
2. On each timeout:
   - `loot_table.roll_loot()` rolls every `LootTableEntry` independently. An entry drops if `randf() <= drop_chance`, with quantity `randi_range(min_quantity, max_quantity)`.
   - `InventoryManager.award_items()` is called for each result.
   - `foraging_completed(items)` is emitted.
3. On stop, `stop_foraging` is emitted and `_reset_action_timer()` stops the timer and removes every timeout connection. The completion effects then run.

Foraging charges no Madra. `forage_active` and `forage_start_time` are never set, and nothing accrues offline.

### Training

1. `_execute_train_action()` emits `start_training` and starts the timer at `tick_interval_seconds`.
2. On each tick, `_on_train_timer_finished`:
   1. Reads the previous tick count for the current zone and computes the previous level.
   2. Calls `ZoneManager.increment_training_ticks()`.
   3. Runs `effects_per_tick`.
   4. Emits `training_tick_processed(action, new_ticks)`.
   5. For each level from `prev_level + 1` to `new_level`: runs `effects_on_level`, then emits `training_level_gained(action, level)`.
3. On stop, `stop_training` is emitted, the timer resets and the completion effects run. Ticks stay in `training_tick_progress`, so the next session continues from the same total.

### Adventure start (zone side)

The full sequence and the Madra numbers are in [ADVENTURING.md § Starting an Adventure](../adventuring/ADVENTURING.md#starting-an-adventure). Zone side:

1. `AdventurePresenter.can_activate()` gates the click on `ResourceManager.can_start_adventure()`. Madra must be at least 50% of the adventure capacity, `get_adventure_madra_capacity()` = `CharacterManager.get_total_attributes_data().get_max_madra()` = total FOUNDATION × 10. This is not the Madra pool cap.
2. `_execute_adventure_action()` checks again. On failure it logs `Not enough Madra! Need X, have Y` and clears the current action. On success it emits `adventure_start_requested(action)`. That signal carries no budget.
3. `ZoneViewState` adds a full-rect `MOUSE_FILTER_STOP` Control over `ZoneView` and ignores input actions while it exists.
4. `ZoneTransition._on_adventure_start_requested()`:
   - computes the budget, `ResourceManager.get_adventure_madra_budget()` = `min(capacity, current Madra)`;
   - spends it through `spend_madra()` as a stream of particles flying from the Madra orb to the character;
   - zooms the camera to 3.0 on the character over 0.5 s;
   - calls `ActionManager.confirm_adventure_start(action, budget)`, which emits `start_adventure(action, budget)`.
5. `start_adventure` triggers `AdventureViewState.change_state()`, whose `ZoneViewState.exit()` removes the blocker, and `AdventureView.start_adventure()`.
6. When the player leaves the end card (`change_state(zone_view_state)`), `ZoneViewState.enter()` calls `ZoneTransition.reset_camera()`.

### Cycling, dialogue, merchant

- **Cycling.** `start_cycling(action)` makes `CyclingViewState` push the cycling view. Escape calls `stop_action()`, which emits `stop_cycling`, and the view is popped. The `CyclingActionData` never reaches the view. See [CYCLING.md](../cycling/CYCLING.md).
- **NPC dialogue.** The handler connects `DialogueManager.dialogue_ended` to `stop_action` (one-shot), then calls `DialogueManager.start_timeline(dialogue_timeline_name, dialogue_timeline_label_jump)`. When the timeline ends, the success effects run (events and quest starts) and the one-time card disappears.
- **Merchant.** Logs `[color=yellow]The merchant nods at you. (Shop coming soon.)[/color]` and calls `stop_action()` synchronously. The completion count goes up by 1; no effects are authored.

### Unlock gating

- `ZoneManager.get_available_actions(zone_id)` returns `[]` if the zone's `zone_unlock_conditions` aren't met. Otherwise it returns every action whose `unlock_conditions` are met and whose completion count is below `max_completions` (or whose `max_completions` is 0).
- `UnlockManager.are_unlock_conditions_met()` only checks ids that are already latched in `UnlockProgressionData.unlocked_condition_ids`. It never evaluates a condition itself.
- Conditions latch in `UnlockManager._evaluate_all_conditions()`. That function only walks `resources/unlocks/unlock_condition_list.tres`, and only runs on these signals:
  - `EventManager.event_triggered`
  - `CultivationManager.advancement_stage_changed` and `core_density_level_updated`
  - `ResourceManager.madra_changed` and `gold_changed`

  A condition used by a zone or action must be registered in that list, or it never unlocks. See [QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md](../progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md) and [UNLOCKS.md](../infrastructure/UNLOCKS.md).
- Latches are permanent. For example, the Madra-100 gate on dialogue 2 stays open after the Madra is spent.
- The `ZONE_UNLOCKED` and `ADVENTURE_COMPLETED` condition types log a warning and return false. Zone gates must use events, cultivation level or stage, resources, items or attributes instead.
- The dev panel's `UnlockManager.force_unlock_condition()` latches any listed condition, and the map and panel refresh.

## Integration Points

| System | Connection |
|---|---|
| `MainView` / `ZoneViewState` | The zone view is the initial base state. `ZoneViewState` routes I / P / A / C and blocks input during the adventure transition ([MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md)) |
| `UnlockManager` | Gates zones and actions; `condition_unlocked` rebuilds the map and the panel |
| `EventManager` | Dialogue success effects fire `TriggerEventEffectData` events, which latch conditions |
| `QuestManager` | Dialogue success effects start quests (`StartQuestEffectData`). Quest completions fire the events that gate later actions ([FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md)) |
| `DialogueManager` / Dialogic | NPC dialogue actions run timeline labels; `dialogue_ended` stops the action |
| `CyclingViewState` / `CyclingView` | Driven by `start_cycling` and `stop_cycling` |
| `AdventureViewState` / `AdventureView` / `AdventureTilemap` | Driven by `start_adventure` and `stop_adventure`. Adventure code calls `stop_action(true/false)`. Adventure encounters fire `aura_well_discovered` and `merchant_discovered` |
| `AdventureCombat` | Fires `q_first_steps_enemy_defeated` on any combat win (this gates dialogue 3); reads `gold_multiplier` |
| `ResourceManager` | Adventure Madra gate, budget and drain; the training Madra trickle (`AwardResourceEffectData`); the resource panel |
| `CharacterManager` | Training attribute grants (`AwardAttributeEffectData`); total FOUNDATION (equipment included) × 10 sets the adventure capacity |
| `InventoryManager` | Forage loot via `award_items()` |
| `CultivationManager` | Resource panel stage and level; the `q_reach_cd_10` gate |
| `PersistenceManager` | `current_selected_zone_id` and `zone_progression_data`; a save reset re-emits `zone_changed` |
| `LogManager` | Adventure rejection and merchant messages |
| Dev panel | `UnlockManager.force_unlock_condition()` |

## Existing Content

### Zones

`resources/zones/zone_data_list.tres`

| Order | `zone_id` | Name | `tilemap_location` | Variant | Unlock | Actions |
|---|---|---|---|---|---|---|
| 0 (start) | `SpiritValley` | Spirit Valley | (0, 0) | 0 Basic | None | 9 |
| 1 | `TestZone` | Test Zone | (0, 1) | 0 Basic | `celestial_intervener_dialogue_1` | None; description is "test zone" |

The two hexes are adjacent, so a glowing path joins them once Test Zone unlocks.

### Spirit Valley actions

`resources/zones/spirit_valley_zone/zone_actions/`, in `all_actions` order:

| # | `action_id` | Name | Type | Unlock condition | Max | Config | Success effects |
|---|---|---|---|---|---|---|---|
| 1 | `wilderness_cycling_action` | `Wilderness Cycling` | CYCLING | `celestial_intervener_dialogue_1` | 0 | All modifiers at defaults (1.0 / 1.0 / 1.0 / 0.0) | — |
| 2 | `celestial_intervener_dialogue_1` | `Talk to the [INTERVENER]` | NPC_DIALOGUE | None | 1 | `celestial_intervener_introduction_1` @ `dialogue_1` | Event `celestial_intervener_dialogue_1`; start `q_fill_core` |
| 3 | `sprint_forest_foraging_action` | `Spring Forest Foraging` | FORAGE | `q_fill_core_completed` | 0 | 5.0 s interval, 0 Madra/s, `loot_table/test_loot_table_foraging.tres` | — |
| 4 | `shallow_woods_adventure_action` | `The Shallow Woods` | ADVENTURE | `q_fill_core_completed` | 0 | `resources/adventure/data/shallow_woods.tres`, 300 s limit, other modifiers at defaults | — |
| 5 | `celestial_intervener_dialogue_2` | `Return to the [INTERVENER]` | NPC_DIALOGUE | `q_fill_core_madra_full` | 1 | Label `dialogue_2` | Event `celestial_intervener_dialogue_2`; start `q_first_steps` |
| 6 | `aura_well_training` | `Aura Well` | TRAIN_STATS | `aura_well_discovered` | 0 | 1.0 s ticks, `[60, 300, 600, 1200]`, tail 2.0; +1.5 Madra per tick; +1 Spirit per level | — |
| 7 | `celestial_intervener_dialogue_3` | `Return to the [INTERVENER]` | NPC_DIALOGUE | `q_first_steps_enemy_defeated` | 1 | Label `dialogue_3` | Event `celestial_intervener_dialogue_3`; start `q_reach_core_density_10` |
| 8 | `celestial_intervener_dialogue_4` | `Return to the [INTERVENER]` | NPC_DIALOGUE | `q_reach_cd_10` | 1 | Label `dialogue_4` | Event `celestial_intervener_dialogue_4` |
| 9 | `spirit_valley_merchant` | `Traveling Merchant` | MERCHANT | `merchant_discovered` | 0 | Plain `ZoneActionData` | — |

Notes:

- The Aura Well effects live in `aura_well_madra_trickle_effect.tres` (`AwardResourceEffectData`, MADRA 1.5) and `aura_well_spirit_award_effect.tres` (`AwardAttributeEffectData`, SPIRIT 1.0).
- No action defines `failure_effects`.
- The `action_id` `sprint_forest_foraging_action` misspells "spring", and it is now a save key.

#### Spring Forest loot

`loot_table/test_loot_table_foraging.tres`

| Item | `item_id` | Drop chance | Quantity |
|---|---|---|---|
| Dewdrop Tear | `DewdropTear` | 100% | 1–5 |
| Spirit Fern | `SpiritFern` | 100% | 2–6 |

Each 5 s roll yields on average 3 Dewdrop Tears and 4 Spirit Ferns. No system consumes either material yet. The same folder also holds `test_loot_table_weapon.tres` (Makeshift Dagger, Iron Shortsword), which no zone uses (see [Tech Debt](#tech-debt)).

#### Aura Well levels

| Level | Ticks for this level | Cumulative ticks | Cumulative time at 1 s/tick | Total Spirit gained |
|---|---|---|---|---|
| 1 | 60 | 60 | 1 min | +1 |
| 2 | 300 | 360 | 6 min | +2 |
| 3 | 600 | 960 | 16 min | +3 |
| 4 | 1200 | 2160 | 36 min | +4 |
| 5 | 2400 (tail) | 4560 | 76 min | +5 |
| 6 | 4800 (tail) | 9360 | 156 min | +6 |

The trickle gives 90 Madra/min. `ResourceManager.add_madra()` clamps the total to the stage cap.

### Unlock conditions used by zones

All of these live in `resources/unlocks/` and are registered in `unlock_condition_list.tres`.

| `condition_id` | Type | Check | Latched by |
|---|---|---|---|
| `celestial_intervener_dialogue_1` | EVENT_TRIGGERED | Event `celestial_intervener_dialogue_1` | Dialogue 1 success effect |
| `q_fill_core_madra_full` | RESOURCE_AMOUNT | Madra ≥ 100 | Cycling (filling the Madra pool) |
| `q_fill_core_completed` | EVENT_TRIGGERED | Event `q_fill_core_completed` | The `q_fill_core` ("Awaken Your Core") completion effect, after dialogue 2 |
| `q_first_steps_enemy_defeated` | EVENT_TRIGGERED | Event `q_first_steps_enemy_defeated` | `AdventureCombat`, on any enemy kill |
| `q_reach_cd_10` | CULTIVATION_LEVEL | Core Density level ≥ 10 | Cycling |
| `aura_well_discovered` | EVENT_TRIGGERED | Event `aura_well_discovered` | Shallow Woods "Aura Well" encounter, "Mark down the location" choice |
| `merchant_discovered` | EVENT_TRIGGERED | Event `merchant_discovered` | Shallow Woods "Refugee Camp" encounter, "Approach the camp" (eligible once `refugee_camp_map` is owned) |

### Unlock chain (zone side)

```
Fresh save             → only "Talk to the [INTERVENER]"; Test Zone locked
Dialogue 1             → event celestial_intervener_dialogue_1 → Wilderness Cycling + Test Zone hex; q_fill_core starts
Madra ≥ 100            → q_fill_core_madra_full → Dialogue 2 card
Dialogue 2             → q_fill_core completes → event q_fill_core_completed → Spring Forest Foraging + The Shallow Woods; q_first_steps starts
First combat win       → q_first_steps_enemy_defeated → Dialogue 3 card
Aura Well encounter    → aura_well_discovered → Aura Well card (any time after adventuring starts)
Dialogue 3             → q_first_steps completes (path point); q_reach_core_density_10 starts
Core Density ≥ 10      → q_reach_cd_10 → Dialogue 4 card
Dialogue 4             → q_reach_core_density_10 completes → Refugee Camp Map item
Refugee Camp encounter → merchant_discovered → Traveling Merchant card
```

Narrative detail for each beat is in [FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md).

## Key Files

| File | Purpose |
|---|---|
| `singletons/zone_manager/zone_manager.gd` | Zone catalog, current zone, progression, availability |
| `singletons/action_manager/action_manager.gd` | Action routing, shared timer, foraging and training handlers, signals |
| `singletons/persistence_manager/zone_progression_data.gd` | Per-zone save data |
| `scripts/resource_definitions/zones/zone_data/zone_data.gd`, `zone_data_list.gd` | Zone resources |
| `scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd` | Base action class and `ActionType` |
| `scripts/resource_definitions/zones/zone_action_data/*/*_action_data.gd` | Forage, cycling, adventure, NPC dialogue and training subclasses |
| `scripts/ui/zone_action_presenter.gd` | Abstract presenter base |
| `scenes/zones/zone_tilemap/zone_tilemap.gd` / `.tscn` | Hex map: selection, overlays, paths, ghost hexes, foraging wander |
| `scenes/zones/zone_info_panel/zone_info_panel.gd` / `.tscn` | Action list |
| `scenes/zones/zone_action_type_section/zone_action_type_section.gd` / `.tscn` | Category section |
| `scenes/zones/zone_action_button/zone_action_button.gd` / `.tscn` | Card shell and presenter factory |
| `scenes/zones/zone_action_button/presenters/*_presenter.gd` / `.tscn` | Foraging, adventure, training and default presenters |
| `scenes/ui/tick_progress_bar/tick_progress_bar.gd` / `.tscn` | Training footer bar |
| `scenes/zones/zone_transition/zone_transition.gd` | Adventure-start drain and zoom |
| `scenes/zones/zone_resource_panel/zone_resource_panel.gd` / `.tscn` | Madra and Core Density orbs |
| `scenes/zones/zone_resource_panel/system_menu/system_menu_button.gd` / `.tscn` | Toolbar navigation buttons |
| `scenes/zones/zone_header/zone_header.gd` / `.tscn` | Zone name and description |
| `scenes/zones/zone_view_background/zone_view_background.gd` / `.tscn` | Parallax background |
| `scenes/zones/glowing_path/glowing_path.gd` / `.tscn`, `assets/shaders/flowing_path.gdshader` | Paths between unlocked zones |
| `scenes/zones/locked_zone_overlay/locked_zone_overlay.gd` / `.tscn` | Locked-zone overlay |
| `scenes/ui/main_view/states/zone_view_state.gd` | Zone view state and input blocker |
| `scenes/tilemaps/hexagon_tile_map_layer.gd`, `hex_hover_selector.gd`, `tilemap_tileset.tres` | Shared hex layer, hover ring, TileSet |
| `assets/shaders/action_card_sweep.gdshader` | Card sweep |
| `resources/zones/zone_data_list.tres`, `resources/zones/**` | Zone content |

### Tests

| File | Tests | Covers |
|---|---|---|
| `tests/unit/test_zone_progression_data.gd` | 7 | `training_tick_progress` default and save round-trip; `ZoneManager.get_training_ticks()` / `increment_training_ticks()` |
| `tests/unit/test_training_action_data.gd` | 18 | Cost-curve, level and progress functions; `_init` action type |
| `tests/unit/test_award_attribute_effect_data.gd` | 3 | The effect that grants training's level reward |
| `tests/integration/test_training_flow.gd` | 1 | `select_action` → ticks, Madra trickle, level-ups, persistence across stop and restart |
| `tests/integration/test_aura_well_discovery_unlock.gd` | 2 | Aura Well hidden before and visible after `aura_well_discovered` |
| `tests/integration/test_beat_3b_merchant_unlock.gd` | 1 | Dialogue 4 appears at CD 10, map award, merchant card after `merchant_discovered` |
| `tests/unit/test_hex_forest_atlas.gd` | 4 | Atlas picker shared with the adventure map |

### Specs and plans

| Document | Status |
|---|---|
| [2026-04-10 zone action button visuals spec](../superpowers/specs/2026-04-10-zone-action-button-visuals-design.md) and [plan](../superpowers/plans/2026-04-10-zone-action-button-visuals.md) | Shipped in PR #18, then reworked into presenters in PR #29. Non-timed actions get a tinted border instead of a static fill |
| [2026-04-17 training action infrastructure spec](../superpowers/specs/2026-04-17-training-action-infrastructure-design.md) and [plan](../superpowers/plans/2026-04-17-training-action-infrastructure.md) | Shipped in PR #29. The content was renamed Spirit Well → Aura Well and gated by an event (PR #36) |
| [2026-04-17 presenter refactor spec](../superpowers/specs/2026-04-17-zone-action-button-presenter-refactor-design.md), [pass 1](../superpowers/plans/2026-04-17-zone-action-button-presenter-refactor-pass-1.md) and [pass 2](../superpowers/plans/2026-04-17-zone-action-button-presenter-refactor-pass-2.md) | Both passes shipped in PR #29 |

## Work Remaining

### Bugs

- `[MEDIUM]` Dialogue 4 can appear out of order. `celestial_intervener_dialogue_4.tres` is gated only by `q_reach_cd_10` (Core Density ≥ 10). A player who reaches CD 10 before finishing dialogue 3 sees two `Return to the [INTERVENER]` cards, and can play `dialogue_4` before `q_reach_core_density_10` has started. Fix: add a second condition on the `celestial_intervener_dialogue_3` event, registered in `unlock_condition_list.tres`.
- `[MEDIUM]` Changing zone counts the interrupted action's completion under the destination zone. `ZoneManager.set_current_zone_by_id()` writes `current_selected_zone_id` before it emits `zone_changed`, and `ActionManager._stop_executing_current_action()` increments using the default zone id, which is now the new zone.
- `[MEDIUM]` `max_completions` counts attempts, not successes. `_stop_executing_current_action()` adds to `action_completion_count` on every stop, including `stop_action(false)` and replacement by another action. A failed run would use up a one-shot boss adventure (Foundation Beat 7).
- `[LOW]` `TrainingPresenter._update_attribute_badge()` caps "max" at `ticks_per_level.size() × amount` (4 Spirit for the Aura Well). Levels keep coming from the tail multiplier, so level 5 reads `+ 5 / 4 Spirit`.
- `[LOW]` `AdventurePresenter` refreshes affordability only on `ResourceManager.madra_changed`. If the adventure capacity changes (total FOUNDATION from gear or attributes), the badge and `can_activate()` stay stale until Madra next changes. `_execute_adventure_action()` checks again, but a stale "unaffordable" still blocks the click.
- `[LOW]` A rejected adventure in `_execute_adventure_action()` still stops whatever was running, because `select_action()` stops the previous action first. The presenter gate normally keeps this path from being reached.

### Missing Functionality

- `[HIGH]` Merchant shop. `_execute_merchant_action()` logs "Shop coming soon" and stops at once. There is no `MerchantActionData` (stock, prices), presenter or shop UI. Foundation Beat 4 needs this. Once a shop UI exists, closing it should call `stop_action()`, the same way dialogue does.
- `[HIGH]` `ZONE_EVENT` has no handler. `_execute_action()` logs "Unknown action type", but the action stays current (selected card, nothing running) until another action replaces it, and `_stop_executing_current_action()` skips its completion effects. Story events such as the Tribulation site (Beats 8–9) need this.
- `[MEDIUM]` Foraging is free. Nothing reads `ForageActionData.madra_cost_per_second`, but the GDD calls for a small continuous Madra cost.
- `[MEDIUM]` Foraging and training can't be toggled off. `_on_card_input()` ignores clicks on the current card and there is no stop control. They end only when another action starts or the zone changes. The GDD specifies an ON/OFF toggle.
- `[MEDIUM]` Idle actions don't survive a reload and don't run offline. The current action isn't saved, `forage_active` / `forage_start_time` are never written, and training has to be selected again after loading.
- `[MEDIUM]` Idle actions don't run alongside other activities. Starting cycling, an adventure or a dialogue stops foraging or training, and they don't resume.
- `[MEDIUM]` No zone gating by boss or adventure. `UnlockConditionData.ZONE_UNLOCKED` and `ADVENTURE_COMPLETED` return false, and nothing records adventure completion. The GDD gates zones behind zone bosses; today that requires firing an event from the boss combat's `success_effects`.
- `[LOW]` The GDD describes a 3D hex-planet map. The built map is a flat 2D `TileMapLayer`. Decide whether the 3D view is still a goal.
- `[LOW]` `center_zone_map_camera` (Space) is bound in `project.godot`, but nothing handles it. After panning, the only way to recentre is to travel to another zone.
- `[LOW]` Unused action modifiers. `CyclingActionData` modifiers are never applied ([CYCLING.md](../cycling/CYCLING.md)). `AdventureActionData.experience_multiplier`, `difficulty_modifier`, `completion_time_modifier`, `cooldown_seconds` and `daily_limit` are never read ([ADVENTURING.md](../adventuring/ADVENTURING.md)).

### Content

- `[HIGH]` Only one real zone. `TestZone` is a placeholder the player can see (name "Test Zone", description "test zone", no actions). It unlocks after dialogue 1, and travelling there only stops the running action. Foundation Beats 8–10 need the Advancement Zone and a Zone 2.
- `[MEDIUM]` Foraged materials have no use. Dewdrop Tear and Spirit Fern list `used_in` recipes, but no system consumes them. There is only one forage action and one loot table.
- `[MEDIUM]` The Traveling Merchant has no stock, and there is no `ZONE_EVENT` content.
- `[LOW]` `ZoneViewBackground` always loads the Spirit Valley layers. Per-zone backgrounds need a `ZoneData` field.
- `[LOW]` Both zones use `tile_variant_index` 0, so the other 22 forest variants never appear on the zone map.
- `[LOW]` Placeholder text and art: Wilderness Cycling's description is "Cycle in the wilderness", Spring Forest Foraging's is "Go to the Spring Forest and Forage some materials", and Spirit Valley's `icon` is `res://64.png`.

### UI

- `[MEDIUM]` Unlocks give no feedback. New hexes and cards appear silently on `condition_unlocked`; only quests have toasts.
- `[MEDIUM]` Locked zones only shake their lock icon. Clicking or hovering should show the zone name and its unlock requirement.
- `[MEDIUM]` Training floods the log window. Every tick calls `ResourceManager.add_madra(1.5)`, which logs `Gained 1 Madra` (the 1.5 is truncated) once per second. This happens even when Madra is at the cap and nothing is gained, and particles keep flying at the cap too.
- `[LOW]` The TRAIN_STATS and MERCHANT sections are both headed "ACTIONS" with a grey dot, because `ZoneActionTypeSection._populate_header()` only knows four types. The Aura Well card itself is purple.
- `[LOW]` Selected non-timed cards (cycling, dialogue, merchant) only get a tinted border. The 2026-04-10 visuals spec called for a static category fill.
- `[LOW]` The zone view shows two different Madra maximums. The resource orb shows the pool cap (100 + 5 × Core Density level), while the adventure badge shows the adventure capacity (total FOUNDATION × 10). Coordinate with [RESOURCES.md](../infrastructure/RESOURCES.md).
- `[LOW]` `GlowingPath` leaves `Line2D.texture_mode` at none. If Line2D emits no UVs in that mode, the `UV.x` wave in `flowing_path.gdshader` shows as a uniform pulse rather than a flow (unverified; check in the editor).

### Tech Debt

- `[MEDIUM]` Removing or renaming a zone id wipes the whole save. `PersistenceManager._ready()` resets all data when `SaveGameData.verify()` (`_verify_current_selected_zone_id()`) fails. Renaming an `action_id` silently drops its completion count, so one-time dialogues reappear. A migration path is needed before Test Zone is replaced.
- `[LOW]` Dead code and assets:
  - `ZoneManager.get_unlocked_zones()` always returns `[]` and has no callers.
  - `ZoneTilemap.zone_selected`, `ActionManager.start_training` and `ActionManager.stop_training` have no listeners.
  - `assets/shaders/tile_aura.gdshader`, `scenes/tilemaps/pulse_node.gd` / `.tscn` with `assets/shaders/pulse_node.gdshader`, and `scenes/tilemaps/tile_map_layer.tscn` are not referenced anywhere.
  - Nothing reads `ZoneData.icon` or `ZoneActionData.icon`, and nothing calls `AdventureActionData.is_valid()`.
- `[LOW]` Signal declarations don't match their emits. `start_foraging(action_data)` is emitted with no argument. `ZoneManager.action_completed` is declared without parameters but emitted with `action_id`.
- `[LOW]` Duplicated constants. Category colours are defined in both `ZoneActionTypeSection._populate_header()` and `CATEGORY_COLORS` in `zone_action_button.gd`. `FOREST_ATLAS_COLS` and `FOREST_VARIANT_COUNT` are defined in both `zone_tilemap.gd` and `HexForestAtlas`.
- `[LOW]` `ForageActionData`, `CyclingActionData` and `NpcDialogueActionData` don't set `action_type` in `_init()`.
- `[LOW]` `ZoneResourcePanel._update_madra()` calls the private `CultivationManager._get_current_stage_resource()` and duplicates the cap formula from `ResourceManager.add_madra()`.
- `[LOW]` `zone_action_button.gd`, `zone_info_panel.gd`, `zone_action_type_section.gd` and `zone_header.gd` have no `class_name`. As a result, presenters hold the button as a `Control` and call its helpers untyped.
- `[LOW]` `ZoneTilemap._ready()` sets `selected_zone` and then calls `update_zone_tile_state()` with the same zone, so `zone_changed` fires twice at startup. `ZoneManager.get_current_zone()` writes to save data when the id is empty.
- `[LOW]` Stopping a dialogue relies on a one-shot `DialogueManager.dialogue_ended` → `stop_action` connection. If another action became current mid-timeline, that action would be stopped instead. Today Dialogic's full-screen `DialogicNode_Input` control covers the zone UI while a timeline runs, which prevents this.
- `[LOW]` Some visuals are built at runtime. `ZoneViewState._add_input_blocker()` creates a `Control`, `ZoneViewBackground` creates its `Parallax2D` / `Sprite2D` layers, and `ZoneTilemap` creates the ghost `Polygon2D`s. Project convention is that UI nodes live in `.tscn` files.
- `[LOW]` Coding-standard gaps:
  - `LockedZoneOverlay` uses `$LockIcon` instead of a `%` reference.
  - `ZoneManager.has_zone()` has an empty `##` comment.
  - The `quantity` parameter of `increment_zone_progression_for_action()` is untyped.
  - `AdventureActionData._init()` lacks `-> void`.
  - `ActionManager.get_current_action()`, `clear_current_action()` and `GlowingPath.setup()` lack `##` docs.
  - `ZoneViewBackground.LAYER_SCALE` is an export with a constant-style name.
- `[LOW]` `resources/zones/spirit_valley_zone/zone_actions/loot_table/test_loot_table_weapon.tres` isn't zone content. Its only user, `resources/adventure/encounters/test_treasure_encounter.tres`, is itself unreferenced. The live forage table is still named `test_loot_table_foraging.tres`.
- `[LOW]` `scenes/tilemaps/hexagon_tile_map_layer.tscn` references `tilemap_tileset.tres` by `uid://eptmap1q2w3e4`, but the TileSet's own UID is `uid://ufqon4iip7nd`, so Godot falls back to the path with a warning.
- `[LOW]` Missing tests:
  - `ActionManager` routing and stop paths, completion counting and `action_completed`.
  - `max_completions` filtering in `get_available_actions()`.
  - Foraging loot awarding, the merchant stub and the adventure Madra check.
  - `ZoneTransition` drain arithmetic (whole-Madra particles plus the remainder).
  - Test Zone gating.
  - `get_current_level()` with an empty `ticks_per_level`.
