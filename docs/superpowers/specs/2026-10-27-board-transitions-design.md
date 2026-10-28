# Board transitions: design

The zone view's map gap (between the cultivator cabinet and the zone chest) holds boards: the cycling board today, the Tribulation board, and later simpler boards for idle activities such as the Aura Well and foraging. This design gives them one shared, reversible open and close transition, built first for cycling and the Tribulation, and asks how far the same system stretches to the other view switches (zone ↔ adventure).

## Why

Today a board snaps. `CyclingViewState.enter()` shows the board and `MainView.set_board_mode(true)` hides the dock in the same frame, and the zone chest swaps its activity list for the technique list in that frame too. Sitting down to cycle is the moment the cultivator turns inward, and it should look like it. The user wants it to look good for both the board and the side panel (the zone chest).

The user also wants the transition to be a system rather than a one-off, so that every board that stands in the map gap gets it, including the simpler idle-activity boards still to come, and wants to know how extendable it is to the other switches between views.

## Goals

- One transition plays whenever a board opens or closes in the map gap. Cycling and the Tribulation use it in this round.
- It has the look the user picked from the mockups (below).
- It is reversible at any point: whatever interrupts it plays it back from where it is, and nothing is left half-shown.
- A new board gets the transition by declaring a few things about itself, without new animation code.
- This round ends with a written assessment of how the zone ↔ adventure switch and the future idle-activity boards would plug in.

## Non-goals

- Changing the zone ↔ adventure switch. It keeps its Madra drain and camera zoom (`ZoneTransition`) in this round; it is only assessed.
- Building the Aura Well or foraging boards.
- The menu books, the merchant shop and the end card. They keep their own open and close.
- Sound.

## Anti-goals (it fails even if it technically works)

- A click or key lands on something mid-transition that the player cannot properly see: the cycling ball while the board is still small, an activity card that is sliding away, the inventory opening over a board that is still closing.
- A transition gets stuck: a board left visible after its state is gone, the dock or the HUD boards left off-screen, the chest left between modes.
- The camera does not come back to the zoom and position the player left it at.
- An existing route to open or close a board stops working: Esc, the board's × button, picking another activity, a stop from outside (a save reset, the dev panel), the Tribulation's Continue and Not yet.

## The look (decided by the user)

The user compared four board styles and three side-panel styles in an animated mockup made from game screenshots, and picked:

- **Board: "Scale up from the cultivator".** The camera eases in on the cultivator, and the board grows out of them to its place in the map gap, smoothly (not in held frames). It shrinks back into them on close.
- **Side panel: "Drawers slide out and in".** The chest's header stays put. The activity rows step out to the right one after another, the chest shortens, and the technique rows step in from the right.

### Opening timeline

Times are from the start of the open. Every "step" moves in 2 px steps at constant speed (style guide §8, Stepped moves).

| When | What |
|---|---|
| 0–480 ms | The zone map's camera eases (ease in-out, cubic) from the player's current zoom to 1.5× that zoom, and moves so the cultivator ends at the board's horizontal centre, 70 px below the board's vertical centre (screen (962, 612) for the cycling board). |
| 0–140 ms | The dock steps straight down off the bottom edge of the screen. |
| 200–520 ms | The board scales from 3% to full size about the point where the camera brings the cultivator (not tracking them frame by frame), ease-out cubic, every frame. Everything on the board scales with it. |
| 0–300 ms | Chest, cycling only: the activities header and then each activity row step out to the right, row *i* starting at *i* × 20 ms and taking 120 ms to cross the chest's width. For a long list the stagger shrinks, so the last row is still out by 300 ms. They are clipped, so they slide under the frame and are gone. |
| 300 ms | Chest, cycling only: the swap. The chest turns from the activity list to the technique list. |
| 300–540 ms | Chest, cycling only: the techniques header and then each technique row step in from the right, row *j* starting at 300 + *j* × 25 ms and taking 140 ms; the stagger shrinks for a long list, so the last row is in by 540 ms. Over the same time the chest's bottom edge steps from the activity list's height to the technique list's height. |

The open takes about 0.54 s with the chest swap and 0.52 s without it.

The chest rows were first drawn overlapping (out 0–365 ms, in 260–540 ms, the height 150–450 ms), as the mockup drew both lists at once. The chest shows one list at a time, so the rows go out, the chest swaps at 300 ms, and the rows come in, inside the same 540 ms.

### Closing

