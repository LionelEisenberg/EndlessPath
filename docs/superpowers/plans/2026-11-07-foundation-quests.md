# Foundation quests and story (#109) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Foundation chain teaches the new loop: cycle (Madra, Spirit), win a first fight, train the body at the river (Health, Strength), fight to fill two stars of the core, then the Breakthrough on the Goals board.

**Architecture:** Content first: one new quest (`q_temper_body`), one new Intervener talk (`celestial_intervener_dialogue_5`, label `dialogue_5`, played fourth), and new copy and gates on the kept quests and talks, all in `.tres` and the one timeline. One new step criterion, a stat's trained level (`UnlockConditionData.ConditionType.STAT_LEVEL`), with an `UnlockManager` sweep on `CharacterManager.stats_changed`, and one route step kind (`DevStepData.Kind.SET_STAT_LEVEL`) so the dev route can play the new beat.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1, Dialogic 2.0-Alpha-19.

**Spec:** the issue (#109) with the approved canvas's answers ([comment](https://github.com/LionelEisenberg/EndlessPath/issues/109#issuecomment-6703563834), [canvas](https://claude.ai/artifact/2hBwLCjQCkiGc3r21uMVqL)); the design is `docs/superpowers/specs/2026-11-04-stats-rework-design.md`, Phase 6.

**Done before the canvas's approval** (no screen changes): the NPC label test, `tests/unit/test_npc_dialogue_labels.gd` (08eae2e4), and the seven mismatched ext_resource UIDs pointed at their files' headers by hand (a19b9295).

## Approved on the canvas

Lionel approved the "Quests and story" canvas as drawn on 2026-11-07. The full list is on #109.
- **Order:** cycle, first fight, body, core. The woods, foraging and Riverbank Training still open together at NPC 2. The Aura Well beat stays as it is.
- **Temper Your Body**, new: NPC 3 starts it, a new NPC 5 completes it at Strength Lv 2 (a new step criterion, figure "Lv 1 / 2") and pays the Horse Stance manual.
- **Harden Your Core:** two stars (Core Density 20), "Fill two stars of your core", still the map; NPC 4 waits for NPC 5's talk and still puts the Breakthrough on the board.
- **No quest after Harden Your Core** (WR-11 by design: a second row runs the board under the log). One quest at a time.
- **Awaken Your Core** is renamed **Awaken Your Spirit**; "Madra" always, "core" only for Core Density. First Steps Out keeps its path point.
- **UnlockManager sweeps on `stats_changed`** (WR-21's stat half). A route step kind sets a stat's level. New preset `harden_core`; `path_open`'s description adds "Temper Your Body is next."
- **Old saves:** no version step. A save between NPC 3 and NPC 4 meets NPC 5 at Strength Lv 2.

## Global Constraints

- No quest reward refills Madra or Health (`test_home_madra_sources.gd`, `test_home_health_sources.gd` already walk every resource).
- Kept ids stay: `q_fill_core`, `q_first_steps`, `q_reach_core_density_10`, `q_reach_cd_10` (now Core Density 20), every event other content gates on, every beat and preset id.
- Each new talk is `celestial_intervener_dialogue_N` (action, event, registered EVENT_TRIGGERED condition) with label `dialogue_N` in `celestial_intervener_introduction_1.dtl`; `project.godot` does not change.
- Each return NPC gates on its own goal and the talk before it.
- Enums are append-only and claimed at merge: `STAT_LEVEL` is `ConditionType` 8 today, `SET_STAT_LEVEL` is `Kind` 14 today.
- No save version step: no kept quest's steps move.
- New `.tres` files carry no hand-written UID; references to them are path-only, as #88's conditions are. Quest and unlock files are edited by hand.
- Copy is plain, in short sentences; "core" only ever means Core Density; "[INTERVENER]" stays in cards and return steps.
- No living docs in this branch; the PR ends with `## Docs to update`.

## Review Focus

1. **Temper Your Body started at Strength Lv 2 or more** (a player who trained before NPC 3): the quest opens on its return step and NPC 5 shows. Test in Task 4.
2. **Harden Your Core started at two stars** (a player who ran before talking to NPC 5): it opens on its return step and NPC 4 shows only after NPC 5's talk. Test in Task 4.
3. **An old save between NPC 3 and NPC 4** (Harden Your Core on its return step, no `dialogue_5`): it loads on that step, NPC 5 shows at Strength Lv 2, and its talk neither restarts nor skips the quest; then NPC 4 completes it. Test in Task 4.
4. **Gear or a modifier lifts a stat total but not its trained level:** a STAT_LEVEL condition stays unmet, and an ATTRIBUTE_VALUE one latches at once. Tests in Task 1.
5. **Horse Stance already learned from a drop when NPC 5 pays the manual:** the talk still completes the quest and logs "You know Horse Stance already". Test in Task 4.

---

### Task 1: A stat's trained level as a step criterion

**Files:**
- Modify: `scripts/resource_definitions/unlocks/unlock_condition_data.gd`
- Modify: `scripts/resource_definitions/quests/quest_step_data.gd`
- Modify: `singletons/unlock_manager/unlock_manager.gd`
- Test: `tests/unit/test_unlock_condition_progress.gd`, `tests/unit/test_quest_step_progress.gd`, `tests/integration/test_goals_panel.gd`
- Create: `tests/integration/test_stat_unlock_sweep.gd`

**Interfaces:**
- Produces: `ConditionType.STAT_LEVEL` (appended, value 8). Fields: `target_value` the level (int), `optional_params = {"stat": "<stat key>"}` (`strength` to `control`, as `CharacterAttributesData.stat_key()` writes them), `comparison_op` `">="`.
- Produces: `is_measurable()` true for STAT_LEVEL; `get_current_value()` is `CharacterManager.get_stat_level(stat)` (the trained level: gear never counts), 0.0 for an unknown key; `evaluate()` compares it to the target.
- Produces: `QuestStepData.get_progress_text()` reads `"Lv %d / %d"` for a STAT_LEVEL measured condition, `"%d / %d"` for every other.
- Produces: UnlockManager sweeps on `CharacterManager.stats_changed` (each level change, gear change, modifier source and save reset).

- [ ] **Step 1: Failing tests.**
  - `test_unlock_condition_progress.gd::test_measurable_conditions_read_current_and_target`: a row `{"name": "Strength level", "condition": <STAT_LEVEL strength >= 3>, "current": 2.0, "target": 3.0}` after `CharacterManager.set_stat_level(STRENGTH, 2)`.
  - same file, `test_a_stat_level_condition_ignores_gear`: Strength trained to Lv 2, a modifier source adding +5 flat Strength (`CharacterManager.set_modifier_source(&"test_strength", ...)`, removed after), the condition `strength >= 3` stays false and reads 2.0.
  - `test_quest_step_progress.gd::test_a_stat_step_reads_its_level`: a step on `strength >= 2` at Lv 1 reads `"Lv 1 / 2"`, finished `"Lv 2 / 2"`.
  - `test_stat_unlock_sweep.gd` (fresh save via `PersistenceManager.use_save`, the unlock list swapped for a test list and put back):
    - `test_a_level_up_latches_a_stat_level_condition`: `strength >= 2` registered; `CharacterManager.add_stat_xp(STRENGTH, 100.0)` (Lv 1 costs 100) latches it at once.
    - `test_a_gear_change_latches_an_attribute_condition` (WR-21's stat half): an ATTRIBUTE_VALUE `strength >= <trained value + 1>` registered; adding a modifier source that raises Strength latches it at once.
  - `test_goals_panel.gd::test_a_stat_step_figure_follows_the_stat`: `_use_single_quest("Temper", "Train Strength", [strength >= 3])`, the figure reads `"Lv 1 / 3"`, then `"Lv 2 / 3"` after `CharacterManager.set_stat_level(STRENGTH, 2)`.
- [ ] **Step 2: Run them; they fail** (no `STAT_LEVEL`).
  `& "C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= "-gtest=<files>" -gexit`
- [ ] **Step 3: Implement** the three files as the Interfaces block says. UnlockManager connects `CharacterManager.stats_changed.connect(_evaluate_all_conditions)` in `_connect_unlock_signals()`, beside the other managers, with the same missing-manager log.
- [ ] **Step 4: Run them; they pass.** Also `test_unlock_manager.gd`, `test_quest_manager.gd`.
- [ ] **Step 5: Commit** `feat(quests): let a quest step wait for a stat's level`.

### Task 2: A route step that sets a stat's level

**Files:**
- Modify: `scripts/resource_definitions/dev/dev_step_data.gd`
- Test: `tests/unit/test_dev_preset_data.gd`, `tests/integration/test_story_route.gd`

**Interfaces:**
- Produces: `DevStepData.Kind.SET_STAT_LEVEL` (appended, 14): `target_id` a stat key, `amount` the level. `apply()` calls `DevCommands.set_stat_level(StringName(target_id), _whole_amount())`; `describe()` is `"Set %s to Lv %d"`; `validate()` flags an unknown key ("unknown stat") and a level below 1 ("the level must be at least 1").

- [ ] **Step 1: Failing tests.** `test_kind_numbers_never_change` gains `"SET_STAT_LEVEL": 14`; `test_a_good_step_validates` gains `_step(Kind.SET_STAT_LEVEL, "strength", 2.0)`; `test_validate_catches_each_bad_step` gains `("willpower", 2.0)` → "unknown stat" and `("strength", 0.0)` → "level". `test_story_route.gd::_assert_took_effect` gains the arm: the stat's `CharacterManager.get_stat_level()` equals `int(step.amount)`.
- [ ] **Step 2: Run; they fail.**
- [ ] **Step 3: Implement** the kind and its three arms, and its line in the kind comment.
- [ ] **Step 4: Run; they pass.**
- [ ] **Step 5: Commit** `feat(dev): add a route step that sets a stat's level`.

### Task 3: The Intervener's lines

**Files:**
- Modify: `assets/dialogue/timelines/celestial_intervener_introduction_1.dtl`
- Test: `tests/unit/test_npc_dialogue_labels.gd` (exists)

Copy, exactly (each label keeps `join celestial_intervener center`, its lines, `leave celestial_intervener`, `[end_timeline]`):
- `dialogue_1`, line 2: `Anywho, your [color=blue]Madra[/color] is running a little dry. We're safe here, so sit and cycle: it fills your Madra and trains your Spirit. Come back when you're all plumped up!` (line 1 unchanged)
- `dialogue_2`: unchanged.
- `dialogue_3`: `You made it back! Took a few hits out there, huh? Here at home, your wounds won't close on their own.` / `Head down to the river and train your body. Every rep patches you up and builds your Strength. Come find me once you're a little stronger.` / `Oh, and that win earned you a path point. Spend it on your Path!`
- `dialogue_4`: `Two stars already! Your core's coming along nicely.` / `I have to go soon, so listen. Fill all ten stars, and train Strength and Spirit as far as this stage allows. Then the heavens will test you: the Tribulation.` / then today's map line, unchanged.
- `dialogue_5` (new, appended after `dialogue_4`): `Look at those arms! That's how you grow here: cycling trains your Spirit, and the river trains your Strength.` / `Your core's another story: it only deepens in a fight. Every enemy you beat fills it a little, and every star you fill earns a path point.` / `Take this manual too. It teaches Horse Stance, another drill for the river. Now go fill two stars of your core!`

- [ ] **Step 1: Edit the timeline.** Wording is checked by eye, not by tests.
- [ ] **Step 2: Run `test_npc_dialogue_labels.gd`; it passes** (no action names `dialogue_5` yet).
- [ ] **Step 3: Commit** `feat(dialogue): rewrite the Intervener's false lines and add dialogue_5`.

### Task 4: The new chain and its route

**Files:**
- Create: `resources/quests/q_temper_body.tres`, `resources/unlocks/q_temper_body_strength.tres`, `resources/unlocks/celestial_intervener_dialogue_5.tres`, `resources/zones/spirit_valley_zone/zone_actions/celestial_intervener_dialogue_5.tres`
- Modify: `resources/quests/q_fill_core.tres`, `q_reach_core_density_10.tres`, `quest_list.tres`; `resources/unlocks/q_reach_cd_10.tres`, `unlock_condition_list.tres`; `resources/zones/spirit_valley_zone/zone_actions/celestial_intervener_dialogue_2.tres`, `_3.tres`, `_4.tres`; `resources/zones/spirit_valley_zone/spirit_valley_zone.tres`; `resources/dev/story_route.tres`
- Test: `tests/integration/test_foundation_quest_chain.gd`, `test_goals_panel.gd`, `test_beat_3b_merchant_unlock.gd`, `test_dev_panel_story_tab.gd`, `test_zone_panel.gd`, `test_dev_manager_build.gd`, `tests/unit/test_unlock_condition_progress.gd`

**Interfaces:**
- Consumes: Task 1's STAT_LEVEL, Task 2's SET_STAT_LEVEL, Task 3's `dialogue_5`.
- Produces: the chain, in play order:

| Talk | Gate | Completes | Starts |
|---|---|---|---|
| NPC 1 | none | | `q_fill_core` "Awaken Your Spirit" |
| NPC 2 | `q_fill_core_madra_full`, talk 1 | `q_fill_core` (opens woods, foraging, river) | `q_first_steps` |
| NPC 3 | `q_first_steps_enemy_defeated`, talk 2 | `q_first_steps` (+1 path point) | `q_temper_body` |
| NPC 5 | `q_temper_body_strength`, talk 3 | `q_temper_body` (Horse Stance manual) | `q_reach_core_density_10` |
| NPC 4 | `q_reach_cd_10` (20), talk 5 | `q_reach_core_density_10` (the map) | nothing |

- Data: `q_temper_body` "Temper Your Body", description "Train your body by the river. It heals you and builds your Strength.", steps `train_strength` "Train Strength at Riverbank Training" on `q_temper_body_strength` (STAT_LEVEL `{"stat": "strength"}` >= 2), `return_to_npc` "Return to the Celestial [INTERVENER]" on `celestial_intervener_dialogue_5`; completion `AwardItemEffectData` with `res://resources/items/drill_manuals/horse_stance_manual.tres`. `q_fill_core` named "Awaken Your Spirit", description "Fill your Madra by cycling, then return to the stranger.". `q_reach_core_density_10` step 0 "Fill two stars of your core", description "Fight to fill your core. Fill two stars, then report back to the Celestial [INTERVENER].". NPC 5: name "Return to the [INTERVENER]", description "Stronger from the river, you return to the [INTERVENER].", label `dialogue_5`, `max_completions` 1, the story icon, effects `TriggerEvent(celestial_intervener_dialogue_5)` then `StartQuest(q_reach_core_density_10)`. NPC 2's description "With your Madra full, talk to the imposing figure."; NPC 4's "Two stars shine in your core. Report back to the [INTERVENER] before they leave.". `quest_list.tres` lists `q_temper_body` after `q_first_steps`; both new conditions registered; NPC 5 joins `all_actions` after NPC 3.
- Route: new `beat_2b` "Temper Your Body" after `beat_2`: `SET_STAT_LEVEL strength 2`, `COMPLETE_ACTION celestial_intervener_dialogue_5`, `reached_when` `celestial_intervener_dialogue_5`; `beat_3b`'s `REACH_CORE_DENSITY` 20.

- [ ] **Step 1: Failing tests.** In `test_foundation_quest_chain.gd`, the chain becomes the table above (`CHAIN: Array[int] = [1, 2, 3, 5, 4]`; NPC 5's own gate `set_stat_level(&"strength", 2)`, NPC 4's `reach_core_density(20)`):
  - `test_no_return_npc_shows_before_the_one_before_it`: over NPCs 2, 3, 5 and 4.
  - `test_temper_your_body_started_at_strength_2_waits_on_npc_5` (Review Focus 1) and `test_harden_your_core_started_at_two_stars_waits_on_npc_4` (2, renamed from the CD 10 test): each quest opens on step 1 and the next NPC shows after the talk.
  - `test_each_npc_completes_one_quest_and_starts_the_next`: the table's last two columns, talk by talk; Madra and Health equal before and after each talk; the path point, Horse Stance (`BodyRefiningManager.is_drill_unlocked("horse_stance")`) and the map arrive at their talks.
  - `test_a_known_horse_stance_still_completes_temper_your_body` (5): unlock the drill first; NPC 5's talk completes the quest, and the log's last line reads "You know Horse Stance already".
  - `test_every_condition_a_step_or_npc_uses_is_registered`: every `completion_conditions` entry of every quest and every `unlock_conditions` entry of every Spirit Valley action is in `UnlockManager.unlock_condition_list`.
  - `test_an_old_save_between_npc_3_and_npc_4_meets_npc_5` (3): a save written with talks 1 to 3 fired and latched, `q_reach_cd_10` latched, Core Density 12, Strength Lv 1, Harden Your Core at step 1 and no `dialogue_5`: it loads on step 1; NPCs 4 and 5 are hidden; at Strength Lv 2 NPC 5 shows; its talk leaves Harden Your Core on step 1; NPC 4 then shows and completes it.
  - The #88 old-save test keeps its point (talk conditions a save never latched latch at load), played through NPC 5.
  - Elsewhere: `test_goals_panel.gd` reads "Awaken Your Spirit" and the core step's two stars (`[3, 0]`, then `[7, 0]`); `test_beat_3b_merchant_unlock.gd` reaches NPC 4 through NPC 5 and Core Density 20; `test_dev_panel_story_tab.gd` reads "Awaken Your Spirit — step ..."; `test_zone_panel.gd::test_count_label` reads "12 here"; `test_dev_manager_build.gd::test_binding_a_snapshot_records_no_first_time` uses Core Density 20; `test_unlock_condition_progress.gd` reads `q_reach_cd_10` at target 20.
- [ ] **Step 2: Run them; they fail.**
- [ ] **Step 3: Write the content and the route** as above.
- [ ] **Step 4: Run them, `test_story_route.gd` and `test_npc_dialogue_labels.gd`; they pass.**
- [ ] **Step 5: Commit** `feat(quests): teach body refining and two stars in the Foundation chain`.

### Task 5: Presets

**Files:**
- Create: `resources/dev/save_presets/harden_core.tres`
- Modify: `resources/dev/save_presets/path_open.tres`
- Test: `tests/integration/test_save_presets.gd`

**Interfaces:**
- Produces: `harden_core`, title "Harden Your Core", description "Strength Lv 2 and Horse Stance learned. Harden Your Core asks for two stars.", `story_through` `beat_2b`. `path_open`'s description becomes "Pure Core Awakening bought; Smooth Flow and Empty Palm equipped. Temper Your Body is next."

- [ ] **Step 1: Failing tests.** `STARTING_PRESETS` gains `"harden_core": {"story_through": "beat_2b"}`; `test_harden_core_has_two_stars_to_fill`: built, Harden Your Core is on step 0, Strength is Lv 2, Horse Stance is learned; `test_path_open_starts_on_temper_your_body`: `q_temper_body` on step 0.
- [ ] **Step 2: Run; they fail.**
- [ ] **Step 3: Write the two presets.**
- [ ] **Step 4: Run; they pass.**
- [ ] **Step 5: Commit** `feat(dev): add the Harden Your Core preset`.

### Task 6: Wrap

- [ ] Full suite: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`; confirm any failure in one process before acting.
- [ ] The issue's Done-when checks, in the game, on `-- --save=user://dev/runs/foundation-quests.tres` from a new game (a scratch driver under the ignored `mockups/`), on the presets, and on an old save copied from a run of `main` before this branch.
- [ ] `git diff project.godot` is empty.
- [ ] PR closing #109, ending with `## Docs to update`.

## What was built differently

(Filled in as the build goes.)
