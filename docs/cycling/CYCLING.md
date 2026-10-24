# Cycling System

Last updated: 2026-10-23

## Overview

Cycling is the Foundation-stage active mini-game and the main source of Madra. The player clicks the Madra ball to send it once around a technique's path, a carved groove on a body figure. Keeping the cursor on the ball, out to the edge of the ring around it, draws Madra continuously. Techniques that define **cycling zones** (inflection points) also award Core Density XP when the player clicks the ball again while it is over a zone. The zones take no clicks of their own. Rewards depend on how near the ball's centre is to the zone's centre: PERFECT, GOOD or OK.

The view is a lacquer board in the zone view's map gap ([spec](../superpowers/specs/2026-10-22-cycling-view-lacquer-design.md), [style guide](../STYLE_GUIDE.md)). The zone view's cultivator cabinet is its Madra and Core Density readout and the Madra and XP pellets fly into it. The zone chest lists the techniques, its Now tray shows the running cycle, and one line under the tray reports the last one.

`CyclingManager` (autoload) owns which techniques are unlocked and which one is equipped. It also records which unlocked techniques the player has seen (the NEW seal), holds a snapshot of the running cycle for the cabinet and the Now tray to read, and keeps the last finished cycle's result for the chest's line under the tray. Techniques are unlocked by purchasing Path Tree nodes. A new save starts with the **Foundational Technique**. It has no zones, so it generates Madra but no Core Density XP. XP starts once the player buys the Pure Core Awakening keystone, which unlocks Smooth Flow. Leveling, the Madra cap and breakthrough are covered in [CULTIVATION.md](../cultivation/CULTIVATION.md).

## Player Experience

1. In Spirit Valley, the **Wilderness Cycling** action card appears after the first Celestial Intervener dialogue (event `celestial_intervener_dialogue_1`). Clicking it calls `ActionManager.select_action()`. That stops any running action, such as foraging, and emits `start_cycling`. `CyclingViewState` is pushed and the board opens in the map gap, between the cabinet and the chest. There is no backdrop. The cabinet, the Goals board and the log stay where they are, the chest lists the techniques, the dock hides, the map takes no clicks, and L does not open the full log.
2. The board shows the action's name ("Wilderness Cycling"), the equipped technique's name, a carved body figure with the technique's path as a groove, and the technique's zones as sockets along it. The groove shows lit from the start, so the path stands out from the carved figure. The Madra ball rests at the path's start inside a brass ring, and it breathes while it waits: the ball steps 60 → 64 → 68 → 64 → 60 px every 2 s and the ring grows with it. The status line reads "Click the Madra ball to begin a cycle." (after a cycle, "Click the ball for another cycle."). The pointer cursor shows over the ball whenever a press would do something.
3. **Left-click the Madra ball** to start a cycle. There is no Start button. The ring hides, and the ball stays 60 px while it cycles. The ball travels the path once over `cycle_duration` seconds with a sine ease-in-out, so it moves slower at the ends. Its drawn position snaps to even px, and its swirl steps through 8 frames, 10 a second. The light the groove had before the cycle sweeps away along the path in half a second, well ahead of the slow-starting ball, and behind the ball the groove lights again, cell by cell, in Madra blue.
4. While the cursor is on the ball, out to the solid ring's outer edge (36 px from its centre, where the ball itself is 29.5), a solid tan ring shows around it and the cycle draws a step of Madra every 0.08 s: `base_madra_per_cycle × 0.08 / cycle_duration`. Each step sends a Madra pellet from the ball into the cabinet's Madra orb. The cabinet and the Now tray show the Madra drawn per second (`+13.3 / s`). When the cursor drifts off, the ring hides and the status line adds "follow the ball". At the Madra cap no Madra is drawn and no pellet flies, and the status line reads "Madra full · zones still pay XP" ("Madra full" for a technique with no zones).
5. A technique's zones show as sockets with a solid tan rim along the groove, even between cycles. A zone gets a brass rim while the ball overlaps it. **Pressing the ball** then scores that zone **PERFECT / GOOD / OK** by how close the ball's centre is to the zone's, and adds the zone's XP to Core Density. If two zones are active, the press scores the nearer. The zone takes a brass, cream or tan stud, a floater pops above it (`PERFECT +25 XP`), and 8, 5 or 3 XP pellets fly from it into the cabinet's Core orb. A zone the ball leaves unpressed ends as a bare socket. Each zone scores once per cycle. A press while no zone is active does nothing. The zones take no clicks of their own.
6. When the ball reaches the end, the zone chest shows the result in one tan line right under the Now tray ("Last cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 XP") and the log gets one line in the Madra tone ("Cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 XP"). The board has no result line of its own. The chest's line stays until the next cycle ends, and goes when the technique switches or the board opens again. The studs and the lit groove stay until the next cycle starts. If the **Auto** toggle (`Auto · off` / `Auto · on`, not saved) is on, the next cycle starts at once. Otherwise the ball waits in its brass ring and breathes again from the small ball. Auto only chains cycles: nothing is earned unless the cursor is in the ball. There is no idle or offline cycling.
7. The chest's **Techniques** list has one drawer per unlocked technique, in unlock order: its icon, its name and a detail line (`200 Madra · 15 s cycle · 4 zones`). The equipped technique's drawer is pulled out and tagged IN USE. Clicking another drawer equips it and flashes its frame. A running cycle ends with no result, and the board moves to the new technique, ready. A technique the player has not seen shows a NEW seal after its name until the pointer leaves its drawer or the player equips it. It does not clear as the pointer arrives: the chest turns to the drawers under the cursor that has just clicked the Wilderness Cycling card, and the seal would go before the player saw it. After any technique unlocks, the Wilderness Cycling card in the chest shows NEW until the player hovers it or opens cycling.
8. The Now tray shows the cycle: its jade bead ring and rod fill through the cycle, beside "Wilderness Cycling" with the Madra rate, the equipped technique and "9 / 15 s" ("15 s cycle" until a cycle runs).
9. **Esc** or the board's **×** closes the view through `ActionManager.stop_action()`. A cycle in progress ends with no result. Madra and XP already paid stay, because both are paid out as they are earned. The chest lists its activities again, the dock returns, the map takes clicks again, and the zone's idle action resumes ("Resumed Aura Well").

## Architecture

```
MainView (Control)                                   — main_view.gd
  MainViewStateMachine/CyclingViewState (Node)       — cycling_view_state.gd (push on start_cycling, pop on stop_cycling)
  ZoneView/CultivatorPlate, ZonePanel, Dock, SubViewport — stay up; MainView.set_cycling_mode() turns the chest, dock and map over
  GoalsPanel, LogWindow (z 1)                        — stay up; the full log is blocked while cycling
  CyclingView (Control, z_index 3, hidden by default) — cycling_view.gd (class CyclingView), lacquer theme
    Board (NinePatchRect, mouse Pass)                — lacquer_cyc_board_ai.png at (680, 24), 564x1036 with its 4 px shadow; grows by stretching art rows 132–535
    ActionLabel, TitleLabel, EscLabel                — "Wilderness Cycling", the technique's name, "Esc"
    CloseButton (TextureButton)                      — the kit's carved ×; pressed → ActionManager.stop_action()
    FigureBox (Control, mouse Pass)                  — (698, 104), 524x872, centred on the board's art
      Body (TextureRect)                             — the carved figure, mouse ignored
      CyclingTechnique (Node2D)                      — cycling_technique.tscn at (-70, -24), the curves' space; path_scale 1.048 about path_pivot (70, 24)
    StatusLabel (Label)                              — (710, 990) under the figure, beside the Auto toggle; wraps
    AutoToggle (TextureButton, toggle mode)          — (1090, 982); AutoLabel, AutoHover (LacquerFrameOverlay)
    EffectsLayer (Control, mouse Ignore, last child) — Madra and XP pellets, one LacquerFloater per zone
```

