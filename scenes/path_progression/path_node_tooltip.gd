class_name PathNodeTooltip
extends Control
## Tooltip popup for path tree nodes.
## Shows node details on hover with animated show/hide.

@onready var _name_label: Label = %NameLabel
@onready var _type_label: Label = %TypeLabel
@onready var _description_label: RichTextLabel = %DescriptionLabel
@onready var _cost_label: Label = %CostLabel
@onready var _level_label: Label = %LevelLabel

var _tween: Tween = null

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Populate the tooltip with node data and animate it in.
func show_tooltip(data: PathNodeData, current_level: int) -> void:
	_name_label.text = data.display_name
	_type_label.text = _get_type_text(data.node_type)
	_description_label.text = data.description
	_cost_label.text = "Cost: %d point%s" % [data.point_cost, "" if data.point_cost == 1 else "s"]

	if data.max_purchases > 1:
		_level_label.text = "Level: %d/%d" % [current_level, data.max_purchases]
	elif current_level >= 1:
		_level_label.text = "Purchased"
	else:
		_level_label.text = ""

	visible = true
	_animate_in()


## Animate the tooltip out and hide it.
func hide_tooltip() -> void:
	_animate_out()

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _get_type_text(node_type: PathNodeData.NodeType) -> String:
	match node_type:
		PathNodeData.NodeType.KEYSTONE:
			return "Keystone"
		PathNodeData.NodeType.MAJOR:
			return "Major"
		PathNodeData.NodeType.MINOR:
			return "Minor"
		PathNodeData.NodeType.REPEATABLE:
			return "Repeatable"
	return ""


func _animate_in() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	scale = Vector2(1.0, 0.2)
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _animate_out() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(1.0, 0.2), 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_tween.tween_callback(func() -> void: visible = false)
