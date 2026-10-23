extends GutTest

## How AdventureTilemap draws the map at zoom 1 in the lacquer look (spec: The
## map): the fixed camera, the fog tiers around the tiles the player sees and
## how far the fog reaches, revealed tiles in the forest atlas's veil and
## visited ones in the forest, the current and hover rims, the route dots of a
## hovered or committed walk, the character at 2x with the kit's shadow walking
## in even px, the old layers gone, and the boss reveal's hit-stop. Drives the
## real tilemap scene on the six-tile fixture map (AdventureMapFixture) and
## walks it by clicking tiles, the way the player does.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const AdventureTilemapScene := preload("res://scenes/adventure/adventure_tilemap/adventure_tilemap.tscn")
const AdventureMapFixture := preload("res://tests/integration/adventure_map_fixture.gd")

const CURRENT_RIM_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/map/lacquer_hex_current_ai.png")
const HOVER_RIM_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/map/lacquer_hex_hover_ai.png")
const HOVER_IN_RIM_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/map/lacquer_hex_hover_in_ai.png")
const SHADOW_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/map/lacquer_char_shadow_ai.png")

# The fixture map's tiles (see AdventureMapFixture).
const START := AdventureMapFixture.START
const FIGHT := AdventureMapFixture.FIGHT
const OPEN_NEAR := AdventureMapFixture.OPEN_NEAR
const OPEN_FAR := AdventureMapFixture.OPEN_FAR
const REST := AdventureMapFixture.REST
const BOSS := AdventureMapFixture.BOSS

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _tilemap: AdventureTilemap
var _map: Dictionary[Vector3i, AdventureEncounter] = {}
var _original_save: SaveGameData
var _saved_vitals: Dictionary[StringName, float] = {}

func before_each() -> void:
	# Walking and resolving tiles write to the save. Run on a fresh one, never
	# the developer's save loaded in memory.
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_saved_vitals = AdventureMapFixture.swap_in_known_vitals()
	_map = AdventureMapFixture.build_map()
	_tilemap = AdventureTilemapScene.instantiate()
	add_child_autofree(_tilemap)
	# The project's hex layer script overrides _ready() without super(), so the
	# addon only sets up its cube<->map conversions when the shared TileSet
	# emits `changed`. Re-emit it so this fresh tilemap's map layers are
	# initialised.
	_tilemap.full_map.tile_set.emit_changed()
	await get_tree().process_frame

func after_each() -> void:
	# The boss reveal slows time for a moment; the next test starts at full speed.
	Engine.time_scale = 1.0
	AdventureMapFixture.restore_vitals(_saved_vitals)
	_saved_vitals.clear()
	# AdventureTilemap creates its AdventureMapGenerator node with .new() and
	# never frees it; free it here so these tests don't leave orphans.
	if is_instance_valid(_tilemap) and is_instance_valid(_tilemap.adventure_map_generator):
		_tilemap.adventure_map_generator.free()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# Binding the developer's save again resumes its idle action. Stop it, so its
	# tick timer does not run on into the next test.
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Starts the run on the fixture map.
func _start() -> void:
	_tilemap.start_adventure_on_map(AdventureMapFixture.ADVENTURE_ACTION, _map)

## Clicks a tile the way the map layer reports a click: with the tile's map cell.
func _click(coord: Vector3i) -> void:
	AdventureMapFixture.click(_tilemap, coord)

## Hovers a tile the way the map layer reports it: with the tile's map cell.
func _hover(coord: Vector3i) -> void:
	_tilemap.visible_map.tile_hovered.emit(_tilemap.visible_map.cube_to_map(coord))

## Clicks a tile, then waits for the character to end its first hop: the whole
## walk, for a tile next door.
func _walk_to(coord: Vector3i) -> void:
	_click(coord)
	await _wait_for_hop(coord)

## Waits for the character to end the hop it is on.
func _wait_for_hop(toward: Vector3i) -> void:
	var arrived: bool = await wait_for_signal(_tilemap.character_body.movement_completed, AdventureMapFixture.HOP_TIMEOUT_SECONDS)
	assert_true(arrived, "a hop of the walk to %s ends in time" % toward)

## The tilemap's node by its unique name, or null when the scene has none.
func _node(unique_name: String) -> Node:
	return _tilemap.get_node_or_null("%" + unique_name)

func _route() -> AdventureRoute:
	return _node("AdventureRoute") as AdventureRoute

## The tile's centre in the tilemap's space, where the rims and the route are.
func _centre(coord: Vector3i) -> Vector2:
	return _tilemap.get_tile_world_centre(coord)

