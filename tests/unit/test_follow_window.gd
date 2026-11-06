extends GutTest

## Unit tests for FollowWindow, the last quarter second of a cycle as the follow
## rule sees it: the press starts following, a cursor that moves with the ball
## starts and keeps it, a resting cursor never follows, catching the ball takes a
## whole window, a still ball keeps a streak but starts none, and a long frame is
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
		verdicts.append(window.judge(1.0 / fps, on_ball, ball, cursor))
	return verdicts

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_the_press_starts_following_on_the_ball() -> void:
	var window := FollowWindow.new()
	window.reset(true)
	assert_true(window.judge(1.0 / 60.0, true, _ball(0.0), _ball(0.0)), "the press on the ball starts it")
	assert_true(window.is_following())
	window.reset(true)
	assert_false(window.judge(1.0 / 60.0, false, _ball(0.0), FAR), "a first frame off the ball does not")
	window.reset(false)
	assert_false(window.judge(1.0 / 60.0, true, _ball(0.0), _ball(0.0)), "nor does a first frame with no press")

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
		# The first frame the ball has gone 8 px since the window's first frame.
		var start: int = ceili(CyclingRules.FOLLOW_START_TRAVEL / SPEED * fps)
		assert_eq(verdicts.find(true), start, "it starts once the ball has gone 8 px, at %d FPS" % fps)
		assert_false(verdicts.slice(start).has(false), "and keeps going, at %d FPS" % fps)

func test_catching_the_ball_takes_a_window() -> void:
	for fps: float in FRAME_RATES:
		var window := FollowWindow.new()
		window.reset(false)
		var away: Array[bool] = _drive(window, fps, 1.0, func(_time: float, _ball_at: Vector2) -> Vector2: return FAR)
		assert_false(away.has(true), "precondition: nothing while far away, at %d FPS" % fps)
		var caught: Array[bool] = _drive(window, fps, 1.0, func(_time: float, ball: Vector2) -> Vector2: return ball + Vector2(5.0, 0.0), 1.0)
		# On the ball from the first of these frames, which the rule looks back on a
		# quarter second later.
		var start: int = ceili(CyclingRules.FOLLOW_WINDOW * fps - 0.0001)
		assert_eq(caught.find(true), start, "it starts a quarter second after the cursor caught the ball, at %d FPS" % fps)
		assert_false(caught.slice(start).has(false), "and keeps going, at %d FPS" % fps)

func test_a_still_ball_keeps_a_streak_and_starts_none() -> void:
	var still := Vector2(100.0, 0.0)
	var cursor: Vector2 = still + Vector2(3.0, 0.0)
	var window := FollowWindow.new()
	window.reset(true)
	var kept: Array[bool] = []
	for _frame: int in 60:
		kept.append(window.judge(1.0 / 60.0, true, still, cursor))
	assert_false(kept.has(false), "the press's streak holds on a still ball")
	window.reset(false)
	var started: Array[bool] = []
	for _frame: int in 60:
		started.append(window.judge(1.0 / 60.0, true, still, cursor))
	assert_false(started.has(true), "and no streak starts on one")

func test_a_long_frame_is_judged_against_the_frame_before_it() -> void:
	var window := FollowWindow.new()
	window.reset(true)
	var offset := Vector2(5.0, 0.0)
	window.judge(1.0 / 60.0, true, _ball(1.0 / 60.0), _ball(1.0 / 60.0) + offset)
	assert_true(window.judge(1.0 / 60.0, true, _ball(2.0 / 60.0), _ball(2.0 / 60.0) + offset), "precondition: following")
	var after: Vector2 = _ball(6.0 + 2.0 / 60.0)
	assert_true(window.judge(6.0, true, after, after + offset), "the cursor moved with the ball through the hitch")
