extends RefCounted

## A fixed Foundation Core Density curve, for tests whose figures lean on what a
## level costs, so retuning the shipped curve moves none of them (no test pins
## shipped tuning). Level 1 costs 10 XP, each level 2% more than the last.
## Preload it: const CoreCurve := preload("res://tests/helpers/core_curve.gd").

const BASE_XP_COST: float = 10.0
const SCALING: float = 1.02

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Swaps CultivationManager's stages for copies whose Foundation runs on the
## fixed curve, and returns the real stages for restore(). Call it before the
## test's save is loaded, since loading reads the stage.
static func use_fixed_curve() -> Array[AdvancementStageResource]:
	var original: Array[AdvancementStageResource] = CultivationManager.advancement_stage_resources
	var stages: Array[AdvancementStageResource] = []
	for stage: AdvancementStageResource in original:
		var copy := stage.duplicate() as AdvancementStageResource
		if copy.stage_id == CultivationManager.AdvancementStage.FOUNDATION:
			copy.core_density_base_xp_cost = BASE_XP_COST
			copy.core_xp_scaling_factor = SCALING
		stages.append(copy)
	CultivationManager.advancement_stage_resources = stages
	return original

## Puts back the stages use_fixed_curve() returned. Call it before the real save
## is loaded again, so it is read against the real stages.
static func restore(original: Array[AdvancementStageResource]) -> void:
	CultivationManager.advancement_stage_resources = original
