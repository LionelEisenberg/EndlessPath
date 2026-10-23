## State for the Cycling View. ActionManager.start_cycling pushes it and
## stop_cycling pops it. Cycling does not cover the zone view: the board sits in
## the map gap, with no backdrop, and the cultivator cabinet, Goals and the log
## stay where the zone view put them. Entering turns the rest of the zone view
## over with MainView.set_cycling_mode() (the chest lists the techniques, the
## dock hides, the map takes no input) and blocks the full log, as a menu book
## does, so that Esc always reaches the board. Exiting undoes all of it.
class_name CyclingViewState
extends MainViewState

func _ready() -> void:
	if ActionManager:
		ActionManager.start_cycling.connect(_on_start_cycling)
		ActionManager.stop_cycling.connect(_on_stop_cycling)

## Called when entering this state: the zone view is turned over to cycling, the
## board shows and the full log is blocked.
func enter() -> void:
	scene_root.set_cycling_mode(true)
	scene_root.cycling_view.visible = true
	_block_full_log(true)

## Called when exiting this state: the full log can open again, the board hides
## and the zone view is given back.
func exit() -> void:
	_block_full_log(false)
	scene_root.cycling_view.visible = false
	scene_root.set_cycling_mode(false)

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("close_cycling_view"):
		ActionManager.stop_action()

## Keeps the full log shut while the board is open, or lets it open again. The
## view-state tests stand a plain Control in for the log: it has no full log.
func _block_full_log(blocked: bool) -> void:
	var log_window: LogWindow = scene_root.log_window as LogWindow
	if log_window != null:
		log_window.set_full_log_blocked(blocked)

func _on_start_cycling(_data: Variant) -> void:
	# Already on the stack: a second entry would outlive the close and stay on
	# top of the zone view, where it swallows the menu keys.
	if not scene_root.state_stack.has(self):
		scene_root.push_state(self)

func _on_stop_cycling() -> void:
	scene_root.pop_state()
