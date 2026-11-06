class_name CycleResult
extends RefCounted

## CycleResult
## What one cycle came to, and the lines that report it: the zone chest's line
## under the Now tray ("Last cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 XP") and the log
## ("Cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 XP"). With the core full
## the XP part reads "Core full" instead, since the core takes none. It holds the
## totals and writes the lines; the cycle that owns it keeps the totals up to
## date.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Joins the parts of a line: a space, a middle dot (U+00B7) and a space.
const SEPARATOR: String = " · "

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

## The Core Density XP the scored zones were worth. A full core takes none of it (see core_full).
var xp: int = 0

## True when the core was full by the cycle's end. The line then says Core full where it would give the XP.
var core_full: bool = false

## The share of the cycle the cursor followed the ball, 0 to 1.
var followed_ratio: float = 0.0

## The XP each stat took this cycle, AttributeType to float: what the stat
## gained, which the cap can make less than it was paid.
var stat_xp: Dictionary = {}

## The stats the cap took XP from this cycle: paid at the cap, or by a payment
## that reached it.
var capped_stats: Array[CharacterAttributesData.AttributeType] = []

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

## Returns the cycle in one phrase: the Madra, then the zones ("3 / 4 zones",
## "1 / 1 zone", or "no zones" for a technique without any), then the PERFECT
## count if there were any, then the XP if any was paid, or "Core full" once the
## core was full (core_full). The parts are joined by SEPARATOR.
func summary() -> String:
	var parts: PackedStringArray = ["+%d Madra" % roundi(madra_added)]
	if zones_total == 0:
		parts.append("no zones")
	else:
		var noun: String = "zone" if zones_total == 1 else "zones"
		parts.append("%d / %d %s" % [zones_scored, zones_total, noun])
	if perfect_count > 0:
		parts.append("%d PERFECT" % perfect_count)
	if core_full:
		parts.append(CultivationManager.CORE_FULL_TEXT)
	elif xp > 0:
		parts.append("+%d XP" % xp)
	return SEPARATOR.join(parts)

## Returns the chest's line under the Now tray: "Last cycle · " and the summary.
func result_line() -> String:
	return "Last cycle" + SEPARATOR + summary()

## Returns the log's line: "Cycle · " and the summary.
func log_line() -> String:
	return "Cycle" + SEPARATOR + summary()
