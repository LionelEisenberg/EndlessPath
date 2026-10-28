class_name MaterialDetails
extends PanelContainer

## MaterialDetails
## The Materials page's details panel, pressed into the paper under the
## material's name (the right page's title): the material in a deep slot
## beside "MATERIAL", how many the player has on a paper tag at the panel's top
## right ("×4,600", on MATERIAL's baseline), its description, and where to find
## it: "FOUND IN" and the zones it can be gathered in, one row each, left out
## when there is none. The zones come from MaterialSources each time a
## material is printed. The panel grows downward with its text.
##
## Laid out to the mockup's Spirit Fern, which starts at the spec's (1008, 300).
## Down the panel's content, "MATERIAL"'s and the tag's baselines sit at 34,
## the description's from 120, and the table's 94 px under the description's
## last baseline (240 under Spirit Fern's two lines), 30 px apart, with 2 px
## under the last rule. The description flows: a longer one pushes the table
## down and a shorter one pulls it up, always by that gap. The gap belongs to
## the table's block, so with no zone both are left out and the panel ends
## under the description.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const _TABLE_ROW_SCENE: PackedScene = preload("res://scenes/inventory/pressed/table_row/table_row.tscn")

## How many the player has, on the tag: the number grouped by commas.
const _COUNT: String = "×%s"
## The caption of the table's first row; the zones under it go uncaptioned.
const _FOUND_IN: String = "FOUND IN"

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _icon: TextureRect = %Icon
@onready var _count_tag: PaperTag = %CountTag
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
## visible. Showing the material already shown only reprints the count. A
## null `def` clears the panel.
func show_material(def: MaterialDefinitionData, amount: int) -> void:
	if def == null:
		clear()
		return
	if def != _def:
		_def = def
		_print(def)
	_count_tag.set_label(_COUNT % BookText.thousands(amount))
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

## Prints the material: its icon, its description and where to find it.
func _print(def: MaterialDefinitionData) -> void:
	_icon.texture = def.icon
	_description.text = def.description
	_set_zones(MaterialSources.zone_names(def))

## Replaces the table: "FOUND IN" by the first zone, the others under it. Hides
## the table and the gap over it when there is no zone.
func _set_zones(zone_names: Array[String]) -> void:
	for row: Node in _sources.get_children():
		_sources.remove_child(row)
		row.queue_free()
	for index: int in zone_names.size():
		_add_row(_FOUND_IN if index == 0 else "", zone_names[index])
	_sources_block.visible = not zone_names.is_empty()

## Adds one row to the table. The value is plain text, so its brackets are
## escaped.
func _add_row(label: String, value: String) -> void:
	var row: TableRow = _TABLE_ROW_SCENE.instantiate() as TableRow
	_sources.add_child(row)
	row.setup(label, LacquerText.decimal_bbcode(value))
