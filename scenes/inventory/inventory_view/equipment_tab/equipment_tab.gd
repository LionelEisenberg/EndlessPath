extends Control

## EquipmentTab
## The Equipment tab, pressed into the book's two pages at 1x. Left page: the
## filter words, a 6x6 page of the bag, and the footer (PaginationBar: page
## slots, the count, the discard slot). Right page: the gear figure
## (GearSelector) and the details panel (EquipmentDetails), which shows the
## item last pointed at and keeps to it while the bag changes. Printer's marks
## sit round the slot the details show and, while dragging, round the slot a
## drop would fill (never one that would refuse the item, never the slot it
## came from). Handles drag/drop between grid slots (paged → global index),
## gear slots, and the trash slot (hold-buffer).

@onready var equipment_grid: EquipmentGrid = %EquipmentGrid
@onready var gear_selector: Control = %GearSelector
@onready var details: EquipmentDetails = %EquipmentDetails
@onready var filter_words: FilterWords = %FilterWords
@onready var pagination_bar: PaginationBar = %PaginationBar
@onready var trash_slot : TrashSlot = pagination_bar.trash_slot

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Centres the 72 px dragged item on the cursor.
const POSITION_OFFSET = Vector2(-36, -36)
## The dragged item's size: a full slot.
const DRAGGED_ITEM_SIZE := Vector2(72, 72)
## Draws the dragged item over the pages.
const DRAGGED_ITEM_Z_INDEX := 10

## What a drop does with the dragged item. _drop_item() acts on it and the
## drag-target marks read it, so a slot is marked only where a drop would land.
enum DropAction {
	## Refused, or onto the slot it came from: the item goes back.
	RETURN,
	## Into the discard slot's hold.
	DISCARD,
	## Onto a gear slot of its type, from the bag or out of the discard slot.
	EQUIP,
	## From one accessory slot to the other.
	SWAP_ACCESSORIES,
	## From a gear slot into a grid slot, swapping with an item that fits.
	UNEQUIP,
	## From one grid slot to another, swapping with what is there.
	MOVE,
	## Out of the discard slot back into the bag.
	RESTORE,
}

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
## Category filters for the filter words: each entry is { label: String,
## match: Callable } where match(ItemInstanceData) -> bool decides which items
## stay in. Built in _ready.
var _categories: Array = []
## The slot holding the item the details show, marked; null when none is.
var _shown_slot: InventorySlot = null
## The slot a drop would land in while dragging, marked; null when none is.
var _drag_target: InventorySlot = null

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

	_build_categories()
	var labels := PackedStringArray()
	for cat in _categories:
		labels.append(cat["label"])
	filter_words.set_options(labels)
	filter_words.option_changed.connect(_on_filter_changed)

	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_refresh_pagination()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Opens the page on its first item: the first one on the grid page shown,
## else the first worn piece in the figure's order (Head, Main hand,
## Accessory 1, Body, Off hand, Accessory 2). With neither, the details hide.
## Called whenever the page is opened.
func open_page() -> void:
	_refresh_pagination()
	for slot in equipment_grid.get_slots():
		if slot.item_instance != null:
			_show_slot(slot)
			return
	for slot in gear_selector.get_slots():
		if slot.item_instance != null:
			_show_slot(slot)
			return
	_mark_shown(null)
	details.clear()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_inventory_changed(_inventory: InventoryData) -> void:
	_refresh_pagination()
	_follow_shown_item.call_deferred()

func _refresh_pagination() -> void:
	var inventory := InventoryManager.get_inventory()
	pagination_bar.setup(inventory.unlocked_equipment_pages, equipment_grid.current_page)
	pagination_bar.set_count(inventory.equipment.size(), inventory.equipment_capacity())

