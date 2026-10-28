class_name EquipmentDetails
extends PanelContainer

## EquipmentDetails
## The Gear page's details panel, pressed into the paper under the figure: the
## item the player last pointed at, in a deep slot beside its name and slot
## caption, its bonuses two to a row, its description, and a hint at the
## panel's foot. The panel has a fixed height laid out for the longest real
## item, the Dreadbeast Tooth Necklace (spec: its name's baselines at screen
## 654 and 688, the slot caption 26 px under the name's last line, the first
## bonus row's baseline at 752, the description from 798, the hint at 866).
## Shorter items flow up from the same gaps. The hint is the first thing to
## give way when an item needs the room (wants_hint()).
##
## %Flow lays out the name, bonuses and description from the top of the
## panel's content; %Hint is pinned to its foot, its line reaching into the
## panel's bottom padding. The header, the bonus rows and the gaps before them
## are all even heights, so every pressed rule lands on an even pixel.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const _BONUS_ROW_SCENE: PackedScene = preload("res://scenes/inventory/inventory_view/equipment_tab/equipment_details/bonus_row.tscn")

## Bonuses printed side by side on one BonusRow.
const _BONUSES_PER_ROW: int = 2

const _HINT_WEAR: String = "Right-click to wear it"
const _HINT_TAKE_OFF: String = "Right-click to take it off"

#-----------------------------------------------------------------------------
# LAYOUT
# The panel's vertical rhythm in px, down from the top of its content (screen
# y 622). They restate the scene's sizes and the book theme's line metrics, so
# wants_hint() can tell from line counts alone where an item's text ends;
# test_equipment_page.gd checks them against the laid-out panel.
#-----------------------------------------------------------------------------

## The icon's deep slot: the header is never shorter.
const _ICON_WELL_HEIGHT: int = 72
## The name column holding one line of name: %NameInset (2), the name's line
## (Yatra One 30 is 45 tall) and %SlotLabel (17, which keeps the column even).
const _ONE_LINE_NAME_COLUMN: int = 2 + 45 + 17
## Each further line of the name: LabelBookItemName's pitch.
const _NAME_LINE_PITCH: int = 34
## %BonusesBlock's top margin, the gap over the first bonus row.
const _BONUS_GAP: int = 16
## One BonusRow: its 22 px text row and the 4 px pressed rule.
const _BONUS_ROW_HEIGHT: int = 26
## %Bonuses' separation, between two bonus rows.
const _BONUS_ROW_GAP: int = 8
## The description's top margin (21) and first line (BM Euljiro 18 is 21 tall).
const _ONE_LINE_DESCRIPTION: int = 21 + 21
## Each further line of the description: LabelBookInk's pitch.
const _DESCRIPTION_LINE_PITCH: int = 26
## Where the hint's line starts, 8 px above the content's foot: its baseline
## then sits at screen 866.
const _HINT_LINE_TOP: int = 232
## The clear space the spec keeps between the necklace's description (its last
## line ends at screen 830) and the hint's line (854).
const _HINT_CLEARANCE: int = 24

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _slot_label: Label = %SlotLabel
@onready var _bonuses_block: MarginContainer = %BonusesBlock
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

## True while an item's text ends clear of the hint's line: at least the
## 24 px the spec keeps under the longest real item's description. Its text
## reaches as far down as the panel's rhythm puts it for `name_lines` of
## name, `bonus_count` bonuses (two to a row) and `description_lines` of
## description. The hint is the first thing to give way.
static func wants_hint(name_lines: int, bonus_count: int, description_lines: int) -> bool:
	return _text_height(name_lines, bonus_count, description_lines) <= _HINT_LINE_TOP - _HINT_CLEARANCE

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## How far down from the content's top an item's text reaches: the header (the
## icon's slot, or the name column when it is taller), the bonus rows with the
## gap over them, then the description with the gap over it. A count of 0
## lines takes the room of one, as an empty Label does.
static func _text_height(name_lines: int, bonus_count: int, description_lines: int) -> int:
	var name_column: int = _ONE_LINE_NAME_COLUMN + _NAME_LINE_PITCH * maxi(name_lines - 1, 0)
	var header: int = maxi(_ICON_WELL_HEIGHT, name_column)
	var rows: int = ceili(bonus_count / float(_BONUSES_PER_ROW))
	var bonuses: int = 0
	if rows > 0:
		bonuses = _BONUS_GAP + rows * _BONUS_ROW_HEIGHT + (rows - 1) * _BONUS_ROW_GAP
	var description: int = _ONE_LINE_DESCRIPTION + _DESCRIPTION_LINE_PITCH * maxi(description_lines - 1, 0)
	return header + bonuses + description

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
## count is odd. Hides the rows and the gap over them when the item has no
## bonus.
func _set_bonuses(pairs: Array[PackedStringArray]) -> void:
	for row: Node in _bonuses.get_children():
		_bonuses.remove_child(row)
		row.queue_free()
	for first: int in range(0, pairs.size(), _BONUSES_PER_ROW):
		var row: BonusRow = _BONUS_ROW_SCENE.instantiate() as BonusRow
		_bonuses.add_child(row)
		var right: PackedStringArray = pairs[first + 1] if first + 1 < pairs.size() else PackedStringArray()
		row.setup(pairs[first], right)
	_bonuses_block.visible = not pairs.is_empty()
