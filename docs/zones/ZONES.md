# Zones & Actions

Last updated: 2026-10-22

## Overview

The zone view is the home base and the initial `MainView` state. Since the map-first rebuild (2026-10-22, branch `feat/zone-view-redesign-4656b7`, [spec](../superpowers/specs/2026-10-21-zone-view-map-first-design.md), [art kit](../superpowers/specs/2026-10-21-zone-view-lacquer-kit.md)) it is drawn in the **Lacquer and brass** look:

- a 2D hex map (`ZoneTilemap`) at zoom 2 fills the screen. The current zone sits at screen (960, 702) inside a lattice of fog, and the player character stands on it;
- the **cultivator cabinet** (`CultivatorPlate`) at the top left shows Madra, Core Density and gold;
- the **Goals board** and the **log board** hang under it (both are `MainView` HUD, see [MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md));
- the **zone chest** (`ZonePanel`) at the top right holds the zone header, the **Now strip** (the running idle action, or an empty tray saying what is paused), and the zone's **activity cards**, grouped Talk, Cultivate, Gather, Venture, Visit;
- the **dock** (`Dock`) at the bottom centre opens Inventory, Abilities, Character and Path.

Clicking a card hands its `ZoneActionData` to `ActionManager`, which runs exactly one action at a time:

- Idle actions (foraging, training) run in place on the zone view.
- Session actions (cycling, adventure, NPC dialogue, the merchant) hand off to their own views or to Dialogic. When one ends, the zone's idle action resumes on its own ("always in an idle action").

`ZoneManager` owns the current zone, per-zone progression (completion counts, training ticks, the last idle action), the map's zone list and map states, and the seen-action record behind the NEW seal. Zones and actions are gated by `UnlockConditionData` ids that `UnlockManager` latches.

There are two zones in `zone_data_list.tres` today:

- **Spirit Valley** is playable and has 9 actions. It is the only zone on the map.
- **Test Zone** is a placeholder with no actions. It is hidden on the map (`hidden_on_map`), west of Spirit Valley at (-1, 0), with no description. The dev panel can show it.

Two more zones exist only as dev demos (`resources/zones/dev/`): a locked Advancement Zone and an Uncharted hex. They show the locked and uncharted map states until Beats 7–10 add real zones.

## Player Experience

1. A fresh save opens on Spirit Valley with 25 Madra. The map shows only Spirit Valley, framed in fog. The only card is `Talk to the [INTERVENER]` under **Talk**, with no NEW seal: the save's first pass marks every action available at that moment as seen, so NEW lights only cards that unlock later. Nothing idle is unlocked, so the Now strip shows its empty tray, "Nothing running"; it keeps its space, so the Activities header sits under it as always. The Goals board shows only the Breakthrough milestone ("Raise Core Density to 100", `0 / 100`).
2. Hovering the current zone's hex or plate brightens its plate. Locked and uncharted hexes (dev demo zones only, today) get a thin brass rim inside their veil and, after 150 ms, a preview popover with the requirement. Fog shows nothing.
3. Clicking a hex:
   - **Open zone** (another unlocked zone): the character walks there at 275 map px/s in whole-px steps while the current action keeps running. On arrival the zone changes, the camera eases onto it (0.3 s), the chest switches to the new zone's cards, and the new zone's idle action starts. The log reads "Travelled to <zone> · resumed <action>", or "Travelled to <zone>" when nothing resumes. A second click during the walk retargets it.
   - **Current zone:** recentres the camera and closes any popover.
   - **Locked zone:** the padlock shakes (0.44 s, whole steps), a heavy brass rim marks the hex, and the popover pins with ×. "Show me ›" appears when the requirement names a card in the current zone; it scrolls the list to that card and flashes it.
   - **Uncharted zone:** the popover pins (UNKNOWN); it never travels.
   - **Fog:** closes any popover.
4. Cards are 392 px lacquer drawers: icon, title, a mode tag (IDLE, ACTIVE, SHOP, STORY) and one detail line. Clicking a card starts that action. An idle card that runs is pulled out 2 px and tagged RUNNING; clicking it again flashes the Now strip instead of restarting it.
5. **Foraging:** the card reads `[dewdrop] 1–5  [fern] 2–6 · every 5 s · free`. While it runs, the Now strip shows each loot range and "haul in N s", and a jade bead ring fills over each 5 s haul. Each haul rolls the loot table, floats the haul ("+3 Dewdrop Tear  +4 Spirit Fern") over the character on a lacquer token, and the character wanders west and back.
6. **Training (Aura Well):** the card reads `+1.5 Madra / s · each level +1 Spirit`. While it runs, the Now strip shows the rate, "Lv n → n+1 · +1 Spirit", the ticks into the level (`214 / 300`) and a jade rod; the cabinet shows `+1.5 / s`; each 1 s tick floats "+1.5 Madra" in Madra blue and the character bobs. The trickle writes nothing to the log.
7. **Adventure:** the card is a normal 72 px drawer, measured against the **adventure capacity** (total FOUNDATION × 10, equipment included), not the Madra pool cap on the cabinet.
   - Below the threshold (50% of capacity), tag ACTIVE: the detail row is the Madra icon, a Madra rod and `25 / 50` in tan, plus a cream `~17 s` at the right while a Madra action runs (the Aura Well); nothing else. A click shakes the row and logs `Not enough Madra! Need X, have Y`; nothing stops.
   - At the threshold: a steady brass frame around the card, "5 min run · carries 100 Madra" in brass and the ENTER tag. A click starts the transition: zone input is blocked, the budget (`min(capacity, current Madra)`) pours from the cabinet's Madra orb to the character as stepped Madra pellets, the map markers hide, the camera zooms ×3 onto the character, and the adventure view opens. Leaving the end card restores the camera. See [ADVENTURING.md § Starting an Adventure](../adventuring/ADVENTURING.md#starting-an-adventure).
