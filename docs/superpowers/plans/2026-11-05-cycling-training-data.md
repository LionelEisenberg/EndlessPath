# Cycling Training Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each cycling technique records what it trains (Spirit XP per cycle and at most one other Spiritual stat), and Spirit raises the Madra every cycle draws. The technique drawers and the Now strip show Madra at the player's current Spirit and follow every stats change (stats rework chunk #91, tracked in #85).

**Architecture:** `CharacterAttributesData.get_cycling_madra_multiplier()` is the multiplier's one home: 1.0 at Spirit 10, plus `CYCLING_MADRA_PER_SPIRIT` for each point above, read from the player's total Spirit (`CharacterManager.get_total_attributes_data()`), so Spirit gear counts. `CyclingTechniqueData` gains `spirit_xp_per_cycle`, `minor_stat` (an `AttributeType` or -1) and `get_madra_per_cycle(madra_multiplier)`; `get_madra_per_second()` takes the same parameter. `CyclingTechnique` caches the multiplier, re-read on `CharacterManager.stats_changed`, and its Madra step draws at it. `TechniqueDrawer.detail_text()` takes the multiplier; `TechniqueList` and `NowStrip` hear `stats_changed` and refresh. A content test holds the catalog sound.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Design:** the master plan's Phase 3 outline, Tasks 3.1 and 3.2 (`2026-11-04-stats-rework.md`), checked against `main` after #86, and issue #91. The issue's Decided list wins where the two differ:
- The roster is settled on the canvas before the drawers or the strip change; the multiplier and the content check change no screen and ran first.
- The zones' tier XP is rebalanced in #99 with the presses' switch, not here.
- Nothing pays Spirit, Mind or Control XP in this chunk.
- DM-02: the stat curve test's helper and path move under section headers.

**Canvas:** "Cycling roster", https://claude.ai/artifact/MNxJ6biuwxZLCGBH8p5wq7. **Awaiting Lionel's approval.** Proposed, as drawn:
- The roster: all three techniques stay, no id changes. The Foundational Technique trains Spirit only and stays the new save's start; Smooth Flow (Pure Core Awakening) trains Spirit + Control; Torrential Flow (its path node) trains Spirit + Mind.
- Mini-games: timed presses train Control; unbroken following (a streak on the ball) trains Mind. Torrential Flow's one zone goes in #99.
- Combining: each technique combines Spirit with its one other stat; one technique at a time. No equip model change.
- Madra per cycle at Spirit Lv 1: 30, 80, 50 (today 50, 200, 250). +10% per Spirit point above 10: x1.9 at Foundation's cap, 57, 152, 95. A new pool of 100 fills in 4, 2 and 2 followed cycles; 190 at Mind's cap fills in the same counts.
- Spirit XP per fully followed cycle: 12, 30, 16 (1.5, 2 and 2 a second). Lv 1 to 10 takes 215, 86 and 162 cycles: about 29, 22 and 22 minutes of cycling.
- Level costs become whole numbers at the source: Lv 3 to 4 costs 156, not 156.25; Lv 1 to 10 costs 2,579.
- The copy is unchanged: the drawer's "80 Madra · 15 s cycle · 4 zones" and the strip's "+5.3 / s", both at the player's Spirit now.

**Save:** no schema change, no version step, no id move (the roster keeps every id). Whole-number costs change no saved value's meaning: nothing in play pays stat XP before this chunk, and the dev panel keeps XP at least 1 under a level's cost.

## Global Constraints

The master plan's Global Constraints hold. In short: explicit types and return types, `##` docs on public functions, `%UniqueName` nodes, no `print()`, tests call production code with the save swap (`PersistenceManager.save_game_data = SaveGameData.new(); PersistenceManager.save_data_reset.emit()`), no GUT doubles, a test that sets a modifier source removes it, and `.tres` values are written out. One test file: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=<res path> -gexit`. Full suite: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.

---

### Task 1: Spirit's cycling Madra multiplier (no screen)

**Files:**
- Modify: `scripts/resource_definitions/character/character_attributes_data.gd` (`CYCLING_MADRA_PER_SPIRIT`, `get_cycling_madra_multiplier()`), `scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd` (`get_madra_per_cycle()`, the parameter on `get_madra_per_second()`), `scenes/cycling/cycling_technique/cycling_technique.gd` (`_madra_multiplier`, `_on_stats_changed()`, `_madra_per_step()`)
- Test: `tests/unit/test_character_attributes_data.gd` (`test_cycling_madra_multiplier`, the derived-values tables), `tests/unit/test_cycling_technique_data.gd` (`test_madra_per_cycle_at_a_multiplier`, `test_madra_per_second_follows_the_multiplier`), `tests/integration/test_cycling_technique.gd` (`test_spirit_raises_the_madra_a_cycle_draws`, `test_the_rate_reads_madra_at_spirit`)

