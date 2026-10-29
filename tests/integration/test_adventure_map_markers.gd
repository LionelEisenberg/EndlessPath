extends GutTest

## How the adventure map marks its encounters with lacquer coins (spec: The map,
## Coins): a coin on each tile the player sees that has something to show, its
## face by what the player knows of the tile, that it never takes the pointer, a
## redraw keeping the coins it has, the dev panel's Show Whole Map, and the stop.
## Drives the real tilemap scene on the six-tile fixture map (AdventureMapFixture)
## and walks it by clicking tiles, the way the player does.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const AdventureTilemapScene := preload("res://scenes/adventure/adventure_tilemap/adventure_tilemap.tscn")
const AdventureMapFixture := preload("res://tests/integration/adventure_map_fixture.gd")

const Face := EncounterCoin.Face

# The fixture map's tiles (see AdventureMapFixture).
const START := AdventureMapFixture.START
const FIGHT := AdventureMapFixture.FIGHT
const OPEN_NEAR := AdventureMapFixture.OPEN_NEAR
const OPEN_FAR := AdventureMapFixture.OPEN_FAR
const REST := AdventureMapFixture.REST
const BOSS := AdventureMapFixture.BOSS
const FIXTURE_TILES: Array[Vector3i] = [START, FIGHT, OPEN_NEAR, OPEN_FAR, REST, BOSS]
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

## The coin layer the map instances, or null when the scene has none.
func _markers() -> AdventureMapMarkers:
	return _tilemap.get_node_or_null("%AdventureMapMarkers") as AdventureMapMarkers

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

#-----------------------------------------------------------------------------
# THE LAYER
#-----------------------------------------------------------------------------

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

	# Once the player walks on, the coin stays carved.
	await _walk_to(START)
	assert_eq(_coin(FIGHT).get_face(), Face.CLEARED, "carved for good")

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

#-----------------------------------------------------------------------------
# THE BOSS
#-----------------------------------------------------------------------------

func test_boss_coin_appears_once_revealed() -> void:
	_start()
	assert_null(_coin(BOSS), "no coin while the boss is fog")

	await _walk_to(FIGHT)

	var coin: EncounterCoin = _coin(BOSS)
	assert_not_null(coin, "the boss coin appears the moment its tile comes into view")
	if coin == null:
		return
	assert_eq(coin.get_face(), Face.BOSS, "the vermilion-ringed coin")

#-----------------------------------------------------------------------------
# A REDRAW
#-----------------------------------------------------------------------------

func test_a_redraw_keeps_its_coins() -> void:
	var markers: AdventureMapMarkers = _markers()
	assert_not_null(markers, "the map has a coin layer")
	if markers == null:
		return
	_start()
	_tilemap.set_dev_reveal_all(true)
	var rest: EncounterCoin = _coin(REST)
	assert_not_null(rest)

	markers.rebuild()

	assert_same(_coin(REST), rest, "the same coin is kept, not rebuilt")
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
	assert_null(_coin(START), "the visited start tile has none")
	assert_null(_coin(OPEN_NEAR), "nor the visited empty tile the player stands on")
	assert_null(_coin(OPEN_FAR), "nor an empty tile the override reveals")

	_tilemap.set_dev_reveal_all(false)

	assert_eq(_faces(), normal_faces, "off: the same coins as before")
	assert_eq(_positions(), normal_positions, "in the same places")
	assert_eq(_fog(), normal_fog, "and the same fog")
	assert_null(_coin(BOSS), "the boss is fog again")

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
