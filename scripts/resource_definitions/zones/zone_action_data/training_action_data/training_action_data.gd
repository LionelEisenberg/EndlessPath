class_name TrainingActionData
extends ZoneActionData

## TrainingActionData
## Defines a training action with a per-level tick-cost curve and associated effects.

#-----------------------------------------------------------------------------
# EXPORTED PROPERTIES
#-----------------------------------------------------------------------------

## Per-tick timer interval in seconds while this action is selected.
@export var tick_interval_seconds: float = 1.0

## Hand-tuned incremental tick cost for levels 1..N (1-indexed).
## ticks_per_level[0] is the cost for level 1; ticks_per_level[1] is the cost to go from level 1 to 2, etc.
@export var ticks_per_level: Array[int] = [60, 300, 600, 1200]

## For levels beyond ticks_per_level.size(), each subsequent level costs
## the previous level's cost multiplied by this factor.
@export var tail_growth_multiplier: float = 2.0

## Effects fired every tick while active (e.g., madra trickle).
@export var effects_per_tick: Array[EffectData] = []

## Effects fired once each time a new level is crossed (e.g., attribute grant).
@export var effects_on_level: Array[EffectData] = []

func _init() -> void:
	action_type = ZoneActionData.ActionType.TRAIN_STATS

#-----------------------------------------------------------------------------
# PURE FUNCTIONS
#-----------------------------------------------------------------------------

## Incremental tick cost to go from level-1 to `level`. Level 0 = 0. Levels beyond
## ticks_per_level.size() apply tail_growth_multiplier to the last array value.
func get_ticks_required_for_level(level: int) -> int:
	if level <= 0:
		return 0
	if ticks_per_level.is_empty():
		return 0
	var array_size: int = ticks_per_level.size()
	if level <= array_size:
		return ticks_per_level[level - 1]
	var last: float = float(ticks_per_level[array_size - 1])
	var extra_levels: int = level - array_size
	return int(round(last * pow(tail_growth_multiplier, extra_levels)))

## Highest completed level given cumulative accumulated ticks.
func get_current_level(accumulated_ticks: int) -> int:
	if accumulated_ticks <= 0:
		return 0
	var level: int = 0
	var cumulative: int = 0
	while true:
		var next_cost: int = get_ticks_required_for_level(level + 1)
		if next_cost <= 0:
			return level
		if cumulative + next_cost > accumulated_ticks:
			return level
		cumulative += next_cost
		level += 1
	return level

## 0.0-1.0 progress toward the next level. 0.0 at tier boundary, ~1.0 just before next boundary.
func get_progress_within_level(accumulated_ticks: int) -> float:
	var current_level: int = get_current_level(accumulated_ticks)
	var cumulative_to_current: int = 0
	for i in range(1, current_level + 1):
		cumulative_to_current += get_ticks_required_for_level(i)
	var next_cost: int = get_ticks_required_for_level(current_level + 1)
	if next_cost <= 0:
		return 0.0
	var progress_ticks: int = accumulated_ticks - cumulative_to_current
	return clamp(float(progress_ticks) / float(next_cost), 0.0, 1.0)
