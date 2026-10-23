extends GutTest

## The adventure map's wheel zoom in the real AdventureView (the developer asked
## for it back in the first review round): the wheel over the map zooms it from 1
## to 2 through its zoom controller, as it zooms the zone map; a wheel over a
## board, or over the hidden map during a fight, does not zoom it; no coin takes
## the wheel, a hover or a press; and the hover follows the pointer as the zoom
## moves the hexes under it. The view is instanced as test_adventure_view_frame.gd
## does, on a canvas layer above GUT's own window so that the pointer reaches it,
## and each run starts through ActionManager on the shared fixture map
## (AdventureMapFixture). The pointer is the real one where the map reads it, and
## goes back to window point (0, 0) after each test; the wheel is pushed into the
## viewport as the mouse sends it, a press and a release.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const AdventureViewScene := preload("res://scenes/adventure/adventure_view/adventure_view.tscn")
const AdventureMapFixture := preload("res://tests/integration/adventure_map_fixture.gd")
const ADVENTURE_ACTION := AdventureMapFixture.ADVENTURE_ACTION

# The fixture map's tiles (see AdventureMapFixture).
const START := AdventureMapFixture.START
const FIGHT := AdventureMapFixture.FIGHT

## The Madra the zone's drain hands each run in these tests.
const MADRA_BUDGET: float = 50.0
## GUT draws its own window on this canvas layer, over the whole screen; the view
## goes above it, or GUT's window would take every press.
const GUT_LAYER: int = 128
## A point on the map that no board covers.
const MAP_POINT: Vector2 = Vector2(960, 640)
## How far inside a board's corner a point is.
const BOARD_INSET: float = 8.0
## The player's vitals a run changes, remembered and put back.
const VITALS_FIELDS: Array[StringName] = [
	&"max_health", &"current_health", &"max_madra", &"current_madra",
	&"max_stamina", &"current_stamina", &"health_regen", &"madra_regen", &"stamina_regen",
]

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _view: AdventureView = null
var _map: Dictionary[Vector3i, AdventureEncounter] = {}
var _original_save: SaveGameData = null
var _saved_vitals: Dictionary[StringName, float] = {}
## True once a test moved the real pointer, so after_each puts it back: the zone
## map reads it to hover a hex, and would otherwise find it where it was left.
var _pointer_moved: bool = false

func before_each() -> void:
	# A run's end resumes the zone's idle action and a won fight pays gold, both
	# into the save. Run on a fresh one, never the developer's save in memory.
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_saved_vitals = _remember_vitals()
	_pointer_moved = false
	_map = AdventureMapFixture.build_map()
	var layer := CanvasLayer.new()
	layer.layer = GUT_LAYER + 1
	add_child_autofree(layer)
	_view = AdventureViewScene.instantiate() as AdventureView
	layer.add_child(_view)
	# The project's hex layer script overrides _ready() without super(), so the
	# addon only sets up its cube<->map conversions when the shared TileSet
	# emits `changed`. Re-emit it so every fresh view gets initialised map layers.
	_view.adventure_tilemap.full_map.tile_set.emit_changed()
	await get_tree().process_frame

func after_each() -> void:
	# The boss reveal slows time for a moment; the next test starts at full speed.
	Engine.time_scale = 1.0
	# Ends the run (and the idle action its end resumes) on the fresh save.
	_stop_every_action()
	# AdventureTilemap creates its AdventureMapGenerator node with .new() and
	# never frees it; free it here so these tests don't leave orphans.
	if is_instance_valid(_view) and is_instance_valid(_view.adventure_tilemap.adventure_map_generator):
		_view.adventure_tilemap.adventure_map_generator.free()
	_restore_vitals(_saved_vitals)
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# Binding the developer's save again resumes its idle action. Stop it, so its
	# tick timer does not run on into the next test.
	_stop_every_action()
	if _pointer_moved:
		await _move_pointer_to_window_point(Vector2.ZERO)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Hands out a map it was given in place of a generated one, so that no test
