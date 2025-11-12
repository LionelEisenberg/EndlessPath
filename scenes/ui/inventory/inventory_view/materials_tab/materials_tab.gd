extends MarginContainer

@onready var grid_container : GridContainer = %GridContainer

var material_container_scene : PackedScene = preload("res://scenes/ui/inventory/inventory_view/materials_tab/material_container.tscn")

func populate_grid_container(materials: Dictionary[MaterialDefinitionData, int]) -> void:
	# Clear the grid container
	for child in grid_container.get_children():
		child.queue_free()

	for material_data in materials.keys():
		var new_material_instance = material_container_scene.instantiate()
		new_material_instance.material_data = material_data
		new_material_instance.material_quantity = materials[material_data]
		grid_container.add_child(new_material_instance)
