extends GutTest

## Pins the Tribulation's real data wiring: the shipped .tres files, not test
## stand-ins. Foundation's core fills at 100 and leads to Copper, a full
## Foundation core holds as much Madra as an empty Copper one (the breakthrough
## never costs Madra), Copper is registered in CultivationManager's stages and
## in the stage list, the Foundation Tribulation leads to Copper, its early reach
## and the two lines it fills in, and Spirit Valley lists The Tribulation as an
## action: the action's type and wiring, the "core_density_full" condition that
## reveals it, and that condition's place in the unlock list.
##
## A change to one of these numbers is a design change: edit it here too.

const Stage := CultivationManager.AdvancementStage
const FOUNDATION_PATH: String = "res://resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres"
const COPPER_PATH: String = "res://resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres"
const STAGE_LIST_PATH: String = "res://resources/cycling/advancement_stages/advancement_stage_list.tres"
const FOUNDATION_TRIBULATION_PATH: String = "res://resources/tribulation/foundation_tribulation.tres"
const TRIBULATION_ACTION_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/tribulation_action.tres"
const CORE_DENSITY_FULL_PATH: String = "res://resources/unlocks/core_density_full.tres"
const UNLOCK_LIST_PATH: String = "res://resources/unlocks/unlock_condition_list.tres"
const SPIRIT_VALLEY_PATH: String = "res://resources/zones/spirit_valley_zone/spirit_valley_zone.tres"

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The shipped stage at `path`. Fails the test and returns null when it won't load.
func _load_stage(path: String) -> AdvancementStageResource:
	var stage: AdvancementStageResource = load(path) as AdvancementStageResource
	assert_not_null(stage, "%s loads as an AdvancementStageResource" % path)
	return stage

## The stage of `stage_id` among `stages`, or null when none is listed.
func _find_stage(stages: Array[AdvancementStageResource], stage_id: Stage) -> AdvancementStageResource:
	for stage: AdvancementStageResource in stages:
		if stage.stage_id == stage_id:
			return stage
	return null

## The shipped Foundation Tribulation. Fails the test and returns null when it won't load.
func _load_tribulation() -> TribulationData:
	var tribulation: TribulationData = load(FOUNDATION_TRIBULATION_PATH) as TribulationData
	assert_not_null(tribulation, "%s loads as a TribulationData" % FOUNDATION_TRIBULATION_PATH)
	return tribulation

## The shipped Spirit Valley action. Fails the test and returns null when it won't load.
func _load_action() -> TribulationActionData:
	var action: TribulationActionData = load(TRIBULATION_ACTION_PATH) as TribulationActionData
	assert_not_null(action, "%s loads as a TribulationActionData" % TRIBULATION_ACTION_PATH)
	return action

## The shipped "core_density_full" condition. Fails the test and returns null
## when it won't load.
func _load_condition() -> UnlockConditionData:
	var condition: UnlockConditionData = load(CORE_DENSITY_FULL_PATH) as UnlockConditionData
	assert_not_null(condition, "%s loads as an UnlockConditionData" % CORE_DENSITY_FULL_PATH)
	return condition

#-----------------------------------------------------------------------------
# FOUNDATION TO COPPER
#-----------------------------------------------------------------------------

func test_foundation_leads_to_copper() -> void:
	var foundation: AdvancementStageResource = _load_stage(FOUNDATION_PATH)
	if foundation == null:
		return
	assert_eq(foundation.max_core_density_level, 100, "Foundation's core fills at 100")
	assert_not_null(foundation.next_stage, "Foundation leads to a next stage")
	if foundation.next_stage == null:
		return
	assert_eq(foundation.next_stage.stage_id, Stage.COPPER)

func test_the_madra_cap_does_not_drop_at_the_breakthrough() -> void:
	var foundation: AdvancementStageResource = _load_stage(FOUNDATION_PATH)
	var copper: AdvancementStageResource = _load_stage(COPPER_PATH)
	if foundation == null or copper == null:
		return
	assert_eq(foundation.get_max_madra(foundation.max_core_density_level), 600.0, "a full Foundation core holds 600 Madra")
	assert_eq(copper.get_max_madra(0), 600.0, "and an empty Copper core starts at the same 600")

#-----------------------------------------------------------------------------
# REGISTRATION
#-----------------------------------------------------------------------------

func test_copper_is_registered() -> void:
	var loaded: AdvancementStageResource = _find_stage(CultivationManager.advancement_stage_resources, Stage.COPPER)
	assert_not_null(loaded, "CultivationManager loads a Copper stage")
	if loaded != null:
		assert_eq(loaded.resource_path, COPPER_PATH, "and it is the shipped file")

	var stage_list: AdvancementStageList = load(STAGE_LIST_PATH) as AdvancementStageList
	assert_not_null(stage_list, "the stage list loads")
	if stage_list == null:
		return
	var listed: AdvancementStageResource = _find_stage(stage_list.advancement_stages, Stage.COPPER)
	assert_not_null(listed, "the stage list names a Copper stage")
	if listed != null:
		assert_eq(listed.resource_path, COPPER_PATH, "and it is the shipped file")

