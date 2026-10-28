class_name EquipmentDetails
extends PanelContainer

## EquipmentDetails
## The Gear page's details panel, pressed into the paper under the figure: the
## item the player last pointed at, in a deep slot beside its name and slot
## caption, its bonuses two to a row as the tooltip words them ("+2 Strength"),
## and its description. The panel has a fixed height laid out for the longest
## real item, the Dreadbeast Tooth Necklace (spec: its name's baselines at
## screen 654 and 688, the slot caption 26 px under the name's last line, the
## first bonus row's baseline at 752, the description from 798). Shorter items
## flow up from the same gaps. It prints no hint (2026-10-28 review).
##
## %Flow lays out the name, bonuses and description from the top of the
## panel's content. The header, the bonus rows and the gaps before them are all
## even heights, so every pressed rule lands on an even pixel.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const _BONUS_ROW_SCENE: PackedScene = preload("res://scenes/inventory/inventory_view/equipment_tab/equipment_details/bonus_row.tscn")

## Bonuses printed side by side on one BonusRow.
const _BONUSES_PER_ROW: int = 2

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _slot_label: Label = %SlotLabel
@onready var _bonuses_block: MarginContainer = %BonusesBlock
@onready var _bonuses: VBoxContainer = %Bonuses
@onready var _description: Label = %Description

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _item: ItemInstanceData = null

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Shows `data` and makes the panel visible. Showing the item already shown
## reprints nothing. A null `data` clears the panel.
func show_item(data: ItemInstanceData) -> void:
	if data == null or data.item_definition == null:
		clear()
		return
	if data != _item:
		_item = data
		_print_item(data.item_definition)
	visible = true

## Empties the panel and hides it.
func clear() -> void:
	_item = null
	visible = false

## Returns the item the panel shows, or null while it is cleared.
func get_item() -> ItemInstanceData:
	return _item

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## Prints the item: its icon, name, slot caption, bonuses and description.
func _print_item(def: ItemDefinitionData) -> void:
	var bonuses: Array[String] = []
	_slot_label.text = ""
	if def is EquipmentDefinitionData:
		var equipment: EquipmentDefinitionData = def as EquipmentDefinitionData
		_slot_label.text = BookText.slot_name(equipment.slot_type)
		bonuses = BookText.bonus_lines(equipment)
	_icon.texture = def.icon
	_name_label.text = def.item_name
	_set_bonuses(bonuses)
	_description.text = def.description

## Replaces the bonus rows: two bonuses to a row, the last one alone when the
## count is odd. Hides the rows and the gap over them when the item has no
## bonus.
func _set_bonuses(bonuses: Array[String]) -> void:
	for row: Node in _bonuses.get_children():
		_bonuses.remove_child(row)
		row.queue_free()
	for first: int in range(0, bonuses.size(), _BONUSES_PER_ROW):
		var row: BonusRow = _BONUS_ROW_SCENE.instantiate() as BonusRow
		_bonuses.add_child(row)
		var right: String = bonuses[first + 1] if first + 1 < bonuses.size() else ""
		row.setup(bonuses[first], right)
	_bonuses_block.visible = not bonuses.is_empty()
