extends GutTest

## How the adventure map marks its encounters with lacquer coins (spec: The map,
## Coins): a coin on each tile the player sees that has something to show, its
## face by what the player knows of the tile, its place over its hex in screen
## space (higher on the hex the player stands on, where it clears the character's
## head), how it follows the camera at any zoom, where the layer draws (over the
## tiles, rims, fog and route, under the character) and that it never takes the
## pointer, the boss coin's shake when the boss comes into view, the dev panel's
## Show Whole Map, and the stop. Drives the real tilemap scene on the six-tile
## fixture map (AdventureMapFixture) and walks it by clicking tiles, the way the
## player does.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const AdventureTilemapScene := preload("res://scenes/adventure/adventure_tilemap/adventure_tilemap.tscn")
const AdventureMapFixture := preload("res://tests/integration/adventure_map_fixture.gd")

const Face := EncounterCoin.Face
const Type := AdventureEncounter.EncounterType

# The fixture map's tiles (see AdventureMapFixture).
const START := AdventureMapFixture.START
const FIGHT := AdventureMapFixture.FIGHT
const OPEN_NEAR := AdventureMapFixture.OPEN_NEAR
const OPEN_FAR := AdventureMapFixture.OPEN_FAR
const REST := AdventureMapFixture.REST
const BOSS := AdventureMapFixture.BOSS
const FIXTURE_TILES: Array[Vector3i] = [START, FIGHT, OPEN_NEAR, OPEN_FAR, REST, BOSS]
## One 60 FPS frame, for stepping the walk, the zoom's ease and the shakes by hand.
const FRAME: float = 1.0 / 60.0

## A coin's top-left sits 26 px left of its centre and 26 up, before it rises.
const COIN_HALF: Vector2 = Vector2(26, 26)

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
	(_tilemap.character_body.get_node("Camera2D") as Camera2D).force_update_scroll()
	_step_tweens(FRAME)

## Clicks a tile, then steps frames until the character ends its first hop (the
## whole walk, for a tile next door) and lets a frame run, so what the tree does at
## the end of a frame has caught up.
func _walk_to(coord: Vector3i) -> void:
	var ended: Array[bool] = [false]
	var on_end := func() -> void: ended[0] = true
	_tilemap.character_body.movement_completed.connect(on_end, CONNECT_ONE_SHOT)
	_click(coord)
	for _frame: int in roundi(AdventureMapFixture.HOP_TIMEOUT_SECONDS / FRAME):
		if ended[0]:
			break
		_step_frame()
	if not ended[0]:
		_tilemap.character_body.movement_completed.disconnect(on_end)
	assert_true(ended[0], "the first hop of the walk to %s ends in time" % coord)
	await get_tree().process_frame

## Waits out a whole frame after the last step of a walk: the first await ends
## before a frame's processing and the second after it, by when the camera and
## the coins' _process placement have caught up with the character.
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

## Does what the engine does just before it draws a frame: says so, so that what
## puts itself over the map (the coin layer) places itself one last time, after
## the frame's tweens (the boss push) have moved the camera. A headless run never
## draws, so it never says it, and the tests that measure where the coins are
## during a camera tween say it for it.
func _before_draw() -> void:
	RenderingServer.frame_pre_draw.emit()

## The coin layer the map instances, or null when the scene has none.
func _markers() -> AdventureMapMarkers:
	return _tilemap.get_node_or_null("%AdventureMapMarkers") as AdventureMapMarkers

## Zooms the map to the level the way the wheel does (through the map's zoom
## controller), steps frames until the camera has got there, and waits for the
## coins to follow it.
func _zoom_to(level: float) -> void:
	var controller := _tilemap.get_node("%CameraZoomController") as CameraZoomController
	controller.set_zoom_level(level)
	for _frame: int in roundi(3.0 / FRAME):
		if not controller.is_zoom_active():
			break
		_step_frame()
	assert_false(controller.is_zoom_active(), "the zoom to %s ends in time" % level)
	await _settle()

## The z index a node draws at: its own, plus its ancestors' for as long as it is
## relative to them (a node that is not a canvas item has none).
func _effective_z(node: Node) -> int:
	if not node is CanvasItem:
		return 0
	var item: CanvasItem = node as CanvasItem
	return item.z_index + (_effective_z(item.get_parent()) if item.z_as_relative else 0)

