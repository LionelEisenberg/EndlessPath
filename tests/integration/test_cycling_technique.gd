extends GutTest

## Integration tests for the play of a cycling technique: CyclingTechnique (the
## Madra ball travelling its path, the Madra drawn while the cursor follows
## it, the zones along the path, a press on the ball, and a cycle's start, end
## and result) and CyclingZone (the states that can still score). A cycle is stepped by
## calling advance() with a chosen cursor, as _process() calls it with the
## mouse. The technique under test is smooth_flow unless a test says otherwise:
## a 15 s cycle of 80 Madra with 4 zones, on a fresh save (25 Madra, max 100).

const TECHNIQUE_SCENE: PackedScene = preload("res://scenes/cycling/cycling_technique/cycling_technique.tscn")
const SMOOTH_FLOW_PATH: String = "res://resources/cycling/cycling_techniques/smooth_flow/smooth_flow.tres"
const FOUNDATION_PATH: String = "res://resources/cycling/cycling_techniques/foundation_cycling_technique/foundation_cycling_technique.tres"
const PLATE_SCENE: PackedScene = preload("res://scenes/zones/cultivator_plate/cultivator_plate.tscn")

## A cursor far from the ball and from every zone.
const FAR: Vector2 = Vector2(-9999.0, -9999.0)

## The stat smooth_flow's zones pay.
const CONTROL := CharacterAttributesData.AttributeType.CONTROL

## One frame at 60 FPS. A cycle is run for its duration plus one frame, because
## 900 sums of 1 / 60 can land a hair under 15.
const FRAME: float = 1.0 / 60.0
const CYCLE_SECONDS: float = 15.0

## The Madra one step draws: base_madra_per_cycle * 0.08 / cycle_duration.
const MADRA_STEP: float = 80.0 * 0.08 / 15.0

## The Madra steady tracking draws a second: base_madra_per_cycle / cycle_duration.
const MADRA_RATE: float = 80.0 / 15.0

## Where the ball waits: the first point of smooth_path.tres, on even px.
const START: Vector2 = Vector2(320.0, 464.0)

## The modifier source _make_room() raises the max Madra stat under.
const ROOM_SOURCE: StringName = &"test_cycling_technique_room"
const CoreCurve := preload("res://tests/helpers/core_curve.gd")

var _technique: CyclingTechnique = null
## The real stages, put back after each test (CoreCurve).
var _original_stages: Array[AdvancementStageResource]

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_stages = CoreCurve.use_fixed_curve()
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_technique = TECHNIQUE_SCENE.instantiate() as CyclingTechnique
	add_child_autofree(_technique)
	# Only the steps these tests take move the cycle, never the real mouse.
	_technique.set_process(false)
	_technique.setup(load(SMOOTH_FLOW_PATH))

func after_each() -> void:
	CoreCurve.restore(_original_stages)
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	# A cycle session left running would leak into later files.
	CyclingManager.end_cycle_session()
	CharacterManager.remove_modifier_source(ROOM_SOURCE)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Steps `seconds` of frames at `fps`, with the cursor on the ball (the drawn
## centre) or far away.
func _run(seconds: float, fps: float, track: bool) -> void:
	for _frame: int in roundi(seconds * fps):
		_technique.advance(1.0 / fps, _technique.get_ball_global_position() if track else FAR)

## Steps `seconds` of 60 FPS frames with the cursor `offset` from the ball.
func _run_off_the_ball(seconds: float, offset: Vector2) -> void:
	for _frame: int in roundi(seconds * 60.0):
		_technique.advance(FRAME, _technique.get_ball_global_position() + offset)

## Steps 60 FPS frames with the cursor far away until `done` returns true, the
## cycle ends or `limit` seconds pass. Returns whether `done` is true.
func _step_until(done: Callable, limit: float = 20.0) -> bool:
	for _frame: int in roundi(limit * 60.0):
		if done.call() or not _technique.is_cycling():
			break
		_technique.advance(FRAME, FAR)
	return done.call()

## A modifier source that adds `amount` to the max Madra stat.
func _max_madra_source(amount: float) -> Callable:
	return func() -> Array[StatModifierData]:
		var modifiers: Array[StatModifierData] = [StatModifierData.new(StatModifierData.Stat.MAX_MADRA, StatModifierData.Kind.FLAT, amount)]
		return modifiers

## Raises the max Madra stat by `amount`, so a cycle's Madra has room under it.
func _make_room(amount: float) -> void:
	CharacterManager.set_modifier_source(ROOM_SOURCE, _max_madra_source(amount))

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
	_technique.madra_particle_requested.connect(func(_from_pos: Vector2, _amount: float) -> void: count[0] += 1)
	return count

## Swaps the fixture's technique for a new one playing foundation_technique: a
## 10 s cycle of 37.5 Madra in 125 steps of 0.3, no zones, on a path that ends
## where it starts. It is built with the technique, so no old zones are thrown
## away.
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

## Returns the second of a cycle `duration` long at which the eased ball
## (CyclingRules.eased_ratio()) has covered `ratio` of the path, found by halving.
func _seconds_to_reach(ratio: float, duration: float) -> float:
	var low: float = 0.0
	var high: float = duration
	for _step: int in 60:
		var middle: float = (low + high) / 2.0
		if CyclingRules.eased_ratio(middle, duration) < ratio:
			low = middle
		else:
			high = middle
	return (low + high) / 2.0

## Runs the straight technique's 10 s cycle for one frame that carries the true
## ball to `x` on the path, with the cursor at `cursor`.
func _advance_straight_to(x: float, cursor: Vector2) -> void:
	_technique.advance(_seconds_to_reach(x / 1000.0, 10.0), cursor)

#-----------------------------------------------------------------------------
# CYCLE LIFECYCLE
#-----------------------------------------------------------------------------

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
	for zone: CyclingZone in _technique.cycling_zones:
		assert_eq(zone.get_state(), CyclingZone.State.SPENT, "%s is spent" % zone.name)
	assert_false(_technique.is_cycling())

func test_ball_waits_at_the_start_when_the_cycle_ends() -> void:
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	assert_false(_technique.is_cycling(), "precondition: the cycle ended")
	assert_eq(_technique.get_ball_global_position(), START)

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

## Each request carries the Madra its step added, so the pellets carry the whole
## of what the cycle drew.
func test_pellets_carry_the_madra_their_step_added() -> void:
	var amounts: Array[float] = []
	_technique.madra_particle_requested.connect(func(_from_pos: Vector2, amount: float) -> void: amounts.append(amount))
	_technique.start_cycle()
	_run(0.5, 60.0, true)
	assert_gt(amounts.size(), 0, "precondition: the cursor drew Madra")
	var carried: float = 0.0
	for amount: float in amounts:
		assert_almost_eq(amount, MADRA_STEP, 0.001, "a full step")
		carried += amount
	assert_almost_eq(carried, _technique.get_current_result().madra_added, 0.0001, "the pellets carry all the Madra drawn")

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
	assert_eq(ResourceManager.get_max_madra(), 100.0, "precondition: the max is 100")
	_technique.start_cycle()
	_run(1.0, 60.0, true)
	assert_signal_not_emitted(_technique, "madra_particle_requested")
	assert_eq(ResourceManager.get_madra(), 100.0)
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
	# A step is 0.427: from 99.2 the first fits whole and the second fills the
	# last 0.373.
	ResourceManager.set_madra(99.2)
	_technique.start_cycle()
	_run(1.0, 60.0, true)
	assert_signal_emit_count(_technique, "madra_particle_requested", 2)
	assert_almost_eq(_technique.get_current_result().madra_added, 0.8, 0.000001)
	assert_eq(ResourceManager.get_madra(), 100.0)

func test_the_result_counts_the_madra_the_pool_gained() -> void:
	# add_madra() reports each step snapped to 0.001 (1.067 for 1.0667), and a
	# full cycle's 187 snapped steps sum to 79.85 for the 79.79 it adds. The
	# finished total is snapped to 0.0001, so it holds the gain to within that.
	_make_room(200.0)
	ResourceManager.set_madra(46.0)
	assert_gt(ResourceManager.get_max_madra(), 46.0 + 200.0, "precondition: the cycle never meets the max")
	watch_signals(_technique)
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, true)
	assert_signal_emit_count(_technique, "cycle_completed", 1)
	var result := get_signal_parameters(_technique, "cycle_completed", 0)[0] as CycleResult
	assert_almost_eq(result.madra_added, ResourceManager.get_madra() - 46.0, 0.0001, "the result holds what the pool gained")