## plays a random map (one can fail its critical-path check).
class FixedMapGenerator extends AdventureMapGenerator:
	var map: Dictionary[Vector3i, AdventureEncounter] = {}

	## Returns the given map.
	func generate_adventure_map() -> Dictionary[Vector3i, AdventureEncounter]:
		return map

## Starts the Shallow Woods on the fixture map the way the zone does once its
## Madra drain ends: the action becomes the current one and the run is confirmed
## with its budget.
func _start_run() -> void:
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var generator := FixedMapGenerator.new()
	generator.map = _map
	tilemap.adventure_map_generator.free()
	tilemap.adventure_map_generator = generator
	var action: AdventureActionData = ADVENTURE_ACTION.duplicate()
	ActionManager._set_current_action(action)
	ActionManager.confirm_adventure_start(action, MADRA_BUDGET)

func _stop_every_action() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func _remember_vitals() -> Dictionary[StringName, float]:
	var saved: Dictionary[StringName, float] = {}
	for field: StringName in VITALS_FIELDS:
		saved[field] = PlayerManager.vitals_manager.get(field)
	return saved

func _restore_vitals(saved: Dictionary[StringName, float]) -> void:
	for field: StringName in saved:
		PlayerManager.vitals_manager.set(field, saved[field])

## Clicks a tile the way the map layer reports a click, then waits for the
## character's first hop to end: the whole walk, for a tile next door.
func _walk_to(coord: Vector3i) -> void:
	AdventureMapFixture.click(_view.adventure_tilemap, coord)
	var arrived: bool = await wait_for_signal(_view.adventure_tilemap.character_body.movement_completed, AdventureMapFixture.HOP_TIMEOUT_SECONDS)
	assert_true(arrived, "the walk to %s ends in time" % coord)

## Moves the real pointer to a point in the viewport, as the player's mouse
## would. The map's hex layers find the hex under a press from the pointer, not
## from the press, so what is meant for the map needs the pointer there.
func _move_pointer_to(point: Vector2) -> void:
	_pointer_moved = true
	await _move_pointer_to_window_point(get_viewport().get_screen_transform() * point)

