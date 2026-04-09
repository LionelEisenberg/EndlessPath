## State for the Zone View.
class_name ZoneViewState
extends MainViewState

## Called when entering this state.
func enter() -> void:
	scene_root.zone_view.visible = true
	# Reset camera zoom if returning from adventure
	var zone_tilemap: Node = scene_root.zone_view.find_child("ZoneTilemap", true, false)
	if zone_tilemap and zone_tilemap.has_method("reset_camera_zoom"):
		zone_tilemap.reset_camera_zoom()

## Called when exiting this state.
func exit() -> void:
	scene_root.zone_view.visible = false

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		scene_root.push_state(scene_root.inventory_view_state)
