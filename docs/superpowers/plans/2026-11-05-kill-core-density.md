# Kills Pay Core Density Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A won fight in an adventure pays Core Density XP by its tier (regular, elite, boss) at the kill, once per fight, kept however the run ends, and the run shows what each kill paid on the fight's tile and as a total in the chest's Run ledger.

**Architecture:** The rule lives on the data: `AdventureActionData` holds the three amounts and answers what a fight pays from the tile's encounter type and the combat choice's boss flag. `AdventureTilemap.handle_combat_result()` pays it in its once-per-fight block, before a boss win ends the run, and keeps the run's total, which `AdventureView` hands to the Run ledger. `CultivationManager.add_core_density_xp()` writes the live save at once, so nothing a lost, timed-out or retreated run does can take it back.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Spec:** Issue #90 ("Pay Core Density for won fights by tier and show what each paid"); the spec's Phase 4 (`docs/superpowers/specs/2026-11-04-stats-rework-design.md`); the master plan's Phase 4 outline, Tasks 4.1, 4.2 and 4.7 (`docs/superpowers/plans/2026-11-04-stats-rework.md`); the merge rules in tracking issue #85. The canvas: [A kill pays Core Density](https://claude.ai/artifact/ErsEdR8nboYnJ6FNH3G7bF).

## The canvas's answers

Drawn on the canvas with Claude's picks, **waiting for Lionel's approval**. Tasks 1 and 2 change no screen and are built meanwhile; Tasks 3 and 4 wait for it. This section is rewritten with Lionel's answers once he gives them.

| Question | Pick |
|---|---|
| Does an ambush pay? | Yes, the regular amount. |
| When does the core-full line log? | At once, at the kill that fills the core. No code changes. |
| Where does a kill's amount show? | The tile's line ("Won · 15 gold · 20 Core Density XP", the XP alone when the fight drops no gold) and the Run ledger's total on a row of its own under Fights (layout A). The boss's tile resolves just before its win ends the run. No floater. |
| The three starting amounts | Regular 20, elite 50, boss 120. A full clear (7 regular, 4 elite, the boss) pays 460 against today's 3,122 XP from Core Density 0 to 100: about 6.8 full clears. |
| A kill at a full core (added) | Pays nothing: the line names no XP and the total doesn't move. The kill that fills the core counts its whole amount. |

## Global Constraints

- Every `.tres` value is written out. The class defaults of the three amounts are 0, so an adventure action pays nothing unless its file says so, and the Shallow Woods file's 20, 50 and 120 differ from the defaults and survive an editor save.
- The tier comes from `AdventureEncounter.encounter_type` of the tile the player stands on and `CombatChoice.is_boss`, never from `CombatantData` (the boss reuses the regular Amorphous Spirit) or from gold (the elite Coalescing Spirit drops none).
- `AdventureActionData.experience_multiplier` stays unread.
- The tilemap counts the run's total, never `AdventureView` (which counts a repeated win again). Gold keeps its double count, as today.
- Copy: "Core Density XP", as the cabinet's "0 / 10 XP" and the cycling card's "Madra and Core Density XP" say it.
- UI nodes live in `.tscn` scenes with theme variants; scripts only set data. No label trims (`tests/integration/test_boards_never_trim_text.gd`).
- No save schema change, so no version step. The PR says so.
- `CultivationManager` is not edited (the core-full line logs at once). If Lionel picks the run's end instead, that change waits for #86's merge rules (`CultivationManager`, different functions).
- No living doc is edited; the PR ends with `## Docs to update`.
- Tests: no shipped tuning is pinned. Tests that pay run on an action whose amounts they set (`regular 7, elite 9, boss 13`), below Foundation's level-1 cost of 10, so the XP stays in `core_density_xp` at level 0 and no level-up muddies the figures.

## Review Focus

1. **A win reported twice.** `AdventureCombat` reports a win again on each hit at 0 Health. The fight pays once, the boss's included, and the total counts it once. Pinned in Task 2 (tilemap) and Task 2's end-flow test (the boss).
2. **The boss's win ends the run synchronously.** The boss pays before `ActionManager.stop_action(true)`: the save holds the XP when `adventure_completed` fires. Pinned by Task 2's end-flow test.
3. **A run that ends badly.** A lost later fight, the timer or a retreat leaves the XP in the save. Pinned in Task 2 (a lost fight, then the stop).
4. **A full core.** A kill pays nothing there and the total doesn't move; after a failed Tribulation drops levels, kills pay again. Pinned in Task 2.
5. **Nothing to pay.** A rest site, a tile with no encounter (a fight picked on START pays nothing unless it is the boss), and a fight reported once the run is over (`current_adventure_action_data` null) pay nothing. Pinned in Tasks 1 and 2.

---

### Task 1: The kill reward rule

**Files:**
- Modify: `scripts/resource_definitions/zones/zone_action_data/adventure_action_data/adventure_action_data.gd`
- Modify: `resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres`
- Test: `tests/unit/test_fight_rules.gd`