func _move_pointer_to_window_point(window_point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = window_point
	motion.global_position = window_point
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame

## One tick of the wheel at a point in the viewport's own 1920x1080 space, as the
## mouse sends it: a press, then its release. The headless window is scaled down,
## so the events go in local coordinates.
func _wheel(point: Vector2, button: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = point
		event.global_position = point
		get_viewport().push_input(event, true)

## `ticks` ticks of the wheel in a row.
func _wheel_ticks(point: Vector2, button: MouseButton, ticks: int) -> void:
	for tick: int in ticks:
		_wheel(point, button)

## A left press and its release at a point in the viewport's own space.
func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		get_viewport().push_input(event, true)

func _zoom_controller() -> CameraZoomController:
	return _view.adventure_tilemap.get_node("%CameraZoomController") as CameraZoomController

func _camera() -> Camera2D:
	return _view.adventure_tilemap.get_node("%Camera2D") as Camera2D

## Waits until the controller has eased the camera to its target, and a frame on.
func _wait_for_the_zoom() -> void:
	var controller: CameraZoomController = _zoom_controller()
	var arrived: bool = await wait_until(func() -> bool: return not controller.is_zoom_active(), 3.0)
	assert_true(arrived, "the zoom ends in time")
	await wait_process_frames(2)

## Where a tile's centre is drawn on the screen. The map's viewport fills the
## screen from its top-left corner, unstretched.
func _screen_point_of(coord: Vector3i) -> Vector2:
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	return tilemap.get_global_transform_with_canvas() * tilemap.get_tile_world_centre(coord)

## The cube coordinate of the map cell under a point of the screen.
func _cube_under(point: Vector2) -> Vector3i:
	var layer: HexagonTileMapLayer = _view.adventure_tilemap.visible_map
	return layer.map_to_cube(layer.local_to_map(layer.get_global_transform_with_canvas().affine_inverse() * point))

## The centre of a coin on the screen.
func _coin_centre(coord: Vector3i) -> Vector2:
	var coin: EncounterCoin = (_view.adventure_tilemap.get_node("%AdventureMapMarkers") as AdventureMapMarkers).get_coin(coord)
	return coin.get_global_transform_with_canvas() * (coin.size / 2.0)

func _hover_rim() -> Sprite2D:
	return _view.adventure_tilemap.get_node("%HoverRim") as Sprite2D

func _route() -> AdventureRoute:
	return _view.adventure_tilemap.get_node("%AdventureRoute") as AdventureRoute

## The route dots of the one hop between two neighbouring tiles, as AdventureRoute lays them.
func _dots_between(from: Vector3i, to: Vector3i) -> PackedVector2Array:
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	return ZoneRoute.dot_positions(tilemap.get_tile_world_centre(from), tilemap.get_tile_world_centre(to))

## The three boards that cover the map's container.
func _boards() -> Array[Control]:
	return [_view.vitals_plate, _view.adventure_chest, _view.technique_dock]

#-----------------------------------------------------------------------------
# THE WHEEL OVER THE MAP
#-----------------------------------------------------------------------------

## A wheel over the map zooms it 10% a tick, in to 2 and out to 1 and no further,
## and the current hex stays at (960, 470).
func test_a_wheel_over_the_map_zooms_in_and_out_between_one_and_two() -> void:
	_start_run()
	await wait_process_frames(2)
	var controller: CameraZoomController = _zoom_controller()
	assert_eq(_camera().zoom, Vector2.ONE, "precondition: the map opens at zoom 1")
	await _move_pointer_to(MAP_POINT)

	_wheel(MAP_POINT, MOUSE_BUTTON_WHEEL_UP)
	assert_almost_eq(controller.target_zoom.x, 1.1, 0.0001, "one tick in aims 10% closer")
	_wheel_ticks(MAP_POINT, MOUSE_BUTTON_WHEEL_UP, 12)
	assert_eq(controller.target_zoom, Vector2(2, 2), "the target stops at 2")
	await _wait_for_the_zoom()
	assert_eq(_camera().zoom, Vector2(2, 2), "the camera eases to it and stops")
	assert_lt(_screen_point_of(START).distance_to(Vector2(960, 470)), 0.01, "with the current hex still at (960, 470)")

	_wheel(MAP_POINT, MOUSE_BUTTON_WHEEL_DOWN)
	assert_almost_eq(controller.target_zoom.x, 1.8, 0.0001, "a tick out aims 10% farther")
	_wheel_ticks(MAP_POINT, MOUSE_BUTTON_WHEEL_DOWN, 15)
	assert_eq(controller.target_zoom, Vector2.ONE, "the target stops at 1: the map never goes below it")
	await _wait_for_the_zoom()
	assert_eq(_camera().zoom, Vector2.ONE, "the camera eases back to zoom 1 and stops")
	assert_lt(_screen_point_of(START).distance_to(Vector2(960, 470)), 0.01, "with the current hex still at (960, 470)")

	_wheel(MAP_POINT, MOUSE_BUTTON_WHEEL_DOWN)
	await _wait_for_the_zoom()
	assert_eq(_camera().zoom, Vector2.ONE, "a wheel out at zoom 1 changes nothing")

## No coin takes the wheel: the coins are a screen-space layer over the hexes, and
## a wheel over one zooms the map as it does anywhere else on it.
func test_a_wheel_over_a_coin_zooms_all_the_same() -> void:
	_start_run()
	await wait_process_frames(2)
	var point: Vector2 = _coin_centre(FIGHT)
	var controller: CameraZoomController = _zoom_controller()
	await _move_pointer_to(point)
	watch_signals(controller)

	_wheel(point, MOUSE_BUTTON_WHEEL_UP)

	assert_signal_emitted(controller, "zoom_changed", "a wheel over the coin on FIGHT zooms the map")

## No coin takes a hover or a press either: over a coin the hex under it is
## hovered, and a press on the coin walks to the hex.
func test_the_hex_under_a_coin_is_still_hovered_and_pressed() -> void:
	_start_run()
	await wait_process_frames(2)
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var point: Vector2 = _coin_centre(FIGHT)
	assert_eq(_cube_under(point), FIGHT, "precondition: the coin's centre is over the fight's hex")

	await _move_pointer_to(point)
	assert_true(_hover_rim().visible, "the pointer over a coin hovers the hex under it")
	assert_eq(_hover_rim().position, tilemap.get_tile_world_centre(FIGHT), "on that hex")
	assert_eq(_route().get_dot_positions(), _dots_between(START, FIGHT), "with the route to it")

	_click(point)
	assert_true(tilemap.character_body.is_moving, "a press on the coin walks to its hex")

#-----------------------------------------------------------------------------
# THE WHEEL WHERE THE MAP IS NOT
#-----------------------------------------------------------------------------

## The boards hold the pointer and the map's viewport hears it only through its
## container, so a wheel over the cabinet, the chest or the dock (in the middle
## and near each corner) never reaches the zoom. The same wheel over the map does
## zoom it, so the test could see a zoom if one came.
func test_a_wheel_over_a_board_does_not_zoom() -> void:
	_start_run()
	await wait_process_frames(2)
	var controller: CameraZoomController = _zoom_controller()
	watch_signals(controller)
	var points: Dictionary[String, Vector2] = {}
	for board: Control in _boards():
		var rect: Rect2 = board.get_global_rect()
		points["%s centre" % board.name] = rect.get_center()
		points["%s top left" % board.name] = rect.position + Vector2(BOARD_INSET, BOARD_INSET)
		points["%s bottom right" % board.name] = rect.end - Vector2(BOARD_INSET, BOARD_INSET)
		points["%s top right" % board.name] = Vector2(rect.end.x - BOARD_INSET, rect.position.y + BOARD_INSET)
		points["%s bottom left" % board.name] = Vector2(rect.position.x + BOARD_INSET, rect.end.y - BOARD_INSET)

	for label: String in points:
		await _move_pointer_to(points[label])
		_wheel_ticks(points[label], MOUSE_BUTTON_WHEEL_UP, 2)
		_wheel_ticks(points[label], MOUSE_BUTTON_WHEEL_DOWN, 1)

	await wait_process_frames(3)
	assert_signal_not_emitted(controller, "zoom_changed", "no wheel over a board aimed the zoom anywhere")
	assert_eq(controller.target_zoom, Vector2.ONE, "the target did not move")
	assert_eq(_camera().zoom, Vector2.ONE, "nor did the camera")

	await _move_pointer_to(MAP_POINT)
	_wheel(MAP_POINT, MOUSE_BUTTON_WHEEL_UP)
	assert_signal_emitted(controller, "zoom_changed", "precondition: the same wheel over the map zooms it")

## During a fight the map's view is hidden and the fight's is up, so a wheel over
## where the map was does not zoom the hidden map. Back on the map it zooms again.
func test_a_wheel_during_a_fight_does_not_zoom_the_hidden_map() -> void:
	_start_run()
	await _walk_to(FIGHT)
	_view.adventure_tilemap.select_choice(AdventureMapFixture.fight_choice(_map))
	assert_true(_view.combat_view.visible, "precondition: the fight is on")
	assert_false(_view.tilemap_view.visible, "precondition: the map's view is hidden")
	var controller: CameraZoomController = _zoom_controller()
	watch_signals(controller)
	await _move_pointer_to(MAP_POINT)

	_wheel_ticks(MAP_POINT, MOUSE_BUTTON_WHEEL_UP, 8)
	await wait_process_frames(3)

	assert_signal_not_emitted(controller, "zoom_changed", "a wheel in a fight aims no zoom")
	assert_eq(_camera().zoom, Vector2.ONE, "the hidden map's camera did not move")
	assert_eq(controller.target_zoom, Vector2.ONE, "nor did its target")

	_view.combat.trigger_combat_end.emit(true, 15)
	assert_true(_view.tilemap_view.visible, "precondition: the map is back")
	await wait_process_frames(2)
	_wheel(MAP_POINT, MOUSE_BUTTON_WHEEL_UP)
	assert_signal_emitted(controller, "zoom_changed", "back on the map the wheel zooms it again")

#-----------------------------------------------------------------------------
# THE HOVER UNDER THE WHEEL
#-----------------------------------------------------------------------------

## The zoom moves the hexes under a still pointer, as a walk does (the camera
## follows the character), so the hover is laid again for the cell the pointer
## rests over: the rim and the route follow the pointer, not the hex they were
## first laid on. The pointer rests over FIGHT at zoom 1 and over the player's own
## hex (which has no rim and no route) at zoom 2, and over FIGHT again at 1.
func test_the_hover_follows_the_pointer_as_the_wheel_zooms() -> void:
	_start_run()
	await wait_process_frames(2)
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var point: Vector2 = _screen_point_of(FIGHT) + Vector2(-30, 60)
	assert_eq(_cube_under(point), FIGHT, "precondition: at zoom 1 the pointer rests over FIGHT")
	await _move_pointer_to(point)
	assert_true(_hover_rim().visible, "precondition: it hovers FIGHT")
	assert_eq(_route().get_dot_positions(), _dots_between(START, FIGHT), "precondition: with the route to it")

	_wheel_ticks(point, MOUSE_BUTTON_WHEEL_UP, 12)
	await _wait_for_the_zoom()

	assert_eq(_camera().zoom, Vector2(2, 2), "precondition: the map zoomed to 2")
	assert_eq(_cube_under(point), START, "precondition: the pointer, which did not move, now rests over the player's own hex")
	assert_false(_hover_rim().visible, "so no rim: the hover is laid for the cell under the pointer, not left on FIGHT")
	assert_eq(_route().get_dot_positions().size(), 0, "and no route")

	_wheel_ticks(point, MOUSE_BUTTON_WHEEL_DOWN, 15)
	await _wait_for_the_zoom()

	assert_eq(_camera().zoom, Vector2.ONE, "precondition: back at zoom 1")
	assert_eq(_cube_under(point), FIGHT, "precondition: the pointer rests over FIGHT again")
	assert_true(_hover_rim().visible, "the rim is back")
	assert_eq(_hover_rim().position, tilemap.get_tile_world_centre(FIGHT), "on FIGHT")
	assert_eq(_route().get_dot_positions(), _dots_between(START, FIGHT), "with its route")

## A committed walk keeps its rim and route through a zoom, as it keeps them when
## the pointer leaves the map: they belong to the walk, not to the pointer.
func test_a_committed_walk_keeps_its_rim_and_route_through_a_zoom() -> void:
	_start_run()
	await wait_process_frames(2)
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var over_fight: Vector2 = _screen_point_of(FIGHT)
	await _move_pointer_to(over_fight)
	_click(over_fight)
	assert_true(tilemap.character_body.is_moving, "precondition: the press set the walk off")

	_zoom_controller().set_zoom_level(1.5)
	await wait_process_frames(10)

	assert_true(tilemap.character_body.is_moving, "precondition: the walk is still under way")
	assert_lt(_camera().zoom.x, 1.5, "precondition: and so is the zoom")
	assert_gt(_camera().zoom.x, 1.0, "precondition: which has begun")
	assert_true(_hover_rim().visible, "the walk's rim stays on its destination")
	assert_eq(_hover_rim().position, tilemap.get_tile_world_centre(FIGHT))
	assert_eq(_route().get_dot_positions(), _dots_between(START, FIGHT), "and its route stays laid")
