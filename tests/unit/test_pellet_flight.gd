extends GutTest

## Unit tests for PelletFlight, the path a LacquerPellet flies: when a flight
## has landed, which is when the board it flies to takes in what it carries, and
## burst() sending one flight per pellet from the start to the target.

## Off the grid on purpose: a flight's ends are the even px nearest them.
const START: Vector2 = Vector2(801.3, 457.7)
const TARGET: Vector2 = Vector2(131.6, 103.1)
const SECONDS: float = 0.6
const BOW: float = 60.0

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _snapped(point: Vector2) -> Vector2:
	return (point / PelletFlight.GRID).round() * PelletFlight.GRID

#-----------------------------------------------------------------------------
# EVERY FLIGHT
#-----------------------------------------------------------------------------

func test_has_landed_at_the_duration() -> void:
	var flight: PelletFlight = PelletFlight.arc(START, TARGET, SECONDS, BOW)
	assert_false(flight.has_landed_at(SECONDS - 0.01))
	assert_true(flight.has_landed_at(SECONDS))

#-----------------------------------------------------------------------------
# BURST
#-----------------------------------------------------------------------------

func test_burst_sends_count_flights_from_the_start() -> void:
	var flights: Array[PelletFlight] = PelletFlight.burst(START, TARGET, 5, SECONDS, 0.04, 36.0)
	assert_eq(flights.size(), 5)
	for flight: PelletFlight in flights:
		assert_eq(flight.point_at(0.0), _snapped(START))
		assert_eq(flight.point_at(flight.duration), _snapped(TARGET))
