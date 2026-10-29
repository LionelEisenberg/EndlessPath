extends GutTest

## Integration tests for ZoneTransition, the adventure drain (spec: Cultivator
## plate › Lookups; lacquer kit §1 rules 4 and 6). It finds the cultivator
## plate and the zone map by name among its parent's descendants, pours the
## Madra budget out as pellets on its own clock, then confirms the adventure.
## The map's camera holds still from the push until the way back has put it
## back. main_game.tscn is only read, never instanced: the scenes it needs are
## built on their own instead.
## The drain and the pellets are taken off the frame clock and stepped by hand
## a frame at a time with the zoom's tween, so no check depends on how long
## real frames take.

const MAIN_GAME_SCENE_PATH: String = "res://scenes/main/main_game/main_game.tscn"
const ZONE_TILEMAP_SCENE_PATH: String = "res://scenes/zones/zone_tilemap/zone_tilemap.tscn"
const PLATE_SCENE_PATH: String = "res://scenes/zones/cultivator_plate/cultivator_plate.tscn"

const ADVENTURE_ID: String = "shallow_woods_adventure_action"

const FRAME: float = 1.0 / 60.0
## More frames than a full drain and zoom take (about 2.1 s).
const MAX_FRAMES: int = 300

var _transition: ZoneTransition = null
var _pellet_parent: Node2D = null

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	_transition = null
	_pellet_parent = null
	# Pellets in flight and the camera tween end with the nodes; let them go
	# before GUT counts orphans.
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

## The zone view's drain set up as main_game.tscn has it: ZoneTransition beside
## the cultivator plate and the zone map, all under one parent.
func _add_transition() -> void:
	var zone_view := Control.new()
	zone_view.size = ZoneMapMath.VIEWPORT_SIZE
	add_child_autofree(zone_view)
	var map: ZoneTilemap = (load(ZONE_TILEMAP_SCENE_PATH) as PackedScene).instantiate()
	map.name = "ZoneTilemap"
	zone_view.add_child(map)
	map.tile_map.tile_set.emit_changed()
	var plate: CultivatorPlate = (load(PLATE_SCENE_PATH) as PackedScene).instantiate()
	plate.name = "CultivatorPlate"
	zone_view.add_child(plate)
	_transition = ZoneTransition.new()
	zone_view.add_child(_transition)
	_transition.set_process(false)
	_pellet_parent = Node2D.new()
	_pellet_parent.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(_pellet_parent)
	_transition.pellet_parent = _pellet_parent
	await get_tree().process_frame

func _pellet_count() -> int:
	var count: int = 0
	for child: Node in _pellet_parent.get_children():
		if child is LacquerPellet:
			count += 1
	return count

## One frame stepped by hand, in the tree's order: the drain (it sends
## pellets), the pellets (they fly), then the tweens (the zoom).
func _step_frame(delta: float = FRAME) -> void:
	simulate(_transition, 1, delta)
	simulate(_pellet_parent, 1, delta)
	for tween: Tween in get_tree().get_processed_tweens():
		if tween.is_valid() and tween.is_running():
			tween.custom_step(delta)

## Starts the drain on a full adventure budget.
func _start_drain() -> void:
	ResourceManager.set_madra(ResourceManager.get_adventure_madra_capacity())
	var adventure: AdventureActionData = ZoneManager.get_action_by_id(ADVENTURE_ID) as AdventureActionData
	ActionManager.adventure_start_requested.emit(adventure)

## Steps 60 FPS frames until the drain and the zoom are over and the
## adventure is confirmed, or MAX_FRAMES go by.
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

func test_main_game_puts_the_plate_and_map_beside_the_transition() -> void:
	var paths: Array[String] = _node_paths((load(MAIN_GAME_SCENE_PATH) as PackedScene).get_state())
	var transition_path: String = _path_named(paths, "ZoneTransition")
	assert_ne(transition_path, "", "main_game.tscn has a ZoneTransition")
	var parent_path: String = transition_path.get_base_dir()
	var plate_path: String = _path_named(paths, "CultivatorPlate")
	var map_path: String = _path_named(paths, "ZoneTilemap")
	assert_true(plate_path.begins_with(parent_path + "/"),
		"the drain finds CultivatorPlate under its parent (%s), not at %s" % [parent_path, plate_path])
	assert_true(map_path.begins_with(parent_path + "/"),
		"the drain finds ZoneTilemap under its parent (%s), not at %s" % [parent_path, map_path])

#-----------------------------------------------------------------------------
# DRAIN
#-----------------------------------------------------------------------------

func test_drain_pours_pellets_then_starts_the_adventure() -> void:
	await _add_transition()
	watch_signals(ActionManager)
	_start_drain()
	assert_true(_transition.is_transitioning())
	assert_eq(_pellet_count(), 1, "the first pellet leaves the orb at once")
	_run_to_the_end()
	assert_signal_emitted(ActionManager, "start_adventure", "the drain confirms the adventure")
	assert_false(_transition.is_transitioning())
	assert_almost_eq(ResourceManager.get_madra(), 0.0, 0.01, "the whole budget drained into the pellets")

## 0.3 s in, the pellets due at 0, 0.04, ... 0.28 s have left (none has landed:
## each flies 0.6 s), however long the frames are.
func test_drain_sends_its_pellets_on_time_at_10_fps() -> void:
	await _add_transition()
	_start_drain()
	for _frame: int in 3:
		_step_frame(0.1)
	assert_eq(_pellet_count(), 8, "eight pellets in 0.3 s of 0.1 s frames")

func test_the_map_camera_holds_from_the_zoom_until_the_way_back_ends() -> void:
	await _add_transition()
	_start_drain()
	assert_true(_map_camera_is_free(), "the drain leaves the camera alone")
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
	_start_drain()
	_run_to_the_end()
	_transition.reset_camera()
	_step_frame()
	assert_ne(_camera().zoom, start_zoom, "precondition: the way back is under way")
	_transition.settle_camera()
	assert_eq(_camera().zoom, start_zoom, "back at the zoom the player left, at once")
	assert_eq(_camera().position, start_position, "and the position")
	assert_true(_map_camera_is_free(), "and the camera let go")
