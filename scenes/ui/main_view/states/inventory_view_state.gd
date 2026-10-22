## State for the Inventory View.
## Opening and closing the book is shared with the other menu books (BookViewState).
class_name InventoryViewState
extends BookViewState

func _get_view() -> MenuBookView:
	return scene_root.inventory_view as MenuBookView

func _is_close_event(event: InputEvent) -> bool:
	return event.is_action_pressed("close_inventory") or event.is_action_pressed("open_inventory")
