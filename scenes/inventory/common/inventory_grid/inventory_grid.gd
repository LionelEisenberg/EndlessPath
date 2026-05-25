class_name InventoryGrid
extends HBoxContainer

## InventoryGrid
## A scrollable grid host. Each tab populates it with its own slot scenes
## via add_slot(). The ScrollRail child stays bound to the inner
## ScrollContainer so visual scrolling tracks the player's wheel/drag.

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
	_grid.add_child(slot)

## Remove and free every slot currently in the grid.
func clear_slots() -> void:
	for child in _grid.get_children():
		child.queue_free()

## Returns all slot children currently in the grid.
func get_slots() -> Array[Node]:
	return _grid.get_children()
