extends GutTest

## Pins the Tribulation's real data wiring: the shipped Foundation and Copper
## .tres files, not test stand-ins. Foundation leads to Copper, Copper has the
## designed XP curve, Madra and cap, a full Foundation core holds as much Madra
## as an empty Copper one (the breakthrough never costs Madra), and Copper is
## registered in CultivationManager's stages and in the stage list.
##
## A change to one of these numbers is a design change: edit it here too.

const Stage := CultivationManager.AdvancementStage
const FOUNDATION_PATH: String = "res://resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres"
const COPPER_PATH: String = "res://resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres"
const STAGE_LIST_PATH: String = "res://resources/cycling/advancement_stages/advancement_stage_list.tres"

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
	assert_eq(foundation.next_stage.stage_name, "Copper")

func test_the_madra_cap_does_not_drop_at_the_breakthrough() -> void:
	var foundation: AdvancementStageResource = _load_stage(FOUNDATION_PATH)
	var copper: AdvancementStageResource = _load_stage(COPPER_PATH)
	if foundation == null or copper == null:
		return
	assert_eq(foundation.get_max_madra(foundation.max_core_density_level), 600.0, "a full Foundation core holds 600 Madra")
	assert_eq(copper.get_max_madra(0), 600.0, "and an empty Copper core starts at the same 600")

#-----------------------------------------------------------------------------
# COPPER
#-----------------------------------------------------------------------------

func test_copper_values() -> void:
	var copper: AdvancementStageResource = _load_stage(COPPER_PATH)
	if copper == null:
		return
	assert_eq(copper.stage_id, Stage.COPPER)
	assert_eq(copper.stage_name, "Copper")
	assert_eq(copper.core_density_base_xp_cost, 20.0)
	assert_eq(copper.core_xp_scaling_factor, 1.02)
	assert_eq(copper.get_xp_for_level(1), 20.0, "level 1 costs the base XP")
	assert_eq(copper.max_madra_base, 600.0)
	assert_eq(copper.max_madra_per_core_density_level, 10.0)
	assert_eq(copper.max_core_density_level, 100)
	assert_null(copper.next_stage, "Copper is the last stage there is data for")

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
