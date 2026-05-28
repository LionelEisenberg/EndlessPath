class_name PaginationBar
extends HBoxContainer

## PaginationBar
## Bottom bar of the Equipment tab: one button per unlocked page (center) and
## the discard/trash slot (right). Emits page_selected on click and
## page_hovered on mouse-enter (used for the drag-to-flip behaviour driven by
## the EquipmentTab controller).

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal page_selected(index: int)   # 0-based page index, on click
signal page_hovered(index: int)    # 0-based page index, on mouse-enter

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var page_buttons: HBoxContainer = %PageButtons
@onready var trash_slot: TrashSlot = %TrashSlot

const PAGE_BUTTON_SCENE: PackedScene = preload("res://scenes/inventory/inventory_view/equipment_tab/page_button/page_button.tscn")

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _active_page: int = 0

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Rebuild the page-button row for `unlocked_pages` and mark `active_page`.
func setup(unlocked_pages: int, active_page: int) -> void:
	_active_page = active_page
	# remove_child before queue_free so get_child_count() is correct
	# synchronously even when setup() runs twice in one frame (queue_free
	# alone defers removal to end-of-frame).
	for child in page_buttons.get_children():
		page_buttons.remove_child(child)
		child.queue_free()
	for p in unlocked_pages:
		page_buttons.add_child(_make_page_button(p))
	_refresh_active_visuals()

## Highlight a different active page without rebuilding the buttons.
func set_active_page(page: int) -> void:
	_active_page = page
	_refresh_active_visuals()

#-----------------------------------------------------------------------------
# INTERNAL
#-----------------------------------------------------------------------------

func _make_page_button(page_index: int) -> TextureButton:
	var btn: TextureButton = PAGE_BUTTON_SCENE.instantiate()
	(btn.get_node("PageNumber") as Label).text = str(page_index + 1)
	btn.pressed.connect(func() -> void: page_selected.emit(page_index))
	btn.mouse_entered.connect(func() -> void: page_hovered.emit(page_index))
	return btn

func _refresh_active_visuals() -> void:
	var i := 0
	for child in page_buttons.get_children():
		if child is BaseButton:
			(child as BaseButton).button_pressed = (i == _active_page)
		i += 1