func test_spirit_raises_the_madra_a_cycle_draws() -> void:
	# Spirit Lv 6 is 15, a multiplier of 1.5, so the Foundational Technique's
	# cycle of 37.5 draws 56.25. The level is set after the technique is ready: it
	# follows the stats change, not only what it read on ready.
	_make_room(500.0)
	ResourceManager.set_madra(0.0)
	_use_foundation()
	CharacterManager.set_stat_level(CharacterAttributesData.AttributeType.SPIRIT, 6)
	assert_eq(_track_one_cycle(func() -> float: return FRAME), 125, "precondition: the cycle's 125 steps")
	assert_almost_eq(_technique.get_current_result().madra_added, 56.25, 0.01, "37.5 Madra at 1.5x")

func test_the_rate_reads_madra_at_spirit() -> void:
	# At Spirit 15 steady tracking reads 1.5 x base_madra_per_cycle / cycle_duration.
	_make_room(500.0)
	CharacterManager.set_stat_level(CharacterAttributesData.AttributeType.SPIRIT, 6)
	_technique.start_cycle()
	_run(2.0, 60.0, true)
	assert_almost_eq(CyclingManager.get_madra_rate(), 1.5 * MADRA_RATE, 0.001)

func test_a_tracked_10_s_cycle_pays_its_last_step_at_120_fps() -> void:
	# A 10 s cycle holds exactly 125 steps of 0.08 s, so its 125th step falls on
	# its last instant. Float error in 1200 frames of 1 / 120 s must not cost it.
	_use_foundation()
	assert_eq(_track_one_cycle(func() -> float: return 1.0 / 120.0), 125, "125 steps at 120 FPS")
	assert_almost_eq(_technique.get_current_result().madra_added, 37.5, 0.000001, "the cycle's 37.5 Madra")
	assert_eq(roundi(_technique.get_current_result().madra_added), 38, "which the card and the log round up, as the drawer does")

func test_a_tracked_10_s_cycle_pays_125_steps_at_uneven_frame_times() -> void:
	# Frames of 1 / 120 to 1 / 40 s, drawn from fixed seeds.
	var rng := RandomNumberGenerator.new()
	for seed_value: int in [1, 2, 3, 4, 5]:
		rng.seed = seed_value
		ResourceManager.set_madra(25.0)
		_use_foundation()
		assert_eq(_track_one_cycle(func() -> float: return rng.randf_range(0.5, 1.5) / 60.0), 125, "125 steps with seed %d" % seed_value)

func test_a_hitch_through_the_end_pays_only_the_steps_left() -> void:
	# 2 s of tracking pay 25 of the cycle's 125 steps. A 16 s frame then covers 200
	# steps with the cursor on the ball (the path ends where it starts), but only
	# 8 s of it, 100 steps, were left in the cycle.
	_make_room(500.0)
	assert_eq(ResourceManager.get_max_madra(), 600.0, "precondition: the max does not bound the hitch")
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
	assert_eq(pellets[0], 125, "the 100 steps left in the cycle, not the 200 the frame covers")
	assert_almost_eq(_technique.get_current_result().madra_added, 37.5, 0.000001)

#-----------------------------------------------------------------------------
# THE MADRA RATE
#-----------------------------------------------------------------------------

## The rate the cabinet and the tray show is time-weighted over the last
## RATE_WINDOW seconds of the cycle: the Madra the cursor drew in them over the
## time they cover. It does not count the 0.08 s steps (a window holds 12 or 13 of
## them, which would flicker between +12.8 and +13.9).

func test_rate_holds_steady_while_tracking() -> void:
	# Steady tracking reads base_madra_per_cycle / cycle_duration at any frame
	# rate, from the first frame on (5.333 reads +5.3).
	for fps: float in [30.0, 60.0, 144.0]:
		_technique.stop_cycling()
		ResourceManager.set_madra(25.0)
		_technique.start_cycle()
		var off: int = 0
		var last: float = 0.0
		for _frame: int in roundi(3.0 * fps):
			_technique.advance(1.0 / fps, _technique.get_ball_global_position())
			last = CyclingManager.get_madra_rate()
			if not is_equal_approx(snappedf(last, 0.1), 5.3):
				off += 1
		assert_eq(off, 0, "frames of 3 s at %d FPS whose rate did not read 5.3" % fps)
		assert_almost_eq(last, MADRA_RATE, 0.001, "exactly base_madra_per_cycle / cycle_duration at %d FPS" % fps)

func test_rate_falls_to_zero_once_tracking_stops() -> void:
	for fps: float in [30.0, 60.0, 144.0]:
		_technique.stop_cycling()
		ResourceManager.set_madra(25.0)
		_technique.start_cycle()
		_run(1.0, fps, true)
		assert_gt(CyclingManager.get_madra_rate(), 0.0, "precondition: the cursor draws at %d FPS" % fps)
		_run(CyclingRules.FOLLOW_GRACE + CyclingTechnique.RATE_WINDOW + 1.0 / fps, fps, false)
		assert_eq(CyclingManager.get_madra_rate(), 0.0, "the grace, RATE_WINDOW and a frame after the cursor left, at %d FPS" % fps)

