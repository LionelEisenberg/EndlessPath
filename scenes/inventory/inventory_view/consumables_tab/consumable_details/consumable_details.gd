class_name ConsumableDetails
extends PanelContainer

## ConsumableDetails
## The Hotbar page's details panel, pressed into the paper under the hotbar:
## the consumable the player last pointed at, in a deep slot beside its name
## and "CONSUMABLE" ("CONSUMABLE · IN SLOT n" while it sits on the hotbar), a
## table of what it does (one TableRow per effect, then its cooldown), its
## description and a hint. The panel grows downward with its text.
##
## Laid out to the mockup's Crude Scale, which fills the spec's (1008, 512) to
## (1476, 824). Down the panel's content, the name's baseline sits at 40, the
## caption 26 px under the name's last line, the table's baselines from 112,
## 30 px apart, the description's from 184 and the hint's at 278. The hint's
## line runs 3 px into the panel's bottom padding, as in the mockup.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const _TABLE_ROW_SCENE: PackedScene = preload("res://scenes/inventory/pressed/table_row/table_row.tscn")

## The caption under the name.
const _KIND: String = "CONSUMABLE"
## Added to the caption while the consumable sits on the hotbar.
const _IN_SLOT: String = " · IN SLOT %d"
## The cooldown row's caption.
const _COOLDOWN: String = "COOLDOWN"

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _kind_label: Label = %KindLabel
@onready var _effects_block: MarginContainer = %EffectsBlock
@onready var _effects: VBoxContainer = %Effects
@onready var _description: Label = %Description

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _def: ConsumableDefinitionData = null

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Shows `def` and makes the panel visible. `hotbar_slot` is the hotbar slot
## (0 to 3) holding it, or -1 when it is not on the hotbar. Showing the
## consumable already shown only refreshes its slot. A null `def` clears the
## panel.
func show_consumable(def: ConsumableDefinitionData, hotbar_slot: int) -> void:
	if def == null:
		clear()
		return
	if def != _def:
		_def = def
		_print(def)
	_kind_label.text = _KIND if hotbar_slot < 0 else _KIND + _IN_SLOT % (hotbar_slot + 1)
	visible = true

## Empties the panel and hides it.
func clear() -> void:
	_def = null
	visible = false

## Returns the consumable the panel shows, or null while it is cleared.
func get_consumable() -> ConsumableDefinitionData:
	return _def

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## Prints the consumable: its icon, name, table and description.
func _print(def: ConsumableDefinitionData) -> void:
	_icon.texture = def.icon
	_name_label.text = def.item_name
	_set_rows(def)
	_description.text = def.description

## Replaces the table: one row per effect, captioned with the effect's kind,
## its value what the effect does with the Madra amounts in Madra ink; then the
## cooldown, when there is one. Hides the table and the gap over it when the
## consumable has neither.
func _set_rows(def: ConsumableDefinitionData) -> void:
	for row: Node in _effects.get_children():
		_effects.remove_child(row)
		row.queue_free()
	for effect: EffectData in def.effects:
		# The colour tags go on last: decimal_bbcode() escapes every "[" it is given.
		_add_row(BookText.effect_label(effect), BookText.color_madra(LacquerText.decimal_bbcode(effect.describe())))
	if def.cooldown_seconds > 0.0:
		_add_row(_COOLDOWN, LacquerText.decimal_bbcode(BookText.seconds(def.cooldown_seconds)))
	_effects_block.visible = _effects.get_child_count() > 0

## Adds one row to the table.
func _add_row(label: String, value_bbcode: String) -> void:
	var row: TableRow = _TABLE_ROW_SCENE.instantiate() as TableRow
	_effects.add_child(row)
	row.setup(label, value_bbcode)