## The coin on the tile, or null.
func _coin(coord: Vector3i) -> EncounterCoin:
	var markers: AdventureMapMarkers = _markers()
	return null if markers == null else markers.get_coin(coord)

## The face of every coin on the fixture's tiles, by tile.
func _faces() -> Dictionary:
	var faces: Dictionary = {}
	for coord: Vector3i in FIXTURE_TILES:
		var coin: EncounterCoin = _coin(coord)
		if coin != null:
			faces[coord] = coin.get_face()
	return faces

## Where every coin on the fixture's tiles is, by tile.
func _positions() -> Dictionary:
	var positions: Dictionary = {}
	for coord: Vector3i in FIXTURE_TILES:
		var coin: EncounterCoin = _coin(coord)
		if coin != null:
			positions[coord] = coin.position
	return positions

## The fog tier on every fixture tile, by tile (-1 where there is none).
func _fog() -> Dictionary:
	var tiers: Dictionary = {}
	for coord: Vector3i in FIXTURE_TILES:
		tiers[coord] = _tilemap.get_fog_tier_at(coord)
	return tiers

## Where the tile's centre is on screen: its world centre through the map's
## canvas transform, which carries the camera.
func _screen_centre(coord: Vector3i) -> Vector2:
	return _tilemap.get_global_transform_with_canvas() * _tilemap.get_tile_world_centre(coord)

## Where a coin's top-left is when its disc is centred `rise` px above the tile's centre.
func _coin_position(coord: Vector3i, rise: float) -> Vector2:
	return (_screen_centre(coord) - COIN_HALF - Vector2(0, rise)).round()

## The screen y of the topmost opaque pixel of the character's current frame:
## the top of its head.
func _character_head_top() -> float:
	var sprite := _tilemap.character_body.get_node("Sprite2D") as Sprite2D
	var frame_size: Vector2i = Vector2i(sprite.texture.get_size()) / Vector2i(sprite.hframes, sprite.vframes)
	@warning_ignore("integer_division")
	var origin: Vector2i = Vector2i(sprite.frame % sprite.hframes, sprite.frame / sprite.hframes) * frame_size
	var image: Image = sprite.texture.get_image()
	for row: int in frame_size.y:
		for column: int in frame_size.x:
			if image.get_pixel(origin.x + column, origin.y + row).a > 0.0:
				# The sprite is centred on its offset.
				var local_y: float = sprite.offset.y - frame_size.y / 2.0 + row
				return (sprite.get_global_transform_with_canvas() * Vector2(0, local_y)).y
	return INF

#-----------------------------------------------------------------------------
# THE LAYER
#-----------------------------------------------------------------------------

func test_the_map_instances_the_coin_layer() -> void:
	var markers: AdventureMapMarkers = _markers()
	assert_not_null(markers, "the map has a coin layer")
	if markers == null:
		return
	var node: Node = markers
	assert_false(node is CanvasLayer, "a node of the map's own canvas: a canvas layer draws over all of it, the character included")
	assert_true(node is Node2D, "a node of the map's canvas, drawn by its z index")
	assert_eq(markers.map, _tilemap, "it reads the map it is a child of")
	assert_eq(markers.get_coin_count(), 0, "no coins before a run")