**Interfaces:**
- Produces: `AdventureActionData.core_density_xp_regular: float`, `core_density_xp_elite: float`, `core_density_xp_boss: float` (defaults 0.0, in an `@export_group("Core Density")`), and `func get_core_density_xp_for(encounter_type: AdventureEncounter.EncounterType, is_boss: bool) -> float`.

- [ ] **Step 1: Write the failing test** `test_core_density_reward_by_encounter_type` in `test_fight_rules.gd`, under a new `CORE DENSITY REWARD` section: an action with regular 7, elite 9, boss 13, and a table of `{name, type, is_boss, xp}`:
  - COMBAT_REGULAR, false → 7; COMBAT_AMBUSH, false → 7; COMBAT_ELITE, false → 9; COMBAT_BOSS, false → 13;
  - COMBAT_REGULAR, true → 13 and NONE, true → 13 (the boss flag alone marks the boss);
  - REST_SITE, TRAP, TREASURE and NONE, false → 0.
  Plus `test_an_action_pays_nothing_unless_its_file_says_so`: `AdventureActionData.new()` answers 0 for regular, elite and boss.
- [ ] **Step 2: Run it to make sure it fails**: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_fight_rules.gd -gexit`. Expected: a parse error on the missing function.
- [ ] **Step 3: Implement** the three fields and `get_core_density_xp_for()` with a `##` doc (the boss amount for `is_boss` or COMBAT_BOSS, the elite one for COMBAT_ELITE, the regular one for COMBAT_REGULAR and COMBAT_AMBUSH, else 0). Write `core_density_xp_regular = 20.0`, `core_density_xp_elite = 50.0` and `core_density_xp_boss = 120.0` into the Shallow Woods action.
- [ ] **Step 4: Run the test**. Expected: PASS.
- [ ] **Step 5: Commit** `feat(adventure): add the kill reward rule for Core Density`.

### Task 2: Pay at the kill, and the run's total