## The route dots from tile to tile, hop by hop, as AdventureRoute lays them.
func _dots_through(coords: Array[Vector3i]) -> PackedVector2Array:
	var dots := PackedVector2Array()
	for index: int in range(1, coords.size()):
		dots.append_array(ZoneRoute.dot_positions(_centre(coords[index - 1]), _centre(coords[index])))
	return dots

func _is_even(value: float) -> bool:
	return is_equal_approx(fposmod(value, 2.0), 0.0)

#-----------------------------------------------------------------------------
# CAMERA
#-----------------------------------------------------------------------------

func test_camera_is_fixed_at_zoom_one() -> void:
	var camera := _tilemap.character_body.get_node_or_null("Camera2D") as Camera2D
	assert_not_null(camera, "the camera follows the character")
	if camera == null:
		return
	assert_eq(camera.zoom, Vector2.ONE, "zoom 1: the tiles at their art size")
	assert_eq(camera.offset, Vector2(0, 70), "the current hex's centre at screen (960, 470)")
	assert_eq(camera.offset, AdventureTilemap.CAMERA_OFFSET)
	var has_zoom_controller: bool = false
	var has_clamp_controller: bool = false
	for child: Node in camera.get_children():
		has_zoom_controller = has_zoom_controller or child is CameraZoomController
		has_clamp_controller = has_clamp_controller or child is CameraClampController
	assert_false(has_zoom_controller, "no wheel zoom on the adventure map")
	assert_true(has_clamp_controller, "the clamp controller stays (inert without boundaries)")

#-----------------------------------------------------------------------------
# FOG
#-----------------------------------------------------------------------------

func test_fog_tiers_around_seen_tiles() -> void:
	_start()

	# From START the player sees START (visited) and FIGHT, OPEN_NEAR and REST
	# (revealed). (2, -1, -1) touches FIGHT and is two from START, so its tier
	# comes from a revealed tile.
	assert_eq(_tilemap.get_fog_tier_at(Vector3i(2, -1, -1)), 1, "next to a revealed tile: tier 1")
	assert_eq(_tilemap.get_fog_tier_at(Vector3i(3, -2, -1)), 2, "two from the nearest seen tile: tier 2")
	assert_eq(_tilemap.get_fog_tier_at(Vector3i(6, -6, 0)), 3, "far from every seen tile: tier 3")
	assert_eq(_tilemap.get_fog_tier_at(BOSS), 1, "a map tile not yet in view is fog like any other")
	for seen: Vector3i in [START, FIGHT, OPEN_NEAR, REST]:
		assert_eq(_tilemap.get_fog_tier_at(seen), -1, "no fog on the seen tile %s" % seen)

func test_fog_lifts_as_tiles_come_into_view() -> void:
	_start()
	assert_eq(_tilemap.get_fog_tier_at(OPEN_FAR), 1, "precondition: OPEN_FAR is fog from START")

	await _walk_to(OPEN_NEAR)

	assert_eq(_tilemap.get_fog_tier_at(OPEN_FAR), -1, "the arrival next to it reveals it, and the fog is redrawn")

func test_fog_reaches_past_the_map() -> void:
	_start()
	var reach: int = AdventureMapFixture.ADVENTURE_ACTION.adventure_data.max_distance_from_start + AdventureTilemap.FOG_MARGIN
	assert_eq(AdventureTilemap.FOG_MARGIN, 8)

	assert_ne(_tilemap.get_fog_tier_at(Vector3i(reach, -reach, 0)), -1, "fog %d tiles out" % reach)
	assert_ne(_tilemap.get_fog_tier_at(Vector3i(-reach, 0, reach)), -1, "fog %d tiles out the other way" % reach)
	assert_eq(_tilemap.get_fog_tier_at(Vector3i(reach + 1, -(reach + 1), 0)), -1, "no fog past the margin")

func test_stop_leaves_no_fog_rims_or_route() -> void:
	_start()
	_hover(FIGHT)

	_tilemap.stop_adventure()

	assert_eq(_tilemap.get_fog_tier_at(Vector3i(2, -1, -1)), -1, "the fog is gone")
	assert_eq(_tilemap.get_fog_tier_at(BOSS), -1, "everywhere")
	var current_rim := _node("CurrentRim") as Sprite2D
	var hover_rim := _node("HoverRim") as Sprite2D
	assert_not_null(current_rim)
	assert_not_null(hover_rim)
	assert_not_null(_route())
	if current_rim == null or hover_rim == null or _route() == null:
		return
	assert_false(current_rim.visible, "no current rim without a run")
	assert_false(hover_rim.visible, "no hover rim without a run")
	assert_eq(_route().get_dot_positions().size(), 0, "no route without a run")

