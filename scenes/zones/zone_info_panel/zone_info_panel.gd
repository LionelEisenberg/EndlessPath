extends PanelContainer

@onready var current_zone_data: ZoneData = ZoneManager.get_current_zone()
@onready var actions_content_vbox: VBoxContainer = %ActionsContent
@onready var zone_title: RichTextLabel = %ZoneTitle
@onready var zone_description: RichTextLabel = %ZoneDescription

@onready var zone_action_type_section_scene: PackedScene = preload("res://scenes/zones/zone_action_type_section/zone_action_type_section.tscn")

func _ready() -> void:
	if ZoneManager:
		ZoneManager.zone_changed.connect(_on_zone_changed)
		ZoneManager.action_completed.connect(_on_action_completed)
		current_zone_data = ZoneManager.get_current_zone()
	else:
		Log.critical("ZoneInfoPanel: ZoneManager is not initialized")

	if UnlockManager:
		UnlockManager.condition_unlocked.connect(_on_condition_unlocked)
	else:
		Log.critical("ZoneInfoPanel: UnlockManager is not initialized")

	if current_zone_data:
		setup_zone_actions()
		setup_zone_info()
	
## Sets up the zone information display.
func setup_zone_info() -> void:
	if current_zone_data:
		zone_title.text = "Current Zone: " + current_zone_data.zone_name
		zone_description.text = current_zone_data.description

func _on_zone_changed(zone_data: ZoneData) -> void:
	if zone_data != current_zone_data:
		current_zone_data = zone_data
		setup_zone_actions()
		setup_zone_info()

func _on_action_completed(_args = null) -> void:
	setup_zone_actions()

func _on_condition_unlocked(_args = null) -> void:
	setup_zone_actions()

## Sets up the zone actions list.
func setup_zone_actions() -> void:
	if actions_content_vbox:
		for child in actions_content_vbox.get_children():
			child.queue_free()
	
	var available_actions: Array[ZoneActionData] = ZoneManager.get_available_actions()
	
	for action_type in ZoneActionData.ActionType.values():
		for action_data in available_actions:
			if action_data.action_type == action_type:
				var new_zone_action_type_section = zone_action_type_section_scene.instantiate()
				new_zone_action_type_section.action_type = action_type
				new_zone_action_type_section.zone_action_data_list = available_actions
				actions_content_vbox.add_child(new_zone_action_type_section)
				break
