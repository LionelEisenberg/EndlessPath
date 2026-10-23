# Cycling View in Lacquer and Brass: Design

> **Status:** approved by the user on 2026-10-22. The decisions below were settled with the user that day in two rounds of questions over a playable mock, plus one question from a builder check (the quest toast). While planning, two details were corrected against the code: the board and figure box pass the mouse instead of ignoring it, and the chest with three techniques is 464 px tall. Not built; the plan is [2026-10-22-cycling-view-lacquer.md](../plans/2026-10-22-cycling-view-lacquer.md).
>
> **Mock-up:** [cycling-view-lacquer-mockup.html](../mockups/cycling-view-lacquer-mockup.html). It is 1:1 with the 1920x1080 viewport and playable, with mock controls above the frame. Its defaults are the decisions; the options the user turned down stay in its bar for reference.
>
> **Art:** new `_ai` pieces in [cycling-view-lacquer/](../mockups/cycling-view-lacquer/), drawn by `cycling-view-lacquer/gen/kit_cycling.py` with the zone kit's primitives ([style guide §11](../../STYLE_GUIDE.md#11-implementation-in-godot), Generators).
>
> **Scope:** the cycling view's look (style guide backlog rows C1–C11) plus the small feel changes the user chose: the groove lighting up behind the ball, zones shown between cycles, a cycle's tier marks kept until the next one, a result line, no pellets once Madra is full, and NEW seals for new techniques. Also the cycling bugs the new look would show ([CYCLING.md](../../cycling/CYCLING.md#bugs)).
>
> **Out of scope:** the cycling path perks (`MADRA_GENERATION_MULT`, `CYCLING_ACCURACY_BONUS`, `CORE_DENSITY_XP_MULT`), the unused `CyclingActionData` modifiers, `timing_window_ratio`, combos and streaks, a penalty for mistimed clicks, audio, Auto Cycle as a Copper reward, new techniques or zones, and balance. One balance note from the mock: at Core Density 32 a Smooth Flow cycle can gain about 5 levels (25–50 XP a zone against about 19 XP a level).

## Goal

Cycling is the Foundation stage's active loop and its main Madra source, opened from the zone view's Wilderness Cycling card. It is the screen the zone view rework left behind, and the style guide's survey ([§13, Cycling](../../STYLE_GUIDE.md#cycling)) found it built from the look the user rejected:

1. **The old look throughout.** A translucent rounded panel over the teal veil, antialiased glowing path lines, a painted orb under a rotating glow shader, soft shader discs for the zones, translucent rounded tabs, liquid orbs on continuous time, glowing particles with trails, and pill buttons.
2. **A second Madra readout.** The overlay's Resources tab repeats the cabinet's Madra and Core Density orbs, a few hundred pixels from the cabinet itself.
3. **Feedback that never shows.** The zone hit flash is overwritten in the same frame, the rate reads `+0.0/s` through the first cycle and never returns to its idle text, and the log gets "Gained N Madra" about 12 times a second.
4. **Nothing to read before you start.** Zones appear only once a cycle runs, so the player can't see where they are until the ball is already moving.
5. **Techniques you can't tell apart.** Rows use the Godot logo as their icon, the equipped one is marked only by a gold name, and a newly unlocked technique says nothing (`CyclingManager.has_unequipped_unlocks()` has no caller).

This design keeps the cycling rules and numbers and changes how they look and read. The view becomes part of the zone view instead of a modal on top of it: the board takes the map's place, the cabinet stays as the readout, and the chest lists the techniques.

## Decisions

"User" means the user decided it (round 1 or 2 on 2026-10-22). **Assumed** means a call made during design that the user has not ruled on; it can be revisited without reopening the design.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | The look (C1–C11), plus the feel changes listed under Scope, plus the bugs the new look would show | User (round 1). The feel changes are cheap and make the lacquer version read | — |
| Layout | **A, in the map gap.** The cycling board takes the map's place and hugs the figure. The cabinet stays as the readout, Goals and Log stay up, the zone chest lists the techniques, the dock hides | User (round 1). The cabinet already shows Madra and Core Density, so there is no second readout; the books already keep Goals and Log up | — |
| Layout details | The chest lists techniques while cycling and returns to its activities on close; the Now tray shows the cycle; the dock hides; Goals and Log stay up | User (round 2) | — |
| Now tray during cycling | Shows Wilderness Cycling: the bead ring through the cycle, the rate, the technique and time, a jade rod for the cycle. **This reverses the zone spec's row** that shows "Aura Well · paused" while a session action runs, for cycling only; the shop, adventures and dialogue keep it | User (round 2). The tray shows what is running; the "paused" rule was written when cycling covered the chest | — |
| Backdrop | None. Cycling no longer shows `GreyBackground` or hides the HUD boards | Follows from layout A | — |
| Map input | The map takes no clicks, hovers or wheel zoom while cycling | **Assumed.** Today `GreyBackground` is the only thing keeping clicks off the map; without it, a click beside the board would walk to another zone and end the cycle on arrival | — |
| Full log while cycling | Blocked, as under a book: L does nothing and Esc closes cycling | **Assumed.** The full log would open under the board (z 1 against z 3) | — |
| Quest toast while cycling | Left as it is. At the top centre (y 28–88, z 10) it covers the board's header for about 3 s when a quest step completes mid-cycle: "Fill your Madra by cycling" at 100 Madra, and Core Density 10 | User (after the builder check): the toast will be reworked later anyway (style guide backlog Z2) | Z2 restyles the toast |
| Body figure | Carved into the board, traced from the user's standing outline at the same 500x832 footprint, so every technique's path and zones land where they do today | User (round 1). Brass stays for state | A seated pose or a figure per technique is wanted |
| Groove | The path is a carved channel. Behind the ball it lights in the Madra ramp | User (round 1: "blue for now") | It should stand apart from the ball, which is the same blue |
| Ball | The ball moves every frame along today's eased path; its drawn position snaps to even px. Its swirl switches between 8 frames, 10 a second | User (round 1) | — |
| Hit tiers | PERFECT brass, GOOD cream, OK tan (green dropped). XP pellets take the tier's colour. Style guide G3 | User (round 1) | — |
| Technique icons | One per technique, from a new `icon` field on `CyclingTechniqueData`. The mock's three `_ai` icons stand in until the user draws their own | User (round 1); the placeholders are **assumed** | The user's icons exist |
| Zones between cycles | Shown as idle sockets with a dotted tan rim | User (round 1) | — |
| Tier marks | A zone hit this cycle keeps its brass, cream or tan stud until the next cycle starts; a zone the ball passed unclicked shows as a spent socket | **Assumed** (the mock) | — |
| Result line | "Last cycle · …" in the board's footer, and one log line per cycle in the Madra tone. Cycling no longer writes "Gained N Madra" | User (round 1, the line); the placement is **assumed** (the mock) | — |
| Madra at the cap | No Madra is added and no pellets fly. The status line says "Madra full · zones still pay XP" ("Madra full" for a technique with no zones) | User (round 2) | — |
| Switching technique mid-cycle | Allowed. It ends the running cycle with no result line; Madra and XP already paid stay | User (round 2). Also fixes the bug where the old tween keeps sliding the ball along the new path | — |
| New technique | A NEW seal after its drawer's title, cleared on first hover or equip; and a NEW seal on the Wilderness Cycling card in the zone chest until the player opens cycling | User (round 2). **Assumed:** hovering the card also clears its seal, as it clears every NEW seal (style guide §7), so the card needs no special case | — |
| Tracking feedback | A tan dotted ring round the ball while the cursor is inside it; "follow the ball" in the status line when it drifts off | **Assumed** (the mock) | — |
| Pellet flights | Madra pellets fly from the ball into the cabinet's Madra orb; XP pellets from the zone into its Core orb. No pulse on arrival | **Assumed** (follows from layout A, like the adventure drain reversed) | The long flight across the screen distracts from tracking |
| Hit floater | "PERFECT +25 XP" on the lacquer token in the tier's colour, rising 40 px in 20 steps over 1 s, then hidden | **Assumed** (style guide F6, the map floater) | — |
| Auto | A raised tablet, "Auto · off"; pressed in with brass corner caps, "Auto · on". Not saved, as today | **Assumed** (the mock) | Auto becomes a Copper reward |
| Show and hide | The board, the chest's lists and the dock show and hide outright, with no transition | **Assumed** (style guide §8) | — |
| Cycle rules | Unchanged: the eased path, 0.08 s Madra steps, the 29.5 px ball and 20 px zone radii, the PERFECT and GOOD thresholds (6 and 14 px), zone XP, one score per zone per cycle | Out of scope | Path perks are wired |

## Layout (1920x1080)

The zone view's furniture keeps its place ([zone view spec, Layout](2026-10-21-zone-view-map-first-design.md#layout-1920x1080)); only the map gap and the chest's list change.

| Region | Rect (x, y, w, h) | Contents |
|---|---|---|
| Map | full screen, under every panel | Unchanged, but takes no input. The board covers its centre, Spirit Valley's hex included |
| Cultivator cabinet | 24, 24, 440, 252 | Unchanged. Its Madra orb fills as the ball draws Madra and the pellets pour into it; `+13.3 / s` shows while the ball draws Madra; the Core orb, level and XP beads move when a zone scores |
| Goals | 24, 276, 440, 220 | Unchanged. The Breakthrough rod moves as Core Density rises |
| Log | 24, bottom 1056, 440 wide | Unchanged; one line per cycle |
| **Cycling board** | 680, 24, 560, 1032 | A strapped lacquer board (anchor furniture), centred on x 960, 24 px from the top and bottom lines |
| · Label | 710, 40 | `Wilderness Cycling` (the action's name), tan |
| · Title | 710, 60 | The technique's name, Yatra One 22, brass |
| · Close | 1182, 40, 28, 28 | The kit's carved ×, with `Esc` right-aligned before it, ending at x 1174 |
| · Figure box | 710, 104, 500, 832 | The carved figure, the groove, the zones and the ball. Curve space starts at (−70, −24) in the box, as it does relative to the outline today |
| · Status | 710, 954, 368 wide | One line, cream (`LabelLacquerName`), ellipsized |
| · Auto | 1090, 946, 120, 36 | The Auto toggle |
| · Result | 710, 996, 500 wide | One line, tan (`RichTextLacquer`), so its decimal points never meet Euljiro |
| **Zone chest** | 1456, 24, 440, hugs content | Header unchanged. Now tray showing the cycle. `Techniques` header at y 204 with `N learned`, then technique drawers from y 232, 80 px apart. With three techniques the chest is 464 tall (local list top 208 + 232 + 24; the mock draws the list 24 px lower) |
| Dock | 722, 976, 476, 80 | Hidden while cycling (the board covers its place) |

## Art

New pieces, drawn on the kit's 2x grid by `kit_cycling.py` and named `_ai`. Sizes are display sizes; boards get the kit's baked 4 px shadow when imported (style guide §11), small raised pieces the 2 px one.

| Piece | File | Size | Notes |
|---|---|---|---|
| Cycling board | `lacquer_cyc_board_a_ai.png` | 560x1032 | `cabinet()` frame, four brass corner straps (one worn, one missing a nail), hand-placed grain, a gloss dash |
| Carved figure | `lacquer_cyc_body_carved_ai.png` | 500x832 | Traced from `cycling_technique_outline.png` at 250x416 art px: the outline's alpha box-filtered, filled, then carved (upper and left walls ink for 2 art px, lower and right walls rim, floor deep). The user's file stays untouched |
| Ball strip | `lacquer_cyc_ball_strip_ai.png` | 8 frames of 60x60 | Madra ramp, ink outline, a two-armed swirl turning half a revolution over the 8 frames, a fixed glint top-left. 60 matches the 29.5 px hit radius |
| Ball rings | `lacquer_cyc_ball_rings_ai.png` | 2 frames of 80x80 | 0: the brass ring (ready to click). 1: tan dots (the cursor is inside) |
| Zone strip | `lacquer_cyc_zone_strip_ai.png` | 6 frames of 48x48 | A carved socket: idle (dotted tan rim), active (brass rim), spent (bare), PERFECT (brass stud), GOOD (cream stud), OK (tan stud) |
| XP pellets | `lacquer_cyc_pellet_{brass,cream,tan}_ai.png` | 12x12 | The kit's Madra pellet recoloured |
| Technique icons | `lacquer_ic_tech_{foundation,smooth,torrent}_ai.png` | 32x32 | Placeholders, 16 art px: each path's shape (figure-eight, ∞, whirlpool) in the Madra ramp |
| Auto toggle | `lacquer_cyc_auto_ai.png`, `lacquer_cyc_auto_on_ai.png` | 120x36 | Raised (off); pressed with brass caps (on) |

Reused from the zone kit as they are: `drawer`, `drawer_run`, `tag`, `seal_new_s`, `now_tray`, `now_plate`, `ring_strip`, the jade `rod_well` set, `frame_hover`, `frame_brass`, `token`, `close`, `close_hover`, `groove` and `groove_end`, `mini_madra`, `ic_cycle` (the action's icon) and `lacquer_madra_pellet_ai.png`.

The groove has no art file: it is drawn per art pixel from the technique's curve (see Implementation notes), in ink with a rim lip below, and lit in the Madra ramp (`#E8F6FD` top edge, `#BBD5E7`, `#849BE4` bottom edge).

The mock's folder also holds pieces for the options the user turned down (boards B and C, the brass-inlay and seated figures, jade pellets, the side tray, the dither tile). They are not imported.

## Behaviour

### Opening and closing

- **Open.** Clicking the Wilderness Cycling card starts cycling as today (`ActionManager.select_action()` → `start_cycling`). The board appears in the map gap, the chest's list switches to the techniques, the dock hides, and the map stops taking input. The cabinet, Goals and Log stay as they are; the full log (L) is blocked while cycling, as it is under a book. The zone's idle action stops as today: it counts a completion and its timer resets.
- **Close.** Esc or the × stops the action as today (`ActionManager.stop_action()`). A running cycle ends; the Madra and XP it paid stay. The zones reset, the board hides, the chest shows its activities again, the dock returns, the map takes input again, and the zone's idle action starts again from zero ("Resumed Aura Well" in the log).

### Ready

The ball rests at the path's start inside its steady brass ring. The zones sit along the carved groove as idle sockets, and the status line reads "Click the Madra ball to begin a cycle." (or "Click the ball for another cycle." once one has run). The ball shows the pointer cursor.

### A cycle

- **Start.** A left click on the ball starts a cycle. The brass ring hides.
- **Travel.** The ball travels the path once over `cycle_duration` with today's sine ease in and out. Its drawn position snaps to even px every frame. Its swirl steps through 8 frames, 10 a second, whether it moves or not.
- **Groove.** Behind the drawn ball the groove lights cell by cell, in path order, in the Madra ramp. At the end of the cycle the whole groove is lit; it goes dark again when the next cycle starts.
- **Drawing Madra.** While the cursor is within 29.5 px of the drawn ball, the tan dotted ring shows, and every 0.08 s the cycle adds `base_madra_per_cycle × 0.08 / cycle_duration` Madra and sends one Madra pellet from the ball to the cabinet's Madra orb. The 0.08 s timer carries its remainder (today it resets to 0 and pays about 96 % of the rate at 60 FPS). The cabinet and the Now tray show the Madra drawn over the last second as `+13.3 / s` and `+13.3 Madra / s`. When the cursor drifts off, the ring hides and the status line adds "follow the ball".
- **Madra full.** At the cap the cycle adds nothing and sends no pellets, and the status line reads "Madra full · zones still pay XP" ("Madra full" with no zones). Zones still score.

### Zones

| State | Socket | When |
|---|---|---|
| Idle | Dotted tan rim | Between cycles, and during a cycle until the ball reaches it |
| Active | Brass rim | While the ball overlaps it (centres within 49.5 px), unscored. It shows the pointer cursor |
| Scored | Brass, cream or tan stud | Clicked while active; PERFECT, GOOD or OK by today's thresholds. Kept until the next cycle starts |
| Spent | Bare dark socket | The ball left it unclicked. Kept until the next cycle starts |

A score sends the zone's XP to Core Density as today, shows a floater above the zone ("PERFECT +25 XP" on the lacquer token, in the tier's colour, 40 px up in 20 steps over 1 s, then hidden), and sends 8, 5 or 3 XP pellets in the tier's colour from the zone to the cabinet's Core orb. A click on a zone that is not active does nothing, as today.

### End of a cycle

The footer's result line reads, for example, "Last cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 XP", and the log gets one line in the Madra tone: "Cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 XP". With no zones: "Last cycle · +50 Madra · no zones". The PERFECT part is left out when there were none, and the XP part when no zone scored. With Auto on, the next cycle starts at once (the studs and the groove reset); with Auto off the ball waits in its brass ring.

The Madra figure is the Madra the cycle added (pellets count only when they add).

### Techniques (the chest while cycling)

- The list holds every unlocked technique in unlock order, as drawers ([style guide §6](../../STYLE_GUIDE.md#6-materials-and-components)): the technique's icon in the socket, its name, and one detail line, "200 Madra · 15 s cycle · 4 zones".
- The equipped technique's drawer is pulled out (`drawer_run`, brass caps, 4 px shadow) with an `IN USE` tag in cream. The others are plain drawers with no tag; hover shows the thin hover frame.
- **Equip.** Clicking another drawer equips it (`CyclingManager.equip_technique()`, saved as today). Its drawer pulls out and flashes the brass frame twice. A running cycle ends with no result line. The board's title, the groove, the zones and the ball move to the new path, ready.
- **NEW.** An unlocked technique the player has not seen shows the NEW seal after its title until its drawer is first hovered or equipped. The equipped technique always counts as seen.

### The Now tray

| Part | Ready | During a cycle |
|---|---|---|
| Ring | Frame 0 | The jade bead ring steps through its 13 frames over the cycle |
| Icon | The action's icon | Same |
| Line 1 | "Wilderness Cycling" | Same, plus the Madra mini icon and "+13.3 Madra / s" at the right while Madra is drawn |
| Line 2 | The technique's name, and "15 s cycle" at the right | The technique's name, and "9 / 15 s" at the right |
| Rod | Empty | The jade rod fills over the cycle (152 steps) |

Clicking the tray does nothing while cycling (the cycling card isn't in the list).

### NEW on the Wilderness Cycling card

When a technique unlocks (bought on the Path tree), the Wilderness Cycling card in the zone chest shows the NEW seal until the player opens cycling or hovers the card, through the same seen state the activity cards already use.

### Copy

| Where | Text |
|---|---|
| Board label | The cycling action's name: "Wilderness Cycling" |
| Board title | The technique's name: "Smooth Flow Technique" |
| Status, ready | "Click the Madra ball to begin a cycle." The first time; after a cycle, "Click the ball for another cycle." |
| Status, cycling | "Cycling · 9 / 15 s"; "Cycling · 9 / 15 s · follow the ball" while the cursor is outside the ball |
| Status, Madra full | "Madra full · zones still pay XP"; "Madra full" for a technique with no zones |
| Result line | "Last cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 XP"; "Last cycle · +50 Madra · no zones" |
| Log line | "Cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 XP" |
| Floater | "PERFECT +25 XP", "GOOD +15 XP", "OK +5 XP" |
| Techniques header | "Techniques" and "3 learned" |
| Drawer detail | "200 Madra · 15 s cycle · 4 zones"; "50 Madra · 8 s cycle · no zones"; "250 Madra · 8 s cycle · 1 zone" |
| Drawer tag | "IN USE" |
| Auto | "Auto · off", "Auto · on" |
| Close | "Esc" before the × |

Numbers with a decimal point (the rates) go through `LacquerText` ([style guide §5](../../STYLE_GUIDE.md#5-type)). Whole seconds and whole Madra need none.

## Data and save changes

- `CyclingTechniqueData.icon: Texture2D`. The three technique resources point at the mock's `_ai` icons until the user draws their own.
- `SaveGameData.seen_cycling_technique_ids: Array[String]` and `seen_cycling_techniques_initialized: bool`, mirroring `seen_action_ids` and `seen_actions_initialized` (`save_game_data.gd:59-62`). On the first load with the new fields, every technique already unlocked counts as seen, so an old save shows no NEW seals. `reset()` clears both.
- No other save change. Auto stays unsaved, as today.

## Implementation notes (Godot 4.7)

These notes come from a read of the code on 2026-10-22. They name what changes and where, and leave the internals to the builder. Project rules still apply:
- UI nodes live in `.tscn` scenes, and scripts only set data (`Node.new()` is not used for UI);
- Label theme variants come before inline overrides ([UI_STYLING.md](../../UI_STYLING.md)); no new variant is needed;
- GUT tests call production code.

### Approach

| Question | Picked | Turned down | Why |
|---|---|---|---|
| Where the board lives | `CyclingView` stays a `MainView` child (z 3, `main_game.tscn:287`), redrawn as the board in the map gap | Moving cycling into `ZoneView` | `CyclingViewState` and `ActionManager`'s `start_cycling` and `stop_cycling` already own opening and closing; the zone view only needs a cycling mode |
| Clicks on the ball and zones | Keep the `Area2D`s and physics picking, as today. The board and the figure box pass the mouse (`MOUSE_FILTER_PASS`), as today's `MarginContainer` does; the root and the effects layer ignore it; the close button, the Auto toggle and the chest's drawers take it | Hit-testing the ball and zones in the figure box's `_gui_input` | Physics picking only sees a press the GUI left unhandled. A `STOP` control marks it handled. With `IGNORE` the map's `SubViewportContainer` under the board (default `STOP`) would take it. `PASS` makes the board the control the GUI finds, so the map never gets the press, and leaves it unhandled for the areas. Keeping the areas is the smaller change; the `_gui_input` route is the fallback if picking misbehaves |
| Techniques in the chest | A `TechniqueList` beside `ActivityList` in `ZonePanel`, shown while cycling, holding a new `TechniqueDrawer` scene that copies `ZoneActionButton`'s node layout | Feeding techniques through `ActivityList` and `ZoneActionButton` | The card is bound to `ZoneActionData` and `ActionManager` all the way down: its click selects the action, "running" is private and idle-only, NEW keys on `action_id`, and it has no title, icon or running setters |
| Who drives the drawers | `CyclingManager`: drawers read the unlocked and equipped techniques and call `equip_technique()`; the board follows `equipped_technique_changed` | Today's chain, `CyclingTechniqueSlot` → `CyclingTabPanel` → `CyclingView.set_current_technique()` → the manager | One source of truth, and the chest needs no reference to the cycling scene |
| What the tray and the cabinet read | A small read-only snapshot of the running cycle on `CyclingManager` (cycling or not, progress, elapsed, duration, the measured Madra rate), written by `CyclingTechnique` | `NowStrip` or `CultivatorPlate` finding the cycling scene by node name | The zone UI already reads singletons; finding nodes by name is the contract `ZoneTransition` keeps a test to protect (`test_zone_transition.gd:81-91`) |
| Groove | `CyclingGroove` (Node2D) rasterises the baked curve into art-px cells once per technique and draws them in `_draw()`; the trail is an index into the cells sorted by path length | A textured `Line2D` (C3's first idea); a baked texture per technique | A rotated line texture leaves the pixel grid and cannot keep the lit lip under the channel on every side of a loop; baked textures need new art for every technique and a mask for the trail |
| Ball | Keep `PathFollow2D` and the `MadraBall` `Area2D` for the path and zone overlaps; draw the ball and its rings as `LacquerStripRect`s at the snapped position | Keep the shader sprite (`madra_ball.gdshader`) | §3 rule 9: no glow, no continuous time |
| Pellets | `MadraPellet`, with a way to set its texture for the XP tiers, parented to the cycling view's effects layer | Restyling `FlyingParticle` | It builds its nodes in code, draws a trail and sits off the grid. Parented to `current_scene` (z 0) a pellet would draw under the HUD boards (z 1) and the board (z 3) |
| Floaters | Promote `MapFloater` to `scenes/common/lacquer/` (style guide F6) and give each zone one | `FloatingText` | 24 px outlined text, an eased rise and a fade |
| Dock and map input | `MainView` gets one cycling-mode switch that hides the dock and stops the map's input; `CyclingViewState` calls it on enter and exit | The code-built full-rect blocker `ZoneViewState._add_input_blocker()` uses for adventures | It would block the chest too, and UI belongs in scenes |

### Target scene tree

```
MainView
├── ZoneView
│   ├── SubViewportContainer/SubViewport/ZoneTilemap   takes no input while cycling
│   ├── CultivatorPlate                                + get_core_orb_global_position(); its rate covers cycling
│   ├── ZonePanel
│   │   ├── NowStrip                                   + CyclingContent group
│   │   ├── ActivitiesHeader                           "Activities" / "N here", or "Techniques" / "N learned"
│   │   ├── ActivityList                               hidden while cycling
│   │   └── TechniqueList (new)                        TechniqueDrawer per unlocked technique
│   └── Dock                                           hidden while cycling
├── GoalsPanel, LogWindow (z 1)                        stay up while cycling
├── GreyBackground (z 2)                               no longer used by cycling
└── CyclingView (z 3)                                  root full rect, mouse IGNORE, lacquer theme
    ├── Board                                          TextureRect at (680, 24), 564x1036 with its shadow, mouse PASS
    ├── ActionLabel (LabelLacquerDetail), TitleLabel (LabelLacquerPanelTitle)
    ├── EscLabel (LabelLacquerHotkey), CloseButton (TextureButton: close / close_hover)
    ├── FigureBox                                      Control at (710, 104), 500x832, mouse PASS
    │   ├── Body                                       TextureRect, the carved figure
    │   ├── CyclingGroove                              Node2D, draws the channel and its lit part
    │   └── CyclingTechnique                           Node2D at (-70, -24): curve space, as today
    │       ├── CyclingPath2D/PathFollow2D/MadraBall    Area2D + CollisionShape2D (r 29.5)
    │       ├── CyclingZone per zone                    Area2D + LacquerStripRect (zone strip)
    │       ├── BallRing                                LacquerStripRect, 2 frames
    │       └── BallSprite                              LacquerStripRect, 8 frames
    ├── StatusLabel (LabelLacquerName), ResultText (RichTextLacquer)
    ├── AutoToggle                                     TextureButton, toggle mode (cyc_auto / cyc_auto_on) + label
    └── EffectsLayer                                   Control, mouse IGNORE: Madra and XP pellets, one floater per zone
```

Removed from the cycling scenes: `MarginContainer/Panel/HBoxContainer`, the outline `Sprite2D` (its embedded `CompressedTexture2D` goes with it), `CyclingTabPanel`, `CyclingResourcePanel` and `ProgressShaderRect`, `CyclingTechniqueSlot` (its `.tscn` still points at a deleted script path), `PathLine` and `PathGlowLine`, the X ESC `CloseButton` that parsed a fake input event, and the `AutoCycleToggle` button inside `CyclingTechnique` (Auto moves to the board). `FlyingParticle` (`scenes/ui/flying_particle/`) has no other user and goes; `FloatingText` stays for the combat bars and orbs. Shaders retired: `madra_ball`, `cycling_zone`, `path_pulse` and `core_density_fill`; `liquid_wave` and `madra_circle.png` stay for the combat orbs. The user's `Madra-Ball.png` and `cycling_technique_outline.png` stay in the project, unreferenced.

### `CyclingView` and `CyclingTechnique` (`scenes/cycling/`)

- **Unchanged rules.** The curve, the eased tween, the 0.08 s Madra step, the radii and the tier thresholds stay. The Madra step carries its remainder (`timer -= MADRA_PARTICLE_INTERVAL`, not `= 0`).
- **Madra full.** At `CultivationManager.get_max_madra()` the step adds nothing and requests no pellet, and the status line switches (see Copy).
- **Ball.** Each frame the ball and its ring are drawn at the `PathFollow2D` position snapped to even px; the swirl frame is `floor(time × 10) % 8`. The ring shows frame 0 while ready, frame 1 while the cursor is inside the ball during a cycle, and hides otherwise. Tracking keeps today's hit test (29.5 px).
- **Zones.** Each `CyclingZone` keeps a state: idle, active, scored (with its tier) or spent, shown as a frame of the zone strip. They stay visible between cycles: `CyclingZone.setup()` no longer hides them, and `_on_cycle_finished()` no longer hides them. All reset when a cycle starts and when the view closes (today's close leaves the old states up and `active_zone` set, a CYCLING.md bug). `flash_zone()` goes: the stud is the feedback, so today's invisible flash bug goes with it.
- **Groove.** `CyclingGroove` gets the baked points of `technique.path_curve` (offset like `CyclingPath2D`) on `setup()`. Cells are 2x2 screen px. Each cell keeps the shortest path length that covers it, so a crossing lights on the first pass. The lip is the cell under each bottom-edge cell. The trail lights every cell up to the drawn ball's path length.
- **Technique switch.** `setup()` kills the movement tween and returns to ready, so a switch mid-cycle emits no `cycle_completed` (the CYCLING.md bug where the old tween keeps sliding).
- **End of a cycle.** `cycle_completed` carries what the result line needs: the Madra the cycle added, zones scored and total, the PERFECT count and the XP. Today it reports `base_madra_per_cycle × accuracy`, which matches neither. The view writes the footer line and one `LogManager.log_message()` line. Cycling calls `ResourceManager.add_madra(amount, true)`: the `quiet` flag already exists (`resource_manager.gd:77`) and keeps "Gained N Madra" out of the log. To sum what was really added, `add_madra()` returns the amount it added (its other callers ignore the value).
- **While hidden.** The view and its technique stop processing while the view is hidden; today `CyclingTechnique._process` and the old orbs run all session.
- **Pellets.** The view turns `madra_particle_requested` and `xp_particle_requested` into `MadraPellet`s in its effects layer, aimed at the cabinet's orb centres. Madra is still added when the pellet leaves the ball, as today, so the orb leads the pellets by their flight time. XP pellets use the tier's texture; counts stay 8, 5 and 3.
- **Floaters.** One promoted floater per zone, popped with `pop(text, color)` in `ThemeConstants.LACQUER_BRASS`, `LACQUER_CREAM` or `LACQUER_TAN`. The floater does not move itself: the view places it each frame, 56 px above the zone and raised by `get_rise()`, as `MapMarkers` places the map's floater (`map_markers.gd:444-447`).
- **Readouts for the zone UI.** `CyclingTechnique` writes the session snapshot on `CyclingManager` each frame of a cycle: progress, elapsed, duration, and the Madra added over the last second.
- **Pure helpers for tests:** the tier for a distance, the pellet count for a tier, the result line for a result, the groove raster for a list of points, and the Madra steps for a timer and a delta.

### `ZonePanel`, `NowStrip` and `TechniqueDrawer` (`scenes/zones/zone_panel/`, `scenes/cycling/technique_drawer/`)

- **`ZonePanel`** gets a public switch for the techniques mode (called through the cycling-mode switch). It swaps `ActivityList` for `TechniqueList`, sets the header to "Techniques" and "N learned" (the "Activities" label needs a unique name), and relayouts with today's rule (the chest hugs its list: 464 px with three techniques). `TechniqueList` rebuilds on `CyclingManager.technique_unlocked` and `equipped_technique_changed`. `UnlockManager` re-evaluates on every `madra_changed`, so a `condition_unlocked` rebuild can land mid-cycle: in techniques mode the hidden activity list may rebuild, but the relayout must measure the technique list.
- **`TechniqueDrawer`** is a 392x72 drawer with `ZoneActionButton`'s nodes (`Drawer`, `Face`, `Icon` at (16, 20), `Title`, `NewSeal`, `Tag`, the detail line at (64, 38), `HoverFrame`, `FlashFrame`):
  - `setup(technique)` sets the icon, the name and the detail line;
  - in use, the face is `drawer_run` at (−2, −2) with the 4 px shadow, and the tag reads "IN USE" in cream; otherwise the plain face and no tag;
  - a click on a drawer not in use calls `CyclingManager.equip_technique()` and then `flash()` (two brass flashes, as the cards do);
  - hover shows the hover frame and marks the technique seen.
- **`NowStrip`** gets a `%CyclingContent` group beside `%TrainingContent` and `%ForageContent`. It shows when the current action is CYCLING. Its ring and rod read `CyclingManager`'s snapshot in `_process`, as the idle actions read `ActionManager.action_timer` (cycling never starts that timer). The tray ignores the mouse while cycling: its click scrolls to the running card, which is not in the list. The "· paused" line stays for the shop, adventures and dialogue.

### `CultivatorPlate` (`scenes/zones/cultivator_plate/`)

- Add `get_core_orb_global_position()` beside `get_madra_orb_global_position()` (`cultivator_plate.gd:61`).
- The rate: `ActionManager.get_current_madra_per_second()` is training-only today (`action_manager.gd:163`). While cycling it returns the snapshot's measured rate, and the plate refreshes on a rate signal as well as `current_action_changed`. Round to 0.1 before `LacquerText.rate()`, which keeps up to two decimals.

### `MainView` and `CyclingViewState` (`scenes/ui/main_view/`)

- `CyclingViewState.enter()` shows the view, calls the cycling-mode switch on and blocks the full log (`LogWindow.set_full_log_blocked(true)`, as `BookViewState` does); `exit()` undoes all three and hides the view. It no longer shows `GreyBackground` or calls `hide_hud_boards()`. `_on_start_cycling()` gets the `state_stack.has(self)` guard `MerchantViewState` has, so a second `start_cycling` cannot push it twice.
- The switch: `ZonePanel`'s techniques mode, the dock's visibility, and the map's input (for example `SubViewport.gui_disable_input`, or the container's `mouse_filter`; a test must show that a press on the visible map beside the board does not travel). Menu keys need nothing new: while cycling is the top state, I, A, C and P already do nothing.
- `MainView` holds no reference to the cabinet, the chest or the dock today, and they have no unique names in `main_game.tscn` (182-201). Give them unique names and `MainView` references like `zone_view`, so the cycling view finds the cabinet without `find_child()`. `ZoneTransition`'s own lookup and its test (`test_zone_transition.gd:81-91`) are unchanged.

### `CyclingManager` and `ZoneManager` (`singletons/`)

- **Seen techniques:** `mark_technique_seen(id)`, `is_technique_seen(id)`. The equipped technique always counts as seen. `has_unequipped_unlocks()` keeps its meaning and stays unused.
- **The session snapshot** (not saved): whether a cycle runs, its progress, elapsed time and duration, the measured rate, and a signal when the rate changes.
- **NEW on the cycling card:** when a technique unlocks, every CYCLING action is marked unseen, so the card's existing NEW seal shows until it is hovered or the player opens cycling (`select_action()` marks it seen, `action_manager.gd:120`). `ZoneManager` has `mark_action_seen()` and `is_action_seen()` but no way to unmark; add one.

### Art import

Add an `import_cycling.py` beside `kit_cycling.py`. It copies the pieces the decisions use into `assets/ui/lacquer/cycling/` (the technique icons into `assets/ui/lacquer/icons/`), bakes the board's 4 px shadow and the Auto toggle's 2 px one, and skips the turned-down pieces. `import_kit.py` can't take this folder: it aborts on `.gdignore` and `gen/` and expects the chest slices.

## Tests to add or update

- **Pure helpers:** tier thresholds (5.9 px PERFECT, 6 px GOOD, 13.9 GOOD, 14 OK); pellet counts; the result line for a full cycle, no PERFECT, no zones scored and a technique with no zones; the Madra steps carry their remainder at 30, 60 and 144 FPS; the groove raster (cells in path order, a lip under each bottom-edge cell, a crossing keeps its first pass).
- **Cycle:** at the cap nothing is added and no pellet is requested; a technique switch mid-cycle emits no `cycle_completed`; closing mid-cycle resets the zones; zone states go idle → active → scored or spent and reset at the next start; one log line per cycle and no "Gained N Madra" from cycling.
- **Chest:** while cycling the list shows one drawer per unlocked technique in unlock order, the equipped one in use; a click equips and flashes; NEW shows for an unseen technique and clears on hover; the chest height hugs the list; the header reads "Techniques" / "N learned", and "Activities" / "N here" again after close.
- **Now tray:** the cycling texts, ring frame and rod step follow the snapshot. `test_zone_panel.gd`'s "Aura Well · paused while cycling" case becomes the cycling tray; the shop case keeps its paused line.
- **Cabinet:** `get_core_orb_global_position()` is the orb's centre; the rate shows while cycling draws Madra and hides when it stops.
- **Mode switch:** cycling no longer shows `GreyBackground` or hides Goals and the log; the dock hides and returns; a press on the visible map does not travel while cycling.
- **Save:** the seen-technique fields round-trip; an old save marks its unlocked techniques seen; unlocking a technique marks the cycling card unseen.
- **Pieces:** `tests/unit/test_lacquer_pieces.gd` checks the promoted floater where it now lives; `test_map_markers.gd` keeps passing with the moved scene. `MadraPellet` gains a texture setter: `test_madra_pellet.gd` checks the tier textures keep its opaque, palette-only rule.
- **Madra:** cycling adds quietly (no "Gained N Madra"); `add_madra()` returns the amount it added, including 0 at the cap. `test_quiet_madra.gd` keeps its cases.
- **Tests that pin today's behaviour and change:**
  - `tests/unit/test_view_state_hud_positions.gd`: `test_cycling_hides_the_boards` (186-187) becomes "cycling keeps the boards"; `test_boards_stay_hidden_until_the_last_overlay_closes` (210-227) uses `CyclingViewState` as its second holder and needs another one.
  - `tests/integration/test_zone_panel.gd`: `test_tray_reads_paused_while_cycling` (318-325) becomes the cycling tray; the shop case (327-345) keeps its paused line.
  - `tests/integration/test_cultivator_plate.gd`: the rate row hidden while cycling (137-145) now shows while the ball draws Madra.
- Nothing tests `CyclingView`, `CyclingTechnique`, `CyclingZone` or the removed panels today, so no cycling-scene test is deleted. The tests above are the first.

## Docs to update when built

- [CYCLING.md](../../cycling/CYCLING.md): player experience, architecture, visual feedback (the Resources tab goes), the bugs this fixes, Work Remaining. Two lines are already stale: `equipped_technique_changed` has a listener (`CyclingPresenter`), and the cycling card uses `CyclingPresenter`, not the default presenter.
- [TESTING.md](../../testing/TESTING.md): the new tests in the coverage map; it also still says `GreyBackground` is untested.
- [STYLE_GUIDE.md](../../STYLE_GUIDE.md): delete rows C1–C11 and their open questions (C-Q1 to C-Q8 and G3 are answered here), and note F6's floater promotion.
- [ZONES.md](../../zones/ZONES.md): the chest's techniques mode, the cycling tray, NEW on the cycling card, the map's input while cycling.
- [MAIN_VIEW.md](../../infrastructure/MAIN_VIEW.md): cycling uses no backdrop and keeps the HUD boards; the dock hides while cycling.
- [PERSISTENCE.md](../../infrastructure/PERSISTENCE.md): the seen-technique fields.
- [UI_STYLING.md](../../UI_STYLING.md): the cycling pieces and the floater's new home (and that it uses a 16 px `RichTextLacquer`, not `LabelLacquerFloater`).
- [CLAUDE.md](../../../CLAUDE.md): the cycling overlay and HUD-board sentences in View Architecture, and the shader count.
- [docs/superpowers/README.md](../README.md): this spec's row.

## Open / deferred

- **The groove's colour.** Madra blue "for now"; revisit if it should stand apart from the ball.
- **The quest toast over the board's header.** Left as it is until the toast is reworked (Z2), which should place it clear of the cycling board.
- **The user's technique icons.** The `_ai` placeholders stand in.
- **A seated figure, or one per technique.** `CyclingTechniqueData` would need a figure field, and every path would be redrawn.
- **Cycling's Work Remaining** in CYCLING.md: the path perks, the action modifiers, `timing_window_ratio`, combos, a mis-click penalty, audio, Auto as a Copper reward.
- **Balance.** Zone XP against XP per level (about 5 levels in one Smooth Flow cycle at Core Density 32).
- **The rest of F6.** `FloatingText` stays for combat until the combat HUD moves (B9).

## Mock-up

[cycling-view-lacquer-mockup.html](../mockups/cycling-view-lacquer-mockup.html) opens from the repo checkout over a local server (the `lacquer-mockups` entry in `.claude/launch.json` serves the repo at 127.0.0.1:3791) or straight from disk. It loads the fonts, the gold icon and the Madra pellet from `assets/`, the zone kit from `zone-view-lacquer/` and the new pieces from `cycling-view-lacquer/`. Play it: click the ball, keep the cursor inside it, and click a zone as the ball passes.

The bar above the frame switches the layout (A, B the modal board, C the full-screen room), the figure (carved, brass inlay, seated), the groove colour, the ball's motion, the XP pellets' colour, the icons, whether zones show between cycles, and the result line. Capture helpers in the URL hash: `#bar=0` hides the bar, `#demo=1&t=9&freeze=1` plays 9 s by itself and stops, `#madra=255` starts near the cap, `#tech=foundation|smooth|torrent`.

Illustrative in the mock, not in the game: the depicted save (Madra 46 / 260, Core Density 32), the "First Elite" quest, and the NEW seal on Torrential Flow.
