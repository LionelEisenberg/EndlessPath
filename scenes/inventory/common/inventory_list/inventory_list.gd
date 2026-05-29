class_name InventoryList
extends HBoxContainer

## InventoryList
## A scrollable vertical list host. Each tab populates it with its own row
## scenes via add_slot(). Mirrors InventoryGrid's API but lays children out in a
## single VBoxContainer column. The ScrollRail child stays bound to the inner
## ScrollContainer so the visual rail tracks scrolling (and hides when the
## content fits).
##
## Editor preview: author a few placeholder rows directly under
## ScrollContainer/ListContainer in the consuming scene. They show in the editor
## with no @tool needed; the tab clears them via clear_slots() before populating
## real data at runtime.

@onready var _scroll: ScrollContainer = %ScrollContainer
@onready var _list: VBoxContainer = %ListContainer
@onready var _rail: ScrollRail = $ScrollRail

func _ready() -> void:
	_rail.bind(_scroll)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Add a row Control to the list.
func add_slot(slot: Control) -> void:
	_ensure_list()
	_list.add_child(slot)

## Remove and free every row currently in the list (including any authored
## editor-preview placeholders).
func clear_slots() -> void:
	_ensure_list()
	for child in _list.get_children():
		child.queue_free()

## Returns all row children currently in the list.
func get_slots() -> Array[Node]:
	_ensure_list()
	return _list.get_children()

#-----------------------------------------------------------------------------
# INTERNAL
#-----------------------------------------------------------------------------

## Resolve the inner VBoxContainer. The @onready ref is null when a caller
## reaches in before this node's _ready has run, so fall back to the path.
func _ensure_list() -> void:
	if _list == null:
		_list = get_node("ScrollContainer/ListContainer")
