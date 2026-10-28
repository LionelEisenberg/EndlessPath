extends GutTest

## Unit tests for CameraZoomController's zoom_applied signal: it announces the
## zoom the camera actually has, after every eased step and the final snap, while
## zoom_changed announces the target the camera is easing to. Whatever must keep
## step with what is drawn (the adventure map's camera offset) follows the first.

const ZoomControllerScene: PackedScene = preload("res://scenes/camera/camera_zoom_controller/camera_zoom_controller.tscn")

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A camera with a zoom controller from 1 to 2 that opens at 1, in the tree.
func _camera_with_controller() -> Array:
	var camera := Camera2D.new()
	var controller: CameraZoomController = ZoomControllerScene.instantiate()
	controller.zoom_min = 1.0
	controller.zoom_max = 2.0
	controller.zoom_default = 1.0
	camera.add_child(controller)
	add_child_autofree(camera)
	return [camera, controller]

## The zooms the signal carried, in order.
func _announced_zooms(controller: CameraZoomController) -> Array[float]:
	var zooms: Array[float] = []
	for index: int in get_signal_emit_count(controller, "zoom_applied"):
		var parameters: Array = get_signal_parameters(controller, "zoom_applied", index)
		zooms.append((parameters[0] as Vector2).x)
	return zooms

#-----------------------------------------------------------------------------
# THE SIGNAL
#-----------------------------------------------------------------------------

func test_zoom_applied_carries_the_zoom_the_camera_has_after_each_step() -> void:
	var pair: Array = _camera_with_controller()
	var camera: Camera2D = pair[0]
	var controller: CameraZoomController = pair[1]
	# The first frame settles the opening zoom.
	simulate(controller, 1, 0.1)
	watch_signals(controller)

	controller.set_zoom_level(2.0)
	simulate(controller, 1, 0.05)

	assert_signal_emit_count(controller, "zoom_applied", 1, "one step, one announcement")
	assert_almost_eq(camera.zoom.x, 1.5, 0.0001, "precondition: half way after a step of weight 0.5")
	assert_eq(_announced_zooms(controller), [camera.zoom.x] as Array[float], "it carries the zoom the camera has now, not the target")
	assert_signal_emit_count(controller, "zoom_changed", 1, "zoom_changed announced the target once, when it was set")

func test_zoom_applied_follows_every_step_of_an_ease_and_its_end() -> void:
	var pair: Array = _camera_with_controller()
	var camera: Camera2D = pair[0]
	var controller: CameraZoomController = pair[1]
	simulate(controller, 1, 0.1)
	watch_signals(controller)
	controller.set_zoom_level(2.0)

	var steps: int = 0
	while controller.is_zoom_active() and steps < 400:
		simulate(controller, 1, 0.02)
		steps += 1

	assert_false(controller.is_zoom_active(), "precondition: the ease ended")
	var zooms: Array[float] = _announced_zooms(controller)
	assert_eq(zooms.size(), steps, "one announcement per step")
	assert_eq(zooms[zooms.size() - 1], 2.0, "the last one is the target the camera snapped to")
	assert_eq(camera.zoom, Vector2(2, 2), "which is the camera's zoom")
	for index: int in range(1, zooms.size()):
		assert_gte(zooms[index], zooms[index - 1], "the zoom only grows on the way in")

func test_a_controller_at_rest_announces_nothing() -> void:
	var pair: Array = _camera_with_controller()
	var controller: CameraZoomController = pair[1]
	simulate(controller, 1, 0.1)
	watch_signals(controller)

	simulate(controller, 5, 0.05)

	assert_signal_not_emitted(controller, "zoom_applied", "no zoom is changing")

#-----------------------------------------------------------------------------
# A LONG FRAME
#-----------------------------------------------------------------------------

## A frame longer than 1 / zoom_speed (a stall, a hitch while the window is
## dragged) asks for a step of more than the whole way. The weight of the step
## stops at 1, so the camera lands on the target and never passes it.
func test_a_long_frame_zooming_in_lands_on_the_target_and_not_past_it() -> void:
	var pair: Array = _camera_with_controller()
	var camera: Camera2D = pair[0]
	var controller: CameraZoomController = pair[1]
	simulate(controller, 1, 0.1)
	watch_signals(controller)
	controller.set_zoom_level(2.0)

	simulate(controller, 1, 0.5)

	assert_almost_eq(camera.zoom.x, 2.0, 0.0001, "it lands on the target, 5 times the whole way is still the whole way")
	assert_lte(camera.zoom.x, controller.zoom_max + 0.0001, "and never reaches past the largest zoom")
	assert_eq(_announced_zooms(controller).back(), camera.zoom.x, "zoom_applied carries the zoom it landed on")

func test_a_long_frame_zooming_out_lands_on_the_target_and_not_past_it() -> void:
	var pair: Array = _camera_with_controller()
	var camera: Camera2D = pair[0]
	var controller: CameraZoomController = pair[1]
	simulate(controller, 1, 0.1)
	camera.zoom = Vector2(2, 2)
	controller.set_zoom_level(1.0)

	simulate(controller, 1, 0.5)

	assert_almost_eq(camera.zoom.x, 1.0, 0.0001, "it lands on the target")
	assert_gte(camera.zoom.x, controller.zoom_min - 0.0001, "and never falls under the smallest zoom (past it the zoom is zero, then turns negative)")
	assert_gt(camera.zoom.y, 0.0, "the camera keeps a zoom it can draw with")
