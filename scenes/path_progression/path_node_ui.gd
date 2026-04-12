class_name PathNodeUI
extends TextureButton
## Visual representation of a single path tree node.
## Handles hover effects, click signaling, and display state.

signal node_clicked(node_id: String)

@onready var _border: Panel = %Border
@onready var _level_label: Label = %LevelLabel
@onready var _tooltip: PathNodeTooltip = %Tooltip

var _node_data: PathNodeData = null
var _hover_tween: Tween = null

## Color constants
const COLOR_GOLD: Color = Color("#a89070")
const COLOR_WHITE: Color = Color.WHITE
const COLOR_DIM_WHITE: Color = Color(1.0, 1.0, 1.0, 0.4)
const COLOR_LOCKED: Color = Color(1.0, 1.0, 1.0, 0.15)

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Initialize the node UI with its data and current purchase level.
func setup(data: PathNodeData, current_level: int) -> void:
	_node_data = data
	if data.icon:
		texture_normal = data.icon
	tooltip_text = ""
	refresh(current_level, false)


## Update visual state after a purchase or point balance change.
func refresh(current_level: int, can_afford: bool) -> void:
	if _node_data == null:
		return

	var is_maxed: bool = current_level >= _node_data.max_purchases
	var is_purchased: bool = current_level >= 1

	# Level label for repeatable nodes
	if _node_data.max_purchases > 1:
		_level_label.text = "%d/%d" % [current_level, _node_data.max_purchases]
		_level_label.visible = true
	else:
		_level_label.visible = false

	# Border color
	var border_style: StyleBoxFlat = _border.get_theme_stylebox("panel") as StyleBoxFlat
	if border_style:
		if is_maxed:
			border_style.border_color = COLOR_GOLD
		elif is_purchased:
			border_style.border_color = COLOR_WHITE
		elif can_afford:
			border_style.border_color = COLOR_DIM_WHITE
		else:
			border_style.border_color = COLOR_LOCKED

	# Modulate alpha
	if is_purchased or can_afford:
		modulate.a = 1.0
	else:
		modulate.a = 0.5

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)
	pivot_offset = size / 2.0
	_tooltip.visible = false


func _on_mouse_entered() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	if _node_data:
		var current_level: int = PathManager.get_node_purchase_count(_node_data.id)
		_tooltip.show_tooltip(_node_data, current_level)


func _on_mouse_exited() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tooltip.hide_tooltip()


func _on_pressed() -> void:
	if _node_data:
		node_clicked.emit(_node_data.id)