#-----------------------------------------------------------------------------
# TILES
#-----------------------------------------------------------------------------

func test_revealed_tile_uses_the_veil_source() -> void:
	_start()
	var cell: Vector2i = _tilemap.visible_map.cube_to_map(FIGHT)

	assert_eq(_tilemap.visible_map.get_cell_source_id(cell), AdventureTilemap.VEIL_ATLAS_SOURCE_ID, "the veil atlas")
	assert_eq(AdventureTilemap.VEIL_ATLAS_SOURCE_ID, 9)
	assert_eq(_tilemap.visible_map.get_cell_atlas_coords(cell), HexForestAtlas.pick(FIGHT), "at the forest variant's coordinates")

func test_visited_tile_uses_the_forest_source() -> void:
	_start()
	await _walk_to(OPEN_NEAR)

	for visited: Vector3i in [START, OPEN_NEAR]:
		var cell: Vector2i = _tilemap.visible_map.cube_to_map(visited)
		assert_eq(_tilemap.visible_map.get_cell_source_id(cell), AdventureTilemap.FOREST_ATLAS_SOURCE_ID, "%s: the forest atlas" % visited)
		assert_eq(_tilemap.visible_map.get_cell_atlas_coords(cell), HexForestAtlas.pick(visited), "%s: its variant" % visited)

## The dev panel's Show Whole Map draws every map tile in the forest, a revealed
## one too (as its veil used to lift), and takes the fog off them; turned off,
## the map is back to what the player sees.
func test_dev_reveal_shows_the_whole_map_and_back() -> void:
	_start()
	var fight_cell: Vector2i = _tilemap.visible_map.cube_to_map(FIGHT)
	var boss_cell: Vector2i = _tilemap.visible_map.cube_to_map(BOSS)

	_tilemap.set_dev_reveal_all(true)

	assert_eq(_tilemap.visible_map.get_cell_source_id(fight_cell), AdventureTilemap.FOREST_ATLAS_SOURCE_ID, "a revealed tile in the forest")
	assert_eq(_tilemap.visible_map.get_cell_source_id(boss_cell), AdventureTilemap.FOREST_ATLAS_SOURCE_ID, "an unseen tile in the forest")
	assert_eq(_tilemap.get_fog_tier_at(BOSS), -1, "no fog on a map tile")
	assert_eq(_tilemap.get_fog_tier_at(Vector3i(3, -3, 0)), 1, "the fog counts its tiers from every map tile")

	_tilemap.set_dev_reveal_all(false)

	assert_eq(_tilemap.visible_map.get_cell_source_id(fight_cell), AdventureTilemap.VEIL_ATLAS_SOURCE_ID, "the revealed tile veiled again")
	assert_eq(_tilemap.visible_map.get_cell_source_id(boss_cell), -1, "the unseen tile gone from the map layer")
	assert_eq(_tilemap.get_fog_tier_at(BOSS), 1, "and under the fog again")
	assert_eq(_tilemap.get_fog_tier_at(Vector3i(3, -3, 0)), 2, "two from the nearest tile the player sees")

#-----------------------------------------------------------------------------
# RIMS
#-----------------------------------------------------------------------------

func test_current_rim_follows_the_player() -> void:
	var rim := _node("CurrentRim") as Sprite2D
	assert_not_null(rim, "the map has a current rim")
	if rim == null:
		return
	_start()
	assert_true(rim.visible, "shown once the run starts")
	assert_eq(rim.texture, CURRENT_RIM_TEXTURE, "the brass rim with its lacquer collar")
	assert_eq(rim.position, _centre(START), "on the start tile")

	await _walk_to(OPEN_NEAR)

	assert_eq(rim.position, _centre(_tilemap.get_current_tile()), "on the tile the player stands on")
	assert_eq(_tilemap.get_current_tile(), OPEN_NEAR, "precondition: the walk arrived")

func test_hover_rims() -> void:
	var rim := _node("HoverRim") as Sprite2D
	assert_not_null(rim, "the map has a hover rim")
	if rim == null:
		return
	_start()
	await _walk_to(OPEN_NEAR)

	_hover(START)
	assert_true(rim.visible, "over a visited tile")
	assert_eq(rim.texture, HOVER_RIM_TEXTURE, "a visited tile gets the bright rim")
	assert_eq(rim.position, _centre(START))

	_hover(FIGHT)
	assert_true(rim.visible, "over a revealed tile")
	assert_eq(rim.texture, HOVER_IN_RIM_TEXTURE, "a revealed tile gets the inner rim, inside its veil's dotted one")
	assert_eq(rim.position, _centre(FIGHT))

	_hover(BOSS)
	assert_false(rim.visible, "hidden over fog")

	_hover(FIGHT)
	_hover(OPEN_NEAR)
	assert_false(rim.visible, "hidden over the current tile")

	_hover(FIGHT)
	_tilemap.visible_map.tile_unhovered.emit()
	assert_false(rim.visible, "hidden off the map")

	await _walk_to(REST)
	_hover(START)
	assert_false(rim.visible, "hidden while a choice waits on the tile")

