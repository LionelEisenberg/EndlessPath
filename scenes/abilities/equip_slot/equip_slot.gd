class_name AbilityEquipSlot
extends PanelContainer

## A single loadout slot in the AbilitiesView sidebar.
## Accepts drag-and-drop from AbilityCard to equip abilities.
## Supports dragging out of occupied slots and reordering between slots.

signal ability_dropped(ability_id: String, slot_index: int)
signal slot_cleared(slot_index: int)

var _ability_data: AbilityData = null
var _slot_index: int = 0
var _is_hover: bool = false

@onready var _icon: TextureRect = %SlotIcon
@onready var _empty_label: Label = %EmptyLabel

# ----- Public API -----

## Configures this slot with its index in the loadout.
func setup(index: int) -> void:
	_slot_index = index

## Sets the ability displayed in this slot.
func set_ability(ability_data: AbilityData) -> void:
	_ability_data = ability_data
	_update_display()

## Clears the slot.
func clear_slot() -> void:
	_ability_data = null
	_update_display()

## Returns the ability in this slot, or null if empty.
func get_ability() -> AbilityData:
	return _ability_data

# ----- Drag and Drop -----

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _ability_data:
		return null
	# Build visual drag preview with the ability icon
	var preview: TextureRect = TextureRect.new()
	preview.custom_minimum_size = Vector2(48, 48)
	preview.size = Vector2(48, 48)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = _ability_data.icon
	preview.modulate = Color(1.0, 1.0, 1.0, 0.85)
	set_drag_preview(preview)
	return {"ability_id": _ability_data.ability_id, "from_slot": _slot_index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("ability_id"):
		_set_hover(true)
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_hover(false)
	if data is Dictionary and data.has("ability_id"):
		ability_dropped.emit(data["ability_id"], _slot_index)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_hover(false)

# ----- Private -----

func _update_display() -> void:
	if _ability_data:
		_icon.texture = _ability_data.icon
		_icon.visible = true
		_empty_label.visible = false
		_icon.modulate = Color.WHITE
	else:
		_icon.texture = null
		_icon.visible = false
		_empty_label.visible = true

func _set_hover(hovering: bool) -> void:
	_is_hover = hovering
	if _is_hover:
		modulate = Color(1.2, 1.15, 1.0, 1.0)
	else:
		modulate = Color.WHITE
