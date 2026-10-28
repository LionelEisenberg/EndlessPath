class_name PelletFlight
extends RefCounted

## PelletFlight
## The path a LacquerPellet flies, worked out from the time since launch alone, so
## a test can ask for any moment directly. A flight has up to two legs:
## - the pop: from the start out to the pop point, slowing to a stop, over
##   pop_seconds (none when pop_seconds is 0, the pop point then the start);
## - the homing leg: a curve from the pop point into the target, pulled toward the
##   control point, starting at rest and speeding up the whole way in: its share of
##   the curve is its share of the time to the power home_ease.
## Every point stands on the even-px grid (kit §1 rule 6).
## The builders lay flights out for each kind of group: arc() for one pellet,
## stream() for a pellet of a steady stream (its bow sways with its index, so the
## stream reads as one ribbon) and burst() for a volley that fans out of a point,
## hangs, then homes into the target one pellet after another.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## One art px of the kit is this many screen px; a pellet only ever stands on
## multiples of it.
const GRID: float = 2.0

## A stream's bow turns this many radians per pellet: about 12 pellets from one
## side to the other and back.
const SWAY_STEP: float = 0.5

## A burst fans its pellets evenly over this arc, centred on the direction away
## from the target, so every pellet swings round on its way in.
const BURST_FAN: float = 200.0 * PI / 180.0
## Every other pellet of a burst pops this share of the reach, so the fan is
## ragged rather than a ring.
const BURST_SHORT: float = 0.65
## Seconds a burst's pellets take to pop out. The homing leg's control point
## stands BURST_SWING reaches out past the pop point, so the pellet drifts on
## outward as it turns.
const BURST_POP_SECONDS: float = 0.12
const BURST_SWING: float = 2.0

## How hard the homing leg speeds up: a stream's pellets leave at rest and are
## pulled in ever faster (HOME_EASE). A burst's pellets have just slowed to a stop
## from their pop, so theirs gather pace sooner (BURST_HOME_EASE), or the hang
## reads as a freeze.
const HOME_EASE: float = 2.0
const BURST_HOME_EASE: float = 1.5

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var start: Vector2 = Vector2.ZERO
var pop: Vector2 = Vector2.ZERO
var control: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var duration: float = 0.0
var pop_seconds: float = 0.0
var home_ease: float = HOME_EASE

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _init(from: Vector2, pop_point: Vector2, control_point: Vector2, to: Vector2, seconds: float, pop_time: float = 0.0, ease: float = HOME_EASE) -> void:
	start = from
	pop = pop_point
	control = control_point
	target = to
	duration = seconds
	pop_seconds = clampf(pop_time, 0.0, seconds)
	home_ease = ease

#-----------------------------------------------------------------------------
# BUILDERS
#-----------------------------------------------------------------------------

## A flight with no pop from `from` to `to` over `seconds`, bowing `bow` px off
## the straight line at its middle: to one side for a positive bow, to the other
## for a negative one.
static func arc(from: Vector2, to: Vector2, seconds: float, bow: float) -> PelletFlight:
	var side: Vector2 = (to - from).orthogonal().normalized()
	return PelletFlight.new(from, from, (from + to) * 0.5 + side * bow, to, seconds)

## Pellet `index` of a steady stream from `from` to `to`: an arc whose bow sways
## between `bow` px to one side and `bow` px to the other as the index climbs.
static func stream(from: Vector2, to: Vector2, seconds: float, bow: float, index: int) -> PelletFlight:
	return arc(from, to, seconds, bow * sin(index * SWAY_STEP))

## A volley of `count` pellets from `from` into `to`. They pop out together, up
## to `reach` px, fanned over BURST_FAN away from the target, then home in: pellet
## k flies `seconds` + k * `seconds_step`, so they land one after another, from
## one edge of the fan to the other.
static func burst(from: Vector2, to: Vector2, count: int, seconds: float, seconds_step: float, reach: float) -> Array[PelletFlight]:
	var flights: Array[PelletFlight] = []
	var away: float = (from - to).angle()
	for k: int in count:
		var share: float = 0.5 if count == 1 else float(k) / (count - 1)
		var direction: Vector2 = Vector2.from_angle(away + (share - 0.5) * BURST_FAN)
		var out: float = reach if k % 2 == 0 else reach * BURST_SHORT
		var pop_point: Vector2 = from + direction * out
		var control_point: Vector2 = pop_point + direction * out * BURST_SWING
		flights.append(PelletFlight.new(from, pop_point, control_point, to, seconds + seconds_step * k, BURST_POP_SECONDS, BURST_HOME_EASE))
	return flights

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Whether the pellet has reached the target `elapsed` seconds after launch.
func has_landed_at(elapsed: float) -> bool:
	return elapsed >= duration

## The pellet's point `elapsed` seconds after launch, on the even-px grid: the
## start before launch, the target once landed.
func point_at(elapsed: float) -> Vector2:
	return (_exact_point_at(elapsed) / GRID).round() * GRID

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _exact_point_at(elapsed: float) -> Vector2:
	if elapsed <= 0.0:
		return start
	if has_landed_at(elapsed):
		return target
	if elapsed < pop_seconds:
		var u: float = elapsed / pop_seconds
		return start.lerp(pop, 1.0 - (1.0 - u) * (1.0 - u))
	var home: float = (elapsed - pop_seconds) / (duration - pop_seconds)
	var eased: float = pow(home, home_ease)
	var a: Vector2 = pop.lerp(control, eased)
	var b: Vector2 = control.lerp(target, eased)
	return a.lerp(b, eased)
