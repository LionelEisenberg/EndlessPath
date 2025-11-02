extends PanelContainer

signal action_selected(action_data: ZoneActionData)
signal forage_stopped()

@export var zone_data: ZoneData = null

@onready var zone_name_label: Label = %ZoneNameLabel
@onready var zone_tier_label: Label = %ZoneTierLabel
@onready var zone_description_label: RichTextLabel = %ZoneDescriptionLabel
@onready var actions_grid_container: GridContainer = %ActionsGridContainer
@onready var forage_status_section: VBoxContainer = %ForageStatusSection
@onready var forage_active_label: Label = %ForageActiveLabel
@onready var forage_stop_button: Button = %ForageStopButton

var action_button_scene = preload("res://scenes/game_systems/zones/zone_action_button/zone_action_button.tscn")

func _ready():
	if forage_stop_button:
		forage_stop_button.pressed.connect(_on_forage_stop_pressed)
	
	if forage_status_section:
		forage_status_section.visible = false

func update_zone_info(data: ZoneData) -> void:
	zone_data = data
	
	if not data:
		_clear_zone_info()
		return
	
	# Update zone header
	if zone_name_label:
		zone_name_label.text = data.zone_name
	
	if zone_tier_label:
		# TODO: Add zone_tier to ZoneData if not present
		zone_tier_label.text = "Tier: N/A"  # Placeholder
	
	if zone_description_label:
		zone_description_label.text = data.description
	
	# Update actions
	_update_actions()

func _clear_zone_info() -> void:
	if zone_name_label:
		zone_name_label.text = ""
	if zone_tier_label:
		zone_tier_label.text = ""
	if zone_description_label:
		zone_description_label.text = ""
	
	_clear_actions()

func _update_actions() -> void:
	if not zone_data:
		return
	
	_clear_actions()
	
	if not actions_grid_container:
		return
	
	# Create action buttons for each available action
	for action_data in zone_data.available_actions:
		var button_instance = action_button_scene.instantiate()
		button_instance.setup_action(action_data)
		button_instance.action_selected.connect(_on_action_selected)
		actions_grid_container.add_child(button_instance)

func _clear_actions() -> void:
	if not actions_grid_container:
		return
	
	for child in actions_grid_container.get_children():
		child.queue_free()

func _on_action_selected(action_data: ZoneActionData) -> void:
	action_selected.emit(action_data)

func set_forage_active(active: bool, zone_id: String = "") -> void:
	if forage_status_section:
		forage_status_section.visible = active
	
	if active and forage_active_label:
		forage_active_label.text = "Foraging in: %s" % (zone_id if zone_id else "Current Zone")

func _on_forage_stop_pressed() -> void:
	forage_stopped.emit()
	set_forage_active(false)

