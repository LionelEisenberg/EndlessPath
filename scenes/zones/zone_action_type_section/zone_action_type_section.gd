extends VBoxContainer

@export var action_type: ZoneActionData.ActionType = ZoneActionData.ActionType.FORAGE
@export var zone_action_data_list: Array[ZoneActionData] = []

@onready var zone_action_button_scene: PackedScene = preload("res://scenes/zones/zone_action_button/zone_action_button.tscn")
@onready var button_section: VBoxContainer = %ZoneActionButtonSection
@onready var action_type_header_label: Label = %ActionTypeHeaderLabel

func _ready() -> void:
	if zone_action_data_list:
		if button_section:
			for child in button_section.get_children():
				child.queue_free()
		populate_actions(action_type, zone_action_data_list)
		populate_header(action_type)

## Populates the section with actions of the given type.
func populate_actions(type: ZoneActionData.ActionType, action_list: Array[ZoneActionData]) -> void:
	for action in action_list:
		if action.action_type == type:
			var new_action_button = zone_action_button_scene.instantiate()
			new_action_button.setup_action(action)
			button_section.add_child(new_action_button)
			
## Populates the header label based on the action type.
func populate_header(type: ZoneActionData.ActionType) -> void:
	match type:
		ZoneActionData.ActionType.FORAGE:
			action_type_header_label.text = "FORAGING ACTIONS"
		ZoneActionData.ActionType.CYCLING:
			action_type_header_label.text = "CYCLING ACTIONS"
		ZoneActionData.ActionType.NPC_DIALOGUE:
			action_type_header_label.text = "DIALOGUE ACTIONS"
