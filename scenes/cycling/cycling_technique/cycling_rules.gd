class_name CyclingRules
extends RefCounted

## CyclingRules
## The cycling mini-game's scoring rules, pure and static so they test without
## a scene. A click on a zone is PERFECT, GOOD or OK by how far the Madra
## ball's centre is from the zone's centre: under 0.3 of the zone's 20 px
## radius (6 px) is PERFECT, under 0.7 of it (14 px) is GOOD, and the rest of
## the zone is OK. The tier sets the zone's XP, how many XP pellets fly to the
## Core orb, and the name and colour of the hit's floater.
## Statics only.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How good a hit was, from worst to best.
enum Tier { OK, GOOD, PERFECT }

## A zone's radius in px: the distance from its centre to its edge.
const ZONE_RADIUS: float = 20.0

## The share of ZONE_RADIUS a hit must be under to be PERFECT (6 px).
const PERFECT_RATIO: float = 0.3

## The share of ZONE_RADIUS a hit must be under to be GOOD (14 px).
const GOOD_RATIO: float = 0.7

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns the tier of a hit made with the ball's centre `distance` px from the
## zone's centre. The distance is taken as a share of ZONE_RADIUS, clamped to
## 0-1, so a ball further out than the zone's edge counts as at the edge.
static func tier_for_distance(distance: float) -> Tier:
	var ratio: float = clampf(distance / ZONE_RADIUS, 0.0, 1.0)
	if ratio < PERFECT_RATIO:
		return Tier.PERFECT
	if ratio < GOOD_RATIO:
		return Tier.GOOD
	return Tier.OK

## Returns the Core Density XP `zone` pays for a hit of `tier`.
static func xp_for_tier(zone: CyclingZoneData, tier: Tier) -> int:
	match tier:
		Tier.PERFECT:
			return zone.perfect_xp
		Tier.GOOD:
			return zone.good_xp
		_:
			return zone.ok_xp

## Returns how many XP pellets fly from the zone to the Core orb for a hit of
## `tier`: 8, 5 or 3.
static func pellet_count(tier: Tier) -> int:
	match tier:
		Tier.PERFECT:
			return 8
		Tier.GOOD:
			return 5
		_:
			return 3

## Returns the word a hit of `tier` shows in its floater: "PERFECT", "GOOD" or
## "OK".
static func tier_name(tier: Tier) -> String:
	match tier:
		Tier.PERFECT:
			return "PERFECT"
		Tier.GOOD:
			return "GOOD"
		_:
			return "OK"

## Returns the colour of a hit of `tier`, for its floater and XP pellets:
## brass for PERFECT, cream for GOOD and tan for OK.
static func tier_color(tier: Tier) -> Color:
	match tier:
		Tier.PERFECT:
			return ThemeConstants.LACQUER_BRASS
		Tier.GOOD:
			return ThemeConstants.LACQUER_CREAM
		_:
			return ThemeConstants.LACQUER_TAN
