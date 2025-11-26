class_name EquipmentGrid
extends MarginContainer

## EquipmentGrid
## Manages the grid view of equipment items and custom scrollbar logic

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const SCROLL_MIN_Y = 0.025
const SCROLL_MAX_Y = 0.90

const POSITION_OFFSET = Vector2(-35, -35)

# TODO: DELETE / REPLACE WITH VALUES WHICH WILL FETCHED FORM AN INVENTORY MANAGER
const NUM_INVENTORY_SLOTS = 50

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var v_scroll_bar : VScrollBar = %VScrollBar
@onready var grabber : TextureRect = %Grabber
@onready var scroll_container : ScrollContainer = %ScrollContainer
@onready var grid_container : GridContainer = %GridContainer

signal slot_clicked(slot: InventorySlot, event: InputEvent)

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

# Drag logic moved to InventoryView

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

var inventory_slot_scene : PackedScene = preload("res://scenes/ui/inventory/inventory_view/equipment_grid/inventory_slot/inventory_slot.tscn")

@export var default_item_instance_data = null
#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	scroll_container.get_v_scroll_bar().scrolling.connect(_on_scrolling)
	
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_update_grid(InventoryManager.get_inventory())

#-----------------------------------------------------------------------------
# INPUT HANDLING
#-----------------------------------------------------------------------------

func _on_slot_clicked(slot: InventorySlot, event: InputEvent) -> void:
	slot_clicked.emit(slot, event)

func get_slots() -> Array[InventorySlot]:
	var slots: Array[InventorySlot] = []
	for child in grid_container.get_children():
		if child is InventorySlot:
			slots.append(child)
	return slots

#-----------------------------------------------------------------------------
# SETUP FUNCTIONS
#-----------------------------------------------------------------------------

func _on_inventory_changed(inventory: InventoryData) -> void:
	_update_grid(inventory)

func _update_grid(inventory: InventoryData) -> void:
	# Clear existing slots
	for slot in grid_container.get_children():
		slot.queue_free()
	
	# Create slots for equipment
	var equipment_dict = inventory.equipment
	
	for i in NUM_INVENTORY_SLOTS:
		var slot = inventory_slot_scene.instantiate()
		slot.clicked.connect(_on_slot_clicked)
		grid_container.add_child(slot)
		
		# Check if we have an item at this index
		if equipment_dict.has(i):
			slot.setup(equipment_dict[i])
		else:
			slot.setup(null)

func _on_scrolling() -> void:
	var page = scroll_container.get_v_scroll_bar().page
	var ratio = scroll_container.get_v_scroll_bar().value / (scroll_container.get_v_scroll_bar().max_value - page)
	# Maps scroll ratio 0.0-1.0 to visual range SCROLL_MIN_Y-SCROLL_MAX_Y
	grabber.position.y = clampf(ratio, SCROLL_MIN_Y, SCROLL_MAX_Y) * v_scroll_bar.get_size().y
