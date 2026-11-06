class_name CycleResult
extends RefCounted

## CycleResult
## What one cycle came to, and the lines that report it: the zone chest's line
## under the Now tray ("Last cycle · +80 Madra · +30 Spirit XP · +21 Control XP ·
## 3 / 4 zones · 1 PERFECT") and the log ("Cycle · +80 Madra · +30 Spirit XP ·
## +21 Control XP"). The log board shows one line a message and trims what runs
## past it, so the log's line keeps what the cycle paid and leaves the zones and
## PERFECTs to the chest, whose line wraps. A stat the cap took XP from reads
## "Spirit capped" in place of its XP. Cycling pays no Core Density. It holds the
## totals and writes the lines; the cycle that owns it keeps the totals up to date.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Joins the parts of a line: a space, a middle dot (U+00B7) and a space.
const SEPARATOR: String = " · "

## A stat's part of the lines: its XP, rounded to a whole XP, or that the cap
## took it.
const STAT_XP_FORMAT: String = "+%d %s XP"
const STAT_CAPPED_FORMAT: String = "%s capped"

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

## The share of the cycle the cursor followed the ball, 0 to 1.
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

## Returns the cycle in one phrase: the Madra, then each stat's part, then the
## zones ("3 / 4 zones", "1 / 1 zone", or "no zones" for a technique without
## any), then the PERFECT count if there were any. The parts are joined by
## SEPARATOR.
func summary() -> String:
	var parts: PackedStringArray = [_madra_part()]
	parts.append_array(_stat_parts())
	if zones_total == 0:
		parts.append("no zones")
	else:
		var noun: String = "zone" if zones_total == 1 else "zones"
		parts.append("%d / %d %s" % [zones_scored, zones_total, noun])
	if perfect_count > 0:
		parts.append("%d PERFECT" % perfect_count)
	return SEPARATOR.join(parts)

## Returns the chest's line under the Now tray: "Last cycle · " and the summary.
func result_line() -> String:
	return "Last cycle" + SEPARATOR + summary()

## Returns the log's line, short enough for the log board's one line: "Cycle · ",
## the Madra and each stat's part.
func log_line() -> String:
	var parts: PackedStringArray = ["Cycle", _madra_part()]
	parts.append_array(_stat_parts())
	return SEPARATOR.join(parts)

#-----------------------------------------------------------------------------
# PARTS
#-----------------------------------------------------------------------------

func _madra_part() -> String:
	return "+%d Madra" % roundi(madra_added)

## Returns each Spiritual stat's part, in the screens' order: "Spirit capped"
## when the cap took its XP, else "+12 Spirit XP" when its XP rounds to 1 or
## more, else none.
func _stat_parts() -> PackedStringArray:
	var parts: PackedStringArray = []
	for stat: CharacterAttributesData.AttributeType in StatDisplay.SPIRITUAL:
		if is_stat_capped(stat):
			parts.append(STAT_CAPPED_FORMAT % StatDisplay.name_of(stat))
		elif roundi(get_stat_xp(stat)) >= 1:
			parts.append(STAT_XP_FORMAT % [roundi(get_stat_xp(stat)), StatDisplay.name_of(stat)])
	return parts
