extends MarginContainer

signal action_selected(action_data: ZoneActionData)

@export var action_data: ZoneActionData = null
@export var is_unlocked: bool = true
@export var is_completed: bool = false
@export var completion_count: int = 0

@onready var icon_texture: TextureRect = %IconTexture
@onready var zone_action_button: Button = %ZoneActionButton
@onready var name_label: Label = %NameLabel

func _ready():
	if action_data:
		setup_action(action_data)
	
	zone_action_button.pressed.connect(_on_button_pressed)

func setup_action(data: ZoneActionData) -> void:
	action_data = data
	
	if name_label:
		name_label.text = data.action_name
	
	if icon_texture and data.icon:
		icon_texture.texture = data.icon

func _on_button_pressed() -> void:
	if action_data and not zone_action_button.disabled:
		action_selected.emit(action_data)