func test_rate_rises_and_falls_within_a_second() -> void:
	# A cursor that catches the ball mid-cycle follows at once, so a window half
	# followed reads half the steady rate.
	_technique.start_cycle()
	_run(1.0, 60.0, false)
	assert_eq(CyclingManager.get_madra_rate(), 0.0, "nothing is drawn yet")
	_run(0.5, 60.0, true)
	assert_almost_eq(CyclingManager.get_madra_rate(), MADRA_RATE / 2.0, 0.1, "half a second of following")
	_run(0.5, 60.0, true)
	assert_almost_eq(CyclingManager.get_madra_rate(), MADRA_RATE, 0.001, "a second of following")
	_run(0.5, 60.0, false)
	assert_almost_eq(CyclingManager.get_madra_rate(), MADRA_RATE * (0.5 + CyclingRules.FOLLOW_GRACE), 0.1, "half a second after it stopped, the grace still drawn")

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
	ResourceManager.set_madra(99.7)
	_technique.start_cycle()
	_run(5.0 / 60.0, 60.0, true)
	assert_eq(ResourceManager.get_madra(), 100.0, "precondition: the fifth frame's step filled the cap")
	assert_almost_eq(CyclingManager.get_madra_rate(), MADRA_RATE, 0.001)

func test_auto_restart_keeps_the_rate() -> void:
	# The restart happens inside the advance() that ends the cycle. The cabinet
	# reads the rate off the session each time it announces one, so a session
	# that read 0 until the next frame would blink the label out for a frame.
	_make_room(500.0)
	assert_eq(ResourceManager.get_max_madra(), 600.0, "precondition: a whole cycle of Madra fits under the max")
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
	assert_almost_eq(snappedf(CyclingManager.get_madra_rate(), 0.1), 5.3, 0.000001, "the rate carries into it")
	_technique.advance(FRAME, _technique.get_ball_global_position())
	assert_true(CyclingManager.is_cycle_running())
	assert_almost_eq(snappedf(CyclingManager.get_madra_rate(), 0.1), 5.3, 0.000001, "and the frame after")
	assert_eq(completed[0], 1)

func test_a_manual_start_begins_from_an_empty_window() -> void:
	# A cycle that ends without Auto, like one that is stopped, leaves no rate
	# behind for the next one.
	_make_room(500.0)
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
# FOLLOWING
#-----------------------------------------------------------------------------

## A cursor that catches the ball mid-cycle follows once it has moved with it for
## a quarter second; past the ring nothing follows.
## A cursor that moves onto the ball mid-cycle follows at once, anywhere in the
## gold circle; past the ring nothing follows.
func test_following_needs_the_cursor_in_the_ring() -> void:
	_technique.advance(FRAME, FAR)
	assert_false(_technique.is_following(), "no cycle runs")
	_technique.start_cycle()
	_technique.advance(FRAME, FAR)
	assert_false(_technique.is_following(), "the first frame is off the ball")
	_run(3.0, 60.0, false)
	_technique.advance(FRAME, _technique.get_ball_global_position())
	assert_true(_technique.is_following(), "catching the ball mid-cycle follows at once")
	# The ball moves a few px a frame here, so the offsets keep clear of the edge.
	_technique.advance(FRAME, _technique.get_ball_global_position() + Vector2(0.0, 24.0))
	assert_true(_technique.is_following(), "off the ball's centre, still in the ring, it follows")
	var past: Vector2 = Vector2(CyclingTechnique.CURSOR_REACH + 10.0, 0.0)
	_technique.advance(FRAME, _technique.get_ball_global_position() + past)
	assert_true(_technique.is_following(), "past the ring, the grace holds it a moment")
	_run_off_the_ball(CyclingRules.FOLLOW_GRACE, past)
	assert_false(_technique.is_following(), "once the grace runs out, past the ring nothing follows")

func test_on_the_ball_uses_the_drawn_ball() -> void:
	_technique.setup(_straight_technique(Vector2(5000.0, 0.0)))
	_technique.start_cycle()
	# The true ball is at x 100.6 and is drawn at 100. A cursor at x 64 is 36 px
	# from the drawn ball (on the ring's outer edge) and 36.6 px from the true one.
	# The press makes the first frame follow on the ball alone.
	_advance_straight_to(100.6, Vector2(64.0, 0.0))
	assert_eq(_technique.get_ball_global_position(), Vector2(100.0, 0.0))
	assert_true(_technique.is_following())
	await _await_queued_frees()

func test_the_cursor_follows_on_the_ring_and_not_past_it() -> void:
	# The solid ring the player follows is drawn out to 36 px, past the ball's own
	# 29.5, so a cursor on the ring follows and one past it does not.
	_technique.setup(_straight_technique(Vector2(5000.0, 0.0)))
	_technique.start_cycle()
	_advance_straight_to(100.6, Vector2(100.0, 33.0))
	assert_eq(_technique.get_ball_global_position(), Vector2(100.0, 0.0), "precondition: the ball is drawn at x 100")
	assert_true(_technique.is_following(), "33 px off, on the ring, the cursor follows")
	_technique.advance(CyclingRules.FOLLOW_GRACE + FRAME, Vector2(100.0, 37.0))
	assert_false(_technique.is_following(), "37 px off, past the ring and the grace, it does not")
	await _await_queued_frees()

## The Foundational path starts, crosses itself and ends at one point. A cursor
## that comes to rest there once the ball has left meets it twice more, at the
## crossing and at the end, and never follows: no ring, no Madra.
func test_a_cursor_resting_on_the_path_draws_nothing() -> void:
	_use_foundation()
	var resting: Vector2 = _technique.get_ball_global_position()
	var ring := _node("BallRing") as CanvasItem
	var pellets: Array[int] = _count_pellets()
	var met: int = 0
	var ringed: int = 0
	_technique.start_cycle()
	_run(1.0, 60.0, false)
	while _technique.is_cycling():
		_technique.advance(FRAME, resting)
		if resting.distance_to(_technique.get_ball_global_position()) <= CyclingTechnique.CURSOR_REACH:
			met += 1
		if _technique.is_cycling() and ring.visible:
			ringed += 1
	assert_gt(met, 0, "precondition: the ball ran through the resting cursor")
	assert_eq(pellets[0], 0, "no Madra step")
	assert_eq(ringed, 0, "and the ring never showed")

## After the press the cursor follows until the creeping ball leaves the ring,
## then never again: a few steps at the start, none at the crossing or the end.
func test_a_cursor_resting_after_the_press_draws_only_the_creeping_start() -> void:
	_use_foundation()
	var resting: Vector2 = _technique.get_ball_global_position()
	var steps_at: Array[float] = []
	_technique.madra_particle_requested.connect(func(_from_pos: Vector2, _amount: float) -> void: steps_at.append(CyclingManager.get_cycle_elapsed()))
	_technique.start_cycle()
	while _technique.is_cycling():
		_technique.advance(FRAME, resting)
	assert_gt(steps_at.size(), 0, "precondition: the press made the start follow")
	assert_lte(steps_at.size(), 12, "only the creeping start draws")
	assert_lt(steps_at.max(), 1.0, "and nothing once the ball has left the ring")

func test_auto_carries_following_into_the_next_cycle() -> void:
	_make_room(500.0)
	_use_foundation()
	_technique.auto_cycle = true
	var completed: Array[int] = [0]
	_technique.cycle_completed.connect(func(_result: CycleResult) -> void: completed[0] += 1)
	_technique.start_cycle()
	while completed[0] == 0:
		_technique.advance(FRAME, _technique.get_ball_global_position())
	assert_true(_technique.is_cycling(), "precondition: Auto started the next cycle")
	var pellets: Array[int] = _count_pellets()
	_run(0.5, 60.0, true)
	assert_true(_technique.is_following(), "the streak carried over")
	assert_gt(pellets[0], 0, "and the next cycle's start draws")