The close is the same timeline played backwards from the end: the technique rows step out, the chest grows back, the activity rows step in, the board shrinks into the cultivator, the camera eases back to exactly the zoom and position the player had, and the dock steps back up.

### Reversal

The transition is one progress value moving between closed and open. Whatever turns it around mid-way (Esc while it opens, a new start while it closes) sends the progress back the other way from where it is. Nothing jumps.

## How each board uses it

| | Cycling board | Tribulation board |
|---|---|---|
| The board's final rectangle | `CyclingView`'s board (x 680 to 1240) | `TribulationView`'s board (952 wide at (484, 24)) |
| Camera push | Yes | Yes |
| Dock | Steps down | Steps down |
| Chest | Drawers swap: activities out, techniques in (today's `ZonePanel.set_techniques_mode()`) | Keeps the activity list; no swap |
| Log and Goals board | Stay where they are | Today they hide at once (`hide_hud_boards`). *My call:* they step off the left edge of the screen in 2 px steps, the Goals board first, in the same rhythm as the chest rows, and step back on close |

A future board declares the same things: its board's rectangle, whether the chest swaps and to what, and whether the HUD boards step away.

## Behaviour rules

- **Input while it plays.** Until the open has finished, the board takes no clicks or keys except Esc. While the close plays, nothing in the zone view takes input: the map, the dock, the chest and the menu keys (I, A, C, P) wait until it has finished. The board's state stays on `MainView`'s stack until the close has finished, the way `BookViewState` waits for the book's close before it pops (see "Architecture").
- **Esc while opening** reverses it (it closes from where it is). For cycling, Esc while opening stops the cycling action as Esc does now. For the Tribulation, Esc does what it does on the intro (Not yet).
- **Every stop plays the close.** Esc, the × button, picking another activity, a zone change, a save reset, the dev panel, the Tribulation's Continue and Not yet: all of them close through the transition. A stop from outside mid-trial still applies nothing of the run.
- **A start while closing.** The player cannot start a board while one is closing: the only way to start cycling or the Tribulation is its card in the chest, and the chest takes no input during the close. A start from outside (the dev panel) reverses the close into an open. *My call:* that is a safety path, covered by tests but not tuned for looks.
- **Keys and clicks during the close are dropped**, not saved for when it ends. *My call.* This is what the zone view's input blocker does during the adventure transition today.
- **The camera** is restored to the zoom and position it had before the open, even if the open was reversed part-way. The wheel zoom and travel stay off the whole time a board is up or moving, as they are today.
- **The Now tray swaps outright, as it does today.** *My call, a change from the mockup* (where it slid with the rows). The tray shows the current action, and the action has already changed by the time the board opens (`ActionManager` stops the old action before it starts cycling), so there is no old content left to slide out. The tray already swaps outright on every action change in the game.
- **The header text** ("Activities · N here" ↔ "Techniques · N learned") changes while the header is out of sight, between its slide out and its slide in.
- **The cultivator cabinet** never moves.

## Style guide exception

The style guide (§8) keeps motion to whole steps on the 2× pixel grid, and its Camera row lists the only eased motions it allows. The board's smooth, eased scale breaks that grid while it plays: partway through, the art's 2×2 pixels are drawn at uneven sizes. The user saw this in slow motion and chose it over the crisp alternative (a frame that grows at full resolution and uncovers the board in place). Record it as a named exception next to the Camera row: "Board open and close: the board scales smoothly out of the cultivator (0.32 s, ease-out cubic) and back."

The camera push is the same kind of motion the guide already allows: the zoom into an adventure is a 1.5× push too (2 to 3).

## Architecture

*My calls, as recommendations. The builder may refine them but should keep the decided behaviour.*

- **A progress-driven player.** One node (for example `BoardTransition`, one instance under `MainView`) holds a progress value from 0 (closed) to 1 (open) and a direction, advances it each frame, and draws every piece from the progress: the camera, the dock, the board's scale, the chest's rows and height, the HUD boards. Reversal is a change of direction.
  - Rejected: a chain of `Tween`s. A Godot tween cannot be turned around from the middle, and the reversal rule needs that.
  - Rejected: an `AnimationPlayer`. It can play backwards, but the pieces here are dynamic (the cultivator's position, the boards' sizes, how many rows each list has), which an authored animation cannot hold.
- **Pure timing functions, tested.** What each piece looks like at a given progress (the board's scale, a row's offset, the chest's height, the camera's zoom and position) are static functions with no node access, like `ZoneMapMath`. GUT tests cover them, including the reverse direction and a mid-way reversal.
- **Boards declare, the player animates.** A board state hands the player a small description of the board: its board Control and rectangle, the chest mode it wants (none, or a swap with the moment to apply it), and whether the HUD boards step away. The open and close of each board state go through it.
- **States wait for the close.** `CyclingViewState` and `TribulationViewState` start the close on stop and leave the stack only when the player reports it has finished, as `BookViewState` waits for `panel_hidden`. If another state sits above the board's state when it must close (the merchant's case today), the builder decides whether to close at once or wait; it must not leave anything half-shown.
- **The chest's rows stay in their containers.** The activity cards and technique drawers are laid out by `VBoxContainer`s, so the slide offsets what each row draws, not its layout position, and the chest clips the rows at its inner edge.
- **The camera push is its own piece, ready to share.** It saves the camera, eases it to a zoom aimed at the cultivator, and restores exactly what it saved. *My call:* `ZoneTransition` and `ZoneViewState.reset_camera()` stay exactly as they are in this round (see Non-goals). The two moves differ today: the adventure zoom always goes to zoom 3 over 0.5 s (ease-in quad), aims at the character through its own formula, and restores with a separate 0.3 s tween. So the push takes its target (a factor of the current zoom, or a fixed zoom) and its curve as parameters, and the assessment says what moving the adventure zoom onto it would take.
- **Missing pieces are skipped.** The view-state tests build `MainView`s with plain Controls standing in for the views, and `set_board_mode()` already skips what is missing. The player does the same: with no camera, chest or dock, it animates what is there and finishes.
- The GodotPrompter `tween-animation`, `state-machine` and `godot-testing` skills apply when the plan is written.

