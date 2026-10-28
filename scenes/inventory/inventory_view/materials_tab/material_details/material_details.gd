class_name MaterialDetails
extends PanelContainer

## MaterialDetails
## The Materials page's details panel, pressed into the paper under the
## material's name (the right page's title): the material in a deep slot
## beside "MATERIAL" and how many the player has ("You have 4,600"), its
## description, and a table of where it is gathered, three TableRows per
## source (GATHERED BY, IN, YIELD), left out when there is none. The sources
## come from MaterialSources each time a material is printed. The panel grows
## downward with its text.
##
## Laid out to the mockup's Spirit Fern, which fills the spec's (1008, 300) to
## (1476, 646). Down the panel's content, "MATERIAL"'s baseline sits at 34,
## the amount's at 66, the description's from 120 and the table's from 240,
## 30 px apart, with 2 px under the last rule. The description keeps room for
## four lines, so the table holds still as the player points from one
## material to the next; a longer description pushes it down.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const _TABLE_ROW_SCENE: PackedScene = preload("res://scenes/inventory/pressed/table_row/table_row.tscn")

## How many the player has, the number grouped by commas.
const _AMOUNT: String = "You have %s"
## The table's captions, one row each per source.
const _GATHERED_BY: String = "GATHERED BY"
const _IN: String = "IN"
const _YIELD: String = "YIELD"

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _icon: TextureRect = %Icon
@onready var _amount_label: Label = %AmountLabel
@onready var _description: Label = %Description
@onready var _sources_block: MarginContainer = %SourcesBlock
@onready var _sources: VBoxContainer = %Sources

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _def: MaterialDefinitionData = null

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Shows `def` with `amount`, how many the player has, and makes the panel
## visible. Showing the material already shown only reprints the amount. A
## null `def` clears the panel.
func show_material(def: MaterialDefinitionData, amount: int) -> void:
	if def == null:
		clear()
		return
	if def != _def:
		_def = def
		_print(def)
	_amount_label.text = _AMOUNT % BookText.thousands(amount)
	visible = true

## Empties the panel and hides it.
func clear() -> void:
	_def = null
	visible = false

## Returns the material the panel shows, or null while it is cleared.
func get_shown_material() -> MaterialDefinitionData:
	return _def

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## Prints the material: its icon, its description and where it is gathered.
func _print(def: MaterialDefinitionData) -> void:
	_icon.texture = def.icon
	_description.text = def.description
	_set_sources(MaterialSources.find(def))

## Replaces the table: for each source, the activity, its zone and its yield
## ("2–6 every 5 s"). Hides the table and the gap over it when there is none.
func _set_sources(sources: Array[MaterialSources.Source]) -> void:
	for row: Node in _sources.get_children():
		_sources.remove_child(row)
		row.queue_free()
	for source: MaterialSources.Source in sources:
		_add_row(_GATHERED_BY, source.activity_name)
		_add_row(_IN, source.zone_name)
		_add_row(_YIELD, BookText.yield_text(source.min_quantity, source.max_quantity, source.interval_seconds))
	_sources_block.visible = not sources.is_empty()

## Adds one row to the table. The value is plain text, so its brackets are
## escaped and a decimal point ("every 2.5 s") is set in Yatra One.
func _add_row(label: String, value: String) -> void:
	var row: TableRow = _TABLE_ROW_SCENE.instantiate() as TableRow
	_sources.add_child(row)
	row.setup(label, LacquerText.decimal_bbcode(value))
