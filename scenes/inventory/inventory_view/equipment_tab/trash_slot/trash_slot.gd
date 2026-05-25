class_name TrashSlot
extends InventorySlot

## TrashSlot
## Discard target. Holds one item at a time in a transient hold-buffer.
## Dropping a new item onto a non-empty TrashSlot destroys the previously
## held item permanently. Pulling the held item out (drag back to grid)
## restores it via InventoryManager.
##
## The hold-buffer stores either:
##   - an ItemInstanceData (for equipment), or
##   - a [definition, quantity] pair for materials / consumables.

const SLOT_TEXTURE := preload("res://assets/sprites/inventory/inventory_slot/UI_NoteBook_Slot04a.png")

## When non-null, the slot is currently holding something.
## Either an ItemInstanceData OR an Array [def, quantity].
var _held: Variant = null

@onready var _x_overlay: Label = $XOverlay

func _ready() -> void:
	empty_texture = SLOT_TEXTURE
	full_texture = SLOT_TEXTURE
	super._ready()
	add_to_group("TrashSlots")
	_update_x_visibility()

## Returns true if currently holding something.
func is_holding() -> bool:
	return _held != null

## Returns the held item (or null). Caller is responsible for emptying via
## clear_hold() if they're pulling the item out.
func get_held() -> Variant:
	return _held

## Empty the hold-buffer without destroying or restoring.
## The caller decides what to do with the previously held value.
func clear_hold() -> void:
	_held = null
	_update_x_visibility()

## Place an item into the hold-buffer. If the buffer already has something,
## that prior item is permanently destroyed.
## Returns the prior item's display name (or "" if buffer was empty).
func accept(held_value: Variant) -> String:
	var discarded_name := ""
	if _held != null:
		discarded_name = _held_display_name(_held)
		_log_discard(_held)
	_held = held_value
	_update_x_visibility()
	return discarded_name

## On close-inventory, restore held content to InventoryManager.
## Called by the parent tab so the user doesn't lose work.
func flush_to_inventory() -> void:
	if _held == null:
		return
	_restore_to_inventory(_held)
	_held = null
	_update_x_visibility()

func _update_x_visibility() -> void:
	if _x_overlay:
		_x_overlay.visible = not is_holding()

func _held_display_name(value: Variant) -> String:
	if value is ItemInstanceData:
		var inst := value as ItemInstanceData
		return inst.item_definition.item_name if inst.item_definition else "(unknown)"
	if value is Array and value.size() == 2:
		var def: ItemDefinitionData = value[0]
		return def.item_name if def else "(unknown)"
	return "(unknown)"

func _log_discard(value: Variant) -> void:
	if LogManager:
		LogManager.log_message("[color=red]Discarded %s[/color]" % _held_display_name(value))

func _restore_to_inventory(value: Variant) -> void:
	if value is ItemInstanceData:
		InventoryManager.restore_equipment_instance(value as ItemInstanceData)
	elif value is Array and value.size() == 2:
		var def: ItemDefinitionData = value[0]
		var qty: int = value[1]
		if def is MaterialDefinitionData:
			InventoryManager.restore_material(def as MaterialDefinitionData, qty)
		elif def is ConsumableDefinitionData:
			InventoryManager.restore_consumable(def as ConsumableDefinitionData, qty)
