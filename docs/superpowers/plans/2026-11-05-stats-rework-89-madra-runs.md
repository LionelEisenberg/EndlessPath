# Stats rework chunk #89: runs on the one Madra pool

Issue: LionelEisenberg/EndlessPath#89, tracked in #85. Design: the master plan's Tasks 2.2 to 2.4 (`2026-11-04-stats-rework.md`), checked against `main` at f5711fd7 (#86's pool, #87's wrapping cards, #91 and #93 merged).

**Goal:** a run plays on the saved Madra pool. Starting one spends nothing, techniques spend from the pool, Scales and rest tiles refill it quietly, and what is left stays there. Every Madra readout shows that pool, and the end card's Health reads as the vitals plate's.

## Mock-ups

Canvas "One Madra Pool": https://claude.ai/artifact/1dmSBZVoz2dzHthSP5Fqpb. Real captures of the card, the run start, the end card and the book, with the proposed copy patched in.

Approved: _waiting for Lionel._ The proposals:
- Q1, the card's ready line: "carries 60 Madra", the pool.
- Q2, the book's Madra row: "46 / 100", live while the book is open.
- Q3, the run start: the pellets fly while the cabinet's figure stays put, counted from the start threshold to full (8 at half the max, 25 at full). The plan counted from empty (16 at half).
- Q4, the end card: "MADRA LEFT" over "46 / 100".
- Q5, one Health rounding rule: the vitals plate's, the current figure rounded up over the max rounded down, on the end card too.

## What `main` already has

