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

const CURRENT_RIM_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/map/lacquer_hex_current_heavy_ai.png")
## The zone map's current rim, which the adventure's replaces.
const ZONE_CURRENT_RIM_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/map/lacquer_hex_current_ai.png")
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

func test_camera_opens_at_zoom_one_and_zooms_from_one_to_two() -> void:
	var camera := _tilemap.character_body.get_node_or_null("Camera2D") as Camera2D
	assert_not_null(camera, "the camera follows the character")
	if camera == null:
		return
	assert_eq(camera.zoom, Vector2.ONE, "zoom 1: the tiles at their art size, today's density")
	assert_eq(camera.offset, Vector2(0, 70), "the current hex's centre at screen (960, 470)")
	assert_eq(camera.offset, AdventureTilemap.CAMERA_OFFSET)
	var zoom_controller: CameraZoomController = null
	var clamp_controller: CameraClampController = null
	for child: Node in camera.get_children():
		if child is CameraZoomController:
			zoom_controller = child
		elif child is CameraClampController:
			clamp_controller = child
	assert_not_null(zoom_controller, "the wheel zooms the map, as it zooms the zone map")
	assert_not_null(clamp_controller, "the clamp controller stays")
	if zoom_controller != null:
		assert_same(_node("CameraZoomController"), zoom_controller, "found by its unique name")
		assert_eq(zoom_controller.zoom_min, 1.0, "never below 1: the 1x map art loses its 1 px lines")
		assert_eq(zoom_controller.zoom_max, 2.0, "to 2, as the zone map")
		assert_eq(zoom_controller.zoom_default, 1.0, "and the adventure opens at today's density")
		assert_eq(zoom_controller.target_zoom, Vector2.ONE, "so it is aimed at zoom 1 to begin with")
	if clamp_controller != null:
		assert_false(clamp_controller.use_boundaries, "inert: the camera follows the character, which never leaves the map")

## The camera's offset is in world px, so what it moves the view by on screen is
## the offset times the zoom: 70 px at every zoom keeps the current hex's centre
## at screen (960, 470).
func test_the_camera_offset_for_a_zoom_keeps_the_hex_at_the_same_screen_px() -> void:
	assert_eq(AdventureTilemap.camera_offset_for(1.0), Vector2(0, 70), "zoom 1: as it has always been")
	assert_eq(AdventureTilemap.camera_offset_for(2.0), Vector2(0, 35), "zoom 2: half the world px")
	for zoom: float in [1.0, 1.1, 1.331, 1.5, 1.77, 2.0]:
		var screen_shift: Vector2 = AdventureTilemap.camera_offset_for(zoom) * zoom
		assert_almost_eq(screen_shift.x, 0.0, 0.0001, "zoom %s: no sideways shift" % zoom)
		assert_almost_eq(screen_shift.y, 70.0, 0.0001, "zoom %s: 70 screen px" % zoom)

#-----------------------------------------------------------------------------
# ZOOM
#-----------------------------------------------------------------------------

## Where the tile's centre is on screen: its world centre through the map's canvas
## transform, which carries the camera's position, offset and zoom.
func _screen_centre(coord: Vector3i) -> Vector2:
	return _tilemap.get_global_transform_with_canvas() * _centre(coord)

## Where the current hex's centre belongs: 70 px above the screen's centre.
func _hex_home() -> Vector2:
	return get_viewport().get_visible_rect().size / 2.0 - Vector2(0, 70)

func _zoom_controller() -> CameraZoomController:
	return _node("CameraZoomController") as CameraZoomController

func _camera() -> Camera2D:
	return _tilemap.character_body.get_node("Camera2D") as Camera2D

## Zooms the map to the level the way the wheel does (through the zoom
## controller) and waits until the camera has got there.
func _zoom_to(level: float) -> void:
	var controller: CameraZoomController = _zoom_controller()
	controller.set_zoom_level(level)
	var arrived: bool = await wait_until(func() -> bool: return not controller.is_zoom_active(), 3.0)
	assert_true(arrived, "the zoom to %s ends in time" % level)
	# A frame on, so that what follows the camera (the coins) has caught up.
	await wait_process_frames(2)