#-----------------------------------------------------------------------------
# FOUNDATION TRIBULATION
#-----------------------------------------------------------------------------

func test_targets_copper() -> void:
	var tribulation: TribulationData = _load_tribulation()
	if tribulation == null:
		return
	assert_eq(tribulation.target_stage, Stage.COPPER, "passing the Foundation Tribulation leads to Copper")

## The early reach is early_reach_min, or the good window plus 0.10 s when that
## reaches farther. The shipped numbers stay on the minimum (the good window plus
## 0.10 s is only 0.24 s), so a wider window on a fresh TribulationData takes the
## second branch.
func test_a_wide_good_window_stretches_the_early_reach() -> void:
	var shipped: TribulationData = _load_tribulation()
	if shipped == null:
		return
	var wide: TribulationData = TribulationData.new()
	wide.good_window = 0.25
	var cases: Array[Dictionary] = [
		{"name": "the shipped trial: the 0.30 s minimum, since good + 0.10 s is only 0.24 s", "data": shipped, "reach": 0.30},
		{"name": "a 0.25 s good window reaches 0.10 s further, past the 0.30 s minimum", "data": wide, "reach": 0.35},
	]
	for case: Dictionary in cases:
		assert_almost_eq((case["data"] as TribulationData).get_early_reach(), case["reach"], 0.0001, case["name"])

## The two lines the trial fills in from templates: the rules line with the
## cracks that fail it and the levels a failure costs, and the fail line with the
## Core Density before and after.
func test_copy() -> void:
	var tribulation: TribulationData = _load_tribulation()
	if tribulation == null:
		return
	assert_eq(tribulation.get_rules_line(), "4 cracks end the trial and cost 5 levels of Core Density.")
	assert_eq(tribulation.get_fail_line(100, 95), "Core Density falls from 100 to 95.")

#-----------------------------------------------------------------------------
# THE SPIRIT VALLEY ACTION
#-----------------------------------------------------------------------------

## A saved .tres stores the enum number, so TRIBULATION is appended after
## ZONE_EVENT and never inserted: every number before it keeps its meaning.
func test_tribulation_type_is_seven() -> void:
	assert_eq(ZoneActionData.ActionType.TRIBULATION, 7, "appended after ZONE_EVENT, which is 6")
	assert_eq(ZoneActionData.ActionType.ZONE_EVENT, 6, "and the types before it keep their numbers")

func test_tribulation_action_is_wired() -> void:
	var action: TribulationActionData = _load_action()
	if action == null:
		return
	assert_eq(action.action_id, "spirit_valley_tribulation")
	assert_eq(action.action_type, ZoneActionData.ActionType.TRIBULATION, "the type is the Tribulation's")
	assert_eq(action.max_completions, 0, "a failed trial can be faced again: the card hides by stage, not by a completion count")

	assert_not_null(action.tribulation, "the action leads into a Tribulation")
	if action.tribulation != null:
		assert_eq(action.tribulation.resource_path, FOUNDATION_TRIBULATION_PATH, "the Foundation one")

	assert_eq(action.unlock_conditions.size(), 1, "one condition reveals the card")
	if action.unlock_conditions.size() == 1:
		assert_eq(action.unlock_conditions[0].condition_id, "core_density_full")

func test_core_density_full_condition() -> void:
	var condition: UnlockConditionData = _load_condition()
	if condition == null:
		return
	assert_eq(condition.condition_id, "core_density_full")
	assert_eq(condition.condition_type, UnlockConditionData.ConditionType.CULTIVATION_LEVEL, "it reads Core Density")
	assert_eq(condition.target_value, 100, "a full Foundation core")
	assert_eq(condition.comparison_op, ">=")

## UnlockManager only evaluates the conditions the list names, so a condition
## missing from it would never unlock and the card would never show.
func test_the_condition_is_registered() -> void:
	var list: UnlockConditionList = load(UNLOCK_LIST_PATH) as UnlockConditionList
	assert_not_null(list, "the unlock list loads")
	if list == null:
		return
	var listed: UnlockConditionData = null
	for condition: UnlockConditionData in list.list:
		if condition.condition_id == "core_density_full":
			listed = condition
	assert_not_null(listed, "the unlock list names core_density_full")
	if listed != null:
		assert_eq(listed.resource_path, CORE_DENSITY_FULL_PATH, "and it is the shipped file")

func test_spirit_valley_lists_the_tribulation() -> void:
	var valley: ZoneData = load(SPIRIT_VALLEY_PATH) as ZoneData
	assert_not_null(valley, "Spirit Valley loads")
	if valley == null:
		return
	var listed: ZoneActionData = null
	for action: ZoneActionData in valley.all_actions:
		if action.action_id == "spirit_valley_tribulation":
			listed = action
	assert_not_null(listed, "Spirit Valley lists The Tribulation")
	if listed != null:
		assert_eq(listed.resource_path, TRIBULATION_ACTION_PATH, "and it is the shipped file")