#-----------------------------------------------------------------------------
# ROUTE
#-----------------------------------------------------------------------------

func test_hover_shows_the_route() -> void:
	var route := _route()
	assert_not_null(route, "the map has a route")
	if route == null:
		return
	_start()
	await _walk_to(OPEN_NEAR)

	_hover(FIGHT)

	var through_start: Array[Vector3i] = [OPEN_NEAR, START, FIGHT]
	assert_eq(route.get_dot_positions(), _dots_through(through_start), "the route runs through the start: two hops' dots")
	assert_eq(route.get_visible_dot_count(), 12)

	_hover(BOSS)
	assert_eq(route.get_dot_positions().size(), 0, "no route into fog")

func test_committed_route_walks_with_the_player() -> void:
	var route := _route()
	var rim := _node("HoverRim") as Sprite2D
	assert_not_null(route, "the map has a route")
	assert_not_null(rim, "the map has a hover rim")
	if route == null or rim == null:
		return
	_start()
	await _walk_to(OPEN_NEAR)

	# Two hops to FIGHT, through the start.
	_click(FIGHT)
	var whole_walk: Array[Vector3i] = [OPEN_NEAR, START, FIGHT]
	assert_eq(route.get_dot_positions(), _dots_through(whole_walk), "the click commits the route")
	_hover(REST)
	assert_eq(route.get_dot_positions(), _dots_through(whole_walk), "hovering mid-walk leaves the route alone")
	assert_eq(rim.position, _centre(FIGHT), "the hover rim stays on the destination")
	assert_true(rim.visible)

	# A third of a second in, the character is about 70 px into the 164 px
	# hop (210 px/s with a hop queued behind it), past its first two dots.
	await wait_physics_frames(20)
	assert_lt(route.get_visible_dot_count(), 12, "the dots the character has passed hide")
	assert_gt(route.get_visible_dot_count(), 6, "only dots of the hop it is on")

	await _wait_for_hop(FIGHT)
	var rest_of_walk: Array[Vector3i] = [START, FIGHT]
	assert_eq(route.get_dot_positions(), _dots_through(rest_of_walk), "partway, the route runs on from the tile reached")

	await _wait_for_hop(FIGHT)
	assert_eq(_tilemap.get_current_tile(), FIGHT, "precondition: the walk arrived")
	assert_eq(route.get_dot_positions().size(), 0, "arrival clears the route")
	assert_false(rim.visible, "the rim on the destination goes once it is the current tile")

func test_stamina_stop_clears_the_route() -> void:
	var route := _route()
	assert_not_null(route, "the map has a route")
	if route == null:
		return
	_start()
	await _walk_to(OPEN_NEAR)
	PlayerManager.vitals_manager.current_stamina = AdventureTilemap.MOVEMENT_STAMINA_COST

	# One step's worth of Stamina pays for the first of the two hops only.
	_click(FIGHT)
	await _wait_for_hop(FIGHT)

	assert_eq(_tilemap.get_current_tile(), START, "precondition: the walk stopped partway")
	assert_eq(route.get_dot_positions().size(), 0, "a walk stopped for Stamina leaves no route")

#-----------------------------------------------------------------------------
# CHARACTER
#-----------------------------------------------------------------------------

func test_character_is_drawn_at_2x_with_the_kit_shadow() -> void:
	var character: CharacterBody2D = _tilemap.character_body
	assert_eq(character.scale, Vector2(2, 2), "32x48 on screen at zoom 1")
	var shadow := _node("CharacterShadow") as Sprite2D
	assert_not_null(shadow, "the character has the kit's shadow")
	if shadow == null:
		return
	assert_eq(shadow.get_parent(), character, "the shadow moves and scales with the character")
	assert_eq(shadow.texture, SHADOW_TEXTURE)
	assert_eq(shadow.position, Vector2(-6, 8), "under the feet, as on the zone map")
	assert_false(shadow.centered, "placed by its top-left")
	assert_eq(shadow.z_index, -1, "drawn under the character")

