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
