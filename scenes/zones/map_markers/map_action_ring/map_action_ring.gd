class_name MapActionRing
extends Control

## MapActionRing
## The running idle action on the zone map (kit §0, §6.3): a 64x64 jade bead
## ring on its own lacquer disc with the action's icon in the middle. The
## beads light over each timer cycle (one Aura Well tick, one foraging haul),
## the same stepping as the Now strip's ring. It sits on the left end of the
## current zone's plate (ZoneMapLabel), which shows it only while an idle
## action runs there.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The ring strip's frames: 0 dark, 12 fully lit.
const RING_FRAME_COUNT: int = 13
const RING_LAST_FRAME: int = 12

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _ring: LacquerStripRect = %Ring
@onready var _action_icon: TextureRect = %ActionIcon

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _action: ZoneActionData = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	show_action(_action)

func _process(_delta: float) -> void:
	_update_frame()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the ring for the running idle action with its icon, or hides it
## outright for null.
func show_action(action: ZoneActionData) -> void:
	_action = action
	if not is_node_ready():
		return
	visible = _action != null
	set_process(visible)
	if _action == null:
		return
	_action_icon.texture = _action.icon
	_update_frame()

## The idle action the ring shows, or null while hidden.
func get_action() -> ZoneActionData:
	return _action

## The ring strip frame shown now (0-12).
func get_frame() -> int:
	return _ring.get_frame().x

## The frame for progress (0-1) through the timer's cycle: floor(progress ×
## 13) lit beads, at most 12.
static func frame_for(progress: float) -> int:
	return mini(floori(clampf(progress, 0.0, 1.0) * RING_FRAME_COUNT), RING_LAST_FRAME)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Progress is how far ActionManager's action timer is through its cycle.
func _update_frame() -> void:
	var timer: Timer = ActionManager.action_timer
	var progress: float = 0.0
	if not timer.is_stopped() and timer.wait_time > 0.0:
		progress = 1.0 - timer.time_left / timer.wait_time
	_ring.set_frame(frame_for(progress))
