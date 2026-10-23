extends GutTest

## Integration tests for the play of a cycling technique: CyclingTechnique (the
## Madra ball travelling its groove, the Madra drawn while the cursor follows
## it, the zones along the path, a press on the ball, and a cycle's start, end
## and result) and CyclingZone (its socket's state frames). A cycle is stepped by
## calling advance() with a chosen cursor, as _process() calls it with the
## mouse. The technique under test is smooth_flow unless a test says otherwise:
## a 15 s cycle of 200 Madra with 4 zones, on a fresh save (25 Madra, cap 100).

const TECHNIQUE_SCENE: PackedScene = preload("res://scenes/cycling/cycling_technique/cycling_technique.tscn")
const SMOOTH_FLOW_PATH: String = "res://resources/cycling/cycling_techniques/smooth_flow/smooth_flow.tres"
const FOUNDATION_PATH: String = "res://resources/cycling/cycling_techniques/foundation_cycling_technique/foundation_cycling_technique.tres"
const PLATE_SCENE: PackedScene = preload("res://scenes/zones/cultivator_plate/cultivator_plate.tscn")

## A cursor far from the ball and from every zone.
const FAR: Vector2 = Vector2(-9999.0, -9999.0)

## One frame at 60 FPS. A cycle is run for its duration plus one frame, because
## 900 sums of 1 / 60 can land a hair under 15.
const FRAME: float = 1.0 / 60.0
const CYCLE_SECONDS: float = 15.0

## The Madra one step draws: base_madra_per_cycle * 0.08 / cycle_duration.
const MADRA_STEP: float = 200.0 * 0.08 / 15.0

## The Madra steady tracking draws a second: base_madra_per_cycle / cycle_duration.
const MADRA_RATE: float = 200.0 / 15.0

## Where the ball waits: the first point of smooth_path.tres, on even px.
const START: Vector2 = Vector2(320.0, 464.0)

## One frame of the zone strip: the strip has a frame for each CyclingZone.State.
const ZONE_FRAME_SIZE: Vector2i = Vector2i(48, 48)

var _technique: CyclingTechnique = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_technique = TECHNIQUE_SCENE.instantiate() as CyclingTechnique
	add_child_autofree(_technique)
	# Only the steps these tests take move the cycle, never the real mouse.
	_technique.set_process(false)
	_technique.setup(load(SMOOTH_FLOW_PATH))

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	# A cycle session left running would leak into later files.
	CyclingManager.end_cycle_session()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Steps `seconds` of frames at `fps`, with the cursor on the ball (the drawn
## centre) or far away.
func _run(seconds: float, fps: float, track: bool) -> void:
	for _frame: int in roundi(seconds * fps):
		_technique.advance(1.0 / fps, _technique.get_ball_global_position() if track else FAR)

## Steps 60 FPS frames with the cursor far away until `done` returns true, the
## cycle ends or `limit` seconds pass. Returns whether `done` is true.
func _step_until(done: Callable, limit: float = 20.0) -> bool:
	for _frame: int in roundi(limit * 60.0):
		if done.call() or not _technique.is_cycling():
			break
		_technique.advance(FRAME, FAR)
	return done.call()

func _zone(index: int) -> CyclingZone:
	return _technique.cycling_zones[index]

func _node(unique_name: String) -> Node:
	return _technique.get_node("%" + unique_name)

## The ball's true distance to the zone: the path follower's, not the drawn ball's.
func _distance_to(zone: CyclingZone) -> float:
	return (_node("PathFollow2D") as PathFollow2D).global_position.distance_to(zone.global_position)

## Starts a cycle and steps it until zone 0 is closer than `within` px (or just
## active, when within is 0).
func _approach_zone_0(within: float) -> CyclingZone:
	var zone: CyclingZone = _zone(0)
	_technique.start_cycle()
	var reached: bool = _step_until(func() -> bool:
		return zone.get_state() == CyclingZone.State.ACTIVE and (within <= 0.0 or _distance_to(zone) < within))
	assert_true(reached, "precondition: the ball comes within %s px of zone 0" % within)
	return zone

## Waits a frame, so the old zones a setup() took out of the tree and queue-freed
## are gone before GUT counts orphans.
func _await_queued_frees() -> void:
	await wait_process_frames(1)

## Counts the Madra pellets the technique requests from now on.
func _count_pellets() -> Array[int]:
	var count: Array[int] = [0]
	_technique.madra_particle_requested.connect(func(_from_pos: Vector2) -> void: count[0] += 1)
	return count

## Swaps the fixture's technique for a new one playing foundation_technique: an 8 s
## cycle of 50 Madra in 100 steps of 0.5, no zones, on a path that ends where it
## starts. It is built with the technique, so no old zones are thrown away.
func _use_foundation() -> void:
	_technique = TECHNIQUE_SCENE.instantiate() as CyclingTechnique
	_technique.technique_data_input = load(FOUNDATION_PATH)
	add_child_autofree(_technique)
	_technique.set_process(false)

## Plays one cycle from ready with the cursor on the ball, each frame
## `next_delta.call()` seconds long, until it ends. Returns the Madra steps it paid.
func _track_one_cycle(next_delta: Callable) -> int:
	var pellets: Array[int] = _count_pellets()
	_technique.start_cycle()
	for _frame: int in 100000:
		if not _technique.is_cycling():
			break
		_technique.advance(next_delta.call(), _technique.get_ball_global_position())
	return pellets[0]

func _left_press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

## A press pushed through the viewport at `position`, with two physics frames on
## each side. The physics server learns where an Area2D is at its next step, so
## the frames before let it catch up with the areas the test just made or moved,
## and the frames after let physics picking deliver the press. The position is in
## the viewport's own coordinates (push_input's local coordinates): the headless
## window is 64 px square, so the usual window-to-viewport stretch would move it.
func _press_at(position: Vector2) -> void:
	await wait_physics_frames(2)
	var event: InputEventMouseButton = _left_press()
	event.position = position
	event.global_position = position
	get_viewport().push_input(event, true)
	await wait_physics_frames(2)

## A technique of one 1000 px straight path from (0, 0) to (1000, 0) with one
## zone, for the cases where the drawn and the true ball differ by a fraction
## of a px. Its cycle is 10 s.
func _straight_technique(zone_position: Vector2) -> CyclingTechniqueData:
	return _straight_technique_with_zones([zone_position])

## The straight technique with a zone at each of `zone_positions`.
func _straight_technique_with_zones(zone_positions: Array[Vector2]) -> CyclingTechniqueData:
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(1000.0, 0.0))
	var data := CyclingTechniqueData.new()
	data.id = "test_straight"
	data.path_curve = curve
	data.cycle_duration = 10.0
	data.base_madra_per_cycle = 100.0
	for zone_position: Vector2 in zone_positions:
		var zone := CyclingZoneData.new()
		zone.position = zone_position
		data.cycling_zones.append(zone)
	return data

