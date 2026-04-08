extends VBoxContainer
## Section container for a category of zone actions with colored dot indicator.

@export var action_type: ZoneActionData.ActionType = ZoneActionData.ActionType.FORAGE
@export var zone_action_data_list: Array[ZoneActionData] = []

@onready var _button_section: VBoxContainer = %ZoneActionButtonSection
@onready var _category_label: Label = %CategoryLabel
@onready var _category_dot: ColorRect = %CategoryDot

var _zone_action_button_scene: PackedScene = preload("res://scenes/zones/zone_action_button/zone_action_button.tscn")

func _ready() -> void:
	for child in _button_section.get_children():
		child.queue_free()
	_populate_actions()
	_populate_header()

func _populate_actions() -> void:
	for action in zone_action_data_list:
		if action.action_type == action_type:
			var new_action_button: MarginContainer = _zone_action_button_scene.instantiate()
			new_action_button.setup_action(action)
			_button_section.add_child(new_action_button)

func _populate_header() -> void:
	var label_text: String = ""
	var dot_color: Color = Color.WHITE
	match action_type:
		ZoneActionData.ActionType.FORAGE:
			label_text = "FORAGING"
			dot_color = Color(0.42, 0.67, 0.37)
		ZoneActionData.ActionType.CYCLING:
			label_text = "CYCLING"
			dot_color = Color(0.37, 0.66, 0.62)
		ZoneActionData.ActionType.ADVENTURE:
			label_text = "ADVENTURE"
			dot_color = Color(0.61, 0.25, 0.25)
		ZoneActionData.ActionType.NPC_DIALOGUE:
			label_text = "DIALOGUE"
			dot_color = Color(0.83, 0.66, 0.29)
		_:
			label_text = "ACTIONS"
			dot_color = Color(0.5, 0.5, 0.5)
	_category_label.text = label_text
	_category_dot.color = dot_color