func test_walk_moves_in_even_px() -> void:
	_start()
	var character: CharacterBody2D = _tilemap.character_body
	var start: Vector2 = character.position

	_click(OPEN_NEAR)
	assert_true(character.is_moving, "precondition: the click starts a walk")
	var off_grid: Array[Vector2] = []
	var frames: int = 0
	while character.is_moving and frames < 180:
		await wait_physics_frames(1)
		frames += 1
		if character.is_moving and not (_is_even(character.position.x) and _is_even(character.position.y)):
			off_grid.append(character.position)

	assert_false(character.is_moving, "precondition: the walk ended")
	assert_gt(frames, 10, "precondition: the walk took a while")
	assert_ne(character.position, start, "precondition: the character moved")
	assert_eq(off_grid.size(), 0, "every frame of the walk on even px: %s" % [off_grid])
	assert_eq(character.position, _centre(OPEN_NEAR), "the walk ends on the tile's centre")

#-----------------------------------------------------------------------------
# REMOVED LAYERS
#-----------------------------------------------------------------------------

func test_old_map_layers_are_gone() -> void:
	for node_name: String in ["FogLayer", "FogVeilContainer", "HoverSelector", "PathPreview", "Atmosphere", "BossFlashLayer", "AdventureHighlightMap"]:
		assert_null(_tilemap.find_child(node_name, true, false), "%s is gone" % node_name)

#-----------------------------------------------------------------------------
# BOSS REVEAL
#-----------------------------------------------------------------------------

func test_boss_reveal_keeps_the_hit_stop() -> void:
	_start()
	watch_signals(_tilemap)

	await _walk_to(FIGHT)

	assert_signal_emitted(_tilemap, "boss_revealed", "precondition: visiting FIGHT reveals the boss")
	assert_eq(Engine.time_scale, 0.25, "time slows right after the reveal")
	# 0.3 s of real time, whatever the time scale.
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0, "and runs at full speed again 0.3 s later")

## The reveal's camera push eases toward the boss and back while the player
## walks on, and leaves the camera on the character, at its offset.
func test_boss_push_returns_the_camera_to_its_offset() -> void:
	var camera := _tilemap.character_body.get_node_or_null("Camera2D") as Camera2D
	assert_not_null(camera, "the camera follows the character")
	if camera == null:
		return
	_start()
	watch_signals(_tilemap)
	await _walk_to(FIGHT)
	assert_signal_emitted(_tilemap, "boss_revealed", "precondition: visiting FIGHT reveals the boss")

	# Win the fight at once and walk back to the start while the push runs.
	_tilemap.select_choice(AdventureMapFixture.fight_choice(_map))
	_tilemap.handle_combat_result(true, 0)
	_click(START)
	assert_true(_tilemap.character_body.is_moving, "precondition: the walk goes on during the push")
	await get_tree().create_timer(0.3, true, false, true).timeout
	var view_from_character: Vector2 = camera.global_position + camera.offset - _tilemap.character_body.global_position
	assert_gt(view_from_character.distance_to(AdventureTilemap.CAMERA_OFFSET), 10.0, "precondition: mid-push, the view has moved toward the boss")
	await _wait_for_hop(START)

	# The push takes 1.2 s of game time, its first 0.15 s of real time at a
	# quarter speed (the hit-stop): over about 1.3 s after the reveal.
	await get_tree().create_timer(0.5, true, false, true).timeout
	assert_eq(_tilemap.get_current_tile(), START, "precondition: the walk went on to the start")
	assert_eq(camera.offset, AdventureTilemap.CAMERA_OFFSET, "the push ends on the camera's own offset")
	assert_eq(camera.position, Vector2.ZERO, "and the camera still sits on the character")

## A run that stops mid-push leaves the camera on its offset, and the push
## does not carry on afterwards.
func test_stop_mid_push_puts_the_camera_back() -> void:
	var camera := _tilemap.character_body.get_node_or_null("Camera2D") as Camera2D
	assert_not_null(camera, "the camera follows the character")
	if camera == null:
		return
	_start()
	await _walk_to(FIGHT)
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_ne(camera.offset, AdventureTilemap.CAMERA_OFFSET, "precondition: the push is under way")

	_tilemap.stop_adventure()

	assert_eq(camera.offset, AdventureTilemap.CAMERA_OFFSET, "the stop puts the camera back on its offset at once")
	await get_tree().create_timer(1.0, true, false, true).timeout
	assert_eq(camera.offset, AdventureTilemap.CAMERA_OFFSET, "and the push does not carry on")
	assert_eq(camera.position, Vector2.ZERO, "the camera still sits on the character")
