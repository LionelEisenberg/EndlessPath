class_name LacquerPellet
extends Node2D

## LacquerPellet
## One opaque pellet that flies a PelletFlight, then frees itself. The adventure's
## Madra drain sends it from the cabinet's Madra orb to the character, the cycling
## view from the ball to the Madra orb (Madra) and from a zone to the Core orb (XP,
## in the tier's ramp), and the tribulation off its ring and into its core.
## Lacquer kit §1 rules 4 and 6: no glow, halo, alpha or eased colour. Every look
## is a frame of one strip (lacquer_pellet_strip_ai.png, a row per Ramp), and every
## point it stands on is on the even-px grid. Its life, in whole frames:
## - it condenses: a 2 art px seed, then a 4 art px pellet, CONDENSE_STEP s each,
##   then the full pellet;
## - it flies with a tail of two smaller, darker dots at its own past points,
##   TAIL_NEAR_LAG and TAIL_FAR_LAG s back, so the faster it goes the longer the
##   tail, and at a standstill the tail hides under it;
## - it lands with a spark at the target, SPARK_STEP s a frame (flash, burst,
##   scatter), and frees itself once the spark is over.
## It emits delivered once, as it lands, so what it carries can show up where it
## lands just then; a pellet taken out of the tree before it lands delivers as it
## goes, so nothing it carries is lost.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted once: when the pellet lands, or when it leaves the tree before it has.
signal delivered

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

## The strip's rows: the Madra ramp, and the cycling hit tiers' brass, cream and tan.
enum Ramp { MADRA, BRASS, CREAM, TAN }

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The strip's columns.
const FULL_FRAME: int = 0
const SMALL_FRAME: int = 1
const SEED_FRAME: int = 2
const TAIL_NEAR_FRAME: int = 3
const TAIL_FAR_FRAME: int = 4
const SPARK_FRAMES: Array[int] = [5, 6, 7]

## Seconds each condensing frame shows: the seed, then the small pellet.
const CONDENSE_STEP: float = 0.04
const CONDENSE_SECONDS: float = CONDENSE_STEP * 2.0

## How many seconds back along the flight each half of the tail stands.
const TAIL_NEAR_LAG: float = 0.03
const TAIL_FAR_LAG: float = 0.06

## Seconds each spark frame shows once the pellet lands.
const SPARK_STEP: float = 0.05
const SPARK_SECONDS: float = SPARK_STEP * 3.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _sprite: Sprite2D = %Sprite
@onready var _tail_near: Sprite2D = %TailNear
@onready var _tail_far: Sprite2D = %TailFar

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _flight: PelletFlight = null
var _elapsed: float = 0.0
var _ramp: Ramp = Ramp.MADRA
var _delivered: bool = false

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _flight == null:
		return
	_elapsed += delta
	_show()
	if has_landed():
		_deliver()
	if _elapsed >= _flight.duration + SPARK_SECONDS:
		queue_free()

func _exit_tree() -> void:
	if _flight != null:
		_deliver()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## The strip column the pellet shows `elapsed` seconds into a flight of
## `duration` seconds: condensing, then full, then the spark once landed.
static func frame_at(elapsed: float, duration: float) -> int:
	if elapsed >= duration:
		return SPARK_FRAMES[mini(floori((elapsed - duration) / SPARK_STEP), SPARK_FRAMES.size() - 1)]
	if elapsed < CONDENSE_STEP:
		return SEED_FRAME
	if elapsed < CONDENSE_SECONDS:
		return SMALL_FRAME
	return FULL_FRAME

## Sends the pellet along `flight` from now, as a seed at the flight's start.
## Call it once the pellet is in the tree.
func fly(flight: PelletFlight) -> void:
	_flight = flight
	_elapsed = 0.0
	_show()

## Shows the pellet, its tail and its spark in `ramp`'s row of the strip. Call
## it once the pellet is in the tree.
func set_ramp(ramp: Ramp) -> void:
	_ramp = ramp
	for sprite: Sprite2D in [_sprite, _tail_near, _tail_far]:
		sprite.frame_coords = Vector2i(sprite.frame_coords.x, ramp)

func get_ramp() -> Ramp:
	return _ramp

## Whether the pellet has reached its target (it sparks there until it frees itself).
func has_landed() -> bool:
	return _flight != null and _flight.has_landed_at(_elapsed)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Emits delivered, the first time only.
func _deliver() -> void:
	if _delivered:
		return
	_delivered = true
	delivered.emit()

## Stands the pellet at its point for _elapsed and shows its frame, and puts each
## half of the tail at its past point while the pellet flies full-sized.
func _show() -> void:
	global_position = _flight.point_at(_elapsed)
	_sprite.frame_coords = Vector2i(frame_at(_elapsed, _flight.duration), _ramp)
	var trailing: bool = _elapsed >= CONDENSE_SECONDS and not has_landed()
	_tail_near.visible = trailing
	_tail_far.visible = trailing
	if trailing:
		_tail_near.position = _flight.point_at(_elapsed - TAIL_NEAR_LAG) - global_position
		_tail_far.position = _flight.point_at(_elapsed - TAIL_FAR_LAG) - global_position
