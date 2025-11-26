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

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var dragged_item: Control = null
var original_slot: InventorySlot = null
var is_dragging: bool = false

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

var inventory_slot_scene : PackedScene = preload("res://scenes/ui/inventory/inventory_view/equipment_grid/inventory_slot/inventory_slot.tscn")

@export var default_item_instance_data = null
#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	default_item_instance_data = load("res://resources/items/test_items/dagger_instance.tres")
	scroll_container.get_v_scroll_bar().scrolling.connect(_on_scrolling)

	_intialize_grid_container()

#-----------------------------------------------------------------------------
# INPUT HANDLING
#-----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if is_dragging and dragged_item:
		if event is InputEventMouseMotion:
			dragged_item.global_position = get_global_mouse_position() + POSITION_OFFSET
		
		elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_drop_item(get_global_mouse_position())

func _on_slot_clicked(slot: InventorySlot, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_dragging and slot.item_instance != null:
			_pick_up_item(slot, event.global_position)

func _pick_up_item(slot: InventorySlot, global_mouse_pos: Vector2) -> void:
	var item = slot.grab_item()
	if item:
		dragged_item = item
		
		is_dragging = true
		original_slot = slot
		
		get_tree().root.add_child(dragged_item)
		dragged_item.global_position = global_mouse_pos + POSITION_OFFSET
		dragged_item.scale = Vector2(2.0, 2.0)
		dragged_item.mouse_filter = Control.MOUSE_FILTER_IGNORE # Pass events through to slots below

func _drop_item(global_mouse_pos: Vector2) -> void:
	var target_slot = _get_slot_under_mouse(global_mouse_pos)
	dragged_item.scale = Vector2(1.0, 1.0)
	if target_slot and target_slot != original_slot:
		if target_slot.item_instance == null:
			# Drop into empty slot
			target_slot.equip_item(dragged_item)
		else:
			# Swap
			var target_item = target_slot.grab_item()
			
			target_slot.equip_item(dragged_item)
			original_slot.equip_item(target_item)
	else:
		# Return to original slot
		original_slot.equip_item(dragged_item)
	
	# Cleanup
	dragged_item.z_index = 0
	dragged_item.mouse_filter = Control.MOUSE_FILTER_PASS
	dragged_item = null
	original_slot = null
	is_dragging = false

func _get_slot_under_mouse(global_pos: Vector2) -> InventorySlot:
	for slot in grid_container.get_children():
		if slot is InventorySlot and slot.get_global_rect().has_point(global_pos):
			return slot
	return null

#-----------------------------------------------------------------------------
# SETUP FUNCTIONS
#-----------------------------------------------------------------------------

func _intialize_grid_container() -> void:
	for slot in grid_container.get_children():
		slot.queue_free()
	
	for i in NUM_INVENTORY_SLOTS:
		var slot = inventory_slot_scene.instantiate()
		slot.clicked.connect(_on_slot_clicked)
		grid_container.add_child(slot)
		if randi() % 2 == 0:
			if randi() % 2 == 0:
				slot.setup(default_item_instance_data)
			else:
				slot.setup(load("res://resources/items/test_items/sword_instance.tres"))

func _on_scrolling() -> void:
	var page = scroll_container.get_v_scroll_bar().page
	var ratio = scroll_container.get_v_scroll_bar().value / (scroll_container.get_v_scroll_bar().max_value - page)
	# Maps scroll ratio 0.0-1.0 to visual range SCROLL_MIN_Y-SCROLL_MAX_Y
	grabber.position.y = clampf(ratio, SCROLL_MIN_Y, SCROLL_MAX_Y) * v_scroll_bar.get_size().y