**Files:**
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`
- Test: `tests/integration/test_adventure_tilemap_events.gd`, `tests/integration/test_adventure_end_flow.gd`

**Interfaces:**
- Consumes: Task 1's `get_core_density_xp_for()`.
- Produces: `AdventureTilemap.get_core_density_xp_earned() -> float` (the run's total, 0 from each `start_adventure_on_map()`, kept after the stop until the next run starts), and a private `_pay_core_density(choice: CombatChoice) -> float` returning what it paid, which Task 3's summary reads.

- [ ] **Step 1: Write the failing tests** in `test_adventure_tilemap_events.gd`, under a new `CORE DENSITY` section, each starting the run with `_start_paying()`: a duplicate of the fixture action with regular 7, elite 9, boss 13.
  - `test_a_won_fight_pays_its_core_density_once`: walk to FIGHT, pick it, `handle_combat_result(true, 15)` twice → `CultivationManager.get_core_density_xp() == 7.0`, level 0, `get_core_density_xp_earned() == 7.0`.
  - `test_only_fights_pay_core_density`: resolve REST's choice, and win a fight picked on START (a NoOp tile) → XP 0, total 0.
  - `test_core_density_is_kept_when_a_later_fight_is_lost`: win FIGHT, walk to BOSS, pick it, `handle_combat_result(false)`, then `stop_adventure()` → XP 7, total 7.
  - `test_a_new_run_starts_its_total_at_zero`: win FIGHT, stop, start again → total 0, the save's XP still 7.
  - `test_a_kill_at_a_full_core_pays_nothing`: the save's `core_density_level` at the stage's cap (`CultivationManager.get_core_density_cap()`), win FIGHT → total 0; then `CultivationManager.lose_core_density_levels(5)`, start again, win FIGHT → XP 7, total 7.
  - `test_a_boss_win_pays_the_boss_amount`: win FIGHT, walk to BOSS, pick it, win twice → XP 7 + 13 = 20 (level 1: 10 XP paid it, 10 left), total 20.
  In `test_adventure_end_flow.gd`: `test_the_boss_pays_its_core_density_before_the_run_ends`: `_start_adventure(300)` on an action with boss 13; a handler on `adventure_completed` records `CultivationManager.get_core_density_xp()`; the boss win reported twice → the recorded XP is 13, the save's XP stays 13, and `adventure_tilemap.get_core_density_xp_earned() == 13.0`. The action is set on `_start_adventure()`'s duplicate through a new optional `Callable` or a sibling helper `_start_adventure_paying(boss_xp)`.
- [ ] **Step 2: Run both files** and see the new tests fail (`get_core_density_xp_earned` missing).
- [ ] **Step 3: Implement** in `adventure_tilemap.gd`: `var _core_density_xp_earned: float = 0.0`, reset in `start_adventure_on_map()`; `_pay_core_density(choice)` pays `current_adventure_action_data.get_core_density_xp_for(type, choice.is_boss)` where `type` is the current tile's encounter type (NONE with no encounter), returns 0 without paying when there is no action, the amount is 0 or the core is full (`CultivationManager.is_core_full()`), else calls `CultivationManager.add_core_density_xp()` and adds to the total. Call it in `handle_combat_result()`'s `if _current_combat_choice:` block, right after `count_fight_won()`, before the boss branch. Update the function's `##` doc (a win pays its Core Density once).
- [ ] **Step 4: Run both files**. Expected: PASS, the existing tests too (the fixture action's own amounts are 20, 50, 120 and no existing test reads Core Density).
- [ ] **Step 5: Commit** `feat(adventure): pay Core Density at the kill, once per fight`.

### Task 3: The tile's line and the boss's tile (after approval)

**Files:**
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`
- Test: `tests/integration/test_adventure_tilemap_events.gd`, `tests/integration/test_adventure_end_flow.gd`

**Interfaces:**
- Produces: `static func summary_for(choice: EncounterChoice, gold_earned: int, core_density_xp: float = 0.0) -> String`. The default keeps every other caller as it is.

- [ ] **Step 1: Write the failing tests.** `test_summary_for` gains: a fight with 15 gold and 20 XP → "Won · 15 gold · 20 Core Density XP"; 0 gold and 50 XP → "Won · 50 Core Density XP"; 15 gold and 0 XP → "Won · 15 gold"; a rest choice ignores the XP. `test_won_fight_summary` runs on `_start_paying()` and expects "Won · 15 gold · 7 Core Density XP". `test_a_boss_win_resolves_its_tile_before_the_run_ends`: walk to BOSS, pick, win → `encounter_resolved` once with `[BOSS, "Won · 13 Core Density XP"]` (the fixture boss's choice has no gold here: `handle_combat_result(true, 0)`), and `is_tile_completed(BOSS)`; a repeat emits nothing more. In the end flow, `test_boss_win_ends_the_adventure_once_as_a_victory` still passes (the map is cleared after the stop).
- [ ] **Step 2: Run** and see them fail.
- [ ] **Step 3: Implement.** `summary_for()`'s fight branch joins "Won", "<gold> gold" when gold > 0 and "<xp> Core Density XP" when the XP is above 0 (`%d` of the whole amount), with " · ". `handle_combat_result()` keeps what `_pay_core_density()` returned and passes it to `summary_for()`. The boss branch calls `_complete_current_tile(summary_for(choice, gold_earned, xp))` before `boss_defeated.emit()` (the choice is let go first, as now), so the chest beside the end card reads CLEARED and the ledger refreshes on the tile's redraw before the run ends.
- [ ] **Step 4: Run** both files. Expected: PASS.
- [ ] **Step 5: Commit** `feat(adventure): name a kill's Core Density on its tile`.

### Task 4: The Run ledger's total (after approval)

**Files:**
- Modify: `scenes/adventure/adventure_chest/expedition_page/expedition_page.tscn`, `expedition_page.gd`
- Modify: `scenes/adventure/adventure_view/adventure_view.gd`
- Test: `tests/integration/test_expedition_page.gd`, `tests/integration/test_adventure_end_flow.gd`

**Interfaces:**
- Consumes: Task 2's `get_core_density_xp_earned()`.
- Produces: `ExpeditionPage.set_run_stats(fights: int, fights_total: int, gold: int, explored: int, explored_total: int, loot: Array[ItemDefinitionData], core_density_xp: float = 0.0) -> void`.

- [ ] **Step 1: Write the failing tests.** `test_run_ledger_values` passes 60 and expects `%CoreValue` "60"; `test_a_new_run_clears_the_ledger` expects "0" after a run with 0. In the end flow, `test_the_ledger_counts_the_boss`: the boss win on an action with boss 13 leaves the page's `%CoreValue` at "13" beside the end card.
- [ ] **Step 2: Run** and see them fail.
- [ ] **Step 3: Implement.** In the scene, under `RunLedger`: `CoreIcon` (TextureRect, `lacquer_ic_core_ai.png`, 32×32 at (0, 82)), `CoreValue` (Label, `LabelLacquerName`, at (40, 80), 200 wide, text "0") and `CoreCaption` (Label, `LabelLacquerDetail`, at (40, 100), 200 wide, "Core Density XP"), each unique and ignoring the mouse; `LootCaption` and `LootSocket1`–`6` move down 46 px; `RunLedger`'s minimum height is 174. `set_run_stats()` sets `%CoreValue` to the whole amount, and the class doc's ledger line names it. `AdventureView._on_run_stats_changed()` passes `adventure_tilemap.get_core_density_xp_earned()`; its doc and `run_stats_changed`'s name the total.
- [ ] **Step 4: Run** `test_expedition_page.gd`, `test_adventure_end_flow.gd`, `test_adventure_chest.gd`, `test_boards_never_trim_text.gd`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(adventure): add the run's Core Density to the Run ledger`.

### Task 5: Wrap

- [ ] `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1` passes (a parallel failure is confirmed in one process first).
- [ ] The issue's "Done when" checks on the chunk's own save: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn -- --preset=adventure_open --save=user://dev/runs/kill-core-density.tres`, plus an old save copied in, loading and playing.
- [ ] This plan's canvas section holds Lionel's answers, and a "What was built differently" section any change from it.
- [ ] The PR closes #90 and ends with `## Docs to update` (the issue's list, plus `docs/superpowers/README.md`'s row for this plan in the docs PR).
