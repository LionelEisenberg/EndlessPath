extends GutTest

## Unit tests for CameraPush, the reversible camera push the board open and
## close transition drives: zoom and position lerp from where the player left
## the camera to an end zoom that puts a world point at a screen point, and
## restore() puts the camera back exactly.

const START_ZOOM: Vector2 = Vector2(2, 2)
const START_POSITION: Vector2 = Vector2(500, 300)
const WORLD_POINT: Vector2 = Vector2(640, 420)
const SCREEN_POINT: Vector2 = Vector2(962, 612)
const NEAR: Vector2 = Vector2(0.001, 0.001)

var _camera: Camera2D = null
var _push: CameraPush = null

func before_each() -> void:
	_camera = autofree(Camera2D.new())
	_camera.zoom = START_ZOOM
	_camera.position = START_POSITION
	_push = CameraPush.new()

#-----------------------------------------------------------------------------
# APPLY
#-----------------------------------------------------------------------------

func test_apply_one_reaches_the_end_zoom_and_aims_at_the_point() -> void:
	_push.begin(_camera, WORLD_POINT, SCREEN_POINT, 3.0)
	_push.apply(1.0)
	assert_eq(_camera.zoom, Vector2(3, 3))
	assert_almost_eq(ZoneMapMath.world_to_screen(WORLD_POINT, _camera.position, 3.0), SCREEN_POINT, NEAR)

func test_apply_zero_is_where_it_started() -> void:
	_push.begin(_camera, WORLD_POINT, SCREEN_POINT, 3.0)
	_push.apply(1.0)
	_push.apply(0.0)
	assert_eq(_camera.zoom, START_ZOOM)
	assert_eq(_camera.position, START_POSITION)

func test_apply_without_begin_leaves_the_camera_alone() -> void:
	_push.apply(1.0)
	assert_eq(_camera.zoom, START_ZOOM)
	assert_eq(_camera.position, START_POSITION)
	assert_false(_push.is_active())

#-----------------------------------------------------------------------------
# RESTORE
#-----------------------------------------------------------------------------

func test_restore_is_exact_after_a_partial_push() -> void:
	_push.begin(_camera, WORLD_POINT, SCREEN_POINT, 3.0)
	_push.apply(0.37)
	assert_true(_push.is_active())
	_push.restore()
	assert_eq(_camera.zoom, START_ZOOM)
	assert_eq(_camera.position, START_POSITION)
	assert_false(_push.is_active())

func test_restore_without_begin_leaves_the_camera_alone() -> void:
	_push.restore()
	assert_eq(_camera.zoom, START_ZOOM)
	assert_eq(_camera.position, START_POSITION)

func test_a_second_begin_keeps_the_first_saved_camera() -> void:
	_push.begin(_camera, WORLD_POINT, SCREEN_POINT, 3.0)
	_push.apply(0.5)
	_push.begin(_camera, WORLD_POINT, SCREEN_POINT, 3.0)
	_push.restore()
	assert_eq(_camera.zoom, START_ZOOM)
	assert_eq(_camera.position, START_POSITION)

func test_a_new_push_after_restore_saves_the_camera_again() -> void:
	_push.begin(_camera, WORLD_POINT, SCREEN_POINT, 3.0)
	_push.apply(1.0)
	_push.restore()
	_camera.zoom = Vector2(1, 1)
	_camera.position = Vector2(10, 20)
	_push.begin(_camera, WORLD_POINT, SCREEN_POINT, 3.0)
	_push.apply(1.0)
	_push.restore()
	assert_eq(_camera.zoom, Vector2(1, 1))
	assert_eq(_camera.position, Vector2(10, 20))