## The hexes under the coins stay hoverable and clickable: nothing a coin is
## made of takes the pointer.
func test_coins_ignore_the_pointer() -> void:
	var markers: AdventureMapMarkers = _markers()
	assert_not_null(markers, "the map has a coin layer")
	if markers == null:
		return
	_start()
	var controls: Array[Node] = markers.find_children("*", "Control", true, false)
	assert_gt(controls.size(), 3, "precondition: three coins and what they are made of")
	var takers: Array[String] = []
	for control: Node in controls:
		if (control as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			takers.append(str(markers.get_path_to(control)))
	assert_eq(takers, [] as Array[String], "no control of the layer takes the pointer")

## The coins draw over the tiles, the rims, the fog and the route and under the
## character and its shadow, so the character walks over a coin instead of
## behind it. (The layer draws by its z index, in the map's own canvas.)
func test_the_character_draws_over_the_coins() -> void:
	_start()
	var markers: AdventureMapMarkers = _markers()
	assert_not_null(markers, "the map has a coin layer")
	if markers == null:
		return
	var coin_z: int = _effective_z(markers)
	var under_the_coins: Array[Node] = [
		_tilemap.get_node("%AdventureFogMap"), _tilemap.get_node("%AdventureFullMap"), _tilemap.get_node("%AdventureVisibleMap"),
		_tilemap.get_node("%CurrentRim"), _tilemap.get_node("%HoverRim"), _tilemap.get_node("%AdventureRoute"),
	]
	for piece: Node in under_the_coins:
		assert_lt(_effective_z(piece), coin_z, "%s draws under the coins" % piece.name)
	assert_lt(coin_z, _effective_z(_tilemap.get_node("%CharacterShadow")), "the character's shadow draws over the coins")
	assert_lt(coin_z, _effective_z(_tilemap.character_body), "and so does the character")
	var coin: EncounterCoin = _coin(FIGHT)
	assert_not_null(coin, "precondition: the fight tile has its coin")
	if coin != null:
		assert_eq(_effective_z(coin), coin_z, "a coin draws where its layer does")

## The coin layer stands in the screen's space whatever the camera does: its own
## transform cancels the camera's, so a coin's position is its screen position and
## its 54 px stay 54 px at any zoom, over the middle of its hex. (The zoom is set
## on the camera here; the map's wheel zoom is tested with the view.)
func test_coins_keep_their_size_and_their_hexes_when_the_zoom_changes() -> void:
	var camera := _tilemap.character_body.get_node("Camera2D") as Camera2D
	var markers: AdventureMapMarkers = _markers()
	assert_not_null(markers, "the map has a coin layer")
	if markers == null:
		return
	_start()
	await _settle()
	for zoom: float in [1.0, 1.5, 2.0]:
		camera.zoom = Vector2(zoom, zoom)
		await _settle()
		assert_true(get_viewport().get_canvas_transform().get_scale().is_equal_approx(Vector2(zoom, zoom)), "precondition: the map is drawn at zoom %s" % zoom)
		assert_true(markers.get_global_transform_with_canvas().is_equal_approx(Transform2D.IDENTITY), "zoom %s: the layer's transform cancels the camera's" % zoom)
		for coord: Vector3i in [FIGHT, OPEN_NEAR, REST]:
			var on_screen: Transform2D = _coin(coord).get_global_transform_with_canvas()
			assert_true(on_screen.get_scale().is_equal_approx(Vector2.ONE), "zoom %s, %s: the coin is drawn at its own size" % [zoom, coord])
			assert_almost_eq(on_screen.origin.x + COIN_HALF.x, _screen_centre(coord).x, 1.0, "zoom %s, %s: over the middle of its hex" % [zoom, coord])
			assert_lt(on_screen.origin.y + COIN_HALF.y, _screen_centre(coord).y, "zoom %s, %s: and above its centre" % [zoom, coord])

## The layer sets its transform again just before the frame is drawn, as it places
## its coins: a camera that changed after the frame's _process (a tween) leaves it
## cancelling the camera's transform all the same.
func test_the_layer_cancels_the_camera_again_before_the_frame_is_drawn() -> void:
	var camera := _tilemap.character_body.get_node("Camera2D") as Camera2D
	var markers: AdventureMapMarkers = _markers()
	assert_not_null(markers, "the map has a coin layer")
	if markers == null:
		return
	_start()
	await _settle()

	camera.zoom = Vector2(1.5, 1.5)
	camera.offset += Vector2(30, 20)
	_before_draw()

	assert_true(markers.get_global_transform_with_canvas().is_equal_approx(Transform2D.IDENTITY), "the pass just before the draw cancels the camera's new transform")
	assert_eq(_coin(FIGHT).get_global_transform_with_canvas().origin.round(), _coin(FIGHT).position, "so a coin's position is where it is drawn")

func test_old_icon_layers_are_gone() -> void:
	for node_name: String in ["EncounterIconContainer", "AdventureMarker"]:
		assert_null(_tilemap.find_child(node_name, true, false), "%s is gone" % node_name)
	_start()
	assert_eq(_tilemap.find_children("*", "EncounterIcon", true, false).size(), 0, "no flat encounter icon on the map")

#-----------------------------------------------------------------------------
# WHICH TILES GET A COIN, AND WITH WHAT FACE
#-----------------------------------------------------------------------------

func test_start_coins_are_unknown() -> void:
	var markers: AdventureMapMarkers = _markers()
	assert_not_null(markers, "the map has a coin layer")
	if markers == null:
		return

	_start()

	# From START the player sees FIGHT, OPEN_NEAR and REST: every one a "?",
	# the empty tile too, so a coin never gives away what is under a veil.
	assert_eq(_faces(), {FIGHT: Face.UNKNOWN, OPEN_NEAR: Face.UNKNOWN, REST: Face.UNKNOWN}, "a question mark on each revealed tile")
	assert_eq(markers.get_coin_count(), 3)
	assert_null(markers.get_coin(START), "no coin on the visited, empty start tile")
	for coord: Vector3i in [FIGHT, OPEN_NEAR, REST]:
		var coin: EncounterCoin = markers.get_coin(coord)
		assert_null(coin.get_glyph_texture(), "%s: the question mark carries no glyph" % coord)

func test_visited_fight_shows_its_glyph() -> void:
	_start()

	await _walk_to(FIGHT)

	assert_eq(_faces(), {FIGHT: Face.GLYPH, OPEN_NEAR: Face.UNKNOWN, REST: Face.UNKNOWN, BOSS: Face.BOSS},
		"the visited fight shows its glyph, its neighbours stay unknown, and the boss it reveals has its coin")
	var coin: EncounterCoin = _coin(FIGHT)
	assert_eq(coin.get_glyph_texture(), EncounterCoin.glyph_for(Type.COMBAT_REGULAR, false), "the combat glyph")
	assert_null(_coin(START), "the empty start tile still has none")

func test_visited_noop_has_no_coin() -> void:
	_start()

	await _walk_to(OPEN_NEAR)

	assert_null(_coin(OPEN_NEAR), "a visited empty tile has no coin")
	assert_null(_coin(START))
	# OPEN_FAR is empty too, but only revealed: it keeps its question mark.
	assert_eq(_faces(), {FIGHT: Face.UNKNOWN, REST: Face.UNKNOWN, OPEN_FAR: Face.UNKNOWN}, "revealed tiles keep their question mark, empty or not")

func test_resolved_tile_turns_carved() -> void:
	_start()
	await _walk_to(FIGHT)
	assert_eq(_coin(FIGHT).get_face(), Face.GLYPH, "precondition: the fight waits for a choice")

	_tilemap.select_choice(AdventureMapFixture.fight_choice(_map))
	_tilemap.handle_combat_result(true, 0)

	var coin: EncounterCoin = _coin(FIGHT)
	assert_eq(coin.get_face(), Face.CLEARED, "a won fight turns carved")
	assert_eq(coin.get_glyph_texture(), EncounterCoin.glyph_for(Type.COMBAT_REGULAR, true), "with the kit's spent glyph")
	_before_draw()
	assert_eq(coin.position, _coin_position(FIGHT, AdventureMapMarkers.COIN_RISE_HERE), "still riding above the character")

	# Once the player walks on, the carved coin comes down to rest on its hex.
	# (The boss push is still easing the camera, so measure as a frame is drawn.)
	await _walk_to(START)
	assert_eq(_coin(FIGHT).get_face(), Face.CLEARED, "carved for good")
	_before_draw()
	assert_eq(_coin(FIGHT).position, _coin_position(FIGHT, AdventureMapMarkers.COIN_RISE), "and sits low again")

func test_resolved_rest_site_turns_carved() -> void:
	_start()
	await _walk_to(REST)
	var coin: EncounterCoin = _coin(REST)
	assert_eq(coin.get_face(), Face.GLYPH, "precondition: the rest site waits for a choice")
	assert_eq(coin.get_glyph_texture(), EncounterCoin.glyph_for(Type.REST_SITE, false), "the rest strip, 5 frames")

	_tilemap.select_choice(AdventureMapFixture.rest_choice(_map))

	assert_eq(_coin(REST).get_face(), Face.CLEARED, "a taken rest turns carved")
	assert_eq(_coin(REST).get_glyph_texture(), EncounterCoin.glyph_for(Type.REST_SITE, true), "with its own spent glyph")

#-----------------------------------------------------------------------------
# THE BOSS
#-----------------------------------------------------------------------------

func test_boss_coin_appears_once_revealed_and_shakes() -> void:
	_start()
	assert_null(_coin(BOSS), "no coin while the boss is fog")

	await _walk_to(FIGHT)

	var coin: EncounterCoin = _coin(BOSS)
	assert_not_null(coin, "the boss coin appears the moment its tile comes into view")
	if coin == null:
		return
	assert_eq(coin.get_face(), Face.BOSS, "the vermilion-ringed coin")
	assert_eq(coin.get_glyph_texture(), EncounterCoin.glyph_for(Type.COMBAT_BOSS, false), "with the boss strip")
	assert_true(coin.is_shaking(), "and its glyph shakes")
	assert_false(_coin(REST).is_shaking(), "no other coin does")
	assert_false(_coin(FIGHT).is_shaking())

	# The shake runs its course and the coin settles back home. The coin's own
	# _process steps the shake, so it is run a frame at a time.
	for _frame: int in roundi(3.0 / FRAME):
		if not coin.is_shaking():
			break
		simulate(coin, 1, FRAME)
	assert_false(coin.is_shaking(), "the shake ends")
	assert_eq((coin.get_node("%Token") as Control).position.x, 0.0, "back on its hex")

func test_a_redraw_does_not_cut_the_boss_shake_short() -> void:
	_start()
	await _walk_to(FIGHT)
	var coin: EncounterCoin = _coin(BOSS)
	assert_true(coin.is_shaking(), "precondition: the boss coin is shaking")

	# Winning the fight redraws the map (map_changed and encounter_resolved).
	_tilemap.select_choice(AdventureMapFixture.fight_choice(_map))
	_tilemap.handle_combat_result(true, 0)

	assert_same(_coin(BOSS), coin, "the redraw keeps the boss coin")
	assert_true(coin.is_shaking(), "and its shake goes on")

#-----------------------------------------------------------------------------
# WHERE THE COINS ARE
#-----------------------------------------------------------------------------

func test_coins_sit_8_px_above_their_hexes() -> void:
	_start()
	await get_tree().process_frame

	var coins: Dictionary = _positions()
	assert_eq(coins.size(), 3, "precondition: three coins")
	for coord: Vector3i in coins:
		assert_eq(coins[coord], _coin_position(coord, AdventureMapMarkers.COIN_RISE), "%s: the 52 px disc centred 8 px above its hex centre" % coord)
	assert_eq(AdventureMapMarkers.COIN_RISE, 8.0)

func test_coin_rides_above_the_character_here() -> void:
	_start()
	# REST, not FIGHT: arriving at FIGHT reveals the boss, and the reveal's camera
	# push moves the view for a moment, away from where the camera rests.
	await _walk_to(REST)
	await _settle()
	var coin: EncounterCoin = _coin(REST)
	var centre: Vector2 = _screen_centre(REST)
	assert_eq(centre, get_viewport().get_visible_rect().size / 2.0 - Vector2(0, 70), "precondition: the current hex sits 70 px above the screen centre")

	assert_eq(AdventureMapMarkers.COIN_RISE_HERE, 64.0)
	assert_eq(coin.position.y, centre.y - 64.0 - 26.0, "the top-left 64 + 26 px above the hex's centre")
	assert_eq(coin.position.x, centre.x - 26.0, "and centred on it")

	var head_top: float = _character_head_top()
	assert_lt(head_top, centre.y, "precondition: the head is above the hex's centre")
	assert_lt(coin.position.y + coin.size.y, head_top, "the coin's bottom, shadow and all, stays above the character's head (%s, head at %s)" % [coin.position.y + coin.size.y, head_top])
	# The other coins keep their low seat.
	assert_eq(_coin(FIGHT).position, _coin_position(FIGHT, AdventureMapMarkers.COIN_RISE), "a coin on another hex rises 8 px")

func test_coins_follow_the_camera() -> void:
	_start()
	await get_tree().process_frame
	var before: Dictionary = _positions()
	assert_eq(before.size(), 3, "precondition: three coins")

	# The camera follows the character: moving it 100 px right slides the whole
	# map 100 px left. One frame later (the first await ends before the frame's
	# processing, the second after it) every coin has moved with it.
	_tilemap.character_body.position.x += 100.0
	await get_tree().process_frame
	await get_tree().process_frame

	var after: Dictionary = _positions()
	for coord: Vector3i in before:
		assert_eq(after[coord], before[coord] - Vector2(100, 0), "%s: 100 px left, in the same frame as its hex" % coord)
		assert_eq(after[coord], _coin_position(coord, AdventureMapMarkers.COIN_RISE), "%s: still where its hex is" % coord)

## The boss reveal's push eases the camera by a tween, which steps at the end of
## the frame, after the nodes' _process. The coins are put over their hexes once
## more just before the frame is drawn, so they never trail the tiles by a frame.
func test_coins_keep_up_with_a_camera_a_tween_moves() -> void:
	var camera := _tilemap.character_body.get_node("Camera2D") as Camera2D
	_start()
	# Arriving at FIGHT reveals the boss and starts the camera push.
	await _walk_to(FIGHT)

	var first_offset: Vector2 = camera.offset
	var last_offset: Vector2 = first_offset
	var off_their_hexes: Array[String] = []
	for frame: int in 24:
		await get_tree().process_frame
		_before_draw()
		last_offset = camera.offset
		for coord: Vector3i in [FIGHT, OPEN_NEAR, REST, BOSS]:
			var rise: float = AdventureMapMarkers.COIN_RISE_HERE if coord == FIGHT else AdventureMapMarkers.COIN_RISE
			if _coin(coord).position != _coin_position(coord, rise):
				off_their_hexes.append("frame %d, %s" % [frame, coord])

	assert_gt(last_offset.distance_to(first_offset), 5.0, "precondition: the push moved the camera while the coins were measured")
	assert_eq(off_their_hexes, [] as Array[String], "every coin sits on its hex in every frame, though the camera moves under them")

## The map announces a resolution with encounter_resolved, and the coin layer
## redraws on it as well as on map_changed. Today map_changed fires first, so cut
## it off to see the resolution's own signal do the work.
func test_a_resolution_alone_redraws_the_coin() -> void:
	var markers: AdventureMapMarkers = _markers()
	assert_not_null(markers, "the map has a coin layer")
	if markers == null:
		return
	_start()
	await _walk_to(FIGHT)
	assert_eq(_coin(FIGHT).get_face(), Face.GLYPH, "precondition: the fight waits for a choice")
	_tilemap.map_changed.disconnect(markers.rebuild)

	_tilemap.select_choice(AdventureMapFixture.fight_choice(_map))
	_tilemap.handle_combat_result(true, 0)

	assert_eq(_coin(FIGHT).get_face(), Face.CLEARED, "the resolution's own signal turns the coin carved")

func test_coins_are_on_whole_pixels() -> void:
	_start()
	await _walk_to(OPEN_NEAR)
	await _settle()

	var coins: Dictionary = _positions()
	assert_gt(coins.size(), 0, "precondition: the map has coins")
	for coord: Vector3i in coins:
		var at: Vector2 = coins[coord]
		assert_eq(at, at.round(), "%s: a coin sits on whole px" % coord)

#-----------------------------------------------------------------------------
# THE RISE AT EVERY ZOOM
#-----------------------------------------------------------------------------

## A coin keeps its place on a hex that grows with the zoom: its rise is 8 px times
## the zoom (8 at zoom 1, 16 at zoom 2). Over the player's hex it is the disc's
## half height, the character's head (24 px at zoom 1, 48 at zoom 2: the character
## is drawn at the zoom) and 14 px of clearance: 64 px at zoom 1, 88 at zoom 2.
func test_the_rise_grows_with_the_zoom() -> void:
	assert_eq(AdventureMapMarkers.COIN_RISE, 8.0, "8 px at zoom 1")
	assert_eq(AdventureMapMarkers.COIN_RISE_HERE, 64.0, "64 px at zoom 1 on the player's hex")
	assert_eq(AdventureMapMarkers.rise_for(1.0, false), 8.0)
	assert_eq(AdventureMapMarkers.rise_for(2.0, false), 16.0)
	assert_almost_eq(AdventureMapMarkers.rise_for(1.5, false), 12.0, 0.0001, "in between, in proportion")
	assert_eq(AdventureMapMarkers.rise_for(1.0, true), AdventureMapMarkers.COIN_RISE_HERE, "the constant is the player's hex's rise at zoom 1")
	assert_eq(AdventureMapMarkers.rise_for(2.0, true), 26.0 + 2.0 * 24.0 + 14.0, "26 + 24 x zoom + 14")
	assert_almost_eq(AdventureMapMarkers.rise_for(1.5, true), 26.0 + 1.5 * 24.0 + 14.0, 0.0001)

## At every zoom each coin is where rise_for() puts it over its hex, so it sits at
## the same place on the hex: its disc's centre is 8 hex-px-at-zoom-1 above the
## hex's centre, the player's coin 64 above at zoom 1 and as far above the head
## at the others.
func test_coins_sit_at_the_same_place_on_their_hexes_at_every_zoom() -> void:
	_start()
	# REST, not FIGHT: arriving at FIGHT reveals the boss, and its camera push moves the view.
	await _walk_to(REST)
	await _settle()
	for zoom: float in [1.0, 1.5, 2.0, 1.25]:
		await _zoom_to(zoom)
		assert_true(get_viewport().get_canvas_transform().get_scale().is_equal_approx(Vector2(zoom, zoom)), "precondition: the map is at zoom %s" % zoom)
		for coord: Vector3i in [FIGHT, OPEN_NEAR, REST]:
			var here: bool = coord == REST
			var rise: float = AdventureMapMarkers.rise_for(zoom, here)
			assert_eq(_coin(coord).position, _coin_position(coord, rise), "zoom %s, %s: %s px above its hex's centre" % [zoom, coord, rise])
			if not here:
				var disc_centre_above: float = _screen_centre(coord).y - (_coin(coord).position.y + COIN_HALF.y)
				assert_almost_eq(disc_centre_above / zoom, 8.0, 0.5, "zoom %s, %s: the same 8 px of the hex at every zoom" % [zoom, coord])
		assert_true(_coin(FIGHT).get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE), "zoom %s: and every coin is drawn at its own size" % zoom)

