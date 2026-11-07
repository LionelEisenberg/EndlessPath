extends GutTest

## Unit tests for FollowWindow, the last quarter second of a cycle as the follow
## rule sees it: the press starts following, a cursor moving in the gold circle
## starts it at once and keeps it anywhere in the circle, a resting cursor never
## follows, a still ball keeps a streak but starts none, and a long frame is
## judged against the frame before it. The motions run at 30, 60 and 144 FPS: the
## ball moves SPEED px a second along x, and the cursor is on it within
## CyclingTechnique.CURSOR_REACH.

const SPEED: float = 200.0
const FRAME_RATES: Array[float] = [30.0, 60.0, 144.0]

## A cursor far from the ball.
const FAR: Vector2 = Vector2(-9999.0, -9999.0)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The ball's true place `seconds` into the window.
func _ball(seconds: float) -> Vector2:
	return Vector2(SPEED * seconds, 0.0)

## Runs `seconds` of frames at `fps` through `window` from `start` seconds in,
## the cursor where `cursor_at.call(time, ball)` puts it at each frame's end, and
## returns each frame's verdict.
func _drive(window: FollowWindow, fps: float, seconds: float, cursor_at: Callable, start: float = 0.0) -> Array[bool]:
	var verdicts: Array[bool] = []
	for frame: int in roundi(seconds * fps):
		var time: float = start + (frame + 1) / fps
		var ball: Vector2 = _ball(time)
		var cursor: Vector2 = cursor_at.call(time, ball)
		var on_ball: bool = cursor.distance_to(ball) <= CyclingTechnique.CURSOR_REACH
		verdicts.append(window.judge(1.0 / fps, on_ball, cursor))
	return verdicts

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_the_press_starts_following_on_the_ball() -> void:
	var window := FollowWindow.new()
	window.reset(true)
	assert_true(window.judge(1.0 / 60.0, true, _ball(0.0)), "the press on the ball starts it")
	assert_true(window.is_following())
	window.reset(true)
	assert_false(window.judge(1.0 / 60.0, false, FAR), "a first frame off the ball does not")
	window.reset(false)
	assert_false(window.judge(1.0 / 60.0, true, _ball(0.0)), "nor does a first frame with no press")

func test_a_resting_cursor_never_follows() -> void:
	# The ball runs through the resting cursor at 0.5 s.
	var resting := Vector2(SPEED * 0.5, 0.0)
	for fps: float in FRAME_RATES:
		var window := FollowWindow.new()
		window.reset(false)
		var verdicts: Array[bool] = _drive(window, fps, 1.5, func(_time: float, _ball_at: Vector2) -> Vector2: return resting)
		assert_false(verdicts.has(true), "a resting cursor never follows at %d FPS" % fps)

func test_a_cursor_moving_with_the_ball_starts_and_keeps_following() -> void:
	for fps: float in FRAME_RATES:
		var window := FollowWindow.new()
		window.reset(false)
		var verdicts: Array[bool] = _drive(window, fps, 1.0, func(_time: float, ball: Vector2) -> Vector2: return ball + Vector2(10.0, 0.0))
		# The first frame the cursor has moved 4 px since the window's first frame.
		var start: int = ceili(CyclingRules.FOLLOW_START_MOVE / SPEED * fps)
		assert_eq(verdicts.find(true), start, "it starts once the cursor has moved 4 px, at %d FPS" % fps)
		assert_false(verdicts.slice(start).has(false), "and keeps going, at %d FPS" % fps)

func test_catching_the_ball_starts_at_once() -> void:
	for fps: float in FRAME_RATES:
		var window := FollowWindow.new()
		window.reset(false)
		var away: Array[bool] = _drive(window, fps, 1.0, func(_time: float, _ball_at: Vector2) -> Vector2: return FAR)
		assert_false(away.has(true), "precondition: nothing while far away, at %d FPS" % fps)
		var caught: Array[bool] = _drive(window, fps, 1.0, func(_time: float, ball: Vector2) -> Vector2: return ball + Vector2(5.0, 0.0), 1.0)
		assert_false(caught.has(false), "the cursor moved onto the ball, so it follows from its first frame there, at %d FPS" % fps)

## Once following, the cursor can sit anywhere in the gold circle: one that
## sweeps from one side of the ball to the other keeps following.
func test_anywhere_in_the_circle_keeps_following() -> void:
	for fps: float in FRAME_RATES:
		var window := FollowWindow.new()
		window.reset(true)
		var verdicts: Array[bool] = _drive(window, fps, 2.0, func(time: float, ball: Vector2) -> Vector2: return ball + Vector2(30.0 * sin(TAU * time), 30.0 * cos(TAU * time)))
		assert_false(verdicts.has(false), "a cursor sweeping round the circle keeps following, at %d FPS" % fps)

func test_a_still_ball_keeps_a_streak_and_starts_none() -> void:
	var cursor := Vector2(103.0, 0.0)
	var window := FollowWindow.new()
	window.reset(true)
	var kept: Array[bool] = []
	for _frame: int in 60:
		kept.append(window.judge(1.0 / 60.0, true, cursor))
	assert_false(kept.has(false), "the press's streak holds on a still ball")
	window.reset(false)
	var started: Array[bool] = []
	for _frame: int in 60:
		started.append(window.judge(1.0 / 60.0, true, cursor))
	assert_false(started.has(true), "and a still cursor starts none")

func test_a_long_frame_is_judged_against_the_frame_before_it() -> void:
	var window := FollowWindow.new()
	window.reset(false)
	var offset := Vector2(5.0, 0.0)
	window.judge(1.0 / 60.0, true, _ball(1.0 / 60.0) + offset)
	var after: Vector2 = _ball(6.0 + 1.0 / 60.0)
	assert_true(window.judge(6.0, true, after + offset), "the cursor moved with the ball through the hitch")

## A cursor that slips out of the circle keeps following while the grace holds,
## and back in it follows on: from a still cursor, so no move is needed.
func test_a_slip_the_grace_holds_keeps_following() -> void:
	var cursor := Vector2(100.0, 0.0)
	var window := FollowWindow.new()
	window.reset(true)
	for _frame: int in 30:
		window.judge(1.0 / 60.0, true, cursor)
	var held: Array[bool] = []
	for _frame: int in 6:
		held.append(window.judge(1.0 / 60.0, false, FAR))
		assert_true(window.is_in_grace(), "the grace holds it")
	assert_false(held.has(false), "six frames off the ball, 0.1 s, keep following")
	assert_true(window.judge(1.0 / 60.0, true, cursor), "back on the ball it follows on")
	assert_false(window.is_in_grace())

func test_a_slip_past_the_grace_ends_following() -> void:
	var cursor := Vector2(100.0, 0.0)
	var window := FollowWindow.new()
	window.reset(true)
	for _frame: int in 30:
		window.judge(1.0 / 60.0, true, cursor)
	for _frame: int in 6:
		window.judge(1.0 / 60.0, false, FAR)
	assert_false(window.judge(1.0 / 60.0, false, FAR), "the seventh frame off the ball ends it")
	assert_false(window.is_in_grace())
	assert_false(window.judge(1.0 / 60.0, true, cursor), "and a still cursor back on the ball does not start again")

## A grace keeps following; it never starts it.
func test_no_grace_for_a_cursor_that_was_not_following() -> void:
	var window := FollowWindow.new()
	window.reset(false)
	window.judge(1.0 / 60.0, true, Vector2(100.0, 0.0))
	assert_false(window.judge(1.0 / 60.0, false, FAR))
	assert_false(window.is_in_grace())
