extends Resource
class_name AdvancementStageResource

@export var stage_name: String
@export var stage_id: CultivationManager.AdvancementStage = CultivationManager.AdvancementStage.FOUNDATION
@export var core_density_base_xp_cost: float = 10.0
@export var core_xp_scaling_factor: float = 1.0
@export var unlocking_mechanics: Array[String] = []
@export var max_madra_base: float = 0.0
@export var max_madra_per_core_density_level: float = 0.0
@export var icon: Texture2D = null
@export var next_stage: AdvancementStageResource = null

func get_xp_for_level(level: int) -> float:
	return core_density_base_xp_cost * pow(core_xp_scaling_factor, level - 1)

func get_max_madra(level: int) -> float:
	return max_madra_base + max_madra_per_core_density_level * level