## The coin over the player's hex clears the character's head by the same space at
## every zoom, though the character is twice as tall on screen at zoom 2.
func test_the_coin_over_the_players_hex_clears_the_head_at_every_zoom() -> void:
	_start()
	await _walk_to(REST)
	await _settle()
	var clearance_at_zoom_one: float = _character_head_top() - (_coin(REST).position.y + _coin(REST).size.y)
	assert_gt(clearance_at_zoom_one, 0.0, "precondition: at zoom 1 the coin's frame ends over the head")
	for zoom: float in [1.5, 2.0, 1.25]:
		await _zoom_to(zoom)
		var coin: EncounterCoin = _coin(REST)
		var head_top: float = _character_head_top()
		assert_lt(head_top, _screen_centre(REST).y, "zoom %s: precondition: the head is above the hex's centre" % zoom)
		assert_lt(coin.position.y + coin.size.y, head_top, "zoom %s: the coin's bottom, shadow and all, stays above the character's head" % zoom)
		assert_almost_eq(head_top - (coin.position.y + coin.size.y), clearance_at_zoom_one, 1.5, "zoom %s: with the same clear space as at zoom 1" % zoom)

#-----------------------------------------------------------------------------
# A REDRAW
#-----------------------------------------------------------------------------

func test_a_redraw_keeps_coins_and_their_animation() -> void:
	var markers: AdventureMapMarkers = _markers()
	assert_not_null(markers, "the map has a coin layer")
	if markers == null:
		return
	_start()
	# Under the dev override the rest site shows its animated glyph.
	_tilemap.set_dev_reveal_all(true)
	var rest: EncounterCoin = _coin(REST)
	assert_not_null(rest)
	simulate(rest, 1, 0.45)
	var glyph := rest.get_node("%Glyph") as LacquerStripRect
	assert_eq(glyph.get_frame(), Vector2i(1, 0), "precondition: a frame in")

	markers.rebuild()

	assert_same(_coin(REST), rest, "the same coin is kept, not rebuilt")
	assert_eq(glyph.get_frame(), Vector2i(1, 0), "so its animation carries on instead of starting over")
	assert_eq(markers.get_coin_count(), 3, "and no coin is added or lost")

