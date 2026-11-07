# Health Comes Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stats rework chunk #104 (tracked in #85): Health comes home from a run as it is and the next run starts there, with Stamina full. The adventure card shows both pools as icon and figure, a pool below half blinks, and a click while either is low asks "Head out?" before the run starts. Since a run may start at 0 Health, only a lost fight marks a lost run.

**Architecture:** `VitalsManager.initialize_current_values()` stops filling the player's Health. `AdventurePresenter` writes the pools line and blinks a low figure from a `Timer` in its scene; its `can_activate()` is false while either pool is low, and `on_activation_rejected()` asks `ActionManager.ask_to_start_adventure()`, which emits `adventure_confirm_requested`. `AdventureConfirmState`, a MainView overlay state, listens for it in `_ready()` like the other states, and shows `AdventureConfirmBoard` in the map gap; **Head out** pops the state and calls `ActionManager.select_action()`, which is unchanged. `AdventureView` keeps a flag the lost fight sets, read by `stop_adventure()` in place of today's Health check.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Spec:** issue #104's Decided list, with the approved "Health comes home" canvas (https://claude.ai/artifact/TRhhdV1JkrQQwFKtZDVZf8), whose answers are below and on #104 (issuecomment-6678416037). The master plan's Task 5.17 for shape only: where it differs, the issue and the canvas win.

## The canvas's answers (approved by Lionel on 2026-11-05, as drawn, after two rounds)

Round one proposed a warning row and a refusal at 0. Lionel: "I want Madra and Health to be similar: if either is below half, have a popup come up with verification." Round two drew that with a warning row. Lionel: "Instead of these warnings on the card just have the HP and Madra / 100 flashing if they're below threshold; with the popup it will be enough. Also thoughts about using icons?"

- **No refusal.** If Health **or** Madra is below half its max (`ResourceManager.is_health_low()`, `is_madra_low()`), clicking the adventure card opens "Head out?"; at half or more the run starts at once, as today. `select_action` is untouched.
- **The card:** its detail line is "[heart] 38 / 100    [drop] 100 / 100", the dock's 16 px minis (`lacquer_mini_health_ai.png`, `lacquer_mini_madra_ai.png`) and each figure in its ink (`LACQUER_HEALTH`, `LACQUER_MADRA`). Health reads through `VitalsText.health_pair`, Madra as the card reads it today (floored). "5 min run" moves to the right column in brass. The card stays ready and ENTER.
- **The blink:** a low figure steps between its ink and `LACQUER_DIM`, 0.5 s lit, 0.5 s dim, while it is low; both blink on one beat. Whole steps, no fade. Half is half of the max as it stands, so gear moves the line; the card follows `madra_changed`, `health_changed` and `stats_changed`.
- **The board:** in the map gap, no backdrop, the cabinet and the chest up. The Tribulation intro's frame (`trib_board9.tres`) and buttons (About art, hover frames). Title "Head out?"; each low pool as its icon and figure on one line; then "Below half. Riverbank Training heals it." (Health), "Below half. Cycling refills it." (Madra), "Below half. Riverbank Training heals Health; cycling refills Madra." (both); at 0 Health "The first hit that lands ends the run. Riverbank Training heals it." Buttons **Head out** and **Not yet**; Esc and a click outside the board also close it.
- **The loss rule:** only a lost fight marks a lost run; a run at 0 that times out reads "Time ran out" and counts as a timeout, one stopped early reads the retreat line and counts nothing.
- **A lost run's cost:** coming home at 0 Health, nothing more. No end card change (#103 owns it).
- **No Health consumable; the Aura Well's rest kept at Body x 5; Stamina full at every run start.**

## Global Constraints

- `CLAUDE.md`'s GDScript standards: explicit types, `##` docs on public functions, private names start with `_`, no `print()`.
- UI nodes live in `.tscn` scenes with theme variants; scripts set text, colours and visibility only.
- No text is ever cut off: the board's lines wrap and the board grows; the board joins `BOARD_SCENES` in `test_boards_never_trim_text.gd`; no file joins `KNOWN_TRIMMERS`.
- Never two Health or two Madra numbers on screen: the card and the board use the cabinet's rounding.
- Lacquer motion: whole steps, no fade or tint tween.
- No end card code, no `AdventureResultData` field, no `select_action` change.
- Saves: no schema change, no version step. A save that came home hurt before this merge stays hurt until the player refines (the PR says so).
- Tests call production code, swap in a fresh `SaveGameData` and restore it, use no GUT doubles.
- One test file: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=<res path> -gexit`. Suite: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.

## Tasks

### Task 1: Health comes home (done before the canvas: no screen change)

- [x] `VitalsManager.initialize_current_values()` fills Stamina and an enemy's Health and Madra only. `test_player_vitals_manager.gd`: `test_a_run_starts_at_the_saved_health`, `test_new_max_health_leaves_the_next_runs_health`; `test_adventure_view_frame.gd`: `test_health_comes_home_from_a_run`, and the gear test drops "the run starts at that maximum".
- [x] `DevCommands.refill_vitals()` sets the saved Health to its max; `test_refill_vitals_keeps_the_run_madra` checks the pool.
- [x] `tests/unit/test_home_health_sources.gd`: only content under `res://resources/adventure/` holds a Health heal.

### Task 2: `ResourceManager.is_madra_low()`