## Extending it (the assessment this round delivers)

Once cycling and the Tribulation run on the player, write up how the rest would plug in, grounded in the built code. At least:

- **The idle-activity boards (Aura Well, foraging).** *Decided by the user:* they open on demand, like cycling. The board opens when the player clicks its card, and the idle action keeps running when the board is closed. So one board moves at a time, and the player needs no handoff from one board to the next, even though `ActionManager.stop_action()` resumes the idle action in the same call that stops cycling. What a new board in the map gap needs: a view with a board Control, a `MainViewState` that hands the player its description, and its choice for the chest. Today the chest knows only two modes (`set_techniques_mode()`); if those boards want their own rows in the chest, the chest needs a general "list mode" rather than a second boolean. Say what that change would be.
- **Zone ↔ adventure.** It differs in kind: it replaces the whole view (`change_state`) rather than standing a board in the gap, and it has the Madra drain before the zoom. Assess what carries over (the camera push, the progress-driven player and its reversal, the input rules) and what it would need of its own (an entry motion for the adventure view and a way back that undoes the push), how much of `ZoneTransition` it would replace, and what moving its fixed zoom-to-3 onto the camera push would change for the player.
- Anything the builder found harder than this design assumed.

The write-up goes into this spec as a closing section, so the decision record holds both the design and its result.

## Docs to update when it is built