## Runs the straight technique's cycle for one frame that carries the true ball
## to `x` on the path (the cycle eases with 0.5 - 0.5 cos(pi t / 10)), with the
## cursor at `cursor`.
func _advance_straight_to(x: float, cursor: Vector2) -> void:
	_technique.advance(10.0 * acos(1.0 - 2.0 * x / 1000.0) / PI, cursor)

#-----------------------------------------------------------------------------
# CYCLE LIFECYCLE
#-----------------------------------------------------------------------------

func test_zones_show_between_cycles() -> void:
	assert_eq(_technique.cycling_zones.size(), 4)
	for zone: CyclingZone in _technique.cycling_zones:
		assert_true(zone.visible, "%s shows" % zone.name)
		assert_eq(zone.get_state(), CyclingZone.State.IDLE, "%s is idle" % zone.name)

func test_start_only_from_ready() -> void:
	watch_signals(_technique)
	assert_false(_technique.is_cycling(), "precondition: the technique is ready")
	assert_true(_technique.start_cycle())
	assert_true(_technique.is_cycling())
	assert_true(CyclingManager.is_cycle_running(), "the session starts with the cycle")
	assert_false(_technique.start_cycle(), "a cycle that runs cannot be started again")
	assert_signal_emit_count(_technique, "cycling_started", 1)
	_technique.stop_cycling()
	assert_true(_technique.start_cycle(), "ready again after stop")

func test_no_cycle_starts_without_a_technique() -> void:
	var bare: CyclingTechnique = add_child_autofree(TECHNIQUE_SCENE.instantiate())
	bare.set_process(false)
	assert_null(bare.technique_data, "precondition: nothing is set up")
	assert_false(bare.start_cycle())
	assert_false(bare.is_cycling())

func test_cycle_completes_with_a_result() -> void:
	watch_signals(_technique)
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	assert_signal_emit_count(_technique, "cycle_completed", 1)
	var result := get_signal_parameters(_technique, "cycle_completed", 0)[0] as CycleResult
	assert_eq(result.madra_added, 0.0)
	assert_eq(result.zones_total, 4)
	assert_eq(result.zones_scored, 0)
	assert_eq(result.result_line(), "Last cycle · +0 Madra · 0 / 4 zones")
	for zone: CyclingZone in _technique.cycling_zones:
		assert_eq(zone.get_state(), CyclingZone.State.SPENT, "%s is spent" % zone.name)
		assert_true(zone.visible, "%s still shows" % zone.name)
	assert_false(_technique.is_cycling())

func test_ball_waits_at_the_start_when_the_cycle_ends() -> void:
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	assert_false(_technique.is_cycling(), "precondition: the cycle ended")
	assert_eq(_technique.get_ball_global_position(), START)
	var ring := _node("BallRing") as LacquerStripRect
	assert_true(ring.visible, "the brass ring waits around the ball")
	assert_eq(ring.get_frame(), Vector2i(0, 0))

#-----------------------------------------------------------------------------
# MADRA
#-----------------------------------------------------------------------------

func test_tracking_draws_madra_quietly() -> void:
	watch_signals(_technique)
	watch_signals(LogManager)
	_technique.start_cycle()
	_run(1.0, 60.0, true)
	assert_signal_emit_count(_technique, "madra_particle_requested", 12)
	assert_almost_eq(ResourceManager.get_madra(), 25.0 + 12.0 * MADRA_STEP, 0.01)
	assert_almost_eq(_technique.get_current_result().madra_added, 12.0 * MADRA_STEP, 0.05)
	assert_signal_not_emitted(LogManager, "message_logged")

func test_pellets_start_at_the_drawn_ball() -> void:
	var origins: Array[Vector2] = []
	var balls: Array[Vector2] = []
	_technique.madra_particle_requested.connect(func(from_pos: Vector2) -> void:
		origins.append(from_pos)
		balls.append(_technique.get_ball_global_position()))
	_technique.start_cycle()
	_run(0.5, 60.0, true)
	assert_gt(origins.size(), 0, "precondition: the cursor drew Madra")
	assert_eq(origins, balls, "each pellet leaves the drawn ball's centre")
	assert_ne(origins[0], origins[origins.size() - 1], "the ball moved between the first pellet and the last")

func test_madra_steps_carry_their_remainder() -> void:
	# The old timer reset to 0 at each step, which paid 10 steps a second at 30 FPS.
	for fps: float in [30.0, 60.0, 144.0]:
		_technique.stop_cycling()
		ResourceManager.set_madra(25.0)
		var pellets: Array[int] = _count_pellets()
		_technique.start_cycle()
		_run(1.0, fps, true)
		assert_eq(pellets[0], 12, "12 Madra steps in 1 s at %d FPS" % fps)

func test_no_madra_or_pellets_at_the_cap() -> void:
	watch_signals(_technique)
	ResourceManager.set_madra(100.0)
	assert_eq(CultivationManager.get_max_madra(), 100.0, "precondition: the cap is 100")
	_technique.start_cycle()
	_run(1.0, 60.0, true)
	assert_signal_not_emitted(_technique, "madra_particle_requested")
	assert_eq(ResourceManager.get_madra(), 100.0)
	assert_eq(_technique.get_current_result().madra_added, 0.0)

func test_madra_above_the_cap_is_left_alone() -> void:
	# add_madra() would clamp it down and report a negative correction.
	ResourceManager.set_madra(150.0)
	_technique.start_cycle()
	_run(1.0, 60.0, true)
	assert_eq(ResourceManager.get_madra(), 150.0)
	assert_eq(_technique.get_current_result().madra_added, 0.0)

func test_a_step_that_adds_nothing_requests_no_pellet() -> void:
	# 0.0004 under the cap: add_madra() fills it but reports 0 (it snaps to
	# 0.001), so the step is not counted and no pellet flies.
	watch_signals(_technique)
	ResourceManager.set_madra(99.9996)
	_technique.start_cycle()
	_run(1.0, 60.0, true)
	assert_signal_not_emitted(_technique, "madra_particle_requested")
	assert_eq(_technique.get_current_result().madra_added, 0.0)

func test_cap_reached_mid_cycle() -> void:
	# Review Focus 2: the step that meets the cap pays what fits, and the later
	# steps pay and request nothing.
	watch_signals(_technique)
	ResourceManager.set_madra(98.0)
	_technique.start_cycle()
	_run(1.0, 60.0, true)
	assert_signal_emit_count(_technique, "madra_particle_requested", 2)
	assert_true(is_equal_approx(_technique.get_current_result().madra_added, 2.0))
	assert_eq(ResourceManager.get_madra(), 100.0)

