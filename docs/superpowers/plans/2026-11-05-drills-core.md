# Drills, Their Rules and the Manager That Pays Reps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Body refining gets its content and its rules (stats rework chunk #97, tracked in #85): a roster of drills as data, `DrillRules` (the judge, XP and Health per rep, a perfect set's XP), the set result, and a `BodyRefiningManager` autoload that holds the catalog and the unlocked, equipped and seen drills, and pays each rep through `pay_rep`. Nothing is playable: #100 builds the board. The dev panel lists, unlocks and equips drills.

**Architecture:** `DrillData` is a read-only `Resource`, one `.tres` per drill under `resources/body_refining/drills/<id>/`, listed in `drill_list.tres` (`DrillList`), as cycling techniques are. `BodyRefiningManager` copies `CyclingManager`'s catalog, unlock, equip and seen API with drill for technique, and binds to `PersistenceManager.save_game_data` the same way. `DrillRules` is a static class: one judge turns an input's share (0 to 1) into a `Tier`, and each tier has one factor that scales a rep's XP and Health alike. `DrillSetResult` is a `RefCounted` that collects a set's tiers and the Health it paid, and knows whether the set was perfect. `pay_rep(drill, tier, result)` pays Strength XP and the minor's XP through `CharacterManager.add_stat_xp()` and Health through `ResourceManager.add_health(amount, true)`, at the player's Strength total (gear included).

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Design:** issue #97's Decided list and the approved "Body refining drills" canvas (https://claude.ai/artifact/TDjWSogqzEoZNXGJUnmPmY). The master plan's Phase 5 outline (Tasks 5.7 to 5.9, 5.19, 5.21, 5.22) for shape only. Where they differ, the issue and the canvas win.

**Save:** adds `unlocked_drill_ids` (default `["stone_lifting"]`), `equipped_drill_id` (default `"stone_lifting"`), `seen_drill_ids` and `seen_drills_initialized`. The defaults suit old saves, so the version step moves nothing; the bump keeps an older build from writing the save back without the fields. The chunk takes the next free number when it merges: v4 if it merges next after #93.

**Pattern:** the resource pattern (read-only shared definitions, preloaded by the autoload). Rejected: drill numbers as constants in code, since the issue wants one file per drill with every value written out.

## The canvas's answers (approved by Lionel on 2026-11-05, as drawn; recorded on #97)

