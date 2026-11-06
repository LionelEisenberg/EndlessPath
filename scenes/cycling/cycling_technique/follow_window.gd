class_name FollowWindow
extends RefCounted

## FollowWindow
## The last quarter second of a cycle as the follow rule sees it: where the true
## ball was at the end of each frame, and where the cursor was from it. judge()
## adds a frame and gives CyclingRules.is_following()'s verdict on it, measured
## against the newest frame at least CyclingRules.FOLLOW_WINDOW old, or the
## window's oldest frame until one is that old: how far the ball went since, and
## how far the cursor's place on the ball shifted. Frames older than that one
## are dropped.
## A cycle starts the window empty, and its first frame follows if the cursor is
## on the ball and the cycle starts following: a press, or an Auto restart that
## carried a streak. The ball has not moved yet, so nothing else can tell.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How far short of FOLLOW_WINDOW a frame's age may be and still count as that
## old. It absorbs float error in the frames' sum.
const _AGE_EPSILON: float = 0.000001

#-----------------------------------------------------------------------------
# TYPES
#-----------------------------------------------------------------------------

## One frame the rule may look back on.
class Sample:
	## Seconds into the window when the frame ended.
	var time: float = 0.0

	## Where the true ball was.
	var ball: Vector2 = Vector2.ZERO

	## Where the cursor was, from the true ball.
	var offset: Vector2 = Vector2.ZERO

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The frames the rule may still look back on, oldest first.
var _samples: Array[Sample] = []

## Seconds the window has run.
var _clock: float = 0.0

## The last frame's verdict; before a cycle's first frame, whether it starts
## following.
var _following: bool = false

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Empties the window for a new cycle. Its first frame follows if the cursor is
## on the ball and `starts_following`.
func reset(starts_following: bool) -> void:
	_samples.clear()
	_clock = 0.0
	_following = starts_following

## Adds a frame `seconds` long that ended with the true ball at `ball` and the
## cursor at `cursor`, `on_ball` saying whether the cursor was on the ball as
## drawn, and returns whether the cursor follows the ball now.
func judge(seconds: float, on_ball: bool, ball: Vector2, cursor: Vector2) -> bool:
	_clock += seconds
	_drop_old_samples()
	var sample := Sample.new()
	sample.time = _clock
	sample.ball = ball
	sample.offset = cursor - ball
	if _samples.is_empty():
		_following = on_ball and _following
	else:
		var reference: Sample = _samples[0]
		_following = CyclingRules.is_following(on_ball, _following, ball.distance_to(reference.ball), sample.offset.distance_to(reference.offset))
	_samples.append(sample)
	return _following

## Returns the last frame's verdict.
func is_following() -> bool:
	return _following

#-----------------------------------------------------------------------------
# SAMPLES
#-----------------------------------------------------------------------------

## Drops the oldest frame while the next one is at least FOLLOW_WINDOW old, so
## the first kept frame is the one the rule looks back on.
func _drop_old_samples() -> void:
	var oldest_needed: float = _clock - CyclingRules.FOLLOW_WINDOW + _AGE_EPSILON
	while _samples.size() > 1 and _samples[1].time <= oldest_needed:
		_samples.pop_front()
