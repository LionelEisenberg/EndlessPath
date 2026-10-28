extends GutTest

## The board transition's camera push against the zone map's own camera moves
## (design: Behaviour rules › The camera): the zoom controller's ease after a
## wheel tick, the glide to a zone (ZoneTilemap.frame_zone()) and the way back
## from the adventure zoom (ZoneTransition.reset_camera()). A board that opens
## while one of them runs ends it at its end first, so the push saves the
## camera where it comes to rest; nothing else moves the camera until the push
## has restored it, and then the zoom controller works again.
## The real zone map, cultivator cabinet and ZoneTransition stand side by side
## under one parent in the tree, as in main_game.tscn, their moves on the frame
## clock. The player's own processing is off, so the tests drive the board with
## advance() and finish(); it is bound through a MainView that never enters the
## tree, the way MainView._ready() binds it.

const ZONE_TILEMAP_SCENE: PackedScene = preload("res://scenes/zones/zone_tilemap/zone_tilemap.tscn")
const PLATE_SCENE: PackedScene = preload("res://scenes/zones/cultivator_plate/cultivator_plate.tscn")
const TRANSITION_SCENE: PackedScene = preload("res://scenes/ui/main_view/board_transition/board_transition.tscn")

const ADVENTURE_ID: String = "shallow_woods_adventure_action"

## The cycling board's rectangle.
const BOARD_RECT: Rect2 = Rect2(680, 24, 564, 1036)
## How far a glide back to the zone starts from the camera's rest.
const GLIDE_FROM: Vector2 = Vector2(-160, 0)
## How long the board stays open while the tests watch the camera: a third of
## a glide, and most of the way a zoom ease covers.
const OPEN_SECONDS: float = 0.1
## One 60 FPS frame, the close's first step.
const FRAME: float = 1.0 / 60.0
const NEAR: Vector2 = Vector2(0.001, 0.001)

var _map: ZoneTilemap = null
var _zone_transition: ZoneTransition = null
var _main_view: MainView = null
var _player: BoardTransition = null
var _spec: BoardTransitionSpec = null

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	var zone_view := Control.new()
	zone_view.size = ZoneMapMath.VIEWPORT_SIZE
	add_child_autofree(zone_view)
	_map = ZONE_TILEMAP_SCENE.instantiate() as ZoneTilemap
	_map.name = "ZoneTilemap"
	zone_view.add_child(_map)
	# The project's hex layer overrides _ready() without super(), so the addon
	# sets up its conversions only when the shared TileSet emits `changed`.
	_map.tile_map.tile_set.emit_changed()
	var plate: CultivatorPlate = PLATE_SCENE.instantiate() as CultivatorPlate
	plate.name = "CultivatorPlate"
	zone_view.add_child(plate)
	_zone_transition = ZoneTransition.new()
	zone_view.add_child(_zone_transition)
	_zone_transition.pellet_parent = add_child_autofree(Node2D.new())
	_player = add_child_autofree(TRANSITION_SCENE.instantiate()) as BoardTransition
	_player.set_process(false)
	_main_view = autofree(MainView.new())
	_main_view.state_stack = []
	_main_view.zone_map = _map
	_main_view.zone_transition = _zone_transition
	_main_view.board_transition = _player
	_main_view._bind_board_transition()
	_spec = BoardTransitionSpec.new()
	_spec.view = autofree(Control.new())
	_spec.view.visible = false
	_spec.board_rect = BOARD_RECT
	# The zoom controller's first ease (to its default zoom) ends on the first
	# frame; the camera rests after it.
	await wait_process_frames(2)

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	# Pellets in flight and the camera tweens end with the nodes; let them go
	# before GUT counts orphans.
	await wait_process_frames(1)

func _zoom_controller() -> CameraZoomController:
	return _map.get_node("%CameraZoomController") as CameraZoomController

## Pours the adventure drain to its end: the camera is on the adventure zoom.
func _zoom_into_an_adventure() -> void:
	ResourceManager.set_madra(ResourceManager.get_adventure_madra_capacity())
	var adventure: AdventureActionData = ZoneManager.get_action_by_id(ADVENTURE_ID) as AdventureActionData
	ActionManager.adventure_start_requested.emit(adventure)
	await wait_for_signal(ActionManager.start_adventure, 4.0)

#-----------------------------------------------------------------------------
# THE ZOOM EASE
#-----------------------------------------------------------------------------

