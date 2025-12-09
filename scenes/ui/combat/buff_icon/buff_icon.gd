class_name BuffIcon
extends MarginContainer

## BuffIcon
## UI component representing an active buff on a combatant.
## Displays icon, duration, and stack count.

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

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Sets up the icon with the given buff data.
func setup(buff_data: BuffEffectData, duration: float, stack_count: int) -> void:
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

#-----------------------------------------------------------------------------
# PROCESS
#-----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if is_active and time_left > 0:
		# Visually countdown
		time_left = max(0.0, time_left - delta)
		update_duration(time_left)
