# One Madra Max Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One saved Madra pool sized by Mind. `ResourceManager.get_max_madra()` is the max Madra stat (Mind × 10 plus modifiers), the pool never holds more, Core Density stops setting a Madra cap, and a run needs half the max (stats rework chunk #86, tracked in #85).

**Architecture:** `ResourceManager` keeps owning `SaveGameData.madra` and gains the max. Adds and sets clamp to [0, max]. A falling max (heard on `CharacterManager.stats_changed`) brings the pool down and emits `madra_changed` once. A save binds at most at the max. On a save reset `CharacterManager` (4th autoload) binds and announces its stats while `ResourceManager` (6th) still holds the old save, so the stat hook skips when the two saves differ and the bind clamps instead. The stage files and `CultivationManager` lose their Madra fields and getters. The cabinet's max follows stat changes.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Design:** the master plan's Task 2.1 (`2026-11-04-stats-rework.md`), checked against `main`, and issue #86. The issue's Decided list wins where the two differ:
- The adventure card's only edit is the one read of the capacity, now `get_max_madra()`. Its class doc and ready line are #89's.
- `ResourceManager` still emits `madra_changed` at every bind (the screens and #88's old-save sweep rely on it).
- A content check pins that only the Aura Well's training action awards Madra.
- PK-05: the shipped stat caps are pinned once, in `test_foundation_tribulation_data.gd`.

**Canvas:** "One Madra max", https://claude.ai/artifact/H2xMiZUJStqBENmw6fjesd. **Approved 2026-11-05, as drawn.** Five states of the cabinet: a new character 25 / 100; the Leeching Ring on 110 / 120; the ring off 100 / 100 (the pool comes down with the max); Core Density Level 10 still 25 / 100; an old save holding 150 opens at 100 / 100. The figures keep the "25 / 100" format, and neither the pool coming down nor the clamp at load writes a log line. Built differently from the issue: the Mind gear is drawn as the Leeching Ring (+20% Mind, the only Mind gear, so 120), not a +50% ring at 140 / 150. Tasks 1 to 3 changed no screen and ran before the approval; Task 4 followed it.

**Save:** no schema change and no version step. A saved pool above the new max is cut to the max when the save binds, and the next write keeps it.

## Global Constraints

The master plan's Global Constraints hold. In short: explicit types and return types, `##` docs on public functions, `%UniqueName` nodes, no `print()`, tests call production code with the save swap (`PersistenceManager.save_game_data = SaveGameData.new_current(); PersistenceManager.save_data_reset.emit()`, restored in `after_each()`), no GUT doubles, and a test that sets a modifier source removes it. One test file: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=<res path> -gexit`. Full suite: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.

---

### Task 1: The max, the clamps and the threshold in ResourceManager

**Files:**
- Modify: `singletons/resource_manager/resource_manager.gd`
- Modify, the callers of the capacity and budget: `scenes/zones/zone_transition/zone_transition.gd` (`_on_adventure_start_requested()`: the drain is the whole pool, its ratio over the max), `scenes/zones/zone_action_button/presenters/adventure_presenter.gd` (the one read in `_update_state()`)
- Test: `tests/unit/test_resource_manager.gd` (fixture becomes the save swap; the stage stub, the two-cap and budget tests go), `tests/integration/test_adventure_flow.gd` (rewritten: Mind gear through InventoryManager), `tests/integration/test_zone_transition.gd`, `tests/integration/test_board_transition_camera.gd`, `tests/integration/test_idle_action_resolution.gd` if it reads a removed name

- [x] **Step 1: Write the failing tests** (master plan Task 2.1 Step 1, `test_resource_manager.gd` and `test_adventure_flow.gd`): the max is the max Madra stat, Core Density leaves it alone, adds and sets stop at the max, a falling max brings the pool down with one `madra_changed`, a falling max above the pool leaves it quiet, a save binds at most at the max (pool and save), a save reset leaves the old save's pool alone, the threshold is half the max, and every bind still announces the pool.
- [x] **Step 2: Run them and see them fail.**
- [x] **Step 3: Implement.** `get_max_madra()` returns `CharacterManager.get_stat(StatModifierData.Stat.MAX_MADRA)`. `add_madra()` and `set_madra()` clamp with `clampf(…, 0.0, get_max_madra())`. `get_adventure_madra_threshold()` is half the max. `_clamp_to_max() -> bool`; `_update_resources()` clamps before its emits and logs a `Log.info` line when it cut; `_ready()` connects `CharacterManager.stats_changed` to `_on_stats_changed()`, which returns while `CharacterManager.live_save_data != live_save_data` and emits once when it cut. Delete `get_adventure_madra_capacity()` and `get_adventure_madra_budget()`. Every Madra and gold function gets its `##` doc. Repoint the drain and the card's read.
- [x] **Step 4: Run the task's tests and `test_quiet_madra.gd`, `test_zone_action_cards.gd`: PASS.**
- [x] **Step 5: Commit:** `feat(madra): size the Madra pool by the max Madra stat`.

### Task 2: Cycling's "Madra full" and the dev panel's Set Madra

**Files:**
- Modify: `scenes/cycling/cycling_technique/cycling_technique.gd` (`_madra_full()` and the two docs), `scenes/cycling/cycling_view/cycling_view.gd` (`_update_status()`), `singletons/dev_manager/dev_commands.gd` (`set_madra()` refuses a value past the max)
- Test: `tests/integration/test_cycling_technique.gd` (`_make_room()` replaces the Core Density raises; the over-the-cap test goes), `tests/integration/test_cycling_view.gd`, `tests/integration/test_dev_commands.gd` (`test_set_madra_refuses_more_than_the_max`)

- [x] **Step 1: Write the failing tests** (master plan Task 2.1 Step 1, those three files).
- [x] **Step 2: Run them and see them fail.**
- [x] **Step 3: Implement** (master plan Task 2.1 Step 3, the cycling and dev bullets).
- [x] **Step 4: Run the task's tests: PASS.**
- [x] **Step 5: Commit:** `feat(madra): measure cycling and Set Madra against the one max`.

### Task 3: The home Madra content check

**Files:**
- Create: `tests/unit/test_home_madra_sources.gd`

- [x] **Step 1: Write the check.** It loads every `.tres` under `res://resources/`, walks each one's stored properties (sub-resources, arrays, dictionaries) and lists every resource other than an `AwardResourceEffectData` that holds a Madra award. Only `aura_well_training_action.tres` may. A second test pins that the walk finds the Aura Well's trickle, so a broken walk can't pass by finding nothing.
- [x] **Step 2: Run it: PASS** (content already holds the rule). Break it once by hand (point a quest at `award_madra_5_effect_data.tres` in memory) to see the message, then revert.
- [x] **Step 3: Commit:** `test(madra): pin the Aura Well as the only Madra award in content`.

### Task 4: The cabinet follows the max, and Core Density's cap goes (after the canvas is approved)

**Files:**
- Modify: `scenes/zones/cultivator_plate/cultivator_plate.gd` (`_update_madra()` reads `ResourceManager.get_max_madra()`; `_on_stats_changed()` refreshes it; the Core Density refreshes of it go; the class doc), `scripts/resource_definitions/cycling/advancement_stage/advancement_stage.gd`, both stage `.tres`, `singletons/cultivation_manager/cultivation_manager.gd`, `scripts/resource_definitions/character/character_attributes_data.gd` (the doc of `get_max_madra()`)
- Test: `tests/integration/test_cultivator_plate.gd` (`test_the_madra_max_follows_the_max_madra_stat`, `test_a_core_density_level_up_leaves_the_madra_max_alone`; `test_madra_fill_follows_max` goes), `tests/unit/test_cultivation_getters.gd`, `tests/unit/test_cultivation_manager.gd` (its Madra cap test and its copy of the shipped stat caps go: PK-05), `tests/unit/test_foundation_tribulation_data.gd`

- [x] **Step 1: Write the failing tests.**
- [x] **Step 2: Run them and see them fail.**
- [x] **Step 3: Implement**, as the approved canvas draws it.
- [x] **Step 4: Run the task's tests: PASS.** `git grep -n -e get_max_madra_at -e max_madra_base -e max_madra_per_core_density_level -e get_adventure_madra_capacity -e get_adventure_madra_budget -e "CultivationManager.get_max_madra" -- scenes scripts singletons tests resources`: no output.
- [x] **Step 5: Commit:** `feat(madra): drop Core Density's Madra cap`.

### Task 5: Wrap

- [x] **Step 1:** The master plan's one note: phases 2 to 6 are built as the chunks in #85, each with its own plan file. Commit: `docs(stats): note that phases 2 to 6 run as #85's chunks`.
- [x] **Step 2:** The full suite: PASS (a parallel-run failure is confirmed in one process first).
- [x] **Step 3:** The issue's Done-when checks on `-- --save=user://dev/runs/madra-pool.tres`, plus a copy of an old save whose pool sat above 100.
- [x] **Step 4:** Record the approved canvas answers here and on #86; open the PR that closes #86, ending with `## Docs to update`.