- [x] True when Madra is below `LOW_MADRA_RATIO` (0.5) of the max, beside `LOW_HEALTH_RATIO`, which other branches may read, so it isn't renamed. Table test in `test_resource_manager.gd` beside `is_health_low`'s. (ResourceManager is a shared surface outside #104's Touches: said so on #104.)

### Task 3: The loss rule

- [x] `AdventureView._fight_lost`, reset when a run starts, set by `_on_stop_combat(false)`; `stop_adventure()` reads it in place of `current_health <= 0`. `test_adventure_end_flow.gd`: `test_zero_health_counts_a_lost_adventure` becomes `test_a_lost_fight_counts_a_lost_adventure` (a fight lost through `_on_stop_combat(false)`), plus `test_a_run_at_zero_health_that_times_out_counts_a_timeout` and `test_a_run_at_zero_health_stopped_early_counts_nothing`. `test_dev_adventure_commands.gd::test_exit_as_defeat_ends_the_run`'s comment and its 0-Health set-up follow.

### Task 4: The card's pools line and blink

- [x] `adventure_presenter.tscn`: the ReadyText row stays; add `BlinkTimer` (0.5 s, not one shot). `AdventurePresenter`: `pools_text(lit: bool)` (static-free, reads the pools) writes "[img]heart[/img] 38 / 100    [img]drop[/img] 100 / 100" with a low figure in `LACQUER_DIM` while unlit; `set_detail_right("<n> min run", LACQUER_BRASS)`; the timer runs while either pool is low and stops (lit) otherwise; follows `health_changed` too. `can_activate()` = neither pool low; `on_activation_rejected()` = `ActionManager.ask_to_start_adventure(action)`.
- [x] `test_zone_action_cards.gd` (or the adventure presenter's test file): the line at full pools; a low pool's figure dims on the blink and lights again; the blink stops once the pool is back at half; gear moving the max starts it; a click below half emits `adventure_confirm_requested` and starts nothing; a click at half or more starts the run.

### Task 5: ActionManager's question

- [x] `signal adventure_confirm_requested(action_data: AdventureActionData)` and `ask_to_start_adventure(action_data)`, which only emits it. Tested through the card's click in `test_zone_action_cards.gd` (there is no ActionManager test file).

### Task 6: The "Head out?" board and its state

- [x] `scenes/zones/adventure_confirm/adventure_confirm_board.tscn` (`AdventureConfirmBoard`, full rect, hidden): a full-rect `ClickAway` (mouse stop), the `Board` `PanelContainer` on `trib_board9.tres`, centred in the map gap (x 466 to 1456), 480 wide; `Title` (`LabelLacquerPanelTitle`, "Head out?"), `Lines` (`RichTextLacquer`, tan, wraps), the `ButtonRow` with `GoButton` / `StayButton` on the About art with hover frames. Script: `ask(action)` writes the lines from the pools and shows the board; `close()`; signals `confirmed`, `dismissed` (Not yet, a click away).
- [x] `scenes/ui/main_view/states/adventure_confirm_state.gd` (`AdventureConfirmState`): `_ready()` connects `ActionManager.adventure_confirm_requested`; pushes itself (once); `enter()` shows the board and blocks the full log; `exit()` closes it; `handle_input()`: `ui_cancel` pops; nothing else reaches the zone view's book keys. On `confirmed`: pop, then `ActionManager.select_action(action)`; on `dismissed`: pop.
- [x] `main_game.tscn`: the state under `MainViewStateMachine`, the board under `MainView` above the HUD boards; `MainView`: `adventure_confirm_board`, `adventure_confirm_state`, `scene_root` set in `_ready()`.
- [x] Tests (`test_adventure_confirm.gd`): each case's lines (Health, Madra, both, 0 Health); Head out starts the adventure and closes the board; Not yet, Esc and a click away close it and start nothing, the idle action still running; a book key does nothing while it is up. The board joins `BOARD_SCENES`.

### Task 7: Verify

- [x] Suite green; the issue's Done-when checks on `-- --save=user://dev/runs/health-comes-home.tres` (and the `adventure_open` preset for the robes check); an old save loads and plays.

## Docs to update (for #112)

The issue's list, with: `ZONES.md` and `MAIN_VIEW.md` (the card's pools line and blink, the "Head out?" board and its state, Esc), `RESOURCES.md` (`is_madra_low`, `LOW_MADRA_RATIO`), `ADVENTURING.md` (the end reasons: only a lost fight is a loss), `PERSISTENCE.md` (the play stats' lost-run row).

## What was built differently

- **The card's pools line** reuses the forage cards' icon and figure piece (`forage_yield.tscn`) twice in an `HFlowContainer`, as the body refining card lists its rewards, instead of one RichTextLabel with inline images: a pool that would pass the line's room moves down whole, and the blink sets one label's colour. The adventure presenter stays out of `BOARD_SCENES`, which wants plain Labels: like the body refining presenter it holds only RichTextLabels, which never trim.
- **The board's lines** are the same two pieces (each shown only while its pool is low) and a wrapping `LabelLacquerDetail` advice Label.
- **The "Exit as defeat" dev check** now leaves its run as a retreat, since only a lost fight is a loss; `test_exit_as_defeat_ends_the_run` stops the run's timer to keep an end that play would count ("Time ran out").
- **Verified in the real main scene** by a scripted driver (`mockups/health_home_canvas/done_when.gd`, gitignored) on `-- --preset=adventure_open --save=user://dev/runs/health-comes-home.tres`: every Done-when check passes; back to half from 0 took 13 perfect Stone Lifting reps, as the canvas said. A version-0 save loads, migrates to 5, its 25 Madra blinks, the click asks, and Head out starts the run.
