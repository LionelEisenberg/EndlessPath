extends PanelContainer

@onready var close_selector_button : TextureButton = %CloseSelectorButton
@onready var slots_container: GridContainer = %CyclingTechniqueGridContainer
@onready var cycling_technique_slot_scene : PackedScene = preload("res://scenes/game_systems/cycling/cycling_technique_selector/cycling_technique_slot.tscn")

@export var cycling_technique_list : CyclingTechniqueList = null


func _ready() -> void:
	close_selector_button.pressed.connect(close_selector)
	setup()

func close_selector() -> void:
	self.visible = false

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
