extends Control

## EquipmentTab
## Left page is the paginated equipment grid + sort sub-banner; the bottom
## PaginationBar holds the count, page buttons, and trash slot. Right page is
## the gear selector + item detail card. Handles drag/drop between grid slots
## (paged → global index), gear slots, and the trash slot (hold-buffer).

@onready var equipment_grid: EquipmentGrid = %EquipmentGrid
@onready var gear_selector: Control = %GearSelector
@onready var selector_sprite: Node2D = %SelectorSprite
@onready var selector_anim: AnimationPlayer = %AnimationPlayer
@onready var item_description_box : TextureRect = %ItemDescriptionBox
@onready var sort_banner: SortSubBanner = %SortSubBanner
@onready var pagination_bar: PaginationBar = %PaginationBar
@onready var trash_slot : TrashSlot = pagination_bar.trash_slot

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var dragged_item: Control = null
var original_slot: InventorySlot = null
## Global equipment index a grid-origin drag started from (-1 for gear/trash
## origins). Captured at pickup because page-flipping mid-drag re-binds the
## persistent grid slots to another page, so the origin node's live index no
## longer reflects where the dragged item actually came from.
var original_grid_index: int = -1
var is_dragging: bool = false
## Category filters for the sort banner: each entry is { label: String,
## match: Callable } where match(ItemInstanceData) -> bool decides which items
## stay at full opacity. Built in _ready.
var _categories: Array = []
const POSITION_OFFSET = Vector2(0, -15)
const SELECTOR_OFFSET = Vector2(28, 28)

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	equipment_grid.slot_clicked.connect(_on_slot_input)
	gear_selector.slot_clicked.connect(_on_slot_input)
	if trash_slot:
		trash_slot.clicked.connect(_on_slot_input)

	pagination_bar.page_selected.connect(_on_page_selected)
	pagination_bar.page_hovered.connect(_on_page_hovered)

	item_description_box.reset()
	selector_sprite.visible = false

	_build_categories()
	var labels := PackedStringArray()
	for cat in _categories:
		labels.append(cat["label"])
	sort_banner.set_options(labels)
	sort_banner.enabled = true
	sort_banner.option_changed.connect(_on_filter_changed)

	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_refresh_pagination()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_inventory_changed(_inventory: InventoryData) -> void:
	_refresh_pagination()

func _refresh_pagination() -> void:
	var inventory := InventoryManager.get_inventory()
	pagination_bar.setup(inventory.unlocked_equipment_pages, equipment_grid.current_page)

func _on_page_selected(index: int) -> void:
	equipment_grid.set_page(index)
	pagination_bar.set_active_page(equipment_grid.current_page)

func _on_page_hovered(index: int) -> void:
	if is_dragging:
		equipment_grid.set_page(index)
		pagination_bar.set_active_page(equipment_grid.current_page)

## Global inventory index of a paged grid slot (local child-index + page offset).
func _grid_global_index(slot: InventorySlot) -> int:
	return equipment_grid.current_page * equipment_grid.slots_per_page() + slot.get_index()

#-----------------------------------------------------------------------------
# CATEGORY FILTER
#-----------------------------------------------------------------------------

## Build the category list. Each match closure takes an ItemInstanceData (or
## null) and returns whether it belongs to the category.
func _build_categories() -> void:
	_categories = [
		{ "label": "All", "match": func(_d: ItemInstanceData) -> bool: return true },
		{ "label": "Weapons", "match": func(d: ItemInstanceData) -> bool: return _item_in_slots(d, [EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, EquipmentDefinitionData.EquipmentSlot.OFF_HAND]) },
		{ "label": "Armor", "match": func(d: ItemInstanceData) -> bool: return _item_in_slots(d, [EquipmentDefinitionData.EquipmentSlot.HEAD, EquipmentDefinitionData.EquipmentSlot.ARMOR]) },
		{ "label": "Accessories", "match": func(d: ItemInstanceData) -> bool: return _item_in_slots(d, [EquipmentDefinitionData.EquipmentSlot.ACCESSORY]) },
	]

## True when `data` is equipment whose slot_type is in `slot_types`.
func _item_in_slots(data: ItemInstanceData, slot_types: Array) -> bool:
	if data == null:
		return false
	var def := data.item_definition
	return def is EquipmentDefinitionData and (def as EquipmentDefinitionData).slot_type in slot_types

## Apply the selected category as a visual dim filter on the grid.
func _on_filter_changed(index: int) -> void:
	if index >= 0 and index < _categories.size():
		equipment_grid.set_category_filter(_categories[index]["match"])

