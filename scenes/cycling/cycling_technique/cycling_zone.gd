class_name CyclingZone
extends Node2D

## CyclingZone
## One scoring zone along a cycling technique's path: a 48 px socket the Madra
## ball passes over. The zone holds a State and shows it as one frame of the zone
## strip, so the idle rim, the active rim, the spent socket and the scored studs
## are all frames: nothing fades or tweens. A zone never hides, so the studs of
## the last cycle stay up until the next one starts.
## The zone takes no press of its own: the player presses the ball while it is
## over the zone. Where the ball is, which zone is active and the scoring belong
## to CyclingTechnique, which also places the zone. The socket ignores the mouse,
## so it never stops a press meant for the ball.

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

## What the zone shows, in the order of the zone strip's frames. IDLE is a tan
## rim: between cycles, and during one until the ball reaches the zone. ACTIVE is
## a brass rim: the ball is over the zone. SPENT is a bare socket: the ball left
## it unscored. PERFECT, GOOD and OK are the studs a press on the ball over an
## active zone leaves.
enum State { IDLE, ACTIVE, SPENT, PERFECT, GOOD, OK }

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _socket: LacquerStripRect = %Socket

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The zone's data: the XP it pays. Set by setup().
var zone_data: CyclingZoneData = null

var _state: State = State.IDLE

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_socket.set_frame(_state)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns the state a hit of `tier` leaves the zone in: its stud.
static func state_for_tier(tier: CyclingRules.Tier) -> State:
	match tier:
		CyclingRules.Tier.PERFECT:
			return State.PERFECT
		CyclingRules.Tier.GOOD:
			return State.GOOD
		_:
			return State.OK

## Gives the zone its data and sets it IDLE.
func setup(data: CyclingZoneData) -> void:
	zone_data = data
	set_state(State.IDLE)

## Shows `state`: its frame of the zone strip.
func set_state(state: State) -> void:
	if state == _state:
		return
	_state = state
	if is_node_ready():
		_socket.set_frame(_state)

## Returns the state the zone is in.
func get_state() -> State:
	return _state

## Returns true while the zone can still score: IDLE or ACTIVE.
func is_open() -> bool:
	return _state == State.IDLE or _state == State.ACTIVE
