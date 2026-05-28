extends Control

## MaterialsTab
## Hosts the shared chrome (SortSubBanner, GridToolbar, InventoryGrid) and a
## right-page MaterialDetailCard + MaterialTipCard. Populates the grid with
## MaterialSlot instances from InventoryManager and updates the detail card
## when a slot is clicked.

const MaterialSlotScene: PackedScene = preload("res://scenes/inventory/inventory_view/materials_tab/material_slot.tscn")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var sort_banner: SortSubBanner = %MaterialsSortSubBanner
@onready var grid_toolbar: GridToolbar = %MaterialsGridToolbar
@onready var grid: InventoryGrid = %MaterialsInventoryGrid
@onready var detail_card: MaterialDetailCard = %MaterialDetailCard
@onready var trash_slot: TrashSlot = grid_toolbar.trash_slot

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	sort_banner.set_options(PackedStringArray(["All"]))
	sort_banner.enabled = false

	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_rebuild(InventoryManager.get_material_items())

#-----------------------------------------------------------------------------
# REBUILD
#-----------------------------------------------------------------------------

func _rebuild(materials: Dictionary[MaterialDefinitionData, int]) -> void:
	grid.clear_slots()
	var first_def: MaterialDefinitionData = null
	for def in materials.keys():
		var slot: MaterialSlot = MaterialSlotScene.instantiate()
		grid.add_slot(slot)
		slot.setup(def, materials[def])
		slot.clicked.connect(_on_slot_clicked)
		if first_def == null:
			first_def = def
	grid_toolbar.set_count_text("%d kinds collected" % materials.size())
	if first_def:
		detail_card.setup_from_definition(first_def)
	else:
		detail_card.reset()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_slot_clicked(slot: MaterialSlot, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		detail_card.setup_from_definition(slot.get_definition())

func _on_inventory_changed(_inv: InventoryData) -> void:
	_rebuild(InventoryManager.get_material_items())
