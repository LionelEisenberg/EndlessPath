class_name AbilityEquipSlot
extends PanelContainer

## A single loadout slot in the AbilitiesView sidebar.
## Accepts drag-and-drop from AbilityCard to equip abilities.
## Supports dragging out of occupied slots and reordering between slots.

signal ability_dropped(ability_id: String, slot_index: int, from_slot: int)

var _ability_data: AbilityData = null
var _slot_index: int = 0
var _is_hover: bool = false

const KEY_LABELS: PackedStringArray = ["Q", "W", "E", "R"]
var _key_hint_label: Label

@onready var _icon: TextureRect = %SlotIcon
@onready var _empty_label: Label = %EmptyLabel

# ----- Public API -----

## Configures this slot with its index in the loadout.
func setup(index: int) -> void:
	_slot_index = index
	_create_key_hint()

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
	var container: Control = Control.new()
	container.z_index = 100
	container.top_level = true
	var bg: Panel = Panel.new()
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = ThemeConstants.BG_MEDIUM
	bg_style.set_border_width_all(2)
	bg_style.border_color = ThemeConstants.BORDER_PRIMARY
	bg_style.set_corner_radius_all(6)
	bg_style.set_content_margin_all(0)
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.position = Vector2(-40, -40)
	bg.size = Vector2(80, 80)
	container.add_child(bg)
	var icon: TextureRect = TextureRect.new()
	icon.texture = _ability_data.icon
	icon.position = Vector2(-32, -32)
	icon.size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = Color(1.5, 1.5, 1.5, 1.0)
	container.add_child(icon)
	set_drag_preview(container)
	return {"ability_id": _ability_data.ability_id, "from_slot": _slot_index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("ability_id"):
		_set_hover(true)
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_hover(false)
	if data is Dictionary and data.has("ability_id"):
		var from_slot: int = data.get("from_slot", -1)
		ability_dropped.emit(data["ability_id"], _slot_index, from_slot)

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

func _create_key_hint() -> void:
	if _slot_index < 0 or _slot_index >= KEY_LABELS.size():
		return
	if _key_hint_label:
		return

	_key_hint_label = Label.new()
	_key_hint_label.text = KEY_LABELS[_slot_index]
	_key_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_hint_label.add_theme_font_size_override("font_size", 11)
	_key_hint_label.add_theme_color_override("font_color", Color("#D4A84A"))
	_key_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_key_hint_label.add_theme_constant_override("outline_size", 2)

	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.85)
	bg.border_color = Color("#D4A84A")
	bg.set_border_width_all(1)
	bg.corner_radius_top_left = 3
	bg.corner_radius_bottom_right = 4
	bg.content_margin_left = 4.0
	bg.content_margin_right = 5.0
	bg.content_margin_top = 0.0
	bg.content_margin_bottom = 1.0
	_key_hint_label.add_theme_stylebox_override("normal", bg)

	_key_hint_label.z_index = 3
	add_child(_key_hint_label)
	_key_hint_label.position = Vector2(-2, -2)

func _set_hover(hovering: bool) -> void:
	_is_hover = hovering
	if _is_hover:
		modulate = Color(1.2, 1.15, 1.0, 1.0)
	else:
		modulate = Color.WHITE