func test_auto_never_starts_following_for_a_resting_cursor() -> void:
	_make_room(500.0)
	_use_foundation()
	var resting: Vector2 = _technique.get_ball_global_position()
	_technique.auto_cycle = true
	var pellets: Array[int] = _count_pellets()
	var completed: Array[int] = [0]
	_technique.cycle_completed.connect(func(_result: CycleResult) -> void: completed[0] += 1)
	_technique.start_cycle()
	_run(1.0, 60.0, false)
	while completed[0] < 2:
		_technique.advance(FRAME, resting)
	assert_eq(pellets[0], 0, "two cycles of Auto drew nothing for a cursor that never moved")

#-----------------------------------------------------------------------------
# SPIRIT XP
#-----------------------------------------------------------------------------

## The Foundational pays 15 Spirit XP for a fully followed 10 s cycle: 1.5 a
## second, 0.75 every half second.
const SPIRIT_XP_PER_SECOND: float = 1.5
const SPIRIT := CharacterAttributesData.AttributeType.SPIRIT

## Spirit's XP toward its next level: every payment in these tests stays short of
## Lv 2's 100 XP.
func _spirit_xp() -> float:
	return CharacterManager.get_stat_xp(SPIRIT)

## The amounts of each stat_xp_paid the technique emitted since watch_signals().
func _paid_amounts() -> Array[float]:
	var amounts: Array[float] = []
	for index: int in get_signal_emit_count(_technique, "stat_xp_paid"):
		amounts.append(get_signal_parameters(_technique, "stat_xp_paid", index)[2])
	return amounts

func test_following_pays_spirit_xp_every_half_second() -> void:
	_use_foundation()
	watch_signals(_technique)
	_technique.start_cycle()
	_run(1.6, 60.0, true)
	assert_eq(get_signal_emit_count(_technique, "stat_xp_paid"), 3, "at 0.5, 1 and 1.5 s")
	for amount: float in _paid_amounts():
		assert_almost_eq(amount, 0.75, 0.0001, "half a second's Spirit XP")
	assert_eq(get_signal_parameters(_technique, "stat_xp_paid", 0)[0], SPIRIT)
	assert_almost_eq(_spirit_xp(), 2.25, 0.0001, "Spirit took all three")

func test_a_fully_followed_cycle_pays_its_spirit_xp() -> void:
	var rng := RandomNumberGenerator.new()
	var frame_times: Array[Dictionary] = [
		{"name": "30 FPS", "next": func() -> float: return 1.0 / 30.0},
		{"name": "60 FPS", "next": func() -> float: return 1.0 / 60.0},
		{"name": "144 FPS", "next": func() -> float: return 1.0 / 144.0},
		{"name": "uneven frames", "next": func() -> float: return rng.randf_range(0.5, 1.5) / 60.0},
	]
	for case: Dictionary in frame_times:
		rng.seed = 7
		CharacterManager.set_stat_level(SPIRIT, 1)
		_use_foundation()
		_track_one_cycle(case.next)
		var result: CycleResult = _technique.get_current_result()
		assert_almost_eq(_spirit_xp(), 15.0, 0.0001, "%s: Spirit took the cycle's 15 XP" % case.name)
		assert_almost_eq(result.get_stat_xp(SPIRIT), 15.0, 0.0001, "%s: and the result holds them" % case.name)
		assert_almost_eq(result.followed_ratio, 1.0, 0.01, "%s: the whole cycle was followed" % case.name)

func test_following_pays_spirit_xp_with_madra_full() -> void:
	ResourceManager.set_madra(ResourceManager.get_max_madra())
	_use_foundation()
	_track_one_cycle(func() -> float: return FRAME)
	assert_eq(_technique.get_current_result().madra_added, 0.0, "precondition: no Madra fit")
	assert_almost_eq(_spirit_xp(), 15.0, 0.0001, "following still paid its Spirit XP")

func test_a_resting_cursor_earns_no_spirit_xp() -> void:
	_use_foundation()
	var resting: Vector2 = _technique.get_ball_global_position()
	watch_signals(_technique)
	_technique.start_cycle()
	_run(1.0, 60.0, false)
	while _technique.is_cycling():
		_technique.advance(FRAME, resting)
	assert_signal_not_emitted(_technique, "stat_xp_paid")
	assert_eq(_spirit_xp(), 0.0)
	assert_eq(_technique.get_current_result().followed_ratio, 0.0)

func test_a_stopped_cycle_keeps_the_spirit_xp_it_followed() -> void:
	_use_foundation()
	watch_signals(_technique)
	_technique.start_cycle()
	_run(1.2, 60.0, true)
	_technique.stop_cycling()
	var amounts: Array[float] = _paid_amounts()
	assert_eq(amounts.size(), 3, "two half seconds, then the rest at the stop")
	assert_almost_eq(amounts[2], 0.3, 0.0001, "the 0.2 s followed since the last payment")
	assert_almost_eq(_spirit_xp(), 1.8, 0.0001, "1.2 s of following in all")

## A switch drops the Spirit XP of the half second not yet paid, so no pellet
## flies from a technique the board has left.
func test_a_switch_drops_the_spirit_xp_not_yet_paid() -> void:
	watch_signals(_technique)
	_technique.start_cycle()
	_run(1.2, 60.0, true)
	_technique.setup(load(FOUNDATION_PATH))
	assert_eq(get_signal_emit_count(_technique, "stat_xp_paid"), 2, "the two half seconds paid as they came, and nothing at the switch")
	assert_almost_eq(_spirit_xp(), 2.0, 0.0001, "Smooth Flow's 2 a second for one second; the 0.2 s after is dropped")
	await _await_queued_frees()

func test_spirit_xp_at_the_cap_marks_the_result() -> void:
	CharacterManager.set_stat_level(SPIRIT, CharacterManager.get_stat_level_cap())
	_use_foundation()
	watch_signals(_technique)
	_track_one_cycle(func() -> float: return FRAME)
	var result: CycleResult = _technique.get_current_result()
	assert_signal_not_emitted(_technique, "stat_xp_paid", "a capped stat takes nothing, so nothing is sent")
	assert_true(result.is_stat_capped(SPIRIT), "the cap took the cycle's Spirit XP")
	assert_eq(result.get_stat_xp(SPIRIT), 0.0)

