class_name EquipmentGrid
extends MarginContainer

## EquipmentGrid
## A fixed 6×6 (36-slot) page of the equipment inventory. The visible page
## is `current_page`; local slot child-index i maps to global inventory
## index current_page * SLOTS_PER_PAGE + i. No scrolling — navigation is
## handled by the PaginationBar.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const SLOTS_PER_PAGE := 36

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal slot_clicked(slot: InventorySlot, event: InputEvent)

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var grid_container: GridContainer = %GridContainer

var inventory_slot_scene: PackedScene = preload("res://scenes/inventory/inventory_view/equipment_tab/inventory_slot/inventory_slot.tscn")

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var current_page: int = 0

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_update_grid(InventoryManager.get_inventory())

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Switch to a page and re-render. Clamps to [0, unlocked_pages - 1].
func set_page(page: int) -> void:
	var inventory := InventoryManager.get_inventory()
	var max_page := inventory.unlocked_equipment_pages - 1
	current_page = clampi(page, 0, max_page)
	_update_grid(inventory)

## Returns the 36 InventorySlot children of the grid.
func get_slots() -> Array[InventorySlot]:
	var slots: Array[InventorySlot] = []
	for child in grid_container.get_children():
		if child is InventorySlot:
			slots.append(child)
	return slots

#-----------------------------------------------------------------------------
# SETUP FUNCTIONS
#-----------------------------------------------------------------------------

func _on_inventory_changed(_inventory: InventoryData) -> void:
	# A page may have been granted; re-clamp current_page and re-render.
	set_page(current_page)

func _update_grid(inventory: InventoryData) -> void:
	for slot in grid_container.get_children():
		slot.queue_free()
	var base := current_page * SLOTS_PER_PAGE
	for i in SLOTS_PER_PAGE:
		var slot = inventory_slot_scene.instantiate()
		slot.clicked.connect(_on_slot_clicked)
		grid_container.add_child(slot)
		var global_index := base + i
		if inventory.equipment.has(global_index):
			slot.setup(inventory.equipment[global_index])
		else:
			slot.setup(null)

#-----------------------------------------------------------------------------
# INPUT HANDLING
#-----------------------------------------------------------------------------

func _on_slot_clicked(slot: InventorySlot, event: InputEvent) -> void:
	slot_clicked.emit(slot, event)
