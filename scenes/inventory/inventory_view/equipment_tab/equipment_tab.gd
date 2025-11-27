extends Control

@onready var equipment_grid: Control = %EquipmentGrid
@onready var gear_selector: Control = %GearSelector
@onready var selector_sprite: Node2D = %SelectorSprite
@onready var selector_anim: AnimationPlayer = %AnimationPlayer
@onready var item_description_box : TextureRect = %ItemDescriptionBox
@onready var trash_slot : TrashSlot = %TrashSlot

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var dragged_item: Control = null
var original_slot: InventorySlot = null
var is_dragging: bool = false
const POSITION_OFFSET = Vector2(-35, -35)
const SELECTOR_OFFSET = Vector2(28, 28)

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	# Connect drag signals
	equipment_grid.slot_clicked.connect(_on_slot_input)
	gear_selector.slot_clicked.connect(_on_slot_input)
	
	item_description_box.reset()

#-----------------------------------------------------------------------------
# INPUT HANDLING
#-----------------------------------------------------------------------------

func _input(event):
	if is_dragging and dragged_item:
		if event is InputEventMouseMotion:
			dragged_item.global_position = get_global_mouse_position() + POSITION_OFFSET
		
		elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_drop_item(get_global_mouse_position())

#-----------------------------------------------------------------------------
# DRAG AND DROP
#-----------------------------------------------------------------------------

func _on_slot_input(slot: InventorySlot, event: InputEvent) -> void:
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		_update_selector(slot)
		if slot.item_instance:
			item_description_box.setup(slot.item_instance.item_instance_data)
		else:
			item_description_box.reset()
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_dragging and slot.item_instance != null:
			_pick_up_item(slot, event.global_position)

func _update_selector(slot: InventorySlot) -> void:
	selector_sprite.global_position = slot.global_position + SELECTOR_OFFSET
	if not selector_sprite.visible:
		selector_sprite.visible = true
		selector_anim.play("start_select")
	elif selector_anim.current_animation != "start_select":
		selector_anim.play("start_select")

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
		# Check if target slot accepts this item
		var item_data = dragged_item.item_instance_data
		
		# Validation for GearSlot
		if target_slot is GearSlot:
			if not target_slot.is_valid_item(item_data):
				_return_to_original()
				_cleanup_drag()
				return
		
		# Logic for swapping/moving via InventoryManager
		if target_slot is GearSlot:
			# Dropping ONTO a gear slot (Equipping)
			
			# Case 1: Grid -> GearSlot
			if not (original_slot is GearSlot):
				# We need the index of the original slot
				var from_index = original_slot.get_index()
				InventoryManager.equip_item(item_data, target_slot.slot_type, from_index)
				dragged_item.queue_free()
				
			# Case 2: GearSlot -> GearSlot (Swap slots? e.g. Accessory 1 to 2)
			else:
				InventoryManager.unequip_item(original_slot.slot_type)
				InventoryManager.equip_item(item_data, target_slot.slot_type)
				dragged_item.queue_free()
				
		elif original_slot is GearSlot:
			# Dropping FROM GearSlot TO Grid (Unequipping to specific slot)
			var target_index = target_slot.get_index()
			InventoryManager.unequip_item_to_slot(original_slot.slot_type, target_index)
			dragged_item.queue_free()
				
		else:
			# Grid -> Grid (Reordering)
			var from_index = original_slot.get_index()
			var to_index = target_slot.get_index()
			
			InventoryManager.move_equipment(from_index, to_index)
			
			# Visual update is handled by InventoryManager signal -> EquipmentGrid update
			dragged_item.queue_free()
	else:
		_return_to_original()
	
	_cleanup_drag()

func _return_to_original() -> void:
	Log.debug(dragged_item)
	original_slot.equip_item(dragged_item)

func _cleanup_drag() -> void:
	if dragged_item:
		dragged_item.z_index = 0
		dragged_item.mouse_filter = Control.MOUSE_FILTER_PASS
	dragged_item = null
	original_slot = null
	is_dragging = false

func _get_slot_under_mouse(global_pos: Vector2) -> InventorySlot:
	# Check EquipmentGrid slots
	for slot in equipment_grid.get_slots():
		if slot.get_global_rect().has_point(global_pos):
			return slot
	
	# Check GearSelector slots
	for slot in gear_selector.get_slots():
		if slot.get_global_rect().has_point(global_pos):
			return slot
			
	return null