func test_the_payment_that_reaches_the_cap_carries_only_what_it_took() -> void:
	# One XP short of the cap, the most set_stat_level() leaves: the first half
	# second's 0.75 fits, and the second's reaches the cap with 0.25 of it.
	var below_cap: int = CharacterManager.get_stat_level_cap() - 1
	CharacterManager.set_stat_level(SPIRIT, below_cap, CharacterManager.stat_progression.get_xp_to_next(below_cap) - 1.0)
	_use_foundation()
	watch_signals(_technique)
	_technique.start_cycle()
	_run(1.1, 60.0, true)
	var amounts: Array[float] = _paid_amounts()
	assert_eq(amounts.size(), 2, "precondition: two half seconds were paid")
	assert_almost_eq(amounts[0], 0.75, 0.0001, "the first fit whole")
	assert_almost_eq(amounts[1], 0.25, 0.0001, "the second carried only the 0.25 the cap left room for")
	assert_true(CharacterManager.is_stat_capped(SPIRIT))
	var result: CycleResult = _technique.get_current_result()
	assert_true(result.is_stat_capped(SPIRIT), "the cap took the rest")
	assert_almost_eq(result.get_stat_xp(SPIRIT), 1.0, 0.0001)

func test_a_hitch_through_the_end_pays_only_the_time_left() -> void:
	# 2 s of following pay four half seconds. A 16 s frame then follows to the
	# path's end, where it started, but only 8 s of it were left in the cycle:
	# one payment of 12 Spirit XP, 15 in all.
	_make_room(500.0)
	_use_foundation()
	var path_end: Vector2 = _technique.get_ball_global_position()
	watch_signals(_technique)
	_technique.start_cycle()
	_run(2.0, 60.0, true)
	assert_eq(get_signal_emit_count(_technique, "stat_xp_paid"), 4, "precondition: four half seconds paid")
	_technique.advance(16.0, path_end)
	assert_false(_technique.is_cycling(), "precondition: the frame ended the cycle")
	assert_eq(get_signal_emit_count(_technique, "stat_xp_paid"), 5, "the hitch paid once")
	assert_almost_eq(_spirit_xp(), 15.0, 0.0001, "the cycle's 15, not the 24 the frame covers")

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

## Smooth Flow trains Control: a hit pays its tier's XP to Control, and cycling
## pays no Core Density.
func test_scoring_an_active_zone_uses_the_tier_rule() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	watch_signals(_technique)
	var core_level: float = CultivationManager.get_core_density_level()
	var core_xp: float = CultivationManager.get_core_density_xp()
	var distance: float = _distance_to(zone)
	var tier: CyclingRules.Tier = CyclingRules.tier_for_distance(distance)
	var xp: int = CyclingRules.xp_for_tier(zone.zone_data, tier)
	assert_true(_technique.try_score_zone(zone))
	assert_eq(zone.get_state(), CyclingZone.state_for_tier(tier))
	assert_signal_emit_count(_technique, "zone_scored", 1)
	assert_eq(get_signal_parameters(_technique, "zone_scored", 0), [zone, tier, xp, float(xp)])
	assert_eq(CharacterManager.get_stat_xp(CONTROL), float(xp), "the zone's XP goes to Control")
	assert_eq(CultivationManager.get_core_density_xp(), core_xp, "and none to Core Density")
	assert_eq(CultivationManager.get_core_density_level(), core_level)
	var result: CycleResult = _technique.get_current_result()
	assert_eq(result.zones_scored, 1)
	assert_eq(result.get_stat_xp(CONTROL), float(xp))

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
	assert_eq(result.get_stat_xp(CONTROL), 6.0, "zone 1's PERFECT pays 6 Control XP")

## A capped Control takes none of a hit's XP, which is lost; the result marks
## it, and the signal says Control took nothing.
func test_a_zone_scored_at_the_cap_marks_the_result() -> void:
	CharacterManager.set_stat_level(CONTROL, CharacterManager.get_stat_level_cap())
	watch_signals(_technique)
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_false(_technique.get_current_result().is_stat_capped(CONTROL), "precondition: the mark comes with a scored zone, not with the cycle")
	assert_true(_technique.try_score_zone(zone))
	assert_eq(CharacterManager.get_stat_xp(CONTROL), 0.0, "a capped Control holds no XP")
	assert_true(_technique.get_current_result().is_stat_capped(CONTROL))
	assert_eq(get_signal_parameters(_technique, "zone_scored", 0)[3], 0.0, "Control took nothing")

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
	watch_signals(_technique)
	_technique.stop_cycling()
	for other: CyclingZone in _technique.cycling_zones:
		assert_eq(other.get_state(), CyclingZone.State.IDLE, "%s is idle" % other.name)
	assert_eq(_technique.get_ball_global_position(), START)
	assert_false(_technique.is_cycling())
	assert_false(CyclingManager.is_cycle_running())
	assert_signal_not_emitted(_technique, "cycle_completed")

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
	assert_eq(_technique.get_ball_global_position(), START, "the ball is back at the start in that same frame")

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
# A SCALED PATH
#-----------------------------------------------------------------------------

func test_scaling_the_path_leaves_the_technique_s_curve_alone() -> void:
	var curve := Curve2D.new()
	curve.add_point(Vector2(0.0, 0.0), Vector2(-10.0, 0.0), Vector2(10.0, 20.0))
	curve.add_point(Vector2(100.0, 0.0), Vector2(-10.0, -20.0), Vector2(10.0, 0.0))
	var data: CyclingTechniqueData = _straight_technique(Vector2(5000.0, 0.0))
	data.path_curve = curve
	_technique.path_scale = 1.5
	_technique.setup(data)
	assert_same(data.path_curve, curve, "the technique keeps its own curve")
	assert_eq(curve.get_point_position(1), Vector2(100.0, 0.0), "untouched")
	await _await_queued_frees()

#-----------------------------------------------------------------------------
# THE BALL'S PATH AND THE SNAPSHOT
#-----------------------------------------------------------------------------

func test_ball_follows_the_eased_path() -> void:
	var follow := _node("PathFollow2D") as PathFollow2D
	for seconds: float in [0.5, 1.0, CYCLE_SECONDS / 2.0, CYCLE_SECONDS - 0.5]:
		_technique.stop_cycling()
		_technique.start_cycle()
		_run(seconds, 60.0, false)
		assert_almost_eq(follow.progress_ratio, CyclingRules.eased_ratio(seconds, CYCLE_SECONDS), 0.001, "the eased share %s s in" % seconds)
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
# THE ZONE
#-----------------------------------------------------------------------------

func test_zone_is_open_while_idle_or_active() -> void:
	var zone: CyclingZone = _zone(0)
	var open: Array[CyclingZone.State] = [CyclingZone.State.IDLE, CyclingZone.State.ACTIVE]
	for state: int in CyclingZone.State.values():
		zone.set_state(state as CyclingZone.State)
		assert_eq(zone.is_open(), state in open, "state %d" % state)

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

func test_physics_picking_scores_a_press_on_the_ring() -> void:
	_approach_zone_0(0.0)
	watch_signals(_technique)
	await _press_at(_technique.get_ball_global_position() + Vector2(0.0, 34.0))
	assert_signal_emit_count(_technique, "zone_scored", 1, "a press on the ring lands on the ball")

func test_physics_picking_ignores_a_press_on_a_zone_off_the_ball() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_gt(zone.global_position.distance_to(_technique.get_ball_global_position()), CyclingTechnique.CURSOR_REACH, "precondition: the zone's centre is past the cursor's reach")
	watch_signals(_technique)
	await _press_at(zone.global_position)
	assert_signal_not_emitted(_technique, "zone_scored")
	assert_true(zone.is_open())

