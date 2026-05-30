extends Control

## ConsumablesTab
## Hosts the SortSubBanner + a vertical InventoryList of consumable rows on the
## left page, plus a CombatHotbar + ItemDescriptionBox on the right page.
## Drag a row onto a combat hotbar slot to equip the consumable there; click an
## equipped hotbar slot to unequip. Left-click a row to show its details.
## (Editor preview rows are authored under the list and cleared at runtime.)

const ConsumableRowScene: PackedScene = preload("res://scenes/inventory/inventory_view/consumables_tab/consumable_row.tscn")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var sort_banner: SortSubBanner = %ConsumablesSortSubBanner
@onready var list: InventoryList = %ConsumablesInventoryList
@onready var hotbar: CombatHotbar = %ConsumablesCombatHotbar
@onready var detail_box: ItemDescriptionBox = %ConsumablesItemDescriptionBox

## Content hash of the consumable stacks at the last list rebuild. equip/unequip
## change only the hotbar (equipped_consumables), not the stacks, so we skip the
## full list rebuild when the stacks are unchanged.
var _last_consumables_hash: int = 0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	sort_banner.set_options(PackedStringArray(["All"]))
	sort_banner.enabled = false
	hotbar.slot_clicked.connect(_on_hotbar_clicked)
	hotbar.consumable_dropped.connect(_on_consumable_dropped)

	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_rebuild(InventoryManager.get_inventory())

#-----------------------------------------------------------------------------
# REBUILD
#-----------------------------------------------------------------------------

func _rebuild(inv: InventoryData) -> void:
	_last_consumables_hash = inv.consumables.hash()
	list.clear_slots()
	var first_def: ConsumableDefinitionData = null
	for def in inv.consumables.keys():
		var row: ConsumableRow = ConsumableRowScene.instantiate()
		list.add_slot(row)
		row.setup(def, inv.consumables[def])
		row.clicked.connect(_on_row_clicked)
		if first_def == null:
			first_def = def
	if first_def:
		detail_box.setup_from_definition(first_def)
	else:
		detail_box.reset()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## Left-click selects the row for the detail panel. Equipping is drag-and-drop
## (handled by the row's _get_drag_data and the hotbar slots' _drop_data).
func _on_row_clicked(row: ConsumableRow, _event: InputEvent) -> void:
	detail_box.setup_from_definition(row.get_definition())

## Equip a consumable dragged from the list onto the hotbar slot it was dropped on.
func _on_consumable_dropped(def: ConsumableDefinitionData, slot_index: int) -> void:
	InventoryManager.equip_consumable(def, slot_index)

func _on_hotbar_clicked(slot: HotbarSlot, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if slot.get_definition() != null:
			InventoryManager.unequip_consumable(slot.slot_index)

func _on_inventory_changed(inv: InventoryData) -> void:
	# Only the consumable stacks drive the list. Skip the rebuild when they're
	# unchanged (e.g. an equip/unequip that only touched the hotbar).
	if inv.consumables.hash() == _last_consumables_hash:
		return
	_rebuild(inv)
