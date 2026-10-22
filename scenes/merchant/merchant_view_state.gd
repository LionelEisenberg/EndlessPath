## State for the Merchant shop overlay.
## ActionManager.start_merchant opens it and ActionManager.stop_merchant
## closes it. Leave and Escape ask ActionManager to stop the merchant action,
## the way the cycling view does. Uses the GreyBackground fade like the
## Character view.
class_name MerchantViewState
extends MainViewState

## The HUD windows the open shop hid, each with the visibility it had.
var _hidden_hud_windows: Dictionary[Control, bool] = {}

func _ready() -> void:
	if ActionManager:
		ActionManager.start_merchant.connect(_on_start_merchant)
		ActionManager.stop_merchant.connect(_on_stop_merchant)

## Called when entering this state.
func enter() -> void:
	_hide_hud_windows()
	scene_root.grey_background.show_with_panel(scene_root.merchant_view)

## Called when exiting this state.
## Hiding is driven by grey_background.panel_hidden -> _on_close_finished -> remove_state,
## so by the time exit() runs the grey background and merchant view are already hidden.
func exit() -> void:
	_restore_hud_windows()

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_stop_merchant_action()

func _on_start_merchant(action_data: MerchantActionData) -> void:
	var merchant_view: MerchantView = scene_root.merchant_view
	if not merchant_view.close_requested.is_connected(_on_close_requested):
		merchant_view.close_requested.connect(_on_close_requested)
	merchant_view.setup(action_data)
	# Already on the stack: rebinding the stock is enough. A second entry would
	# outlive the close and leave an invisible shop catching input.
	if not scene_root.state_stack.has(self):
		scene_root.push_state(self)

func _on_stop_merchant() -> void:
	if not _is_top_state():
		# Another view sits above the shop. Hide the shop at once, without the
		# grey fade that view may be using, and leave that view open.
		scene_root.merchant_view.visible = false
		scene_root.remove_state(self)
		return
	if not scene_root.grey_background.panel_hidden.is_connected(_on_close_finished):
		scene_root.grey_background.panel_hidden.connect(_on_close_finished, CONNECT_ONE_SHOT)
	scene_root.grey_background.hide_with_panel(scene_root.merchant_view)

## Removes only this state, so a view pushed during the fade-out stays open.
func _on_close_finished() -> void:
	scene_root.remove_state(self)

func _on_close_requested() -> void:
	_stop_merchant_action()

## Stops the merchant action, and only that. The shop stays the top state for
## its whole fade-out, while the idle action it replaced already runs again: a
## second Leave or Escape then must not stop that idle action.
func _stop_merchant_action() -> void:
	if ActionManager.get_current_action() is MerchantActionData:
		ActionManager.stop_action()

func _is_top_state() -> bool:
	return not scene_root.state_stack.is_empty() and scene_root.state_stack.back() == self

## Hides the log and the Goals board. The shop covers part of them, so their
## text would show cut off at the panel's edge.
func _hide_hud_windows() -> void:
	for window: Control in [scene_root.log_window, scene_root.goals_panel]:
		_hidden_hud_windows[window] = window.visible
		window.visible = false

func _restore_hud_windows() -> void:
	for window: Control in _hidden_hud_windows:
		window.visible = _hidden_hud_windows[window]
	_hidden_hud_windows.clear()