#-----------------------------------------------------------------------------
# SEALS
#-----------------------------------------------------------------------------

const TORRENTIAL_PATH: String = "res://resources/cycling/cycling_techniques/torrential_flow/torrential_flow.tres"
const MIND := CharacterAttributesData.AttributeType.MIND
## Seeds the seals' arrows, so a test draws the same seals every run.
const SEAL_SEED: int = 99

## Plays torrential_flow: an 8 s cycle with no zones and three seal nodes the
## ball reaches at 2, 4.5 and 7 s, each seal showing 1.5 s before.
func _use_torrential() -> void:
	_technique.setup(load(TORRENTIAL_PATH))
	_technique.seal_rng.seed = SEAL_SEED

func _seal(index: int) -> SealNode:
	return _technique.seal_nodes[index]

## Keys seal `index`'s arrows, each of which must be taken.
func _key_seal(index: int) -> void:
	for arrow: int in _seal(index).get_arrows():
		assert_true(_technique.press_seal(arrow), "precondition: the seal takes its arrow")

func test_the_seals_sit_where_the_ball_arrives() -> void:
	_use_torrential()
	assert_eq(_technique.seal_nodes.size(), 3)
	_technique.start_cycle()
	var reached: float = 0.0
	for index: int in 3:
		var seconds: float = _seal(index).arrive_seconds
		_run(seconds - reached, 60.0, true)
		reached = seconds
		assert_almost_eq(_seal(index).global_position.distance_to(_technique.get_ball_global_position()), 0.0, 2.0,
			"seal %d sits where the ball is at %s s" % [index, seconds])
	assert_eq([_seal(0).arrive_seconds, _seal(1).arrive_seconds, _seal(2).arrive_seconds], [2.0, 4.5, 7.0])
	await _await_queued_frees()

func test_a_seal_shows_its_lead_before_the_ball_arrives() -> void:
	_use_torrential()
	watch_signals(_technique)
	_technique.start_cycle()
	_run(0.45, 60.0, true)
	assert_eq(_seal(0).get_state(), SealNode.State.IDLE, "not yet")
	assert_signal_not_emitted(_technique, "seal_shown")
	_run(0.1, 60.0, true)
	assert_eq(_seal(0).get_state(), SealNode.State.SHOWING, "1.5 s before the ball")
	assert_eq(_seal(0).get_arrows().size(), CyclingRules.SEAL_LENGTH)
	assert_signal_emit_count(_technique, "seal_shown", 1)
	assert_eq(get_signal_parameters(_technique, "seal_shown", 0), [_seal(0)])
	assert_eq(_seal(1).get_state(), SealNode.State.IDLE, "the next seal waits its turn")
	await _await_queued_frees()

func test_keying_a_seal_opens_it() -> void:
	_use_torrential()
	_technique.start_cycle()
	_run(0.6, 60.0, true)
	_key_seal(0)
	assert_eq(_seal(0).get_state(), SealNode.State.OPEN)
	await _await_queued_frees()

func test_an_open_seal_pays_mind_as_the_ball_bursts_through() -> void:
	_use_torrential()
	_technique.start_cycle()
	_run(0.6, 60.0, true)
	_key_seal(0)
	watch_signals(_technique)
	_run(1.3, 60.0, true)
	assert_eq(CharacterManager.get_stat_xp(MIND), 0.0, "nothing until the ball gets there")
	_run(0.15, 60.0, true)
	assert_eq(CharacterManager.get_stat_xp(MIND), 5.0, "the seal's 5 Mind XP as the ball bursts through")
	assert_signal_emit_count(_technique, "seal_burst", 1)
	assert_eq(get_signal_parameters(_technique, "seal_burst", 0), [_seal(0), 5.0, 5.0])
	assert_eq(_seal(0).get_state(), SealNode.State.OPEN, "the node stays green")
	assert_eq(_technique.get_current_result().get_stat_xp(MIND), 5.0)
	await _await_queued_frees()

func test_a_missed_seal_fizzles_and_pays_nothing() -> void:
	_use_torrential()
	watch_signals(_technique)
	_technique.start_cycle()
	_run(2.1, 60.0, true)
	assert_eq(_seal(0).get_state(), SealNode.State.SPENT)
	assert_signal_emit_count(_technique, "seal_missed", 1)
	assert_eq(get_signal_parameters(_technique, "seal_missed", 0), [_seal(0)])
	assert_signal_not_emitted(_technique, "seal_burst")
	assert_eq(CharacterManager.get_stat_xp(MIND), 0.0)
	await _await_queued_frees()

func test_a_capped_mind_opens_seals_for_nothing() -> void:
	CharacterManager.set_stat_level(MIND, CharacterManager.get_stat_level_cap())
	_use_torrential()
	_technique.start_cycle()
	_run(0.6, 60.0, true)
	_key_seal(0)
	watch_signals(_technique)
	_run(1.5, 60.0, true)
	assert_eq(get_signal_parameters(_technique, "seal_burst", 0), [_seal(0), 5.0, 0.0], "Mind took nothing")
	assert_eq(CharacterManager.get_stat_xp(MIND), 0.0)
	assert_true(_technique.get_current_result().is_stat_capped(MIND))
	await _await_queued_frees()

func test_a_stop_drops_an_open_seal() -> void:
	_use_torrential()
	_technique.start_cycle()
	_run(0.6, 60.0, true)
	_key_seal(0)
	_run(1.2, 60.0, true)
	_technique.stop_cycling()
	assert_eq(CharacterManager.get_stat_xp(MIND), 0.0, "the ball never got there")
	for index: int in 3:
		assert_eq(_seal(index).get_state(), SealNode.State.IDLE, "seal %d is back to waiting" % index)
	await _await_queued_frees()

func test_keys_do_nothing_with_no_seal_showing() -> void:
	assert_false(_technique.press_seal(CyclingRules.Arrow.UP), "smooth_flow, ready: no seals at all")
	_technique.start_cycle()
	assert_false(_technique.press_seal(CyclingRules.Arrow.UP), "smooth_flow, cycling: no seals at all")
	_use_torrential()
	assert_false(_technique.press_seal(CyclingRules.Arrow.UP), "ready")
	_technique.start_cycle()
	_run(0.2, 60.0, true)
	assert_false(_technique.press_seal(CyclingRules.Arrow.UP), "before the first seal shows")
	_run(2.3, 60.0, true)
	assert_eq(_seal(0).get_state(), SealNode.State.SPENT, "precondition: the first seal is gone")
	assert_eq(_seal(1).get_state(), SealNode.State.IDLE, "precondition: the second has not shown")
	assert_false(_technique.press_seal(CyclingRules.Arrow.UP), "between seals")
	await _await_queued_frees()

func test_a_hitch_across_a_seal_s_window() -> void:
	_use_torrential()
	watch_signals(_technique)
	_technique.start_cycle()
	_technique.advance(2.2, _technique.get_ball_global_position())
	assert_eq(_seal(0).get_state(), SealNode.State.SPENT, "shown and fizzled in one frame")
	assert_signal_emit_count(_technique, "seal_shown", 1)
	assert_signal_emit_count(_technique, "seal_missed", 1)
	assert_eq(CharacterManager.get_stat_xp(MIND), 0.0)
	await _await_queued_frees()

