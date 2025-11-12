extends Control

@onready var materials_tab : MarginContainer = %MaterialsTab

# Signal for closing the inventory
signal close_inventory

func _ready() -> void:
	if InventoryManager:
		## Handle inventory signals
		InventoryManager.inventory_changed.connect(_on_inventory_changed)

		## Initialize tabs
		populate_materials_tab(InventoryManager.get_inventory().materials)

# Handle input for closing inventory
func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_inventory.emit()

func populate_materials_tab(materials : Dictionary[MaterialDefinitionData, int]) -> void:
	materials_tab.populate_grid_container(materials)

func _on_inventory_changed(inventory: InventoryData) -> void:
	populate_materials_tab(inventory.materials)
