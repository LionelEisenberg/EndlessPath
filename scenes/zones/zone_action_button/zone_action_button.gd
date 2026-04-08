extends MarginContainer
## Action card button for zone actions.

const CARD_NORMAL: StyleBox = preload("res://assets/styleboxes/action_card_normal.tres")
const CARD_HOVER: StyleBox = preload("res://assets/styleboxes/action_card_hover.tres")

@export var action_data: ZoneActionData
@export var is_current_action: bool = false:
	set(value):
		is_current_action = value
		if is_instance_valid(_action_card):
			_update_card_style()

@onready var _action_card: PanelContainer = %ActionCard
@onready var _action_name_label: Label = %ActionNameLabel
@onready var _action_desc_label: Label = %ActionDescLabel

func _ready() -> void:
	ActionManager.current_action_changed.connect(_on_current_action_changed)
	if ActionManager.get_current_action() == action_data:
		is_current_action = true
	_action_card.mouse_entered.connect(_on_mouse_entered)
	_action_card.mouse_exited.connect(_on_mouse_exited)
	_action_card.gui_input.connect(_on_card_input)
	if action_data:
		_action_name_label.text = action_data.action_name
		if action_data.description != "":
			_action_desc_label.text = action_data.description
			_action_desc_label.visible = true
		else:
			_action_desc_label.text = ""
			_action_desc_label.visible = false

## Sets up the card with action data.
func setup_action(data: ZoneActionData) -> void:
	action_data = data
	if is_instance_valid(_action_name_label):
		_action_name_label.text = data.action_name
	if is_instance_valid(_action_desc_label):
		_action_desc_label.text = data.description if data.description != "" else ""
		_action_desc_label.visible = data.description != ""

func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_current_action:
			ActionManager.select_action(action_data)

func _on_mouse_entered() -> void:
	if not is_current_action:
		_action_card.add_theme_stylebox_override("panel", CARD_HOVER)

func _on_mouse_exited() -> void:
	_update_card_style()

func _update_card_style() -> void:
	if is_current_action:
		_action_card.add_theme_stylebox_override("panel", CARD_HOVER)
	else:
		_action_card.add_theme_stylebox_override("panel", CARD_NORMAL)

func _on_current_action_changed(_new_action: ZoneActionData) -> void:
	var new_is_current: bool = ActionManager.get_current_action() == action_data
	is_current_action = new_is_current