func test_the_current_hex_stays_where_it_is_at_every_zoom() -> void:
	_start()
	await wait_process_frames(2)
	assert_eq(_screen_centre(START), _hex_home(), "precondition: at zoom 1 the hex is 70 px above the centre")
	assert_eq(_hex_home(), Vector2(960, 470), "precondition: (960, 470) in the 1920x1080 view")

	for level: float in [2.0, 1.5, 1.0, 1.25, 2.0]:
		await _zoom_to(level)
		assert_true(_camera().zoom.is_equal_approx(Vector2(level, level)), "precondition: the camera is at zoom %s" % level)
		assert_lt(_screen_centre(START).distance_to(_hex_home()), 0.01, "zoom %s: the current hex's centre is still at (960, 470), not at %s" % [level, _screen_centre(START)])

## While the controller eases the zoom the offset follows the camera's own zoom,
## frame by frame (not only the target it is easing to, and not a frame late), so
## the current hex never leaves (960, 470) on the way.
func test_the_hex_stays_put_in_every_frame_of_the_ease() -> void:
	_start()
	await wait_process_frames(2)
	var controller: CameraZoomController = _zoom_controller()
	controller.set_zoom_level(2.0)

	var drifted: Array[String] = []
	var frames: int = 0
	# The ease lasts about a second of game time, however many frames that takes.
	while controller.is_zoom_active() and frames < 20000:
		await get_tree().process_frame
		frames += 1
		var off_by: float = _screen_centre(START).distance_to(_hex_home())
		if off_by > 0.01:
			drifted.append("frame %d (zoom %.3f): %.3f px" % [frames, _camera().zoom.x, off_by])

	assert_gt(frames, 10, "precondition: the ease takes a good few frames")
	assert_eq(_camera().zoom, Vector2(2, 2), "precondition: and ends at zoom 2")
	assert_eq(drifted, [] as Array[String], "the hex is at (960, 470) in every frame of the ease")

## A run opens at the zoom controller's default whatever zoom the last run was left
## at: the map (and its camera) outlives a run.
func test_a_new_run_opens_at_the_default_zoom() -> void:
	_start()
	await _zoom_to(2.0)
	assert_eq(_camera().zoom, Vector2(2, 2), "precondition: the run was zoomed in")
	_tilemap.stop_adventure()

	_start()

	assert_eq(_camera().zoom, Vector2.ONE, "the next run opens at zoom 1, at once")
	assert_eq(_camera().offset, AdventureTilemap.CAMERA_OFFSET, "with the offset for it")
	assert_eq(_zoom_controller().target_zoom, Vector2.ONE, "and the controller is aimed there")
	await wait_process_frames(2)
	assert_eq(_camera().zoom, Vector2.ONE, "it stays")
	assert_eq(_screen_centre(START), _hex_home(), "the current hex is where it is at zoom 1")

## The fog is sized for the widest view the map has, zoom 1 (the controller never
## goes below it), so from the farthest tile of the map the whole screen is fog or
## tiles the player sees at every zoom: a closer camera shows less of the world,
## never more.
func test_the_fog_covers_the_screen_at_every_zoom() -> void:
	_start()
	var reach: int = AdventureMapFixture.ADVENTURE_ACTION.adventure_data.max_distance_from_start
	var farthest: Array[Vector3i] = [
		Vector3i(reach, -reach, 0), Vector3i(-reach, reach, 0), Vector3i(reach, 0, -reach),
		Vector3i(-reach, 0, reach), Vector3i(0, reach, -reach), Vector3i(0, -reach, reach),
	]
	var size: Vector2 = get_viewport().get_visible_rect().size
	var edge_points: Array[Vector2] = []
	for x: int in range(0, int(size.x), 40):
		edge_points.append(Vector2(x, 0))
		edge_points.append(Vector2(x, size.y - 1.0))
	for y: int in range(0, int(size.y), 40):
		edge_points.append(Vector2(0, y))
		edge_points.append(Vector2(size.x - 1.0, y))
	edge_points.append(Vector2(size.x - 1.0, size.y - 1.0))
	var seen: Array[Vector3i] = _tilemap.get_seen_tiles()

	for zoom: float in [1.0, 2.0]:
		await _zoom_to(zoom)
		for tile: Vector3i in farthest:
			_tilemap.character_body.global_position = _tilemap.get_tile_world_centre(tile)
			# The camera moves with the character at the end of the frame.
			await wait_process_frames(2)
			var bare: Array[String] = []
			for point: Vector2 in edge_points:
				var cell: Vector2i = _tilemap.visible_map.local_to_map(_tilemap.visible_map.get_global_transform_with_canvas().affine_inverse() * point)
				var cube: Vector3i = _tilemap.visible_map.map_to_cube(cell)
				if _tilemap.get_fog_tier_at(cube) == -1 and not seen.has(cube):
					bare.append("%s at %s" % [cube, point])
			assert_eq(bare, [] as Array[String], "zoom %s, the player on %s: no bare ground on screen" % [zoom, tile])

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
	assert_eq(rim.texture, CURRENT_RIM_TEXTURE, "the heavier brass rim with its lacquer collar")
	assert_eq(rim.position, _centre(START), "on the start tile")

	await _walk_to(OPEN_NEAR)

	assert_eq(rim.position, _centre(_tilemap.get_current_tile()), "on the tile the player stands on")
	assert_eq(_tilemap.get_current_tile(), OPEN_NEAR, "precondition: the walk arrived")

