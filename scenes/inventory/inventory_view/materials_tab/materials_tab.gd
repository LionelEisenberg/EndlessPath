extends Control

## MaterialsTab
## The Materials tab, pressed into the book's two pages at 1x. Left page: the
## caption "N KINDS" and the same 6 × 6 page of slots as Equipment, a deep
## MaterialSlot per material with its count on a paper tag, then shallow empty
## slots to the end of the page (or of the last row past it). Past 36 kinds
## the grid scrolls. The grid sits in GridFrame, which clips it in its place:
## the grid itself does not clip, so the printer's marks round a slot show
## whole. Right page: the material's name as the title and, under its last
## line, the details panel (MaterialDetails). The details show the material
## last pointed at and keep to it while the stacks change; printer's marks sit
## round its slot. With nothing gathered, the page says so and the right page
## stays blank. Materials can't be dragged or discarded.

const _SLOT_SCENE: PackedScene = preload("res://scenes/inventory/inventory_view/materials_tab/material_slot.tscn")

## The caption over the grid.
const _KINDS: String = "%d KINDS"
const _ONE_KIND: String = "1 KIND"

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var grid: InventoryGrid = %MaterialsInventoryGrid
@onready var kinds_label: Label = %KindsLabel
@onready var empty_label: Label = %EmptyLabel
@onready var right_title: PageTitle = %RightTitle
@onready var details: MaterialDetails = %MaterialDetails

## Content hash of the material stacks at the last rebuild. Equipment and
## consumable changes leave the stacks alone, so they skip the rebuild.
var _last_materials_hash: int = 0
## The grid's slots in order: the materials, then the empty slots.
var _slots: Array[MaterialSlot] = []
## The slot the printer's marks sit round; null when none.
var _marked: MaterialSlot = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_rebuild(InventoryManager.get_material_items())

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Opens the page on its first item: rebuilds the grid, then shows the first
## material, or hides the details when nothing is gathered. The details are
## cleared first, so they work out the material's sources again: an activity
## unlocked since the page last showed is listed. Called whenever the page is
## opened.
func open_page() -> void:
	details.clear()
	_rebuild(InventoryManager.get_material_items())

#-----------------------------------------------------------------------------
# REBUILD
#-----------------------------------------------------------------------------

## Rebuilds the grid, one slot per material in inventory order, then the empty
## slots, and keeps the details on the material they show.
func _rebuild(materials: Dictionary[MaterialDefinitionData, int]) -> void:
	_last_materials_hash = materials.hash()
	_marked = null
	grid.clear_slots()
	_slots.clear()
	for def: MaterialDefinitionData in materials.keys():
		_add_slot(def, materials[def])
	for _empty: int in _empty_slot_count(materials.size()):
		_add_slot(null, 0)
	kinds_label.text = _ONE_KIND if materials.size() == 1 else _KINDS % materials.size()
	empty_label.visible = materials.is_empty()
	_follow_shown(materials)

## Adds one slot to the grid: a material and how many the player has, or an
## empty slot when `def` is null.
func _add_slot(def: MaterialDefinitionData, qty: int) -> void:
	var slot: MaterialSlot = _SLOT_SCENE.instantiate() as MaterialSlot
	grid.add_slot(slot)
	slot.setup(def, qty)
	slot.hovered.connect(_on_slot_hovered)
	slot.clicked.connect(_on_slot_clicked)
	_slots.append(slot)

## How many empty slots follow `kinds` materials: the rest of the 6 × 6 page,
## or of the last row past it. None when nothing is gathered, since the page
## then prints a line in the grid's place.
static func _empty_slot_count(kinds: int) -> int:
	if kinds == 0:
		return 0
	var columns: int = InventoryData.PAGE_COLUMNS
	var rows: int = maxi(InventoryData.PAGE_ROWS, ceili(float(kinds) / columns))
	return rows * columns - kinds

#-----------------------------------------------------------------------------
# THE SHOWN MATERIAL
#-----------------------------------------------------------------------------

## Shows `def` in the details and its name as the right page's title, and
## marks `slot`, unmarking the one before.
func _show(def: MaterialDefinitionData, slot: MaterialSlot) -> void:
	_mark(slot)
	right_title.title = def.item_name
	right_title.visible = true
	details.show_material(def, InventoryManager.get_material_items().get(def, 0))

## Shows the first material, or clears the details, the title and the marks
## when nothing is gathered.
func _show_first() -> void:
	if _slots.is_empty() or _slots[0].get_definition() == null:
		_mark(null)
		details.clear()
		right_title.visible = false
		return
	_show(_slots[0].get_definition(), _slots[0])

## Keeps the details and the marks on the material shown after the stacks
## changed, and reprints how many the player has. When it has left the bag,
## the page shows its first material.
func _follow_shown(materials: Dictionary[MaterialDefinitionData, int]) -> void:
	var shown: MaterialDefinitionData = details.get_shown_material()
	if shown == null or not materials.has(shown):
		_show_first()
		return
	_show(shown, _slot_of(shown))

## Moves the printer's marks to `slot`. Null leaves nothing marked.
func _mark(slot: MaterialSlot) -> void:
	if _marked != null and _marked != slot and is_instance_valid(_marked):
		_marked.set_marked(false)
	_marked = slot
	if slot != null:
		slot.set_marked(true)

## The slot holding `def`, or null.
func _slot_of(def: MaterialDefinitionData) -> MaterialSlot:
	for slot: MaterialSlot in _slots:
		if slot.get_definition() == def:
			return slot
	return null

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## Pointing at a slot shows its material. An empty slot changes nothing, so
## the details keep the last material.
func _on_slot_hovered(slot: MaterialSlot) -> void:
	if slot.get_definition() == null:
		return
	_show(slot.get_definition(), slot)

## A left press on a slot shows its material, as pointing at it does.
func _on_slot_clicked(slot: MaterialSlot, event: InputEvent) -> void:
	if slot.get_definition() == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show(slot.get_definition(), slot)

func _on_inventory_changed(inv: InventoryData) -> void:
	# Only the material stacks drive the page: skip the rebuild when an
	# equipment or consumable change left them as they were.
	if inv.materials.hash() != _last_materials_hash:
		_rebuild(inv.materials)