```
CyclingTechnique (Node2D)                            — cycling_technique.gd
  CyclingGroove (Node2D)                             — cycling_groove.gd: the carved channel, drawn per art pixel
  CyclingPath2D (Path2D)                             — curve = technique.path_curve, scaled by path_scale
    PathFollow2D (rotates = false, loop = false)     — the true ball position
      MadraBall (Area2D)                             — the only press target: a left press calls press_ball()
        CollisionShape2D (CircleShape2D r 36)        — CURSOR_REACH: a press out to the ring's edge lands
    CyclingZone1..N (Node2D)                         — cycling_zone.tscn, built by _build_zones(): no shape, no input
  BallRing (LacquerStripRect, 88x88 frames)          — frame 0 the ready ring, 1 the solid tan ring, 2 and 3 the ready ring grown for the breath
  BallSprite (LacquerStripRect, 68x68 frames)        — the 8-frame swirl, one row per breath size (60, 64 and 68 px)

CyclingZone (Node2D)                                 — cycling_zone.gd
  Socket (LacquerStripRect, 48x48 frames)            — one frame per State, mouse ignored
```

```
TechniqueList (Control)                              — zone_panel/technique_list/technique_list.gd, in the zone chest
  Drawers (VBoxContainer, separation 8)              — one TechniqueDrawer per unlocked technique

TechniqueDrawer (Control, 392 x 72 or taller)        — technique_drawer/technique_drawer.gd, ZoneActionButton's layout
  Drawer (Control)                                   — moves to (-2, -2) while the technique is in use
    Face (NinePatchRect), Icon (32x32 at 16, 20), Title, NewSeal, Tag (IN USE), Detail (64, 38 under a one-line name), HoverFrame, FlashFrame
```

`CyclingView` is instanced in `main_game.tscn` for the whole session and hidden. `MainView._ready()` hands it the cabinet (`cultivator_plate`, through `_hand_cabinet_to_cycling_view()`); with none, no pellet is sent. `CyclingTechnique.technique_data_input` is null in the scene, so `CyclingView._ready()` plays the equipped technique. Showing the view turns processing on for the view and the technique, and hiding it turns both off, ends a running cycle without a result, hides every floater and frees the pellets in flight, so reopening starts clean.

Only the ball takes presses. It takes them through physics picking, which only sees a press the GUI left unhandled. The zones have no `Area2D`: their sockets ignore the mouse, so a zone never stands between the player and a press meant for the ball over it. The board and the figure box pass the mouse, the view's root and the effects layer ignore it, and the close button, the Auto toggle and the chest's drawers take it.

`CyclingTechnique` is driven by `advance(delta, cursor_global)`. `_process()` feeds it the mouse, and the tests feed it a chosen cursor. `CyclingRules` and `CycleResult` are pure and separate, so they test without a scene.

