class_name CyclingRules
extends RefCounted

## CyclingRules
## The cycling mini-game's scoring rules, pure and static so they test without
## a scene. A press on the ball that scores a zone is PERFECT, GOOD or OK by how
## far the Madra ball's centre is from the zone's centre: under 0.3 of the zone's
## 20 px radius (6 px) is PERFECT, under 0.7 of it (14 px) is GOOD, and anything
## farther is OK. The tier sets the zone's XP, how many XP pellets fly to the
## Core orb, and the name and colour of the hit's floater.
## Following the ball is judged here too (is_following()): the cursor must be on
## the ball and move with it, so a cursor resting on the path follows nothing as
## the ball passes. FollowWindow measures what the rule reads.
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

## Seconds of the cycle the follow rule looks back over.
const FOLLOW_WINDOW: float = 0.25

## px the true ball must have gone over the window before a cursor can start
## following it: below that the ball creeps, and a cursor moving with it cannot
## be told from one resting on it.
const FOLLOW_START_TRAVEL: float = 8.0

## px the cursor's place on the ball may always shift over the window and keep
## following, so a hand held still on the creeping ball at either end of a cycle
## keeps its streak.
const FOLLOW_KEEP_DRIFT: float = 16.0

## The share of the ball's travel over the window that the cursor's place on the
## ball must shift less than: to start following, and to keep it at speed.
const FOLLOW_DRIFT_SHARE: float = 0.5

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

## Returns whether the cursor follows the ball this frame. `on_ball` is whether
## it is on the ball as drawn; `travel` is how far the true ball went over the
## window and `drift` how far the cursor's place on the ball shifted, in px. Off
## the ball nothing follows. A cursor that `was_following` keeps it while the
## shift stays under FOLLOW_KEEP_DRIFT or under FOLLOW_DRIFT_SHARE of the travel,
## whichever allows more. One that was not starts only once the ball has gone
## FOLLOW_START_TRAVEL and the shift is under FOLLOW_DRIFT_SHARE of it, so a
## resting cursor, whose place on the ball shifts as far as the ball goes, never
## starts.
static func is_following(on_ball: bool, was_following: bool, travel: float, drift: float) -> bool:
	if not on_ball:
		return false
	if was_following:
		return drift < maxf(FOLLOW_KEEP_DRIFT, travel * FOLLOW_DRIFT_SHARE)
	return travel >= FOLLOW_START_TRAVEL and drift < travel * FOLLOW_DRIFT_SHARE

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