func test_the_result_counts_the_madra_the_pool_gained() -> void:
	# add_madra() reports each step snapped to 0.001 (1.067 for 1.0667), and a
	# full cycle's 187 snapped steps sum to 199.53: "+200" for the 199.47 it adds.
	PersistenceManager.save_game_data.core_density_level = 40.0
	ResourceManager.set_madra(46.0)
	assert_gt(CultivationManager.get_max_madra(), 46.0 + 200.0, "precondition: the cycle never meets the cap")
	watch_signals(_technique)
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, true)
	assert_signal_emit_count(_technique, "cycle_completed", 1)
	var result := get_signal_parameters(_technique, "cycle_completed", 0)[0] as CycleResult
	assert_almost_eq(result.madra_added, ResourceManager.get_madra() - 46.0, 0.000001, "the result holds what the pool gained")
	assert_eq(result.result_line(), "Last cycle · +199 Madra · 0 / 4 zones")

func test_a_tracked_8_s_cycle_pays_its_last_step_at_120_fps() -> void:
	# An 8 s cycle holds exactly 100 steps of 0.08 s, so its 100th step falls on
	# its last instant. Float error in 960 frames of 1 / 120 s must not cost it.
	_use_foundation()
	assert_eq(_track_one_cycle(func() -> float: return 1.0 / 120.0), 100, "100 steps at 120 FPS")
	assert_almost_eq(_technique.get_current_result().madra_added, 50.0, 0.000001, "the cycle's 50 Madra")

func test_a_tracked_8_s_cycle_pays_100_steps_at_60_and_144_fps() -> void:
	for fps: float in [60.0, 144.0]:
		ResourceManager.set_madra(25.0)
		_use_foundation()
		assert_eq(_track_one_cycle(func() -> float: return 1.0 / fps), 100, "100 steps at %d FPS" % fps)

func test_a_tracked_8_s_cycle_pays_100_steps_at_uneven_frame_times() -> void:
	# Frames of 1 / 120 to 1 / 40 s, drawn from fixed seeds.
	var rng := RandomNumberGenerator.new()
	for seed_value: int in [1, 2, 3, 4, 5]:
		rng.seed = seed_value
		ResourceManager.set_madra(25.0)
		_use_foundation()
		assert_eq(_track_one_cycle(func() -> float: return rng.randf_range(0.5, 1.5) / 60.0), 100, "100 steps with seed %d" % seed_value)

func test_a_hitch_through_the_end_pays_only_the_steps_left() -> void:
	# 2 s of tracking pay 25 of the cycle's 100 steps. A 16 s frame then covers 200
	# steps with the cursor on the ball (the path ends where it starts), but only
	# 6 s of it, 75 steps, were left in the cycle.
	PersistenceManager.save_game_data.core_density_level = 100.0
	assert_eq(CultivationManager.get_max_madra(), 600.0, "precondition: the cap does not bound the hitch")
	_use_foundation()
	var curve: Curve2D = _technique.technique_data.path_curve
	assert_eq(curve.get_point_position(curve.point_count - 1), curve.get_point_position(0), "precondition: the path ends where it starts")
	var path_end: Vector2 = _technique.get_ball_global_position()
	var pellets: Array[int] = _count_pellets()
	_technique.start_cycle()
	_run(2.0, 60.0, true)
	assert_eq(pellets[0], 25, "precondition: 2 s of tracking paid 25 steps")
	_technique.advance(16.0, path_end)
	assert_false(_technique.is_cycling(), "precondition: the frame ended the cycle")
	assert_eq(pellets[0], 100, "the 75 steps left in the cycle, not the 200 the frame covers")
	assert_almost_eq(_technique.get_current_result().madra_added, 50.0, 0.000001)

#-----------------------------------------------------------------------------
# THE MADRA RATE
#-----------------------------------------------------------------------------

## The rate the cabinet and the tray show is time-weighted over the last
## RATE_WINDOW seconds of the cycle: the Madra the cursor drew in them over the
## time they cover. It does not count the 0.08 s steps (a window holds 12 or 13 of
## them, which would flicker between +12.8 and +13.9).

func test_rate_holds_steady_while_tracking() -> void:
	# Steady tracking reads base_madra_per_cycle / cycle_duration at any frame
	# rate, from the first frame on (13.333 reads +13.3).
	for fps: float in [30.0, 60.0, 144.0]:
		_technique.stop_cycling()
		ResourceManager.set_madra(25.0)
		_technique.start_cycle()
		var off: int = 0
		var last: float = 0.0
		for _frame: int in roundi(3.0 * fps):
			_technique.advance(1.0 / fps, _technique.get_ball_global_position())
			last = CyclingManager.get_madra_rate()
			if not is_equal_approx(snappedf(last, 0.1), 13.3):
				off += 1
		assert_eq(off, 0, "frames of 3 s at %d FPS whose rate did not read 13.3" % fps)
		assert_almost_eq(last, MADRA_RATE, 0.001, "exactly base_madra_per_cycle / cycle_duration at %d FPS" % fps)

func test_rate_falls_to_zero_once_tracking_stops() -> void:
	for fps: float in [30.0, 60.0, 144.0]:
		_technique.stop_cycling()
		ResourceManager.set_madra(25.0)
		_technique.start_cycle()
		_run(1.0, fps, true)
		assert_gt(CyclingManager.get_madra_rate(), 0.0, "precondition: the cursor draws at %d FPS" % fps)
		_run(CyclingTechnique.RATE_WINDOW + 1.0 / fps, fps, false)
		assert_eq(CyclingManager.get_madra_rate(), 0.0, "RATE_WINDOW and a frame after the cursor left, at %d FPS" % fps)

func test_rate_rises_and_falls_within_a_second() -> void:
	# A window that is half tracked reads half the steady rate.
	_technique.start_cycle()
	_run(1.0, 60.0, false)
	assert_eq(CyclingManager.get_madra_rate(), 0.0, "nothing is drawn yet")
	_run(0.5, 60.0, true)
	assert_almost_eq(CyclingManager.get_madra_rate(), MADRA_RATE / 2.0, 0.1, "half a second of tracking")
	_run(0.5, 60.0, true)
	assert_almost_eq(CyclingManager.get_madra_rate(), MADRA_RATE, 0.001, "a second of tracking")
	_run(0.5, 60.0, false)
	assert_almost_eq(CyclingManager.get_madra_rate(), MADRA_RATE / 2.0, 0.1, "half a second after it stopped")

func test_rate_reads_zero_at_the_cap() -> void:
	ResourceManager.set_madra(100.0)
	_technique.start_cycle()
	_run(CyclingTechnique.RATE_WINDOW + FRAME, 60.0, true)
	assert_eq(CyclingManager.get_madra_rate(), 0.0, "the cursor follows the ball but nothing is drawn")

func test_rate_falls_to_zero_once_the_cap_is_met() -> void:
	ResourceManager.set_madra(98.0)
	_technique.start_cycle()
	_run(0.5, 60.0, true)
	assert_gt(CyclingManager.get_madra_rate(), 0.0, "precondition: the frames before the cap drew")
	assert_eq(ResourceManager.get_madra(), 100.0, "precondition: the cap is met")
	_run(CyclingTechnique.RATE_WINDOW + FRAME, 60.0, true)
	assert_eq(CyclingManager.get_madra_rate(), 0.0)

