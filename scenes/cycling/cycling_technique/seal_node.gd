class_name SealNode
extends Node2D

## SealNode
## One seal node on a cycling technique's path: a 48 px diamond socket the Madra
## ball passes over, and, while its seal shows, the plate of arrows over it. Seals
## are the game that trains Mind (CyclingRules). The node holds a State and shows
## it as one frame of the seal strip, so the tan socket, the green rim, the filled
## node and the cracked one are all frames: nothing fades or tweens.
## CyclingTechnique places the node, shows its seal SEAL_LEAD before the ball
## arrives (show_seal()), hands it the player's keys (press()) and, as the ball
## arrives, bursts an open node or fizzles one whose seal still shows. Each arrow
## on the plate is a frame of the arrow strip: its column the arrow, its row the
## look (Look). A wrong key flashes every arrow red for CRACK_SECONDS while the
## plate shakes SHAKE_PX left and right each SHAKE_STEP, and starts the seal over;
## the next right key ends the flash at once. An open seal's plate stays
## OPEN_PLATE_SECONDS with every arrow lit, then hides. The technique steps the
## node's clock with advance(). The node ignores the mouse, so it never stops a
## press meant for the ball.

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

## What the node shows, in the order of the seal strip's frames. IDLE is a tan
## socket: before its seal shows. SHOWING is a green rim: its seal shows, waiting
## for its keys. OPEN is the node filled green: its seal is keyed, and stays so
## once the ball has burst through. SPENT is cracked and dark: the ball got there
## first.
enum State { IDLE, SHOWING, OPEN, SPENT }

## How an arrow on the plate looks, in the order of the arrow strip's rows:
## waiting its turn, the next to key, keyed, or red after a wrong key.
enum Look { WAITING, NEXT, DONE, WRONG }

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Seconds every arrow flashes red after a wrong key.
const CRACK_SECONDS: float = 0.3

## The plate's shake while the arrows flash: SHAKE_PX to the right, then to the
## left, each SHAKE_STEP seconds.
const SHAKE_STEP: float = 0.05
const SHAKE_PX: float = 2.0

## Seconds an open seal's plate stays, every arrow lit, before it hides.
const OPEN_PLATE_SECONDS: float = 0.25

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _socket: LacquerStripRect = %Socket
@onready var _plate: Control = %Plate
@onready var _glyphs: Array[LacquerStripRect] = [%Glyph1, %Glyph2, %Glyph3]

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## When the ball reaches the node, in seconds into the cycle. Set by setup().
var arrive_seconds: float = 0.0

var _state: State = State.IDLE
var _arrows: Array[int] = []
var _keyed: int = 0
## Seconds of the red flash left; 0 when the arrows show their own looks.
var _crack_left: float = 0.0
## Seconds an open seal's plate has left; below 0 when no hide is pending.
var _plate_left: float = -1.0
## Where the plate stands when it does not shake.
var _plate_rest: Vector2 = Vector2.ZERO

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_plate_rest = _plate.position
	_socket.set_frame(_state)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Gives the node the second the ball reaches it and sets it IDLE.
func setup(seconds: float) -> void:
	arrive_seconds = seconds
	reset()

## Shows the seal `arrows` (CyclingRules.Arrow values): the green rim, and the
## plate with the first arrow next and the rest waiting.
func show_seal(arrows: Array[int]) -> void:
	_arrows = arrows.duplicate()
	_keyed = 0
	_crack_left = 0.0
	_plate_left = -1.0
	_set_state(State.SHOWING)
	_plate.position = _plate_rest
	_plate.visible = true
	_paint()

## Takes a key while the seal shows: the right arrow lights and the next one is
## next, and the last one opens the node; a wrong key starts the seal over with
## the red flash. Returns whether the key was right. Outside SHOWING it changes
## nothing and returns false.
func press(arrow: int) -> bool:
	if _state != State.SHOWING:
		return false
	_keyed = CyclingRules.seal_progress(_arrows, _keyed, arrow)
	var right: bool = _keyed > 0
	_crack_left = 0.0 if right else CRACK_SECONDS
	_plate.position = _plate_rest
	if _keyed >= _arrows.size():
		_set_state(State.OPEN)
		_plate_left = OPEN_PLATE_SECONDS
	_paint()
	return right

## The ball has burst through the open node: the plate hides and the node stays
## green.
func burst() -> void:
	_plate_left = -1.0
	_plate.visible = false

## The ball got there before the seal was keyed: the node cracks and goes dark.
func fizzle() -> void:
	_crack_left = 0.0
	_plate_left = -1.0
	_set_state(State.SPENT)
	_plate.visible = false

## Puts the node back to IDLE with no seal, as a new cycle or a stop finds it.
func reset() -> void:
	_arrows.clear()
	_keyed = 0
	_crack_left = 0.0
	_plate_left = -1.0
	_set_state(State.IDLE)
	if is_node_ready():
		_plate.visible = false
		_plate.position = _plate_rest

## Moves the node's clock on by `delta` seconds: the red flash and its shake run
## out, and an open seal's plate hides once its time is up.
func advance(delta: float) -> void:
	if _crack_left > 0.0:
		_crack_left = maxf(_crack_left - delta, 0.0)
		if _crack_left > 0.0:
			var step: int = floori((CRACK_SECONDS - _crack_left) / SHAKE_STEP)
			_plate.position = _plate_rest + Vector2(SHAKE_PX if step % 2 == 0 else -SHAKE_PX, 0.0)
		else:
			_plate.position = _plate_rest
			_paint()
	if _plate_left >= 0.0:
		_plate_left -= delta
		if _plate_left <= 0.0:
			_plate_left = -1.0
			_plate.visible = false

## Returns the state the node is in.
func get_state() -> State:
	return _state

## Returns the seal's arrows, empty while none shows.
func get_arrows() -> Array[int]:
	return _arrows.duplicate()

## Returns how many of the seal's arrows are keyed.
func get_keyed() -> int:
	return _keyed

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _set_state(state: State) -> void:
	_state = state
	if is_node_ready():
		_socket.set_frame(_state)

## Shows each arrow in its look.
func _paint() -> void:
	for slot: int in _glyphs.size():
		var arrow: int = _arrows[slot] if slot < _arrows.size() else CyclingRules.Arrow.UP
		_glyphs[slot].set_frame(arrow, _look_for(slot))

func _look_for(slot: int) -> Look:
	if _crack_left > 0.0:
		return Look.WRONG
	if slot < _keyed:
		return Look.DONE
	if slot == _keyed:
		return Look.NEXT
	return Look.WAITING