## True when the drop target is the same inventory location the drag started
## from (so the drag cancels instead of moving). Grid origins compare by global
## index, which stays correct even if the player flipped pages mid-drag.
func _drag_target_is_origin(target: InventorySlot) -> bool:
	if original_slot is GearSlot:
		return target == original_slot
	if target is GearSlot:
		return false
	return _grid_global_index(target) == original_grid_index

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
		# Remember the source page's global index now (gear origins use -1).
		original_grid_index = -1 if slot is GearSlot else _grid_global_index(slot)
		if dragged_item.item_instance_data:
			item_description_box.setup(dragged_item.item_instance_data)
		add_child(dragged_item)
		dragged_item.set_anchors_preset(Control.PRESET_TOP_LEFT)
		dragged_item.custom_minimum_size = Vector2(28, 28)
		dragged_item.size = Vector2(28, 28)
		dragged_item.global_position = global_mouse_pos + POSITION_OFFSET
		dragged_item.scale = Vector2(1.0, 1.0)
		dragged_item.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _drop_item(global_mouse_pos: Vector2) -> void:
	var target_slot = _get_slot_under_mouse(global_mouse_pos)
	dragged_item.scale = Vector2(1.0, 1.0)

	# Trash drop short-circuits everything else.
	if target_slot is TrashSlot:
		_handle_trash_drop(target_slot as TrashSlot)
		_cleanup_drag()
		return

	# Restoring from trash back into inventory.
	if original_slot is TrashSlot:
		if target_slot == null:
			_return_to_original()
			_cleanup_drag()
			return
		var inst: ItemInstanceData = dragged_item.item_instance_data
		if target_slot is GearSlot:
			var gear: GearSlot = target_slot as GearSlot
			if not gear.is_valid_item(inst):
				_return_to_original()
				_cleanup_drag()
				return
			InventoryManager.equip_item(inst, gear.slot_type, -1, gear.accessory_index)
		else:
			InventoryManager.restore_equipment_instance(inst, _grid_global_index(target_slot))
		dragged_item.queue_free()
		_cleanup_drag()
		return

	if target_slot and not _drag_target_is_origin(target_slot):
		var item_data = dragged_item.item_instance_data

		if target_slot is GearSlot:
			if not target_slot.is_valid_item(item_data):
				_return_to_original()
				_cleanup_drag()
				return

		if target_slot is GearSlot:
			# Dropping ONTO a gear slot (Equipping)
			if not (original_slot is GearSlot):
				var from_index = original_grid_index
				InventoryManager.equip_item(item_data, target_slot.slot_type, from_index, target_slot.accessory_index)
				dragged_item.queue_free()
			else:
				InventoryManager.swap_accessory_slots(original_slot.accessory_index, target_slot.accessory_index)
				dragged_item.queue_free()

		elif original_slot is GearSlot:
			# Dropping FROM GearSlot TO Grid (Unequipping to a specific slot). If
			# the target holds an item that can't go into this gear slot, the swap
			# is rejected — return the dragged item to its slot rather than lose it.
			var target_index = _grid_global_index(target_slot)
			if InventoryManager.unequip_item_to_slot(original_slot.slot_type, target_index, original_slot.accessory_index):
				dragged_item.queue_free()
			else:
				_return_to_original()
		else:
			# Grid -> Grid (Reordering)
			var from_index = original_grid_index
			var to_index = _grid_global_index(target_slot)
			InventoryManager.move_equipment(from_index, to_index)
			dragged_item.queue_free()
	else:
		_return_to_original()

	_cleanup_drag()

#-----------------------------------------------------------------------------
# QUICK EQUIP (Right-Click)
#-----------------------------------------------------------------------------

func _quick_equip(slot: InventorySlot) -> void:
	var item_data: ItemInstanceData = slot.item_instance.item_instance_data
	if not item_data.item_definition is EquipmentDefinitionData:
		return

	if slot is GearSlot:
		InventoryManager.unequip_item(slot.slot_type, slot.accessory_index)
	else:
		var equip_def: EquipmentDefinitionData = item_data.item_definition as EquipmentDefinitionData
		var from_index: int = _grid_global_index(slot)
		var accessory_index: int = -1
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
	if original_slot is TrashSlot:
		var trash := original_slot as TrashSlot
		var data: ItemInstanceData = dragged_item.item_instance_data
		trash.accept(data)
		dragged_item.queue_free()
		return
	if original_slot is GearSlot:
		original_slot.equip_item(dragged_item)
		return
	# Grid origin: the item was never removed from inventory.equipment, so drop
	# the floating visual and re-render the current page. Correct even if the
	# player flipped pages mid-drag — the item stays at its original global index
	# and reappears when they flip back.
	dragged_item.queue_free()
	equipment_grid.set_page(equipment_grid.current_page)

func _cleanup_drag() -> void:
	if dragged_item:
		dragged_item.z_index = 0
		dragged_item.mouse_filter = Control.MOUSE_FILTER_PASS
	dragged_item = null
	original_slot = null
	original_grid_index = -1
	is_dragging = false

func _get_slot_under_mouse(global_pos: Vector2) -> InventorySlot:
	for slot in equipment_grid.get_slots():
		if slot.get_global_rect().has_point(global_pos):
			return slot
	for slot in gear_selector.get_slots():
		if slot.get_global_rect().has_point(global_pos):
			return slot
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
	trash.accept(data)
	_remove_dragged_from_inventory_state()
	dragged_item.queue_free()

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
		inventory.equipment.erase(original_grid_index)
	InventoryManager.inventory_changed.emit(inventory)

func _pick_up_from_trash(trash: TrashSlot, global_mouse_pos: Vector2) -> void:
	var held = trash.get_held()
	if held == null:
		return
	if held is ItemInstanceData:
		var visual: Control = trash.grab_item()
		trash.clear_hold()
		if visual == null:
			return
		dragged_item = visual
		is_dragging = true
		original_slot = trash
		add_child(dragged_item)
		dragged_item.set_anchors_preset(Control.PRESET_TOP_LEFT)
		dragged_item.custom_minimum_size = Vector2(28, 28)
		dragged_item.size = Vector2(28, 28)
		dragged_item.global_position = global_mouse_pos + POSITION_OFFSET
		dragged_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if item_description_box:
			item_description_box.setup(held)