func test_the_frame_that_meets_the_cap_still_draws() -> void:
	# A frame draws if there is room under the cap before its steps, so the frame
	# whose own step fills the cap still counts.
	ResourceManager.set_madra(99.5)
	_technique.start_cycle()
	_run(5.0 / 60.0, 60.0, true)
	assert_eq(ResourceManager.get_madra(), 100.0, "precondition: the fifth frame's step filled the cap")
	assert_almost_eq(CyclingManager.get_madra_rate(), MADRA_RATE, 0.001)

func test_auto_restart_keeps_the_rate() -> void:
	# The restart happens inside the advance() that ends the cycle. The cabinet
	# reads the rate off the session each time it announces one, so a session
	# that read 0 until the next frame would blink the label out for a frame.
	PersistenceManager.save_game_data.core_density_level = 100.0
	assert_eq(CultivationManager.get_max_madra(), 600.0, "precondition: a whole cycle of Madra fits under the cap")
	var completed: Array[int] = [0]
	_technique.cycle_completed.connect(func(_result: CycleResult) -> void: completed[0] += 1)
	_technique.auto_cycle = true
	_technique.start_cycle()
	for _frame: int in roundi((CYCLE_SECONDS + 1.0) * 60.0):
		_technique.advance(FRAME, _technique.get_ball_global_position())
		if completed[0] > 0:
			break
	assert_eq(completed[0], 1, "precondition: the cycle ended")
	assert_true(CyclingManager.is_cycle_running(), "the next cycle started in the same frame")
	assert_eq(snappedf(CyclingManager.get_madra_rate(), 0.1), 13.3, "the rate carries into it")
	_technique.advance(FRAME, _technique.get_ball_global_position())
	assert_true(CyclingManager.is_cycle_running())
	assert_eq(snappedf(CyclingManager.get_madra_rate(), 0.1), 13.3, "and the frame after")
	assert_eq(completed[0], 1)

func test_a_manual_start_begins_from_an_empty_window() -> void:
	# A cycle that ends without Auto, like one that is stopped, leaves no rate
	# behind for the next one.
	PersistenceManager.save_game_data.core_density_level = 100.0
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, true)
	assert_false(_technique.is_cycling(), "precondition: the cycle ended without Auto")
	assert_eq(CyclingManager.get_madra_rate(), 0.0, "the session is over")
	_technique.start_cycle()
	_technique.advance(FRAME, FAR)
	assert_eq(CyclingManager.get_madra_rate(), 0.0, "nothing was drawn in the new cycle")
	_run(1.0, 60.0, true)
	_technique.stop_cycling()
	_technique.start_cycle()
	_technique.advance(FRAME, FAR)
	assert_eq(CyclingManager.get_madra_rate(), 0.0, "a stopped cycle leaves nothing either")

#-----------------------------------------------------------------------------
# TRACKING AND THE RING
#-----------------------------------------------------------------------------

func test_ring_shows_ready_then_tracking_then_hides() -> void:
	var ring := _node("BallRing") as LacquerStripRect
	_technique.advance(FRAME, FAR)
	assert_true(ring.visible, "the steady ring waits around the ready ball")
	assert_eq(ring.get_frame(), Vector2i(0, 0))
	assert_false(_technique.is_tracking())
	_technique.start_cycle()
	assert_false(ring.visible, "the ring hides as the cycle starts")
	_technique.advance(FRAME, FAR)
	assert_false(ring.visible, "and stays hidden while the cursor is off the ball")
	assert_false(_technique.is_tracking())
	_technique.advance(FRAME, _technique.get_ball_global_position())
	assert_true(ring.visible)
	assert_eq(ring.get_frame(), Vector2i(1, 0), "the dotted ring shows while tracking")
	assert_true(_technique.is_tracking())
	_technique.advance(FRAME, _technique.get_ball_global_position() + Vector2(CyclingTechnique.BALL_RADIUS + 1.0, 0.0))
	assert_false(ring.visible)
	assert_false(_technique.is_tracking())

#-----------------------------------------------------------------------------
# THE READY BALL BREATHES
#-----------------------------------------------------------------------------

func test_breath_level_steps_up_and_back_down_each_period() -> void:
	var levels: Array[int] = []
	for seconds: float in [0.1, 0.5, 1.0, 1.5, 1.9, 2.1]:
		levels.append(CyclingTechnique.breath_level(seconds))
	assert_eq(CyclingTechnique.BREATH_SECONDS, 2.0)
	assert_eq(levels, [0, 1, 2, 1, 0, 0], "small, up to the largest at half the period, and back")

func test_the_ready_ball_breathes() -> void:
	var sprite := _node("BallSprite") as LacquerStripRect
	var ring := _node("BallRing") as LacquerStripRect
	var rows: Array[int] = []
	var rings: Array[int] = []
	for _frame: int in 120:
		_technique.advance(FRAME, FAR)
		if rows.is_empty() or rows[-1] != sprite.get_frame().y:
			rows.append(sprite.get_frame().y)
		if rings.is_empty() or rings[-1] != ring.get_frame().x:
			rings.append(ring.get_frame().x)
		assert_eq(sprite.global_position + sprite.size / 2.0, START, "the ball stays centred on the start")
		assert_eq(ring.global_position + ring.size / 2.0, START, "and so does its ring")
	assert_eq(rows, [0, 1, 2, 1, 0], "60, 64, 68, 64 and back to 60 px over two seconds")
	assert_eq(rings, [0, 2, 3, 2, 0], "the ready ring grows with it")
	assert_true(ring.visible)

func test_the_ball_keeps_its_size_while_cycling() -> void:
	var sprite := _node("BallSprite") as LacquerStripRect
	_technique.start_cycle()
	for _frame: int in 120:
		_technique.advance(FRAME, _technique.get_ball_global_position())
		assert_eq(sprite.get_frame().y, 0)

func test_each_wait_starts_the_breath_small() -> void:
	var sprite := _node("BallSprite") as LacquerStripRect
	_run(1.0, 60.0, false)
	assert_eq(sprite.get_frame().y, 2, "precondition: mid-breath")
	_technique.start_cycle()
	_technique.stop_cycling()
	assert_eq(sprite.get_frame().y, 0, "waiting again starts from the small ball")
	_run(1.0, 60.0, false)
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	assert_false(_technique.is_cycling(), "precondition: the cycle ended")
	assert_eq(sprite.get_frame().y, 0, "and so does the wait after a cycle")

func test_tracking_uses_the_drawn_ball() -> void:
	_technique.setup(_straight_technique(Vector2(5000.0, 0.0)))
	_technique.start_cycle()
	# The true ball is at x 100.6 and is drawn at 100. A cursor at x 71 is 29 px
	# from the drawn ball (inside 29.5) and 29.6 px from the true one.
	_advance_straight_to(100.6, Vector2(71.0, 0.0))
	assert_eq(_technique.get_ball_global_position(), Vector2(100.0, 0.0))
	assert_true(_technique.is_tracking())
	await _await_queued_frees()

