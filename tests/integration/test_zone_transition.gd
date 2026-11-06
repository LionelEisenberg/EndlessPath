extends GutTest

## Integration tests for ZoneTransition, the zoom into the character that
## starts an adventure. It finds the zone map by name among its parent's
## descendants, zooms, then confirms the adventure. Starting spends nothing and
## sends no pellets: the run plays on the saved pool. The map's camera holds
## still from the push until the way back has put it back. main_game.tscn is
## only read, never instanced: the scenes it needs are built on their own
## instead. The zoom's tween is stepped by hand a frame at a time, so no check
## depends on how long real frames take.

const MAIN_GAME_SCENE_PATH: String = "res://scenes/main/main_game/main_game.tscn"
const ZONE_TILEMAP_SCENE_PATH: String = "res://scenes/zones/zone_tilemap/zone_tilemap.tscn"

const ADVENTURE_ID: String = "shallow_woods_adventure_action"

const FRAME: float = 1.0 / 60.0
## More frames than the zoom takes (0.5 s).
const MAX_FRAMES: int = 300

var _transition: ZoneTransition = null

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	_transition = null
	# The camera tween ends with the nodes; let it go before GUT counts orphans.
	await get_tree().process_frame

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Each node's path in the scene's own tree ("." is the root), by index.
func _node_paths(state: SceneState) -> Array[String]:
	var paths: Array[String] = []
	for index: int in state.get_node_count():
		paths.append(str(state.get_node_path(index)))
	return paths

## The path of the node named `node_name` among `paths`, or "".
func _path_named(paths: Array[String], node_name: String) -> String:
	for path: String in paths:
		if path.get_file() == node_name:
			return path
	return ""

## The zone view's transition set up as main_game.tscn has it: ZoneTransition
## beside the zone map, under one parent.
func _add_transition() -> void:
	var zone_view := Control.new()
	zone_view.size = ZoneMapMath.VIEWPORT_SIZE
	add_child_autofree(zone_view)
	var map: ZoneTilemap = (load(ZONE_TILEMAP_SCENE_PATH) as PackedScene).instantiate()
	map.name = "ZoneTilemap"
	zone_view.add_child(map)
	map.tile_map.tile_set.emit_changed()
	_transition = ZoneTransition.new()
	zone_view.add_child(_transition)
	await get_tree().process_frame

## One frame of the zoom's tween, stepped by hand.
func _step_frame(delta: float = FRAME) -> void:
	for tween: Tween in get_tree().get_processed_tweens():
		if tween.is_valid() and tween.is_running():
			tween.custom_step(delta)

## Requests the Shallow Woods' start on a full pool.
func _start_transition() -> void:
	ResourceManager.set_madra(ResourceManager.get_max_madra())
	var adventure: AdventureActionData = ZoneManager.get_action_by_id(ADVENTURE_ID) as AdventureActionData
	ActionManager.adventure_start_requested.emit(adventure)

## Steps 60 FPS frames until the zoom is over and the adventure is confirmed,
## or MAX_FRAMES go by.
func _run_to_the_end() -> void:
	for _frame: int in MAX_FRAMES:
		if not _transition.is_transitioning():
			return
		_step_frame()

func _map() -> ZoneTilemap:
	return _transition.get_parent().find_child("ZoneTilemap", true, false) as ZoneTilemap

## Whether the map's camera is free to move on its own: its zoom controller
## works only while ZoneTilemap.hold_camera() lets it.
func _map_camera_is_free() -> bool:
	return (_map().get_node("%CameraZoomController") as CameraZoomController).enabled

func _camera() -> Camera2D:
	return _map().get_camera()

#-----------------------------------------------------------------------------
# LOOKUPS
#-----------------------------------------------------------------------------

func test_main_game_puts_the_map_beside_the_transition() -> void:
	var paths: Array[String] = _node_paths((load(MAIN_GAME_SCENE_PATH) as PackedScene).get_state())
	var transition_path: String = _path_named(paths, "ZoneTransition")
	assert_ne(transition_path, "", "main_game.tscn has a ZoneTransition")
	var parent_path: String = transition_path.get_base_dir()
	var map_path: String = _path_named(paths, "ZoneTilemap")
	assert_true(map_path.begins_with(parent_path + "/"),
		"the transition finds ZoneTilemap under its parent (%s), not at %s" % [parent_path, map_path])

#-----------------------------------------------------------------------------
# START
#-----------------------------------------------------------------------------

func test_the_start_zooms_then_starts_the_adventure_spending_nothing() -> void:
	await _add_transition()
	watch_signals(ActionManager)
	_start_transition()
	assert_true(_transition.is_transitioning(), "the zoom is under way")
	assert_signal_not_emitted(ActionManager, "start_adventure", "the adventure waits for the zoom")
	_run_to_the_end()
	assert_signal_emitted_with_parameters(ActionManager, "start_adventure", [ZoneManager.get_action_by_id(ADVENTURE_ID)])
	assert_false(_transition.is_transitioning())
	assert_eq(ResourceManager.get_madra(), ResourceManager.get_max_madra(), "starting spends nothing: the run spends from the pool")

func test_the_map_camera_holds_from_the_zoom_until_the_way_back_ends() -> void:
	await _add_transition()
	assert_true(_map_camera_is_free(), "precondition: the camera is free before the start")
	_start_transition()
	assert_false(_map_camera_is_free(), "the camera holds still from the zoom's start")
	_run_to_the_end()
	assert_false(_map_camera_is_free(), "the camera holds still through the zoom and the adventure")
	_transition.reset_camera()
	_step_frame()
	assert_false(_map_camera_is_free(), "and through the way back")
	for _frame: int in 30:
		_step_frame()
	assert_true(_map_camera_is_free(), "the end of the way back lets it go")

func test_settle_camera_ends_the_way_back_at_once() -> void:
	await _add_transition()
	var start_zoom: Vector2 = _camera().zoom
	var start_position: Vector2 = _camera().position
	_start_transition()
	_run_to_the_end()
	_transition.reset_camera()
	_step_frame()
	assert_ne(_camera().zoom, start_zoom, "precondition: the way back is under way")
	_transition.settle_camera()
	assert_eq(_camera().zoom, start_zoom, "back at the zoom the player left, at once")
	assert_eq(_camera().position, start_position, "and the position")
	assert_true(_map_camera_is_free(), "and the camera let go")
