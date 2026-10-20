## State for the Merchant shop overlay.
## ActionManager.start_merchant opens it and ActionManager.stop_merchant
## closes it. Leave and Escape ask ActionManager to stop the merchant action,
## the way the cycling view does. Uses the GreyBackground fade like the
## Character view.
class_name MerchantViewState
extends MainViewState

func _ready() -> void:
	if ActionManager:
		ActionManager.start_merchant.connect(_on_start_merchant)
		ActionManager.stop_merchant.connect(_on_stop_merchant)

## Called when entering this state.
func enter() -> void:
	scene_root.grey_background.show_with_panel(scene_root.merchant_view)

## Called when exiting this state.
## Hiding is driven by grey_background.panel_hidden -> _on_close_finished -> remove_state,
## so by the time exit() runs the grey background and merchant view are already hidden.
func exit() -> void:
	pass

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		ActionManager.stop_action()

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
	ActionManager.stop_action()

func _is_top_state() -> bool:
	return not scene_root.state_stack.is_empty() and scene_root.state_stack.back() == self