#-----------------------------------------------------------------------------
# ZONES AND SCORING
#-----------------------------------------------------------------------------

func test_zone_states_follow_the_ball() -> void:
	var zone: CyclingZone = _zone(0)
	_technique.start_cycle()
	assert_eq(zone.get_state(), CyclingZone.State.IDLE, "idle until the ball reaches it")
	assert_true(_step_until(func() -> bool: return zone.get_state() == CyclingZone.State.ACTIVE), "active as the ball reaches it")
	assert_lte(_distance_to(zone), 49.5)
	assert_true(_step_until(func() -> bool: return zone.get_state() == CyclingZone.State.SPENT), "spent once the ball leaves it unscored")
	assert_gt(_distance_to(zone), 49.5)

func test_zone_overlap_uses_the_true_ball() -> void:
	_technique.setup(_straight_technique(Vector2(150.0, 0.0)))
	var zone: CyclingZone = _zone(0)
	_technique.start_cycle()
	# The true ball at x 100.6 is 49.4 px from the zone (inside 49.5). It is
	# drawn at 100, 50 px away.
	_advance_straight_to(100.6, FAR)
	assert_eq(zone.get_state(), CyclingZone.State.ACTIVE)
	await _await_queued_frees()

func test_scoring_an_active_zone_uses_the_tier_rule() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	watch_signals(_technique)
	var distance: float = _distance_to(zone)
	var tier: CyclingRules.Tier = CyclingRules.tier_for_distance(distance)
	var xp: int = CyclingRules.xp_for_tier(zone.zone_data, tier)
	assert_true(_technique.try_score_zone(zone))
	assert_eq(zone.get_state(), CyclingZone.state_for_tier(tier))
	assert_signal_emit_count(_technique, "zone_scored", 1)
	assert_eq(get_signal_parameters(_technique, "zone_scored", 0), [zone, tier, xp])
	assert_eq(CultivationManager.get_core_density_xp(), float(xp), "the zone's XP goes to Core Density")
	var result: CycleResult = _technique.get_current_result()
	assert_eq(result.zones_scored, 1)
	assert_eq(result.xp, xp)

func test_a_closer_ball_scores_a_better_tier() -> void:
	# From the edge of the zone (OK), then inside 14 px (GOOD), then 6 px (PERFECT).
	for row: Array in [[0.0, CyclingZone.State.OK], [14.0, CyclingZone.State.GOOD], [6.0, CyclingZone.State.PERFECT]]:
		_technique.stop_cycling()
		var zone: CyclingZone = _approach_zone_0(row[0])
		assert_true(_technique.try_score_zone(zone))
		assert_eq(zone.get_state(), row[1], "a hit within %s px" % row[0])
	assert_eq(_technique.get_current_result().perfect_count, 1)

func test_score_distance_uses_the_true_ball() -> void:
	_technique.setup(_straight_technique(Vector2(106.5, 0.0)))
	var zone: CyclingZone = _zone(0)
	_technique.start_cycle()
	# The true ball at x 100.6 is 5.9 px from the zone: PERFECT (under 6). It is
	# drawn at 100, 6.5 px away, which would be GOOD.
	_advance_straight_to(100.6, FAR)
	assert_true(_technique.try_score_zone(zone))
	assert_eq(zone.get_state(), CyclingZone.State.PERFECT)
	await _await_queued_frees()

func test_inactive_or_scored_zones_ignore_clicks() -> void:
	var zone: CyclingZone = _zone(0)
	assert_false(_technique.try_score_zone(zone), "no cycle runs")
	zone.set_state(CyclingZone.State.ACTIVE)
	assert_false(_technique.try_score_zone(zone), "no cycle runs, whatever the zone shows")
	zone.set_state(CyclingZone.State.IDLE)
	var active: CyclingZone = _approach_zone_0(0.0)
	assert_false(_technique.try_score_zone(_zone(1)), "zone 1 is idle")
	assert_true(_technique.try_score_zone(active))
	assert_false(_technique.try_score_zone(active), "a scored zone cannot score twice")

func test_a_zone_leaving_active_unscored_cannot_score() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_step_until(func() -> bool: return zone.get_state() == CyclingZone.State.SPENT))
	assert_false(_technique.try_score_zone(zone))
	assert_eq(_technique.get_current_result().zones_scored, 0)

func test_studs_stay_until_the_next_start() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	var stud: CyclingZone.State = zone.get_state()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	assert_false(_technique.is_cycling(), "precondition: the cycle ended")
	assert_eq(zone.get_state(), stud, "the stud stays after the cycle")
	assert_true(_technique.start_cycle())
	assert_eq(zone.get_state(), CyclingZone.State.IDLE, "the next start clears it")

func test_a_scored_zone_shows_in_the_result() -> void:
	watch_signals(_technique)
	var zone: CyclingZone = _approach_zone_0(6.0)
	assert_true(_technique.try_score_zone(zone))
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	var result := get_signal_parameters(_technique, "cycle_completed", 0)[0] as CycleResult
	assert_eq(result.zones_scored, 1)
	assert_eq(result.perfect_count, 1)
	assert_eq(result.xp, 25)
	assert_eq(result.result_line(), "Last cycle · +0 Madra · 1 / 4 zones · 1 PERFECT · +25 XP")

func test_pointer_over_the_ball_while_a_press_would_do_something() -> void:
	var ball: Vector2 = _technique.get_ball_global_position()
	assert_true(_technique.wants_pointer(ball), "over the ready ball: a press starts a cycle")
	assert_true(_technique.wants_pointer(ball + Vector2(29.0, 0.0)), "inside the ball's radius")
	assert_false(_technique.wants_pointer(ball + Vector2(40.0, 0.0)), "40 px away")
	_technique.start_cycle()
	_technique.advance(FRAME, FAR)
	assert_false(_technique.wants_pointer(_technique.get_ball_global_position()), "no zone is active: a press does nothing")
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.wants_pointer(_technique.get_ball_global_position()), "over the ball while a zone is active: a press scores it")
	assert_false(_technique.wants_pointer(zone.global_position), "the zone itself takes no press")
	assert_false(_technique.wants_pointer(_zone(1).global_position), "nor does an idle one")

#-----------------------------------------------------------------------------
# ENDING, SWITCHING AND AUTO
#-----------------------------------------------------------------------------

func test_switching_technique_mid_cycle_ends_quietly() -> void:
	watch_signals(_technique)
	_technique.start_cycle()
	_run(1.0, 60.0, true)
	_technique.setup(load(FOUNDATION_PATH))
	assert_signal_not_emitted(_technique, "cycle_completed")
	assert_false(_technique.is_cycling())
	assert_false(CyclingManager.is_cycle_running())
	assert_eq(_technique.cycling_zones.size(), 0, "foundation has no zones")
	assert_eq(_technique.get_ball_global_position(), Vector2(322.0, 400.0), "the ball waits at the new path's start")
	assert_eq(CyclingManager.get_madra_rate(), 0.0)
	await _await_queued_frees()

