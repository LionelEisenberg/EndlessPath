# Zone View, Map-First (v2): Design

> **Status:** design approved by the user on 2026-10-21 after three mock rounds. Builder check done the same day; the user decided the map shows only Spirit Valley until Beats 7–10. A scene-first layout, with the forest clearing at the centre, was dropped in favour of keeping the hex map at the centre as the GDD describes. A first map-first version was then revised with the user's feedback (round 3). The same evening the user found the look "very AI" (halos, colours, thin borders), compared three art directions and picked **Lacquer and brass**, then asked for it to be built (see [Art direction](#art-direction-lacquer-and-brass)). **Built on 2026-10-22** on `feat/zone-view-redesign-4656b7`, not merged. The plan's [As built](../plans/2026-10-21-zone-view-map-first.md#as-built-2026-10-22) section lists where the build differs from this spec; [ZONES.md](../../zones/ZONES.md) describes the result.
>
> **Mock-up:** [zone-view-map-first-mockup.html](../mockups/zone-view-map-first-mockup.html) (1:1 with the 1920x1080 viewport, interactive, with mock controls above the frame), in the lacquer look.
>
> **Art kit:** [2026-10-21-zone-view-lacquer-kit.md](2026-10-21-zone-view-lacquer-kit.md): palette, type, every texture and its placement in screen px. Where the kit and this spec differ on a size or position, the kit wins; its §7 lists each difference.
>
> **Scope:** the zone view (`MainView/ZoneView`) layout and behaviour:
> - the Goals panel that replaces `QuestWindow`, shared with the adventure view;
> - the rule that an idle action always resumes.
>
> Out of scope: the GDD's 3D hex planet, new zone content (Beats 7–10), and new art beyond placeholder icons.

## Goal

The zone view is the game's hub. The player returns to it after every cycle, adventure and menu, and idle actions run on it. A frame captured from the running game on 2026-10-20 shows six problems:

1. **No focal point.** Six floating frames of similar weight: the header, the orb column, Quests, Log, Zone Actions and the toolbar.
2. **The map holds the centre but is tiny.** Its two zones cover under 2% of the screen, inside a dark blob of ghost hexes:
   - selected and unselected hexes look the same;
   - locked zones only shake;
   - a side-view forest painting sits behind a top-down map.
3. **No "now".** The running idle action shows only inside its own card. There is no way to see at a glance what is running and what it earns.
4. **Cards don't support a choice.** They show no cost, yield or time. The adventure card's red `20 / 60` is Madra against the adventure threshold, and it reads like a second Madra maximum next to the orb's `260`.
5. **Progress is hard to read.** Core Density is a small swirl and `Lvl 32`, with no XP toward the next level.
6. **Space goes to the wrong things.** The lore paragraph holds the top-left permanently, while Quests and Log start collapsed. The toolbar spends 1920 px on four buttons.

[ZONES.md § Work Remaining › UI](../../zones/ZONES.md#ui) lists several of these.

## Decisions

"User" means the user decided it in review. **Assumed** means a call made during design that the user has not ruled on; it can be revisited without reopening the design.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Centrepiece | The hex map stays at the centre (GDD: hex map plus a 2D side panel). It is drawn larger, with fog tiers, and the forest painting is removed from behind it | User | A 3D planet view is built |
| Map scale and framing | Default zoom **2.0** (tiles 328x380 on screen, one art pixel = 2 screen px, nearest filtering). Round 3 assumed 1.5; all three art-direction swatches moved to 2.0 because 1.5 blurs the ink tiles. The current zone's centre sits at screen (960, 702), so the upper half of the map is kept for the road ahead ("the map grows north"). Until more zones exist, that half is fog | One open zone has to fill the centre without looking empty | Zones are added somewhere other than north |
| Art direction | **Lacquer and brass:** dark red-brown lacquered wood panels, brass straps and caps, jade only for progress, cinnabar seals, one 2x pixel grid, hard shadows, no glow, blur, gradient or fade | User, 2026-10-21, from three swatches (field journal, lacquer and brass, classic pixel windows) | — |
| Zones shown on the map | Spirit Valley only, until Beats 7–10 author more zones; Test Zone is hidden. The locked, uncharted, popover and travel behaviour is still built. **Assumed:** it is exercised by GUT fixtures and by a dev-panel toggle that loads demo zones (not part of `zone_data_list.tres`) | User | Beats 7–10 add the Advancement Zone and Zone 2 |
| Fog | **Assumed:** every lattice cell out to the camera clamp is drawn. Tier = hex distance to the nearest charted zone, capped at 3, with darker art at each tier. Fog uses natural tile variants only, so it never looks like a place you can go. This replaces today's black ghost polygons | It reads as unexplored land, not a void | Fog art is made |
| Hex states | **Assumed:** current = a lacquer collar and brass rim on the grout, plus the character. Open = a dull brass hairline; hovered, a brighter brass rim. Locked = the tile in a desaturated palette veil with a dashed vermilion rim and a brass padlock. Uncharted = a dark veil, dotted tan rim, a tan `?` glyph and a 3-frame pixel twinkle every 4 s. A hovered or pinned locked or uncharted hex gets a thin or heavy brass rim just inside its own. (Round 4's corner brackets and light sweep were dropped in the design review as reticle- and halo-like) | Today selected and unselected hexes look the same | — |
| Plates under hexes | Name plus one status line: the running action for the current zone ("Aura Well · +1.5 Madra / s"), the blocker for a locked one ("Tribulation Guardian") | User liked these | — |
| Other zones' details | Popovers on the map: hover shows a preview, and a click pins it. A pinned popover has a × close button, plus "Show me ›" when the requirement points at a card in this zone. The side panel never switches to another zone | User: no AHEAD row; the map is how you move | A zone needs a full detail page |
| Travel | Click an open hex. **Assumed:** no confirmation. A left click travels, as today; panning stays on the right button, so it can't trigger travel. The walk to an adjacent zone takes about 0.6 s with the old action still running, then the destination's idle action starts. Travel stays a straight-line walk with no adjacency check, as today | User: clicking the map allows movement | Accidental travel in playtests, or zones far apart |
| Right column | One full-height panel: zone header (hex thumbnail, name, About) → Now strip → scrolling activity list | User: zone identity above the current action; the list must scroll | — |
| Now strip | 88 px: ring timer, action name, one rate, at most one progress line. Clicking it scrolls to its card and flashes it. No Stop button, no session totals, no blinking dot | User: a separate display is good but must be compact | — |
| Always in an action | Once any idle action is unlocked, one is always running. When cycling, an adventure, the merchant or dialogue ends, the zone's last idle action resumes. With no idle action available (fresh save, or a zone with none), the Now strip collapses and the list moves up | User | — |
| Activity cards | Icon tile, title, a mode tag (IDLE, ACTIVE, SHOP, STORY; RUNNING when current; ENTER when an adventure is affordable), and one line of yield, cost and time. **Assumed** groups: TALK, CULTIVATE, GATHER, VENTURE, VISIT (TALK first, so a new story step is never below the fold). Icons come from the unused `ZoneActionData.icon` | Cards should support a choice | — |
| Adventure affordability | "Needs 60 Madra · you have 46" with a bar, plus "ready in ~10 s" while a Madra-producing action runs, or "train or cycle to fill" otherwise. At or above the threshold: "Ready · carries up to 120 Madra · 5 min run" and an ENTER tag. The threshold is 50% of the adventure capacity (total FOUNDATION × 10), so 50 / 100 at default stats. 60 / 120 is the depicted save, with FOUNDATION 12 | Removes the number that reads like a second Madra maximum | Adventure costs change |
| Cultivator plate | Madra orb (as today), then a Core Density orb drawn like the cycling view's, with `Level N` and an XP bar, then gold. Same order as `CyclingResourcePanel` | User: show both, matching the cycling view | — |
| Goals | A self-contained panel that replaces `QuestWindow` in both the zone view and the adventure view. It shows the first active quest's current step plus the Breakthrough milestone (Core Density / 100), or the milestone alone when no quest is active. **Assumed** placement: the zone view puts it under the plate at (24, 292). The adventure view puts it top-right at (1456, 24), which is free; `QuestWindow` sits at x 1147–1467, y 28–271 today and stays put in adventures. The left side doesn't work there: (24, 244) would overlap the adventure map's `EncounterInfoPanel` (x 187–563, y 268–668) | User: keep it and make it consistent across views | The adventure HUD is redesigned |
| Dock | Inventory, Abilities, Character, Path, centred at the bottom. A notification draws a static gold ring around the button plus a count pill in its top-left corner, leaving the hotkey letter visible. No Map button | User | More menus are added |
| Gold | **Assumed:** the third row of the cultivator plate | The top-right corner now belongs to the zone panel | — |
| Lore | Behind an About pill on the zone header, opening as a popover under the Now strip | It is read once; the strip stays visible | — |
| Realm cartouche | Not built | User: there is no realm system yet | Realms exist |
| Test Zone | **Assumed:** hidden from the map, and saves standing in it are moved to Spirit Valley. Its id is kept, because removing a zone id resets any save standing in that zone (`SaveGameData.verify()`) | It is a visible placeholder ([STATE_OF_THE_GAME](../../STATE_OF_THE_GAME.md) onboarding item) | Zone 2 replaces it |

## Layout (1920x1080)

The left and right columns are 440 px wide with 24 px margins, so the open map runs from x 464 to x 1456, centred on x 960.

| Region | Rect (x, y, w, h) | Contents |
|---|---|---|
| Map | full screen, under every panel | The fog lattice and zone hexes at zoom 2 on the map ground `#090E0E`. Spirit Valley, the only zone shown, is centred at (960, 702) with fog tiers counted from it. With the dev demo toggle, a locked Advancement Zone appears at (1124, 417) and an Uncharted hex at (960, 132), joined by a dotted route. That shows the machinery for when Beats 7–10 add zones |
| Cultivator plate (cabinet) | 24, 24, 440, 252 | 1. Madra row: 80 px Madra orb, `Madra`, `46 / 260`, and `+1.5 / s` while the running action adds Madra. 2. Core Density row: 80 px core orb whose swirl fills from the centre to level / 100, `Core Density` and `Foundation`, `Level 32`, a row of XP beads with `17 / 18 XP`. 3. Gold row: coin, `120 gold` |
| Goals | 24, 272, 440, 220: a fixed board hung on two cords from the cabinet (body 24, 292, 440, 200). In the adventure view: 1456, 24 | `Goals`; quest row (icon, quest name, step text, a progress figure only when the step can measure one); divider; milestone row (`Breakthrough`, "Raise Core Density to 100", rod, `32 / 100`). With no active quest the milestone row moves up |
| Log | 24, bottom at 1056, 440 wide, 74 + 26 px per line (204 at five lines) | `Log` and `Full log · L`; up to 5 lines, newest last, fading by colour steps with age (never by opacity). The board grows upward one line at a time |
| Zone panel (chest) | 1456, 24, 440, height hugs content (176 to 1032) | One panel that grows to the bottom line only when the list needs it (kit §0). A long list scrolls inside it and folds under its last whole card |
| · Zone header | 1472, 38, 408, 52 | 46x52 brass-outlined thumbnail of the zone's tile; zone name in Yatra One 30 px brass; About button (88x36) |
| · Now strip | 1472, 106, 408, 88 | A recessed tray with a brass `Now` plate on its top edge; 56 px bead ring with the action icon; name and rate; second line; optional progress rod |
| · Activities header | 1472, 204, 408, 24 | `Activities` (Yatra One 20 px brass) and `N here`. Moves to y 102 when the strip collapses |
| · Activity list | 1472, 232, 408, 808 | A scroll viewport (1472, 132, 408, 908 when the strip collapses). Cards are 392 wide, then a 4 px gap and a 12 px brass rail column. Dithered lips show at a scrolled edge |
| Dock | 722, 976, 476, 80 | Four 108x64 buttons with a 32 px icon, a 14 px label and the hotkey letter at the top right |

Text is never smaller than 13 px. Labels use theme variants ([UI_STYLING.md](../../UI_STYLING.md)) from a lacquer theme; the type scale is in the kit's §3.

## Art direction: Lacquer and brass

The user picked this look on 2026-10-21 from three swatches of the same slice, after finding round 3's teal halos and thin glowing borders "very AI". The full kit is [2026-10-21-zone-view-lacquer-kit.md](2026-10-21-zone-view-lacquer-kit.md). Its rules, in short:

- **One pixel grid.** One art pixel is 2 screen px. Screen-space textures (`assets/ui/lacquer/`) are drawn at 2x already and show at their file size. The map's tiles are native and the camera's zoom 2 doubles them. Map-space overlays the kit drew at 2x are stored halved (`assets/ui/lacquer/map/`) so the same zoom brings them back. Nearest filtering everywhere, including the zone SubViewport.
- **Materials.** Opaque lacquer fields (`#2C1414`) with hand-placed grain, brass (`#D4A84A`) straps, caps and titles, cream (`#F0E8D8`) and tan (`#A89070`) text, cinnabar (`#A83C30`) seals. Jade (`#5CC4A0` ramp) only for progress fills; Madra quantities use the Madra blue ramp.
- **Never:** glow, halo, blur, gradients, opacity fades, translucent panels, rounded pills, thin luminous borders, emoji. Shadows are hard offsets: 4 px `#050707` for big pieces, 2 px `#150909` for small ones.
- **Motion in whole steps.** Rings, orbs, beads and rods switch frames from strips; floaters move in 2 px steps; things show and hide outright.
- **Type.** Yatra One for painted titles (zone name, panel titles, the stage name); BM Euljiro for everything else, 13 px minimum.
- **Dropped from round 3:** per-action tints (every timer ring is jade), the mists, motes, vignette and globe shade, the parallax forest painting, the card sweep fills and the flying Madra particles from the cards. The Madra drain into an adventure (`ZoneTransition`) stays.
- **Files.** Every agent-made texture ends in `_ai` (CLAUDE.md, AI-Generated Art). The user's own files (hex tiles, character sheet, inventory icon, the two fonts) are used as they are, never edited.

## Behaviour

### Now strip

| Running action | Ring | Line 1 | Line 2 | Progress line |
|---|---|---|---|---|
| Aura Well | Jade beads light one by one over each 1 s tick | "Aura Well" · "+1.5 Madra / s" | "Lv 1 → 2 · +1 Spirit" · "214 / 300" | Ticks toward the next level |
| Foraging | Jade beads light over the 5 s haul (the only haul timer) | "Spring Forest Foraging" | Dewdrop Tear icon "1–5", Spirit Fern icon "2–6" · "haul in N s" | None |
| None available | The strip is not shown | | | |

Clicking the strip scrolls the list until the running card is fully visible (24 px margin) and flashes a brass frame over the card twice (300 ms on, 300 ms off). Clicking the running card flashes the strip. The map repeats the same information around the character: the ring, "+1.5 Madra" floaters (or the haul text), and the plate's status line.

### Idle action resolution

One rule picks the idle action whenever the zone view needs one:
- on load;
- on arrival in a zone;
- when cycling, an adventure, the merchant or dialogue ends.

1. The zone's saved last idle action, if it is still available.
2. Otherwise, the first available idle card in list order.
3. Otherwise, nothing: the Now strip collapses.

Every resume writes a log line ("Resumed the Aura Well"). Travel writes one merged line instead: "Travelled to Spirit Valley · resumed the Aura Well", or just "Travelled to Test Zone" when nothing resumes. Starting an idle action saves it as the zone's last idle action. **Assumed:** when the first idle action in a zone unlocks while nothing is running there, it starts automatically and the log says so.

### Map interaction

| Target | Hover | Click |
|---|---|---|
| Current zone | Plate text brightens | Recentres the camera; closes any popover |
| Open zone you are not in | A brighter brass rim, the route dots to it turn cream, plate line reads "Click to travel" in brass | Travel: the character walks the route (0.6 s), the panel switches to the new zone on arrival (no crossfade: things show and hide outright), and that zone's idle action starts by the rule above |
| Locked zone | A thin brass rim inside the veil, plate brightens; after 150 ms a preview popover: `LOCKED`, the zone name, the full requirement ("Defeat the Tribulation Guardian in The Shallow Woods") | The lock shakes (0.44 s, in even-px steps); a heavy brass rim inside the veil; the popover pins with "Show me ›", which scrolls the list to the card the requirement names and flashes it |
| Uncharted zone | Same as locked, with `UNKNOWN` and "Revealed after the Tribulation." | Pins the popover; never travels |
| Fog | Nothing | Closes any popover |

Only one popover is open at a time. The following close it:
- its ×;
- Esc;
- a click on empty map or anywhere outside it;
- a click on another hex;
- travelling.

The dotted route brightens only toward a zone you can travel to, never toward a locked or uncharted one.

### Other behaviour

- **Adventure card:** the rod fills with Madra; at the threshold the card switches to ENTER (brass tag, brass edge).
- **Lore popover:** opens under the Now strip and covers the top of the list; About, Esc or a click outside closes it.
- **Log:** training ticks no longer write "Gained 1 Madra" every second. Gains are summarised by the strip and floaters.
- **NEW tag:** static (no animation) and cleared when the card is first hovered or used. **Assumed.**

### Copy

| Where | Text |
|---|---|
| Current-zone plate, line 2 | "Aura Well · +1.5 Madra / s", "Foraging · a haul every 5 s", or nothing when no idle action runs |
| Plate of an open zone you are not in | "Open · N activities"; on hover, "Click to travel" in gold |
| Locked plate, line 2 | The blocker in short ("Tribulation Guardian") |
| Uncharted plate, line 2 | "After the Tribulation" |
| Adventure card, below the threshold | "Needs 60 Madra · you have 46", then "ready in ~10 s" or "train or cycle to fill" |
| Adventure card, at the threshold | "Ready · carries up to 120 Madra · 5 min run" |
| Empty activity list | "Nothing to do here yet." |

## Data and save changes

- `ZoneProgressionData.last_idle_action_id: String`, written when an idle action starts.
- `ZoneData`:
  - `hidden_on_map: bool` (Test Zone sets it);
  - a way to tell UNCHARTED from LOCKED (for example `chart_conditions`: unmet means uncharted, met while the unlock conditions are unmet means locked).
- **Text for locked zones.** `UnlockConditionData` has no player-facing text, so locked plates and popovers read it from the zone. **Assumed** `ZoneData` fields:
  - `blocker_short_text`, the plate's second line ("Tribulation Guardian");
  - `requirement_text`, the popover sentence;
  - `requirement_action_id`, the card "Show me ›" scrolls to; empty means no button.
- **Demo zones for the dev-panel toggle:** a locked zone and an uncharted zone as `ZoneData` resources outside `zone_data_list.tres`, for example under `resources/zones/dev/`. They never appear in a normal save.
- The Advancement Zone and Zone 2 themselves are authored by Beats 7–10, not by this build.
- `ZoneData.tile_variant_index`: Spirit Valley moves from 0 (Basic) to 6 (River), so the current zone's tile is distinctive.
- Save migration: a save whose `current_selected_zone_id` is `TestZone` moves to `SpiritValley` before `SaveGameData.verify()` runs.
- `ZoneActionData.icon` is set for every action. The mock's placeholder icons stand in until real art exists. They were drawn by an agent, so if any are added to the project they carry the `_ai` suffix (CLAUDE.md, AI-Generated Art), for example `ic_well_ai.png`.

## Implementation notes (Godot 4.7)

These notes come from a read of the code on 2026-10-21. They name what changes and where, and leave the internals to the builder. Project rules still apply:
- UI nodes live in `.tscn` scenes, and scripts only set data;
- Label theme variants come before inline overrides ([UI_STYLING.md](../../UI_STYLING.md));
- GUT tests call production code.

### Target scene tree

```
MainView
├── ZoneView
│   ├── ZoneTransition                     kept; restores the framed camera after an adventure
│   ├── SubViewportContainer/SubViewport
│   │   └── ZoneTilemap                    fog layers, zone layer, overlays, route, character, camera
│   │       └── MapMarkers (CanvasLayer)    plates, glyphs, popovers, brackets in screen space
│   ├── CultivatorPlate                    replaces ZoneResourcePanel
│   ├── ZonePanel                          replaces ZoneInfoPanel and ZoneHeader
│   │   ├── ZoneHeaderRow                  thumbnail, name, About
│   │   ├── NowStrip                       hidden when no idle action is running
│   │   └── ActivityList (ScrollContainer) group headers and ZoneActionButton cards
│   └── Dock                               replaces Toolbar (gold moves to the plate)
├── GoalsPanel                             replaces QuestWindow; each view state positions it
└── LogWindow                              restyled as the fading feed; L opens the full history
```

`ZoneViewBackground` (the parallax painting) is no longer instanced in the zone view. The scene stays in the project.

### Map (`scenes/zones/zone_tilemap/`)

- **Camera.**
  - Raise `CameraZoomController` from 0.65–1.35 (default 0.729) to 1.0–2.0 with default 2.0. Today a 2.0 default would be clamped to 1.35 (`zone_tilemap.tscn:42-56`).
  - Set `canvas_item_default_texture_filter = 0` (nearest) on the zone `SubViewport`: SubViewports default to linear, so today the map's tiles and character are drawn linear-filtered.
  - Put the map ground (`#090E0E`) behind the map and stop instancing `Atmosphere` and `ZoneViewBackground` in the zone view.
  - Zero `Camera2D.offset` (today (100, 50)).
  - Add a pure static framing helper that places the current zone's centre at screen (960, 702) at any zoom, with GUT tests. Use it on `_ready` and on travel. Today the camera starts at world (0, 0) and the code never centres it. That happens to frame Spirit Valley, whose cell centre is world (0, 0), apart from the (100, 50) offset; a save standing in any other zone starts off-centre.
  - The `CameraClampController` boundary becomes the known zones' bounds plus 1.5 hexes. It must also run after travel tweens, which it doesn't today.
  - `ZoneTransition.reset_camera()` returns to the framed position.
- **Fog.**
  - Replace `_refresh_ghost_neighbors()`'s runtime `Polygon2D`s with a fog `TileMapLayer` under the zone layer. Fill cells out to the clamp bounds; the tier is the cube distance to the nearest charted zone, capped at 3.
  - The kit pre-draws each tier as a 9-cell atlas from the natural-only pool (Basic, Mountains1, Clearing1, Lake1, Lake2, Hole, Dead, Ravine, Cave), so no material is needed: one TileSet atlas source per tier.
  - The cell within a tier's atlas comes from a new `HexForestAtlas.pick_from(cube, pool_size)`, deterministic per cell. `pick()` takes cube coordinates (`hex_forest_atlas.gd:20`).
  - Fog cells have no zone. They do emit `tile_clicked` (the layer emits for any cell with a source), and `get_zone_at_tile` returns null for them, which closes a popover.
- **Zone tile states.**
  - Locked and uncharted: `LockedZoneOverlay` draws the kit's veiled tile over the zone's cell (the veil, the dashed vermilion or dotted tan rim are baked in); the uncharted one gets a pixel twinkle beside its `?`. The lock and `?` glyphs move to `MapMarkers`. `shake()` stays (`locked_zone_overlay.gd:16`). The kit's veiled tiles bake the Stones and Mountains2 art, which the demo zones use; a zone with another tile needs its own veil art.
  - Current: the kit's lacquer collar and brass rim drawn over the cell. Open (not current): a dull brass hairline. The unused `tile_aura` shader stays unused (it is a glow).
  - Spirit Valley's `tile_variant_index` changes from 0 to 6.
- **Hover and pinned.** Rim swaps on the hex's own overlay, not a selector: `hex_hover` on a travelable open hex, `hex_hover_in` or `hex_pinned_in` inside a veiled one. `HexHoverSelector` is no longer used in the zone view (the adventure map keeps it). Today hover shows nothing on locked zones (`zone_tilemap.gd:269-277`); it now does.
- **Clicks.**
  - `hexagon_tile_map_layer.gd` emits `tile_clicked` on a left press in `_input`, and the adventure map shares that script. Panning is right-drag (`camera_pan_controller.gd:12`), so a left click can keep travelling on press.
  - Every new panel root (plate, Goals, log, zone panel, dock) uses `MOUSE_FILTER_STOP`. Today `ZoneResourcePanel`, `LogWindow` and `QuestWindow` set their roots to IGNORE, so a click on their padding reaches the map.
- **Travel.**
  - Keep the straight-line walk.
  - Raise `CHARACTER_MOVE_SPEED` from 150 to about 275 world px/s. Adjacent zone centres are about 164 world px apart, so this gives about 0.6 s. Zoom does not change travel time.
  - Move `ZoneManager.set_current_zone()` from the click to the arrival. Today the click emits `zone_changed` before the walk (`zone_tilemap.gd:213-215`), which stops the action at once and contradicts "the old action keeps running during the walk".
  - `ZoneTilemap._ready` emits `zone_changed` twice on load (`zone_tilemap.gd:78` and `81`). The load-time resolution must run once, not once per emit.
  - Set `PlayerCharacter`'s scale to 1, so its 16x24 frame draws at 2x (32x48) at zoom 2, on the same grid as the tiles.
- **Route and paths.** Dotted routes (brass-tan dots every 12 world px) join the current zone to the charted zones and the uncharted hexes beyond them; this is the "road ahead". A route toward a zone you can travel to turns cream while that zone is hovered. `GlowingPath` (a glow) is no longer used in the zone view; the scene stays in the project.
- **`MapMarkers`.**
  - It holds a `ZoneMapLabel` scene per known zone (name plus status or blocker line), the lock and `?` glyphs, the two map popovers, and the floaters.
  - Positions come from the canvas transform each frame, so text stays crisp at every zoom.
  - Clicking a plate does the same as clicking its hex.

### Zone panel (`scenes/zones/zone_panel/`, new)

- **Header row.** It shows:
  - the zone's tile thumbnail, via an atlas region of the tile variant;
  - `ZoneData.zone_name` at the zone title size;
  - an About button that opens the lore popover (`ZoneData.description`).

  `ZoneHeader`'s job moves here (`zone_header.gd:7`).
- **`NowStrip`.**
  - It reads `ActionManager.current_action` and is visible only for an idle action (FORAGE or TRAIN_STATS).
  - Training uses `TrainingActionData.get_current_level()` and `get_progress_within_level()`, and listens to `training_tick_processed` and `training_level_gained`.
  - The ring timers poll `ActionManager.action_timer`, as the presenters do today.
  - A click calls `ensure_control_visible()` on the running card and flashes it.
  - When the strip hides, the list takes its space.
- **`ActivityList`.**
  - A `ScrollContainer` with its own scrollbar hidden, plus a brass rail beside it (caps lit when the list can scroll that way, a carved track, a thumb). Cards have a fixed width, so the rail column is always reserved.
  - Rebuild triggers are unchanged: `ZoneManager.zone_changed`, `action_completed` and `UnlockManager.condition_unlocked`, as in `zone_info_panel.gd:8-22`.
  - Groups replace the per-type `ZoneActionTypeSection` headers: TALK = NPC_DIALOGUE, CULTIVATE = CYCLING and TRAIN_STATS, GATHER = FORAGE, VENTURE = ADVENTURE, VISIT = MERCHANT. **Assumed:** ZONE_EVENT goes in VISIT.
  - The per-type colour tables go: the lacquer look drops action tints. Today they are duplicated between `zone_action_type_section.gd:26` and `zone_action_button.gd:15`, and neither covers every type.
- **Cards.** `ZoneActionButton` keeps its shell, presenters and slots (`zone_action_button.gd:120`, `zone_action_presenter.gd:21`) and gains:
  - an icon tile from `ZoneActionData.icon`;
  - a mode tag;
  - one detail line filled by the presenter.

  | Presenter | Detail line |
  |---|---|
  | Foraging | Yield icons and ranges, interval, cost |
  | Training | Madra rate and level reward |
  | Adventure | Needs-Madra bar, "ready in ~N s", the ENTER state |
  | Default | Description |

  "Ready in ~N s" divides the missing Madra by the running action's Madra per second. The NEW tag needs to know whether a card has been seen (see Data).

### Cultivator plate (replaces `ZoneResourcePanel`)

- **Orbs.** The lacquer look draws both orbs from frame strips instead of shaders:
  - Madra orb: frame round(Madra / max × 32) of the 33-frame strip.
  - Core orb: column round(min(level, 100) / 100 × 16) of the 17-column strip, with the swirl phase (row 0–3) stepped every 1.5 s.

  The cycling view keeps its shader orbs (`CyclingResourcePanel`); round 3's idea of sharing the orb scenes between the two panels is dropped.
- **Labels and signals.**
  - The XP bar listens to `CultivationManager.core_density_xp_updated`. Today's zone panel listens only to `core_density_level_updated`.
  - Gold listens to `ResourceManager.gold_changed`, which today feeds `toolbar.gd:15`.
  - The `+N / s` rate shows while the running action awards Madra each tick: the amount over `tick_interval_seconds`.
- **Max Madra.** Add a public max-Madra getter. Today both panels and `ResourceManager.add_madra()` call the private `CultivationManager._get_current_stage_resource()`.
- **Lookups.** Keep `get_madra_orb_global_position()`, the particle target. Update the two lookups that find the panel by the node name `ZoneResourcePanel`: `zone_action_button.gd:64` and `zone_transition.gd:47`.

### Goals (replaces `QuestWindow`)

- **Placement.** A `MainView` child, as `QuestWindow` is today. Each view state sets its position:
  - zone view (24, 292);
  - adventure view (1456, 24), with `AdventureViewState` setting it as it already moves the log (`adventure_view_state.gd:6`);
  - hidden in the merchant, as `MerchantViewState._hide_hud_windows()` does today (`merchant_view_state.gd:66`).
- **Content.**
  - Row 1: the first active quest's current step, from `QuestManager.quest_started`, `quest_step_advanced` and `quest_completed`.
  - Row 2: the Breakthrough milestone from `CultivationManager`.
  - A progress figure appears only when the step's completion condition is measurable: a RESOURCE_AMOUNT or CULTIVATION_LEVEL condition shows current / target. `QuestStepData` has no type field, so read the step's conditions. For example, `q_fill_core`'s `reach_max_madra` step uses `q_fill_core_madra_full` (Madra ≥ 100) and shows Madra / 100. Event-completed steps, such as defeating an enemy, show no figure.
- **Size.** Its height hugs one or two rows. `QuestToast` is unchanged.

### Log

`LogWindow` becomes the five-line feed at (24, 852, 440, 204), fading by colour steps (kit §5.3). **Assumed:** L opens the full history, through a new input action wired to the unused `LogManager.toggle_window()`. The adventure view keeps moving it to (24, 24).

Training must stop writing a line per tick. `ResourceManager.add_madra()` logs "Gained N Madra" on every call of 1 or more, even at the cap (`resource_manager.gd:74`), and the Aura Well's trickle effect calls it each second. Either let the effect add Madra silently, or add a quiet flag. Either way, a capped add writes nothing.

### Dock

`Toolbar` becomes a centred 476 px dock with the four `SystemMenuButton`s and no gold.

`SystemMenuButton` gets a notification state that replaces the 12x12 Abilities-only `ColorRect` badge (`system_menu_button.gd:126`):
- a 2 px gold ring;
- a count pill in the top-left corner when there is a number.

Its two users:
- **Path:** `PathManager.get_point_balance()` and `points_changed`. Today only the path tree listens to these.
- **Abilities:** keeps `AbilityManager.has_unequipped_unlocks()`, shown as the ring with no count.

Remove the unused `BADGE_PROVIDER` constant.

### ActionManager (`singletons/action_manager/action_manager.gd`)

- **Resume after any session action.** Generalise the merchant-only resume (`_idle_action_to_resume`, lines 44, 67-77 and 325-329). When cycling, an adventure, dialogue or the merchant replaces an idle action, the zone's idle action resumes on stop, through the resolution order in Behaviour. Today only a MERCHANT stop resumes, so cycling, adventures and dialogue leave nothing running.
- **Zone change.** `_on_zone_changed` (lines 57-60) stops the action and leaves nothing running. After the stop, it runs the resolution order for the destination.
- **Load and unlock.**
  - On load, run the resolution order, so the zone's last idle action restarts. The running action is not saved today.
  - When an idle action unlocks while nothing is running in the zone, start it.
- **Rejected adventure (hardening).**
  - From the UI, an unaffordable adventure never reaches `select_action()`: `AdventurePresenter.can_activate()` rejects the click first (`zone_action_button.gd:147-150`).
  - `select_action()` itself still stops the current action before `_execute_adventure_action()` checks affordability (lines 183-193). A non-UI caller, or a stale `_is_affordable` (it refreshes only on `madra_changed`), would leave nothing running.
  - Check affordability before stopping.
- **Saving the last idle action.** Starting an idle action writes `ZoneProgressionData.last_idle_action_id`.
- **Side effect to know.** Every stop counts as a completion and runs `success_effects` (lines 128-146). Resuming more often raises the idle actions' completion counts. That is harmless today, since idle actions have `max_completions` 0 and no effects, but it matters if either changes.

### Data and save (`singletons/persistence_manager/`, `scripts/resource_definitions/zones/`)

- `ZoneProgressionData.last_idle_action_id: String` (beside `training_tick_progress`, `zone_progression_data.gd:12`). It saves with `save.tres`, and old saves load the default.
- **Assumed:** `SaveGameData.seen_action_ids: Array[String]` for the NEW tag, cleared on hover or use.
- **`ZoneData` additions:**
  - `hidden_on_map: bool`;
  - the uncharted/locked distinction (for example `chart_conditions`).

  The six zone loops in `zone_tilemap.gd` (`set_all_zones_in_tile_map`, `get_zone_at_tile`, the ghost-neighbour, overlay and path refreshes) switch to a map-zone list that skips hidden zones.
- **Test Zone.**
  - Set `hidden_on_map` and keep its id.
  - In `PersistenceManager._ready()`, before `verify()`, move a save whose `current_selected_zone_id` is `TestZone` to `SpiritValley`. A failed `verify()` wipes the whole save (`persistence_manager.gd:16`), but `TestZone` still exists, so it would not fail. The migration only stops a player being stranded on a hidden hex.

### Tests to add or update

- **ActionManager resume:**
  - after cycling, an adventure win, an adventure loss, dialogue and the merchant;
  - on zone change, with and without a saved last idle action;
  - a rejected adventure keeps the idle action running;
  - the first idle unlock auto-starts.
- **Update `tests/integration/test_merchant_shop_flow.gd`.** Its fixture is a fresh `SaveGameData`, so foraging and the Aura Well are locked.
  - `test_shop_resumes_the_idle_action_it_replaced` (lines 65-70) would fail under "if it is still available", because locked foraging is not available. Unlock foraging in its setup.
  - Lines 72-76 (a zone change during the shop leaves nothing) keep passing with that fixture, but add a case where the destination has an available idle action.
- **Save:** a `last_idle_action_id` round-trip, following `tests/unit/test_zone_progression_data.gd:12-23`; the `TestZone` migration.
- **Map helpers:** the framing helper at several zooms; fog tier distances; `pick_from` (deterministic, natural pool only).
- **Map states, with fixture zones:** these can't be seen in a normal save until Beats 7–10.
  - A locked zone shows its plate text and popover, and "Show me" appears only when `requirement_action_id` names a card in the current zone.
  - An uncharted zone never travels.
  - Clicking an open zone travels and resumes its idle action on arrival.
  - Hidden zones (Test Zone) are skipped everywhere.
- **Panels:**
  - the plate's rate shows only while a Madra-awarding action runs;
  - the Path badge count follows `points_changed`;
  - Goals falls back to the milestone when no quest is active.

### Docs to update when built

- [ZONES.md](../../zones/ZONES.md): scene tree, behaviour, Work Remaining.
- [MAIN_VIEW.md](../../infrastructure/MAIN_VIEW.md): Goals and log placement per view.
- [UI_STYLING.md](../../UI_STYLING.md): any new variants for plates, tags and the strip.
- [FOUNDATION_PLAYTHROUGH.md](../../progression/FOUNDATION_PLAYTHROUGH.md): Path points are now announced.

## Open / deferred

- **Unlock reveal sequence:** when a locked zone opens, the camera frames it, the lock pops, the veil lifts, the route redraws as a `GlowingPath`, and the plate reads "Open" with a NEW chip. Designed during round 2; not needed until a zone can unlock.
- **Recentre button and off-screen indicator:** for when the player pans the current zone out of view. Zoom range 0.75–2.0, with plates reduced to the name below 1.25.
- **The 3D hex planet:** the screen-space globe shade is only a hint. A real sphere needs a warped SubViewport with inverse-mapped picking.
- **A detail view for zones you haven't reached:** popovers hold one requirement. Several requirements would need more room.

## Mock-up

[zone-view-map-first-mockup.html](../mockups/zone-view-map-first-mockup.html) opens in any browser from the repo checkout (it loads the font and sprites from `assets/`). By default the map shows Spirit Valley alone, as the build will. The controls above the frame switch between:
- the locked and uncharted demo: the Advancement Zone and Uncharted hexes, their plates, popovers and the route north;
- Aura Well running, Foraging running, and a fresh save with no idle action;
- 5 or 9 activities (the list scrolls at 9);
- an open-zone demo hex for trying travel by clicking it;
- pinned and hovered popovers;
- the lore popover.

Illustrative content, not in the game today:
- the Aura Well running in the depicted save;
- the planned Beat 5 "First Elite" quest;
- the Path badge;
- the Advancement Zone and Uncharted hexes;
- the Test Zone travel demo;
- the placeholder cards in the 9-activity list;
- the action and material icons.
