extends Control

@onready var materials_tab : MarginContainer = %MaterialsTab

# Signal for opening the inventory
signal open_inventory

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
	if visible and event.is_action_pressed("close_inventory"):
		close_inventory.emit()
		return
	
	if event.is_action_pressed("open_inventory"):
		open_inventory.emit()
		return

func populate_materials_tab(materials : Dictionary[MaterialDefinitionData, int]) -> void:
	materials_tab.populate_grid_container(materials)

func _on_inventory_changed(inventory: InventoryData) -> void:
	populate_materials_tab(inventory.materials)