- **Roster:** Stone Lifting (Strength only, the new save's drill), Horse Stance (Strength + Body), Falling Leaf (Strength + Agility), Waterfall Tempering (Strength + Body).
- **Inputs:** hold to lift and let go in the brass band; hold steady in a drifting band; click to catch; press on the beat. #100 builds Stone Lifting's, #106 the rest.
- **Sets and judging:** 10 reps a set; a MISS still uses up its rep. One judge on the input's share: PERFECT ≥ 0.85, GOOD ≥ 0.6, OK ≥ 0.3, else MISS. Factors 1, 0.75, 0.5, 0, on XP and Health alike. A perfect set is 10 PERFECT reps. MISS is an addition to the issue's three tiers, so mashing pays nothing.
- **Combining:** each drill combines Strength with its one other stat; one drill at a time. The equipped drill stays one id.
- **Health per rep:** `health_per_rep × factor × (1 + 0.1 × max(0, Strength − 10))`, from the Strength total with gear. 4, 4, 2, 3 at Strength Lv 1.
- **XP per rep:** Strength 6, 8, 4, 6; the other stat 4, 2, 3. Lv 1 to 10 Strength (2,579 XP) takes 43, 33, 65 and 43 perfect sets, about 22 to 29 minutes, with Spirit's cap.
- **Rep length:** 4, 4, 2, 3 s. Icons: none drawn here; #100 and #106 draw them with the cards.

## Global Constraints

The master plan's Global Constraints hold: explicit types, `##` docs on public functions, no `print()`, tests call production code with the save swap (restored in `after_each()`), no GUT doubles. `project.godot` is committed alone, with its `[dialogic]` keys intact. One test file: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=<res path> -gexit`. Full suite: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.

---

### Task 1: The saved drill fields and their version step

**Files:**
- Modify: `singletons/persistence_manager/save_game_data.gd` (a BODY REFINING MANAGER block after CYCLING MANAGER; `CURRENT_VERSION = 4`; a step in `_run_version_steps()`; the `_to_string` lines)
- Test: `tests/unit/test_save_migration.gd` (`test_v4_keeps_the_starting_drill`, an old file loading the defaults), `tests/unit/test_save_round_trip.gd` (`_full_save()` sets each drill field)

- [x] **Step 1: Write the failing tests.**
- [x] **Step 2: Run them and see them fail.**
- [x] **Step 3: Implement.**
- [x] **Step 4: Run the two files: PASS.**

### Task 2: DrillData, DrillList and the drills

**Files:**
- Create: `scripts/resource_definitions/body_refining/drill/drill_data.gd` (`DrillData`: `id`, `drill_name`, `icon`, `minor_stat: int` (-1, BODY or AGILITY), `strength_xp_per_rep`, `minor_xp_per_rep`, `health_per_rep`, `input: Input` (an enum: HOLD_RELEASE, HOLD_STEADY, CATCH, BEAT), `rep_seconds`, `reps_per_set`), `drill_list.gd` (`DrillList`: `drills: Array[DrillData]`)
- Create: `resources/body_refining/drills/drill_list.tres` and one `<id>/<id>.tres` per approved drill, every value written out
- Test: `tests/unit/test_drill_data.gd`: `test_each_drill_trains_strength_and_at_most_one_physical_minor`, `test_drill_ids_are_unique`, `test_every_value_is_written_out` (each file's text names every field but the icon), `test_the_approved_roster` (a table of the canvas's numbers)

- [x] Steps as Task 1.

### Task 3: DrillRules and DrillSetResult

**Files:**
- Create: `scripts/body_refining/drill_rules.gd` (`DrillRules`, statics: `enum Tier { MISS, OK, GOOD, PERFECT }`, `judge(share) -> Tier`, `factor(tier)`, `xp_for_rep(base_xp, tier)`, `health_multiplier(strength)`, `health_for_rep(drill, tier, strength)`, `perfect_set_xp(drill, stat)`), `scripts/body_refining/drill_set_result.gd` (`DrillSetResult`: `drill`, `add_rep(tier, health)`, `get_rep_count()`, `count_of(tier)`, `get_health_restored()`, `is_complete()`, `is_perfect()`)
- Test: `tests/unit/test_drill_rules.gd`: table tests for the judge's edges, the factors, XP, Health at Strength 10, 15 and 19 (and below 10), and a perfect set's XP for Strength, the minor and an untrained stat; `is_perfect()` for a full PERFECT set, one GOOD rep, and a short set

Paths: `scenes/body_refining/drill/` in the master plan holds the play scenes #100 builds; the rules have no scene, so they sit in `scripts/body_refining/` beside `scripts/tribulation/`.

- [x] Steps as Task 1.

### Task 4: The BodyRefiningManager autoload and pay_rep

**Files:**
- Create: `singletons/body_refining_manager/body_refining_manager.gd`
- Modify: `project.godot` (`BodyRefiningManager` right after `CyclingManager`; committed alone)
- Test: `tests/unit/test_body_refining_manager.gd`: CyclingManager's catalog, unlock, equip, seen and first-pass tests with drill for technique; `test_a_rep_pays_strength_the_minor_and_health`, `test_a_rep_pays_each_stat_once`, `test_a_capped_strength_still_refills_health`, `test_a_rep_pays_xp_at_full_health`, `test_health_per_rep_reads_strength_with_gear`, `test_a_rep_is_recorded_in_the_set_result`, `test_a_miss_pays_nothing`

- [x] Steps as Task 1.

### Task 5: Dev commands, the Player tab and presets

**Files:**
- Modify: `singletons/dev_manager/dev_commands.gd` (`unlock_drill`, `equip_drill`, `unlock_all_drills`, refusing an unknown id, and equip a locked drill), `singletons/dev_manager/dev_manager.gd` (`_mark_everything_seen()` marks unlocked drills seen), `scenes/ui/dev_panel/tabs/player_tab.gd` and `.tscn` (a Drills row beside the techniques: picker, Unlock, Equip, Unlock all)
- Test: `tests/integration/test_dev_commands.gd` (`test_unlock_and_equip_drill`, `test_drill_commands_refuse_an_unknown_id_and_equip_refuses_a_locked_one`, `test_unlock_all_drills_unlocks_every_one`, the dev-line table gains the three), `tests/integration/test_dev_manager_build.gd` (`test_a_built_save_shows_no_new_seals` checks drills), `tests/integration/test_dev_panel.gd` (the Player tab's drill buttons run their commands)

- [x] Steps as Task 1.

### Task 6: Drills open the Tribulation (test only)

**Files:**
- Test: `tests/integration/test_tribulation_flow.gd`: `test_strength_trained_by_drills_opens_the_trial`: Spirit at the cap, the core full, then `BodyRefiningManager.pay_rep()` with PERFECT reps of the starting drill until `CharacterManager.is_stat_capped(STRENGTH)`; `select_action()` then starts the trial.

- [x] **Step 1: Write the test. Step 2: run it: PASS (it pins behaviour Tasks 1 to 4 built).**

### Task 7: Wrap

- [x] The suite passes. The Done-when checks run on `-- --save=user://dev/runs/drills-core.tres`, and on a copy of a pre-chunk save. `git diff main -- project.godot` shows only the autoload.
- [x] The PR closes #97 and ends with `## Docs to update`.

## What was built differently

From the master plan's Phase 5 outline:
- `DrillRules.Tier` gains MISS (approved on the canvas): `{ MISS, OK, GOOD, PERFECT }`.
- `DrillData`'s input is `input_kind: InputKind`, not `input`: a member named `input` would read like the global `Input` singleton. `rep_seconds` and `reps_per_set` join it, and `has_minor_stat()`.
- `DrillRules` and `DrillSetResult` live in `scripts/body_refining/`, beside `scripts/tribulation/`: they have no scene. `scenes/body_refining/drill/` is left for #100's play scenes.
- `DrillSetResult` has no `summary()` or `log_line()`: the result and log lines a set shows are #100's. It records each rep's tier and the Health it restored.
- `pay_rep()` returns the Health it restored, and pays the Health before the XP, at the Strength the rep was played with.
- No `auto_drill_ids`, `unlock_auto()` or `auto_unlocked` (#110), no `ZoneManager._on_drill_unlocked()` (#100 marks the card NEW), and no drill icons (#100 and #106 draw them with the cards).
- The version 4 step moves nothing, so it is a stamp in `_run_version_steps()` with no `_migrate_to_v4()`.
- No preset step unlocks a drill (no `DevStepData.Kind` was added), so `test_dev_manager_build.gd` checks the build's seen pass on a drill unlocked after the build, and that every unlocked drill of a built save is seen.
- `DevCommands.set_health()` and the Player tab's Health row came with #93.
