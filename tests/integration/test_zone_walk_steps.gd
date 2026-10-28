extends GutTest

## The zone map's travel walk moves in 2 screen px steps (lacquer kit §0 and
## §1 rule 6: 328 px in 0.6 s, steps(164)): at the camera's zoom 2 the
## character stands on whole world px on every physics frame of the walk, as
## the idle wander and bob already do.

const ZoneTilemapScene: PackedScene = preload("res://scenes/zones/zone_tilemap/zone_tilemap.tscn")

const TEST_ZONE_ID: String = "TestZone"
const TEST_ZONE_UNLOCK_ID: String = "celestial_intervener_dialogue_1"

var _map: ZoneTilemap

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	# The map sets the current zone on load and travel writes to the save: run
	# on a fresh one, never the developer's save.
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_map = ZoneTilemapScene.instantiate()
	add_child_autofree(_map)
	# A leftover from when the project's hex layer skipped the addon's own set-up:
	# the layer now sets itself up in its own _ready(), so this re-emit of the
	# shared TileSet's `changed` is no longer needed. It is harmless.
	_map.tile_map.tile_set.emit_changed()
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	ZoneManager.set_hidden_zones_visible(false)
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	await get_tree().process_frame

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _zone(zone_id: String) -> ZoneData:
	for zone: ZoneData in ZoneManager.get_map_zones():
		if zone.zone_id == zone_id:
			return zone
	return ZoneManager.get_zone_by_id(zone_id)

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_walk_to_test_zone_stands_on_whole_px() -> void:
	ZoneManager.set_hidden_zones_visible(true)
	UnlockManager.force_unlock_condition(TEST_ZONE_UNLOCK_ID)
	var character: CharacterBody2D = _map.character_body
	var start: Vector2 = character.position
	_map.click_zone(_zone(TEST_ZONE_ID))
	assert_true(_map.is_travelling(), "precondition: the click starts a walk")
	var off_grid: Array[Vector2] = []
	var frames: int = 0
	while _map.is_travelling() and frames < 120:
		await wait_physics_frames(1)
		frames += 1
		if character.position != character.position.round():
			off_grid.append(character.position)
	assert_false(_map.is_travelling(), "precondition: the walk ended")
	assert_gt(frames, 10, "precondition: the walk took a while")
	assert_ne(character.position, start, "precondition: the character moved")
	assert_eq(off_grid.size(), 0, "every frame of the walk on whole world px: %s" % [off_grid])
