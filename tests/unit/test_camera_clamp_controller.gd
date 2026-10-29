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

## A point inside either rect of the L stays, a point in its empty corner goes to
## the nearest rect, and with no rects the point is left where it is.
func test_nearest_point_in_rects() -> void:
	var none: Array[Rect2] = []
	var cases: Array[Dictionary] = [
		{"name": "inside the wide rect", "point": Vector2(150.0, 50.0), "rects": L_RECTS, "expected": Vector2(150.0, 50.0)},
		{"name": "inside the tall rect", "point": Vector2(50.0, 150.0), "rects": L_RECTS, "expected": Vector2(50.0, 150.0)},
		{"name": "the empty corner, nearer the wide rect", "point": Vector2(190.0, 120.0), "rects": L_RECTS, "expected": Vector2(190.0, 100.0)},
		{"name": "the empty corner, nearer the tall rect", "point": Vector2(120.0, 190.0), "rects": L_RECTS, "expected": Vector2(100.0, 190.0)},
		{"name": "no rects", "point": Vector2(999.0, -5.0), "rects": none, "expected": Vector2(999.0, -5.0)},
	]
	for case: Dictionary in cases:
		var rects: Array[Rect2] = case.rects
		assert_eq(CameraClampController.nearest_point_in_rects(case.point, rects), case.expected, case.name)

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