func test_the_result_keeps_each_seal_and_zone_outcome() -> void:
	_use_torrential()
	watch_signals(_technique)
	_technique.start_cycle()
	_run(0.6, 60.0, true)
	_key_seal(0)
	_run(5.0, 60.0, true)
	assert_eq(_seal(2).get_state(), SealNode.State.SHOWING, "precondition: the third seal shows")
	_key_seal(2)
	_run(2.5, 60.0, true)
	var result := get_signal_parameters(_technique, "cycle_completed", 0)[0] as CycleResult
	assert_eq(result.seal_states, [SealNode.State.OPEN, SealNode.State.SPENT, SealNode.State.OPEN] as Array[int])
	assert_eq(result.zone_states, [] as Array[int], "torrential_flow has no zones")
	assert_eq(result.get_stat_xp(MIND), 10.0, "two seals paid")
	await _await_queued_frees()

func test_the_result_keeps_each_zone_outcome() -> void:
	watch_signals(_technique)
	var zone: CyclingZone = _approach_zone_0(6.0)
	assert_true(_technique.try_score_zone(zone))
	_run(CYCLE_SECONDS, 60.0, true)
	var result := get_signal_parameters(_technique, "cycle_completed", 0)[0] as CycleResult
	assert_eq(result.zone_states, [CyclingZone.State.PERFECT, CyclingZone.State.SPENT, CyclingZone.State.SPENT, CyclingZone.State.SPENT] as Array[int])
	assert_eq(result.seal_states, [] as Array[int], "smooth_flow has no seals")

#-----------------------------------------------------------------------------
# AUTO
#-----------------------------------------------------------------------------

## The Foundational's Madra and Spirit XP a cycle nobody follows pays under an
## unlocked Auto: 0.4 of its 37.5 Madra and 15 Spirit XP.
const AUTO_MADRA_PER_CYCLE: float = 37.5 * 0.4
const AUTO_SPIRIT_PER_CYCLE: float = 15.0 * 0.4

## Turns Auto on for the fixture's technique, unlocking it first when `unlocked`.
func _auto_on(unlocked: bool) -> void:
	if unlocked:
		CyclingManager.unlock_auto(_technique.technique_data.id)
	_technique.auto_cycle = true

## Plays one cycle from ready, with the cursor far away or on the ball when
## `track`, and returns its result: under Auto the next cycle starts at once,
## so the technique's current result is already the next one's.
func _auto_cycle(track: bool = false) -> CycleResult:
	var results: Array[CycleResult] = []
	_technique.cycle_completed.connect(func(result: CycleResult) -> void: results.append(result))
	_technique.start_cycle(track)
	for _frame: int in roundi(20.0 * 60.0):
		if not results.is_empty():
			break
		_technique.advance(FRAME, _technique.get_ball_global_position() if track else FAR)
	assert_eq(results.size(), 1, "precondition: the cycle ended")
	return results[0] if not results.is_empty() else CycleResult.new()

func test_a_cycle_followed_to_its_end_is_perfect() -> void:
	_use_foundation()
	_track_one_cycle(func() -> float: return FRAME)
	assert_almost_eq(_technique.get_current_result().followed_ratio, 1.0, 0.000001)
	assert_true(_technique.get_current_result().is_perfect())

func test_unattended_auto_pays_at_the_auto_rate() -> void:
	_use_foundation()
	_auto_on(true)
	assert_true(_technique.is_auto_running())
	var result: CycleResult = _auto_cycle()
	assert_almost_eq(result.madra_added, AUTO_MADRA_PER_CYCLE, 0.01, "0.4 of the cycle's Madra")
	assert_almost_eq(result.get_stat_xp(SPIRIT), AUTO_SPIRIT_PER_CYCLE, 0.0001, "0.4 of its Spirit XP")
	assert_almost_eq(_spirit_xp(), AUTO_SPIRIT_PER_CYCLE, 0.0001, "and Spirit took it")
	assert_eq(result.followed_ratio, 0.0, "Auto's time is not followed time")
	assert_false(result.is_perfect())

func test_auto_pays_nothing_unattended_before_the_unlock() -> void:
	_use_foundation()
	_auto_on(false)
	assert_false(_technique.is_auto_running())
	var result: CycleResult = _auto_cycle()
	assert_eq(result.madra_added, 0.0)
	assert_eq(_spirit_xp(), 0.0)
	assert_true(_technique.is_cycling(), "Auto still chains the cycles")

func test_following_under_auto_pays_the_full_rate() -> void:
	_use_foundation()
	_auto_on(true)
	var result: CycleResult = _auto_cycle(true)
	assert_almost_eq(result.madra_added, 37.5, 0.01)
	assert_almost_eq(result.get_stat_xp(SPIRIT), 15.0, 0.0001)

func test_the_session_reads_the_auto_rate() -> void:
	_use_foundation()
	_auto_on(true)
	_technique.start_cycle(false)
	_run(2.0, 60.0, false)
	assert_almost_eq(CyclingManager.get_madra_rate(), 37.5 / 10.0 * 0.4, 0.001)

func test_auto_at_the_spirit_cap_still_refills_madra() -> void:
	_use_foundation()
	CharacterManager.set_stat_level(SPIRIT, CultivationManager.get_stat_level_cap())
	_auto_on(true)
	watch_signals(_technique)
	var result: CycleResult = _auto_cycle()
	var multiplier: float = CharacterManager.get_total_attributes_data().get_cycling_madra_multiplier()
	assert_almost_eq(result.madra_added, AUTO_MADRA_PER_CYCLE * multiplier, 0.01, "Spirit at its cap raises the cycle's Madra")
	assert_true(result.is_stat_capped(SPIRIT), "the cap took Auto's Spirit XP")
	assert_signal_not_emitted(_technique, "stat_xp_paid")

func test_an_auto_cycle_moves_the_ball_at_an_even_speed() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Auto unlocked", "unlocked": true, "ratio": 0.25},
		{"name": "Auto locked", "unlocked": false, "ratio": CyclingRules.eased_ratio(CYCLE_SECONDS / 4.0, CYCLE_SECONDS)},
	]
	for case: Dictionary in cases:
		PersistenceManager.save_game_data = SaveGameData.new()
		PersistenceManager.save_data_reset.emit()
		_technique.stop_cycling()
		_auto_on(case.unlocked)
		_technique.start_cycle(false)
		_run(CYCLE_SECONDS / 4.0, 60.0, false)
		assert_almost_eq((_node("PathFollow2D") as PathFollow2D).progress_ratio, case.ratio, 0.002, case.name)

