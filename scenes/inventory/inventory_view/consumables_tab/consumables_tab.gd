extends Control

## ConsumablesTab
## Hosts the shared chrome (SortSubBanner, GridToolbar, InventoryGrid) for
## consumable stacks on the left page, plus a CombatHotbar + ItemDetailCard
## on the right page. Right-click a consumable in the grid to equip it to
## the first empty hotbar slot. Click an equipped hotbar slot to unequip.

const ConsumableSlotScene: PackedScene = preload("res://scenes/inventory/inventory_view/consumables_tab/consumable_slot.tscn")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var sort_banner: SortSubBanner = %ConsumablesSortSubBanner
@onready var grid_toolbar: GridToolbar = %ConsumablesGridToolbar
@onready var grid: InventoryGrid = %ConsumablesInventoryGrid
@onready var hotbar: CombatHotbar = %ConsumablesCombatHotbar
@onready var detail_card: ItemDetailCard = %ConsumablesItemDetailCard
@onready var trash_slot: TrashSlot = %ConsumablesTrashSlot

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	sort_banner.set_options(PackedStringArray(["All"]))
	sort_banner.enabled = false
	grid_toolbar.set_trash_slot(trash_slot)
	hotbar.slot_clicked.connect(_on_hotbar_clicked)

	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_rebuild(InventoryManager.get_inventory())

#-----------------------------------------------------------------------------
# REBUILD
#-----------------------------------------------------------------------------

func _rebuild(inv: InventoryData) -> void:
	grid.clear_slots()
	var first_def: ConsumableDefinitionData = null
	for def in inv.consumables.keys():
		var slot: ConsumableSlot = ConsumableSlotScene.instantiate()
		grid.add_slot(slot)
		slot.setup(def, inv.consumables[def])
		slot.clicked.connect(_on_grid_slot_clicked)
		if first_def == null:
			first_def = def
	grid_toolbar.set_count_text("%d stacks" % inv.consumables.size())
	if first_def:
		detail_card.setup_from_definition(first_def)
	else:
		detail_card.reset()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_grid_slot_clicked(slot: ConsumableSlot, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			detail_card.setup_from_definition(slot.get_definition())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_equip_to_first_empty(slot.get_definition())

func _on_hotbar_clicked(slot: HotbarSlot, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if slot.get_definition() != null:
			InventoryManager.unequip_consumable(slot.slot_index)

func _on_inventory_changed(inv: InventoryData) -> void:
	_rebuild(inv)

#-----------------------------------------------------------------------------
# PRIVATE HELPERS
#-----------------------------------------------------------------------------

## Equip the consumable to the first empty hotbar slot (0..3). If all four
## slots are already occupied, overwrite slot 0 as a fallback so the
## right-click always lands somewhere visible.
func _equip_to_first_empty(def: ConsumableDefinitionData) -> void:
	if def == null:
		return
	var inv: InventoryData = InventoryManager.get_inventory()
	for i in 4:
		if not inv.equipped_consumables.has(i):
			InventoryManager.equip_consumable(def, i)
			return
	# All slots full — replace slot 0
	InventoryManager.equip_consumable(def, 0)
