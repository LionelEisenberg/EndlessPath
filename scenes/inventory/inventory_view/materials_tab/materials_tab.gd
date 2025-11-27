extends Control

@onready var materials_vbox: VBoxContainer = %MaterialsVbox

var material_container_scene: PackedScene = preload("res://scenes/inventory/inventory_view/materials_tab/material_container.tscn")

func _ready() -> void:
	if InventoryManager:
		## Handle inventory signals
		InventoryManager.inventory_changed.connect(_on_inventory_changed)

		## Initialize tabs
		populate_materials_tab(InventoryManager.get_material_items())

## Populates the tab with the given materials.
func populate_materials_tab(materials: Dictionary[MaterialDefinitionData, int]) -> void:
	# Clear the grid container
	for child in materials_vbox.get_children():
		child.queue_free()

	for material_data in materials.keys():
		var new_material_instance = material_container_scene.instantiate()
		new_material_instance.material_data = material_data
		new_material_instance.material_quantity = materials[material_data]
		materials_vbox.add_child(new_material_instance)

func _on_inventory_changed(inventory: InventoryData) -> void:
	populate_materials_tab(inventory.materials)
