extends PanelContainer

signal technique_change_request(data: CyclingTechniqueData)

@onready var close_selector_button : TextureButton = %CloseSelectorButton
@onready var slots_container: GridContainer = %CyclingTechniqueGridContainer
@onready var cycling_technique_slot_scene : PackedScene = preload("res://scenes/cycling/cycling_technique_selector/cycling_technique_slot.tscn")
@onready var info_panel: PanelContainer = %InfoPanel

@export var cycling_technique_list : CyclingTechniqueList = null

var selected_technique_data: CyclingTechniqueData = null

func _ready() -> void:
	close_selector_button.pressed.connect(close_selector)
	setup()

func close_selector() -> void:
	self.visible = false

func open_selector(data: CyclingTechniqueData) -> void:
	self.visible = true
	selected_technique_data = data
	info_panel.setup(selected_technique_data)

	for slot in slots_container.get_children():
		if selected_technique_data:
			slot.set_selected(slot.technique_data == selected_technique_data)
		else:
			slot.set_selected(false)

func setup() -> void:
	if not cycling_technique_list:
		return

	# Clear previous children
	for child in slots_container.get_children():
		child.queue_free()

	for technique_data in cycling_technique_list.cycling_techniques:
		var slot = cycling_technique_slot_scene.instantiate()
		slots_container.add_child(slot)
		slot.setup(technique_data)

		slot.slot_selected.connect(_on_technique_slot_selected)
	
	info_panel.change_technique_button.pressed.connect(_on_change_technique_button_pressed)

func _on_technique_slot_selected(data: CyclingTechniqueData) -> void:
	selected_technique_data = data
	info_panel.setup(selected_technique_data)

	for slot in slots_container.get_children():
		slot.set_selected(slot.technique_data == selected_technique_data)

func _on_change_technique_button_pressed() -> void:
	if selected_technique_data:
		technique_change_request.emit(selected_technique_data)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_selector()