8. The session actions:
   - **Cycling** (ACTIVE): "<equipped technique> · Madra and Core Density XP". Opens the cycling view; Escape closes it and ends the action.
   - **Dialogue** (STORY): the description as the detail line. Plays a Dialogic timeline over the zone view. These cards are one-time: the card disappears when the timeline ends.
   - **Traveling Merchant** (SHOP): "<n> wares · you have <gold> gold". Opens the shop over the zone view; Leave or Escape closes it. Stock, prices and rules are in [FOUNDATION_PLAYTHROUGH.md Beat 4](../progression/FOUNDATION_PLAYTHROUGH.md#beat-4-merchant-shop-implemented).

   When any of them ends, the zone's idle action resumes and the log reads "Resumed <action>".
9. New cards appear as soon as a condition unlocks, with a NEW seal until first hovered or used. When the first idle action of a zone unlocks while nothing runs, it starts on its own ("Started <action>").
10. Around the map:
    - Right-drag pans the camera and the mouse wheel zooms (1.0–2.0). Below zoom 1.25 the plates show only their names.
    - About in the chest header opens the zone's lore inline under the Now strip; About, Escape or a click outside closes it.
    - The dock opens Inventory, Abilities, Character and Path. Path shows a cinnabar count seal while path points are unspent; Abilities shows a brass ring while an unlocked ability is unequipped.
    - L opens the full log.

Foraging and training keep running while the Inventory, Path, Abilities or Character overlays are open, and while the character walks to another zone. Cycling, an adventure, a dialogue or the merchant replaces them, and they resume when that action ends. On load the zone's last idle action starts again.

### Controls

| Input | Effect | Handled by |
|---|---|---|
| Left-click open hex or its plate | Walk there; the zone changes on arrival | `ZoneTilemap.click_zone()` → `MapPopoverState.click()` |
| Left-click current hex | Recentre the camera (a walk in progress turns back home) | `ZoneTilemap.click_zone()` |
| Left-click locked / uncharted hex | Pin the popover (the padlock shakes on a locked hex) | `MapMarkers`, `MapGlyph.shake()` |
| Left-click fog or empty map | Close the popover | `MapMarkers` |
| Escape | Close the full log; else the zone lore; else the pinned popover. The lore and the popover close only while the zone view is the active state, so an overlay opened from the keyboard (C, I, A, P) gets Esc first | `LogWindow`, `ZonePanel`, `MapMarkers` |
| Left-click action card | Start the action (on the running idle card: flash the Now strip) | `ZoneActionButton._on_gui_input()` |
| Left-click Now strip | Scroll to the running card and flash it | `ZonePanel.scroll_to_action()` |
| Rail caps, rail thumb drag, mouse wheel over the list | Scroll the activity list (caps step one drawer in six even-px steps) | `LacquerRail`, the list's `ScrollContainer` |
| Right-drag | Pan the camera | `CameraPanController` |
| Mouse wheel over the map | Zoom 1.0–2.0 (default 2.0, 10% per tick) | `CameraZoomController` |
| I / A / C / P, or dock buttons | Open Inventory / Abilities / Character / Path | `ZoneViewState.handle_input()`; see [MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md) |
| L | Open or close the full log | `LogWindow._unhandled_input()` |
| Escape (in the cycling view) | Close cycling and stop the action | `CyclingViewState.handle_input()` |
| Space (`center_zone_map_camera`) | Bound in `project.godot`, but no handler exists | — |

## Architecture

### Scene tree

`ZoneView` lives in `scenes/main/main_game/main_game.tscn`:

```
MainView/ZoneView (Control, %ZoneView)        shown/hidden by ZoneViewState
├── ZoneTransition (Node)                     zone_transition.gd — adventure start: Madra pellet drain + camera zoom
├── SubViewportContainer (1920×1080)
│   └── SubViewport (transparent_bg, canvas_item_default_texture_filter Nearest)
│       └── ZoneTilemap (Node2D)              zone_tilemap.tscn (below)
├── CultivatorPlate (Control, 440×252 at (24, 24))      scenes/zones/cultivator_plate/ — Madra, Core Density, gold
├── ZonePanel (Control, 440 wide at (1456, 24))         scenes/zones/zone_panel/ — the zone chest
└── Dock (Control, 476×80 at (722, 976))                scenes/ui/dock/ — four SystemMenuButtons
```

The Goals board (`GoalsPanel`, at (24, 276), 4 px under the kit's 272 so its cords read; they reach 4 px above its root to the cabinet's rings) and the log board (`LogWindow`, slot at (24, 852)) are children of `MainView`, not of `ZoneView`, because the adventure view shows them too. `ZoneViewState.enter()` puts them there.

`scenes/zones/zone_tilemap/zone_tilemap.tscn`:

```
ZoneTilemap (Node2D)                          zone_tilemap.gd (class ZoneTilemap)
├── MapGround (CanvasLayer -1)                GroundRect: full-rect #090E0E behind the map
├── FogTileMapLayer (%)                       hexagon_tile_map_layer.tscn with scenes/tilemaps/fog_tileset.tres (sources 1–3 = tiers 1–3)
├── LockedOverlayContainer (%)                one LockedZoneOverlay per locked or uncharted map zone
├── MainZoneTileMapLayer (%)                  hexagon_tile_map_layer.tscn — the map zones only; tile_clicked / tile_hovered / tile_unhovered
├── HexMarkerContainer (%)                    one ZoneHexMarker per current or open map zone
├── RouteContainer (%)                        one ZoneRoute per pair of zones a route joins
├── PlayerCharacter (%)                       character_body_2d.tscn at scale 1; CharacterShadow sprite
├── Camera2D (%)                              zoom 2, offset zero
│   ├── CameraZoomController                  zoom_min 1.0, zoom_max 2.0, zoom_default 2.0
│   ├── CameraPanController                   right-mouse drag
│   └── CameraClampController                 use_boundaries, clamp_centre_only; per-zone camera windows set from code
└── MapMarkers (%)                            map_markers.tscn (CanvasLayer 1, below)
```

`scenes/zones/map_markers/map_markers.tscn` draws in screen space over the map:

```
MapMarkers (CanvasLayer, layer 1)             map_markers.gd (class MapMarkers)
├── Root (Control)
│   ├── ActionRing                            MapActionRing — 64×64 jade bead ring + action icon, beside the character
│   ├── Floater                               MapFloater — "+1.5 Madra" / haul text on a lacquer token
│   ├── GlyphContainer                        MapGlyph per veiled zone — padlock, or "?" with its twinkle
│   ├── PlateContainer                        ZoneMapLabel per map zone — 248×52 plate: name + status line
│   └── Popover                               ZoneMapPopover — LOCKED or UNKNOWN card, preview or pinned
└── PreviewTimer (Timer)                      150 ms hover delay before a preview popover
```

`scenes/zones/zone_panel/zone_panel.tscn` (the chest):

```
ZonePanel (Control)                           zone_panel.gd (class ZonePanel), theme = lacquer_theme.tres
├── Chest                                     ChestTop / ChestMid (tiled) / ChestBottom slices; height hugs the content
├── Thumb                                     the zone's tile thumbnail (river for Spirit Valley, basic otherwise)
├── ZoneNameLabel                             LabelLacquerZoneName
├── AboutButton                               toggles the lore; hidden when the zone has no description
├── NowStrip                                  now_strip.tscn (class NowStrip) — always shown; empty while no idle action runs
├── ActivitiesHeader                          "Activities", a carved groove, "<n> here"
├── ActivityList                              activity_list.tscn (class ActivityList) — ScrollContainer, group labels, cards, LacquerRail, lips
└── LorePanel                                 LoreBoard + LoreText (LabelLacquerLore, 366 wide), hidden by default
```

Each card is `scenes/zones/zone_action_button/zone_action_button.tscn` (class `ZoneActionButton`): a fixed 392×72 (or 96 tall) root with a `Drawer` child holding the face, icon, title, NEW seal, tag, the detail slot (an `HBoxContainer` at x+64, y+38, 316 wide), the footer slot and three `LacquerFrameOverlay`s (the ready frame, hover and flash). A presenter is added at runtime and reparents its children into the slots.

### Singletons

| Singleton | File | Owns |
|---|---|---|
| `ZoneManager` | `singletons/zone_manager/zone_manager.gd` | Zone catalog (`ZoneDataList`), current zone id, per-zone `ZoneProgressionData`, action availability, map zones and map states, dev zone toggles, seen actions, focus requests |
| `ActionManager` | `singletons/action_manager/action_manager.gd` | The single `current_action`, routing by `ActionType`, the shared `action_timer`, foraging and training tick handlers, idle-action resolution and its log lines |

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
| `get_last_idle_action_id(zone_id)`, `set_last_idle_action_id(zone_id, action_id)` | `String`, `void` | The idle action the zone resumes |
| `get_map_zones()` | `Array[ZoneData]` | Zone list order; skips `hidden_on_map` zones unless hidden zones are shown; demo zones last when shown |
| `get_zone_map_state(zone_data)` | `ZoneMapState` | `UNCHARTED` while its `chart_conditions` aren't latched, else `LOCKED` while its `zone_unlock_conditions` aren't, else `CURRENT` or `OPEN` |
| `is_zone_charted(zone_data)` | `bool` | Every chart condition latched (or none) |
| `set_demo_zones_visible(visible)`, `set_hidden_zones_visible(visible)` | `void` | Dev toggles. Emit `map_zones_changed` when the setting changes. Not saved |
| `mark_action_seen(action_id)`, `is_action_seen(action_id)` | `void`, `bool` | `SaveGameData.seen_action_ids`; an unseen available action shows NEW |
| `request_action_focus(action_id)` | `void` | Emits `action_focus_requested` (the popover's "Show me") |
| `get_available_actions(zone_id = current)` | `Array[ZoneActionData]` | See [Unlock gating](#unlock-gating) |
| `get_action_by_id(action_id)` | `ZoneActionData` | Searches every zone in the list |
| `get_zone_by_id(zone_id)`, `get_all_zones()` | `ZoneData`, `Array[ZoneData]` | The list only; demo zones are not in it |
| `get_unlocked_zones()` | `Array[ZoneData]` | Stub that always returns `[]`; no callers |

`ActionManager` public API: `select_action(action_data)`, `stop_action(successful = true)`, `resolve_idle_action(zone_id) -> ZoneActionData`, `get_current_madra_per_second() -> float` (a running training action's Madra per second, else 0), `confirm_adventure_start(action_data, madra_budget)`, `get_current_action()`, `clear_current_action()`, plus the public vars `current_action` and `action_timer` (a `Timer` child that foraging and training reuse; the Now strip and the map ring read it every frame).

`ZoneActionGroups` (`scripts/utils/zone_action_groups.gd`, statics) holds the list order and the tags: `group_of(action_type)` (TALK = NPC_DIALOGUE; CULTIVATE = CYCLING, TRAIN_STATS; GATHER = FORAGE; VENTURE = ADVENTURE; VISIT = MERCHANT, ZONE_EVENT), `label(group)`, `sort_actions(actions)` (stable: by group, list order within a group) and `mode_tag(action)` (IDLE for FORAGE and TRAIN_STATS, ACTIVE for CYCLING and ADVENTURE, SHOP for MERCHANT, STORY for NPC_DIALOGUE and ZONE_EVENT).

### Zone map rendering

`ZoneTilemap._rebuild_map()` redraws everything for `ZoneManager.get_map_zones()` and emits `map_rebuilt`. It runs on load, on `ZoneManager.map_zones_changed` and on every `UnlockManager.condition_unlocked`.

- **Zone layer.** Only the map zones get a cell on `MainZoneTileMapLayer`, at `ZoneData.tilemap_location`, from forest atlas source 8. A veiled zone gets the base tile's transparent alternative (source 0, alternative 4), so its cell stays clickable under the veil.
- **Fog.** Every other cell out to half a viewport past the widest camera clamp (at zoom 1.0) is fog on `FogTileMapLayer`, written with `set_cell`. A cell's tier is its hex distance to the nearest charted map zone, capped at 3 (`ZoneMapMath.fog_tier`); the tier picks the atlas source (1–3, `assets/ui/lacquer/map/lacquer_fog_t{1,2,3}_atlas_ai.png`). The art follows kit §6.2's hand-placed table on its 32 cells, and about 60% of the cells past them are Basic (`ZoneMapMath.fog_art_index`).
- **Hex states.** The current zone gets the brass rim and lacquer collar, and an open zone a dull brass hairline (`ZoneHexMarker`). A locked or uncharted zone gets a veiled tile with its dashed vermilion or dotted tan rim baked in (`LockedZoneOverlay`). Hover and pin are rim swaps, never glows: an open hex hovered gets the brighter rim; a veiled hex gets a thin inner rim on hover and a heavy one while pinned.
- **Routes.** `ZoneRoute` draws six 4×4 map-space dots, 12 map px apart, across the shared rim of two neighbouring hexes. Routes run from the current zone, neighbour to neighbour, to the other charted map zones, and on to the uncharted ones. Hovering a zone you can travel to turns the dots on its way cream, stopping at the first zone that is not open or current.
- **Markers.** `MapMarkers` places every marker each frame from the SubViewport's canvas transform. At zoom 2 each sits at the kit's offset from its hex centre; at other zooms only its anchor follows the hex (by zoom / 2) and the marker keeps its kit size, so no text drops under 13 px. Below zoom 1.25 a plate shows its name only and narrows to the name plus 16 px a side. The current zone's plate draws over its neighbours. The whole layer hides during the adventure zoom-in and returns once the camera is back at its resting zoom.
- **Character.** At scale 1 with a hard shadow, its top-left at the zone centre + (0, 19) map px (screen (960, 740) in Spirit Valley). Foraging wanders west and back (0 → −24 → −8 → 0 map px over the 5 s haul, phase-locked to the haul timer); the Aura Well bobs (0, −1, −2, −1 map px every 0.6 s). The travel walk stands on whole map px every physics frame (`snap_walk_to_whole_px`), so it moves in 2 screen px steps.

Plate lines (`ZoneMapLabel`):

| Map state | Name | Status line |
|---|---|---|
| Current | Brass (cream on hover) | The running idle action: "Aura Well · +1.5 Madra / s" with the well icon, "Foraging · a haul every 5 s" with the forage icon; the name alone, centred, when nothing idle runs |
| Open | Cream | "Open · N activities" in tan ("Open · 1 activity", "Open · nothing to do yet"); "Click to travel" in brass on hover |
| Locked | Cream | Swords icon + `ZoneData.blocker_short_text` |
| Uncharted | Tan until hovered | `blocker_short_text` in tan |

A long action name or blocker ellipsizes inside the plate's 228 px line slot; the icon and the rate stay whole.

#### Tile Variants

`ZoneData.tile_variant_index` picks one cell of the forest atlas:

- Atlas image: `assets/sprites/tilemap/hex_tiles/forest/hex_forest_atlas.png`.
- TileSet: `scenes/tilemaps/tilemap_tileset.tres`, source 8, 164×190 cells, alternative 0 only.
- `ZoneTilemap._get_zone_tile_atlas_coords()` maps index N to atlas cell `(N % 6, N / 6)`. An out-of-range index logs a warning and falls back to 0.

`scenes/tilemaps/scripts/pack_hex_atlas.py` generates the atlas. `FOREST_ATLAS_COLS` (6) and `FOREST_VARIANT_COUNT` (23) must match the script. The adventure map uses the same atlas through `HexForestAtlas.pick()`, and the fog picks from its natural pool with `HexForestAtlas.pick_from()` (`scripts/utils/hex_forest_atlas.gd`).

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
| `ZoneHexMarker` | `scenes/zones/zone_hex_marker/` (`Node2D`) | Current rim (`map/lacquer_hex_current_ai`), open hairline (`lacquer_hex_open_ai`), hover rim (`lacquer_hex_hover_ai`). `setup(state)`, `set_hovered()` |
| `LockedZoneOverlay` | `scenes/zones/locked_zone_overlay/` (`Node2D`) | Veiled tile for LOCKED or UNCHARTED (`map/lacquer_tile_locked_ai`, `lacquer_tile_uncharted_ai`, lighter on hover), inner rims `lacquer_hex_hover_in_ai` and `lacquer_hex_pinned_in_ai`. `setup(state)`, `set_hovered()`, `set_pinned()`. The veil art bakes the demo zones' tiles |
| `ZoneRoute` | `scenes/zones/zone_route/` (`Node2D`) | `set_points(from, to)`, `set_lit(lit)`; draws `map/lacquer_route_dot_ai` (lit: the cream dot) in `_draw()` |
| `ZoneMapLabel` | `scenes/zones/map_markers/zone_map_label/` | The plate. `setup(zone_data, state)`, `set_hovered()`, `set_pinned()` (brass frame), `set_name_only()`, `get_line_text()`; emits `pressed` |
| `MapGlyph` | `scenes/zones/map_markers/map_glyph/` | Padlock or "?" with a twinkle (frames 1, 2, 1 for 0.1, 0.2, 0.1 s every 4 s). `shake()` moves the icon 0, −8, 8, −6, 4, 0 px over 0.44 s, each step held |
| `MapActionRing` | `scenes/zones/map_markers/map_action_ring/` | 13-frame jade ring; frame `floor(progress × 13)`, at most 12, from `action_timer`. Shown only while an idle action runs |
| `MapFloater` | `scenes/zones/map_markers/map_floater/` | `pop(text, colour)` on `token.tres`; rises 40 px over 1 s in 2 px steps, then hides. Stops when the idle action changes |
| `ZoneMapPopover` | `scenes/zones/map_markers/zone_map_popover/` | Locked card (LOCKED chop, name, requirement; pinned: ×, "Show me ›") left of the hex, uncharted card (UNKNOWN) right of it. Emits `close_pressed`, `show_me_pressed(action_id)` |
| `MapPopoverState` | `scripts/ui/map_popover_state.gd` (`RefCounted`) | Hovered, preview and pinned zone ids. `click(zone_id, state)` returns TRAVEL, PIN, RECENTRE or CLOSE |
| `ZoneMapMath` | `scripts/utils/zone_map_math.gd` (statics) | `camera_position_for()`, `world_to_screen()`, `camera_window_for()`, `cell_to_cube()`, `fog_tier()`, `fog_art_index()`, the forage wander and training bob offsets |

### Camera

The zone camera is a plain `Camera2D` with the three shared controllers from `scenes/camera/`.

- `ZoneTilemap.frame_zone(zone, duration)` puts the zone's centre at screen (960, 702) at the current zoom (`ZoneMapMath.camera_position_for()`), at once on load and over `camera_ease_duration` (0.3 s, `TRANS_CUBIC` / `EASE_IN_OUT`) after travel or a recentre, then re-clamps (`CameraClampController.clamp_now()`).
- The clamp keeps at least one map zone's centre in the free map window between the panels (screen x 546–1374, y 95–881) at every zoom. Each map zone has a camera window (`ZoneMapMath.camera_window_for()`); `ZoneTilemap` hands them to `CameraClampController.clamp_regions` (with `clamp_centre_only`), which keeps the camera centre in the nearest one, and sets them again on every `CameraZoomController.zoom_changed`.
- `ZoneTransition` zooms to 3.0 when an adventure starts. `ZoneTransition.reset_camera()` restores the saved zoom and position over 0.3 s when `ZoneViewState.enter()` runs.

### Zone chest (`ZonePanel`)

- **Header.** The tile thumbnail, the zone name and About. About is hidden when `ZoneData.description` is empty (Test Zone). It opens the lore inline under the Now strip and pushes the Activities header and the list down 276 px.
- **Now strip** (`NowStrip`). Always shown, and it always keeps its space: the Activities header (screen y 204) and the list (232) never move up to take it (the user's review, 2026-10-22). While the current action is FORAGE or TRAIN_STATS, a 13-frame jade ring around the action icon fills over each timer cycle. Aura Well: name, "+1.5 Madra / s", "Lv n → n+1 · +1 Spirit", `<ticks in level> / <ticks for next>` and a rod (`steps 152`, from `TrainingActionData.get_ticks_in_level()` / `get_ticks_for_next_level()`). Foraging: name, each loot entry's mini icon and range, and "haul in N s". Clicking it emits `strip_pressed`. While no idle action runs the tray is empty: the ring at frame 0, no icon, rate or rod, and one tan `LabelLacquerDetail` line (`%EmptyLabel`, centred on the ring). It reads "<idle action> · paused" while a session action (the shop, cycling, an adventure, dialogue) stands in for the zone's idle action, naming the one `ActionManager.resolve_idle_action()` gives for the current zone (the one that resumes), or "Nothing running" when the zone has none (a fresh save, Test Zone). It refreshes on `current_action_changed` and on `condition_unlocked`, so an idle action that unlocks mid-session shows as paused. The empty tray ignores the mouse: no hover frame, no pointing hand, and a click does nothing.
- **Activity list** (`ActivityList`). `build(actions)` groups the cards with `ZoneActionGroups` under tan group labels (only non-empty groups). Flow: label row 18 + 6, cards 8 apart, groups 14 apart. An empty zone reads "Nothing to do here yet." The native scrollbar is hidden; `LacquerRail` stands in for it and shows only when the list overflows. Hard lips show at an edge the list is scrolled away from.
- **Sizing.** The chest hugs its content: `max(176, list top + list height + 24)`. A list too long for the space down to local 992 scrolls, folds 8 px under its last whole drawer (never a cut card), and the chest snaps to the bottom line (local 1032) when it ends within 64 px of it.
- **Focus.** `scroll_to_action(action_id)` scrolls only as far as needed to show the whole card with 24 px around it, then flashes the card's brass frame twice. `ZoneManager.action_focus_requested` and the Now strip call it.

| Rebuild trigger | Notes |
|---|---|
| `ZoneManager.zone_changed` | A new zone starts the list at the top; the same zone keeps its scroll |
| `ZoneManager.action_completed` | Drops actions that reached `max_completions` |
| `UnlockManager.condition_unlocked` | Adds newly unlocked actions; also fires with `""` on save reset |

Rebuilds are queued to the end of the frame, so several signals rebuild once.

### Activity cards and presenters

`ZoneActionButton` owns the drawer, the icon (`ZoneActionData.icon`), the title (ellipsized where the NEW seal or the tag starts), the NEW seal, the mode tag, the running state, hover, flash and click routing. It knows nothing about action types; a presenter, picked from `PRESENTER_SCENES` by `action_type` (else `DEFAULT_PRESENTER_SCENE`), fills the detail and footer slots.

Card behaviour:

- **Click.** Marks the action seen. On the running idle card it emits `card_pressed_while_running` (the list flashes the Now strip). A click on the current action does nothing. If `presenter.can_activate()` returns false, the card calls `presenter.on_activation_rejected()`. Otherwise it calls `ActionManager.select_action(action_data)`.
- **Hover.** Shows the hover frame (`frame_hover.tres`) and marks the action seen, which hides NEW.
- **Running.** Only an idle action that runs: the drawer moves to (−2, −2) on `lacquer_drawer_run_ai` and the tag reads RUNNING in cream. Re-checked on every `ActionManager.current_action_changed`.
- **Tall drawer.** `set_tall(true)` uses the 96 px drawer. A non-idle card whose detail is wider than 316 px wraps it onto two lines in the tall drawer (`fit_detail_label()`); an idle card's line ellipsizes instead. The adventure card no longer uses it (the user's review, 2026-10-22).
- **Ready frame.** `set_ready_frame(true)` shows the brass frame (`frame_brass.tres`, `%ReadyFrame`) over the card, steadily: the adventure at its threshold. It replaced the tall drawer's brass-edged face. `flash()` hides it while the flash runs (1.2 s), since the flash is the same frame, then shows it again; a Madra tick mid-flash does not bring it back early.
- **Helpers for presenters.** `set_mode_tag(text, style)` (CARVED, RUNNING, ENTER), `get_detail_slot()`, `get_footer_slot()`, `set_tall()`, `set_ready_frame()`, `fit_detail_label()`, `fit_detail_rich_text()` (RichTextLabel lines with a Yatra decimal point, cut at a word with "…"), `flash()`, `is_new_shown()`.

`ZoneActionPresenter` (`scripts/ui/zone_action_presenter.gd`) is an `@abstract` `Node`:

- Abstract methods: `setup(data, owner_button)` and `teardown()`.
- Overridable hooks: `set_is_current()`, `can_activate()` (default `true`) and `on_activation_rejected()`.

| Presenter | Scene | Action types | Detail line | Behaviour |
|---|---|---|---|---|
| `ForagingPresenter` | `presenters/foraging_presenter.tscn` | FORAGE | One `ForageYield` per loot entry (the item's `get_mini_icon()` and "min–max"), then "every 5 s · free" ("· N Madra / s" when `madra_cost_per_second > 0`) | Static; the haul timer lives in the Now strip and on the map |
| `TrainingPresenter` | `presenters/training_presenter.tscn` | TRAIN_STATS | "+1.5 Madra / s · each level +1 Spirit" (from `get_madra_per_second()` and the first `AwardAttributeEffectData` in `effects_on_level`) | Static; progress lives in the Now strip |
| `AdventurePresenter` | `presenters/adventure_presenter.tscn` | ADVENTURE | Below the threshold, the `NeedGroup` row in the footer slot: `mini_madra` (x+64, y+38), the Madra rod (x+86, y+40, `steps 74`), then `<madra> / <threshold>` (`MadraFigure`, tan) at x+248 and, only while `ActionManager.get_current_madra_per_second() > 0`, `~<n> s` (`HintLabel`, cream, right edge x+380). At it: "<minutes> min run · carries <capacity> Madra" in brass on the detail line (`ReadyText`, ellipsized past 316 px), the ready frame and the ENTER tag | 72 px in both states. Refreshes on `madra_changed`, `current_action_changed`, `base_attribute_changed` and `InventoryManager.inventory_changed` (gear changes capacity). `can_activate()` = `ResourceManager.can_start_adventure()`; a rejected click shakes the Madra row in even-px steps and logs `Not enough Madra!` |
| `CyclingPresenter` | `presenters/cycling_presenter.tscn` | CYCLING | "<equipped technique> · Madra and Core Density XP"; follows the equipped technique | The fresh save's "Foundational Technique" wraps in the tall drawer |
| `MerchantPresenter` | `presenters/merchant_presenter.tscn` | MERCHANT | "<n> wares · you have <gold> gold" (stock lines not yet sold out) | Follows gold and purchases |
| `DefaultZoneActionPresenter` | `presenters/default_presenter.tscn` | NPC_DIALOGUE, ZONE_EVENT, any other | The action's description | Tag STORY |

### Cultivator cabinet and dock

- **`CultivatorPlate`** (`scenes/zones/cultivator_plate/`, kit §5.1). The Madra orb is the empty frame of its strip under `assets/shaders/lacquer_madra_orb.gdshader`, filled to `Madra / max`, with `Madra / max` beside it; `max` is `CultivationManager.get_max_madra()` (100 + 5 × Core Density level at Foundation). The rate `+1.5 / s` shows only while `ActionManager.get_current_madra_per_second() > 0`. The core orb is a column of its strip under `assets/shaders/lacquer_core_orb.gdshader`, filled to `min(level, 100) / 100`: column 0 (the dormant pebble, no fill) at level 0, column 1 (the empty socket) from level 1. Beside it are the stage name, `Level N`, 18 XP beads (`floor(xp × 18 / need)`, so a bead lights only once its share is earned and the beads never run ahead of the floored figure) and `xp / need XP`. Gold is one right-aligned row (coin, number, `gold`) ending at the cabinet's right text edge (screen x 446). The script only sets each orb material's `progress`; the shaders animate on their own (see [Orb shaders](#orb-shaders)). It reads everything once on `_ready`, then follows `madra_changed`, `gold_changed`, `core_density_xp_updated`, `core_density_level_updated`, `advancement_stage_changed` and `current_action_changed`. `get_madra_orb_global_position()` is where `ZoneTransition` starts its drain.
- **`Dock`** (`scenes/ui/dock/`) holds the four `SystemMenuButton`s and decides their notifications. Navigation behaviour is documented in [MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md#dock-and-systemmenubutton).

#### Orb shaders

The two cabinet orbs are the only shaders in the lacquer zone view. They take the cycling view's orbs (`liquid_wave`, `core_density_fill`) as their model but keep the kit's pixel rules (kit §1): each works out its colour per 2 px art cell (40x40 cells on the 80 px orb, from the rect's local position), uses only the Madra ramp, and steps time 10 times a second (`steps_per_second`), so the motion reads as hand-drawn frames. Wherever they draw nothing, the strip frame underneath shows, so the brass rim and the carved socket stay crisp. Each `ShaderMaterial` is local to its scene.

| Shader | `progress` | What it draws |
|---|---|---|
| `lacquer_madra_orb` | `Madra / max` | A liquid in the socket (cells within √249 of the centre, rows 4–35): a surface of two summed sine waves with a 1 cell `#E8F6FD` crest and a `#849BE4` line under it, three 1 cell bubbles rising, a slanted sheen sliding across every 4 s, three undulating `#849BE4` current dashes drifting under the surface, a darker lower-right ring and a wavy deep band at the bottom. 1 fills the socket with no crest; 0 draws nothing |
| `lacquer_core_orb` | `min(level, 100) / 100` | A disc from radius 2.5 cells (level 1) to 15.78 (level 100, the socket's rim): a two-arm spiral in three bands (`#BBD5E7`, `#849BE4`, `#1C2F60`) turning once every 12 s, a `#E8F6FD` core and a 1 cell `#E8F6FD` edge. 0 draws nothing, so the dormant pebble shows |

## Data Model

### ZoneData

`scripts/resource_definitions/zones/zone_data/zone_data.gd`

| Field | Type | Default | Notes |
|---|---|---|---|
| `zone_name` | `String` | `""` | Chest header, map plate, popover title, travel log line |
| `zone_id` | `String` | `""` | Key for save data and lookups |
| `description` | `String` (multiline) | `""` | The lore behind About (plain text, paragraphs split on blank lines). Empty hides About |
| `icon` | `Texture2D` | `null` | No code reads it |
| `zone_unlock_conditions` | `Array[UnlockConditionData]` | `[]` | Every condition must be latched for the zone to unlock (LOCKED until then) |
| `all_actions` | `Array[ZoneActionData]` | `[]` | Also sets card order within a group |
| `tilemap_location` | `Vector2i` | `(0, 0)` | Hex cell |
| `tile_variant_index` | `int` | `0` | Forest atlas variant (see [Tile Variants](#tile-variants)). 6 (River) also picks the river thumbnail |
| `hidden_on_map` | `bool` | `false` | Keeps the zone off the map unless the dev panel shows hidden zones. Saves that name it stay valid |
| `chart_conditions` | `Array[UnlockConditionData]` | `[]` | While any is unlatched the map shows the zone as UNCHARTED, whatever its unlock conditions say |
| `blocker_short_text` | `String` | `""` | The locked or uncharted plate's status line |
| `requirement_text` | `String` (multiline) | `""` | The popover's requirement sentence |
| `requirement_action_id` | `String` | `""` | The card "Show me ›" scrolls to. Empty: no Show me |

`ZoneDataList` (`zone_data_list.gd`) has `list: Array[ZoneData]` and `get_zone_data_by_id(zone_id) -> ZoneData`. `ZoneManager._all_zone_data` preloads the catalog from `resources/zones/zone_data_list.tres`. `list[0]` is the starting zone. The demo zones load from `ZoneManager.DEMO_ZONE_PATHS` and never enter the list.

### ZoneActionData

`scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd`

| Field | Type | Default | Notes |
|---|---|---|---|
| `action_id` | `String` | `""` | Key for completion counts, training ticks, the last idle action and the seen record |
| `action_name` | `String` | `""` | Card title, Now strip, plate line, log lines |
| `action_type` | `ActionType` | `FORAGE` | Selects the handler, presenter, group and mode tag |
| `description` | `String` (multiline) | `""` | The story cards' detail line |
| `icon` | `Texture2D` | `null` | The card icon, the Now strip and the map ring. Set on every Spirit Valley action (`assets/ui/lacquer/icons/ic_*_ai.png`; the adventure uses the user's `combat_icon.png`) |
| `unlock_conditions` | `Array[UnlockConditionData]` | `[]` | Every condition must be latched |
| `max_completions` | `int` | `0` | 0 = unlimited. N = the action is hidden once `action_completion_count >= N` |
| `success_effects` | `Array[EffectData]` | `[]` | Run by `stop_action(true)`, and when another action replaces this one |
| `failure_effects` | `Array[EffectData]` | `[]` | Run by `stop_action(false)` |

### ActionType

| Value | Enum | Data class | Handler | Presenter | Group / tag | Status |
|---|---|---|---|---|---|---|
| 0 | `FORAGE` | `ForageActionData` | `_execute_forage_action`: repeating timer, loot roll | `ForagingPresenter` | Gather / IDLE | Implemented |
| 1 | `ADVENTURE` | `AdventureActionData` | `_execute_adventure_action`: `adventure_start_requested` (`select_action()` checked the Madra first) | `AdventurePresenter` | Venture / ACTIVE | Implemented |
| 2 | `NPC_DIALOGUE` | `NpcDialogueActionData` | `_execute_dialogue_action`: Dialogic timeline | Default | Talk / STORY | Implemented |
| 3 | `MERCHANT` | `MerchantActionData` | `_execute_merchant_action`: emits `start_merchant`; the shop's Leave or Escape calls `stop_action()` | `MerchantPresenter` | Visit / SHOP | Implemented |
| 4 | `TRAIN_STATS` | `TrainingActionData` | `_execute_train_action`: repeating tick timer | `TrainingPresenter` | Cultivate / IDLE | Implemented |
| 5 | `CYCLING` | `CyclingActionData` | `_execute_cycling_action`: `start_cycling` | `CyclingPresenter` | Cultivate / ACTIVE | Implemented |
| 6 | `ZONE_EVENT` | — | None. `_execute_action()` logs "Unknown action type" | Default | Visit / STORY | Not implemented |

FORAGE and TRAIN_STATS are the **idle** types; every other type is a **session** action. If the data class doesn't match the type (for example `action_type = FORAGE` on a resource that isn't a `ForageActionData`), the handler logs an error and does nothing. Only `AdventureActionData._init()`, `TrainingActionData._init()` and `MerchantActionData._init()` set `action_type`; the other subclasses rely on the value saved in the `.tres`.

### Subclasses

| Class | Field | Type | Default | Read by |
|---|---|---|---|---|
| `ForageActionData` | `loot_table` | `LootTable` | `null` | `ActionManager._on_forage_timer_finished()`, the forage card and the Now strip |
| | `madra_cost_per_second` | `float` | `0.0` | The forage card's detail line only; foraging costs no Madra |
| | `foraging_interval_in_sec` | `float` | `5.0` | `action_timer.wait_time`, the card and the plate line |
| `CyclingActionData` | `madra_multiplier`, `cycle_duration_modifier`, `xp_multiplier` | `float` | `1.0` | Nothing. `CyclingView.initialize_cycling_action_data()` is never called ([CYCLING.md](../cycling/CYCLING.md)) |
| | `madra_cost_per_cycle` | `float` | `0.0` | Nothing |
| `AdventureActionData` | `adventure_data` | `AdventureData` | `null` | `AdventureTilemap.start_adventure()` |
| | `time_limit_seconds` | `int` | `10` | `AdventureView.start_adventure()` (a value ≤ 0 falls back to 10) and the ready card's "<minutes> min run" |
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
| `MerchantActionData` | `stock` | `MerchantStock` | `null` | `MerchantView` rows, `MerchantManager` purchases, the merchant card's ware count |
| | `greeting` | `String` (multiline) | `""` | Flavour text under the shop title, in smaller text that wraps across the header; hidden when empty |
| | `shop_theme` | `Theme` | `null` | `MerchantView.setup()` sets it as the shop's root theme; null keeps the scene default (Spirit Valley) |

`AdventureActionData.is_valid()` exists but nothing calls it.

`TrainingActionData` pure functions (unit-tested):

| Method | Returns |
|---|---|
| `get_ticks_required_for_level(level)` | Incremental cost of `level`. Returns 0 for level ≤ 0 or an empty array; uses the rounded tail formula beyond the array |
| `get_current_level(accumulated_ticks)` | Highest level whose cumulative cost ≤ the ticks (always 0 for an empty array) |
| `get_progress_within_level(accumulated_ticks)` | Progress toward the next level, 0.0–1.0 |
| `get_madra_per_second()` | Sum of the MADRA `AwardResourceEffectData` amounts in `effects_per_tick`, divided by `tick_interval_seconds` |
| `get_ticks_in_level(accumulated_ticks)`, `get_ticks_for_next_level(accumulated_ticks)` | The Now strip's `214 / 300` |

### Save data

`ZoneProgressionData` (`singletons/persistence_manager/zone_progression_data.gd`) is stored once per zone id in `SaveGameData.zone_progression_data`.

| Field | Type | Notes |
|---|---|---|
| `zone_id` | `String` | |
| `action_completion_count` | `Dictionary[String, int]` | `action_id` → number of times the action was stopped (see [Action lifecycle](#action-lifecycle)) |
| `training_tick_progress` | `Dictionary[String, int]` | `action_id` → accumulated training ticks |
| `last_idle_action_id` | `String` | The idle action last started in the zone; it resumes there while still available |
| `forage_active` | `bool` | Never set; only printed by `_to_string()` |
| `forage_start_time` | `float` | Never set; only printed by `_to_string()` |

`SaveGameData` zone fields and helpers:

- `current_selected_zone_id: String`. The empty default resolves to `list[0]`.
- `zone_progression_data: Dictionary[String, ZoneProgressionData]`.
- `seen_action_ids: Array[String]` and `seen_actions_initialized: bool`. The first initialisation of a save marks every action available at that moment as seen, so an older save does not light NEW on every card.
- `get_zone_progression_data(zone_id)` creates the entry on demand.
- `increment_zone_progression_for_action(action_id, zone_id, quantity) -> int`.
- `migrate()`, with `ZONE_ID_MIGRATIONS = {"TestZone": "SpiritValley"}`: a save standing in the now hidden Test Zone moves to Spirit Valley.

On load, `PersistenceManager._ready()` calls `migrate()`, then `SaveGameData.verify()`, which fails if `current_selected_zone_id` names a zone that `ZoneManager.has_zone()` doesn't know. A failed check resets the whole save. The current action is not saved, but the load's `zone_changed` resolves and starts the zone's idle action (usually the last one). `SaveTimer` autosaves every 5 s. See [PERSISTENCE.md](../infrastructure/PERSISTENCE.md).

## Core Systems / Flows

### Action lifecycle

```
Card click
  └─ ActionManager.select_action(action)
       ├─ ZoneManager.mark_action_seen(action.action_id)
       ├─ ADVENTURE and not ResourceManager.can_start_adventure() → return (nothing stops)
       ├─ _stop_executing_current_action(true)           # only if something is running
       │     ├─ ZoneManager.increment_zone_progression_for_action(old.action_id, zone it started in)   # only in the save it started under
       │     │     └─ action_completed(action_id)         # if max_completions > 0 and count >= max
       │     └─ _stop_<type>_action(true): stop_* signal, timer reset, success_effects
       ├─ _set_current_action(action) → current_action_changed   # remembers its save and zone
       ├─ idle action → ZoneManager.set_last_idle_action_id(zone, action_id)
       └─ _execute_action(action) → per-type handler

ActionManager.stop_action(successful = true)
  ├─ _stop_executing_current_action(successful): count +1, stop_* signal, success_ or failure_effects
  ├─ clear_current_action() → current_action_changed(null)
  └─ the stopped action was a session action → _resume_idle_action(): resolve, select, log "Resumed <name>"
```

Idle action resolution (`resolve_idle_action(zone_id)`): the zone's saved last idle action while it is still in `get_available_actions()` and idle; else the first idle action in `ZoneActionGroups.sort_actions()` order (so the Aura Well before foraging); else null. It runs:

| When | Handler | Log line |
|---|---|---|
| A session action stops | `stop_action()` → `_resume_idle_action()` | "Resumed <name>" |
| `ZoneManager.zone_changed` (load, travel, save reset) | `_on_zone_changed()`: stops what runs, resolves, selects. A repeat for the same zone whose idle action already runs in the live save changes nothing | Travel: "Travelled to <zone> · resumed <name>", or "Travelled to <zone>". Otherwise "Resumed <name>" |
| `UnlockManager.condition_unlocked` (non-empty id) while nothing runs | `_on_condition_unlocked()` | "Started <name>" |

What ends an action:

| Caller | When | `successful` |
|---|---|---|
| `ActionManager.select_action()` | Another action starts (stops the old one without clearing) | `true` |
| `ActionManager._on_zone_changed()` | `ZoneManager.zone_changed` (arrival, load, save reset) | `true` |
| `DialogueManager.dialogue_ended` (one-shot, connected in `_execute_dialogue_action`) | The Dialogic timeline ends | `true` |
| `CyclingViewState.handle_input()` | `close_cycling_view` (Escape) | `true` |
| `AdventureTilemap.handle_combat_result()` | Boss combat won | `true` |
| `AdventureView._on_stop_combat()` | Combat lost | `false` |
| `AdventureView._on_adventure_timer_timeout()` | Time limit reached | `false` |
| `MerchantViewState` (Leave button or Escape) | The player leaves the shop; it stops only a merchant action | `true` |

Every stop adds 1 to `action_completion_count`, under the zone the action started in and only in the save it started under (a save reset swaps the save first, so that stop counts nothing). This happens whether the action succeeded, failed or was replaced, so `max_completions` counts attempts, not successes.

### Signals

`ZoneManager`:

| Signal | Emitted by | Listeners |
|---|---|---|
| `zone_changed(zone_data)` | `set_current_zone_by_id()`; `_initialize_from_save()` on save reset | `ActionManager._on_zone_changed` (stops and resolves), `ZonePanel` (rebuild), `ZoneTilemap` (rebuild; a change it did not make snaps the character and camera there) |
| `action_completed(action_id)` | `increment_zone_progression_for_action()` | `ZonePanel`, `MapMarkers` (plate counts) |
| `map_zones_changed()` | `set_demo_zones_visible()`, `set_hidden_zones_visible()` | `ZoneTilemap` (rebuild; a walk whose target left the map ends where it began) |
| `action_focus_requested(action_id)` | `request_action_focus()` | `ZonePanel.scroll_to_action()` |

`ActionManager`:

| Signal | Emitted by | Listeners |
|---|---|---|
| `current_action_changed(action_data)` | `_set_current_action()` | Every action card, `NowStrip`, `CultivatorPlate` (rate), `MapMarkers` (ring, plate line), `ZoneTilemap` (idle motion), `AdventurePresenter` |
| `start_foraging(action_data)` (emitted with no argument) | `_execute_forage_action()` | `ZoneTilemap` (wander) |
| `foraging_completed(items: Dictionary)` | Every forage timeout | `ZoneTilemap` (wander), `MapMarkers` (haul floater) |
| `stop_foraging()` | `_stop_forage_action()` | `ZoneTilemap` (character returns to its stand) |
| `start_cycling(action_data)` | `_execute_cycling_action()` | `CyclingViewState` (pushes the cycling view) |
| `stop_cycling()` | `_stop_cycling_action()` | `CyclingViewState` (pops), `CyclingView` |
| `adventure_start_requested(action_data)` | `_execute_adventure_action()` | `ZoneViewState` (input blocker), `ZoneTransition`, `MapMarkers` (hides) |
| `start_adventure(action_data, madra_budget)` | `confirm_adventure_start()` | `AdventureViewState` (change state), `AdventureView.start_adventure` |
| `stop_adventure()` | `_stop_adventure_action()` | `AdventureView.stop_adventure` (→ `adventure_completed` → end card), `AdventureViewState` (no-op) |
| `start_training(action_data)`, `stop_training()` | Training start / stop | `ZoneTilemap` (bob) |
| `training_tick_processed(action_data, new_tick_count)` | Every training tick | `NowStrip`, `MapMarkers` ("+1.5 Madra" floater) |
| `training_level_gained(action_data, new_level)` | Once per level crossed | `NowStrip` |
| `start_merchant(action_data)` | `_execute_merchant_action()` | `MerchantViewState` (binds the shop, pushes the overlay) |
| `stop_merchant()` | `_stop_merchant_action()` | `MerchantViewState` (fades the shop out, then removes only itself from the stack; closes at once if another view sits above the shop) |

Other signals the zone code consumes:

- `UnlockManager.condition_unlocked` (`ActionManager`, `ZonePanel`, `ZoneTilemap`).
- `tile_clicked`, `tile_hovered` and `tile_unhovered` from `scenes/tilemaps/hexagon_tile_map_layer.gd`, on both map layers (`ZoneTilemap`).
- `ResourceManager.madra_changed` (`AdventurePresenter`, `CultivatorPlate`) and `gold_changed` (`CultivatorPlate`, `MerchantPresenter`).
- `PersistenceManager.save_data_reset` (`ZoneTilemap` ends a walk, `MapMarkers` closes the popover).

`ZoneTilemap.zone_selected(zone_data, tile_coord)` is emitted when a walk starts, but nothing listens to it.

### Zone selection (travel)

```
hexagon_tile_map_layer.gd _input (left click on a cell)           or a plate press (MapMarkers.plate_pressed)
  └─ tile_clicked(coord) → ZoneTilemap._on_zone_tile_clicked → click_zone(zone)
       └─ MapMarkers.click_zone(zone_id) → MapPopoverState.click(zone_id, map state)
            ├─ TRAVEL (open zone): close the popover; _travel_to(zone)
            │     ├─ zone_selected.emit (no listeners)
            │     └─ PlayerCharacter.move_to_position(stand, 275 map px/s, whole-px steps)   # the old action keeps running
            │           └─ movement_completed → _arrive(zone)
            │                 ├─ selected_zone setter → ZoneManager.set_current_zone → zone_changed
            │                 │     ├─ ActionManager: stop, resolve the idle action, log "Travelled to …"
            │                 │     └─ ZonePanel rebuild; ZoneTilemap rebuild (rims, fog, routes, plates)
            │                 └─ frame_zone(zone, 0.3 s) → clamp_now()
            ├─ PIN (locked / uncharted): pin the popover; a locked glyph shakes
            ├─ RECENTRE (current zone): frame_zone; a walk in progress turns back home
            └─ CLOSE (fog): close the popover
```

A second click during a walk retargets it. Cycling, an adventure, dialogue or the merchant starting mid-walk, a save reset, or a zone change from outside end the walk where it began (or snap the character to the real current zone), so there is always one current zone and one running action. The completion of the action that travel stops counts in the zone it started in.

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
   3. Runs `effects_per_tick`. The Aura Well trickle (`AwardResourceEffectData`, `quiet = true`) adds Madra without a log line.
   4. Emits `training_tick_processed(action, new_ticks)`.
   5. For each level from `prev_level + 1` to `new_level`: runs `effects_on_level`, then emits `training_level_gained(action, level)`.
3. On stop, `stop_training` is emitted, the timer resets and the completion effects run. Ticks stay in `training_tick_progress`, so the next session continues from the same total.

### Adventure start (zone side)

The full sequence and the Madra numbers are in [ADVENTURING.md § Starting an Adventure](../adventuring/ADVENTURING.md#starting-an-adventure). Zone side:

1. `AdventurePresenter.can_activate()` gates the click on `ResourceManager.can_start_adventure()`. Madra must be at least 50% of the adventure capacity, `get_adventure_madra_capacity()` = `CharacterManager.get_total_attributes_data().get_max_madra()` = total FOUNDATION × 10. This is not the Madra pool cap.
2. `select_action()` checks again before it stops anything. On failure it writes a `Log.info` line and returns, so the running idle action keeps going. On success `_execute_adventure_action()` emits `adventure_start_requested(action)`. That signal carries no budget.
3. `ZoneViewState` adds a full-rect `MOUSE_FILTER_STOP` Control over `ZoneView` and ignores input actions while it exists. `MapMarkers` hides.
4. `ZoneTransition._on_adventure_start_requested()`:
   - computes the budget, `ResourceManager.get_adventure_madra_budget()` = `min(capacity, current Madra)`;
   - spends it through `spend_madra()` as 8–25 `MadraPellet`s (opaque Madra-blue pellets with an ink outline, on even screen px) flying from the cabinet's Madra orb to the character;
   - zooms the camera to 3.0 on the character over 0.5 s;
   - calls `ActionManager.confirm_adventure_start(action, budget)`, which emits `start_adventure(action, budget)`.
5. `start_adventure` triggers `AdventureViewState.change_state()`, whose `ZoneViewState.exit()` removes the blocker, and `AdventureView.start_adventure()`.
6. When the player leaves the end card (`change_state(zone_view_state)`), `ZoneViewState.enter()` calls `ZoneTransition.reset_camera()`. The adventure's stop already resumed the zone's idle action.

### Cycling, dialogue, merchant

- **Cycling.** `start_cycling(action)` makes `CyclingViewState` push the cycling view. Escape calls `stop_action()`, which emits `stop_cycling`; the view is popped and the idle action resumes. The `CyclingActionData` never reaches the view. See [CYCLING.md](../cycling/CYCLING.md).
- **NPC dialogue.** The handler connects `DialogueManager.dialogue_ended` to `stop_action` (one-shot), then calls `DialogueManager.start_timeline(dialogue_timeline_name, dialogue_timeline_label_jump)`. When the timeline ends, the success effects run (events and quest starts), the one-time card disappears, and the idle action resumes.
- **Merchant.** `_execute_merchant_action()` emits `start_merchant(action)`. `MerchantViewState` binds the action's stock to `MerchantView` and pushes the overlay, which fades in with the grey backdrop and hides the log and Goals boards; a second `start_merchant` while the shop is open only rebinds the stock. The action stays current while the shop is open. Leave (`MerchantView.close_requested`) or Escape calls `stop_action()` while the merchant is the current action, which emits `stop_merchant` and resumes the zone's idle action at once. The state fades the shop out, then removes only itself from the stack (`MainView.remove_state()`), so a view pushed during the fade stays open. If another view already sits above the shop, the shop closes at once without the fade. Each visit adds 1 to the completion count; no effects are authored. Purchases go through `MerchantManager` (see [RESOURCES.md](../infrastructure/RESOURCES.md#gold-sink-the-merchant)).

### Unlock gating

- `ZoneManager.get_available_actions(zone_id)` returns `[]` if the zone's `zone_unlock_conditions` aren't met. Otherwise it returns every action whose `unlock_conditions` are met and whose completion count is below `max_completions` (or whose `max_completions` is 0).
- `get_zone_map_state()` reads `chart_conditions` and `zone_unlock_conditions` the same latched way.
- `UnlockManager.are_unlock_conditions_met()` only checks ids that are already latched in `UnlockProgressionData.unlocked_condition_ids`. It never evaluates a condition itself.
- Conditions latch in `UnlockManager._evaluate_all_conditions()`. That function only walks `resources/unlocks/unlock_condition_list.tres`, and only runs on these signals:
  - `EventManager.event_triggered`
  - `CultivationManager.advancement_stage_changed` and `core_density_level_updated`
  - `ResourceManager.madra_changed` and `gold_changed`

  A condition used by a zone or action must be registered in that list, or it never unlocks. The demo zones rely on this: their `dev_never_unlocked_condition.tres` is deliberately left out of the list. See [QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md](../progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md) and [UNLOCKS.md](../infrastructure/UNLOCKS.md).
- Latches are permanent. For example, the Madra-100 gate on dialogue 2 stays open after the Madra is spent.
- The `ZONE_UNLOCKED` and `ADVENTURE_COMPLETED` condition types log a warning and return false. Zone gates must use events, cultivation level or stage, resources, items or attributes instead.
- The dev panel's `UnlockManager.force_unlock_condition()` latches any listed condition, and the map and chest refresh.

## Integration Points

| System | Connection |
|---|---|
| `MainView` / `ZoneViewState` | The zone view is the initial base state. `ZoneViewState` routes I / P / A / C, places the Goals and log boards, and blocks input during the adventure transition ([MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md)) |
| `UnlockManager` | Gates zones and actions; `condition_unlocked` rebuilds the map and the chest, and can auto-start a first idle action |
| `EventManager` | Dialogue success effects fire `TriggerEventEffectData` events, which latch conditions |
| `QuestManager` | Dialogue success effects start quests (`StartQuestEffectData`). Quest completions fire the events that gate later actions ([FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md)) |
| `DialogueManager` / Dialogic | NPC dialogue actions run timeline labels; `dialogue_ended` stops the action |
| `CyclingViewState` / `CyclingView` / `CyclingManager` | Driven by `start_cycling` and `stop_cycling`; the cycling card reads the equipped technique |
| `AdventureViewState` / `AdventureView` / `AdventureTilemap` | Driven by `start_adventure` and `stop_adventure`. Adventure code calls `stop_action(true/false)`. Adventure encounters fire `aura_well_discovered` and `merchant_discovered` |
| `AdventureCombat` | Fires `q_first_steps_enemy_defeated` on any combat win (this gates dialogue 3); reads `gold_multiplier` |
| `ResourceManager` | Adventure Madra gate, budget and drain; the quiet training Madra trickle (`AwardResourceEffectData`); the cabinet and merchant card |
| `CharacterManager` / `InventoryManager` | Training attribute grants (`AwardAttributeEffectData`); total FOUNDATION (equipment included) × 10 sets the adventure capacity; forage loot via `award_items()`; items' `mini_icon` |
| `CultivationManager` | Cabinet stage, level, XP and `get_max_madra()`; `BREAKTHROUGH_LEVEL` for the Goals milestone; the `q_reach_cd_10` gate |
| `PersistenceManager` | `current_selected_zone_id`, `zone_progression_data`, `seen_action_ids`; `migrate()` before `verify()`; a save reset re-emits `zone_changed` |
| `LogManager` | "Resumed", "Travelled to", "Started" lines; adventure rejection messages |
| `MerchantViewState` / `MerchantView` / `MerchantManager` | Driven by `start_merchant` and `stop_merchant`. The shop calls `stop_action()` on Leave or Escape and buys through `MerchantManager` |
| Dev panel | `UnlockManager.force_unlock_condition()`; the Zones toggles call `ZoneManager.set_demo_zones_visible()` and `set_hidden_zones_visible()` ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md)) |

## Existing Content

### Zones

`resources/zones/zone_data_list.tres`

| Order | `zone_id` | Name | `tilemap_location` | Variant | On map | Unlock | Actions |
|---|---|---|---|---|---|---|---|
| 0 (start) | `SpiritValley` | Spirit Valley | (0, 0) | 6 River | Yes | None | 9 |
| 1 | `TestZone` | Test Zone | (-1, 0), west of Spirit Valley | 0 Basic | Hidden (`hidden_on_map`); the dev panel shows it | `celestial_intervener_dialogue_1` | None; no description, so no About |

Dev demo zones, `resources/zones/dev/` (never in the list, shown by the dev panel's "Demo zones" toggle):

| `zone_id` | Name | `tilemap_location` | Variant | State | Plate / popover |
|---|---|---|---|---|---|
| `AdvancementZoneDemo` | Advancement Zone | (0, -1), north-east of Spirit Valley | 20 Stones | LOCKED (unlock condition `dev_demo_never_unlocked`) | "Tribulation Guardian"; "Defeat the Tribulation Guardian in The Shallow Woods", Show me → `shallow_woods_adventure_action` |
| `UnchartedZoneDemo` | Uncharted | (0, -2), due north beyond it | 8 Mountains2 | UNCHARTED (chart condition `dev_demo_never_unlocked`) | "After the Tribulation"; "Revealed after the Tribulation." |

### Spirit Valley actions

`resources/zones/spirit_valley_zone/zone_actions/`, in `all_actions` order:

| # | `action_id` | Name | Type | Unlock condition | Max | Config | Success effects |
|---|---|---|---|---|---|---|---|
| 1 | `wilderness_cycling_action` | `Wilderness Cycling` | CYCLING | `celestial_intervener_dialogue_1` | 0 | All modifiers at defaults (1.0 / 1.0 / 1.0 / 0.0) | — |
| 2 | `celestial_intervener_dialogue_1` | `Talk to the [INTERVENER]` | NPC_DIALOGUE | None | 1 | `celestial_intervener_introduction_1` @ `dialogue_1` | Event `celestial_intervener_dialogue_1`; start `q_fill_core` |
| 3 | `sprint_forest_foraging_action` | `Spring Forest Foraging` | FORAGE | `q_fill_core_completed` | 0 | 5.0 s interval, 0 Madra/s, `loot_table/test_loot_table_foraging.tres` | — |
| 4 | `shallow_woods_adventure_action` | `The Shallow Woods` | ADVENTURE | `q_fill_core_completed` | 0 | `resources/adventure/data/shallow_woods.tres`, 300 s limit, other modifiers at defaults | — |
| 5 | `celestial_intervener_dialogue_2` | `Return to the [INTERVENER]` | NPC_DIALOGUE | `q_fill_core_madra_full` | 1 | Label `dialogue_2` | Event `celestial_intervener_dialogue_2`; start `q_first_steps` |
| 6 | `aura_well_training` | `Aura Well` | TRAIN_STATS | `aura_well_discovered` | 0 | 1.0 s ticks, `[60, 300, 600, 1200]`, tail 2.0; +1.5 Madra per tick (quiet); +1 Spirit per level | — |
| 7 | `celestial_intervener_dialogue_3` | `Return to the [INTERVENER]` | NPC_DIALOGUE | `q_first_steps_enemy_defeated` | 1 | Label `dialogue_3` | Event `celestial_intervener_dialogue_3`; start `q_reach_core_density_10` |
| 8 | `celestial_intervener_dialogue_4` | `Return to the [INTERVENER]` | NPC_DIALOGUE | `q_reach_cd_10` | 1 | Label `dialogue_4` | Event `celestial_intervener_dialogue_4` |
| 9 | `spirit_valley_merchant` | `Traveling Merchant` | MERCHANT | `merchant_discovered` | 0 | `MerchantActionData`: `resources/merchants/spirit_valley_merchant_stock.tres` (7 entries), `spirit_valley_merchant_theme.tres` | — |

In the chest these show grouped: Talk (the dialogues), Cultivate (Wilderness Cycling, Aura Well), Gather (Spring Forest Foraging), Venture (The Shallow Woods), Visit (Traveling Merchant). With both idle actions unlocked and none saved, the Aura Well resolves first.

Notes:

- The Aura Well effects live in `aura_well_madra_trickle_effect.tres` (`AwardResourceEffectData`, MADRA 1.5, `quiet = true`) and `aura_well_spirit_award_effect.tres` (`AwardAttributeEffectData`, SPIRIT 1.0).
- Icons: cycling `ic_cycle_ai`, foraging `ic_forage_ai`, Aura Well `ic_well_ai`, merchant `ic_merchant_ai`, dialogues `ic_story_ai` (all in `assets/ui/lacquer/icons/`), adventure the user's `assets/sprites/ui/stat_icons/combat_icon.png`.
- No action defines `failure_effects`.
- The `action_id` `sprint_forest_foraging_action` misspells "spring", and it is now a save key.

#### Spring Forest loot

`loot_table/test_loot_table_foraging.tres`

| Item | `item_id` | Drop chance | Quantity | Mini icon |
|---|---|---|---|---|
| Dewdrop Tear | `DewdropTear` | 100% | 1–5 | `lacquer_mini_dewdrop_ai` |
| Spirit Fern | `SpiritFern` | 100% | 2–6 | `lacquer_mini_fern_ai` |

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

The trickle gives 90 Madra/min. `ResourceManager.add_madra()` clamps the total to the stage cap, and writes no log line for the quiet trickle.

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

`resources/zones/dev/dev_never_unlocked_condition.tres` (EVENT_TRIGGERED, `dev_demo_never_unlocked`) is not registered, so it never latches: the demo zones stay locked and uncharted.

### Unlock chain (zone side)

```
Fresh save             → only "Talk to the [INTERVENER]"; Test Zone locked and hidden
Dialogue 1             → event celestial_intervener_dialogue_1 → Wilderness Cycling (+ Test Zone, still hidden); q_fill_core starts
Madra ≥ 100            → q_fill_core_madra_full → Dialogue 2 card
Dialogue 2             → q_fill_core completes → event q_fill_core_completed → Spring Forest Foraging + The Shallow Woods; q_first_steps starts
                         (the dialogue's end resumes the first idle action: foraging starts, "Resumed Spring Forest Foraging")
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
| `singletons/zone_manager/zone_manager.gd` | Zone catalog, current zone, progression, availability, map zones and states, seen actions |
| `singletons/action_manager/action_manager.gd` | Action routing, shared timer, foraging and training handlers, idle-action resolution, signals |
| `singletons/persistence_manager/zone_progression_data.gd`, `save_game_data.gd` | Per-zone save data; seen actions and `migrate()` |
| `scripts/resource_definitions/zones/zone_data/zone_data.gd`, `zone_data_list.gd` | Zone resources |
| `scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd` | Base action class and `ActionType` |
| `scripts/resource_definitions/zones/zone_action_data/*/*_action_data.gd` | Forage, cycling, adventure, NPC dialogue, training and merchant subclasses |
| `scripts/utils/zone_action_groups.gd` | Groups, list order and mode tags |
| `scripts/utils/zone_map_math.gd` | Camera framing and windows, fog tiers and art, wander and bob |
| `scripts/ui/zone_action_presenter.gd` | Abstract presenter base |
| `scripts/ui/map_popover_state.gd` | Hover, preview and pin state for the map popover |
| `scenes/zones/zone_tilemap/zone_tilemap.gd` / `.tscn` | Hex map: zones, fog, hex states, routes, camera, travel, idle motion |
| `scenes/zones/map_markers/**` | Plates, glyphs, ring, floater, popover |
| `scenes/zones/zone_hex_marker/`, `locked_zone_overlay/`, `zone_route/` | Hex rims, veils and route dots |
| `scenes/zones/zone_panel/**` | The zone chest: header, lore, `NowStrip`, `ActivityList`, `LacquerRail` |
| `scenes/zones/zone_action_button/zone_action_button.gd` / `.tscn` | Card shell and presenter factory |
| `scenes/zones/zone_action_button/presenters/*_presenter.gd` / `.tscn`, `forage_yield.tscn` | Foraging, training, adventure, cycling, merchant and default presenters |
| `scenes/zones/cultivator_plate/` | Madra, Core Density and gold cabinet |
| `assets/shaders/lacquer_madra_orb.gdshader`, `lacquer_core_orb.gdshader` | The cabinet's flowing Madra liquid and turning Core Density spiral |
| `scenes/zones/zone_transition/zone_transition.gd`, `madra_pellet.gd` / `.tscn` | Adventure-start drain and zoom |
| `scenes/ui/main_view/states/zone_view_state.gd` | Zone view state, HUD placement and input blocker |
| `scenes/tilemaps/hexagon_tile_map_layer.gd`, `tilemap_tileset.tres`, `fog_tileset.tres` | Shared hex layer and the two TileSets |
| `scenes/camera/camera_clamp_controller/camera_clamp_controller.gd` | Clamp regions (`clamp_regions`, `clamp_centre_only`, `clamp_now()`) |
| `assets/ui/lacquer/`, `assets/ui/lacquer/map/`, `assets/ui/lacquer/icons/` | The lacquer kit's textures (all `_ai`) |
| `resources/zones/zone_data_list.tres`, `resources/zones/**` | Zone content; `resources/zones/dev/` holds the demo zones |

### Tests

| File | Tests | Covers |
|---|---|---|
| `tests/unit/test_zone_progression_data.gd` | 8 | `training_tick_progress` default and save round-trip; `last_idle_action_id` round-trip; `ZoneManager.get_training_ticks()` / `increment_training_ticks()` |
| `tests/unit/test_zone_map_state.gd` | 18 | The four map states, hidden and demo zones in `get_map_zones()`, `map_zones_changed`, per-zone last idle action, `request_action_focus()`, Test Zone at (-1, 0) with no description |
| `tests/unit/test_seen_actions.gd` | 5 | `mark_action_seen()` / `is_action_seen()`, the once-per-save first-init pass |
| `tests/unit/test_save_migration.gd` | 7 | `migrate()` moves a Test Zone save to Spirit Valley; old saves load the new fields' defaults |
| `tests/unit/test_zone_action_groups.gd` | 7 | Groups, list order, labels, mode tags |
| `tests/unit/test_training_action_data.gd` | 18 | Cost-curve, level and progress functions; `_init` action type |
| `tests/unit/test_training_action_helpers.gd` | 7 | `get_madra_per_second()`, ticks in and for the level |
| `tests/unit/test_award_attribute_effect_data.gd` | 3 | The effect that grants training's level reward |
| `tests/unit/test_zone_map_math.gd` | 15 | Framing at every zoom, camera windows, fog tiers and art, wander and bob |
| `tests/unit/test_map_popover_state.gd` | 18 | Click results, one pinned popover, the preview delay |
| `tests/unit/test_camera_clamp_controller.gd` | 5 | Clamping the centre into the nearest region |
| `tests/unit/test_character_walk_steps.gd` | 5 | Whole-px walk steps at the same pace |
| `tests/unit/test_hex_forest_atlas.gd` | 10 | Atlas picker shared with the adventure map; `pick_from()` |
| `tests/unit/test_madra_pellet.gd` | 8 | Drain pellet colours, outline and 2 px steps |
| `tests/integration/test_idle_action_resolution.gd` | 35 | Resolution order, resume after every session action, travel and save-reset cases, the log lines, auto-start on a first idle unlock, completions in the zone and save the action started in, `get_current_madra_per_second()` |
| `tests/integration/test_training_flow.gd` | 1 | `select_action` → ticks, Madra trickle, level-ups, persistence across stop and restart |
| `tests/integration/test_zone_map_render.gd` | 33 | Camera framing and clamp, fog tiers and coverage at zoom 1, hex states, the character's stand and idle motion, outside zone changes |
| `tests/integration/test_map_markers.gd` | 46 | Plates and their lines (re-counted on `action_completed`), glyphs, routes, ring and floaters, positions at other zooms, name-only plates, demo toggles |
| `tests/integration/test_zone_travel.gd` | 49 | Hover rims and routes (also after the camera moves under a still pointer), previews, pins, Show me, travel on arrival, retargeting, walks cut short, Esc (left to an overlay or the full log) and outside clicks |
| `tests/integration/test_zone_transition.gd` | 3 | The drain's lookups in `main_game.tscn` and `zone_tilemap.tscn` (read, never instanced), and one whole drain: pellets, Madra spent, adventure confirmed |
| `tests/integration/test_zone_walk_steps.gd` | 1 | The map's travel walk stands on whole world px |
| `tests/integration/test_zone_panel.gd` | 48 | Header, Now strip variants and the haul countdown, the empty tray ("Nothing running", "<name> · paused" with the shop open or while cycling, Test Zone, clicks ignored), groups, count, empty zone, scroll and flash, rail and lips, lore, chest sizing |
| `tests/integration/test_zone_action_cards.gd` | 45 | Mode tags, running drawer, NEW seal, each presenter's detail line, adventure states (72 px both ways, the figure, the hint only while a Madra action runs, the row's shake, the ready frame and the flash over it), tall drawer, ellipsis |
| `tests/integration/test_cultivator_plate.gd` | 26 | Cabinet values, the fills handed to the orb shaders (and their per-cabinet materials), the core orb's pebble and socket columns, XP beads that light only for earned XP, rate visibility, the right-aligned gold row, orb position |
| `tests/integration/test_aura_well_discovery_unlock.gd` | 2 | Aura Well hidden before and visible after `aura_well_discovered` |
| `tests/integration/test_beat_3b_merchant_unlock.gd` | 1 | Dialogue 4 appears at CD 10, map award, merchant card after `merchant_discovered` |
| `tests/integration/test_merchant_shop_flow.gd` | 35 | The merchant action stays current until `stop_action()`, a second stop is a no-op, leaving resumes the zone's idle action (also after travel during the shop), and `MerchantView`'s rows, buying, Leave, theme and layout |
| `tests/unit/test_merchant_view_state.gd` | 9 | `start_merchant` pushes the shop once; closing removes only `MerchantViewState`, after the fade or at once when another view sits above it |
| `tests/integration/test_dev_panel_zone_toggles.gd` | 4 | The two Zones toggles and their `[DEV]` lines |

### Specs and plans

| Document | Status |
|---|---|
| [2026-04-10 zone action button visuals spec](../superpowers/specs/2026-04-10-zone-action-button-visuals-design.md) and [plan](../superpowers/plans/2026-04-10-zone-action-button-visuals.md) | Shipped in PR #18, then reworked into presenters in PR #29. Superseded by the 2026-10-21 lacquer cards |
| [2026-04-17 training action infrastructure spec](../superpowers/specs/2026-04-17-training-action-infrastructure-design.md) and [plan](../superpowers/plans/2026-04-17-training-action-infrastructure.md) | Shipped in PR #29. The content was renamed Spirit Well → Aura Well and gated by an event (PR #36) |
| [2026-04-17 presenter refactor spec](../superpowers/specs/2026-04-17-zone-action-button-presenter-refactor-design.md), [pass 1](../superpowers/plans/2026-04-17-zone-action-button-presenter-refactor-pass-1.md) and [pass 2](../superpowers/plans/2026-04-17-zone-action-button-presenter-refactor-pass-2.md) | Both passes shipped in PR #29. The presenter split survives; the slots changed in the 2026-10-21 rebuild |
| [2026-10-21 map-first zone view spec](../superpowers/specs/2026-10-21-zone-view-map-first-design.md), [lacquer art kit](../superpowers/specs/2026-10-21-zone-view-lacquer-kit.md), [mock-up](../superpowers/mockups/zone-view-map-first-mockup.html) and [plan](../superpowers/plans/2026-10-21-zone-view-map-first.md) | Built 2026-10-22 on `feat/zone-view-redesign-4656b7`, not merged. The plan's "As built" section lists the deviations |

## Work Remaining

### Bugs

- `[MEDIUM]` Dialogue 4 can appear out of order. `celestial_intervener_dialogue_4.tres` is gated only by `q_reach_cd_10` (Core Density ≥ 10). A player who reaches CD 10 before finishing dialogue 3 sees two `Return to the [INTERVENER]` cards, and can play `dialogue_4` before `q_reach_core_density_10` has started. Fix: add a second condition on the `celestial_intervener_dialogue_3` event, registered in `unlock_condition_list.tres`.
- `[MEDIUM]` `max_completions` counts attempts, not successes. `_stop_executing_current_action()` adds to `action_completion_count` on every stop, including `stop_action(false)` and replacement by another action. A failed run would use up a one-shot boss adventure (Foundation Beat 7).

### Missing Functionality

- `[HIGH]` `ZONE_EVENT` has no handler. `_execute_action()` logs "Unknown action type", but the action stays current (nothing running, no idle action resumed) until another action replaces it, and `_stop_executing_current_action()` skips its completion effects. Story events such as the Tribulation site (Beats 8–9) need this.
- `[MEDIUM]` Foraging is free. `ForageActionData.madra_cost_per_second` only feeds the card's detail line, but the GDD calls for a small continuous Madra cost.
- `[MEDIUM]` Foraging and training can't be toggled off. A click on the running card flashes the Now strip, and an idle action ends only when another action replaces it or the zone changes. The map-first spec makes "always in an idle action" the rule; the GDD specifies an ON/OFF toggle. Decide which wins.
- `[MEDIUM]` Idle actions don't run offline or alongside session actions. The load restarts the zone's last idle action, but nothing accrues while the game is closed (`forage_active` / `forage_start_time` are never written), and cycling, an adventure, a dialogue or the merchant pause the idle action until they end.
- `[MEDIUM]` No zone gating by boss or adventure. `UnlockConditionData.ZONE_UNLOCKED` and `ADVENTURE_COMPLETED` return false, and nothing records adventure completion. The GDD gates zones behind zone bosses; today that requires firing an event from the boss combat's `success_effects`. The map's LOCKED and UNCHARTED states, plates and popovers are ready for it.
- `[LOW]` The GDD describes a 3D hex-planet map. The built map is a flat 2D `TileMapLayer`. Decide whether the 3D view is still a goal.
- `[LOW]` `center_zone_map_camera` (Space) is bound in `project.godot`, but nothing handles it. Clicking the current zone's hex recentres the camera instead.
- `[LOW]` Unused action modifiers. `CyclingActionData` modifiers are never applied ([CYCLING.md](../cycling/CYCLING.md)). `AdventureActionData.experience_multiplier`, `difficulty_modifier`, `completion_time_modifier`, `cooldown_seconds` and `daily_limit` are never read ([ADVENTURING.md](../adventuring/ADVENTURING.md)).

### Content

- `[HIGH]` Only one real zone. `TestZone` is a placeholder (name "Test Zone", no description, no actions) kept in the list but hidden on the map; travelling there (dev toggle) only stops the running action. Foundation Beats 8–10 need the Advancement Zone and a Zone 2. The demo zones show where they will go.
- `[MEDIUM]` Foraged materials have no use. Dewdrop Tear and Spirit Fern list `used_in` recipes, but no system consumes them. There is only one forage action and one loot table.
- `[MEDIUM]` There is no `ZONE_EVENT` content.
- `[LOW]` Art made for the demo layout only: `LockedZoneOverlay`'s veils bake the Stones and Mountains2 tiles, and the chest has thumbnails only for the River tile and Basic. A real locked zone, or a zone on another tile, needs its own `_ai` textures.
- `[LOW]` Placeholder text and art: Wilderness Cycling's description is "Cycle in the wilderness", Spring Forest Foraging's is "Go to the Spring Forest and Forage some materials", and Spirit Valley's `icon` is `res://64.png` (unread).

### UI

- `[MEDIUM]` Unlocks give little feedback. A new card gets a static NEW seal, and only a first idle unlock writes a log line ("Started …"); a new story or session card appears silently, and only quests have toasts.
- `[LOW]` With the zone lore open and a map popover pinned, Escape closes the lore first and the popover on a second press; the mock closes the popover first. `ZonePanel` sits after the map's `SubViewportContainer`, which hands keys to the map in the root's unhandled-input pass, so the panel hears Esc first.
- `[LOW]` The zone view shows two different Madra maximums. The cabinet shows the pool cap (100 + 5 × Core Density level), while the adventure card measures the adventure capacity (total FOUNDATION × 10). Coordinate with [RESOURCES.md](../infrastructure/RESOURCES.md).

### Tech Debt

- `[MEDIUM]` Removing a zone id still wipes the whole save. `PersistenceManager._ready()` resets all data when `SaveGameData.verify()` (`_verify_current_selected_zone_id()`) fails; only ids listed in `SaveGameData.ZONE_ID_MIGRATIONS` are moved first. Renaming an `action_id` silently drops its completion count, last idle action and seen record, so one-time dialogues reappear.
- `[LOW]` Dead code and assets:
  - `ZoneManager.get_unlocked_zones()` always returns `[]` and has no callers.
  - `ZoneTilemap.zone_selected` has no listeners.
  - The old zone view leftovers: `scenes/zones/glowing_path/` with `assets/shaders/flowing_path.gdshader`, `assets/shaders/action_card_sweep.gdshader`, `assets/styleboxes/zones/action_card_selected.tres`, `scenes/ui/tick_progress_bar/` (`TickProgressBar`) and `assets/sprites/ui/lock_icon.png` are no longer referenced.
  - `assets/shaders/tile_aura.gdshader`, `scenes/tilemaps/pulse_node.gd` / `.tscn` with `assets/shaders/pulse_node.gdshader`, and `scenes/tilemaps/tile_map_layer.tscn` are not referenced anywhere.
  - Nothing reads `ZoneData.icon`, and nothing calls `AdventureActionData.is_valid()`.
- `[LOW]` A signal declaration doesn't match its emit: `start_foraging(action_data)` is emitted with no argument.
- `[LOW]` `FOREST_ATLAS_COLS` and `FOREST_VARIANT_COUNT` are defined in both `zone_tilemap.gd` and `HexForestAtlas`.
- `[LOW]` `ForageActionData`, `CyclingActionData` and `NpcDialogueActionData` don't set `action_type` in `_init()`.
- `[LOW]` `zone_changed` fires twice on load. `ActionManager` treats the repeat as a no-op (`_last_resolved_zone_id`), and the other listeners rebuild twice. `ZoneManager.get_current_zone()` writes to save data when the id is empty.
- `[LOW]` Stopping a dialogue relies on a one-shot `DialogueManager.dialogue_ended` → `stop_action` connection. If another action became current mid-timeline, that action would be stopped instead. Today Dialogic's full-screen `DialogicNode_Input` control covers the zone UI while a timeline runs, which prevents this.
- `[LOW]` `ZoneViewState._add_input_blocker()` creates a `Control` in code. Project convention is that UI nodes live in `.tscn` files.
- `[LOW]` Coding-standard gaps:
  - `ZoneManager.has_zone()` has an empty `##` comment.
  - The `quantity` parameter of `increment_zone_progression_for_action()` is untyped.
  - `AdventureActionData._init()` lacks `-> void`.
  - `ActionManager.get_current_action()` and `clear_current_action()` lack `##` docs.
- `[LOW]` `resources/zones/spirit_valley_zone/zone_actions/loot_table/test_loot_table_weapon.tres` isn't zone content. Its only user, `resources/adventure/encounters/test_treasure_encounter.tres`, is itself unreferenced. The live forage table is still named `test_loot_table_foraging.tres`.
- `[LOW]` `scenes/tilemaps/hexagon_tile_map_layer.tscn` references `tilemap_tileset.tres` by `uid://eptmap1q2w3e4`, but the TileSet's own UID is `uid://ufqon4iip7nd`, so Godot falls back to the path with a warning.
- `[LOW]` Missing tests:
  - `max_completions` filtering in `get_available_actions()`.
  - Foraging loot awarding (`_on_forage_timer_finished()`).
  - `ZoneTransition` drain arithmetic (whole-Madra pellets plus the remainder).
  - `get_current_level()` with an empty `ticks_per_level`.
