extends Control

## ConsumablesTab
## The Consumables tab, pressed into the book's two pages at 1x. Left page: the
## list of stacks (ConsumableRow), one row every 80 px, seven in view and the
## rest scrolling. The list sits in ListFrame, which clips the rows in its
## place: the list itself does not clip, so the printer's marks round a row
## show whole. Right page: the hotbar with its keys printed under it, the
## printed hint, and the details panel (ConsumableDetails). The details show
## the consumable last pointed at, in the list or on the hotbar, and keep to it
## while the stacks change; printer's marks sit round the row or hotbar slot
## pointed at. Drag a row onto a hotbar slot to equip the consumable there,
## drag between slots to move or swap, click a filled slot to empty it.

const _ROW_SCENE: PackedScene = preload("res://scenes/inventory/inventory_view/consumables_tab/consumable_row.tscn")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var list: InventoryList = %ConsumablesInventoryList
@onready var hotbar: ConsumablesHotbar = %ConsumablesHotbar
@onready var details: ConsumableDetails = %ConsumableDetails
@onready var empty_label: Label = %EmptyLabel

## Content hash of the consumable stacks at the last list rebuild. equip/unequip
## change only the hotbar (equipped_consumables), not the stacks, so we skip the
## full list rebuild when the stacks are unchanged.
var _last_consumables_hash: int = 0
## The list's rows, top to bottom.
var _rows: Array[ConsumableRow] = []
## The row or hotbar slot the printer's marks sit round; null when none.
var _marked: Control = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	hotbar.slot_clicked.connect(_on_hotbar_clicked)
	hotbar.consumable_dropped.connect(_on_consumable_dropped)
	hotbar.slot_hovered.connect(_on_hotbar_slot_hovered)

	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_rebuild(InventoryManager.get_inventory())

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Opens the page on its first item: rebuilds the list, then shows the first
## stack, or hides the details when the pack is empty. Called whenever the page
## is opened.
func open_page() -> void:
	_rebuild(InventoryManager.get_inventory())
	_show_first()

#-----------------------------------------------------------------------------
# REBUILD
#-----------------------------------------------------------------------------

## Rebuilds the list, one row per stack in inventory order, the last without
## its rule, then keeps the details on the consumable they show.
func _rebuild(inv: InventoryData) -> void:
	_last_consumables_hash = inv.consumables.hash()
	if _marked is ConsumableRow:
		_marked = null
	list.clear_slots()
	_rows.clear()
	for def: ConsumableDefinitionData in inv.consumables.keys():
		var row: ConsumableRow = _ROW_SCENE.instantiate() as ConsumableRow
		list.add_slot(row)
		row.setup(def, inv.consumables[def])
		row.hovered.connect(_on_row_hovered)
		row.clicked.connect(_on_row_clicked)
		_rows.append(row)
	if not _rows.is_empty():
		_rows[-1].set_rule_visible(false)
	empty_label.visible = _rows.is_empty()
	_follow_shown(inv)

#-----------------------------------------------------------------------------
# THE SHOWN CONSUMABLE
#-----------------------------------------------------------------------------

## Shows `def` in the details and marks `pointed`, the row or hotbar slot the
## player pointed at, unmarking the one before.
func _show(def: ConsumableDefinitionData, pointed: Control) -> void:
	_mark(pointed)
	details.show_consumable(def)

## Shows the first stack, or clears the details and the marks when the pack is
## empty.
func _show_first() -> void:
	if _rows.is_empty():
		_mark(null)
		details.clear()
		return
	_show(_rows[0].get_definition(), _rows[0])

## Keeps the details and the marks on the consumable shown after the stacks or
## the hotbar changed, and prints its hotbar slot again. The marks stay on the
## hotbar slot they sit round while it still holds that consumable, and
## otherwise go to its row. When it has left the pack, the page shows its first
## item.
func _follow_shown(inv: InventoryData) -> void:
	var shown: ConsumableDefinitionData = details.get_consumable()
	if shown == null or not inv.consumables.has(shown):
		_show_first()
		return
	var pointed: Control = _marked
	if not (pointed is HotbarSlot and (pointed as HotbarSlot).get_definition() == shown):
		pointed = _row_of(shown)
	_show(shown, pointed)

## Moves the printer's marks to `pointed`, a ConsumableRow or a HotbarSlot.
## Null leaves nothing marked.
func _mark(pointed: Control) -> void:
	if _marked != null and _marked != pointed and is_instance_valid(_marked):
		_set_marked(_marked, false)
	_marked = pointed
	if pointed != null:
		_set_marked(pointed, true)

## Shows or hides the printer's marks round a ConsumableRow or a HotbarSlot.
static func _set_marked(pointed: Control, marked: bool) -> void:
	if pointed is ConsumableRow:
		(pointed as ConsumableRow).set_marked(marked)
	elif pointed is HotbarSlot:
		(pointed as HotbarSlot).set_marked(marked)

## The row showing `def`, or null.
func _row_of(def: ConsumableDefinitionData) -> ConsumableRow:
	for row: ConsumableRow in _rows:
		if row.get_definition() == def:
			return row
	return null

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## Pointing at a row shows it. The details hold still while a drag is under way.
func _on_row_hovered(row: ConsumableRow) -> void:
	if get_viewport().gui_is_dragging():
		return
	_show(row.get_definition(), row)

## Left-click shows the row. Equipping is drag-and-drop (handled by the row's
## _get_drag_data and the hotbar slots' _drop_data).
func _on_row_clicked(row: ConsumableRow, _event: InputEvent) -> void:
	_show(row.get_definition(), row)

## Pointing at a filled hotbar slot shows its consumable; an empty slot changes
## nothing.
func _on_hotbar_slot_hovered(slot: HotbarSlot) -> void:
	if slot.get_definition() == null or get_viewport().gui_is_dragging():
		return
	_show(slot.get_definition(), slot)

## Route a hotbar drop: a slot-to-slot drag (`from_slot >= 0`) moves/swaps the two
## slots; a drag from the list (`from_slot == -1`) equips the consumable there.
func _on_consumable_dropped(def: ConsumableDefinitionData, slot_index: int, from_slot: int) -> void:
	if from_slot >= 0:
		InventoryManager.swap_consumable_slots(from_slot, slot_index)
	else:
		InventoryManager.equip_consumable(def, slot_index)

## Unequip on left-click release. The press is reserved for drag detection, and a
## drag consumes its own release, so this only fires for a real (non-drag) click.
func _on_hotbar_clicked(slot: HotbarSlot, event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_viewport().gui_is_dragging():
			return
		if slot.get_definition() != null:
			InventoryManager.unequip_consumable(slot.slot_index)

func _on_inventory_changed(inv: InventoryData) -> void:
	# Only the consumable stacks drive the list. Skip the rebuild when they're
	# unchanged (e.g. an equip/unequip that only touched the hotbar), but keep
	# the details' hotbar slot and the marks current.
	if inv.consumables.hash() != _last_consumables_hash:
		_rebuild(inv)
		return
	_follow_shown(inv)
