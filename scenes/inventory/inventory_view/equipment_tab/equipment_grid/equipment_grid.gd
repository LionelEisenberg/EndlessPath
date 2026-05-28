@tool
class_name EquipmentGrid
extends MarginContainer

## EquipmentGrid
## One page of the equipment inventory, laid out as num_rows × num_columns
## slots. Page size (slots_per_page) is num_rows * num_columns; local slot index
## i on `current_page` maps to global inventory index
## current_page * slots_per_page() + i. Slot nodes are persistent children
## authored in the scene (editor-visible, stable across page flips) — the grid
## shows/hides and re-binds them, never recreates them. No scrolling; navigation
## is handled by the PaginationBar.
##
## num_rows / num_columns / row_separation / col_separation are live layout knobs
## (applied in-editor via @tool). NOTE: the scene provides a fixed pool of slot
## instances (SLOT_POOL_SIZE), so configs are capped at that many visible slots.
## InventoryData.SLOTS_PER_PAGE (capacity math) is independent — if you settle on
## a page size other than 36, sync it there and grow the slot pool to match.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Number of InventorySlot instances authored in the scene. Visible slot count
## (num_rows * num_columns) cannot exceed this without adding more instances.
const SLOT_POOL_SIZE := 48

#-----------------------------------------------------------------------------
# EXPORTS (live layout tuning)
#-----------------------------------------------------------------------------

@export var num_rows: int = InventoryData.PAGE_ROWS:
	set(value):
		num_rows = maxi(value, 1)
		if is_node_ready():
			_apply_grid_layout()
@export var num_columns: int = InventoryData.PAGE_COLUMNS:
	set(value):
		num_columns = maxi(value, 1)
		if is_node_ready():
			_apply_grid_layout()
@export var row_separation: int = 6:
	set(value):
		row_separation = maxi(value, 0)
		if is_node_ready():
			_apply_grid_layout()
@export var col_separation: int = 6:
	set(value):
		col_separation = maxi(value, 0)
		if is_node_ready():
			_apply_grid_layout()

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal slot_clicked(slot: InventorySlot, event: InputEvent)

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var grid_container: GridContainer = %GridContainer

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var current_page: int = 0

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	_apply_grid_layout()
	if Engine.is_editor_hint():
		return
	# Slots are persistent children authored in the scene (editor-visible and
	# stable across page flips); we only re-bind their data, never recreate them.
	for slot in get_slots():
		slot.clicked.connect(_on_slot_clicked)
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_update_grid(InventoryManager.get_inventory())

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Slots shown per page (num_rows * num_columns), capped at the authored pool.
func slots_per_page() -> int:
	return mini(num_rows * num_columns, SLOT_POOL_SIZE)

## Switch to a page and re-render. Clamps to [0, unlocked_pages - 1].
func set_page(page: int) -> void:
	var inventory := InventoryManager.get_inventory()
	var max_page := maxi(inventory.unlocked_equipment_pages - 1, 0)
	current_page = clampi(page, 0, max_page)
	_update_grid(inventory)

## Returns the currently-visible InventorySlot children of the grid.
func get_slots() -> Array[InventorySlot]:
	var slots: Array[InventorySlot] = []
	for child in grid_container.get_children():
		if child is InventorySlot and child.visible:
			slots.append(child)
	return slots

#-----------------------------------------------------------------------------
# SETUP FUNCTIONS
#-----------------------------------------------------------------------------

## Apply the tunable layout (columns, separations, visible slot count) to the
## GridContainer. Editor-safe: touches only the grid, no runtime/Inventory deps.
func _apply_grid_layout() -> void:
	if grid_container == null:
		return
	grid_container.columns = num_columns
	grid_container.add_theme_constant_override("h_separation", col_separation)
	grid_container.add_theme_constant_override("v_separation", row_separation)
	var visible_count := slots_per_page()
	var i := 0
	for child in grid_container.get_children():
		if child is Control:
			(child as Control).visible = i < visible_count
		i += 1

func _on_inventory_changed(_inventory: InventoryData) -> void:
	# A page may have been granted; re-clamp current_page and re-render.
	set_page(current_page)

func _update_grid(inventory: InventoryData) -> void:
	# Re-bind data onto the visible slot children (no recreation). Each local
	# child index i maps to global index base + i for the current page.
	var base := current_page * slots_per_page()
	var slots := get_slots()
	for i in slots.size():
		var global_index := base + i
		if inventory.equipment.has(global_index):
			slots[i].setup(inventory.equipment[global_index])
		else:
			slots[i].setup(null)

#-----------------------------------------------------------------------------
# INPUT HANDLING
#-----------------------------------------------------------------------------

func _on_slot_clicked(slot: InventorySlot, event: InputEvent) -> void:
	slot_clicked.emit(slot, event)
