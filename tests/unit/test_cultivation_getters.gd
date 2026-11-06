extends GutTest

## Unit tests for CultivationManager's public getters on the real Foundation
## stage, which callers read instead of the private stage-resource lookup: the
## condition that puts each stage's Breakthrough on the Goals board, and a given
## stage's stat level cap.

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
# STAT LEVEL CAP OF A STAGE
#-----------------------------------------------------------------------------

## Each stage's own cap, read from its resource whatever stage the save is in,
## and 0 for a stage with no resource.
func test_stat_level_cap_of_reads_the_given_stage() -> void:
	PersistenceManager.save_game_data.current_advancement_stage = CultivationManager.AdvancementStage.COPPER
	for stage_resource: AdvancementStageResource in CultivationManager.advancement_stage_resources:
		assert_eq(CultivationManager.get_stat_level_cap_of(stage_resource.stage_id), stage_resource.stat_level_cap, "%s's cap" % stage_resource.stage_name)
	assert_eq(CultivationManager.get_stat_level_cap_of(CultivationManager.AdvancementStage.IRON), 0, "Iron has no stage resource")

## The version 2 save step calls it from migrate(), before the managers bind.
func test_stat_level_cap_of_needs_no_bound_save() -> void:
	var bound: SaveGameData = CultivationManager.live_save_data
	CultivationManager.live_save_data = null
	var cap: int = CultivationManager.get_stat_level_cap_of(CultivationManager.AdvancementStage.FOUNDATION)
	CultivationManager.live_save_data = bound
	assert_gt(cap, 0, "Foundation's cap reads with no save bound")
