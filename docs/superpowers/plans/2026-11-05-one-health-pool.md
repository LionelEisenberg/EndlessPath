# One Health Pool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One saved Health pool in `ResourceManager`, sized by the max Health stat (Body × 10 plus modifiers, gear included), with the over-max rule and one change signal Madra has (stats rework chunk #93, tracked in #85). Nothing in play reads it yet: runs keep their own Health until #98.

**Architecture:** `SaveGameData.health` defaults to `HEALTH_UNSET` (-1.0). A version step (`_migrate_to_v3()`) writes the sentinel into every older save explicitly, so the fill never depends on the field's default, and the bump keeps an older build from writing the save back without Health. `ResourceManager` fills an unset Health to the max and clamps one above it, at bind and on `CharacterManager.stats_changed`, both behind one guard: the max is read only while `CharacterManager` holds the same save (its gear source reads that save). If `CharacterManager` binds after `ResourceManager`, the fill waits for its `stats_changed`. The Health functions are twins of the Madra ones #86 left. `is_health_low()` is below `LOW_HEALTH_RATIO` (0.5) of the max.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Design:** issue #93's Decided list, and the master plan's Task 5.2 and 5.22 notes (`2026-11-04-stats-rework.md`). Where they differ, the issue wins.

**Save:** adds `health`, with a version step. The chunk takes the next free number when it merges: v3 if it merges first.

**Pattern:** the save stays a `Resource` written as `.tres` with incremental `_migrate_to_vN()` steps, as the project already does. The save-load skill's JSON recommendation conflicts with the project's established format, so the project wins.

## Global Constraints

The master plan's Global Constraints hold: explicit types, `##` docs on public functions, `%UniqueName` nodes, no `print()`, tests call production code with the save swap (restored in `after_each()`), no GUT doubles, and a test that sets a modifier source removes it. One test file: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=<res path> -gexit`. Full suite: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.

---

### Task 1: The saved field and its version step

**Files:**
- Modify: `singletons/persistence_manager/save_game_data.gd` (`HEALTH_UNSET`, `health`, `CURRENT_VERSION = 3`, `_migrate_to_v3()`, the `_to_string` line)
- Test: `tests/unit/test_save_migration.gd`, `tests/unit/test_save_round_trip.gd` (`_full_save()` sets `health`)

- [x] **Step 1: Write the failing tests:** `test_v3_leaves_health_for_the_bind_to_fill` (a v2 save holding a stray Health value comes out unset), `test_v3_skips_a_current_save`, `test_a_new_and_a_reset_save_hold_health_unset`, `test_an_old_file_loads_health_unset`, `test_to_string_names_health`; `_full_save()` sets `health`.
- [x] **Step 2: Run them and see them fail.**
- [x] **Step 3: Implement.**
- [x] **Step 4: Run the two files: PASS.**

### Task 2: LL-06, DM-03 and DM-04

**Files:**
- Modify: `singletons/cultivation_manager/cultivation_manager.gd` (`get_stat_level_cap_of(stage)`, plain values, reading the stage list), `singletons/persistence_manager/save_game_data.gd` (the version 2 step reads through it; `migrate()` stops without stamping when `CultivationManager` is missing), `singletons/persistence_manager/persistence_manager.gd` (a save still below the current version after `migrate()` blocks saving, since `save_data()` stamps on write)
- Test: `tests/unit/test_cultivation_getters.gd` or `test_cultivation_manager.gd` (the read, table), `tests/unit/test_save_migration.gd` (an inner `SaveGameData` whose `CultivationManager` check fails stays at version 1, unconverted; DM-04's four messages)

- [x] **Step 1: Write the failing tests.**
- [x] **Step 2: Run them and see them fail.**
- [x] **Step 3: Implement.** Each version step stamps its own number once it ran, so a stop leaves the save at the last step it finished.
- [x] **Step 4: Run the files: PASS.**

### Task 3: ResourceManager's Health

**Files:**
- Modify: `singletons/resource_manager/resource_manager.gd`
- Test: `tests/unit/test_resource_manager.gd`

- [x] **Step 1: Write the failing tests:** the max is the max Health stat (table: new character, Body Lv 3, a +40 bonus); adds keep [0, max] and return what was added; a whole gain logs "Gained N Health", quiet and at-max don't; spend refuses more than the pool; set holds [0, max]; an unset Health binds full; a falling max brings Health down with one `health_changed`; one above the pool leaves it quiet; a save binds at most at the max; every bind announces Health; a save reset leaves the old save's Health alone; when `CharacterManager` holds another save, the bind waits and its `stats_changed` fills; `is_health_low()` below half (table).
- [x] **Step 2: Run them and see them fail.**
- [x] **Step 3: Implement.**
- [x] **Step 4: Run the file: PASS.**

### Task 4: The dev panel's Set Health and Health line

**Files:**
- Modify: `singletons/dev_manager/dev_commands.gd` (`set_health(value)`), `scenes/ui/dev_panel/tabs/player_tab.tscn` (a Health row and a `HealthLabel` line), `scenes/ui/dev_panel/tabs/player_tab.gd`
- Test: `tests/integration/test_dev_commands.gd` (`test_set_health_sets_exactly_and_refuses_past_the_max`), `tests/integration/test_dev_panel.gd` (`test_player_tab_sets_health`, `test_player_tab_health_line_follows_the_pool_and_its_max`)

- [x] **Step 1: Write the failing tests.**
- [x] **Step 2: Run them and see them fail.**
- [x] **Step 3: Implement.** The line reads "Health 40 / 100" and follows `health_changed` and `CharacterManager.stats_changed`.
- [x] **Step 4: Run the files: PASS.**

### Task 5: Wrap

- [x] **Step 1:** The full suite: PASS.
- [x] **Step 2:** The issue's Done-when checks on `user://dev/runs/health-pool.tres`, and a copy of a save from before this chunk. They ran headless through a throwaway scene (deleted) that opened the save with `PersistenceManager.open_save_file()`, drove the Player tab and wrote with `save_data()`, one process per step so the reload is a fresh launch. The run check called the run's own start (`VitalsManager.initialize_current_values()`, as `AdventureView` does) rather than playing a run.
- [x] **Step 3:** Open the PR that closes #93, ending with `## Docs to update`.

## Built differently

- DM-03 also touches `PersistenceManager`, outside the issue's Touches: `save_data()` stamps the current version on every write, so `migrate()` leaving a save unstamped is not enough. A loaded save still below the current version after `migrate()` blocks saving.
- The version steps now stamp their own numbers (`_run_version_steps()`), and a new step joins that function instead of `migrate()`.
- The Health clamp at a falling max writes a `Log.info` line; Madra's at a falling max writes none. Neither writes to the player's log.
