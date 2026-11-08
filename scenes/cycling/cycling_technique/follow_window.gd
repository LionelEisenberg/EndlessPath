class_name FollowWindow
extends RefCounted

## FollowWindow
## The last quarter second of a cycle as the follow rule sees it: where the
## cursor was at the end of each frame. judge() adds a frame and gives
## CyclingRules.is_following()'s verdict on it, with how far the cursor has moved
## since the newest frame at least CyclingRules.FOLLOW_WINDOW old, or the
## window's oldest frame until one is that old. Frames older than that one are
## dropped.
## A cursor that was following and leaves the gold circle keeps following while
## the slip is short enough (CyclingRules.grace_holds()): is_in_grace() says so,
## and back in the circle it follows on without moving first. One that was not
## following gets no grace, so a grace never starts following.
## A cycle starts the window empty, and its first frame follows if the cursor is
## on the ball and the cycle starts following: a press, or an Auto restart that
## carried a streak. Nothing has moved yet, so nothing else can tell.

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

	## Where the cursor was.
	var cursor: Vector2 = Vector2.ZERO

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

## Seconds the cursor has been out of the gold circle while a grace holds it
## following; 0 while it is in the circle or not following.
var _grace_seconds: float = 0.0

## Whether the last frame follows only because a grace holds it.
var _in_grace: bool = false

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Empties the window for a new cycle. Its first frame follows if the cursor is
## on the ball and `starts_following`.
func reset(starts_following: bool) -> void:
	_samples.clear()
	_clock = 0.0
	_following = starts_following
	_grace_seconds = 0.0
	_in_grace = false

## Adds a frame `seconds` long that ended with the cursor at `cursor`, `on_ball`
## saying whether it was in the gold circle around the ball as drawn, and returns
## whether the cursor follows the ball now: in the circle by the follow rule, or
## out of it while a grace holds.
func judge(seconds: float, on_ball: bool, cursor: Vector2) -> bool:
	_clock += seconds
	_drop_old_samples()
	if _samples.is_empty():
		_following = on_ball and _following
		_grace_seconds = 0.0
		_in_grace = false
	elif not on_ball and _following and CyclingRules.grace_holds(_grace_seconds + seconds):
		_grace_seconds += seconds
		_in_grace = true
	else:
		_following = CyclingRules.is_following(on_ball, _following, cursor.distance_to(_samples[0].cursor))
		_grace_seconds = 0.0
		_in_grace = false
	var sample := Sample.new()
	sample.time = _clock
	sample.cursor = cursor
	_samples.append(sample)
	return _following

## Returns the last frame's verdict.
func is_following() -> bool:
	return _following

## Returns whether the last frame follows only because a grace holds it: the
## cursor is out of the gold circle, and has been for no longer than the grace.
func is_in_grace() -> bool:
	return _in_grace

#-----------------------------------------------------------------------------
# SAMPLES
#-----------------------------------------------------------------------------

## Drops the oldest frame while the next one is at least FOLLOW_WINDOW old, so
## the first kept frame is the one the rule looks back on.
func _drop_old_samples() -> void:
	var oldest_needed: float = _clock - CyclingRules.FOLLOW_WINDOW + _AGE_EPSILON
	while _samples.size() > 1 and _samples[1].time <= oldest_needed:
		_samples.pop_front()
