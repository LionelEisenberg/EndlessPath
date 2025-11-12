extends VBoxContainer

@export var action_type : ZoneActionData.ActionType = ZoneActionData.ActionType.FORAGE
@export var zone_action_data_list : Array[ZoneActionData] = []

@onready var zone_action_button_scene : PackedScene = preload("res://scenes/game_systems/zones/zone_action_button/zone_action_button.tscn")
@onready var button_section: VBoxContainer = %ZoneActionButtonSection
@onready var action_type_header_label: Label = %ActionTypeHeaderLabel

func _ready() -> void:
	if zone_action_data_list:
		if button_section:
			for child in button_section.get_children():
				child.queue_free()
		populate_actions(action_type, zone_action_data_list)
		populate_header(action_type)

func populate_actions(type: ZoneActionData.ActionType, action_list: Array[ZoneActionData]):
	for action in action_list:
		if action.action_type == type: 
			var new_action_button = zone_action_button_scene.instantiate()
			new_action_button.setup_action(action)
			button_section.add_child(new_action_button)
			
func populate_header(type: ZoneActionData.ActionType):
	match type:
		ZoneActionData.ActionType.FORAGE:
			action_type_header_label.text = "FORAGING ACTIONS"
		ZoneActionData.ActionType.CYCLING:
			action_type_header_label.text = "CYCLING ACTIONS"
