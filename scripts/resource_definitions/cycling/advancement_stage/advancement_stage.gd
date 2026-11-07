extends Resource
class_name AdvancementStageResource

@export var stage_name: String
@export var stage_id: CultivationManager.AdvancementStage = CultivationManager.AdvancementStage.FOUNDATION
@export var core_density_base_xp_cost: float = 10.0
@export var core_xp_scaling_factor: float = 1.0
## The highest Core Density level of the stage. XP earned there is lost.
@export var max_core_density_level: int = 100
## How many stars Core Density shows as in this stage. Each star is an equal
## share of max_core_density_level: it lights once that share is reached.
@export var core_density_star_count: int = 10
## The highest level each of the six stats can be trained to in this stage.
## Training past it is lost; gear can still lift a total above it.
@export var stat_level_cap: int = 10
@export var unlocking_mechanics: Array[String] = []
@export var icon: Texture2D = null
@export var next_stage: AdvancementStageResource = null
## The latched condition (registered in unlock_condition_list.tres) that puts the
## stage's Breakthrough on the Goals board. Null shows it from the stage's start.
@export var breakthrough_goal_condition: UnlockConditionData = null

## The XP that one level costs: reaching `level` from the level below it, not the
## total from 0. Level 1 costs the base, and each level `core_xp_scaling_factor`
## times the one before.
func get_xp_for_level(level: int) -> float:
	return core_density_base_xp_cost * pow(core_xp_scaling_factor, level - 1)

## The stars Core Density `level` lights in this stage: each star whose whole
## share of max_core_density_level is reached. 0 with no stars or no cap.
func get_stars_lit(level: int) -> int:
	if core_density_star_count <= 0 or max_core_density_level <= 0:
		return 0
	var lit: int = floori(float(clampi(level, 0, max_core_density_level)) * core_density_star_count / max_core_density_level)
	return clampi(lit, 0, core_density_star_count)

## How full star `star` (from 0) is at Core Density `level`, 0 to 1: the part of
## its share of max_core_density_level already reached. 0 for a star past the
## count, and with no stars or no cap.
func get_star_fill(level: int, star: int) -> float:
	if core_density_star_count <= 0 or max_core_density_level <= 0 or star < 0 or star >= core_density_star_count:
		return 0.0
	var stars: float = float(clampi(level, 0, max_core_density_level)) * core_density_star_count / max_core_density_level
	return clampf(stars - star, 0.0, 1.0)

## Every star's fill at Core Density `level`, in order (get_star_fill()): one
## entry per star, so the list is as long as the star count.
func get_star_fills(level: int) -> Array[float]:
	var fills: Array[float] = []
	for star: int in maxi(core_density_star_count, 0):
		fills.append(get_star_fill(level, star))
	return fills