func _on_page_selected(index: int) -> void:
	equipment_grid.set_page(index)
	pagination_bar.set_active_page(equipment_grid.current_page)
	# Deferred: following can open the page, whose PaginationBar.setup() frees
	# the page button still emitting this signal.
	_follow_shown_item.call_deferred()

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
## null) and returns whether it belongs to the category. The labels are
## printed as they are, in capitals.
func _build_categories() -> void:
	_categories = [
		{ "label": "ALL", "match": func(_d: ItemInstanceData) -> bool: return true },
		{ "label": "WEAPONS", "match": func(d: ItemInstanceData) -> bool: return _item_in_slots(d, [EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, EquipmentDefinitionData.EquipmentSlot.OFF_HAND]) },
		{ "label": "ARMOR", "match": func(d: ItemInstanceData) -> bool: return _item_in_slots(d, [EquipmentDefinitionData.EquipmentSlot.HEAD, EquipmentDefinitionData.EquipmentSlot.ARMOR]) },
		{ "label": "ACCESSORIES", "match": func(d: ItemInstanceData) -> bool: return _item_in_slots(d, [EquipmentDefinitionData.EquipmentSlot.ACCESSORY]) },
	]

## True when `data` is equipment whose slot_type is in `slot_types`.
func _item_in_slots(data: ItemInstanceData, slot_types: Array) -> bool:
	if data == null:
		return false
	var def := data.item_definition
	return def is EquipmentDefinitionData and (def as EquipmentDefinitionData).slot_type in slot_types

## Apply the selected category to the grid: items outside it fade into the paper.
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
# THE SHOWN ITEM
#-----------------------------------------------------------------------------

## Shows the item in `slot` in the details and marks the slot. Pointing again
## at the slot already shown changes nothing.
func _show_slot(slot: InventorySlot) -> void:
	var data: ItemInstanceData = slot.item_instance.item_instance_data
	if slot == _shown_slot and data == details.get_item():
		return
	_mark_shown(slot)
	details.show_item(data, _hint_mode(slot))

## The details' hint for the item in `slot`: take it off a gear slot, drag it
## back out of the discard slot, else wear it.
func _hint_mode(slot: InventorySlot) -> EquipmentDetails.HintMode:
	if slot is GearSlot:
		return EquipmentDetails.HintMode.WORN
	if slot is TrashSlot:
		return EquipmentDetails.HintMode.DISCARD
	return EquipmentDetails.HintMode.BAG

## Marks `slot` as the one the details show and unmarks the last one. Null
## leaves no slot marked.
func _mark_shown(slot: InventorySlot) -> void:
	if _shown_slot != null and _shown_slot != slot:
		_shown_slot.set_marked(false)
	_shown_slot = slot
	if slot != null:
		slot.set_marked(true)

## Follows whatever the details show by the time the call runs.
func _follow_shown_item() -> void:
	_follow_item(details.get_item())

## Keeps the details and the marks on `item` after the bag changed: marks the
## visible grid or gear slot holding it (none when it is on another page) and
## refreshes its hint. The discard slot's item, when it was the last thing
## pointed at, keeps its details and marks as they are. Any other item no
## longer in the bag or worn opens the page on its first item instead. Waits
## while a drag is under way: the drop follows the item again.
func _follow_item(item: ItemInstanceData) -> void:
	if is_dragging:
		return
	if item == null:
		open_page()
		return
	# Keyed on the marks, not on what the discard slot holds: right after a
	# discard drop nothing is marked, so the details move on.
	if _shown_slot is TrashSlot and (_shown_slot as TrashSlot).get_held() == item:
		return
	var inventory := InventoryManager.get_inventory()
	var worn: bool = item in inventory.equipped_gear.values() or item in inventory.equipped_accessories.values()
	if not worn and item not in inventory.equipment.values():
		open_page()
		return
	_mark_shown(_visible_slot_holding(item))
	details.show_item(item, EquipmentDetails.HintMode.WORN if worn else EquipmentDetails.HintMode.BAG)

## The visible grid or gear slot that holds `item`, or null.
func _visible_slot_holding(item: ItemInstanceData) -> InventorySlot:
	for slot in equipment_grid.get_slots():
		if slot.item_instance != null and slot.item_instance.item_instance_data == item:
			return slot
	for slot in gear_selector.get_slots():
		if slot.item_instance != null and slot.item_instance.item_instance_data == item:
			return slot
	return null