func test_an_auto_cycle_s_seals_burst_on_their_nodes() -> void:
	_use_torrential()
	_auto_on(true)
	var bursts: Array[Vector2] = []
	_technique.seal_burst.connect(func(seal: SealNode, _xp: float, _taken: float) -> void:
		bursts.append(seal.global_position - (_node("PathFollow2D") as PathFollow2D).global_position))
	_technique.start_cycle(false)
	for index: int in _technique.seal_nodes.size():
		var shown: bool = _step_until(func() -> bool: return _seal(index).get_state() == SealNode.State.SHOWING)
		assert_true(shown, "seal %d shows" % index)
		_key_seal(index)
	_step_until(func() -> bool: return bursts.size() == 3)
	assert_eq(bursts.size(), 3, "every opened seal burst")
	for offset: Vector2 in bursts:
		assert_lt(offset.length(), 8.0, "the even ball meets the node as it bursts")
	assert_almost_eq(CharacterManager.get_stat_xp(MIND), 15.0, 0.0001, "seals keyed under Auto still pay Mind")
	await _await_queued_frees()

#-----------------------------------------------------------------------------
# THE GRACE AND A PERFECT CYCLE
#-----------------------------------------------------------------------------

## How far off the ball a slipping cursor sits: past the ring.
const SLIP: Vector2 = Vector2(80.0, 0.0)

## Plays one Foundational cycle from a press at 60 FPS, the cursor on the ball
## but `slip` seconds off it from 3 s in, and returns its result.
func _cycle_with_a_slip(slip: float) -> CycleResult:
	_use_foundation()
	_technique.start_cycle()
	_run(3.0, 60.0, true)
	_run_off_the_ball(slip, SLIP)
	while _technique.is_cycling():
		_technique.advance(FRAME, _technique.get_ball_global_position())
	return _technique.get_current_result()

## A slip the grace holds counts as followed and is paid. One past the grace
## counts as missed from the moment the cursor left, and a cycle still needs
## 95% of it followed to be perfect: 0.4 s of a 10 s cycle is under the 5%,
## 0.6 s is over.
func test_a_slip_counts_against_the_cycle_past_the_grace() -> void:
	var cases: Array[Dictionary] = [
		{"name": "held by the grace", "slip": 0.05, "ratio": 1.0, "perfect": true},
		{"name": "0.3 s", "slip": 0.3, "ratio": 0.97, "perfect": true},
		{"name": "0.4 s", "slip": 0.4, "ratio": 0.96, "perfect": true},
		{"name": "0.6 s", "slip": 0.6, "ratio": 0.94, "perfect": false},
	]
	for case: Dictionary in cases:
		CharacterManager.set_stat_level(SPIRIT, 1)
		var result: CycleResult = _cycle_with_a_slip(case.slip)
		assert_almost_eq(result.followed_ratio, case.ratio, 0.002, "%s: the share followed" % case.name)
		assert_almost_eq(result.get_stat_xp(SPIRIT), 15.0 * case.ratio, 0.05, "%s: Spirit paid for the time followed" % case.name)
		assert_eq(result.is_perfect(), case.perfect, "%s: perfect" % case.name)

func test_the_ring_dims_once_the_cycle_cannot_be_perfect() -> void:
	_use_foundation()
	var ring := _node("BallRing") as CanvasItem
	_technique.start_cycle()
	_run(2.0, 60.0, true)
	assert_true(_technique.can_still_be_perfect(), "followed so far")
	assert_eq(ring.self_modulate, Color.WHITE)
	_run_off_the_ball(0.4, SLIP)
	_run(0.5, 60.0, true)
	assert_true(_technique.can_still_be_perfect(), "0.4 s missed is within the 5%")
	assert_eq(ring.self_modulate, Color.WHITE, "the ring is bright")
	_run_off_the_ball(0.3, SLIP)
	_run(0.5, 60.0, true)
	assert_false(_technique.can_still_be_perfect(), "0.7 s missed is not")
	assert_eq(ring.self_modulate, CyclingTechnique.RING_LOST_MODULATE, "the following ring dims")
	_technique.stop_cycling()
	assert_eq(ring.self_modulate, Color.WHITE, "the ready ring is bright again")

## Steps 60 FPS frames with the cursor on the ball until `done` returns true or
## the cycle ends, and returns whether `done` is true.
func _follow_until(done: Callable) -> bool:
	while _technique.is_cycling() and not done.call():
		_technique.advance(FRAME, _technique.get_ball_global_position())
	return done.call()

func test_a_missed_zone_or_seal_ends_the_perfect_at_once() -> void:
	_technique.start_cycle()
	assert_true(_follow_until(func() -> bool: return _zone(0).get_state() == CyclingZone.State.ACTIVE), "precondition: zone 0 opened")
	assert_true(_technique.can_still_be_perfect(), "followed, nothing missed yet")
	assert_true(_follow_until(func() -> bool: return _zone(0).get_state() == CyclingZone.State.SPENT), "precondition: zone 0 went by unscored")
	assert_false(_technique.can_still_be_perfect(), "a zone left unscored")
	_use_torrential()
	_technique.start_cycle()
	assert_true(_follow_until(func() -> bool: return _seal(0).get_state() == SealNode.State.SHOWING), "precondition: seal 0 shows")
	assert_true(_technique.can_still_be_perfect(), "followed, nothing missed yet")
	assert_true(_follow_until(func() -> bool: return _seal(0).get_state() == SealNode.State.SPENT), "precondition: seal 0 fizzled")
	assert_false(_technique.can_still_be_perfect(), "a seal that fizzled")
	await _await_queued_frees()

## The groove lights where the ball paid: a slip past the grace leaves a dark
## gap, kept once the cycle ends, and one the grace held stays lit.
func test_a_slip_leaves_a_dark_gap_in_the_groove() -> void:
	var cases: Array[Dictionary] = [
		{"name": "past the grace", "slip": 0.5, "lit": false},
		{"name": "held by the grace", "slip": 0.05, "lit": true},
	]
	for case: Dictionary in cases:
		_use_foundation()
		var groove := _node("CyclingGroove") as CyclingGroove
		var follow := _node("PathFollow2D") as PathFollow2D
		_technique.start_cycle()
		_run(2.0, 60.0, true)
		var before: float = follow.progress
		_run_off_the_ball(case.slip / 2.0, SLIP)
		var during: float = follow.progress
		_run_off_the_ball(case.slip / 2.0, SLIP)
		_run(1.0, 60.0, true)
		var after: float = follow.progress
		assert_true(groove.is_lit_at(before - 4.0), "%s: lit before the slip" % case.name)
		assert_eq(groove.is_lit_at(during), case.lit, "%s: the slip" % case.name)
		assert_true(groove.is_lit_at(after - 4.0), "%s: lit again once followed" % case.name)
		while _technique.is_cycling():
			_technique.advance(FRAME, _technique.get_ball_global_position())
		assert_eq(groove.is_lit_at(during), case.lit, "%s: the cycle's light stays until the next one" % case.name)

func test_an_auto_cycle_nobody_follows_lights_its_groove() -> void:
	_use_foundation()
	_auto_on(true)
	_technique.start_cycle(false)
	_run(3.0, 60.0, false)
	var progress: float = (_node("PathFollow2D") as PathFollow2D).progress
	assert_true((_node("CyclingGroove") as CyclingGroove).is_lit_at(progress - 4.0), "Auto paid behind the ball")
