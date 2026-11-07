class_name CyclingRules
extends RefCounted

## CyclingRules
## The cycling mini-game's scoring rules, pure and static so they test without
## a scene. A press on the ball that scores a zone is PERFECT, GOOD or OK by how
## far the Madra ball's centre is from the zone's centre: under 0.3 of the zone's
## 20 px radius (6 px) is PERFECT, under 0.7 of it (14 px) is GOOD, and anything
## farther is OK. The tier sets the XP the zone pays the technique's other stat
## (Smooth Flow's Control), how many pellets fly to that stat's cell, and the
## name and colour of the hit's floater.
## Following the ball is judged here too (is_following()): anywhere in the gold
## circle around the ball keeps following, and a cursor in it starts once it
## moves, so a cursor resting on the path follows nothing as the ball passes. A
## slip out of the circle no longer than FOLLOW_GRACE keeps following
## (grace_holds()). FollowWindow measures what the rules read.
## So is the ball's ease (eased_ratio()), and a perfect cycle's share of the
## cycle followed (followed_enough(), misses_allowed()).
## So are seals, the game that trains Mind: a seal is SEAL_LENGTH arrows
## (random_seal()), shown SEAL_LEAD before the ball reaches its node, and each key
## lights the next arrow or starts the seal over (seal_progress()).
## Statics only.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How good a hit was, from worst to best.
enum Tier { OK, GOOD, PERFECT }

## A seal's arrows, keyed on W A S D or the arrow keys.
enum Arrow { UP, LEFT, DOWN, RIGHT }

## The arrows in a seal.
const SEAL_LENGTH: int = 3

## Seconds a seal shows before the ball reaches its node.
const SEAL_LEAD: float = 1.5

## A zone's radius in px: the distance from its centre to its edge.
const ZONE_RADIUS: float = 20.0

## The share of ZONE_RADIUS a hit must be under to be PERFECT (6 px).
const PERFECT_RATIO: float = 0.3

## The share of ZONE_RADIUS a hit must be under to be GOOD (14 px).
const GOOD_RATIO: float = 0.7

## Seconds of the cycle the follow rule looks back over.
const FOLLOW_WINDOW: float = 0.25

## px a cursor on the ball must have moved over the window to start following:
## a resting one never does, and a twitch does not either.
const FOLLOW_START_MOVE: float = 4.0

## Seconds of a slip out of the gold circle that still keep following.
const FOLLOW_GRACE: float = 0.1

## The share of a cycle a perfect cycle needs followed.
const PERFECT_FOLLOWED_SHARE: float = 0.95

## Seconds the ball takes to reach its even speed at a cycle's start, and to
## slow from it at the end.
const EASE_SECONDS: float = 1.0

## How far short of a limit a sum of frames may fall and still count as there.
## It absorbs float error.
const _EPSILON: float = 0.000001

## The share of the full rate an unlocked Auto pays while nobody follows the
## ball, for Madra and Spirit XP alike.
const AUTO_RATE: float = 0.4

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
## it is in the gold circle around the ball as drawn, and `moved` how far the
## cursor went over the window, in px. Off the ball nothing follows. A cursor
## that `was_following` keeps it anywhere in the circle; one that was not starts
## once it has moved FOLLOW_START_MOVE, so a resting cursor never starts.
static func is_following(on_ball: bool, was_following: bool, moved: float) -> bool:
	return on_ball and (was_following or moved >= FOLLOW_START_MOVE)

## Returns whether a slip of `slip_seconds` out of the gold circle still keeps
## following: it is no longer than FOLLOW_GRACE.
static func grace_holds(slip_seconds: float) -> bool:
	return slip_seconds <= FOLLOW_GRACE + _EPSILON

## Returns whether a cycle followed for `followed_ratio` of its time (0 to 1)
## was followed enough to be perfect: PERFECT_FOLLOWED_SHARE of it.
static func followed_enough(followed_ratio: float) -> bool:
	return followed_ratio >= PERFECT_FOLLOWED_SHARE - _EPSILON

## Returns whether a cycle `duration` seconds long that has missed
## `missed_seconds` of following so far can still be followed enough to be
## perfect.
static func misses_allowed(missed_seconds: float, duration: float) -> bool:
	return missed_seconds <= (1.0 - PERFECT_FOLLOWED_SHARE) * duration + _EPSILON

## Returns the ball's share of the path `seconds` into a cycle `duration` long,
## 0 at the start and 1 at the end. Its speed rises along a half cosine over the
## first EASE_SECONDS, holds even, and falls the same way over the last
## EASE_SECONDS. A cycle shorter than two of them ramps over half of it each way.
static func eased_ratio(seconds: float, duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	var t: float = clampf(seconds, 0.0, duration)
	var ramp: float = minf(EASE_SECONDS, duration / 2.0)
	# The even speed, in shares of the path a second: each ramp covers half of
	# what that speed would over the same time.
	var speed: float = 1.0 / (duration - ramp)
	if t <= ramp:
		return _ramp_distance(t, ramp) * speed
	if t >= duration - ramp:
		return 1.0 - _ramp_distance(duration - t, ramp) * speed
	return (ramp / 2.0 + t - ramp) * speed

## Returns how many of `seal`'s arrows are keyed after `arrow` is pressed with
## `keyed` of them keyed: one more when `arrow` is the next one, else 0, since a
## wrong key starts the seal over. SEAL_LENGTH keyed means the seal is open.
static func seal_progress(seal: Array[int], keyed: int, arrow: int) -> int:
	if keyed < seal.size() and seal[keyed] == arrow:
		return keyed + 1
	return 0

## Returns a new seal drawn from `rng`: SEAL_LENGTH arrows, never one arrow
## SEAL_LENGTH times.
static func random_seal(rng: RandomNumberGenerator) -> Array[int]:
	var seal: Array[int] = []
	while seal.is_empty() or seal.count(seal[0]) == SEAL_LENGTH:
		seal.clear()
		for i: int in SEAL_LENGTH:
			seal.append(rng.randi_range(Arrow.UP, Arrow.RIGHT))
	return seal

## Returns the XP of the technique's other stat `zone` pays for a hit of
## `tier`.
static func xp_for_tier(zone: CyclingZoneData, tier: Tier) -> int:
	match tier:
		Tier.PERFECT:
			return zone.perfect_xp
		Tier.GOOD:
			return zone.good_xp
		_:
			return zone.ok_xp

## Returns how many pellets fly from the zone to the stat's cell for a hit of
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

## Returns the colour of a hit of `tier`, for its floater: brass for PERFECT,
## cream for GOOD and tan for OK.
static func tier_color(tier: Tier) -> Color:
	match tier:
		Tier.PERFECT:
			return ThemeConstants.LACQUER_BRASS
		Tier.GOOD:
			return ThemeConstants.LACQUER_CREAM
		_:
			return ThemeConstants.LACQUER_TAN

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Returns the distance a ball covers `t` seconds into a ramp `ramp` seconds long
## up to a speed of 1, its speed rising along a half cosine.
static func _ramp_distance(t: float, ramp: float) -> float:
	return t / 2.0 - ramp / TAU * sin(PI * t / ramp)
