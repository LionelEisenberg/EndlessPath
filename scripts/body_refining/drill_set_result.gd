class_name DrillSetResult
extends RefCounted

## One set of a drill as it is played: the tier each rep was judged and the
## Health the reps restored. BodyRefiningManager.pay_rep() records each rep it
## pays here. A set is perfect when every one of its reps is PERFECT, which
## unlocks the drill's Auto (#110).

const Tier = DrillRules.Tier

## The drill the set is of.
var drill: DrillData = null

var _tiers: Array[Tier] = []
var _health_restored: float = 0.0

func _init(set_drill: DrillData = null) -> void:
	drill = set_drill

## Records one rep judged `tier` that restored `health`.
func add_rep(tier: Tier, health: float) -> void:
	_tiers.append(tier)
	_health_restored += health

## How many reps the set has recorded.
func get_rep_count() -> int:
	return _tiers.size()

## How many of the set's reps were judged `tier`.
func count_of(tier: Tier) -> int:
	return _tiers.count(tier)

## The Health the set's reps restored. A rep at full Health restores none.
func get_health_restored() -> float:
	return _health_restored

## True once the set holds the drill's reps_per_set reps.
func is_complete() -> bool:
	return drill != null and get_rep_count() >= drill.reps_per_set

## True when the set is complete and every rep was PERFECT.
func is_perfect() -> bool:
	return is_complete() and count_of(Tier.PERFECT) == get_rep_count()
