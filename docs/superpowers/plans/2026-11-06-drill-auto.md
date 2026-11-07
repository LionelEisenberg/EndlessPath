# Unlock drill Auto after a perfect set (#110)

Stats rework chunk #110, tracked in #85. Design: the spec's Phase 5 and Anti-goals, the master plan's Task 5.16, #101's Auto shape (`2026-11-06-cycling-auto.md`) and the answers below. Built against `main` at 26d8b6e6 (#134 and #135 merged).

## Approved mock-up answers

Canvas: [Drill Auto](https://claude.ai/artifact/5AG7bRrF7c2pqRNq5TE4XG), round 1, approved as drawn on 2026-11-06. Recorded on #110 (issuecomment-6702563586). Each is #101's answer for cycling, carried over, unless it says otherwise.

1. **Before the unlock the toggle is locked.** Cycling's toggle at the right of the drill board's footer, the drill's line wrapping beside it (the shorter centred on the taller). Locked: the mini lock, the art darkened, the label faded, no press. On hover the stat tooltip: "Unlock Auto" / "Play a perfect set: all ten reps Perfect." The footer line never changes for the lock. The toggle follows the drill in use.
2. **A perfect set** is ten Perfect reps (`DrillSetResult.is_perfect()`), played to its tenth rep. A full pool or a capped Strength still counts. It unlocks that drill only.
3. **The unlock shows** as a brass floater over the stage, "PERFECT SET · Auto unlocked", two brass flashes on the toggle (which stays off), and one yellow log line, "<drill> · Auto unlocked". No drawer mark.
4. **One flat 0.4×** of a Perfect rep, Strength XP and Health alike, at the drill's rep pace. The cap holds.
5. **Auto playing:** with Auto on, the board plays sets by itself whenever it is ready (Auto turned on, the board opened, a set ended); the stage plays itself as a good player would. Each rep pops "Auto" in tan, lights its bead dimmed, and sends two pellets each to Strength and Health. Footer: "Auto drills on at 40%. Turn Auto off to play for the full rate." After an Auto set: "Last set · Auto · [arm] +N XP · [heart] +N"; log "Set · Auto · +N Strength XP · +N Health".
6. **Presses while Auto plays** play nothing. Turning Auto off or on mid-set ends that set (reps paid, neither counted nor logged).
7. **No Auto with the board closed.** 8. **Not beside Auto cycling.** 9. **No other stat:** no Body, no Agility.

Saved: `auto_drill_ids`, empty for old saves; the toggle's state is not saved. `ActionManager` and the idle checks don't change.

## Shape

- `SaveGameData.auto_drill_ids: Array[String] = []`, version 7, a step that moves nothing (claimed at merge).
- `BodyRefiningManager`: `signal auto_unlocked(drill)`, `unlock_auto(id)` (saved, idempotent, an unknown id refused with `push_error`), `is_auto_unlocked(id)`. `pay_rep()` pays no minor stat for an Auto rep.
- `DrillRules`: `Tier.AUTO` (never judged; an Auto rep's own kind) with factor `AUTO_RATE = 0.4`.
- `DrillRun.play_auto(t)`: feeds the run a good player's inputs up to `t`, at exact times, then judges what time decided. Each run overrides it from its own marks:
  - `StoneLiftingRun`: lifts as each rep may begin, lets go at `BAND_CENTRE_USEC`.
  - `HorseStanceRun`: on a fixed `AUTO_STEP_USEC` grid, sinks while the needle is shallower than the arc's centre and rises while deeper.
  - `FallingLeafRun`: catches each leaf at its middle `AUTO_CATCH_USEC` into its fall.
  - `TimedPressRun`: presses on each target.
- `DrillPlay`:
  - `auto_play: bool`; `is_auto_running()` = `auto_play` and the drill's Auto unlocked (the play checks the unlock itself, as `CyclingTechnique` does).
  - While Auto runs and no set does, `_process()` starts an Auto set; an Auto set's frames call `play_auto()`, and each judgement becomes `Tier.AUTO` before it is paid. A press while Auto runs is taken and plays nothing.
  - `TIER_WORDS[AUTO]` "Auto" in tan; the bead lights Perfect's frame dimmed.
  - `is_auto_set()` for the board's lines.
- `DrillSetResult`: `is_auto()` (a rep was Auto); the log line opens "Set · Auto" and leaves the other stat out.
- `BodyRefiningView`:
  - Its scene adds `%AutoToggle` (cycling's, with `%AutoLabel`, `%AutoLock`, `%AutoHover`, `%AutoFlash`), `%AutoTooltip` (a `StatTooltip`) and `%UnlockFloater`; `%StatusText` narrows to 368 px beside the toggle.
  - `_refresh_auto()` gates the toggle on the drill's unlock and hands the play `auto_play`; toggling ends a set in progress.
  - `_on_set_completed()` unlocks the drill's Auto after a perfect set; `_on_auto_unlocked()` pops the floater, flashes the toggle, logs the line and redraws the toggle.
  - The footer: `AUTO_LINE` as an Auto set starts with no last set to show; `result_line()` reads "Last set · Auto · …" for an Auto set, without the other stat or the perfect count. `PELLETS_BY_TIER[AUTO] = 2`.
  - `_relayout_board()` sets the toggle beside the footer line.

## Tests

- `test_body_refining_manager.gd`: the unlock per drill, saved, idempotent with one signal, an unknown id refused (done); an Auto rep pays 0.4 of Strength and Health and no minor stat.
- `test_drill_rules.gd`: AUTO's factor.
- `test_drill_set_result.gd`: an Auto set is never perfect; its log line.
- Each run's test: `play_auto()` judges every rep of a set on time, and on Stone Lifting, Horse Stance and Waterfall every rep would be Perfect.
- `test_drill_play.gd`: `test_auto_plays_reps_at_the_auto_rate`; locked Auto plays nothing; a press under Auto plays nothing; Auto starts the next set by itself.
- `test_body_refining_view.gd`: `test_auto_stays_locked_until_a_perfect_set`, `test_a_perfect_set_unlocks_auto` (floater, log, the other drill locked), a near miss leaves it locked; the locked toggle keeps Auto off; toggling mid-set ends the set; the Auto footer lines.
- `test_save_migration.gd` (version 7) and `test_save_round_trip.gd` (done).

## Built differently

- **The footer under Auto.** Answer 5 has the board start the next Auto set as one ends, and the last Auto set's line show "until the next set starts", which would show it for one frame. So an Auto set's line stays through the next Auto set until that one ends; `AUTO_LINE` shows as the first Auto set starts (Auto turned on, the board opened, a drill picked).
- **What an Auto rep could not pay.** An Auto rep pops "Auto" with no second line, as drawn, except that, like any scored rep, it shows what it could not pay ("[arm] capped", "[heart] full"): the canvas drew Auto with nothing capped and Health low.
- **The long-name layout test** (`test_a_long_name_wraps_and_the_board_grows`) now wraps the action's name to two lines, not three. Beside the toggle the footer's line wraps to two lines, and a three-line name with the pay line and a two-line footer runs 16 px past the screen. Every action name today fits one line.
- **Auto's play is exact, not per frame.** Each run's `play_auto()` gives its inputs at exact times (Horse Stance's on a fixed 50 ms grid), so an Auto set plays the same on any frame rate; every input's Auto set is all Perfect before it is paid as AUTO.
- **The unlock floater** stands 286 px under the figure box's top, centred on the board (`UNLOCK_FLOATER_DROP`), where the canvas drew it over the gauge, for every drill.
