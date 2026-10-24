class_name RunClock
extends Control

## The adventure's run clock in the chest's header: a carved recess holding a
## mini hourglass and the time left as M:SS in cream. At 30 s or less the
## recess becomes the vermilion seal and the cream stays, so nothing but the
## recess changes; nothing flashes.
## bind_timer() hands it the run's Timer and paints the clock from it at once:
## a run starts from a tween callback, which steps after the frame's _process,
## so the first frame of a run would otherwise show the last one's end (after a
## timeout, 0:00 on the seal). While that timer runs, _process reads its time
## left every frame. A stopped timer leaves the clock as it was: a run that
## ends with time left keeps showing it.

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
	_refresh()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Follows timer from now on, and the one bound before no longer, and shows its
## time left at once if it runs. Null lets the clock go.
func bind_timer(timer: Timer) -> void:
	_timer = timer
	_refresh()

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

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Paints the time left and the recess from the bound timer while it runs. A
## stopped or missing timer leaves the clock as it was.
func _refresh() -> void:
	if not is_instance_valid(_timer) or _timer.is_stopped():
		return
	var seconds_left: float = _timer.time_left
	_time_label.text = format_time(seconds_left)
	_recess.texture = RECESS_LOW if is_low(seconds_left) else RECESS