- `ResourceManager`: `get_madra()`, `get_max_madra()`, the clamped `add_madra(amount, quiet)` (emits `madra_changed` on every call) and `set_madra()`, `get_adventure_madra_threshold()`, `can_start_adventure()`. The pool comes down with the max (`_on_stats_changed`).
- The cabinet already reads `get_max_madra()` and needs no change (#86).
- The card prints `get_max_madra()` in its ready line through #87's `set_detail_right()`.
- `ZoneTransition` spends the whole pool pellet by pellet and passes it on as `madra_budget`; `AdventureView` fills the vitals with it and reports it as `madra_spent`.
- `CharacterView.fight_lines()` prints max Madra alone; `_fill_fight_rows()` sets the two column widths in code (`_FIGHT_COLUMN_WIDTHS`).

## Tasks

### Task 1: the player's Madra is the pool (no screen changes)

Files: `vitals_manager.gd`, `adventure_view.gd` (`_initialize_combat_resources`), `dev_commands.gd` (`refill_vitals`), `player_manager.gd` (class doc, `reset_vitals` doc), and the tests that wrote the player's Madra fields.

- `VitalsManager`, player only (`is_player`):
  - `current_madra` and `max_madra` read `ResourceManager.get_madra()` and `get_max_madra()`. Writing `current_madra` calls `ResourceManager.set_madra()` and emits nothing itself; the pool's signal does.
  - `_ready()` connects `ResourceManager.madra_changed` to `_on_pool_changed()`, which re-emits `madra_changed` once per pool change. The connection goes with the node when `reset_vitals()` frees it.
  - `_apply_madra_change(amount)` calls `ResourceManager.add_madra(amount, true)` when `amount != 0.0`: quiet, so a Scale or a rest tile logs no "Gained" line and a hit or a step leaves the pool's signal (which sweeps every unlock condition) alone.
  - `initialize_current_values()` loses `starting_madra`: it fills Health and Stamina, and an enemy's Madra, never the player's pool.
  - `_on_stats_changed()` drops its `max_madra` line. Enemies keep in-memory Madra.
  - `##` docs on `initialize_current_values()` and `apply_vitals_change()`.
- `AdventureView._initialize_combat_resources()` calls `initialize_current_values()`. Until Task 2, a real run starts on what the drain left.
- `DevCommands.refill_vitals()`: `_while_paused(vitals.initialize_current_values)`; the pool stays as it is.
- `PlayerManager`: a class doc (owns the player's VitalsManager, the run's Health and Stamina and a window onto the saved Madra pool); `reset_vitals()`'s doc says Madra is ResourceManager's saved pool and stays.
- Tests: the master plan's MADRA: THE ONE POOL section in `test_player_vitals_manager.gd` (reads, changes landing in the pool, writes, one signal per change, quiet with no Madra change, a Scale's quiet refill, initialise leaves the pool, an enemy's Madra is its own). The dock, plate, consumable, dev and frame tests set the pool instead of the player's Madra fields (master plan Task 2.2's list).

### Task 2: runs start and end on the pool

Files: `zone_transition.gd`, `action_manager.gd`, `adventure_view.gd`, `adventure_view_state.gd`, `adventure_tab.gd`, `adventure_result_data.gd`, `adventure_end_card.gd` and `.tscn`, and the callers of the old signatures in the tests.

- `ZoneTransition`: `static func drain_pellet_count(madra, max_madra) -> int`, the pellets a start pours, by the curve Q3 approves. The spend, the per-pellet amounts and the deficit pellet go. `_on_zoom_complete()` calls `confirm_adventure_start(action)`. The class doc says the pellets are a flourish.
- `ActionManager`: `signal start_adventure(action_data)` and `confirm_adventure_start(action_data)`, with no budget.
- `AdventureView`: `start_adventure(action_data)`, no `_madra_budget`; `_initialize_combat_resources()` logs the pool the run starts on; `_build_result_data()` sets `madra_left` and `madra_max` from the pool.
- `AdventureViewState._on_start_adventure(_data)` and the dev tab's `_on_adventure_started(_action)` take the action only.
- `AdventureResultData.madra_left` and `madra_max` replace `madra_spent` (Q4 may drop the max).
- The end card: the Madra line with Q4's copy, and the Health line with Q5's rule.
- Tests: `test_zone_transition.gd` (the pellets spend nothing; the pellet count table), `test_adventure_end_flow.gd` (a run quit midway keeps what it spent and what is left, and the result carries both), `test_adventure_result_data.gd`, a new `test_adventure_end_card.gd` (the Madra line and the Health line as the plate reads it), and the old-signature callers.

### Task 3: one Health rounding rule

Files: a static helper both screens call, `vitals_plate.gd`, `adventure_end_card.gd`.

- With Q5's recommended rule: `VitalsPlate` and the end card print Health through one static function pair (the figure rounded up, the max rounded down). A table test pins the rule on 0.4, 90.9, 99.1 and 100 Health. #98 reuses it.

### Task 4: every Madra readout shows the pool

Files: `adventure_presenter.gd`, `character_view.gd` and `.tscn`, `test_zone_action_cards.gd`, a new `test_character_book_madra.gd`.

- `AdventurePresenter`: the ready line prints the pool (Q1). The class doc names the pool it carries and a threshold of half the max, which Mind and gear move.
- `CharacterView`:
  - `fight_lines()`' Madra entry reads "<pool> / <max>" (Q2).
  - `_rebuild_fight_rows()` rebuilds the In a fight rows; `refresh()` calls it, and `ResourceManager.madra_changed` calls it while the book is shown. #98 hooks Health to it.
  - The two column widths move from `_FIGHT_COLUMN_WIDTHS` into the scene: `%FightRows` becomes two columns laid out in `character_view.tscn` (each a VBox with its width), and the code splits the lines between them.
- Tests: the card's ready line at the threshold and after a Mind ring comes off; the book's Madra entry, and its row found by its "MADRA" caption following the pool and its max while open.

### Task 5: checks and PR

- Full suite through `tests/run_tests.ps1`. `git grep -n -e madra_budget -e madra_spent -e _drain_budget -e "MADRA SPENT" -- scenes scripts singletons tests` prints nothing.
- The issue's Done-when checks on `-- --save=user://dev/runs/madra-runs.tres`. An old save loads and plays on a copy.
- The PR closes #89 and ends with `## Docs to update` (the issue's list). Save: no schema change and no version step. A run now writes the saved pool, so the autosave and a quit mid-run keep what it spent and what is left.

## Built differently

_Filled in as the build goes._