func test_switching_rebuilds_the_zones() -> void:
	var old_zone: CyclingZone = _zone(0)
	_technique.setup(load(SMOOTH_FLOW_PATH))
	assert_eq(_technique.cycling_zones.size(), 4)
	assert_ne(_zone(0), old_zone, "the zones are new")
	assert_false(old_zone.is_inside_tree(), "the old zones are out of the tree at once")
	var hanging: int = 0
	for child: Node in _node("CyclingPath2D").get_children():
		if child is CyclingZone:
			hanging += 1
	assert_eq(hanging, 4, "only the new zones hang under the path")
	await _await_queued_frees()

func test_stop_resets_zones() -> void:
	# Review Focus 5.
	var zone: CyclingZone = _zone(0)
	_technique.start_cycle()
	assert_true(_step_until(func() -> bool: return zone.get_state() == CyclingZone.State.SPENT), "precondition: a zone is spent")
	var groove := _node("CyclingGroove") as CyclingGroove
	assert_gt(groove.get_lit_count(), 0, "precondition: the groove is lit behind the ball")
	watch_signals(_technique)
	_technique.stop_cycling()
	for other: CyclingZone in _technique.cycling_zones:
		assert_eq(other.get_state(), CyclingZone.State.IDLE, "%s is idle" % other.name)
	assert_eq(groove.get_lit_count(), groove.get_cell_count(), "the groove shows lit again, as between cycles")
	assert_eq(_technique.get_ball_global_position(), START)
	assert_false(_technique.is_cycling())
	assert_false(CyclingManager.is_cycle_running())
	assert_signal_not_emitted(_technique, "cycle_completed")

func test_stop_after_a_cycle_clears_the_studs_and_keeps_the_groove_lit() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	var groove := _node("CyclingGroove") as CyclingGroove
	assert_eq(groove.get_lit_count(), groove.get_cell_count(), "precondition: the whole groove is lit")
	_technique.stop_cycling()
	assert_eq(zone.get_state(), CyclingZone.State.IDLE)
	assert_eq(groove.get_lit_count(), groove.get_cell_count())

func test_auto_chains_cycles() -> void:
	watch_signals(_technique)
	_technique.auto_cycle = true
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	assert_signal_emit_count(_technique, "cycle_completed", 1)
	assert_signal_emit_count(_technique, "cycling_started", 2)
	assert_true(_technique.is_cycling(), "the next cycle started at once")
	for zone: CyclingZone in _technique.cycling_zones:
		assert_ne(zone.get_state(), CyclingZone.State.SPENT, "the studs reset with the new cycle")

func test_a_frame_hitch_spends_skipped_zones() -> void:
	# Review Focus 1: a frame that jumps past the whole cycle spends every zone.
	watch_signals(_technique)
	_technique.start_cycle()
	_technique.advance(16.0, FAR)
	assert_signal_emit_count(_technique, "cycle_completed", 1)
	for zone: CyclingZone in _technique.cycling_zones:
		assert_eq(zone.get_state(), CyclingZone.State.SPENT, "%s is spent" % zone.name)
	assert_false(_technique.is_cycling())
	var ring := _node("BallRing") as LacquerStripRect
	assert_eq(_technique.get_ball_global_position(), START, "the ball is back at the start in that same frame")
	assert_true(ring.visible)
	assert_eq(ring.get_frame(), Vector2i(0, 0))

func test_a_long_hitch_lights_the_whole_groove() -> void:
	# Past the end the ease stops at 1. Unclamped, two cycles' time would bring the
	# ball back to the start with the groove dark.
	var groove := _node("CyclingGroove") as CyclingGroove
	_technique.start_cycle()
	_technique.advance(CYCLE_SECONDS * 2.0, FAR)
	assert_false(_technique.is_cycling())
	assert_eq(groove.get_lit_count(), groove.get_cell_count())

func test_a_technique_set_up_while_another_cycles_leaves_its_session() -> void:
	# The session belongs to the technique that started it. Another technique's
	# setup() (the one its _ready() runs, too) and stop end only a session of its own.
	_technique.start_cycle()
	_run(1.0, 60.0, true)
	assert_almost_eq(CyclingManager.get_madra_rate(), MADRA_RATE, 0.001, "precondition: the session shows the cycle's rate")
	var other: CyclingTechnique = TECHNIQUE_SCENE.instantiate() as CyclingTechnique
	other.technique_data_input = load(FOUNDATION_PATH)
	add_child_autofree(other)
	other.set_process(false)
	assert_true(CyclingManager.is_cycle_running(), "another technique loading leaves the session")
	other.setup(load(SMOOTH_FLOW_PATH))
	other.stop_cycling()
	assert_true(CyclingManager.is_cycle_running(), "and so do its setup() and stop_cycling()")
	assert_almost_eq(CyclingManager.get_madra_rate(), MADRA_RATE, 0.001, "the rate is still the cycle's")
	assert_almost_eq(CyclingManager.get_cycle_elapsed(), 1.0, 0.001, "and so is the time")

func test_a_technique_freed_mid_cycle_ends_its_session() -> void:
	_technique.start_cycle()
	_run(1.0, 60.0, true)
	assert_true(CyclingManager.is_cycle_running(), "precondition: the session runs")
	_technique.free()
	assert_false(CyclingManager.is_cycle_running(), "the session ends with the technique")
	assert_eq(CyclingManager.get_madra_rate(), 0.0)

func test_the_exported_technique_is_set_up_when_the_scene_loads() -> void:
	var loaded: CyclingTechnique = TECHNIQUE_SCENE.instantiate() as CyclingTechnique
	loaded.technique_data_input = load(SMOOTH_FLOW_PATH)
	add_child_autofree(loaded)
	loaded.set_process(false)
	assert_eq(loaded.technique_data, load(SMOOTH_FLOW_PATH))
	assert_eq(loaded.cycling_zones.size(), 4)
	assert_eq(loaded.get_ball_global_position(), START)

#-----------------------------------------------------------------------------
# DRAWING AND THE SNAPSHOT
#-----------------------------------------------------------------------------

func test_ball_is_drawn_on_even_px() -> void:
	var sprite := _node("BallSprite") as LacquerStripRect
	var ring := _node("BallRing") as LacquerStripRect
	_technique.start_cycle()
	for _frame: int in 120:
		_technique.advance(FRAME, _technique.get_ball_global_position())
		for control: Control in [sprite, ring]:
			assert_eq(fposmod(control.global_position.x, 2.0), 0.0, "%s x is even" % control.name)
			assert_eq(fposmod(control.global_position.y, 2.0), 0.0, "%s y is even" % control.name)
	assert_ne(_technique.get_ball_global_position(), START, "precondition: the ball moved")