#-----------------------------------------------------------------------------
# THE DEV PANEL'S SHOW WHOLE MAP
#-----------------------------------------------------------------------------

## Review Focus 2: the dev toggle on, then off, puts the coins and the fog back
## to exactly the normal set.
func test_dev_reveal_toggle_round_trip() -> void:
	_start()
	await _walk_to(OPEN_NEAR)
	var normal_faces: Dictionary = _faces()
	var normal_positions: Dictionary = _positions()
	var normal_fog: Dictionary = _fog()
	assert_eq(normal_faces, {FIGHT: Face.UNKNOWN, REST: Face.UNKNOWN, OPEN_FAR: Face.UNKNOWN}, "precondition: the normal set, mid-run")

	_tilemap.set_dev_reveal_all(true)

	assert_eq(_faces(), {FIGHT: Face.GLYPH, REST: Face.GLYPH, BOSS: Face.BOSS},
		"on: every unvisited encounter tile shows its glyph, the boss keeps its own coin, and no empty tile has one")
	assert_eq(_coin(FIGHT).get_glyph_texture(), EncounterCoin.glyph_for(Type.COMBAT_REGULAR, false))
	assert_eq(_coin(REST).get_glyph_texture(), EncounterCoin.glyph_for(Type.REST_SITE, false))
	assert_eq(_coin(BOSS).get_glyph_texture(), EncounterCoin.glyph_for(Type.COMBAT_BOSS, false))
	assert_null(_coin(START), "the visited start tile has none")
	assert_null(_coin(OPEN_NEAR), "nor the visited empty tile the player stands on")
	assert_null(_coin(OPEN_FAR), "nor an empty tile the override reveals")

	_tilemap.set_dev_reveal_all(false)

	assert_eq(_faces(), normal_faces, "off: the same coins as before")
	assert_eq(_positions(), normal_positions, "in the same places")
	assert_eq(_fog(), normal_fog, "and the same fog")
	assert_null(_coin(BOSS), "the boss is fog again")

