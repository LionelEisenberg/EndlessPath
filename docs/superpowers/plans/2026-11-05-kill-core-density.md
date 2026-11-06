# Kills Pay Core Density Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A won fight in an adventure pays Core Density XP at the kill, once per fight, kept however the run ends: 20 for a regular fight, 50 for an elite, 120 for the boss. The run shows what each kill paid: icons on the fight's tile, a total in the chest's Run ledger, and beads that fly into a core in the run's cabinet.

**Architecture:** Core Density XP is a reward effect, `AwardCoreDensityXpEffectData`, which each fight's `CombatChoice` carries in its `success_effects` as it carries its loot, and which any other choice can carry. Effects already run once per fight in `AdventureTilemap.handle_combat_result()`'s once-per-fight block, before a boss win ends the run, so the pay inherits both. `AdventureTilemap._apply_effects()` counts what the rewards pay into the run's total, which `AdventureView` hands to the Run ledger and uses to send the beads. `CultivationManager.add_core_density_xp()` writes the live save at once, so nothing a lost, timed-out or retreated run does can take it back.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Spec:** Issue #90 ("Pay Core Density for won fights by tier and show what each paid") and Lionel's answers recorded on it; the spec's Phase 4 (`docs/superpowers/specs/2026-11-04-stats-rework-design.md`); the master plan's Phase 4 outline, Tasks 4.1, 4.2 and 4.7 (`docs/superpowers/plans/2026-11-04-stats-rework.md`); the merge rules in tracking issue #85. The canvas: [A kill pays Core Density](https://claude.ai/artifact/ErsEdR8nboYnJ6FNH3G7bF).

## The canvas's answers

**Settled by Lionel (round 1):**

| Question | Answer |
|---|---|
| How is Core Density paid? | As a reward effect on each fight's choice, as its loot is; any event can grant it too. This replaces the issue's "three amounts on the adventure action" and its tier rule. |
| The three starting amounts | 20, 50 and 120, fine for now. A full clear (7 regular, 4 elite, the boss) pays 460 against today's 3,122 XP from Core Density 0 to 100: about 6.8 full clears. |
| Does an ambush pay? | No part of it: an encounter pays what its choice's effect says. |
| When does the core-full line log? | At once, at the kill that fills the core. No code changes. |
| Where does a kill's amount show? | Gold and Core Density by icons, not words, on the tile's line; the Run ledger's total in layout B (two by two); beads that fly to a core in the run's cabinet and bump it up. No floater. |
| The boss's tile and the end card | Out of scope (#103): the boss's tile stays unresolved as today. |