## A wheel tick, then the board opens while the zoom still eases: the push
## starts from the zoom the tick chose, the zoom holds while the board is open,
## the close takes up from there, and its end gives back the chosen zoom.
func test_a_zoom_ease_under_way_ends_before_the_push_and_holds() -> void:
	var camera: Camera2D = _map.get_camera()
	var zoom: CameraZoomController = _zoom_controller()
	zoom.zoom_out()
	await wait_process_frames(1)
	var chosen: Vector2 = zoom.target_zoom
	assert_true(zoom.is_zoom_active(), "precondition: the wheel tick's ease is under way")
	assert_ne(camera.zoom, chosen, "precondition: the camera is short of the chosen zoom")
	_main_view.open_board(_spec)
	_player.finish()
	var open_zoom: Vector2 = camera.zoom
	assert_almost_eq(open_zoom, chosen * BoardTransitionTiming.CAMERA_ZOOM_FACTOR, NEAR,
		"the push starts from the zoom the wheel tick chose")
	await wait_seconds(OPEN_SECONDS)
	assert_eq(camera.zoom, open_zoom, "the zoom holds while the board is open")
	var before_close: Vector2 = camera.zoom
	_main_view.close_board(_spec, Callable())
	_player.advance(FRAME)
	assert_almost_eq(camera.zoom, before_close, NEAR, "the close's first frame does not jump")
	_player.finish()
	assert_eq(camera.zoom, chosen, "the close gives back the zoom the wheel tick chose")
	assert_eq(_map.get_resting_zoom(), chosen, "which is the zoom controller's target")
	zoom.zoom_in()
	await wait_process_frames(1)
	assert_ne(camera.zoom, chosen, "and the zoom controller eases again")

#-----------------------------------------------------------------------------
# THE GLIDE TO A ZONE
#-----------------------------------------------------------------------------

## The camera glides back to the zone (a click on the current zone's hex
## recentres it this way) when the board opens: the push starts from the
## glide's end, the camera holds while the board is open, and the close gives
## back the glide's end.
func test_a_glide_to_a_zone_under_way_ends_before_the_push_and_holds() -> void:
	var camera: Camera2D = _map.get_camera()
	var rest: Vector2 = camera.position
	camera.position += GLIDE_FROM
	_map.frame_zone(ZoneManager.get_current_zone(), _map.camera_ease_duration)
	await wait_process_frames(1)
	assert_ne(camera.position, rest, "precondition: the glide is under way")
	_main_view.open_board(_spec)
	_player.finish()
	var open_position: Vector2 = camera.position
	await wait_seconds(OPEN_SECONDS)
	assert_eq(camera.position, open_position, "the camera holds while the board is open")
	_main_view.close_board(_spec, Callable())
	_player.finish()
	assert_eq(camera.position, rest, "the close gives back where the glide was taking the camera")

#-----------------------------------------------------------------------------
# THE WAY BACK FROM AN ADVENTURE
#-----------------------------------------------------------------------------

## The camera eases back from the adventure zoom (the zone view's return) when
## the board opens: the push starts from the camera the player had before the
## adventure, it holds while the board is open, and the close gives it back.
func test_the_way_back_from_an_adventure_ends_before_the_push_and_holds() -> void:
	var camera: Camera2D = _map.get_camera()
	var rest_zoom: Vector2 = camera.zoom
	var rest_position: Vector2 = camera.position
	await _zoom_into_an_adventure()
	assert_ne(camera.zoom, rest_zoom, "precondition: the camera is on the adventure zoom")
	_zone_transition.reset_camera()
	await wait_process_frames(1)
	assert_ne(camera.zoom, rest_zoom, "precondition: the way back is under way")
	_main_view.open_board(_spec)
	_player.finish()
	var open_zoom: Vector2 = camera.zoom
	assert_almost_eq(open_zoom, rest_zoom * BoardTransitionTiming.CAMERA_ZOOM_FACTOR, NEAR,
		"the push starts from the zoom the player had before the adventure")
	await wait_seconds(OPEN_SECONDS)
	assert_eq(camera.zoom, open_zoom, "the zoom holds while the board is open")
	_main_view.close_board(_spec, Callable())
	_player.finish()
	assert_eq(camera.zoom, rest_zoom, "the close gives back the zoom from before the adventure")
	assert_eq(camera.position, rest_position, "and the position")
