extends GutTest

## How AdventureTilemap draws what the player sees of the map (spec: The map):
## the fog lifting as tiles come into view, the dev panel's Show Whole Map and
## back, where the hover rim shows and where it does not, the route dots of a
## hovered or committed walk and what clears them, what a stop leaves behind, and
## the boss reveal's hit-stop, which slows game time and gives it back. Drives the
## real tilemap scene on the six-tile fixture map (AdventureMapFixture) and walks
## it by clicking tiles, the way the player does.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const AdventureTilemapScene := preload("res://scenes/adventure/adventure_tilemap/adventure_tilemap.tscn")
const AdventureMapFixture := preload("res://tests/integration/adventure_map_fixture.gd")

# The fixture map's tiles (see AdventureMapFixture).
const START := AdventureMapFixture.START
const FIGHT := AdventureMapFixture.FIGHT
const OPEN_NEAR := AdventureMapFixture.OPEN_NEAR
const OPEN_FAR := AdventureMapFixture.OPEN_FAR
const REST := AdventureMapFixture.REST
const BOSS := AdventureMapFixture.BOSS
## One 60 FPS frame, for stepping the walk by hand.
const FRAME: float = 1.0 / 60.0

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
	# A leftover from when the project's hex layer skipped the addon's own set-up:
	# the layer now sets itself up in its own _ready(), so this re-emit of the
	# shared TileSet's `changed` is no longer needed. It is harmless.
	_tilemap.full_map.tile_set.emit_changed()
	await get_tree().process_frame

func after_each() -> void:
	# The boss reveal slows time for a moment, and a test may set a dev speed; the
	# next test starts at full speed, with the base speed put back too.
	GameSpeed.set_base_scale(1.0)
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

## Moves every running tween in the tree on by `delta`, as a frame does: the
## boss reveal's push.
func _step_tweens(delta: float) -> void:
	for tween: Tween in get_tree().get_processed_tweens():
		if tween.is_valid() and tween.is_running():
			tween.custom_step(delta)

## One 60 FPS frame stepped by hand, in the tree's order: the character's
## physics step (the walk) and its camera's controllers (the zoom's ease), the
## camera following it (the tree's transform update), then the tweens. The walk is
## taken off the physics clock, so only the test moves it.
func _step_frame() -> void:
	_tilemap.character_body.set_physics_process(false)
	simulate(_tilemap.character_body, 1, FRAME)
	_camera().force_update_scroll()
	_step_tweens(FRAME)

## Clicks a tile, then steps frames until the character ends its first hop: the
## whole walk, for a tile next door.
func _walk_to(coord: Vector3i) -> void:
	_click(coord)
	await _wait_for_hop(coord)

## Steps frames until the character ends the hop it is on. Returns whether it did.
func _step_to_the_hop_end() -> bool:
	var ended: Array[bool] = [false]
	var on_end := func() -> void: ended[0] = true
	_tilemap.character_body.movement_completed.connect(on_end, CONNECT_ONE_SHOT)
	for _frame: int in roundi(AdventureMapFixture.HOP_TIMEOUT_SECONDS / FRAME):
		if ended[0]:
			break
		_step_frame()
	if not ended[0]:
		_tilemap.character_body.movement_completed.disconnect(on_end)
	return ended[0]

## Steps frames until the character ends the hop it is on, then lets a frame run,
## so what the tree does at the end of a frame (the camera following, a deferred
## hover) has caught up.
func _wait_for_hop(toward: Vector3i) -> void:
	assert_true(_step_to_the_hop_end(), "a hop of the walk to %s ends in time" % toward)
	await get_tree().process_frame

## The tilemap's node by its unique name, or null when the scene has none.
func _node(unique_name: String) -> Node:
	return _tilemap.get_node_or_null("%" + unique_name)

func _camera() -> Camera2D:
	return _tilemap.character_body.get_node("Camera2D") as Camera2D

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

#-----------------------------------------------------------------------------
# FOG
#-----------------------------------------------------------------------------

func test_fog_lifts_as_tiles_come_into_view() -> void:
	_start()
	assert_eq(_tilemap.get_fog_tier_at(OPEN_FAR), 1, "precondition: OPEN_FAR is fog from START")

	await _walk_to(OPEN_NEAR)

	assert_eq(_tilemap.get_fog_tier_at(OPEN_FAR), -1, "the arrival next to it reveals it, and the fog is redrawn")

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

func test_hover_rims() -> void:
	var rim := _node("HoverRim") as Sprite2D
	assert_not_null(rim, "the map has a hover rim")
	if rim == null:
		return
	_start()
	await _walk_to(OPEN_NEAR)

	_hover(START)
	assert_true(rim.visible, "over a visited tile")
	assert_eq(rim.position, _centre(START))

	_hover(FIGHT)
	assert_true(rim.visible, "over a revealed tile")
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
# BOSS REVEAL
#-----------------------------------------------------------------------------

func test_boss_reveal_keeps_the_hit_stop() -> void:
	_start()
	watch_signals(_tilemap)

	# Read before any real frame runs: the hit-stop's timer runs on real frames, and
	# a slow one could outlast its 0.15 s.
	_click(FIGHT)
	assert_true(_step_to_the_hop_end(), "precondition: the walk to FIGHT ends")

	assert_signal_emitted(_tilemap, "boss_revealed", "precondition: visiting FIGHT reveals the boss")
	assert_eq(Engine.time_scale, 0.25, "time slows right after the reveal")
	# 0.3 s of real time, whatever the time scale.
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0, "and runs at full speed again 0.3 s later")

## Under a dev time speed the hit-stop slows to a quarter of that speed, and time comes
## back to the dev speed, not to 1.0. The base speed is put back to 1.0 by after_each().
func test_the_hit_stop_returns_to_the_dev_speed() -> void:
	GameSpeed.set_base_scale(2.0)
	_start()
	watch_signals(_tilemap)

	# Read before any real frame runs, as above.
	_click(FIGHT)
	assert_true(_step_to_the_hop_end(), "precondition: the walk to FIGHT ends")

	assert_signal_emitted(_tilemap, "boss_revealed", "precondition: visiting FIGHT reveals the boss")
	assert_eq(Engine.time_scale, 0.5, "time slows to a quarter of the dev speed right after the reveal")
	# 0.3 s of real time, whatever the time scale.
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_eq(Engine.time_scale, 2.0, "and returns to the dev speed 0.3 s later")
