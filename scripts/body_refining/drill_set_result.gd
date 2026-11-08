class_name DrillSetResult
extends RefCounted

## One set of a drill as it is played: the tier each rep was judged and the bead
## it lit (get_bead_tiers(): the Last set card's beads), the Health each rep
## restored, the XP its reps stored for the set's end, and the XP each
## stat took once it was paid. BodyRefiningManager.pay_rep() records each rep it
## pays here and stores its XP, and BodyRefiningManager.finish_set() pays what the
## set stored (#143: a set pays its XP when it ends). A set is perfect when every
## one of its reps is PERFECT, which unlocks the drill's Auto (#110).
## It writes the log's line for a finished set ("Set · +48 Strength XP · +32
## Health"): the log board shows one line a message and prints plain text, so
## the line keeps to words. A stat the cap took XP from reads "Strength capped" in
## place of its XP, and a set whose scored reps restored no Health, the pool
## being full, reads "Health full" in place of the Health. A set Auto played
## (is_auto()) opens "Set · Auto" and leaves the other stat out: Auto never pays
## it. The board writes its own line with icons from the same totals.

const Tier = DrillRules.Tier
const AttributeType = CharacterAttributesData.AttributeType

## Joins the parts of the log's line: a space, a middle dot (U+00B7) and a space.
const SEPARATOR: String = " · "
const LOG_WORD: String = "Set"
const AUTO_WORD: String = "Auto"
## A stat's part of the line: its XP, rounded to a whole XP, or that the cap took it.
const STAT_XP_FORMAT: String = "+%d %s XP"
const STAT_CAPPED_FORMAT: String = "%s capped"
## The Health part: what the set restored, rounded to a whole, or that the pool was full.
const HEALTH_FORMAT: String = "+%d Health"
const HEALTH_FULL_TEXT: String = "Health full"
## Where a rep never placed on a bead sorts: after every bead.
const UNPLACED_KEY: int = 1_000_000

## The drill the set is of.
var drill: DrillData = null

var _tiers: Array[Tier] = []
## The bead each rep lit, in the order the reps were judged: -1 for one not placed.
var _beads: Array[int] = []
var _rep_health: Array[float] = []
var _health_restored: float = 0.0
## The XP each stat took, AttributeType to float.
var _stat_xp: Dictionary = {}
## The XP the set's reps stored for each stat and nobody has paid yet,
## AttributeType to float.
var _stored_xp: Dictionary = {}
## The stats the cap took XP from: paid at the cap, or by a rep that reached it.
var _capped_stats: Array[AttributeType] = []

func _init(set_drill: DrillData = null) -> void:
	drill = set_drill

## Records one rep judged `tier` that restored `health`.
func add_rep(tier: Tier, health: float) -> void:
	_tiers.append(tier)
	_beads.append(-1)
	_rep_health.append(health)
	_health_restored += health

## Records that the last rep added lit bead `bead` (from 0). A drill that judges
## out of turn lights its beads out of order.
func place_last_rep(bead: int) -> void:
	if not _beads.is_empty():
		_beads[-1] = bead

## Returns each rep's tier in the order of the beads they lit. Reps never placed
## on a bead keep the order they were judged in, after the placed ones.
func get_bead_tiers() -> Array[Tier]:
	var order: Array[int] = []
	for index: int in _tiers.size():
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool: return _bead_key(a) < _bead_key(b))
	var tiers: Array[Tier] = []
	for index: int in order:
		tiers.append(_tiers[index])
	return tiers

## Stores `xp` of `stat`'s XP that a rep earned, for the set's end to pay.
func store_stat_xp(stat: AttributeType, xp: float) -> void:
	if xp > 0.0:
		_stored_xp[stat] = get_stored_stat_xp(stat) + xp

## The XP of `stat` the set's reps stored and nobody has paid yet.
func get_stored_stat_xp(stat: AttributeType) -> float:
	return _stored_xp.get(stat, 0.0)

## Returns the XP stored for each stat (AttributeType to float), in the order the
## stats were first stored, and forgets it, so it is paid once.
func take_stored_xp() -> Dictionary:
	var stored: Dictionary = _stored_xp
	_stored_xp = {}
	return stored

## Records a payment of `stat`'s XP: `taken` is what the stat took, and `capped`
## whether the cap took the rest.
func record_stat_xp(stat: AttributeType, taken: float, capped: bool) -> void:
	_stat_xp[stat] = get_stat_xp(stat) + taken
	if capped and not _capped_stats.has(stat):
		_capped_stats.append(stat)

## How many reps the set has recorded.
func get_rep_count() -> int:
	return _tiers.size()

## How many of the set's reps were judged `tier`.
func count_of(tier: Tier) -> int:
	return _tiers.count(tier)

## The Health the set's reps restored. A rep at full Health restores none.
func get_health_restored() -> float:
	return _health_restored

## The Health rep `index` (from 0) restored.
func get_rep_health(index: int) -> float:
	return _rep_health[index]

## The XP `stat` took this set.
func get_stat_xp(stat: AttributeType) -> float:
	return _stat_xp.get(stat, 0.0)

## Whether the cap took XP from `stat` this set.
func is_stat_capped(stat: AttributeType) -> bool:
	return _capped_stats.has(stat)

## True when a scored rep was recorded and the set restored no Health: the pool
## was full. A set of misses paid no Health to begin with.
func is_health_full() -> bool:
	return _tiers.any(func(tier: Tier) -> bool: return tier != Tier.MISS) and _health_restored <= 0.0

## True once the set holds the drill's reps_per_set reps.
func is_complete() -> bool:
	return drill != null and get_rep_count() >= drill.reps_per_set

## True when the set is complete and every rep was PERFECT.
func is_perfect() -> bool:
	return is_complete() and count_of(Tier.PERFECT) == get_rep_count()

## True when Auto played the set: it holds an AUTO rep. A set is played by hand or
## by Auto from its first rep to its last, never both.
func is_auto() -> bool:
	return count_of(Tier.AUTO) > 0

## Returns the log's line: "Set · ", "Auto · " for a set Auto played, Strength's
## part, the drill's other stat's part when it has one and the set was played by
## hand, then the Health part.
func log_line() -> String:
	var parts: PackedStringArray = [LOG_WORD]
	if is_auto():
		parts.append(AUTO_WORD)
	parts.append(_stat_part(AttributeType.STRENGTH))
	if drill != null and drill.has_minor_stat() and not is_auto():
		parts.append(_stat_part(drill.minor_stat as AttributeType))
	parts.append(HEALTH_FULL_TEXT if is_health_full() else HEALTH_FORMAT % roundi(_health_restored))
	return SEPARATOR.join(parts)

## Where rep `index` sorts among the beads: its bead, or after every bead in the
## order it was judged.
func _bead_key(index: int) -> int:
	return _beads[index] if _beads[index] >= 0 else UNPLACED_KEY + index

func _stat_part(stat: AttributeType) -> String:
	if is_stat_capped(stat):
		return STAT_CAPPED_FORMAT % StatDisplay.name_of(stat)
	return STAT_XP_FORMAT % [roundi(get_stat_xp(stat)), StatDisplay.name_of(stat)]
