## State for the Inventory View.
class_name InventoryViewState
extends MainViewState

## Called when entering this state.
func enter() -> void:
	scene_root.grey_background.visible = true
	scene_root.inventory_view.visible = true
	scene_root.inventory_view.animate_open()

## Called when exiting this state.
func exit() -> void:
	scene_root.inventory_view.visible = false
	scene_root.grey_background.visible = false

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("close_inventory") or event.is_action_pressed("open_inventory"):
		if not scene_root.inventory_view.inventory_closed.is_connected(_on_inventory_animation_closed):
			scene_root.inventory_view.inventory_closed.connect(_on_inventory_animation_closed)
		scene_root.inventory_view.animate_close()

func _on_inventory_animation_closed() -> void:
	scene_root.pop_state()
	scene_root.inventory_view.inventory_closed.disconnect(_on_inventory_animation_closed)