## The player's hex wears a rim two px heavier than the zone map's: its own
## file, of the tile's own size so that it lies on the hex as the zone's does.
## The zone map keeps the lighter rim.
func test_current_rim_is_the_heavy_rim_at_the_tiles_size() -> void:
	var rim := _node("CurrentRim") as Sprite2D
	assert_not_null(rim, "the map has a current rim")
	if rim == null:
		return
	assert_eq(rim.texture.resource_path, "res://assets/ui/lacquer/map/lacquer_hex_current_heavy_ai.png", "the adventure's own rim")
	assert_eq(rim.texture.get_size(), Vector2(164, 190), "164x190, the tile's size, as the zone's rim is")
	assert_ne(rim.texture, ZONE_CURRENT_RIM_TEXTURE, "not the zone map's rim")
	assert_eq(ZONE_CURRENT_RIM_TEXTURE.get_size(), rim.texture.get_size(), "which is the same size, so either lies on a hex alike")
	assert_true(rim.centered, "centred on the tile, as the zone's rim is")

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

## The same at zoom 2: the push starts from and returns to the offset for the
## zoom, (0, 35), not the zoom 1 offset, so the current hex is back at
## (960, 470) when it ends.
func test_boss_push_returns_the_camera_to_the_zoom_correct_offset() -> void:
	var camera: Camera2D = _camera()
	_start()
	await _zoom_to(2.0)
	var home: Vector2 = AdventureTilemap.camera_offset_for(2.0)
	assert_eq(camera.offset, home, "precondition: (0, 35) at zoom 2")
	watch_signals(_tilemap)
	await _walk_to(FIGHT)
	assert_signal_emitted(_tilemap, "boss_revealed", "precondition: visiting FIGHT reveals the boss")
	assert_lt(camera.offset.distance_to(home), 15.0, "the push starts from the zoom's offset (the zoom 1 offset is 35 px from it)")

	await get_tree().create_timer(0.3, true, false, true).timeout
	var view_from_character: Vector2 = camera.global_position + camera.offset - _tilemap.character_body.global_position
	assert_gt(view_from_character.distance_to(home), 10.0, "precondition: mid-push, the view has moved toward the boss")

	# The push takes 1.2 s of game time, its first 0.15 s of real time at a quarter speed:
	# about 1.3 s after the reveal, 0.3 s of which have passed.
	await get_tree().create_timer(1.6, true, false, true).timeout
	assert_eq(camera.zoom, Vector2(2, 2), "precondition: the zoom held")
	assert_eq(camera.offset, home, "the push ends on the zoom's offset")
	assert_lt(_screen_centre(FIGHT).distance_to(_hex_home()), 0.01, "so the current hex is at (960, 470)")

## Watches the boss reveal's push for the whole of it (1.3 s after the reveal, plus
## room), once the character has walked to FIGHT, which reveals the boss one hex
## away: how far, at most, the character, who stands still in the world, moved from
## its place on screen, and every frame in which any of its sprite was off the screen.
func _watch_the_push() -> Dictionary:
	var screen: Rect2 = get_viewport().get_visible_rect()
	var sprite := _tilemap.character_body.get_node("Sprite2D") as Sprite2D
	var peak: float = 0.0
	var off_screen: Array[String] = []
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 1800:
		await get_tree().process_frame
		var at: Vector2 = _tilemap.character_body.get_global_transform_with_canvas().origin
		peak = maxf(peak, at.distance_to(_hex_home()))
		var sprite_rect: Rect2 = sprite.get_global_transform_with_canvas() * sprite.get_rect()
		if not screen.encloses(sprite_rect):
			off_screen.append(str(sprite_rect))
	return {"peak": peak, "off_screen": off_screen}

## Starts a run with the map at the zoom, walks to FIGHT and watches the push.
func _watch_the_push_at(level: float) -> Dictionary:
	_start()
	await _zoom_to(level)
	await _walk_to(FIGHT)
	return await _watch_the_push()