- `docs/infrastructure/MAIN_VIEW.md`: the transition (what it does, the timeline's owner, how a board declares itself), the state table rows for `CyclingViewState` and `TribulationViewState`, and the ActionManager-driven flow.
- `docs/STYLE_GUIDE.md` §8: the exception above.
- `docs/cycling/CYCLING.md` and `docs/cultivation/breakthrough-tribulation.md`: one line each linking to the transition in `MAIN_VIEW.md`, if they describe how their board opens.

## Left to the builder

- The node and class names, and where the board descriptions live (a `Resource`, a small `RefCounted`, or method arguments).
- How the dock, the HUD boards and the chest rows are offset in Godot, within the rules above.
- How the camera move stays inside the map's camera bounds (`CameraClampController`) when the cultivator stands near an edge of the zone.
- The merchant-above-the-board case.

## Result: how far it extends

Written after cycling and the Tribulation moved onto the transition, from the code as built. The living description is [MAIN_VIEW.md § Board transitions](../../infrastructure/MAIN_VIEW.md#board-transitions).

What was built, in short: `BoardTransitionTiming` (`scripts/utils/board_transition_timing.gd`) holds the timeline as pure functions; `CameraPush` (`scenes/camera/camera_push/camera_push.gd`) is the reversible camera move; `BoardTransition` (`scenes/ui/main_view/board_transition/`) is the progress-driven player, one instance under `MainView`; a board describes itself in a `BoardTransitionSpec`; `MainView.open_board()` and `close_board()` play it, or open and close at once when there is no player. The two left-to-the-builder items not settled above came out as follows. The camera push sets the camera directly and is not clamped to the zone's camera window; nobody has looked at a push near a zone's edge. A view pushed above a closing board stays open, because the board's state removes only itself when its close ends; that case is reachable only from the dev panel, since the chest takes no click while a board is up.

### The on-demand idle boards (Aura Well, foraging)

A new board in the map gap needs three things, and no animation code:

| Piece | What it needs | Model |
|---|---|---|
| A view | A `Control` holding the board, hidden by default, after the boards and before `BoardTransition` in `MainView`'s children (the shield must come later in the tree to take the clicks), and a `get_board_rect()` that is right before the board has ever been shown. A board that grows with its content has not laid out then, so it reports a rest size, as `TribulationView.BOARD_REST_HEIGHT` does | `CyclingView.get_board_rect()`, `TribulationView.get_board_rect()` |
| A state | A `MainViewState` that builds one `BoardTransitionSpec` on its first open and keeps it; reads the view and its rect only when the board opens from closed; calls `open_board()` in `enter()` and `close_board(spec, remove_state(self))` on its stop; turns a close around with `open_board()` when a start comes while it is still on the stack; ignores a stop while it is not on the stack; and drops every key while `is_board_closing()` | `CyclingViewState`, `TribulationViewState` |
| Its spec | `swaps_chest` and `moves_hud_boards`. A board that keeps the activity list and leaves the HUD boards up sets neither, and its open is the camera push, the dock and the board's growth, 520 ms | The Tribulation's spec, without the HUD boards |

The two states are near copies already. A third board is the point to pull their shared shape into a base class (one spec, push or turn around, close then remove, the input guard), with each board naming its view, its spec flags and its stop signal.

The idle boards differ from cycling in what drives them. Cycling's state follows `ActionManager.start_cycling` and `stop_cycling`. An idle board opens when the player clicks its card and closes on Esc or its ×, while the idle action keeps running, so its open and close are not action signals. It needs a request from the card (today a click on the running idle card only flashes the Now tray) and a close that stops nothing. It still has to close when the idle action stops (another action replaces it, the zone changes, a save reset), so its state also follows the idle action's stop.

**One board at a time holds only if the chest takes no clicks while an idle board is up.** If an idle board keeps the activity list and leaves it clickable, a click on the cycling card while the Aura Well board is up runs: `select_action()` stops the Aura Well (its state starts its close), then `start_cycling` opens the cycling board, and `BoardTransition.open()` finds another board up and snaps it closed (every piece put back at once, the camera too) before cycling opens from closed. That reads as a jump. Two ways out: the idle board's view takes every click outside the board, as the Tribulation's root does, so the player closes it before picking another activity; or the player learns a handoff, letting the first close finish (or reach the camera-free part of its timeline) before the second open begins. The first is a property of the view and needs no player change.

**Rows of its own in the chest.** If an idle board wants the chest to show something of its own (the Aura Well's levels, foraging's yields), the chest's boolean techniques mode has to become a list mode:

- `ZonePanel`: the `bool` techniques mode becomes a mode value (`ACTIVITIES`, `TECHNIQUES`, one per board list), `set_techniques_mode(on)` becomes `set_list_mode(mode)` and `is_techniques_mode()` becomes `get_list_mode()`. `chest_height_for(techniques)` becomes `chest_height_for(mode)`, and `get_slide_rows()` asks the list of the current mode. Each list keeps the shape `TechniqueList` has: `build()`, `get_content_height()`, `get_slide_rows()`, and a header text and count. The header's text and count, and the last cycle's line ("techniques mode only"), are keyed by the mode. The new list sits in `SlideClip`, which cuts it at the chest's inner edge.
- `BoardTransitionSpec.swaps_chest` becomes `chest_mode`, the mode to swap to (`ACTIVITIES` for no swap). The player's chest step wants `ACTIVITIES` before `CHEST_SWAP_MS` and the spec's mode from it, where it now wants techniques or not, and reads the heights of those two modes. `duration_ms()` takes whether the spec swaps.
- `MainView`'s instant path calls `set_list_mode(spec.chest_mode)` and back.
- The timeline needs nothing: the staggers already shrink to fit any row count. A list longer than the chest needs the activity list's scroll and fold, which the technique list does not have, and `SlideClip` is a fixed 1032 px tall.

### Zone ↔ adventure

Today `ZoneTransition` (`scenes/zones/zone_transition/zone_transition.gd`) plays the entry: on `adventure_start_requested`, `ZoneViewState` adds a code-built full-rect `Control` that stops the mouse and ignores keys, `MapMarkers` hides, and `ZoneTransition` pours 8 to 25 Madra pellets from the cabinet to the character, 40 ms apart, spending the Madra pellet by pellet; about 0.7 s after the last one it saves the camera and tweens it to zoom 3 over 0.5 s (ease-in quad), aimed at the character through its own formula (the character's position plus half the tile map's offset); then `confirm_adventure_start()` leads to `change_state(adventure)`, and the adventure view appears outright, its own map opening at zoom 1. The way back is `ZoneViewState.enter()` after the end card, which calls `ZoneTransition.reset_camera()`: a separate 0.3 s tween (ease-out quad) to the saved zoom and position. `MapMarkers` shows again once the camera's zoom equals the zoom controller's resting zoom.

**What carries over.**

- **`CameraPush`** covers the camera half outright. `begin(camera, character, screen_point, 3.0)` with the fixed `end_zoom` of 3 saves the camera at the push's start, `apply(weight)` takes any curve (the caller owns it), and `restore()` puts back exactly what was saved. The way back becomes the same push driven from 1 to 0 over 0.3 s, then `restore()`. The aim becomes an explicit screen point instead of the tile-map offset formula. `push_camera_position()`, which `CameraPush.begin()` uses, lives in `BoardTransitionTiming`; a second user is the point to move it to `ZoneMapMath` or to `CameraPush` itself.
- **The input rules** carry over as they are: the shield that takes every click while something moves, and a state that drops every key meanwhile. `BoardTransition`'s shield is a scene node, so using it (or one like it) would retire the input blocker `ZoneViewState` builds in code, a tech-debt item in MAIN_VIEW.md.
- **The progress model and its reversal** give little on the way in. The drain spends Madra as each pellet leaves, so once it starts the entry is committed and there is nothing to turn around to; the adventure has no cancel by design. Where the model would help is the way back: one timeline played from the end, the camera pulling out while the dock steps up and the chest's rows step in, instead of today's outright zone view with a camera tween on top and the markers waiting for the camera.

**What the adventure needs of its own.**

- **A `change_state` switch, not a board in the gap.** `BoardTransition` assumes the zone view stays up for the whole run and ends its run by restoring everything at the close. The adventure's push ends in a cut to another base view, the zone view hides with the camera still pushed, and the restore has to wait the whole run, until `ZoneViewState.enter()`. So it needs an open whose end calls `confirm_adventure_start()`, an open phase that holds while the zone view is hidden, and a close that `ZoneViewState.enter()` starts. `MainView.change_state()` also clears the stack without `exit()`, so nothing may be mid-close at the cut.
- **The drain before the push**, as a first segment that only plays forward and whose length depends on the budget (8 to 25 pellets). `BoardTransitionTiming`'s segments are fixed, so the timeline would take the drain's length as a parameter, or the drain stays where it is and the push starts when it ends.
- **An entry motion for the adventure view.** Its vitals cabinet, chest and technique dock stand where the zone view's cabinet, chest and dock stand, so the board transition's own moves fit: the technique dock stepping up from the bottom (the dock's step, reversed) and the adventure chest's rows stepping in, given an `AdventureChest` row list like `ZonePanel.get_slide_rows()`. That is a second player, bound to the adventure view's pieces, running after the cut. It also has to settle the zoom at the cut: the zone push ends at 3, and the adventure map opens at its own zoom 1.

**How much of `ZoneTransition` it replaces.** The camera half: the saved zoom and position, the zoom tween at the drain's end, and `reset_camera()`'s tween. The drain (the budget split into whole-Madra pellets, the spending, the timers) and the call to `confirm_adventure_start()` stay, and they are most of the file. `MapMarkers`' check for the camera at rest still holds after `restore()`.

**What moving the zoom onto `CameraPush` changes for the player.** `CameraPush` has no curve of its own, so the adventure can keep its ease-in quad and the player sees the same dive. Moved onto the board's curve (`camera_weight()`, ease in and out, cubic, 480 ms), the push would slow down and settle on the character before the cut instead of plunging into it at full speed: calmer, but the entry would lose its sense of diving into the map. Other changes the player would see: the character lands on a named screen point (where the adventure first shows them, if that is chosen) instead of where the offset formula puts them; the zoom stays a fixed 3, so a player zoomed out to 1 still gets a 3× push, against the board's 1.5× of whatever zoom they had; and the way back ends on exactly the saved camera, as the tween already does, so that part looks the same.

A first step that changes nothing for the player: move only the camera half of `ZoneTransition` onto `CameraPush`, keeping its ease-in quad, its 0.5 s and its 0.3 s way back. A full progress-driven adventure switch is worth it once the adventure view has an entry motion to play.

### Harder than this design assumed

Each of these came up during the build:

- **The chest shows one list at a time.** The mockup drew the activity rows and the technique rows on screen together, overlapping in time; `ZonePanel` shows one list or the other. So the rows run out, the chest swaps at 300 ms, and the rows run in (`BoardTransitionTiming.CHEST_SWAP_MS`, `out_stagger()`, `in_stagger()`; the player's chest step). The staggers shrink for a long list so each phase keeps its window.
- **The containers undid the slide.** The rows are laid out by their `VBoxContainer`s (the activity list's groups and cards, `TechniqueList`'s drawer column), which lay them out again at the end of any frame where something asks, putting every row back at rest. The swap asks every time (it builds the drawers and shows the other list). `BoardTransition` connects to each container's `sort_children`, reads the rows' rest x again there and slides them back before the frame is drawn.
- **A scaled `Control`'s global position moves.** The plan worked the pivot out each frame from the view's live global position, which is its transform's origin and moves by pivot × (1 − scale) once the view is scaled: from the second frame the pivot would have come out near (29, 18) instead of (962, 612). `BoardTransition.open()` records the view's full-size top-left when it opens from closed and works the pivot out from that. For the same reason the states read their board's rect only on an open from closed, never on a reversal: a board mid-scale reports a scaled rect.
- **The Tribulation board has not laid out before its first open.** It is hidden until the transition shows it, so on the first open of a session its wrapping labels were 1 px wide and its rect read 952 × 2318: the camera aimed the cultivator below the screen and the board grew out of the bottom edge. `TribulationView.get_board_rect()` now reports `BOARD_REST_HEIGHT` (768) for the height.
- **The last cycle's line clears when the cycling board shows.** `CyclingView` clears the kept result as it shows, 200 ms into the open, after the chest's heights were read at the start, so the techniques height was 26 px stale. The player reads both heights again at each swap (`ZonePanel.chest_height_for()`), and `chest_height_for(true)` builds the hidden technique list first, so a loaded save does not read an empty one.
- **The clip.** Clipping the technique list at its own root cut the drawers' baked shadow and the in-use frame at rest, so the header and the drawers share one `SlideClip` that ends at the chest's inner edge (`zone_panel.tscn`).
- **Picking follows tree order.** Godot gives a click to the Control latest in the tree under the mouse, whatever its `z_index`, so `BoardTransition` sits after the boards and before `DevPanel` in `main_game.tscn`.
- **`close_board()` closes whichever board is up.** With a player it ignores its spec, so each state ignores its stop signal while it is not on the stack: a stray `stop_cycling` must not close the Tribulation board.

Two edges found in review were left for the review of the whole branch:

- A `MainView.change_state()` while a board closes clears the stack without calling `exit()`, so the board's state never lifts the full-log block and L stays dead. Only the dev panel can reach it. It is a case of the older tech-debt item on `change_state()` in MAIN_VIEW.md.
- Review also raised that the cycling technique now stops when the close ends rather than at the stop, so a cycle finishing inside the half-second close would still pay out. Checked while writing this, it does not happen: `CyclingView` connects to `ActionManager.stop_cycling` itself and stops the technique there, before the close plays (a cycling view test pins it). The board shrinks with the ball back at its start, and its hide at the close's end stops the technique again, which does nothing.

Taste points from the in-game check, left as they are:

- The activity rows are cut at the activity list's scroll window (about screen x 1868), while the header and the drawers are cut at the chest's inner edge (x 1892), so for about a tenth of a second the two edges differ.
- The chest stands empty at its full height for about 180 ms of the open (and about 210 ms of the close) with a short list: the top rows have left well before 300 ms, and the techniques arrive only then.
- A board rect read before its board lays out is off by the lines that wrap: a cycling action name that wraps to three lines grows the board 24 px after its rect was read, leaving the scale's pivot and the camera's aim 12 px off; a Tribulation zone name that wraps does the same against `BOARD_REST_HEIGHT`. Neither shows.
