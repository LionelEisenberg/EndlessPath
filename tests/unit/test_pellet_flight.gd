extends GutTest

## Unit tests for PelletFlight, the path a LacquerPellet flies: every point on
## even px, the start before launch and the target once landed; arc() bows to a
## side and speeds up, stream() sways its bow with the index so the stream is one
## ribbon, and burst() fans a volley out, slows it to a hang and lands it one
## pellet after another.

## Off the grid on purpose: the points must still land on even px.
const START: Vector2 = Vector2(801.3, 457.7)
const TARGET: Vector2 = Vector2(131.6, 103.1)
const SECONDS: float = 0.6
const BOW: float = 60.0
const FRAME: float = 1.0 / 60.0

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _is_on_grid(point: Vector2) -> bool:
	return is_equal_approx(fposmod(point.x, 2.0), 0.0) and is_equal_approx(fposmod(point.y, 2.0), 0.0)

func _snapped(point: Vector2) -> Vector2:
	return (point / PelletFlight.GRID).round() * PelletFlight.GRID

## How far `point` stands off the straight line from START to TARGET, signed by
## side: positive on the side arc() bows to for a positive bow.
func _off_line(point: Vector2) -> float:
	var side: Vector2 = (TARGET - START).orthogonal().normalized()
	return (point - START).dot(side)

## The signed bow of pellet `index` of a stream: how far off the straight line
## its point stands at the middle of the curve.
func _stream_bow(index: int) -> float:
	var flight: PelletFlight = PelletFlight.stream(START, TARGET, SECONDS, BOW, index)
	return _off_line(flight.control) / 2.0

#-----------------------------------------------------------------------------
# EVERY FLIGHT
#-----------------------------------------------------------------------------

func test_points_stand_at_the_ends_before_and_after() -> void:
	var flight: PelletFlight = PelletFlight.arc(START, TARGET, SECONDS, BOW)
	assert_eq(flight.point_at(-1.0), _snapped(START), "the start before launch")
	assert_eq(flight.point_at(0.0), _snapped(START), "the start at launch")
	assert_eq(flight.point_at(SECONDS), _snapped(TARGET), "the target on landing")
	assert_eq(flight.point_at(SECONDS + 1.0), _snapped(TARGET), "and after")

func test_every_point_is_on_even_px() -> void:
	var flights: Array[PelletFlight] = [PelletFlight.arc(START, TARGET, SECONDS, BOW)]
	flights.append_array(PelletFlight.burst(START, TARGET, 8, SECONDS, 0.04, 36.0))
	var off_grid: Array[Vector2] = []
	for flight: PelletFlight in flights:
		var elapsed: float = 0.0
		while elapsed <= flight.duration:
			var point: Vector2 = flight.point_at(elapsed)
			if not _is_on_grid(point):
				off_grid.append(point)
			elapsed += FRAME
	assert_eq(off_grid.size(), 0, "%s" % [off_grid.slice(0, 5)])

func test_has_landed_at_the_duration() -> void:
	var flight: PelletFlight = PelletFlight.arc(START, TARGET, SECONDS, BOW)
	assert_false(flight.has_landed_at(SECONDS - 0.01))
	assert_true(flight.has_landed_at(SECONDS))

#-----------------------------------------------------------------------------
# ARC
#-----------------------------------------------------------------------------

## The curve's middle stands half the bow off the line, on the bow's side.
func test_arc_bows_to_the_side_of_its_bow() -> void:
	var middle: float = sqrt(0.5) * SECONDS
	var left: PelletFlight = PelletFlight.arc(START, TARGET, SECONDS, BOW)
	var right: PelletFlight = PelletFlight.arc(START, TARGET, SECONDS, -BOW)
	var straight: PelletFlight = PelletFlight.arc(START, TARGET, SECONDS, 0.0)
	assert_almost_eq(_off_line(left.point_at(middle)), BOW / 2.0, 2.0)
	assert_almost_eq(_off_line(right.point_at(middle)), -BOW / 2.0, 2.0)
	assert_almost_eq(_off_line(straight.point_at(middle)), 0.0, 2.0)

## It leaves at rest and speeds up the whole way in.
func test_arc_speeds_up() -> void:
	var flight: PelletFlight = PelletFlight.arc(START, TARGET, SECONDS, BOW)
	var first: float = flight.point_at(0.0).distance_to(flight.point_at(SECONDS / 2.0))
	var second: float = flight.point_at(SECONDS / 2.0).distance_to(flight.point_at(SECONDS))
	assert_gt(second, first * 2.0, "the second half covers far more ground")
	var last_frame: float = flight.point_at(SECONDS - FRAME).distance_to(flight.point_at(SECONDS))
	var first_frame: float = flight.point_at(0.0).distance_to(flight.point_at(FRAME))
	assert_gt(last_frame, first_frame)

