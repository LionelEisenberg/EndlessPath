## State for the Character View.
## Opening and closing the book is shared with the other menu books (BookViewState).
class_name CharacterViewState
extends BookViewState

func _get_view() -> MenuBookView:
	return scene_root.character_view as MenuBookView

func _is_close_event(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_character")
