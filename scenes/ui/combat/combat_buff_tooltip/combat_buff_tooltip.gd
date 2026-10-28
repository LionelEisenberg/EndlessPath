class_name CombatBuffTooltip
extends PanelContainer

## CombatBuffTooltip
## Shows buff details on hover: name, description, duration, stacks.

#-----------------------------------------------------------------------------
# NODES
#-----------------------------------------------------------------------------

@onready var _buff_icon: TextureRect = %BuffIcon
@onready var _buff_name: Label = %BuffName
@onready var _description: Label = %Description
@onready var _duration_label: Label = %DurationLabel
@onready var _stacks_label: Label = %StacksLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _active_buff: ActiveBuff

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Shows the tooltip for the given active buff.
func show_for_buff(buff: ActiveBuff) -> void:
	_active_buff = buff
	var data: BuffEffectData = buff.buff_data

	_buff_icon.texture = data.buff_icon
	_buff_name.text = data.buff_id.capitalize()
	_description.text = data.describe()
	_update_meta()

	visible = true

## Hides the tooltip.
func hide_tooltip() -> void:
	_active_buff = null
	visible = false

## Positions to the right of the given control.
func position_beside(control: Control) -> void:
	var rect: Rect2 = control.get_global_rect()
	var x: float = rect.position.x + rect.size.x + 8.0
	var y: float = rect.position.y

	# Flip left if would overflow right
	if x + size.x > get_viewport_rect().size.x:
		x = rect.position.x - size.x - 8.0

	global_position = Vector2(x, y)

#-----------------------------------------------------------------------------
# PROCESS — Live Duration
#-----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if visible and _active_buff:
		_update_meta()

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _update_meta() -> void:
	if _active_buff:
		_duration_label.text = "%.1fs remaining" % _active_buff.time_remaining
		if _active_buff.stack_count > 1:
			_stacks_label.text = "x%d stacks" % _active_buff.stack_count
			_stacks_label.visible = true
		else:
			_stacks_label.visible = false