- [x] **Step 1: Write the failing tests.**
- [x] **Step 2: Run them and see them fail.**
- [x] **Step 3: Implement.**
- [x] **Step 4: Run the task's tests: PASS.**
- [x] **Step 5: Commit:** `feat(cycling): let Spirit raise the Madra a cycle draws`.

### Task 2: Training data and the catalog content check (no screen)

**Files:**
- Modify: `cycling_technique_data.gd` (`spirit_xp_per_cycle: float = 0.0`, `minor_stat: int = -1`), the three technique `.tres` files under `resources/cycling/cycling_techniques/`
- Create: `tests/unit/test_cycling_technique_catalog.gd`

- [x] **Step 1: Write the check:** ids unique and not empty; every path node's `UNLOCK_CYCLING_TECHNIQUE` names a catalog id (and some node does); a new save's default technique ids are in the catalog; every technique pays Spirit XP above 0 and trains -1, MIND or CONTROL beside it; every technique's file writes out both fields.
- [x] **Step 2: Run it and see it fail.**
- [x] **Step 3: Write the canvas's proposed values into the three files.**
- [x] **Step 4: Run it: PASS.**
- [x] **Step 5: Commit:** `feat(cycling): record what each technique trains`.

### Task 3: DM-02 (no screen)

- [x] `tests/unit/test_stat_progression_data.gd`: `SHIPPED_PATH` under a CONSTANTS header and `_curve()` under HELPERS. Commit: `test(stats): put the curve test's path and helper under headers`.

### Task 4: The approved numbers (after the canvas is approved)

**Files:**
- Modify: the three technique `.tres` (`base_madra_per_cycle`, and the training values if the canvas changed them), `scripts/resource_definitions/character/stat_progression_data.gd` (if costs become whole: `get_xp_to_next()` rounds)
- Test: `tests/integration/test_cycling_technique.gd` (`MADRA_STEP`, `MADRA_RATE`, the Foundational 50-a-cycle pins), `tests/unit/test_stat_progression_data.gd` (156.25 becomes 156, a whole-cost table), `tests/integration/test_character_book.gd` (the 156.25 precondition test), and the rest of `git grep -n -e "200.0" -e "50.0" -e "250.0" -- tests` that reads a shipped technique's Madra

- [ ] **Step 1: Update the pins to the approved numbers; run them and see them fail.**
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run the task's tests: PASS.**
- [ ] **Step 4: Commit:** `feat(cycling): set Madra per cycle against the one pool`, and separately `feat(stats): make level costs whole numbers` if approved.

### Task 5: The drawers and the Now strip follow Spirit (after the canvas is approved)

**Files:**
- Modify: `scenes/cycling/technique_drawer/technique_drawer.gd` (`detail_text(data, madra_multiplier)`, `refresh_detail()`), `scenes/zones/zone_panel/technique_list/technique_list.gd` (hears `CharacterManager.stats_changed`, refreshes every drawer's detail), `scenes/zones/zone_panel/now_strip/now_strip.gd` (`_update_technique()` sizes the rate slot at Spirit's multiplier; hears `stats_changed` while cycling)
- Test: `tests/integration/test_technique_drawer.gd` (`test_detail_text` at a multiplier), `tests/integration/test_zone_panel.gd` (`test_drawers_follow_a_spirit_level`, `test_the_rate_slot_follows_a_spirit_level`)

- [ ] **Step 1: Write the failing tests.**
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the task's tests: PASS.**
- [ ] **Step 5: Commit:** `feat(cycling): show Madra per cycle at the player's Spirit`.

### Task 6: Wrap

- [ ] **Step 1:** The full suite: PASS (a parallel-run failure is confirmed in one process first).
- [ ] **Step 2:** The issue's Done-when checks on `-- --save=user://dev/runs/cycling-training-data.tres`, plus a copy of an old save, and the `path_open` preset builds.
- [ ] **Step 3:** Record the approved canvas answers here and on #91; open the PR that closes #91, ending with `## Docs to update`, with the cycles and minutes the Spirit cap takes for #96 and #111.