#-----------------------------------------------------------------------------
# INPUT HANDLING
#-----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if is_dragging and dragged_item:
		if event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			dragged_item.global_position = motion.global_position + POSITION_OFFSET
			_mark_drag_target(_landing_slot(_get_slot_under_mouse(motion.global_position)))
		elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_drop_item(get_global_mouse_position())

#-----------------------------------------------------------------------------
# DRAG AND DROP
#-----------------------------------------------------------------------------

func _on_slot_input(slot: InventorySlot, event: InputEvent) -> void:
	var pointed: bool = event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed)
	if pointed and not is_dragging and slot.item_instance != null:
		_show_slot(slot)

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

func _pick_up_item(slot: InventorySlot, global_mouse_pos: Vector2) -> void:
	var item = slot.grab_item()
	if item:
		dragged_item = item
		is_dragging = true
		original_slot = slot
		# Remember the source page's global index now (gear origins use -1).
		original_grid_index = -1 if slot is GearSlot else _grid_global_index(slot)
		# The item is in hand now, so its emptied slot loses the marks.
		_mark_shown(null)
		_hold_dragged_item(global_mouse_pos)

## Re-parents the dragged item to the tab as a full slot drawn over the pages,
## centred on the cursor.
func _hold_dragged_item(global_mouse_pos: Vector2) -> void:
	add_child(dragged_item)
	dragged_item.set_anchors_preset(Control.PRESET_TOP_LEFT)
	dragged_item.custom_minimum_size = DRAGGED_ITEM_SIZE
	dragged_item.size = DRAGGED_ITEM_SIZE
	dragged_item.z_index = DRAGGED_ITEM_Z_INDEX
	dragged_item.global_position = global_mouse_pos + POSITION_OFFSET
	dragged_item.scale = Vector2(1.0, 1.0)
	dragged_item.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Marks `slot`, the one a drop would fill, and unmarks the last target. Null
## leaves no target marked.
func _mark_drag_target(slot: InventorySlot) -> void:
	if slot == _drag_target:
		return
	if _drag_target != null:
		_drag_target.set_marked(false)
	_drag_target = slot
	if slot != null:
		slot.set_marked(true)

## What a drop on `target` would do with the dragged item. Null, the slot it
## came from, a gear slot of another type, or a grid slot a worn item can't go
## into, sends it back.
func _drop_action(target: InventorySlot) -> DropAction:
	if target == null:
		return DropAction.RETURN
	if target is TrashSlot:
		# Back into the discard slot it came out of is going back, not a discard.
		return DropAction.RETURN if original_slot is TrashSlot else DropAction.DISCARD
	if _drag_target_is_origin(target):
		return DropAction.RETURN
	if target is GearSlot:
		if not (target as GearSlot).is_valid_item(dragged_item.item_instance_data):
			return DropAction.RETURN
		return DropAction.SWAP_ACCESSORIES if original_slot is GearSlot else DropAction.EQUIP
	if original_slot is TrashSlot:
		return DropAction.RESTORE
	if original_slot is GearSlot:
		if not _worn_item_fits(original_slot as GearSlot, _grid_global_index(target)):
			return DropAction.RETURN
		return DropAction.UNEQUIP
	return DropAction.MOVE

## The slot a drop on `target` would fill, for the drag-target marks: the
## target itself, or for an item out of the discard slot, the grid slot
## InventoryManager.restore_equipment_instance() would put it in. Null when the
## drop sends the item back, or fills a slot on another page.
func _landing_slot(target: InventorySlot) -> InventorySlot:
	match _drop_action(target):
		DropAction.RETURN:
			return null
		DropAction.RESTORE:
			return _visible_grid_slot(_restore_index(_grid_global_index(target)))
	return target

