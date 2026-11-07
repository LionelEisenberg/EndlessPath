extends GutTest

## GameSpeed.hit_stop(): the moment time slows, for the boss's reveal and a
## fight's deciding hit. Time runs at a quarter of the base speed for 0.15 s of
## real time, then at the base speed again, whatever the dev speed is.

func after_each() -> void:
	GameSpeed.set_base_scale(1.0)

func test_a_hit_stop_slows_time_then_returns_to_the_base_speed() -> void:
	var cases: Array[Dictionary] = [
		{"name": "normal speed", "base": 1.0, "slowed": 0.25},
		{"name": "a dev speed", "base": 2.0, "slowed": 0.5},
	]
	for case: Dictionary in cases:
		GameSpeed.set_base_scale(case.base)

		GameSpeed.hit_stop(get_tree())

		assert_eq(Engine.time_scale, case.slowed, "%s: time slows to a quarter at once" % case.name)
		# 0.3 s of real time, whatever the time scale.
		await get_tree().create_timer(0.3, true, false, true).timeout
		assert_eq(Engine.time_scale, case.base, "%s: and runs at the base speed again" % case.name)

## The stop lasts HIT_STOP_SECONDS of real time, not of slowed time.
func test_a_hit_stop_lasts_its_seconds_of_real_time() -> void:
	GameSpeed.hit_stop(get_tree())
	await get_tree().create_timer(GameSpeed.HIT_STOP_SECONDS * 0.5, true, false, true).timeout
	assert_eq(Engine.time_scale, GameSpeed.HIT_STOP_SCALE, "halfway through, time is still slow")
	await get_tree().create_timer(GameSpeed.HIT_STOP_SECONDS, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0, "after it, full speed")
