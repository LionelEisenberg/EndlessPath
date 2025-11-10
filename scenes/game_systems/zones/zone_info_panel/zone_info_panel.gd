extends PanelContainer

@onready var current_zone_data : ZoneData = ZoneManager.get_current_zone()
@onready var actions_content_vbox : VBoxContainer = %ActionsContent

@onready var zone_action_type_section_scene : PackedScene = preload("res://scenes/game_systems/zones/zone_action_type_section/zone_action_type_section.tscn")

func _ready() -> void:
	if ZoneManager:
		ZoneManager.zone_changed.connect(_on_zone_changed)
		current_zone_data = ZoneManager.get_current_zone()
	
	if current_zone_data:
		setup_zone_actions()
	

func _on_zone_changed(zone_data: ZoneData) -> void:
	if zone_data != current_zone_data:
		current_zone_data = zone_data
		setup_zone_actions()
	
func setup_zone_actions() -> void:
	if actions_content_vbox:
		for child in actions_content_vbox.get_children():
			child.queue_free()
	
	for action_type in ZoneActionData.ActionType.values():
		for action_data in current_zone_data.available_actions:
			if action_data.action_type == action_type:
				var new_zone_action_type_section = zone_action_type_section_scene.instantiate()
				new_zone_action_type_section.action_type = action_type
				new_zone_action_type_section.zone_action_data_list = current_zone_data.available_actions
				actions_content_vbox.add_child(new_zone_action_type_section)
				break
