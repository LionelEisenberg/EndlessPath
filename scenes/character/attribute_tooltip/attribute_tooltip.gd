class_name AttributeTooltip
extends PanelContainer

## Shared tooltip for attribute rows.
## Repositions above the hovered row and displays attribute description + formulas.

#-----------------------------------------------------------------------------
# NODES
#-----------------------------------------------------------------------------

@onready var _title_label: Label = %TitleLabel
@onready var _body_label: Label = %BodyLabel
@onready var _effects_label: Label = %EffectsLabel

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Shows the tooltip above the given row with the provided data.
func show_for_row(row: Control, data: Dictionary) -> void:
	_title_label.text = data.get("title", "")
	_body_label.text = data.get("description", "")
	_effects_label.text = data.get("effects", "")
	_effects_label.visible = not data.get("effects", "").is_empty()

	visible = true
	reset_size()

	var rect: Rect2 = row.get_global_rect()
	global_position = Vector2(rect.position.x, rect.position.y - size.y - 8)

## Hides the tooltip.
func hide_tooltip() -> void:
	visible = false
