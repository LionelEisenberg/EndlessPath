class_name InventoryGrid
extends HBoxContainer

## InventoryGrid
## A scrollable grid host. Each tab populates it with its own slot scenes
## via add_slot(). The ScrollRail child stays bound to the inner
## ScrollContainer so visual scrolling tracks the player's wheel/drag.
##
## Editor preview: author placeholder slots directly under
## ScrollContainer/GridContainer in the consuming scene (no @tool needed). The
## tab clears them via clear_slots() before populating real data at runtime.

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export var columns: int = 6:
	set(value):
		columns = value
		if _grid:
			_grid.columns = value

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _scroll: ScrollContainer = %ScrollContainer
@onready var _grid: GridContainer = %GridContainer
@onready var _rail: ScrollRail = $ScrollRail

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_grid.columns = columns
	_rail.bind(_scroll)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Add a slot Control to the grid.
func add_slot(slot: Control) -> void:
	_ensure_grid()
	_grid.add_child(slot)

## Remove and free every slot currently in the grid.
func clear_slots() -> void:
	_ensure_grid()
	for child in _grid.get_children():
		child.queue_free()

## Returns all slot children currently in the grid.
func get_slots() -> Array[Node]:
	_ensure_grid()
	return _grid.get_children()

#-----------------------------------------------------------------------------
# INTERNAL
#-----------------------------------------------------------------------------

## Resolve the inner GridContainer. The @onready ref is null when a caller
## reaches in before this node's _ready has run, so fall back to the path.
func _ensure_grid() -> void:
	if _grid == null:
		_grid = get_node("ScrollContainer/GridContainer")