func test_ball_sprite_and_ring_are_centred_on_the_drawn_ball() -> void:
	var sprite := _node("BallSprite") as LacquerStripRect
	var ring := _node("BallRing") as LacquerStripRect
	_technique.start_cycle()
	_run(3.0, 60.0, false)
	var ball: Vector2 = _technique.get_ball_global_position()
	assert_eq(sprite.global_position + sprite.size / 2.0, ball)
	assert_eq(ring.global_position + ring.size / 2.0, ball)

func test_swirl_steps_ten_frames_a_second_ready_or_cycling() -> void:
	var sprite := _node("BallSprite") as LacquerStripRect
	_technique.advance(0.05, FAR)
	assert_eq(sprite.get_frame(), Vector2i(0, 0))
	for running: bool in [false, true]:
		if running:
			_technique.start_cycle()
		# Each step lands mid-frame: the clock is 0.05 + 0.1 k seconds.
		for step: int in range(1, 11):
			_technique.advance(0.1, FAR)
			assert_eq(sprite.get_frame().x, (step + (10 if running else 0)) % 8, "frame at step %d (running %s)" % [step, running])

func test_the_groove_shows_lit_before_the_first_cycle() -> void:
	var groove := _node("CyclingGroove") as CyclingGroove
	assert_gt(groove.get_cell_count(), 0, "precondition: the path has cells")
	assert_eq(groove.get_lit_count(), groove.get_cell_count(), "lit as a full cycle leaves it")
	_technique.advance(FRAME, FAR)
	assert_eq(groove.get_lit_count(), groove.get_cell_count(), "and it stays lit while the ball waits")

func test_groove_lights_behind_the_ball() -> void:
	var groove := _node("CyclingGroove") as CyclingGroove
	var total: int = groove.get_cell_count()
	_technique.start_cycle()
	assert_eq(groove.get_lit_count(), total, "the last cycle's light shows as the cycle starts")
	_run(1.0, 60.0, false)
	var trail: int = groove.get_lit_count()
	assert_gt(trail, 0, "once the sweep is done the ball's trail is lit")
	assert_lt(trail, total / 10, "and only that, still short a second in")
	_run(4.0, 60.0, false)
	assert_gt(groove.get_lit_count(), trail, "the trail grows behind the ball")
	assert_lt(groove.get_lit_count(), total)
	_run(CYCLE_SECONDS - 5.0 + FRAME, 60.0, false)
	assert_eq(groove.get_lit_count(), total, "the whole groove is lit at the end")
	_technique.start_cycle()
	assert_eq(groove.get_lit_count(), total, "and it stays lit as the next cycle starts, until the sweep")

func test_a_start_sweeps_the_old_light_away_ahead_of_the_ball() -> void:
	var groove := _node("CyclingGroove") as CyclingGroove
	var total: int = groove.get_cell_count()
	_technique.start_cycle()
	_run(CyclingTechnique.GROOVE_SWEEP_SECONDS / 2.0, 60.0, false)
	var mid_sweep: int = groove.get_lit_count()
	assert_lt(mid_sweep, total * 0.7, "half way through the sweep, about half the groove is dark")
	assert_gt(mid_sweep, total * 0.3, "and the far half keeps the old light")
	_run(CyclingTechnique.GROOVE_SWEEP_SECONDS / 2.0 + FRAME, 60.0, false)
	assert_lt(groove.get_lit_count(), total / 10, "the sweep is done in GROOVE_SWEEP_SECONDS, leaving the trail")

func test_ball_follows_the_eased_path() -> void:
	_technique.start_cycle()
	_run(CYCLE_SECONDS / 2.0, 60.0, false)
	var follow := _node("PathFollow2D") as PathFollow2D
	assert_almost_eq(follow.progress_ratio, 0.5, 0.001, "half way through at half the time")
	_technique.stop_cycling()
	assert_eq(follow.progress_ratio, 0.0)

func test_session_snapshot_follows_the_cycle() -> void:
	_technique.start_cycle()
	_run(6.0, 60.0, false)
	assert_true(CyclingManager.is_cycle_running())
	assert_almost_eq(CyclingManager.get_cycle_progress(), 0.4, 0.001)
	assert_eq(CyclingManager.get_cycle_duration(), CYCLE_SECONDS)
	_run(CYCLE_SECONDS - 6.0 + FRAME, 60.0, false)
	assert_false(CyclingManager.is_cycle_running())

#-----------------------------------------------------------------------------
# WITH THE CABINET
#-----------------------------------------------------------------------------

## Closing cycling while the Aura Well is the zone's idle action. stop_action()
## makes ActionManager emit stop_cycling, which the view hands to the technique:
## it ends the cycle's session (announcing a rate of 0), and only then does the
## Aura Well resume. The cabinet reads the rate off ActionManager each time the
## session announces one, so neither that order nor a late end_cycle_session()
## can leave the cycle's 0 on the Aura Well's "+1.5 / s".
func test_the_aura_well_rate_survives_closing_cycling() -> void:
	var plate: CultivatorPlate = add_child_autofree(PLATE_SCENE.instantiate())
	var rate := plate.get_node("%RateLabel") as RichTextLabel
	ActionManager.stop_cycling.connect(_technique.stop_cycling)
	EventManager.trigger_event("aura_well_discovered")
	assert_eq(ActionManager.get_current_action().action_id, "aura_well_training", "precondition: the Aura Well runs")
	assert_eq(rate.get_parsed_text(), "+1.5 / s")
	ActionManager.select_action(ZoneManager.get_action_by_id("wilderness_cycling_action"))
	_technique.start_cycle()
	_run(2.0, 60.0, true)
	assert_true(rate.visible, "precondition: the cabinet shows the cycle's rate")
	assert_ne(rate.get_parsed_text(), "+1.5 / s")
	ActionManager.stop_action()
	assert_eq(ActionManager.get_current_action().action_id, "aura_well_training", "the Aura Well resumed")
	assert_false(CyclingManager.is_cycle_running())
	assert_eq(rate.get_parsed_text(), "+1.5 / s")
	CyclingManager.start_cycle_session(15.0)
	CyclingManager.update_cycle_session(1.0, 5.0)
	CyclingManager.end_cycle_session()
	assert_true(rate.visible)
	assert_eq(rate.get_parsed_text(), "+1.5 / s", "a late end of a session leaves it")

#-----------------------------------------------------------------------------
# THE SCENES
#-----------------------------------------------------------------------------

