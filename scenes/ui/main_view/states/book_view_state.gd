## Base for the states that show a menu book (Inventory, Abilities, Character,
## Path). Opens the book with the backdrop fade, and closes it on Esc, the
## menu's own key, the book's close tab or, once the book has opened, a click
## on the backdrop outside the book; all of them take the same route. The log
## and the Goals board stay where they are while a book is open, under the
## backdrop, but the full log is closed and kept shut (L does nothing), so Esc
## always reaches the book.
## Subclasses name their view and their close keys.
class_name BookViewState
extends MainViewState

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Called when entering this state.
func enter() -> void:
	var view: MenuBookView = _get_view()
	if not view.close_requested.is_connected(_request_close):
		view.close_requested.connect(_request_close)
	if not scene_root.grey_background.clicked.is_connected(_on_backdrop_clicked):
		scene_root.grey_background.clicked.connect(_on_backdrop_clicked)
	_block_full_log(true)
	scene_root.grey_background.show_with_panel(view)

## Called when exiting this state.
## Hiding is driven by grey_background.panel_hidden -> _on_close_finished -> pop_state,
## so by the time exit() runs the grey background and the view are already hidden.
func exit() -> void:
	var view: MenuBookView = _get_view()
	if view.close_requested.is_connected(_request_close):
		view.close_requested.disconnect(_request_close)
	if scene_root.grey_background.clicked.is_connected(_on_backdrop_clicked):
		scene_root.grey_background.clicked.disconnect(_on_backdrop_clicked)
	_block_full_log(false)

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if _is_close_event(event):
		_request_close()

#-----------------------------------------------------------------------------
# HOOKS
#-----------------------------------------------------------------------------

## The book this state shows.
func _get_view() -> MenuBookView:
	return null

## True when the event should close the book.
func _is_close_event(_event: InputEvent) -> bool:
	return false

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _request_close() -> void:
	if not scene_root.grey_background.panel_hidden.is_connected(_on_close_finished):
		scene_root.grey_background.panel_hidden.connect(_on_close_finished, CONNECT_ONE_SHOT)
	scene_root.grey_background.hide_with_panel(_get_view())

## The backdrop only closes a book that lies open: a click while it is still
## opening, such as a quick second click on the dock button, does nothing.
func _on_backdrop_clicked() -> void:
	if _get_view().book_frame.is_moving():
		return
	_request_close()

## Handle completion of the close (backdrop fade and book) to pop the state.
func _on_close_finished() -> void:
	scene_root.pop_state()
