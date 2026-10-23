class_name AbilityEquipSlot
extends DropTargetSlot

## A single loadout slot in the Abilities book.
## Accepts drag-and-drop from AbilityRow to equip abilities, and is itself a
## drag source so an equipped ability can be reordered between slots. The
## drop-target hover + routing is inherited from DropTargetSlot.

signal ability_dropped(ability_id: String, slot_index: int, from_slot: int)

var _ability_data: AbilityData = null
var _slot_index: int = 0

const KEY_LABELS: PackedStringArray = ["Q", "W", "E", "R"]
const DragPreviewScene: PackedScene = preload("res://scenes/abilities/ability_row/ability_drag_preview.tscn")

@onready var _icon: TextureRect = %SlotIcon
@onready var _empty_label: Label = %EmptyLabel
@onready var _key_hint_label: Label = %KeyHintLabel

# ----- Public API -----

## Configures this slot with its index in the loadout.
func setup(index: int) -> void:
	_slot_index = index
	_set_key_hint()

## Sets the ability displayed in this slot.
func set_ability(ability_data: AbilityData) -> void:
	_ability_data = ability_data
	_update_display()

## Clears the slot.
func clear_slot() -> void:
	_ability_data = null
	_update_display()

# ----- Drag source -----

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _ability_data:
		return null
	var preview: AbilityDragPreview = DragPreviewScene.instantiate() as AbilityDragPreview
	preview.setup(_ability_data.icon)
	set_drag_preview(preview)
	return {"ability_id": _ability_data.ability_id, "from_slot": _slot_index}

# ----- Drop target (hover + routing inherited from DropTargetSlot) -----

func _accepts(data: Variant) -> bool:
	return data is Dictionary and data.has("ability_id")

func _on_dropped(data: Variant) -> void:
	ability_dropped.emit(data["ability_id"], _slot_index, data.get("from_slot", -1))

# ----- Private -----

func _update_display() -> void:
	if _ability_data:
		_icon.texture = _ability_data.icon
		_icon.visible = true
		_empty_label.visible = false
	else:
		_icon.texture = null
		_icon.visible = false
		_empty_label.visible = true

func _set_key_hint() -> void:
	if _slot_index < 0 or _slot_index >= KEY_LABELS.size():
		_key_hint_label.get_parent().visible = false
		return

	_key_hint_label.text = KEY_LABELS[_slot_index]
	_key_hint_label.get_parent().visible = true
