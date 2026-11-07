class_name CycleResult
extends RefCounted

## CycleResult
## What one cycle came to, which the zone chest's last cycle card shows
## (LastCycleCard), and the log's line that reports it ("Cycle [Madra icon] +80
## [Spirit icon] +30 [Control icon] +21": each part an icon and its figure,
## three spaces apart, the icons as [img] tags the log draws). A stat the cap
## took XP from reads "capped" after its icon. Cycling pays no Core Density. It
## holds the totals and writes the line; the cycle that owns it keeps the totals
## up to date. It also knows whether the cycle was perfect (is_perfect()).

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The log's line: its parts LOG_SEPARATOR apart, each an icon at 16 px
## (LOG_ICON_FORMAT, the Madra's MADRA_ICON_PATH and each stat's own icon) and
## its figure, or CAPPED_TEXT for a stat the cap took XP from.
const LOG_SEPARATOR: String = "   "
const LOG_ICON_FORMAT: String = "[img=16x16]%s[/img]"
const MADRA_ICON_PATH: String = "res://assets/ui/lacquer/lacquer_mini_madra_ai.png"
const CAPPED_TEXT: String = "capped"

#-----------------------------------------------------------------------------
# TOTALS
#-----------------------------------------------------------------------------

## The Madra the cycle added. Madra that did not fit under the cap is not in it.
var madra_added: float = 0.0

## How many zones were scored.
var zones_scored: int = 0

## How many zones the technique has.
var zones_total: int = 0

## How many of the scored zones were PERFECT.
var perfect_count: int = 0

## The share of the cycle the cursor followed the ball, 0 to 1. A slip a grace
## held counts as followed.
var followed_ratio: float = 0.0

## The XP each stat took this cycle, AttributeType to float: what the stat
## gained, which the cap can make less than it was paid.
var stat_xp: Dictionary = {}

## The stats the cap took XP from this cycle: paid at the cap, or by a payment
## that reached it.
var capped_stats: Array[CharacterAttributesData.AttributeType] = []

## Each zone's state as the cycle ended (CyclingZone.State), in the technique's
## order: its stud, or SPENT when the ball left it unscored.
var zone_states: Array[int] = []

## Each seal node's state as the cycle ended (SealNode.State), in the technique's
## order: OPEN when the ball burst through it, SPENT when it fizzled.
var seal_states: Array[int] = []

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Records a payment of `stat`'s XP: `taken` is what the stat took, and
## `capped` whether the cap took the rest.
func record_stat_xp(stat: CharacterAttributesData.AttributeType, taken: float, capped: bool) -> void:
	stat_xp[stat] = get_stat_xp(stat) + taken
	if capped and not capped_stats.has(stat):
		capped_stats.append(stat)

## Returns the XP `stat` took this cycle.
func get_stat_xp(stat: CharacterAttributesData.AttributeType) -> float:
	return stat_xp.get(stat, 0.0)

## Returns whether the cap took XP from `stat` this cycle.
func is_stat_capped(stat: CharacterAttributesData.AttributeType) -> bool:
	return capped_stats.has(stat)

## Returns whether the cycle was perfect, which unlocks its technique's Auto:
## followed for CyclingRules.PERFECT_FOLLOWED_SHARE of it, every zone pressed
## PERFECT and every seal opened. A technique with neither only follows. A full
## pool or a capped stat does not matter: it is how the cycle was played, not
## what it paid.
func is_perfect() -> bool:
	if not CyclingRules.followed_enough(followed_ratio):
		return false
	for state: int in zone_states:
		if state != CyclingZone.State.PERFECT:
			return false
	for state: int in seal_states:
		if state != SealNode.State.OPEN:
			return false
	return true

## Returns the Spiritual stats the cycle paid, in the screens' order
## (StatDisplay.SPIRITUAL): each that took XP rounding to 1 or more, and each
## the cap took XP from.
func get_paid_stats() -> Array[CharacterAttributesData.AttributeType]:
	var paid: Array[CharacterAttributesData.AttributeType] = []
	for stat: CharacterAttributesData.AttributeType in StatDisplay.SPIRITUAL:
		if is_stat_capped(stat) or roundi(get_stat_xp(stat)) >= 1:
			paid.append(stat)
	return paid

## Returns the log's line: "Cycle", the Madra's icon and "+80", then each paid
## stat's icon and "+30", or "capped" when the cap took its XP, the parts
## LOG_SEPARATOR apart.
func log_line() -> String:
	var parts: PackedStringArray = ["Cycle", "%s +%d" % [LOG_ICON_FORMAT % MADRA_ICON_PATH, roundi(madra_added)]]
	for stat: CharacterAttributesData.AttributeType in get_paid_stats():
		var figure: String = CAPPED_TEXT if is_stat_capped(stat) else "+%d" % roundi(get_stat_xp(stat))
		parts.append("%s %s" % [LOG_ICON_FORMAT % StatDisplay.icon_of(stat).resource_path, figure])
	return LOG_SEPARATOR.join(parts)
