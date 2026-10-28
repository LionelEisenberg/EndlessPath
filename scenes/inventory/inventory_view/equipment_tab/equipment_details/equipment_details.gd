class_name EquipmentDetails
extends PanelContainer

## EquipmentDetails
## The Gear page's details panel, pressed into the paper under the figure: the
## item the player last pointed at, in a deep slot beside its name and slot
## caption, its bonuses two to a row, its description, and a hint at the
## panel's foot. The panel has a fixed height laid out for the longest real
## item, so the hint is the first thing to give way when an item needs the
## room (wants_hint()).

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const _BONUS_ROW_SCENE: PackedScene = preload("res://scenes/inventory/inventory_view/equipment_tab/equipment_details/bonus_row.tscn")

## Bonuses printed side by side on one BonusRow.
const _BONUSES_PER_ROW: int = 2

const _HINT_WEAR: String = "Right-click to wear it"
const _HINT_TAKE_OFF: String = "Right-click to take it off"

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _slot_label: Label = %SlotLabel
@onready var _bonuses: VBoxContainer = %Bonuses
@onready var _description: Label = %Description
@onready var _hint: Label = %Hint

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _item: ItemInstanceData = null

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Shows `data` and makes the panel visible. `worn` picks the hint: wear it
## from the bag, or take it off a gear slot. Showing the item already shown
## only refreshes the hint. A null `data` clears the panel.
func show_item(data: ItemInstanceData, worn: bool) -> void:
	if data == null or data.item_definition == null:
		clear()
		return
	if data != _item:
		_item = data
		_print_item(data.item_definition)
	_hint.text = _HINT_TAKE_OFF if worn else _HINT_WEAR
	visible = true

## Empties the panel and hides it.
func clear() -> void:
	_item = null
	visible = false

## Returns the item the panel shows, or null while it is cleared.
func get_item() -> ItemInstanceData:
	return _item

## True while an item leaves the panel room for its hint: a name of at most two
## lines, at most four bonuses (two rows) and a description of at most two
## lines. The hint is the first thing to give way.
static func wants_hint(name_lines: int, bonus_count: int, description_lines: int) -> bool:
	return name_lines <= 2 and bonus_count <= 4 and description_lines <= 2

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## Prints the item: its icon, name, slot caption, bonuses and description, and
## keeps the hint only while the item leaves room for it.
func _print_item(def: ItemDefinitionData) -> void:
	var pairs: Array[PackedStringArray] = []
	_slot_label.text = ""
	if def is EquipmentDefinitionData:
		var equipment: EquipmentDefinitionData = def as EquipmentDefinitionData
		_slot_label.text = BookText.slot_name(equipment.slot_type)
		pairs = BookText.bonus_pairs(equipment)
	_icon.texture = def.icon
	_name_label.text = def.item_name
	_set_bonuses(pairs)
	_description.text = def.description
	# Both labels wrap at their minimum width, so the counts hold before layout.
	_hint.visible = wants_hint(_name_label.get_line_count(), pairs.size(), _description.get_line_count())

## Replaces the bonus rows: two bonuses to a row, the last one alone when the
## count is odd. Hides the rows' box when the item has no bonus.
func _set_bonuses(pairs: Array[PackedStringArray]) -> void:
	for row: Node in _bonuses.get_children():
		_bonuses.remove_child(row)
		row.queue_free()
	for first: int in range(0, pairs.size(), _BONUSES_PER_ROW):
		var row: BonusRow = _BONUS_ROW_SCENE.instantiate() as BonusRow
		_bonuses.add_child(row)
		var right: PackedStringArray = pairs[first + 1] if first + 1 < pairs.size() else PackedStringArray()
		row.setup(pairs[first], right)
	_bonuses.visible = not pairs.is_empty()