## True when a worn item from `gear` can go into grid slot `index`: the slot is
## free, or its item fits `gear` and the two swap. The same check
## InventoryManager.unequip_item_to_slot() makes.
func _worn_item_fits(gear: GearSlot, index: int) -> bool:
	var equipment: Dictionary = InventoryManager.get_inventory().equipment
	if not equipment.has(index):
		return true
	var occupant: ItemDefinitionData = (equipment[index] as ItemInstanceData).item_definition
	return occupant is EquipmentDefinitionData and (occupant as EquipmentDefinitionData).slot_type == gear.slot_type

## Where InventoryManager.restore_equipment_instance() puts an item dropped on
## grid slot `index`: there when the slot is free and inside the bag, else the
## bag's first free slot; -1 when the bag is full.
func _restore_index(index: int) -> int:
	var inventory: InventoryData = InventoryManager.get_inventory()
	if index >= 0 and index < inventory.equipment_capacity() and not inventory.equipment.has(index):
		return index
	for free_index: int in inventory.equipment_capacity():
		if not inventory.equipment.has(free_index):
			return free_index
	return -1

## The grid slot showing global inventory `index` on the page shown, or null.
func _visible_grid_slot(index: int) -> InventorySlot:
	var slots: Array[InventorySlot] = equipment_grid.get_slots()
	var local: int = index - equipment_grid.current_page * equipment_grid.slots_per_page()
	if index < 0 or local < 0 or local >= slots.size():
		return null
	return slots[local]

func _drop_item(global_mouse_pos: Vector2) -> void:
	var target_slot: InventorySlot = _get_slot_under_mouse(global_mouse_pos)
	dragged_item.scale = Vector2(1.0, 1.0)
	var item_data: ItemInstanceData = dragged_item.item_instance_data
	match _drop_action(target_slot):
		DropAction.DISCARD:
			_handle_trash_drop(target_slot as TrashSlot)
		DropAction.EQUIP:
			var gear: GearSlot = target_slot as GearSlot
			# An item out of the discard slot leaves no grid slot behind.
			var from_index: int = -1 if original_slot is TrashSlot else original_grid_index
			InventoryManager.equip_item(item_data, gear.slot_type, from_index, gear.accessory_index)
			dragged_item.queue_free()
		DropAction.SWAP_ACCESSORIES:
			InventoryManager.swap_accessory_slots((original_slot as GearSlot).accessory_index, (target_slot as GearSlot).accessory_index)
			dragged_item.queue_free()
		DropAction.UNEQUIP:
			# _drop_action() checked the target fits; should the manager refuse
			# all the same, the item goes back rather than being lost.
			var worn: GearSlot = original_slot as GearSlot
			if InventoryManager.unequip_item_to_slot(worn.slot_type, _grid_global_index(target_slot), worn.accessory_index):
				dragged_item.queue_free()
			else:
				_return_to_original()
		DropAction.MOVE:
			InventoryManager.move_equipment(original_grid_index, _grid_global_index(target_slot))
			dragged_item.queue_free()
		DropAction.RESTORE:
			InventoryManager.restore_equipment_instance(item_data, _grid_global_index(target_slot))
			dragged_item.queue_free()
		DropAction.RETURN:
			_return_to_original()
	_cleanup_drag()

#-----------------------------------------------------------------------------
# QUICK EQUIP (Right-Click)
#-----------------------------------------------------------------------------

func _quick_equip(slot: InventorySlot) -> void:
	# The trash is not a grid slot: its held item is rescued only by dragging it
	# out, and the grid path below would erase whatever sits at the trash's
	# aliased grid index.
	if slot is TrashSlot:
		return
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

## Ends a drag: unmarks the drop target, then marks wherever the shown item
## landed once the slots have re-bound.
func _cleanup_drag() -> void:
	if dragged_item:
		dragged_item.z_index = 0
		dragged_item.mouse_filter = Control.MOUSE_FILTER_PASS
	dragged_item = null
	original_slot = null
	original_grid_index = -1
	is_dragging = false
	_mark_drag_target(null)
	_follow_shown_item.call_deferred()

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
		_mark_shown(null)
		_hold_dragged_item(global_mouse_pos)
