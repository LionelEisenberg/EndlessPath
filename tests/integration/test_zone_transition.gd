extends GutTest

## Integration tests for ZoneTransition, the adventure drain (spec: Cultivator
## plate › Lookups; lacquer kit §1 rules 4 and 6). It finds the cultivator
## plate and the zone map by name among its parent's descendants, pours Madra
## pellets from the plate's orb to the character, zooms the map's camera in,
## then confirms the adventure. main_game.tscn is only read, never instanced:
## its SaveTimer would write the real save.

const MAIN_GAME_SCENE_PATH: String = "res://scenes/main/main_game/main_game.tscn"
const ZONE_TILEMAP_SCENE_PATH: String = "res://scenes/zones/zone_tilemap/zone_tilemap.tscn"
const PLATE_SCENE_PATH: String = "res://scenes/zones/cultivator_plate/cultivator_plate.tscn"

const ADVENTURE_ID: String = "shallow_woods_adventure_action"

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
	_pellet_parent = Node2D.new()
	add_child_autofree(_pellet_parent)
	_transition.pellet_parent = _pellet_parent
	await get_tree().process_frame

func _pellet_count() -> int:
	var count: int = 0
	for child: Node in _pellet_parent.get_children():
		if child is MadraPellet:
			count += 1
	return count

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

func test_zone_map_has_the_camera_and_character_the_drain_zooms_to() -> void:
	var paths: Array[String] = _node_paths((load(ZONE_TILEMAP_SCENE_PATH) as PackedScene).get_state())
	assert_has(paths, "./Camera2D", "the zoom looks for a Camera2D right under the map")
	assert_ne(_path_named(paths, "PlayerCharacter"), "", "the pellets fly to the PlayerCharacter")

#-----------------------------------------------------------------------------
# DRAIN
#-----------------------------------------------------------------------------

func test_drain_pours_pellets_then_starts_the_adventure() -> void:
	await _add_transition()
	ResourceManager.set_madra(ResourceManager.get_adventure_madra_capacity())
	var adventure: AdventureActionData = ZoneManager.get_action_by_id(ADVENTURE_ID) as AdventureActionData
	watch_signals(ActionManager)
	ActionManager.adventure_start_requested.emit(adventure)
	assert_true(_transition.is_transitioning())
	assert_eq(_pellet_count(), 1, "the first pellet leaves the orb at once")
	await wait_for_signal(ActionManager.start_adventure, 4.0)
	assert_signal_emitted(ActionManager, "start_adventure", "the drain confirms the adventure")
	assert_false(_transition.is_transitioning())
	assert_almost_eq(ResourceManager.get_madra(), 0.0, 0.01, "the whole budget drained into the pellets")
