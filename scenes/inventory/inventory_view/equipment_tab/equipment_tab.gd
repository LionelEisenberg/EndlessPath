extends Control

@onready var equipment_grid: Control = %EquipmentGrid
@onready var gear_selector: Control = %GearSelector
@onready var selector_sprite: Node2D = %SelectorSprite
@onready var selector_anim: AnimationPlayer = %AnimationPlayer
@onready var item_description_box : TextureRect = %ItemDescriptionBox
@onready var trash_slot : TrashSlot = %TrashSlot
@onready var sort_banner: SortSubBanner = %SortSubBanner
@onready var grid_toolbar: GridToolbar = %GridToolbar

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var dragged_item: Control = null
var original_slot: InventorySlot = null
var is_dragging: bool = false
const POSITION_OFFSET = Vector2(0, -15)
const SELECTOR_OFFSET = Vector2(28, 28)

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	# Connect drag signals
	equipment_grid.slot_clicked.connect(_on_slot_input)
	gear_selector.slot_clicked.connect(_on_slot_input)

	item_description_box.reset()
	selector_sprite.visible = false

	sort_banner.set_options(PackedStringArray(["All", "Weapons", "Armor", "Accessories"]))
	sort_banner.enabled = false  # filtering wiring is deferred per spec
	grid_toolbar.set_trash_slot(trash_slot)

	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_refresh_count()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_inventory_changed(_inventory: InventoryData) -> void:
	_refresh_count()

func _refresh_count() -> void:
	var inventory := InventoryManager.get_inventory()
	grid_toolbar.set_count(inventory.equipment.size(), EquipmentGrid.NUM_INVENTORY_SLOTS)

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
		if not is_dragging:
			if slot.item_instance:
				item_description_box.setup(slot.item_instance.item_instance_data)
			else:
				item_description_box.reset()
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_dragging:
			if slot is TrashSlot and (slot as TrashSlot).is_holding():
				_pick_up_from_trash(slot as TrashSlot, event.global_position)
				return
			if slot.item_instance != null:
				_pick_up_item(slot, event.global_position)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if not is_dragging and slot.item_instance != null:
			_quick_equip(slot)

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

		# Show tooltip for the item being dragged
		if dragged_item.item_instance_data:
			item_description_box.setup(dragged_item.item_instance_data)

		add_child(dragged_item)
		dragged_item.global_position = global_mouse_pos + POSITION_OFFSET
		dragged_item.scale = Vector2(1.0, 1.0)
		dragged_item.mouse_filter = Control.MOUSE_FILTER_IGNORE # Pass events through to slots below

func _drop_item(global_mouse_pos: Vector2) -> void:
	var target_slot = _get_slot_under_mouse(global_mouse_pos)
	dragged_item.scale = Vector2(1.0, 1.0)

	# Trash drop short-circuits everything else.
	if target_slot is TrashSlot:
		_handle_trash_drop(target_slot as TrashSlot)
		_cleanup_drag()
		return

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
				InventoryManager.equip_item(item_data, target_slot.slot_type, from_index, target_slot.accessory_index)
				dragged_item.queue_free()

			# Case 2: GearSlot -> GearSlot (only meaningful between the two accessory slots)
			else:
				InventoryManager.swap_accessory_slots(original_slot.accessory_index, target_slot.accessory_index)
				dragged_item.queue_free()

		elif original_slot is GearSlot:
			# Dropping FROM GearSlot TO Grid (Unequipping to specific slot)
			var target_index = target_slot.get_index()
			InventoryManager.unequip_item_to_slot(original_slot.slot_type, target_index, original_slot.accessory_index)
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

#-----------------------------------------------------------------------------
# QUICK EQUIP (Right-Click)
#-----------------------------------------------------------------------------

## Right-click to equip from grid, or unequip from gear slot.
func _quick_equip(slot: InventorySlot) -> void:
	var item_data: ItemInstanceData = slot.item_instance.item_instance_data
	if not item_data.item_definition is EquipmentDefinitionData:
		return

	if slot is GearSlot:
		# Right-click on gear slot → unequip to grid
		InventoryManager.unequip_item(slot.slot_type, slot.accessory_index)
	else:
		# Right-click on grid slot → equip to matching gear slot
		var equip_def: EquipmentDefinitionData = item_data.item_definition as EquipmentDefinitionData
		var from_index: int = slot.get_index()
		var accessory_index: int = -1
		# For accessories, pick the first empty physical slot (else slot 0 to swap).
		if equip_def.slot_type == EquipmentDefinitionData.EquipmentSlot.ACCESSORY:
			var equipped: Dictionary = InventoryManager.get_inventory().equipped_accessories
			if not equipped.has(0):
				accessory_index = 0
			elif not equipped.has(1):
				accessory_index = 1
			else:
				accessory_index = 0
		InventoryManager.equip_item(item_data, equip_def.slot_type, from_index, accessory_index)

#-----------------------------------------------------------------------------
# DRAG HELPERS
#-----------------------------------------------------------------------------

func _return_to_original() -> void:
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

	# Check TrashSlot
	if trash_slot and trash_slot.get_global_rect().has_point(global_pos):
		return trash_slot

	return null

#-----------------------------------------------------------------------------
# TRASH SLOT
#-----------------------------------------------------------------------------

func _handle_trash_drop(trash: TrashSlot) -> void:
	if dragged_item == null:
		return
	var data: ItemInstanceData = dragged_item.item_instance_data
	var prior_name: String = trash.accept(data)
	if prior_name != "":
		_show_discard_flash(prior_name)
	# The visual disappeared when the item was picked up, but the inventory
	# dictionary still holds a reference. Remove that reference so the next
	# refresh doesn't restore the item visually. Skip when the drag started
	# from the trash itself (item was never in inventory while held).
	_remove_dragged_from_inventory_state()
	dragged_item.queue_free()

## Removes the dragged item from InventoryData based on where it came from.
## No-op if the drag originated in the trash slot itself.
func _remove_dragged_from_inventory_state() -> void:
	if original_slot == null or original_slot is TrashSlot:
		return
	var inventory: InventoryData = InventoryManager.get_inventory()
	if original_slot is GearSlot:
		var gear: GearSlot = original_slot as GearSlot
		if gear.accessory_index >= 0:
			inventory.equipped_accessories.erase(gear.accessory_index)
		else:
			inventory.equipped_gear.erase(gear.slot_type)
	else:
		var from_index: int = original_slot.get_index()
		inventory.equipment.erase(from_index)
	InventoryManager.inventory_changed.emit(inventory)

func _show_discard_flash(item_name: String) -> void:
	var flash := get_tree().get_first_node_in_group("DiscardFlashes")
	if flash and flash.has_method("show_for"):
		flash.show_for(item_name)

func _pick_up_from_trash(trash: TrashSlot, global_mouse_pos: Vector2) -> void:
	var held = trash.get_held()
	trash.clear_hold()

	# Equipment instances are dragged as visual ItemInstance controls.
	if held is ItemInstanceData:
		var item_instance_scene: PackedScene = preload("res://scenes/inventory/item_instance/item_instance.tscn")
		var visual: Control = item_instance_scene.instantiate()
		add_child(visual)
		visual.setup(held)
		dragged_item = visual
		is_dragging = true
		original_slot = trash
		dragged_item.global_position = global_mouse_pos + POSITION_OFFSET
		dragged_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Show tooltip for the dragged item.
		if item_description_box:
			item_description_box.setup(held)