## The push is in screen px: it moves the view as far on screen at every zoom as it
## does at zoom 1, 45% of the hex to the boss (74 px), instead of twice as far at
## zoom 2, where a hex is twice as wide. So the character, whose whole sprite is
## measured every frame, never leaves the screen at zoom 2.
func test_the_boss_push_moves_the_view_as_far_on_screen_at_zoom_two_as_at_zoom_one() -> void:
	var at_one: Dictionary = await _watch_the_push_at(1.0)
	_tilemap.stop_adventure()
	var at_two: Dictionary = await _watch_the_push_at(2.0)

	var one_hex: float = (_centre(BOSS) - _centre(FIGHT)).length()
	assert_gt(at_one["peak"], 60.0, "precondition: at zoom 1 the push moves the view a good way")
	assert_almost_eq(at_one["peak"], one_hex * 0.45, 1.0, "precondition: 45% of the way to the boss, one hex off")
	assert_almost_eq(at_two["peak"], at_one["peak"], 1.0, "at zoom 2 the push peaks at the same screen offset, %s px, not %s" % [at_one["peak"], at_two["peak"]])
	assert_eq(at_one["off_screen"], [] as Array[String], "the character's sprite stays on screen through the push at zoom 1")
	assert_eq(at_two["off_screen"], [] as Array[String], "and at zoom 2")

## The push stays that far on screen even when the zoom changes while it runs: the
## offset divides the push by the camera's own zoom at every moment (a push turned
## into world px once, at the reveal, would move the view twice as far as the zoom
## eased from 1 to 2 under it).
func test_a_zoom_that_starts_during_the_push_does_not_change_how_far_it_moves_the_view() -> void:
	_start()
	await _walk_to(FIGHT)
	_zoom_controller().set_zoom_level(2.0)

	var seen: Dictionary = await _watch_the_push()

	var one_hex: float = (_centre(BOSS) - _centre(FIGHT)).length()
	assert_eq(_camera().zoom, Vector2(2, 2), "precondition: the zoom arrived while the push was watched")
	assert_almost_eq(seen["peak"], one_hex * 0.45, 1.0, "the push peaked at 45% of the hex to the boss on screen, whatever the zoom did under it")
	assert_eq(seen["off_screen"], [] as Array[String], "and the character stayed on screen")

## A zoom that starts while the push runs neither cancels the push nor is undone
## by it: the offset is the zoom's own plus the push at every moment, so the
## zoom's follow of the camera does not fight the tween, and the push still ends on
## the offset for the zoom the camera ended at.
func test_zooming_during_the_push_neither_fights_nor_cancels_it() -> void:
	var camera: Camera2D = _camera()
	_start()
	watch_signals(_tilemap)
	await _walk_to(FIGHT)
	assert_signal_emitted(_tilemap, "boss_revealed", "precondition: visiting FIGHT reveals the boss")
	_zoom_controller().set_zoom_level(2.0)

	await get_tree().create_timer(0.4, true, false, true).timeout
	var base: Vector2 = AdventureTilemap.camera_offset_for(camera.zoom.x)
	assert_gt(camera.zoom.x, 1.2, "precondition: the zoom is under way")
	assert_gt(camera.offset.distance_to(base), 10.0, "the push goes on moving the view, on top of the zoom's offset, while the zoom eases")

	await get_tree().create_timer(1.6, true, false, true).timeout
	assert_eq(camera.zoom, Vector2(2, 2), "the zoom arrived")
	assert_eq(camera.offset, AdventureTilemap.camera_offset_for(2.0), "and the push ended on the offset for it")

## A stop at zoom 2 mid-push puts the camera back on the zoom's offset at once.
func test_stop_mid_push_at_zoom_two_puts_the_camera_on_the_zooms_offset() -> void:
	var camera: Camera2D = _camera()
	_start()
	await _zoom_to(2.0)
	await _walk_to(FIGHT)
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_gt(camera.offset.distance_to(AdventureTilemap.camera_offset_for(2.0)), 10.0, "precondition: the push is under way")

	_tilemap.stop_adventure()

	assert_eq(camera.offset, AdventureTilemap.camera_offset_for(2.0), "the camera is back on the zoom's offset at once")
	await get_tree().create_timer(1.0, true, false, true).timeout
	assert_eq(camera.offset, AdventureTilemap.camera_offset_for(2.0), "and the push does not carry on")

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