#-----------------------------------------------------------------------------
# STREAM
#-----------------------------------------------------------------------------

func test_stream_bow_stays_within_its_bow() -> void:
	for index: int in 40:
		assert_lte(absf(_stream_bow(index)), BOW / 2.0 + 0.001, "pellet %d" % index)

## Over a sway the stream bows to both sides, all the way out.
func test_stream_sways_from_side_to_side() -> void:
	var lowest: float = 0.0
	var highest: float = 0.0
	for index: int in 13:
		lowest = minf(lowest, _stream_bow(index))
		highest = maxf(highest, _stream_bow(index))
	assert_gt(highest, BOW / 2.0 * 0.95, "out to one side")
	assert_lt(lowest, -BOW / 2.0 * 0.95, "and to the other")

## Neighbours fly close paths, so the stream reads as one ribbon, not a spray.
func test_stream_neighbours_bow_alike() -> void:
	for index: int in 30:
		var step: float = absf(_stream_bow(index + 1) - _stream_bow(index))
		assert_lte(step, BOW / 2.0 * PelletFlight.SWAY_STEP + 0.001, "pellets %d and %d" % [index, index + 1])

#-----------------------------------------------------------------------------
# BURST
#-----------------------------------------------------------------------------

func test_burst_sends_count_flights_from_the_start() -> void:
	var flights: Array[PelletFlight] = PelletFlight.burst(START, TARGET, 5, SECONDS, 0.04, 36.0)
	assert_eq(flights.size(), 5)
	for flight: PelletFlight in flights:
		assert_eq(flight.point_at(0.0), _snapped(START))
		assert_eq(flight.point_at(flight.duration), _snapped(TARGET))

## Pellet k lands seconds_step after pellet k - 1.
func test_burst_lands_one_after_another() -> void:
	var flights: Array[PelletFlight] = PelletFlight.burst(START, TARGET, 8, SECONDS, 0.04, 36.0)
	for k: int in flights.size():
		assert_almost_eq(flights[k].duration, SECONDS + 0.04 * k, 0.0001, "pellet %d" % k)

## Each pops out to its own point within the reach, and the fan's middle points
## straight away from the target.
func test_burst_fans_out_away_from_the_target() -> void:
	var reach: float = 36.0
	var flights: Array[PelletFlight] = PelletFlight.burst(START, TARGET, 3, SECONDS, 0.04, reach)
	var seen: Dictionary = {}
	for flight: PelletFlight in flights:
		var out: Vector2 = flight.pop - START
		assert_lte(out.length(), reach + 0.001)
		assert_gte(out.length(), reach * PelletFlight.BURST_SHORT - 0.001)
		seen[flight.point_at(PelletFlight.BURST_POP_SECONDS)] = true
	assert_eq(seen.size(), 3, "every pellet pops to its own point")
	var away: Vector2 = (START - TARGET).normalized()
	assert_almost_eq((flights[1].pop - START).normalized().dot(away), 1.0, 0.001, "the middle one points away")

func test_a_burst_of_one_pops_straight_away() -> void:
	var flights: Array[PelletFlight] = PelletFlight.burst(START, TARGET, 1, SECONDS, 0.04, 36.0)
	var away: Vector2 = (START - TARGET).normalized()
	assert_almost_eq((flights[0].pop - START).normalized().dot(away), 1.0, 0.001)

## The pop is fast at first and slows to a stop at the pop point, then the
## pellet hangs before it speeds in.
func test_burst_pops_then_hangs() -> void:
	var flight: PelletFlight = PelletFlight.burst(START, TARGET, 1, SECONDS, 0.0, 36.0)[0]
	var pop_end: float = PelletFlight.BURST_POP_SECONDS
	assert_eq(flight.point_at(pop_end), _snapped(flight.pop), "at the pop point when the pop ends")
	var first_frame: float = flight.point_at(0.0).distance_to(flight.point_at(FRAME))
	var hang: float = flight.point_at(pop_end).distance_to(flight.point_at(pop_end + FRAME))
	var last_frame: float = flight.point_at(SECONDS - FRAME).distance_to(flight.point_at(SECONDS))
	assert_gt(first_frame, hang, "it pops out faster than it hangs")
	assert_gt(last_frame, first_frame, "and zips in fastest of all")

func test_a_burst_of_none_is_empty() -> void:
	assert_eq(PelletFlight.burst(START, TARGET, 0, SECONDS, 0.04, 36.0).size(), 0)
