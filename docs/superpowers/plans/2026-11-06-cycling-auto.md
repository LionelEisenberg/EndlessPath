# Unlock cycling Auto after a perfect cycle (#101)

Stats rework chunk #101, tracked in #85. Design: the spec's Phase 3 and Anti-goals, the master plan's Tasks 3.7 to 3.9, and the answers below. Built against `main` at 5a649279 (#128, #130 to #132 merged).

## Approved mock-up answers

Canvas: [Auto cycling](https://claude.ai/artifact/LuUQ78a7ysxSetP3Hv44nR), round 2, approved 2026-11-06. Recorded on #101; the closed-board answer also on #107.

1. **Before the unlock the toggle is locked.** The kit's 16 px lock (`lacquer_mini_lock_ai.png`) beside "Auto", the toggle's art darkened and its label faded; a press does nothing, no hover frame, no pointer hand. On hover a tooltip board (the cabinet's `StatTooltip` piece) rises above the toggle, right edges aligned: "Unlock Auto", then what a perfect cycle is for the technique ("Play a perfect cycle: follow the ball the whole cycle", "… and press every zone PERFECT.", "… and open every seal."). The status line never changes for the lock.
2. **A perfect cycle** runs to its end, followed the whole way (the gold ring never out from the first frame to the end), with every zone PERFECT and every seal opened. A full pool or a capped stat still counts.
3. **The unlock shows** as a brass floater over the ball, "PERFECT CYCLE · Auto unlocked", two brass flashes on the toggle (which stays off), and one yellow log line, "<technique> · Auto unlocked".
4. **No drawer mark.**
5. **One flat 0.4×** for Madra and Spirit XP while Auto is on and nobody follows. Following pays the full rate. The cap holds.
6. **Auto running:** the running status line opens "Auto cycles on at 40%. Follow the ball for the full rate.", then the technique's clause, read as the cycle starts. No gold ring while Auto carries the ball. With Auto on, the board starts a cycle by itself whenever it is ready.
7. **Auto pays no other stat:** it never plays zones or seals; the player still can.
8. **Flat speed (Lionel, at approval):** an Auto cycle moves the ball at an even speed, no ease in or out, so chained cycles flow into each other. #94 dropped the speed curve, so this is the only speed change.
9. **No Auto with the board closed.** Closing stops cycling as today; #107 closes.

## Shape

- `SaveGameData.auto_cycling_technique_ids: Array[String] = []`, version 6, a step that moves nothing.
- `CyclingManager`: `signal auto_unlocked(technique)`, `unlock_auto(id)` (saved, idempotent, an id outside the catalog refused with `push_error`), `is_auto_unlocked(id) -> bool`.
- `CycleResult`: `followed_throughout: bool`, `is_perfect() -> bool` (followed throughout, every zone state PERFECT, every seal state OPEN).
- `CyclingRules.AUTO_RATE = 0.4`.
- `CyclingTechnique`:
  - `_followed_throughout` breaks on any running frame that does not follow; written to the result as the cycle finishes.
  - `is_auto_running() -> bool`: `auto_cycle` and the technique's Auto unlocked (the technique checks the unlock itself, so a locked technique never pays unattended even if a caller set `auto_cycle`).
  - Unattended frames (Auto running, not following) draw Madra on the Madra timer at `AUTO_RATE` of the frame's time and gather Spirit time at `AUTO_RATE`, without adding to the followed time. The rate window records the frame at the same share, so the session's rate reads 0.4×.
  - `_flat`: decided as a cycle starts (Auto running then). A flat cycle's ball moves linearly; seal nodes keep their places, and a flat cycle reaches each node at the cycle's share of the path where the eased ball reached it, so seals show and burst on time.
- `StatTooltip.set_text(title, figure)`: fills the board with any two lines (the cabinet's piece, reused).
- `CyclingView`:
  - Its scene adds `%AutoLock` (the mini lock) and `%AutoFlash` (a frame overlay with the flash style) to the toggle, and `%AutoTooltip` (a `StatTooltip`) as the last child.
  - `_show_auto_state()` draws locked, off and on; locked disables the toggle and turns `auto_cycle` off.
  - The toggle's hover shows the tooltip when locked, the hover frame otherwise.
  - `_on_cycle_completed()` unlocks the equipped technique's Auto after a perfect cycle; `_on_auto_unlocked()` pops the floater, flashes the toggle, logs the line and redraws the toggle.
  - `status_line()` takes whether Auto runs, read as a cycle starts.
  - `_process()` starts a cycle whenever Auto runs and the ball is ready.

## Tests

- `test_cycling_manager.gd`: unlock saved, per technique, idempotent with one signal, unknown id refused.
- `test_cycling_rules.gd`: `test_is_perfect` table (followed or not, zone tiers, seals, zoneless).
- `test_cycling_technique.gd`: a followed cycle is followed throughout and a break is not; unattended Auto pays 0.4× Madra and Spirit; locked Auto pays nothing unattended; following under Auto pays the full rate; an Auto cycle's ball moves at an even speed and its seals still burst on their nodes; the session rate reads 0.4×.
- `test_cycling_view.gd`: a perfect cycle unlocks only its technique (floater, log line, flash); a near miss does not; the locked toggle is disabled and keeps Auto off; the tooltip's text on hover with the status line unchanged; the Auto status line; Auto starts a cycle when ready. Rewrites `test_auto_toggle_sets_auto_cycle` and `test_a_toggle_that_starts_pressed_is_honoured` for the gate.
- `test_save_round_trip.gd` (`_full_save()` sets the list), `test_save_migration.gd` (version 6 moves nothing; version 5's test stops asserting it is current).
- `test_cultivator_plate.gd` or a stat tooltip test: `set_text()`.

## Built differently

(Filled in as the build goes.)
