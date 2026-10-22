extends GutTest

## Unit tests for CameraClampController's clamp regions: in centre mode, when
## regions are set, the camera's centre is kept inside one of them, the
## nearest, so the clamp can follow a shape no single rect covers (the zone
## map keeps at least one zone in view).

const CameraClampControllerScene: PackedScene = preload("res://scenes/camera/camera_clamp_controller/camera_clamp_controller.tscn")

## Two rects that meet in an L: their bounding box has an empty corner at
## (100-200, 100-200).
const L_RECTS: Array[Rect2] = [Rect2(0.0, 0.0, 200.0, 100.0), Rect2(0.0, 0.0, 100.0, 200.0)]

#-----------------------------------------------------------------------------
# NEAREST POINT
#-----------------------------------------------------------------------------

func test_a_point_inside_a_rect_stays() -> void:
	assert_eq(CameraClampController.nearest_point_in_rects(Vector2(150.0, 50.0), L_RECTS), Vector2(150.0, 50.0))
	assert_eq(CameraClampController.nearest_point_in_rects(Vector2(50.0, 150.0), L_RECTS), Vector2(50.0, 150.0))

func test_a_point_in_the_empty_corner_goes_to_the_nearest_rect() -> void:
	assert_eq(CameraClampController.nearest_point_in_rects(Vector2(190.0, 120.0), L_RECTS), Vector2(190.0, 100.0), "nearer the wide rect")
	assert_eq(CameraClampController.nearest_point_in_rects(Vector2(120.0, 190.0), L_RECTS), Vector2(100.0, 190.0), "nearer the tall rect")

func test_no_rects_leave_the_point() -> void:
	var none: Array[Rect2] = []
	assert_eq(CameraClampController.nearest_point_in_rects(Vector2(999.0, -5.0), none), Vector2(999.0, -5.0))

#-----------------------------------------------------------------------------
# CLAMPING A CAMERA
#-----------------------------------------------------------------------------

func _camera_with_clamp() -> Array:
	var camera := Camera2D.new()
	var clamp: CameraClampController = CameraClampControllerScene.instantiate()
	camera.add_child(clamp)
	add_child_autofree(camera)
	clamp.use_boundaries = true
	clamp.clamp_centre_only = true
	clamp.boundary_min = Vector2.ZERO
	clamp.boundary_max = Vector2(200.0, 200.0)
	return [camera, clamp]

func test_clamp_now_keeps_the_centre_in_a_region() -> void:
	var pair: Array = _camera_with_clamp()
	var camera: Camera2D = pair[0]
	var clamp: CameraClampController = pair[1]
	clamp.clamp_regions = L_RECTS
	camera.position = Vector2(500.0, 520.0)
	clamp.clamp_now()
	assert_eq(camera.position, Vector2(100.0, 200.0), "out past the empty corner: pulled to the tall rect's far corner")

func test_without_regions_the_boundary_alone_clamps() -> void:
	var pair: Array = _camera_with_clamp()
	var camera: Camera2D = pair[0]
	var clamp: CameraClampController = pair[1]
	camera.position = Vector2(500.0, 520.0)
	clamp.clamp_now()
	assert_eq(camera.position, Vector2(200.0, 200.0), "the boundary's corner, as before")
