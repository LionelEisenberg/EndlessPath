extends GutTest

## Unit tests for CultivationManager's public getters on the real Foundation
## stage, which callers read instead of the private stage-resource lookup: the
## XP a level costs, and the condition that puts each stage's Breakthrough on
## the Goals board.

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# BREAKTHROUGH GOAL
#-----------------------------------------------------------------------------

## Foundation's Breakthrough goes on the Goals board at NPC 4, the end of the
## Intervener's chain (Beat 3b). The condition is registered, so it latches.
func test_foundations_breakthrough_goal_waits_for_npc_4() -> void:
	var condition: UnlockConditionData = CultivationManager.get_breakthrough_goal_condition()
	assert_not_null(condition)
	if condition == null:
		return
	assert_eq(condition.condition_id, "celestial_intervener_dialogue_4")
	assert_eq(condition.condition_type, UnlockConditionData.ConditionType.EVENT_TRIGGERED)
	assert_eq(condition.target_value, "celestial_intervener_dialogue_4", "the event NPC 4 fires")
	assert_has(UnlockManager.unlock_condition_list.list, condition, "registered, so it latches")

func test_copper_has_no_breakthrough_goal_condition() -> void:
	PersistenceManager.save_game_data.current_advancement_stage = CultivationManager.AdvancementStage.COPPER
	assert_null(CultivationManager.get_breakthrough_goal_condition())

#-----------------------------------------------------------------------------
# XP PER LEVEL
#-----------------------------------------------------------------------------

## Foundation's level 1 costs 10 XP, and each level 2% more than the last.
func test_xp_for_level_follows_the_stages_curve() -> void:
	assert_almost_eq(CultivationManager.get_xp_for_level(1), 10.0, 0.0001)
	assert_almost_eq(CultivationManager.get_xp_for_level(2), 10.2, 0.0001)
	assert_almost_eq(CultivationManager.get_xp_for_level(11), 10.0 * pow(1.02, 10), 0.0001)
