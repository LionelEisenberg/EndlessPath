# Foundation Beat 2 (First Steps Out) — Design

**Reference spec:** [`docs/progression/FOUNDATION_PLAYTHROUGH.md`](../../progression/FOUNDATION_PLAYTHROUGH.md) § Beat 2 — First Steps Out
**Authoring conventions:** [`docs/progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md`](../../progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md)
**Related prior work:** Foundation Beat 1 (PR #28), Path Progression PR #20, Ability system redesign PR #22.

## Goal

Wire the second playable beat. Player completes Beat 1, immediately starts `q_first_steps`, enters adventure, defeats an enemy, returns to the Wandering Spirit, receives their first Path Point. Player spends it on the Pure Core Awakening keystone (the only purchasable node at this point), which unlocks the Smooth Flow cycling technique and Empty Palm ability. Badges on the Cycling and Abilities nav buttons signal "something to equip"; player visits each view and equips manually. Quest `q_reach_core_density_10` starts, pointing toward Beat 3.

## Player experience target

~3-6 real minutes of committed play (matches the pacing target in `FOUNDATION_PLAYTHROUGH.md` § 2.4).

The first adventure is beatable but costly: the player loses ~50% of their HP to win one combat. Reinforces that adventures are a resource investment, not free exploration.

## Architecture

### Quest chain

```
q_fill_core (Beat 1, existing)
  └─ completion_effects NOW ALSO:
     └─ inline StartQuestEffect → "q_first_steps"

q_first_steps (NEW)
  ├─ description: "Venture into the wilderness and test your strength."
  ├─ Step 1: "Defeat an enemy in combat"
  │    completion_event_id = "q_first_steps_enemy_defeated"
  ├─ Step 2: "Return to the Wandering Spirit"
  │    completion_event_id = "wandering_spirit_dialogue_3"
  └─ completion_effects:
     ├─ inline AwardPathPointEffect(1)
     └─ inline StartQuestEffect → "q_reach_core_density_10"

q_reach_core_density_10 (NEW, stub for Beat 3)
  ├─ description: "Deepen your cultivation. Raise your Core Density to level 10."
  ├─ Step 1: "Reach Core Density level 10"
  │    completion_conditions = [q_reach_cd_10 condition (CULTIVATION_LEVEL ≥ 10)]
  └─ completion_effects: (empty — Beat 3 adds the reward)
```

### Quest start trigger

`q_first_steps` is not triggered by "adventure entry" at runtime — it starts as a completion effect of `q_fill_core`. Since Beat 1 ends with the player talking to NPC 2 (which completes `q_fill_core`), `q_first_steps` is already active before the player enters Adventure for the first time. Simpler than wiring a new "on adventure entry" signal, and functionally identical to the FOUNDATION_PLAYTHROUGH.md spec from the player's perspective.

### Combat → event bridge

The existing `AdventureCombat.trigger_combat_end(is_successful: bool, gold_earned: int)` signal fires at the end of every combat. We hook this to fire an EventManager event when `is_successful == true`:

```gdscript
# In AdventureCombat or an equivalent listener
func _on_combat_ended(is_successful: bool, _gold: int) -> void:
    if is_successful:
        EventManager.trigger_event("q_first_steps_enemy_defeated")
```

Implementation choice — **hook inside `AdventureCombat`** where the signal is emitted rather than a separate bridge node. Minimal indirection; the combat scene is the natural owner of "combat ended in victory."

EventManager dedups — subsequent victories don't re-fire. Persistent via save data.

### NPC 3 — wandering_spirit_dialogue_3

New `NpcDialogueActionData` zone action in Spirit Valley:

```
action_id = "wandering_spirit_dialogue_3"
action_name = "Return to the Wisened Dirt Eel"  # matches NPC 1/2 placeholder
description = "Report back to the stranger with news of your first victory."
dialogue_timeline_name = "wandering_spirit_3"
action_type = 2 (NPC_DIALOGUE)
max_completions = 1
unlock_conditions = [q_first_steps_enemy_defeated condition]
success_effects = [
    inline TriggerEventEffect(event_id = "wandering_spirit_dialogue_3")
]
```

New Dialogic timeline `assets/dialogue/timelines/wandering_spirit_3.dtl` — minimal placeholder flavor copy mirroring `wandering_spirit_1.dtl` / `wandering_spirit_2.dtl` syntax.

### Award Path Point effect

New `EffectData` subclass `AwardPathPointEffectData` — mirrors the existing `StartQuestEffectData` shape.

```gdscript
class_name AwardPathPointEffectData
extends EffectData

@export var amount: int = 1

func _init() -> void:
    effect_type = EffectType.AWARD_PATH_POINT

func process() -> void:
    if PathManager == null:
        Log.error("AwardPathPointEffectData: PathManager not available")
        return
    PathManager.add_points(amount)
```

`EffectData.EffectType` enum gets one new value: `AWARD_PATH_POINT = 6` (appended after `START_QUEST = 5`).

No new `.tres` file for the effect — authored inline as a sub-resource in `q_first_steps.completion_effects`.

### Unlock conditions

Two new `UnlockConditionData` resources, both registered in `unlock_condition_list.tres`:

| Condition id | Type | Target / params | Gated by |
|---|---|---|---|
| `q_first_steps_enemy_defeated` | EVENT_TRIGGERED (4) | target_value = `"q_first_steps_enemy_defeated"` | NPC 3 `unlock_conditions` |
| `q_reach_cd_10` | CULTIVATION_LEVEL (1) | target_value = `10`, comparison_op = `">="` | `q_reach_core_density_10` step 1 `completion_conditions` |

Per conventions doc: the NPC 3 gate uses a wrapping EVENT_TRIGGERED condition because a zone action gates on the moment. The quest step for CD 10 uses a state-predicate condition directly (no event needed — cultivation level isn't a "moment").

### Badges on system menu nav buttons

Two new methods:

- `CyclingManager.has_unequipped_unlocks() -> bool` — returns true if any unlocked technique is not currently equipped.
- `AbilityManager.has_unequipped_unlocks() -> bool` — returns true if any unlocked ability is not in any equipped slot.

Both are derived state — no new save fields. They compute from the already-persisted `unlocked_*_ids` and `equipped_*_id(s)` fields.

`SystemMenuButton` scene gets a small badge Node (a colored Control dot, anchored to the top-right corner of the button) with visibility driven by the manager state. Listens to `CyclingManager.technique_unlocked` / `equipped_technique_changed` and `AbilityManager.ability_unlocked` / `equipped_abilities_changed` to refresh visibility.

Logic:

- Cycling nav button's badge visible when `CyclingManager.has_unequipped_unlocks() == true`.
- Abilities nav button's badge visible when `AbilityManager.has_unequipped_unlocks() == true`.
- No save-data tracking; badge derives from current state each time a relevant signal fires.
- When the player equips the technique/ability, the signal re-fires, predicate evaluates false, badge disappears.

Visual style: deferred to implementation time — start with a simple small colored dot; can be refined via playtest feedback.

### Enemy tuning

Retune the existing encounter on the first-adventure tile to target the "50% player HP cost" feel:

- Starting point: reduce enemy HP so player can defeat it in 3-5 ability uses with bare-hands.
- Tune enemy damage so the combat costs the player ~50% HP over its duration.
- Exact numbers settled at implementation time; baseline goes in the plan's Section 2 economy tables.

No new encounter/enemy data — just value changes on existing resources.

## New files

| File | Purpose |
|---|---|
| `scripts/resource_definitions/effects/award_path_point_effect_data.gd` | New `EffectData` subclass |
| `resources/quests/q_first_steps.tres` | Two-step quest data |
| `resources/quests/q_reach_core_density_10.tres` | Single-step quest data |
| `resources/unlocks/q_first_steps_enemy_defeated.tres` | EVENT_TRIGGERED condition |
| `resources/unlocks/q_reach_cd_10.tres` | CULTIVATION_LEVEL ≥ 10 condition |
| `resources/zones/spirit_valley_zone/zone_actions/wandering_spirit_dialogue_3.tres` | NPC 3 zone action |
| `assets/dialogue/timelines/wandering_spirit_3.dtl` | NPC 3 Dialogic timeline |
| `scenes/zones/system_menu/system_menu_button_badge.tscn` *(or inline)* | Badge visual |
| `tests/unit/test_award_path_point_effect_data.gd` | Unit tests for new effect |

## Modified files

| File | Change |
|---|---|
| `scripts/resource_definitions/effects/effect_data.gd` | Add `AWARD_PATH_POINT = 6` to the `EffectType` enum |
| `resources/quests/q_fill_core.tres` | Add inline `StartQuestEffect("q_first_steps")` to `completion_effects` |
| `resources/quests/quest_list.tres` | Register `q_first_steps` and `q_reach_core_density_10` |
| `resources/unlocks/unlock_condition_list.tres` | Register the two new conditions |
| `resources/zones/spirit_valley_zone/spirit_valley_zone.tres` | Add `wandering_spirit_dialogue_3` to `all_actions` |
| `project.godot` | Add `wandering_spirit_3` to Dialogic's `dtl_directory` map |
| `scenes/combat/adventure_combat/adventure_combat.gd` | Fire `q_first_steps_enemy_defeated` event on combat victory |
| `singletons/cycling_manager/cycling_manager.gd` | Add `has_unequipped_unlocks()` public method |
| `singletons/ability_manager/ability_manager.gd` | Add `has_unequipped_unlocks()` public method |
| `scenes/zones/system_menu/system_menu_button.gd` + `.tscn` | Add badge node and visibility logic |
| Existing encounter / enemy data | Retune HP + damage for the first-adventure fight |
| `docs/progression/FOUNDATION_PLAYTHROUGH.md` | Update Beat 2 entry to reflect deviations: no tutorial, manual equip, `q_reach_core_density_10` starts on `q_first_steps` completion |

## Runtime flow (Beat 1 end → Beat 2 end)

1. Player completes Beat 1 by talking to NPC 2. `q_fill_core` completes.
2. Completion effects fire: `TriggerEvent("q_fill_core_completed")` + `StartQuest("q_first_steps")`. Adventure + Foraging unlock (existing Beat 1 behavior). `q_first_steps` is now active, on step 1.
3. Player enters Adventure. First encounter contains a combat-tile enemy.
4. Combat starts. Player uses bare-hands ability (existing starter state). Tutorial popup cut per design — combat UI does the teaching.
5. Player wins the combat. `AdventureCombat` fires `trigger_combat_end(true, ...)` AND `EventManager.trigger_event("q_first_steps_enemy_defeated")`.
6. QuestManager advances `q_first_steps` to step 2. UnlockManager's condition-eval pass sees `q_first_steps_enemy_defeated` now true → NPC 3 visible.
7. Player returns to Spirit Valley. NPC 3 "Return to the Wisened Dirt Eel" is now visible.
8. Player clicks NPC 3. Dialogic plays `wandering_spirit_3` timeline. Success effect fires `TriggerEvent("wandering_spirit_dialogue_3")`.
9. QuestManager advances step 2 → quest completes. Completion effects fire: `AwardPathPoint(1)` → `PathManager.add_points(1)`; `StartQuest("q_reach_core_density_10")` → new quest active, step 1 is condition-based (CD ≥ 10, not yet met).
10. Player has 1 path point. Opens Path Tree (existing UI). The only purchasable node is `pure_core_awakening` (prerequisite-free, in the starting tier). Clicks → purchase. PathManager fires `unlock_technique("smooth_flow")` and `unlock_ability("empty_palm")`.
11. `CyclingManager.technique_unlocked` signal fires. SystemMenuButton badge on Cycling refreshes — visible (Smooth Flow unlocked but Foundation still equipped).
12. `AbilityManager.ability_unlocked` signal fires. SystemMenuButton badge on Abilities refreshes — visible.
13. Player opens Cycling view, equips Smooth Flow. `equipped_technique_changed` fires. Badge predicate re-evaluates — now false (only one unlocked technique, now equipped). Badge hidden.
14. Player opens Abilities view, equips Empty Palm to slot 1. Badge hidden.
15. Beat 2 complete. `q_reach_core_density_10` is active, waiting on CD level 10 for Beat 3.

## Out of scope (explicit)

| Item | Reason |
|---|---|
| In-combat tutorial popup | Cut per design. Quest description does light onboarding; combat UI should be self-explanatory. Revisit in a future UX pass if playtest shows confusion. |
| Auto-equip of unlocked content | Player controls when to swap. Badges make the availability visible without forcing it. |
| Badge save-data persistence | Derived state from unlocked/equipped ids. No new save fields. |
| `q_reach_core_density_10` completion effect | Beat 3's problem — this spec just starts the quest so Beat 3 has something to hang off. |
| Keystone auto-purchase | Player spends the path point themselves — path tree is already the UI for this. |
| Dialogue copy polish | `wandering_spirit_3.dtl` is a one-line placeholder. Copy pass is a future editorial task. |
| Further adventure map / encounter variety | Beat 2 only needs the first combat to feel right; map expansion is Beat 3-8 work. |
| Ability loadout rework | Per `PATH_PROGRESSION.md`, how abilities get equipped is a future rework concern. Manual equip uses whatever wiring AbilityManager already exposes. |

## Deviations from FOUNDATION_PLAYTHROUGH.md Beat 2

- **No tutorial popup.** Spec said "In-combat tutorial popup on first combat." We cut it — design decision, documented here and to be reflected back into the playthrough doc.
- **Quest triggered by Beat 1 completion, not "adventure entry."** Spec said `q_first_steps` starts on adventure entry. We wire it as a Beat 1 completion effect for simpler plumbing and identical player experience.
- **`q_reach_core_density_10` starts on `q_first_steps` completion, not keystone purchase.** Spec said on keystone purchase. Starting on quest completion avoids adding a START_QUEST effect type to `PathNodeEffectData`. Functionally equivalent because the player buys the keystone immediately after reaching the path tree (it's the only purchasable node).
- **Manual equip.** Spec implied auto-apply ("replaces bare-hands starter in slot 1"). We defer to manual equip with a badge indicator. Aligns with existing unlock-vs-equip split in CyclingManager and AbilityManager.

`FOUNDATION_PLAYTHROUGH.md` Beat 2 entry will be updated to reflect these deviations as part of the implementation PR.

## Test plan

### Unit tests

- `test_award_path_point_effect_data.gd` — new: `process()` calls `PathManager.add_points(amount)`; handles missing PathManager gracefully.
- `test_quest_manager.gd` (modify) — new test: `q_first_steps` completion fires both `AwardPathPoint` and `StartQuest` effects in order.
- `test_cycling_manager.gd` (modify) — new test: `has_unequipped_unlocks()` returns false when no techniques unlocked, true when unlocked != equipped, false when equipped matches unlocked.
- `test_ability_manager.gd` (modify) — mirror for abilities.

### Integration / manual playtest

- Fresh save. Complete Beat 1 (cycle × N, talk to NPC 2). Verify `q_first_steps` now active.
- Enter Adventure. Win first combat. Verify step 1 advances and NPC 3 becomes visible.
- Return to Spirit Valley. Talk to NPC 3. Verify quest completes, path point awarded (+1 in Path Tree UI), `q_reach_core_density_10` active.
- Open Path Tree, purchase Pure Core Awakening. Verify both Cycling and Abilities nav buttons now show badges.
- Open Cycling view. Verify Smooth Flow is in the unlocked list and the badge clears once Smooth Flow is equipped.
- Open Abilities view. Verify Empty Palm is in the unlocked list and the badge clears once equipped.
- Reload save. Verify badges reflect the current equipped-vs-unlocked state (should be empty if everything was equipped pre-reload).

### Tuning verification

- First adventure's combat: record average HP lost. Target: 40-60%. Retune encounter data if out of range.
- Time from Beat 1 completion to Beat 2 completion: target 3-6 minutes of committed play.

## Open tuning questions

(These become Section 3 entries in the next `FOUNDATION_PLAYTHROUGH.md` update.)

- **First-combat enemy HP / damage.** Starting values: TBD at implementation. Test plan: playtest 5+ combats, record HP% lost, adjust.
- **Badge visual style.** Starting value: small solid-color dot. Test plan: playtest, refine.

## Self-review

**Spec coverage check** against FOUNDATION_PLAYTHROUGH.md Beat 2:

- [x] Quest starts — via Beat 1 completion chain (documented deviation, same net effect)
- [x] First combat in first adventure — existing flow, enemy retuned
- [x] Tutorial popup — explicitly cut, rationale documented
- [x] Quest completes on adventure action — our interpretation: on enemy defeat + NPC return, documented as a deviation (cleaner and more actionable than "any adventure outcome")
- [x] Path point reward — via new `AwardPathPointEffect`
- [x] Keystone effects — player spends path point manually; unlocks propagate via existing wiring
- [x] `q_reach_core_density_10` starts — on quest completion (deviation from "keystone purchase", documented)

**Placeholder check:** no TBDs in task bodies. Tuning numbers intentionally deferred to implementation; playtest is explicit.

**Internal consistency:** effect type numbering matches EffectData enum intent. Quest id / event id / condition id naming follows conventions doc.

**Scope check:** Beat 2 implementation is bounded. One new effect type, three new quest-related resources, one new NPC action, one new condition, small manager additions, one UI badge, one combat-scene line. Matches the "one beat = one PR" cadence from Beat 1.