**Round 2, waiting for Lionel** (Claude's picks): icons at 32 px in the line; the ledger's figures with icons only, no captions; the run's cabinet gains a Core row drawn as the zone cabinet's core block, 96 px taller, the Goals board 96 px lower; the beads burst from the hex the player stands on, brass, one per 4 XP up to 16; a kill at a full core pays nothing (no beads, no icon, no total).

## Global Constraints

- Every `.tres` value is written out: each fight's reward effect writes its `amount`.
- `EffectData.EffectType.AWARD_CORE_DENSITY_XP` is 9, appended (an append-only enum claimed at merge; renumber if another chunk took 9 first).
- `AdventureActionData.experience_multiplier` stays unread.
- The tilemap counts the run's total, never `AdventureView` (which counts a repeated win again). Gold keeps its double count, as today.
- UI nodes live in `.tscn` scenes with theme variants; scripts only set data. No label trims (`tests/integration/test_boards_never_trim_text.gd`). The tile's line uses the `RichTextLacquer` variant.
- No save schema change, so no version step. The PR says so.
- `CultivationManager` is not edited.
- Files outside the issue's Touches are declared on #90 first: `EffectData`, the five Shallow Woods fight files, and (if approved) `VitalsPlate` and `AdventureViewState`. #89 also edits `VitalsPlate`; whichever merges second keeps both.
- No living doc is edited; the PR ends with `## Docs to update`.
- Tests: no shipped amount is pinned. Content tests check rules (every fight pays, an elite more than a regular fight, the boss the most). Tests that pay give their own choices rewards of 7, 9 or 13, below Foundation's level-1 cost of 10, so the XP stays in `core_density_xp` at level 0.

## Review Focus

1. **A win reported twice.** `AdventureCombat` reports a win again on each hit at 0 Health. The fight pays once, the boss's included, and the total counts it once (and sends its beads once). Pinned in Task 2 (tilemap) and its end-flow test (the boss).
2. **The boss's win ends the run synchronously.** The boss pays before `ActionManager.stop_action(true)`: the save holds the XP when `adventure_completed` fires. Pinned by Task 2's end-flow test.
3. **A run that ends badly.** A lost later fight, the timer or a retreat leaves the XP in the save. Pinned in Task 2. Beads still in flight when a run ends land at once (Task 5).
4. **A full core.** A reward pays nothing there and the total doesn't move; after a failed Tribulation drops levels, kills pay again. Pinned in Task 2.
5. **Nothing to pay.** A choice whose effects carry no reward pays nothing; an event's reward pays and counts. Pinned in Task 2.

---

### Task 1: The reward effect and the fights that carry it (built)

**Files:** `scripts/resource_definitions/effects/award_core_density_xp_effect_data.gd` (new), `effect_data.gd`; the five files under `resources/adventure/encounters/shallow_woods/combat_encounters/`; tests `tests/unit/test_award_core_density_xp_effect_data.gd` (new) and `tests/unit/test_fight_rules.gd`.

**Interfaces:** Produces `AwardCoreDensityXpEffectData` (`amount: float`, `process()` pays it through `CultivationManager.add_core_density_xp()`, nothing for 0 or less) and `EffectData.EffectType.AWARD_CORE_DENSITY_XP = 9`.

- [x] Tests: `test_process_pays_its_amount_into_the_core`, `test_process_with_a_non_positive_amount_is_noop`, `test_effect_type_is_award_core_density_xp` (pins 9); `test_every_shallow_woods_fight_pays_core_density_by_its_tier`.
- [x] The effect, the enum value, and the reward on each fight: Amorphous Spirit and Starving Dreadbeast 20, Coalescing Spirit and Ravenous Dreadbeast 50 (beside its loot), Manifested Spirit 120.

### Task 2: The run's total (built)

**Files:** `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`; tests `tests/integration/test_adventure_tilemap_events.gd`, `test_adventure_end_flow.gd`.

**Interfaces:** Produces `AdventureTilemap.get_core_density_xp_earned() -> float` (0 from each `start_adventure_on_map()`, kept after the stop until the next run starts). `_apply_effects(effects) -> float` returns the Core Density its rewards paid (none into a full core) and adds it to the total.

- [x] Tests: `test_a_won_fight_pays_its_core_density_once`, `test_a_choice_without_the_reward_pays_nothing`, `test_any_choice_with_the_reward_pays_it`, `test_core_density_is_kept_when_a_later_fight_is_lost`, `test_a_new_run_starts_its_total_at_zero`, `test_a_kill_at_a_full_core_pays_nothing`, `test_a_boss_win_pays_the_boss_amount`; `test_the_boss_pays_its_core_density_before_the_run_ends`.

### Task 3: Icons on the tile's line (after round 2)

**Files:** `adventure_tilemap.gd`, `expedition_page.tscn` and `.gd`; tests `test_adventure_tilemap_events.gd`, `test_expedition_page.gd`.

**Interfaces:** `static func summary_for(choice: EncounterChoice, gold_earned: int, core_density_xp: float = 0.0) -> String` returns BBCode: a fight reads `Won`, then ` · ` and the gold icon and figure when gold > 0, then ` · ` and the core icon and figure when the XP is above 0; any other choice lists its effects' words as today, then the core icon and figure. The icons are constants on `AdventureTilemap` (`GOLD_ICON`, `CORE_ICON`) at the approved size. `handle_combat_result()` and the other two callers pass what `_apply_effects()` returned. `%LineLabel` becomes a `RichTextLabel` (`RichTextLacquer`, BBCode, fit content, word-smart wrap), and the page's content height is still right without waiting a frame.

- [ ] Tests: `test_summary_for` gains the icon cases (expected strings built from the constants); `test_won_fight_summary` expects the core icon and 7; the page's `test_content_height_is_right_without_waiting_a_frame` and the trim test still pass.

### Task 4: The Run ledger, two by two (after round 2)

**Files:** `expedition_page.tscn` and `.gd`, `adventure_view.gd`; tests `test_expedition_page.gd`, `test_adventure_end_flow.gd`.

**Interfaces:** `ExpeditionPage.set_run_stats(fights: int, fights_total: int, gold: int, explored: int, explored_total: int, loot: Array[ItemDefinitionData], core_density_xp: float = 0.0) -> void`. In the scene: `CoreIcon` (`lacquer_ic_core_ai.png`) and `CoreValue` beside Fights; gold and explored on the second row; the loot row 46 px lower; `RunLedger` 174 tall; captions as approved. `AdventureView._on_run_stats_changed()` passes `adventure_tilemap.get_core_density_xp_earned()`, and `_on_boss_defeated()` announces the run's figures so the ledger counts the boss before the run ends.

- [ ] Tests: `test_run_ledger_values` and `test_a_new_run_clears_the_ledger` read `%CoreValue`; `test_the_ledger_counts_the_boss` (end flow).

### Task 5: The Core row and the beads (after round 2)

**Files:** `scenes/adventure/vitals_plate/vitals_plate.tscn` and `.gd` (the board's art taller, as a new `_ai` file or a nine-patch of today's), `scenes/ui/main_view/states/adventure_view_state.gd` (`GOALS_POSITION` 96 px lower), `adventure_tilemap.gd` (a `core_density_earned(amount: float)` signal), `adventure_view.gd` (an effects layer and the bursts); tests in `test_adventure_view_frame.gd` or a new `test_vitals_plate_core.gd`.

**Interfaces:** `VitalsPlate.hold_core_xp(amount: float)`, `release_core_xp(amount: float)` and `get_core_orb_global_position() -> Vector2`, as `CultivatorPlate` has them; the Core row reads `CultivationManager` and follows `core_density_level_updated` and `core_density_xp_updated`. `AdventureView` hears `core_density_earned`, holds the amount, bursts `bead_count_for(amount)` pellets (`clampi(ceili(amount / 4.0), 1, 16)`) with `PelletFlight.burst()` from the current hex's screen point to the orb, and releases each bead's share as it lands; a run's end releases what is still held.

- [ ] Tests: the row shows the level and XP less what is held; a release shows it; `bead_count_for()` as a table; a won fight sends one burst however often the win is reported; the run's end releases everything held.

### Task 6: Wrap

- [ ] `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1` passes (a parallel failure is confirmed in one process first).
- [ ] The issue's "Done when" checks on the chunk's own save: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn -- --preset=adventure_open --save=user://dev/runs/kill-core-density.tres`, plus an old save copied in, loading and playing.
- [ ] This plan's canvas section holds Lionel's round-2 answers, and a "What was built differently" section any change from it.
- [ ] The PR closes #90 and ends with `## Docs to update` (the issue's list, plus `docs/superpowers/README.md`'s row for this plan in the docs PR).
