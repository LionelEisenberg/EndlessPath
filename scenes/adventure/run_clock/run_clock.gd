class_name RunClock
extends Control

## The adventure's run clock in the chest's header: a carved recess holding a
## mini hourglass and the time left as M:SS in cream. At 30 s or less the
## recess becomes the vermilion seal and the cream stays, so nothing but the
## recess changes; nothing flashes.
## bind_timer() hands it the run's Timer. While that timer runs, _process
## reads its time left every frame. A stopped timer leaves the clock as it
## was: a run that ends with time left keeps showing it.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## At this many seconds left or fewer the recess becomes the seal.
const LOW_SECONDS: float = 30.0

## The carved recess, and the seal that takes its place at LOW_SECONDS or less.
const RECESS: Texture2D = preload("res://assets/ui/lacquer/lacquer_timer_ai.png")
const RECESS_LOW: Texture2D = preload("res://assets/ui/lacquer/lacquer_timer_low_ai.png")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _recess: TextureRect = %Recess
@onready var _time_label: Label = %TimeLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _timer: Timer = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not is_instance_valid(_timer) or _timer.is_stopped():
		return
	var seconds_left: float = _timer.time_left
	_time_label.text = format_time(seconds_left)
	_recess.texture = RECESS_LOW if is_low(seconds_left) else RECESS

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Follows timer from now on, and the one bound before no longer. Null lets
## the clock go.
func bind_timer(timer: Timer) -> void:
	_timer = timer

## Returns true while the vermilion seal shows in place of the carved recess.
func is_low_shown() -> bool:
	return _recess.texture == RECESS_LOW

## Returns the time as M:SS: whole minutes, and the seconds past them cut, not
## rounded, so the last second reads 0:00 throughout (as the old timer pill did).
static func format_time(seconds_left: float) -> String:
	return "%d:%02d" % [floori(seconds_left / 60.0), int(seconds_left) % 60]

## Returns true when seconds_left is low enough for the seal: LOW_SECONDS or
## fewer.
static func is_low(seconds_left: float) -> bool:
	return seconds_left <= LOW_SECONDS
