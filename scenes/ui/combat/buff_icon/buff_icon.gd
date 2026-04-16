class_name BuffIcon
extends MarginContainer

## BuffIcon
## UI component representing an active buff on a combatant.
## Displays icon, duration, and stack count.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal hovered(buff_data: BuffEffectData)
signal unhovered

#-----------------------------------------------------------------------------
# SCENE REFERENCES
#-----------------------------------------------------------------------------

@onready var buff_texture: TextureRect = %BuffTexture
@onready var duration_progress_bar: TextureProgressBar = %DurationProgressBar
@onready var duration_label: Label = %DurationLabel
@onready var stack_label: Label = %StackLabel

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var max_duration: float = 0.0
var time_left: float = 0.0
var is_active: bool = false
var _buff_data: BuffEffectData

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Sets up the icon with the given buff data.
func setup(buff_data: BuffEffectData, duration: float, stack_count: int) -> void:
	_buff_data = buff_data

	# Set Icon
	if buff_texture:
		buff_texture.texture = buff_data.buff_icon

	# Set State
	max_duration = duration
	time_left = duration
	is_active = true

	# Initial Update
	update_duration(duration)
	update_stacks(stack_count)

	# Enable mouse hover
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## Updates the duration display.
func update_duration(new_time_left: float) -> void:
	time_left = new_time_left
	
	if duration_label:
		duration_label.text = "%.1fs" % time_left
	
	if duration_progress_bar and max_duration > 0:
		duration_progress_bar.value = time_left / max_duration

## Updates the stack count display.
func update_stacks(count: int) -> void:
	if stack_label:
		stack_label.text = str(count)
		stack_label.visible = count > 1

# Duration is synced externally by CombatantInfoPanel from the authoritative ActiveBuff state.
# No independent _process countdown — avoids visual drift from actual buff duration.

func _on_mouse_entered() -> void:
	if _buff_data:
		hovered.emit(_buff_data)

func _on_mouse_exited() -> void:
	unhovered.emit()