func test_dev_reveal_does_not_hand_out_a_shake() -> void:
	_start()

	_tilemap.set_dev_reveal_all(true)

	assert_false(_coin(BOSS).is_shaking(), "showing the whole map is not the boss coming into view")

#-----------------------------------------------------------------------------
# STOP
#-----------------------------------------------------------------------------

func test_stop_removes_every_coin() -> void:
	var markers: AdventureMapMarkers = _markers()
	assert_not_null(markers, "the map has a coin layer")
	if markers == null:
		return
	_start()
	await _walk_to(FIGHT)
	assert_gt(markers.get_coin_count(), 0, "precondition: the run has coins")

	_tilemap.stop_adventure()

	assert_eq(markers.get_coin_count(), 0, "the stop takes every coin off the map")
	for coord: Vector3i in FIXTURE_TILES:
		assert_null(markers.get_coin(coord), "%s: none left" % coord)

func test_stop_under_the_dev_override_leaves_no_coin() -> void:
	var markers: AdventureMapMarkers = _markers()
	assert_not_null(markers, "the map has a coin layer")
	if markers == null:
		return
	_start()
	_tilemap.set_dev_reveal_all(true)
	assert_eq(markers.get_coin_count(), 3, "precondition: the whole map's coins")

	_tilemap.stop_adventure()

	assert_eq(markers.get_coin_count(), 0, "none left, override or not")

func test_a_second_run_has_only_its_own_coins() -> void:
	var markers: AdventureMapMarkers = _markers()
	assert_not_null(markers, "the map has a coin layer")
	if markers == null:
		return
	_start()
	await _walk_to(FIGHT)
	_tilemap.stop_adventure()

	_start()

	assert_eq(_faces(), {FIGHT: Face.UNKNOWN, OPEN_NEAR: Face.UNKNOWN, REST: Face.UNKNOWN}, "the new run starts with the start tile's neighbours, all unknown")
	assert_eq(markers.get_coin_count(), 3)