The techniques' paths and zones are authored on a 500x832 footprint, the size the figure had before the review of 2026-10-23, and the board's figure is 1.048x that (see [The Board](#the-board-cyclingview)). `CyclingTechnique.setup()` scales the path's points, its handles and the zones' positions by `path_scale` about `path_pivot`, so the data resources stay as authored. `path_scale` is 1.048 on the board, and `path_pivot` is (70, 24), the figure's top-left corner in curve space. Zone positions snap to even px afterwards, so sockets and floaters stay on the 2 px grid. The ball, the zones' size and the scoring radii do not scale. At a scale of 1 the technique plays its own curve.

## Data Model

### CyclingTechniqueData (`scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd`)
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `id` | `String` | `""` | Unique snake_case key. Used by `CyclingManager`, `SaveGameData` and path-node effects |
| `technique_name` | `String` | `"Basic Cycling"` | Display name |
| `icon` | `Texture2D` | `null` | 16 art px shown at 32 in the technique's drawer. All three techniques point at `_ai` placeholders |
| `path_curve` | `Curve2D` | — | Path the ball follows, in the curve's space as authored. The technique plays a copy scaled by `path_scale`, and leaves this resource as it is |
| `cycle_duration` | `float` | `10.0` | Seconds for one full pass |
| `base_madra_per_cycle` | `float` | `25.0` | Madra for a cycle with the cursor in the ball the whole time |
| `cycling_zones` | `Array[CyclingZoneData]` | `[]` | Scoring zones. Empty means no Core Density XP |

### CyclingZoneData (`.../cycling_technique/cycling_zone_data.gd`)
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `position` | `Vector2` | `(0, 0)` | Zone centre in the curve's space, as authored on the 500x832 footprint. The technique scales it by `path_scale` about `path_pivot` and snaps it to even px, so the socket sits on the 2 px grid |
| `timing_window_ratio` | `float` | `0.05` | **Never read.** Zone radius is `CyclingRules.ZONE_RADIUS` (20) |
| `perfect_xp` | `int` | `15` | XP for PERFECT |
| `good_xp` | `int` | `10` | XP for GOOD |
| `ok_xp` | `int` | `5` | XP for OK |

### CyclingTechniqueList (`.../cycling_technique/cycling_technique_list.gd`)
| Field | Type | Description |
|-------|------|-------------|
| `cycling_techniques` | `Array[CyclingTechniqueData]` | Full catalog. `CyclingManager` preloads `resources/cycling/cycling_techniques/cycling_technique_list.tres` |

### CyclingActionData (extends `ZoneActionData`)
| Field | Type | Default | Status |
|-------|------|---------|--------|
| `madra_multiplier` | `float` | `1.0` | Never applied |
| `cycle_duration_modifier` | `float` | `1.0` | Never applied |
| `xp_multiplier` | `float` | `1.0` | Never applied |
| `madra_cost_per_cycle` | `float` | `0.0` | Never applied |

The action resource never reaches the view. `CyclingViewState._on_start_cycling(_data)` ignores its argument, and the view reads only the action's name from `ActionManager.get_current_action()`.

### SaveGameData (cycling fields)
| Field | Type | Default |
|-------|------|---------|
| `unlocked_cycling_technique_ids` | `Array[String]` | `["foundation_technique"]` |
| `equipped_cycling_technique_id` | `String` | `"foundation_technique"` |
| `seen_cycling_technique_ids` | `Array[String]` | `[]` |
| `seen_cycling_techniques_initialized` | `bool` | `false` |

Madra lives in `SaveGameData.madra`, owned by `ResourceManager`. Core Density lives in `core_density_xp`, `core_density_level` and `current_advancement_stage`, owned by `CultivationManager`. The session snapshot, the last cycle's result, the Auto toggle and the cycle itself are never saved.

## Core Systems

### Cycle Lifecycle (`CyclingTechnique`)
The technique is either ready or cycling. There is no state enum and no tween.

```
MadraBall.input_event (left press) → press_ball()
  ready → start_cycle()                                       [only with a technique]
  cycling → try_score_zone(the ACTIVE zone nearest the true ball)   [nothing when no zone is ACTIVE]
start_cycle()
  → every zone IDLE (last cycle's studs clear), the ring hides
  → the groove keeps the last cycle's light: the trail and the sweep are zeroed, so the sweep clears it (below)
  → CyclingManager.start_cycle_session(cycle_duration); cycling_started.emit()
advance(delta, cursor) while ready: the swirl and the breath step (below)
advance(delta, cursor) while cycling, in this order:
  1. elapsed += delta, up to cycle_duration (a frame that runs past the end counts only the time left);
     the ball moves to the eased share of the path (0.5 - 0.5 cos(PI × elapsed / duration))
     and is drawn at that position snapped to even px, in the 60 px row of the ball strip
  2. the cursor within CURSOR_REACH (36 px, the solid ring's outer edge) of the drawn ball is "tracking": the solid ring shows, otherwise it hides
  3. while tracking, the Madra timer gathers the frame's time and draws a step per 0.08 s (below)
  4. zones turn ACTIVE or SPENT (below); the groove's sweep runs on and its trail lights up to the true ball's path length
  5. the frame joins the rate window and the session snapshot is updated
  6. once elapsed reaches cycle_duration: _finish_cycle()
_finish_cycle()
  → open zones SPENT, the session ends, the ball goes back to the start in its brass ring, breathing from the small ball
  → the groove stays lit, as the full trail left it
  → cycle_completed(result); with auto_cycle on, start_cycle() at once and the rate window carries over
stop_cycling() / setup(technique) → ready: no result, zones IDLE, groove lit, its session ended if it was cycling
_exit_tree() mid-cycle → its session ended
ActionManager.stop_cycling → CyclingView._on_stop_cycling() → CyclingTechnique.stop_cycling()
```

The ball has two positions. The **drawn** one, snapped to the 2 px grid, is what the player sees, so tracking, the ring and the pellets use it. The **true** one, the `PathFollow2D`'s, is where the ball is on the path, so which zones it overlaps, how near a press was and how far the groove is lit use it.

**The waiting ball breathes.** While no cycle runs, `advance()` counts `_breath_clock`, and the static `breath_level(seconds)` turns it into a level 0, 1 or 2 (`roundi(1 - cos(TAU × seconds / BREATH_SECONDS))`). Every `BREATH_SECONDS` (2 s) the ball steps 60 → 64 → 68 → 64 → 60 px, holding each size about a third of the time with the largest at the middle. Level n shows row n of the ball strip, and the ready ring's frame 0, 2 or 3, so the brass ring grows with the ball. The steps are whole, so the art stays on the 2 px grid. Every return to ready (`setup()`, `stop_cycling()`, a finished cycle) restarts the breath from the small ball. While a cycle runs, the ball stays on the 60 px row.

A cycle that is stopped, or cut off by switching technique, emits nothing. After a frame hitch (one long `delta`) the Madra steps it covered are all drawn, up to the cycle's end, and a zone the ball jumped past ends the cycle SPENT, never stuck IDLE or ACTIVE.

### CyclingTechnique and CyclingZone API
| Member | Behaviour |
|--------|-----------|
| `CyclingTechnique.setup(data)` | Sets the technique up: its path scaled by `path_scale`, its groove (lit) and its zones, all ready. A running cycle ends without a result. A null technique leaves nothing to play |
| `start_cycle() -> bool` | Starts a cycle from ready only, and returns whether one started |
| `stop_cycling()` | Ends any cycle without a result and puts everything back to ready |
| `advance(delta, cursor_global)` | One frame of play, in the order above |
| `press_ball() -> bool` | The press. From ready it starts a cycle. During one it scores the ACTIVE zone nearest the true ball through `try_score_zone()`, and does nothing when no zone is ACTIVE. Returns whether it did either. `%MadraBall`'s `input_event` calls it on a left press |
| `try_score_zone(zone) -> bool` | Scores an ACTIVE zone while a cycle runs |
| `wants_pointer(cursor_global) -> bool` | Whether a press there would do something: the cursor is over the ball, and either no cycle runs or a zone is ACTIVE |
| `breath_level(seconds) -> int` | Static. The waiting ball's level 0, 1 or 2 (60, 64 or 68 px) `seconds` into its wait |
| `is_cycling()`, `is_tracking()`, `get_ball_global_position()`, `get_current_result()` | State getters. The result is the running cycle's so far, or the last finished cycle's until the technique goes back to ready |
| `auto_cycle`, `technique_data`, `cycling_zones`, `technique_data_input` | The Auto flag, the technique being played, its zones in data order, and the export (null in the scene) |
| `path_scale`, `path_pivot` | Exports. `setup()` scales the path's points, handles and the zones' positions by `path_scale` about `path_pivot`. They are 1.048 and (70, 24) on the board and 1 and (0, 0) by default |
| Constants | `BALL_RADIUS` 29.5 (the ball itself: a zone opens when its edge reaches it), `CURSOR_REACH` 36 (the solid ring's outer edge: tracking, presses, the hand cursor), `MADRA_PARTICLE_INTERVAL` 0.08, `SWIRL_FRAMES` 8, `SWIRL_FPS` 10, `RATE_WINDOW` 1.0, `GROOVE_SWEEP_SECONDS` 0.5, `BREATH_SECONDS` 2.0 |
| `CyclingZone.setup(data)`, `set_state(state)`, `get_state()`, `is_open()`, `state_for_tier(tier)` | The zone's data and `State`; `is_open()` is IDLE or ACTIVE; `state_for_tier()` is static and gives a tier's stud. A `Node2D` with no shape and no signals |

### Madra Generation
- While the cursor is tracking, `_madra_timer` gathers the frame's time. Each time it reaches `MADRA_PARTICLE_INTERVAL` (0.08 s) it subtracts the interval, keeping the remainder, and draws one step. Income is therefore the nominal rate at any frame rate (tests run 30, 60 and 144 FPS).
- The frame that ends a cycle gives the timer only the time left in the cycle, so a long hitch draws no step past the end. A step pays once the timer is within `_STEP_EPSILON` (1e-6 s) of the interval, which absorbs float error: an 8 s cycle holds exactly 100 steps, so its 100th falls on the cycle's last instant, and without the tolerance 1/120 s frames paid 99. A fully tracked cycle therefore pays the same whole steps at any frame rate: 100 for the 8 s techniques, and 187 for Smooth Flow (199.47 Madra; its 15 s hold 187.5 steps). Tests run 60, 120 and 144 FPS, uneven frames and a 16 s hitch.
- A step is `ResourceManager.add_madra(base_madra_per_cycle × 0.08 / cycle_duration, true)`: quiet, so nothing reaches the log. It does nothing at or above the cap, so Madra already over the cap is left alone and no pellet flies. It counts only for the Madra it really added, which is less than a full step when the cap cuts it short. A step that added something goes into `CycleResult.madra_added` and emits `madra_particle_requested(drawn ball centre)`.
- `ResourceManager.add_madra()` clamps the pool to the stage cap (`100 + 5 × Core Density level` at Foundation; see [CULTIVATION.md](../cultivation/CULTIVATION.md#madra-cap)).
- Madra is added as the pellet leaves the ball, so the cabinet's orb leads the pellets by their flight time.
- **The rate** shown on the cabinet and the Now tray is the Madra drawn per second, weighted by time. Every running frame joins a window of (seconds, Madra drawn), and the window keeps the shortest run of the newest frames that covers `RATE_WINDOW` (1 s). The rate is the Madra in it over the time it covers.
- The rate reads `base_madra_per_cycle / cycle_duration` exactly (13.3 for Smooth Flow) under steady tracking below the cap, at any frame rate. Within a second of the cursor starting or stopping, or of the cap being met, it rises to that or falls to 0. An Auto restart carries the window into the next cycle and rewrites the snapshot in the same `advance()`; any other ending empties it.

### Zones and Accuracy Tiers
- A `CyclingZone` holds a `State` and shows it as one frame of the zone strip: `IDLE` (solid tan rim: between cycles, and during one until the ball reaches the zone), `ACTIVE` (brass rim: the ball overlaps it), `SPENT` (bare socket: the ball left it unscored), and the studs `PERFECT` (brass), `GOOD` (cream) and `OK` (tan). A zone never hides: the studs of the last cycle stay up until the next one starts.
- `_update_zones()` makes each open zone (IDLE or ACTIVE) ACTIVE while the true ball is within 49.5 px of its centre (the ball's 29.5 plus the zone's 20), and SPENT when an ACTIVE one is left. `_finish_cycle()` spends every zone still open.
- A zone takes no press. A left press on the ball goes to `press_ball()`, which during a cycle hands the ACTIVE zone nearest the true ball to `try_score_zone(zone)`. That scores only while a cycle runs and the zone is ACTIVE, and the press does nothing when no zone is. The tier comes from the distance between the **true** ball and the zone's centre, through `CyclingRules.tier_for_distance()`:

| Tier | Ball-to-zone distance | XP | Colour | XP pellets |
|------|-----------------------|----|--------|------------|
| PERFECT | under 6 px (ratio under `PERFECT_RATIO` 0.3 of the 20 px radius) | `perfect_xp` | brass | 8 |
| GOOD | under 14 px (ratio under `GOOD_RATIO` 0.7) | `good_xp` | cream | 5 |
| OK | otherwise, up to about 49.5 px | `ok_xp` | tan | 3 |

- Scoring calls `CultivationManager.add_core_density_xp(xp)`, adds to the `CycleResult` (zones scored, PERFECT count, XP), sets the zone to its stud and emits `zone_scored(zone, tier, xp)`. The view pops the zone's floater and sends the pellets.
- `wants_pointer(cursor_global)` tells the view when a press would do something, for the pointer cursor: the cursor is over the ball and either no cycle runs (the press starts one) or a zone is ACTIVE (it scores). Over the ball in the middle of a cycle with no ACTIVE zone, the cursor stays an arrow.

### CyclingRules and CycleResult (`scenes/cycling/cycling_technique/`)
- `CyclingRules` (static): `Tier { OK, GOOD, PERFECT }`, `ZONE_RADIUS`, `PERFECT_RATIO`, `GOOD_RATIO`, `tier_for_distance(distance)`, `xp_for_tier(zone, tier)`, `pellet_count(tier)`, `tier_name(tier)` and `tier_color(tier)` (`ThemeConstants.LACQUER_BRASS`, `LACQUER_CREAM`, `LACQUER_TAN`).
- `CycleResult` (`RefCounted`) holds the totals of one cycle: `madra_added`, `zones_scored`, `zones_total`, `perfect_count` and `xp`. `summary()` joins the parts with " · ": "+186 Madra", "3 / 4 zones" (or "no zones" for a technique without any), "1 PERFECT" when there was one, "+75 XP" when any was paid. `result_line()` is "Last cycle · " and the summary, for the chest's line under the Now tray. `log_line()` is "Cycle · " and the summary, for the log. The Madra is rounded to whole Madra and counts only what was really added.

### The Groove (`CyclingGroove`)
- `setup(curve)` rasterises the curve once into cells of 2 px (one art pixel). Each sampled point covers a 2 x 2 block of cells, so the channel is about two cells thick. Each cell keeps the shortest path length that covers it, so a crossing lights on its first pass. The cell under each bottom-edge cell is its lip, drawn in `LACQUER_RIM`. Cells are ink until lit. `setup()` leaves a new groove dark: no trail, and the whole path swept.
- A cell shows lit while the ball's trail covers it or the sweep has not reached it yet. A lit cell takes the Madra ramp: `LACQUER_MADRA_HI` on a top edge, `LACQUER_MADRA_MID` on a bottom edge, `LACQUER_MADRA` between.
- `set_lit_length(length)` is the **trail**: it lights every cell within the length the ball has travelled. A negative length lights none. It redraws only when the number of trail cells changes.
- `set_swept_length(length)` is the **sweep**: it clears the last cycle's light from every cell within the length. The cells past it keep their light, and the trail still lights the cells it covers. A negative length clears none, so every cell past the trail shows lit. It redraws only when the swept count changes.
- `light_all()` lights every cell, as a full cycle leaves the groove. `get_lit_count()` counts the cells that show lit: the trail's cells plus the cells the sweep has not reached.
- **Lit between cycles.** The groove shows lit before the first cycle and after any end, stop or switch, as a full cycle leaves it: `CyclingTechnique` calls `light_all()` whenever it goes back to ready. With the groove dark between cycles, the path was hard to tell from the carved figure (the user's review, 2026-10-23). A cycle's start zeroes the trail and the sweep, so the old light stays. Each frame then moves the sweep along the path at an even pace, the whole path in `GROOVE_SWEEP_SECONDS` (0.5 s), and the trail up to the true ball's travelled length. The ball eases in, so the sweep runs well ahead of it, and the ball's trail lights the groove again behind it.
- `build_cells(points)` and `lip_cells(cells)` are static and pure. Place the node on an even screen px (the technique sits at (-70, -24) in a figure box at (698, 104)), or its cells leave the grid.

### The Board (`CyclingView`)
- **Status line** (`StatusLabel`), by `CyclingView.status_line()`: `Click the Madra ball to begin a cycle.` until a cycle has ended since the board was shown or the technique was switched, then `Click the ball for another cycle.`. While a cycle runs: `Cycling · 9 / 15 s` (the whole seconds gone, floored, and the length) with ` · follow the ball` added while the cursor is off the ball. At the Madra cap it reads `Madra full · zones still pay XP` (`Madra full` with no zones), tracking or not.
- **Figure and footer**: the board has no result line, so the carved figure takes the row the line left. It is 524x872: traced again from the user's standing outline at 262x436 art px, 1.048x the 500x832 figure it replaced, and the same ratio. `FigureBox` sits at (698, 104), centred on the board's art, and the status line (710, 990) and the Auto toggle (1090, 982) move down into the row under it. The techniques' paths and zones are scaled by the same 1.048 (see the path scale under Architecture).
- **No text is cut off.** The action's name, the technique's name and the status line wrap instead of ending in "…". `_relayout_board()` stacks the board from its top whenever one of them changes: a second line of a name pushes the figure box down to stay 14 px under it (on even px), and the footer with it, where the status line and the Auto toggle centre on the taller of the two. The board keeps its art's height until the footer comes within 30 px of its bottom (`BOARD_ROOM`: the bottom frame, the corner brackets and the shadow), then grows to keep that room: it is a `NinePatchRect` whose plain middle, art rows 132–535 (all the same), stretches. With a line each, everything stands where the scene puts it, and a two-line name with a two-line status line still ends the board on screen. No shipped text wraps today: the longest name takes 259 of the title's 468 px, the longest status line 285 of 368.
- **Last cycle**: when a cycle ends, `_on_cycle_completed()` hands its `CycleResult` to `CyclingManager.set_last_cycle_result()`. The board shows nothing of it: the zone chest shows `CycleResult.result_line()` under the Now tray (see The Chest While Cycling). The same cycle writes one `[color=cyan]` line to the log (`CycleResult.log_line()`); cycling no longer writes "Gained N Madra". The view clears the kept result with `clear_last_cycle_result()` when the board is shown and when the technique switches, and a save reset clears it too. The line sits by the Now tray, which already reads the running cycle, instead of away from it in the board's footer.
- **Pellets**: one `MadraPellet` per step, added to the effects layer. Madra pellets keep the Madra-blue art and fly from the drawn ball to the cabinet's Madra orb in 0.6 s, bowing up to 60 px. XP pellets use `set_texture()` for the tier's colour, start at fixed offsets within 7 px of the zone's centre and fly to the cabinet's Core orb: the first in 0.55 s bowing up to 40 px, each next 0.03 s longer and 10 px wider. There is no pulse on arrival.
- **Floaters**: one `LacquerFloater` per zone, in the effects layer. `zone_scored` pops it with `PERFECT +25 XP` in the tier's colour. The view places it each frame with its top 56 px above the zone's centre, raised by its rise (40 px in 20 steps over 1 s, then hidden).
- **Auto**: `AutoToggle` sets `CyclingTechnique.auto_cycle` and its label (`Auto · on`, cream and 2 px lower; `Auto · off`, tan). It is not saved.
- **Technique switch**: `equipped_technique_changed` calls `CyclingTechnique.setup()`, which ends a running cycle without a result, rebuilds the zones and the floaters, sets the title and clears the last cycle's result and the "another cycle" text.

### Technique Unlock and Equip (`CyclingManager`)
| Method | Returns | Behaviour |
|--------|---------|-----------|
| `get_unlocked_techniques()` | `Array[CyclingTechniqueData]` | Resolves saved IDs against the catalog in unlock order and skips unknown IDs |
| `get_equipped_technique()` | `CyclingTechniqueData` | `null` if none or unknown |
| `unlock_technique(technique_id)` | `void` | Idempotent. Calls `push_error` for an unknown ID. Otherwise appends to save data and emits `technique_unlocked` |
| `equip_technique(technique_id)` | `void` | Calls `push_error` if the ID is unknown or locked. Otherwise sets save data and emits `equipped_technique_changed` |
| `is_technique_unlocked(technique_id)` | `bool` | — |
| `has_unequipped_unlocks()` | `bool` | True if any unlocked ID differs from the equipped one. No caller: the NEW seals replaced the badge it was meant for |
| `mark_technique_seen(technique_id)` | `void` | Records the ID in `seen_cycling_technique_ids`. Ignores an empty ID or one already recorded |
| `is_technique_seen(technique_id)` | `bool` | True when recorded, and always true for the equipped technique. False for an empty ID |
| `start_cycle_session(duration)` | `void` | Starts the snapshot: running, no time elapsed, rate 0. A session already running is replaced |
| `update_cycle_session(elapsed, madra_rate)` | `void` | Sets the elapsed seconds and the measured rate. Ignored while no session runs |
| `end_cycle_session()` | `void` | Clears the snapshot. Announces the drop to 0 if a rate was showing |
| `is_cycle_running()`, `get_cycle_progress()`, `get_cycle_elapsed()`, `get_cycle_duration()`, `get_madra_rate()` | `bool`, `float` | The snapshot: 0 to 1 progress, seconds, and Madra per second. All 0 or false when idle |
| `set_last_cycle_result(result)` | `void` | Keeps `result` as the last finished cycle's and emits `last_cycle_changed(result)`. `CyclingView` calls it when a cycle ends |
| `clear_last_cycle_result()` | `void` | Forgets the kept result and emits `last_cycle_changed(null)`, only if one was kept |
| `get_last_cycle_result()` | `CycleResult` | The kept result, or `null` when none is |

- The catalog index (`_techniques_by_id`) is built in `_ready()` from `cycling_technique_list.tres`. Entries with an empty `id` are skipped. `_live_save_data` re-points on `PersistenceManager.save_data_reset`, and the seen record is initialised again.
- **Unlock path:** `PathManager.purchase_node()` loops over the node's effects and calls `CyclingManager.unlock_technique(effect.string_value)` for each `UNLOCK_CYCLING_TECHNIQUE`. `technique_unlocked` then rebuilds the chest's `TechniqueList`, makes `ZoneManager` mark every CYCLING action unseen (the Wilderness Cycling card shows NEW until it is hovered or cycling opens) and queues a rebuild of the chest so the card repaints. Locked techniques are never listed.
- **Equip path:** a press on a `TechniqueDrawer` calls `CyclingManager.equip_technique(id)`. `equipped_technique_changed` then reaches the board (`CyclingView` sets the technique up), the `TechniqueList` (it refreshes every drawer, since the drawers do not listen), the Now tray and the cycling card's `CyclingPresenter`.
- **On load:** `CyclingView._load_equipped_technique()` plays the equipped technique. If there is none, it equips the first unlocked one.
- **Seen techniques:** the first time a save is initialised (`seen_cycling_techniques_initialized` false), every technique unlocked at that moment counts as seen, so an old save shows no NEW seals. A drawer marks its technique seen when the pointer leaves it and when it is pressed to equip it, never as the pointer arrives.
- **The session snapshot** is written by `CyclingTechnique` each frame of a cycle and read by `NowStrip` (ring, rod, figure, rate), `CultivatorPlate` (through `ActionManager.get_current_madra_per_second()`) and `CyclingView` (the status line). `madra_rate_changed(rate)` fires when the measured rate moves to another tenth (`RATE_STEP`, the step the cabinet and the Now tray show it in), and on the drop to 0 when a session ends.
- **The last cycle's result** is set by `CyclingView` when a cycle ends and read by `ZonePanel`, which shows its `result_line()` under the Now tray while the chest lists the techniques. It is never saved. The view clears it when the board is shown and when the technique switches, and a save reset clears it too. `last_cycle_changed(result)` passes `null` when it is cleared.
- **The session belongs to the technique that started it.** `setup()` and `stop_cycling()` end it only if that technique was cycling, so another `CyclingTechnique` loading (its `_ready()` runs `setup()`) leaves a running session alone; the Tribulation design reuses cycling components. A technique that leaves the tree mid-cycle ends its own session in `_exit_tree()`.

### The Chest While Cycling
`MainView.set_cycling_mode(true)` calls `ZonePanel.set_techniques_mode(true)`. The header reads "Techniques" and "3 learned" and a `TechniqueList` takes the activity list's place; the chest hugs it (464 px tall with three techniques, 490 px once the last cycle's line shows). The list neither scrolls nor folds. Each `TechniqueDrawer` is a drawer on `ZoneActionButton`'s layout, 392 wide and 72 tall while its name and its detail line take a line each, and it shares the cards' static `layout_title_row()`:

- `setup(technique)` sets the icon, the name and the detail line (`TechniqueDrawer.detail_text()`: `200 Madra · 15 s cycle · 4 zones`, `50 Madra · 8 s cycle · no zones`, `250 Madra · 8 s cycle · 1 zone`).
- `refresh()` pulls the drawer out to (-2, -2) on the running face with an IN USE tag in cream while its technique is the equipped one, shows or hides the NEW seal and lays the text out around it.
- **Long text wraps and the drawer grows.** Nothing on a drawer is cut off. `layout_title_row(..., true)` wraps the name where the NEW seal or the tag starts and hugs its widest line, and the seal stays beside its first line. Only the drawer in use has a tag, so every other drawer, every NEW one among them, runs its row on to the detail line's 316 px: "Smooth Flow Technique" and its seal fit one line. The detail line wraps inside its 316 px, 4 px under the name's last line. The drawer is 16 px taller than the detail line's bottom, on even px and never under 72. Its face is a `NinePatchRect` that stretches rows 60 and 61, the plain band under the icon socket (they match, so the socket, the edges and the in-use brackets show as drawn; the icon stays at y 20), and its hover and flash frames follow. A change of height emits `height_changed`, and a drawer whose name wrapped only beside its seal shrinks back when the seal clears.
- A left press on a drawer not in use equips its technique, marks it seen, and flashes the brass frame twice. A press on the drawer in use does nothing. Hover shows the thin frame. The pointer leaving the drawer marks the technique seen, which clears its NEW seal; the pointer arriving does not, because the drawers can turn up under a cursor that has just clicked the cycling card.
- `is_in_use()`, `is_new_shown()` and `flash()` are public for the list and the tests. The drawer does not listen to `CyclingManager`: the list calls `refresh()` on every drawer when the equipped technique changes.
- `TechniqueList` has `build()`, `get_content_height()` (the drawers' heights and the gaps), `get_drawer(technique_id)`, `get_drawer_count()` and the signal `layout_changed`, which it also emits when a drawer's height changes, so the chest grows or shrinks with the drawer. It rebuilds on `technique_unlocked` whether shown or not, so it is current the moment the chest turns to it, and refreshes the drawers on `equipped_technique_changed`.
- The lore panel stays as the player left it when cycling opens.
- **The last cycle's line.** Once a cycle has ended, `%LastCycleLabel` shows `CycleResult.result_line()` right under the Now tray, in the techniques mode only. It is a `LabelLacquerDetail` (tan) at (16, 180), 408 wide, and ignores the mouse. A line too long for the tray wraps (a cycle of 12345 Madra and 99999 XP takes two lines). It pushes the lore panel, the header and the list down by its height on even px (18 px a line) and `LAST_CYCLE_GAP` (8 px): 26 px for one line (`LORE_TOP` 182 → 208), 44 for two, and the chest grows as much. `ZonePanel` follows `CyclingManager.last_cycle_changed`: the line shows or hides and the chest lays out again at once, with no rebuild. It goes when the board opens, the technique switches or the save resets, and when the chest turns back to its activities.
- The detail is in [ZONES.md](../zones/ZONES.md#zone-chest-zonepanel).

### Path Tree Hook Points
Path perks are authored and priced in [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md). Only the technique unlock is live. `PathManager.get_effects()` aggregates the other effects into `PathEffectsSummary`, but nothing outside tests reads it.

| `PathNodeEffectData.EffectType` | Intended effect | Where it would plug in | Status |
|--------------------------------|-----------------|------------------------|--------|
| `UNLOCK_CYCLING_TECHNIQUE` | Unlock technique `string_value` | `PathManager.purchase_node()` → `CyclingManager.unlock_technique()` | Live |
| `MADRA_GENERATION_MULT` | Multiply Madra per cycle | `CyclingTechnique._madra_per_step()` | Not applied |
| `CYCLING_ACCURACY_BONUS` | Add px to the zone radius | `CyclingRules.ZONE_RADIUS`, which `tier_for_distance()` and `CyclingTechnique._update_zones()` read. The zones have no shape of their own | Not applied |
| `CORE_DENSITY_XP_MULT` | Multiply Core Density XP | `CyclingTechnique.try_score_zone()` (the `xp_for_tier()` result) or `CultivationManager.add_core_density_xp()` | Not applied |
| `MADRA_CAPACITY_BONUS`, `MADRA_ON_LEVEL_UP` | Madra cap and level-up Madra | See [CULTIVATION.md](../cultivation/CULTIVATION.md) | Not applied |

### Visual Feedback
| Element | Implementation |
|---------|----------------|
| Board and figure | `lacquer_cyc_board_ai.png` with the carved figure (`lacquer_cyc_body_carved_ai.png`, 524x872: traced again from the user's standing outline at 262x436 art px, 1.048x the 500x832 figure it replaced, and the same ratio). The technique scales its path and zones by the same 1.048, so every curve and zone lands where it did on the figure |
| Path | `CyclingGroove`: an ink channel with a lip, lit in the Madra ramp. It shows lit between cycles, is swept dark ahead of a starting ball and lights again behind it. No glow, no `Line2D` |
| Madra ball | `BallSprite`, an 8-frame swirl in 68x68 frames at 10 a second, whether or not a cycle runs, at the true position snapped to even px. The strip has three rows, the ball at 60, 64 and 68 px: the waiting ball breathes through them (60 → 64 → 68 → 64 → 60 every 2 s), and the ball stays 60 px while it cycles |
| Ball ring | `BallRing`, 88x88 frames. While ready, the brass ring: frame 0, or frame 2 or 3 (grown 4 and 8 px across) as the ball breathes. While the cursor is on the ball, the solid tan ring (frame 1). Hidden otherwise |
| Zones | `Socket`, a 48x48 frame per `CyclingZone.State`. The idle rim is a solid tan loop. The stud is the hit's feedback, so there is no flash |
| Last cycle | Not on the board: the zone chest's line under the Now tray |
| Pellets | `MadraPellet` (the adventure drain's scene). Madra blue from the ball, `lacquer_cyc_pellet_{brass,cream,tan}_ai.png` from a zone. Opaque, on even px, no trail |
| Floaters | `LacquerFloater`: the hit's tier and XP on a lacquer token |
| Tier colours | PERFECT brass, GOOD cream, OK tan, for floaters, pellets and studs (the user's call; green is gone) |
| Cabinet | The Madra orb fills as each step is drawn, with the pellets pouring into it, and the rate shows (`+13.3 / s`) while the ball draws Madra. The Core orb, level and XP beads move when a zone scores |
| Now tray | The bead ring, the rod, the figure and the rate follow the session snapshot every frame |

## Signals

| Signal | Source | Listeners |
|--------|--------|-----------|
| `cycling_started` | `CyclingTechnique` | None |
| `cycle_completed(result: CycleResult)` | `CyclingTechnique` | `CyclingView._on_cycle_completed` |
| `madra_particle_requested(from_pos)` | `CyclingTechnique` | `CyclingView._on_madra_particle_requested` |
| `zone_scored(zone, tier, xp)` | `CyclingTechnique` | `CyclingView._on_zone_scored` |
| `last_cycle_changed(result: CycleResult)` | `CyclingManager` | `ZonePanel` (the line under the Now tray). `result` is `null` when the result is cleared |
| `technique_unlocked(technique)` | `CyclingManager` | `TechniqueList` (rebuild), `ZoneManager` (cycling actions unseen), `ZonePanel` (queued rebuild) |
| `equipped_technique_changed(technique)` | `CyclingManager` | `CyclingView` (set the technique up), `TechniqueList` (refresh the drawers), `NowStrip`, `CyclingPresenter` |
| `madra_rate_changed(rate)` | `CyclingManager` | `CultivatorPlate` (the rate label) |
| `start_cycling(action_data)` / `stop_cycling()` | `ActionManager` | `CyclingViewState` (push/pop); `CyclingView` (stop only) |

## Integration Points

| System | Connection |
|--------|------------|
| `ActionManager` | Selecting a `CYCLING` zone action stops the current action and emits `start_cycling`. `stop_action()` emits `stop_cycling`, increments zone progression for the action, runs its `success_effects` (none authored), and resumes the zone's idle action ("Resumed <name>"). While cycling, `get_current_madra_per_second()` returns the cycle's measured rate |
| `MainView` / `CyclingViewState` | Push/pop state. `enter()` calls `MainView.set_cycling_mode(true)`, shows the board and blocks the full log; `exit()` undoes all three. `handle_input()` maps `close_cycling_view` (Esc) to `ActionManager.stop_action()`. See [MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md) |
| `ResourceManager` | `add_madra(amount, true)` per step (quiet); `madra_changed`; `get_madra()` for the cap check |
| `CultivationManager` | `add_core_density_xp()` per scored zone; `get_max_madra()` for the cap check |
| `CultivatorPlate` | The pellets' targets (`get_madra_orb_global_position()`, `get_core_orb_global_position()`). It shows the Madra rate on `madra_rate_changed` and the Madra, level and XP as they change |
| `ZonePanel` / `NowStrip` | The chest lists the techniques (`set_techniques_mode()`), the tray shows the cycle, and a line under the tray shows the last one (`CyclingManager.last_cycle_changed`). See [ZONES.md](../zones/ZONES.md) |
| `ZoneManager` | A technique unlock marks every CYCLING action unseen, so its card shows NEW |
| `LogManager` | One `[color=cyan]` line per finished cycle |
| `PathManager` | `purchase_node()` → `CyclingManager.unlock_technique()` |
| `PersistenceManager` | Technique IDs, seen IDs, Madra and Core Density persist in `SaveGameData`. Auto, the running cycle and the last cycle's result do not |
| `UnlockManager` / `QuestManager` | Every `madra_changed` (about 12/s while tracking) re-evaluates unlock conditions. `q_fill_core` step 1 completes at Madra ≥ 100 (`q_fill_core_madra_full`) |
| `DevPanel` (Ctrl+Shift+D) | "Unlock All Cycling Techniques" iterates `CyclingManager._technique_catalog`. The panel also has "Madra" and "Add CD XP" fields |
| Zones | Spirit Valley's Wilderness Cycling card uses `CyclingPresenter` ("<equipped technique> · Madra and Core Density XP", following `equipped_technique_changed`). The Aura Well training action is a second, passive Madra source (+1.5 per tick); see [ZONES.md](../zones/ZONES.md) |

## Existing Content

### Techniques (`resources/cycling/cycling_techniques/`)
| `id` | Name | Duration | Madra/cycle | Madra/s at 100% tracking | Madra per step | Zones | Max XP/cycle | Curve | How unlocked |
|------|------|----------|-------------|--------------------------|----------------|-------|--------------|-------|--------------|
| `foundation_technique` | Foundational Technique | 8 s | 50 | 6.25 | 0.5 | 0 | 0 | `foundation_path.tres` (5 points, vertical loop) | Default in `SaveGameData` |
| `smooth_flow` | Smooth Flow Technique | 15 s | 200 | 13.3 | 1.07 | 4 | 125 | `smooth_path.tres` (13 points) | Path node `pure_core_awakening` (keystone, 1 point, no prerequisite) |
| `torrential_flow` | Torrential Flow | 8 s | 250 | 31.25 | 2.5 | 1 | 30 | `torrential_curve.tres` (12 points) | Path node `torrential_flow` (major, 1 point, requires `pure_core_awakening`) |

Catalog order in `cycling_technique_list.tres` is Foundational, Smooth Flow, Torrential Flow. Each technique's `icon` is a 32x32 placeholder, `lacquer_ic_tech_{foundation,smooth,torrent}_ai.png` in `assets/ui/lacquer/icons/`, each drawing its path's shape in the Madra ramp.

### Cycling Zones
| Technique | Resource | Position | PERFECT | GOOD | OK |
|-----------|----------|----------|---------|------|----|
| Smooth Flow | `smooth_flow/cycling_zone_data/zone_1.tres` | (464, 416) | 25 | 15 | 5 (default) |
| Smooth Flow | `zone_2.tres` | (110, 430) | 25 | 15 | 5 (default) |
| Smooth Flow | `zone_3.tres` | (320, 180) | 50 | 25 | 10 |
| Smooth Flow | `zone_4.tres` | (530, 430) | 25 | 15 | 5 (default) |
| Torrential Flow | inline sub-resource in `torrential_flow.tres` | (322, 256) | 30 | 25 | 20 |

Every zone sits on its technique's curve, and the ball passes Smooth Flow's zones in order 1 → 4. The positions are as authored: the board draws them 1.048x about (70, 24) (`path_scale`, `path_pivot`) and snaps them to even px. All zones leave `timing_window_ratio` at 0.05, which is unused. Smooth Flow per-cycle XP is 125 when every zone scores PERFECT, 70 when every zone scores GOOD and 25 when every zone scores OK.

### Cycling Actions
| Action | `action_id` | Zone | Unlock condition | Modifiers |
|--------|-------------|------|------------------|-----------|
| Wilderness Cycling | `wilderness_cycling_action` | Spirit Valley | `celestial_intervener_dialogue_1` (`EVENT_TRIGGERED`) | All defaults, unused |

### Art
All new pieces are agent-made (`_ai`), drawn on the zone kit's 2x grid by `docs/superpowers/mockups/cycling-view-lacquer/gen/kit_cycling.py` and copied in by `import_cycling.py`, which bakes the board's 4 px shadow and the Auto toggle's 2 px one.

The mock keeps its approved first-round art. Four of the game's pieces differ from it, so `kit_cycling.py`'s `game_kit()` writes the game's versions of the ball strip, the ball rings, the zone strip and the carved figure to the mock folder's `game/` subfolder, and `import_cycling.py` copies those from there. The review of 2026-10-23 redrew them: the tracking ring and a zone's idle rim were checkerboard dots that read as broken, and are now solid tan loops; the ball strip gained the breathing sizes and the rings the grown ready rings; and the figure was traced again at 524x872.

| Asset | Used by |
|-------|---------|
| `assets/ui/lacquer/cycling/lacquer_cyc_board_ai.png` (564x1036) | `CyclingView` `Board` |
| `lacquer_cyc_body_carved_ai.png` (524x872) | `Body`, the carved figure |
| `lacquer_cyc_ball_strip_ai.png` (544x204: 8 swirl frames across and 3 breath sizes down, in 68 px cells), `lacquer_cyc_ball_rings_ai.png` (352x88: four 88 px frames, the ready ring, the solid tan tracking ring, and the ready ring grown by 4 and by 8 px) | `BallSprite` (68x68 frames), `BallRing` (88x88 frames) |
| `lacquer_cyc_zone_strip_ai.png` (288x48: 6 frames of 48x48, the idle rim solid) | `CyclingZone` `Socket` |
| `lacquer_cyc_pellet_{brass,cream,tan}_ai.png` (12x12) | The XP pellets, through `MadraPellet.set_texture()` |
| `lacquer_cyc_auto_ai.png`, `lacquer_cyc_auto_on_ai.png` (120x36, or 122x38 with the shadow) | `AutoToggle` |
| `assets/ui/lacquer/icons/lacquer_ic_tech_{foundation,smooth,torrent}_ai.png` (32x32) | `CyclingTechniqueData.icon`, the drawers |
| From the zone kit | `close`, `close_hover`, `drawer`, `drawer_run`, `tag`, `seal_new_s`, `frame_hover`, `frame_brass`, `token`, the jade `ring_strip` and rod pieces, `ic_cycle` (the action's icon) and `lacquer_madra_pellet_ai.png` |
| `assets/sprites/cycling/Madra-Ball.png`, `cycling_technique_outline.png` | The user's files, kept but no longer referenced. The figure was traced from the outline |
| `Cycling_Technique_Background.webp`, `background.png`, `backgrounds/cycling_background_with_border.png`, `border.png`, `fill.png` | Not referenced by any scene or script |
| `madra_circle.png`, `liquid_wave.gdshader` | The combat orbs. The cycling view no longer uses them |

## Key Files

| File | Purpose |
|------|---------|
| `scenes/cycling/cycling_view/cycling_view.gd` / `.tscn` | The board: the status line, pellets, floaters, Auto, close. It hands each finished cycle's result to `CyclingManager` |
| `scenes/cycling/cycling_technique/cycling_technique.gd` / `.tscn` | Cycle play: the ball and its press, the breath, Madra steps, the rate, zones, scoring, the path scale, the session snapshot |
| `scenes/cycling/cycling_technique/cycling_zone.gd` / `.tscn` | One scoring zone: its `State` and its socket. A `Node2D` that takes no input |
| `scenes/cycling/cycling_technique/cycling_rules.gd`, `cycle_result.gd` | `CyclingRules` (tiers, XP, pellets, colours) and `CycleResult` (totals and lines) |
| `scenes/cycling/cycling_groove/cycling_groove.gd` | `CyclingGroove`: the carved, lit channel, with its trail and sweep |
| `scenes/cycling/technique_drawer/technique_drawer.gd` / `.tscn` | `TechniqueDrawer`: one technique in the chest |
| `scenes/zones/zone_panel/technique_list/technique_list.gd` / `.tscn` | `TechniqueList`: the chest's list while cycling |
| `scenes/zones/zone_panel/zone_panel.gd` / `.tscn` | The chest, including `%LastCycleLabel`: the last cycle's line under the Now tray |
| `scenes/zones/zone_transition/madra_pellet.gd` / `.tscn` | `MadraPellet`, also the cycling pellets |
| `scenes/common/lacquer/lacquer_floater/` | `LacquerFloater`, the zone hits' floaters |
| `scenes/ui/main_view/states/cycling_view_state.gd`, `scenes/ui/main_view/main_view.gd` | Modal state: show/hide, Esc handling; `set_cycling_mode()` |
| `singletons/cycling_manager/cycling_manager.gd` | Unlocked, equipped and seen technique state, the catalog, the session snapshot and the last cycle's result |
| `scripts/resource_definitions/cycling/cycling_technique/*.gd` | `CyclingTechniqueData`, `CyclingZoneData`, `CyclingTechniqueList` |
| `scripts/resource_definitions/zones/zone_action_data/cycling_action_data/cycling_action_data.gd` | `CyclingActionData` (unused modifiers) |
| `resources/cycling/cycling_techniques/` | Technique, curve and zone content |
| `assets/ui/lacquer/cycling/`, `assets/ui/lacquer/icons/lacquer_ic_tech_*_ai.png` | The art above |
| `tests/unit/test_cycling_manager.gd` | 39 `CyclingManager` tests (defaults, unlock, equip, errors, `has_unequipped_unlocks`, seen techniques, the session snapshot, `madra_rate_changed`, and the last cycle's result with its reset) |
| `tests/unit/test_cycling_rules.gd`, `test_cycling_groove.gd`, `test_cycling_technique_data.gd`, `test_cycling_art.gd`, `test_cycling_rate.gd`, `test_cycling_mode.gd` | 7, 15, 4, 17, 3 and 12 tests: the pure rules and result lines, the groove raster with its trail and sweep, the icons and seen fields, the art's sizes, palettes, breathing sizes and unbroken rings, the cycling rate on `ActionManager`, and cycling mode on `MainView` |
| `tests/integration/test_cycling_technique.gd`, `test_cycling_view.gd`, `test_technique_drawer.gd` | 85, 71 and 25 tests: the play (Madra steps at 30, 60 and 144 FPS, every step of a tracked 8 s cycle at any frame rate, a hitch through the end, the Madra a cycle counts, the rate, the breath, zones, scoring by pressing the ball, the cursor's reach out to the ring's edge, the groove's sweep, the path scale, session ownership, real physics picking), the board (its text wrapping and the board growing, still on screen), and the drawer (long text wrapping, the drawer growing) |

## Work Remaining

### Bugs

None known.

### Missing Functionality

- `[HIGH]` Path perks that target cycling do nothing. `MADRA_GENERATION_MULT`, `CYCLING_ACCURACY_BONUS` and `CORE_DENSITY_XP_MULT` are sold in the Pure Madra tree but never applied (see Path Tree Hook Points).
- `[HIGH]` `CyclingActionData` modifiers (`madra_multiplier`, `cycle_duration_modifier`, `xp_multiplier`, `madra_cost_per_cycle`) are never applied. The action data is also dropped: `CyclingViewState._on_start_cycling()` ignores it, and the view reads only the action's name. Every cycling action behaves identically.
- `[MEDIUM]` Zone size is a static 20 px for every zone of every technique (`CyclingRules.ZONE_RADIUS`), so zone difficulty cannot vary. The user asked that it become a variable of each technique later (review of 2026-10-23); for now it stays static. `CyclingZoneData.timing_window_ratio` is never read. The 20 px sets the reach at which a zone turns ACTIVE (49.5 px between centres, with the ball's 29.5), the 6 and 14 px PERFECT and GOOD distances, and the 48 px socket art, so a size that varies has to reach all three.
- `[MEDIUM]` No combo or streak reward for consecutive PERFECT/GOOD presses.
- `[LOW]` No penalty for mis-timed presses. A press while no zone is active is ignored, and the first press while one is active scores it at OK or better, so pressing the ball as it passes a zone guarantees at least OK.
- `[LOW]` Auto Cycle is free from the start and only chains cycles. The GDD frames auto-cycling as a Copper Scripting reward, and there is no idle or offline cycling.
- `[LOW]` The technique list neither scrolls nor folds. The chest fits 10 drawers (9 while the last cycle's line shows, 6 while the lore is open) and the catalog has 3. A longer catalog needs the activity list's fold and scroll.

### Content

- `[HIGH]` No audio. There are no `AudioStreamPlayer` nodes under `scenes/cycling/`: nothing for ball movement, zone presses, PERFECT hits or cycle completion.
- `[MEDIUM]` Techniques differ only in curve, zones, numbers and icon. All share one carved figure and board, and `CyclingTechniqueData` has no field for a figure or background. A seated pose or a figure per technique would redraw every path.
- `[MEDIUM]` Only 3 techniques and 5 zones exist, all Foundation-tier. Torrential Flow has a single zone.
- `[LOW]` Placeholder art: the three technique icons are `_ai` placeholders until the user draws their own, and the groove is Madra blue, the same colour as the ball.

### UI

- `[LOW]` The quest toast covers the board's header for about 3 s when a quest step completes mid-cycle ("Fill your Madra by cycling" at 100 Madra, and Core Density 10). It sits at the top centre (y 28–88, z 10). The toast is due a rework (style guide row Z2), which should place it clear of the board.
- `[LOW]` The board does not explain that the starting Foundational Technique has no zones and earns no Core Density XP. Its drawer only says "no zones".
- `[LOW]` Locked techniques are hidden by design, so players cannot see what is still unlockable.

### Tech Debt

- `[MEDIUM]` Test gap: content integrity. Nothing checks that technique IDs are unique and non-empty, or that every path node's `UNLOCK_CYCLING_TECHNIQUE` value names a catalog technique. `test_path_manager.gd` checks `PathManager.get_unlocked_cycling_techniques()` but not that `CyclingManager` actually unlocked the technique.
- `[LOW]` Private access across classes. `DevPanel` reads `CyclingManager._technique_catalog`.
- `[LOW]` `CyclingManager.has_unequipped_unlocks()` has no caller.

## Related Docs

- [CULTIVATION.md](../cultivation/CULTIVATION.md): Core Density, Madra cap, stages, breakthrough
- [breakthrough-tribulation.md](../cultivation/breakthrough-tribulation.md): Tribulation design (reuses cycling components; not implemented)
- [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md): path nodes that unlock techniques and the cycling perks
- [FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md): intended cycling pacing (Beat 1 Madra fill, Keystone #1)
- [RESOURCES.md](../infrastructure/RESOURCES.md): Madra pool and adventure budget
- [ZONES.md](../zones/ZONES.md): the cabinet, the chest's techniques mode and the Now tray
- [MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md): cycling mode on the main view
- [STYLE_GUIDE.md](../STYLE_GUIDE.md): the look the board follows
- Design record: [cycling view in lacquer and brass spec](../superpowers/specs/2026-10-22-cycling-view-lacquer-design.md), its [plan](../superpowers/plans/2026-10-22-cycling-view-lacquer.md) and [mock-up](../superpowers/mockups/cycling-view-lacquer-mockup.html)
- Historical: [CYCLING_UI_REDESIGN.md](CYCLING_UI_REDESIGN.md), [CYCLING_UI_IMPLEMENTATION_PLAN.md](CYCLING_UI_IMPLEMENTATION_PLAN.md) (the tabbed view this replaced), [technique unlock spec](../superpowers/specs/2026-04-12-cycling-technique-unlock-design.md)
