extends MarginContainer
## Card-style encounter choice button.

const CARD_NORMAL: StyleBox = preload("res://assets/styleboxes/zones/action_card_normal.tres")
const CARD_HOVER: StyleBox = preload("res://assets/styleboxes/zones/action_card_hover.tres")

signal button_pressed

@onready var _choice_card: PanelContainer = %ChoiceCard
@onready var _choice_label: Label = %ChoiceLabel

var _label_text: String = ""
var _is_disabled: bool = false

## Sets up the button with label, texture, and color.
func setup(label: String, _texture: Texture2D, _fill_color: Color, is_disabled: bool) -> void:
	_label_text = label
	_is_disabled = is_disabled

func _ready() -> void:
	_choice_label.text = _label_text
	if _is_disabled:
		_choice_label.modulate.a = 0.4
	_choice_card.mouse_entered.connect(_on_mouse_entered)
	_choice_card.mouse_exited.connect(_on_mouse_exited)
	_choice_card.gui_input.connect(_on_card_input)

func _on_card_input(event: InputEvent) -> void:
	if _is_disabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		button_pressed.emit()

func _on_mouse_entered() -> void:
	if not _is_disabled:
		_choice_card.add_theme_stylebox_override("panel", CARD_HOVER)

func _on_mouse_exited() -> void:
	_choice_card.add_theme_stylebox_override("panel", CARD_NORMAL)
