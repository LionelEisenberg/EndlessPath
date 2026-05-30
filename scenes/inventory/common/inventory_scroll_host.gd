class_name InventoryScrollHost
extends HBoxContainer

## InventoryScrollHost
## Shared base for the scrollable slot/row hosts (InventoryGrid, InventoryList).
## Holds the common API — add_slot / clear_slots / get_slots — and binds the
## ScrollRail to the inner ScrollContainer. Subclasses differ only in the inner
## container type (GridContainer vs VBoxContainer), resolved as the scroll's
## single child.
##
## Editor preview: author placeholder slots/rows directly under
## ScrollContainer/<container> in the consuming scene; they show in the editor
## and the owning tab clears them via clear_slots() before populating at runtime.

@onready var _scroll: ScrollContainer = %ScrollContainer
## The inner content container (GridContainer or VBoxContainer) — the
## ScrollContainer's only child.
@onready var _content: Container = %ScrollContainer.get_child(0) as Container
@onready var _rail: ScrollRail = $ScrollRail

func _ready() -> void:
	_rail.bind(_scroll)

## Add a slot/row Control to the content container.
func add_slot(slot: Control) -> void:
	_content.add_child(slot)

## Remove and free every child currently in the content container (including
## any authored editor-preview placeholders).
func clear_slots() -> void:
	for child in _content.get_children():
		child.queue_free()

## Returns all children currently in the content container.
func get_slots() -> Array[Node]:
	return _content.get_children()