func test_ball_shape_radius_is_the_ball_radius() -> void:
	var shape := (_node("MadraBall").get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	assert_eq(shape.radius, CyclingTechnique.BALL_RADIUS)

func test_the_ball_is_the_only_click_target() -> void:
	assert_true((_node("MadraBall") as Area2D).input_pickable)
	for zone: CyclingZone in _technique.cycling_zones:
		var node: Node = zone
		assert_false(node is CollisionObject2D, "%s takes no press of its own" % zone.name)
		assert_eq(zone.find_children("*", "CollisionObject2D", true, false).size(), 0, "nor does anything inside it")

func test_controls_inside_the_technique_ignore_the_mouse() -> void:
	# A Control that stops the mouse marks the press handled, and physics
	# picking never sees a handled press.
	var controls: Array[Node] = _technique.find_children("*", "Control", true, false)
	assert_eq(controls.size(), 6, "the ring, the ball and four sockets")
	for control: Node in controls:
		assert_eq((control as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % control.name)

func test_positions_and_sizes_are_even() -> void:
	var controls: Array[Node] = _technique.find_children("*", "Control", true, false)
	for control: Node in controls:
		var rect := control as Control
		assert_eq(fposmod(rect.global_position.x, 2.0), 0.0, "%s x is even" % rect.name)
		assert_eq(fposmod(rect.global_position.y, 2.0), 0.0, "%s y is even" % rect.name)
		assert_eq(fposmod(rect.size.x, 2.0), 0.0, "%s width is even" % rect.name)
		assert_eq(fposmod(rect.size.y, 2.0), 0.0, "%s height is even" % rect.name)

func test_the_scene_no_longer_uses_the_old_art_and_shaders() -> void:
	var text: String = FileAccess.get_file_as_string("res://scenes/cycling/cycling_technique/cycling_technique.tscn")
	text += FileAccess.get_file_as_string("res://scenes/cycling/cycling_technique/cycling_zone.tscn")
	for retired: String in ["torrential_flow", "torrential_curve", "Madra-Ball.png", "madra_ball", "cycling_zone.gdshader", "ShaderMaterial"]:
		assert_false(text.contains(retired), "the scenes no longer name %s" % retired)

#-----------------------------------------------------------------------------
# THE ZONE
#-----------------------------------------------------------------------------

func test_zone_shows_its_state_as_a_frame() -> void:
	var zone: CyclingZone = _zone(0)
	var socket := zone.get_node("%Socket") as LacquerStripRect
	assert_eq(socket.frame_size, ZONE_FRAME_SIZE)
	assert_eq(socket.position, Vector2(-24.0, -24.0))
	for state: int in CyclingZone.State.values():
		zone.set_state(state as CyclingZone.State)
		assert_eq(zone.get_state(), state)
		assert_eq(socket.get_frame(), Vector2i(state, 0), "state %d is frame %d" % [state, state])

func test_zone_is_open_while_idle_or_active() -> void:
	var zone: CyclingZone = _zone(0)
	var open: Array[CyclingZone.State] = [CyclingZone.State.IDLE, CyclingZone.State.ACTIVE]
	for state: int in CyclingZone.State.values():
		zone.set_state(state as CyclingZone.State)
		assert_eq(zone.is_open(), state in open, "state %d" % state)

func test_state_for_tier() -> void:
	assert_eq(CyclingZone.state_for_tier(CyclingRules.Tier.PERFECT), CyclingZone.State.PERFECT)
	assert_eq(CyclingZone.state_for_tier(CyclingRules.Tier.GOOD), CyclingZone.State.GOOD)
	assert_eq(CyclingZone.state_for_tier(CyclingRules.Tier.OK), CyclingZone.State.OK)

func test_zone_is_placed_at_its_data_position() -> void:
	for index: int in _technique.cycling_zones.size():
		assert_eq(_zone(index).position, _zone(index).zone_data.position)
		assert_eq(_zone(index).zone_data, (load(SMOOTH_FLOW_PATH) as CyclingTechniqueData).cycling_zones[index])

#-----------------------------------------------------------------------------
# PRESSES ON THE BALL
#-----------------------------------------------------------------------------

func test_a_left_press_on_the_ball_starts_a_cycle() -> void:
	var ball := _node("MadraBall") as Area2D
	var release: InputEventMouseButton = _left_press()
	release.pressed = false
	ball.input_event.emit(get_viewport(), release, 0)
	assert_false(_technique.is_cycling(), "a release does not start it")
	ball.input_event.emit(get_viewport(), _left_press(), 0)
	assert_true(_technique.is_cycling())

func test_a_press_on_the_ball_scores_the_active_zone() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	var tier: CyclingRules.Tier = CyclingRules.tier_for_distance(_distance_to(zone))
	watch_signals(_technique)
	(_node("MadraBall") as Area2D).input_event.emit(get_viewport(), _left_press(), 0)
	assert_signal_emit_count(_technique, "zone_scored", 1)
	assert_eq(get_signal_parameters(_technique, "zone_scored", 0)[0], zone)
	assert_eq(zone.get_state(), CyclingZone.state_for_tier(tier), "the tier still comes from the ball's distance to the zone")
	assert_true(_technique.is_cycling(), "the cycle runs on")

func test_press_ball_starts_from_ready_then_scores() -> void:
	assert_true(_technique.press_ball(), "from ready it starts a cycle")
	assert_true(_technique.is_cycling())
	assert_false(_technique.press_ball(), "mid-cycle with no zone active it does nothing")
	assert_true(_technique.is_cycling(), "and does not restart the cycle")
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.press_ball(), "over an active zone it scores it")
	assert_false(zone.is_open())
	assert_false(_technique.press_ball(), "a scored zone cannot score again")

func test_a_press_scores_the_active_zone_nearest_the_ball() -> void:
	# The true ball at x 100.6 has the zone at 70 30.6 px away and the zone at
	# 140 39.4 px away: both are active, and the nearer one scores.
	_technique.setup(_straight_technique_with_zones([Vector2(140.0, 0.0), Vector2(70.0, 0.0)]))
	_technique.start_cycle()
	_advance_straight_to(100.6, FAR)
	assert_eq(_zone(0).get_state(), CyclingZone.State.ACTIVE, "precondition: the far zone is active")
	assert_eq(_zone(1).get_state(), CyclingZone.State.ACTIVE, "precondition: the near zone is active")
	assert_true(_technique.press_ball())
	assert_false(_zone(1).is_open(), "the nearer zone scored")
	assert_true(_zone(0).is_open(), "the farther one is still open")
	await _await_queued_frees()

func test_physics_picking_delivers_a_press_on_the_ball() -> void:
	await _press_at(_technique.get_ball_global_position())
	assert_true(_technique.is_cycling(), "a press on the ready ball starts the cycle")

func test_physics_picking_ignores_a_press_off_the_ball() -> void:
	await _press_at(_technique.get_ball_global_position() + Vector2(60.0, 0.0))
	assert_false(_technique.is_cycling())

func test_physics_picking_scores_through_the_ball() -> void:
	_approach_zone_0(0.0)
	watch_signals(_technique)
	await _press_at(_technique.get_ball_global_position())
	assert_signal_emit_count(_technique, "zone_scored", 1)

func test_physics_picking_ignores_a_press_on_a_zone_off_the_ball() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_gt(zone.global_position.distance_to(_technique.get_ball_global_position()), CyclingTechnique.BALL_RADIUS, "precondition: the zone's centre is off the ball")
	watch_signals(_technique)
	await _press_at(zone.global_position)
	assert_signal_not_emitted(_technique, "zone_scored")
	assert_true(zone.is_open())
