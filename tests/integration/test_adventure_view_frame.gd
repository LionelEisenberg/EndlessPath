extends GutTest

## Integration tests for the lacquer frame of the adventure view (spec: Scene
## tree, Signal map, Data flow): AdventureView with the vitals cabinet
## (VitalsPlate), the chest (AdventureChest: title, run clock, expedition page)
## and the technique dock (TechniqueDock), wired to the real map
## (AdventureTilemap), the real fight (AdventureCombat) and the run's Timer.
## The view is instanced as test_adventure_end_flow.gd does, on a canvas layer
## above GUT's own window so that a press reaches it, and each run starts the
## way the zone starts one, through ActionManager, on a fixed map: the tilemap
## is handed a generator that returns the shared fixture map
## (AdventureMapFixture) or the map a test builds, so no test generates a random
## one. Wiring is tested by emitting the map's signals. Walks are real, and so
## is the pointer where the map reads it: a press, a hover and the pointer
## leaving the map for a board.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const AdventureViewScene := preload("res://scenes/adventure/adventure_view/adventure_view.tscn")
const AdventureMapFixture := preload("res://tests/integration/adventure_map_fixture.gd")
const AMORPHOUS_SPIRIT_ENCOUNTER: AdventureEncounter = preload("res://resources/adventure/encounters/shallow_woods/combat_encounters/regular/amorphous_spirit_encounter.tres")
const CRUDE_SCALE: ItemDefinitionData = preload("res://resources/items/consumables/crude_scale.tres")
const ENFORCE_ICON: Texture2D = preload("res://assets/sprites/abilities/enforce.png")
const ADVENTURE_ACTION := AdventureMapFixture.ADVENTURE_ACTION

# The fixture map's tiles (see AdventureMapFixture).
const START := AdventureMapFixture.START
const FIGHT := AdventureMapFixture.FIGHT
const OPEN_NEAR := AdventureMapFixture.OPEN_NEAR
const REST := AdventureMapFixture.REST

const Slot := TechniqueSlot.SlotState

## The Madra the zone's drain hands each run in these tests.
const MADRA_BUDGET: float = 50.0
## The Shallow Woods' time limit, in seconds.
const TIME_LIMIT: float = 300.0
## A run this short shows the clock's low seal from its start.
const SHORT_TIME_LIMIT: int = 20
## GUT draws its own window on this canvas layer, over the whole screen; the
## view goes above it, or GUT's window would take every press.
const GUT_LAYER: int = 128
## The player's vitals a run changes, remembered and put back.
const VITALS_FIELDS: Array[StringName] = [
	&"max_health", &"current_health", &"max_madra", &"current_madra",
	&"max_stamina", &"current_stamina", &"health_regen", &"madra_regen", &"stamina_regen",
]
## How far past the border between two hexes a walk must be to stand in the
## second one, in px of distance difference (twice the distance past it).
const PAST_THE_BORDER: float = 8.0
## One 60 FPS frame, for stepping the walk, the tweens and the shakes by hand.
const FRAME: float = 1.0 / 60.0

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
	# A leftover from when the project's hex layer skipped the addon's own set-up:
	# the layer now sets itself up in its own _ready(), so this re-emit of the
	# shared TileSet's `changed` is no longer needed. It is harmless.
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

## Hands out a map it was given in place of a generated one. A random Shallow
## Woods map fails its critical-path check five times in a row now and then, and
## the error that logs fails the test it lands in.
class FixedMapGenerator extends AdventureMapGenerator:
	var map: Dictionary[Vector3i, AdventureEncounter] = {}

	## Returns the given map.
	func generate_adventure_map() -> Dictionary[Vector3i, AdventureEncounter]:
		return map

## Starts the Shallow Woods the way the zone does once its Madra drain ends: the
## action becomes the current one and the run is confirmed with its budget. The
## run plays on `_map` (the fixture map, unless the test set another): the
## tilemap is handed a generator that returns it, so no random map is generated
## and none can fail. A time limit of 0 keeps the action's own.
func _start_run(time_limit_seconds: int = 0) -> void:
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var generator := FixedMapGenerator.new()
	generator.map = _map
	tilemap.adventure_map_generator.free()
	tilemap.adventure_map_generator = generator
	var action: AdventureActionData = ADVENTURE_ACTION.duplicate()
	if time_limit_seconds > 0:
		action.time_limit_seconds = time_limit_seconds
	ActionManager._set_current_action(action)
	ActionManager.confirm_adventure_start(action, MADRA_BUDGET)

func _stop_every_action() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

## Moves every running tween in the tree on by `delta`, as a frame does: the
## Stamina row's shake, the boss reveal's push.
func _step_tweens(delta: float) -> void:
	for tween: Tween in get_tree().get_processed_tweens():
		if tween.is_valid() and tween.is_running():
			tween.custom_step(delta)

## One 60 FPS frame stepped by hand, in the tree's order: the character's
## physics step (the walk), the camera following it (the tree's transform update),
## then the tweens. The walk is taken off the physics clock, so only the test
## moves it.
func _step_frame() -> void:
	var character: CharacterBody2D = _view.adventure_tilemap.character_body
	character.set_physics_process(false)
	simulate(character, 1, FRAME)
	(character.get_node("Camera2D") as Camera2D).force_update_scroll()
	_step_tweens(FRAME)

## Steps `seconds` of 60 FPS frames.
func _run(seconds: float) -> void:
	for _frame: int in roundi(seconds / FRAME):
		_step_frame()

## Steps frames until the character ends the hop it is on, then lets a frame run,
## so what the tree does at the end of a frame (a hover laid again) has caught up.
## Returns whether the hop ended.
func _wait_for_hop() -> bool:
	var character: CharacterBody2D = _view.adventure_tilemap.character_body
	var ended: Array[bool] = [false]
	var on_end := func() -> void: ended[0] = true
	character.movement_completed.connect(on_end, CONNECT_ONE_SHOT)
	for _frame: int in roundi(AdventureMapFixture.HOP_TIMEOUT_SECONDS / FRAME):
		if ended[0]:
			break
		_step_frame()
	if not ended[0]:
		character.movement_completed.disconnect(on_end)
	await get_tree().process_frame
	return ended[0]

## Clicks a tile the way the map layer reports a click, then steps frames until
## the character's first hop ends: the whole walk, for a tile next door.
func _walk_to(coord: Vector3i) -> void:
	AdventureMapFixture.click(_view.adventure_tilemap, coord)
	var arrived: bool = await _wait_for_hop()
	assert_true(arrived, "the walk to %s ends in time" % coord)

## Clicks `to`, two hops away through `through`, and returns once the first hop
## has crossed into `through`'s hex, while the character still walks.
func _walk_partway(through: Vector3i, to: Vector3i) -> void:
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var from_centre: Vector2 = tilemap.get_tile_world_centre(tilemap.get_current_tile())
	var through_centre: Vector2 = tilemap.get_tile_world_centre(through)
	AdventureMapFixture.click(tilemap, to)
	for frame: int in 120:
		_step_frame()
		var at: Vector2 = tilemap.character_body.global_position
		if at.distance_to(through_centre) + PAST_THE_BORDER < at.distance_to(from_centre):
			break
	var at_end: Vector2 = tilemap.character_body.global_position
	assert_lt(at_end.distance_to(through_centre) + PAST_THE_BORDER, at_end.distance_to(from_centre), "precondition: the first hop crossed into %s's hex" % through)
	assert_true(tilemap.character_body.is_moving, "precondition: the walk is under way")
	await get_tree().process_frame

## Moves the real pointer to a point in the viewport, as the player's mouse
## would. The map's hex layers find the hex under a press from the pointer, not
## from the press, so a press meant for the map needs the pointer there.
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

## A left press and its release at a point in the viewport's own 1920x1080
## space: the headless window is scaled down, so the events go in local
## coordinates.
func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		get_viewport().push_input(event, true)

## The cube coordinate of the map cell under a point of the screen. The map's
## viewport fills the screen from its top-left corner, unstretched.
func _cube_under(point: Vector2) -> Vector3i:
	var layer: HexagonTileMapLayer = _view.adventure_tilemap.visible_map
	return layer.map_to_cube(layer.local_to_map(layer.get_global_transform_with_canvas().affine_inverse() * point))

## The tile source drawn in the map cell under a point of the screen, -1 for
## none.
func _drawn_source_under(point: Vector2) -> int:
	var layer: HexagonTileMapLayer = _view.adventure_tilemap.visible_map
	return layer.get_cell_source_id(layer.local_to_map(layer.get_global_transform_with_canvas().affine_inverse() * point))

## Where a tile's centre is drawn on the screen. The map's viewport fills the
## screen from its top-left corner, unstretched.
func _screen_point_of(coord: Vector3i) -> Vector2:
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	return tilemap.get_global_transform_with_canvas() * tilemap.get_tile_world_centre(coord)

## A point on the vitals cabinet: a board that covers the map's container, so the
## pointer there is off the map.
func _on_a_board() -> Vector2:
	return _view.vitals_plate.get_global_rect().get_center()

func _hover_rim() -> Sprite2D:
	return _view.adventure_tilemap.get_node("%HoverRim") as Sprite2D

func _route() -> AdventureRoute:
	return _view.adventure_tilemap.get_node("%AdventureRoute") as AdventureRoute

## The route dots of the one hop between two neighbouring tiles, as AdventureRoute lays them.
func _dots_between(from: Vector3i, to: Vector3i) -> PackedVector2Array:
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	return ZoneRoute.dot_positions(tilemap.get_tile_world_centre(from), tilemap.get_tile_world_centre(to))

## The route dots of a walk through the tiles, hop by hop.
func _dots_through(coords: Array[Vector3i]) -> PackedVector2Array:
	var dots := PackedVector2Array()
	for index: int in range(1, coords.size()):
		dots.append_array(_dots_between(coords[index - 1], coords[index]))
	return dots

## Starts the run on the fixture map and stands the player on OPEN_NEAR with the
## Stamina for one hop only, so that a walk to FIGHT, two hops through START,
## stops at START. Stamina does not regenerate while the test walks.
func _stand_on_open_near_with_one_hop_of_stamina() -> void:
	_start_run()
	await _walk_to(OPEN_NEAR)
	await wait_process_frames(2)
	PlayerManager.vitals_manager.stamina_regen = 0.0
	PlayerManager.vitals_manager.current_stamina = AdventureTilemap.MOVEMENT_STAMINA_COST

## Steps frames until the walk's first hop ends, where the Stamina stop is.
func _wait_for_the_stamina_stop() -> void:
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var stopped: bool = await _wait_for_hop()
	assert_true(stopped, "precondition: the first hop ends in time")
	assert_eq(tilemap.get_current_tile(), START, "precondition: the walk stopped partway, on START")
	assert_false(tilemap.character_body.is_moving, "precondition: and does not go on")

func _page() -> ExpeditionPage:
	return _view.adventure_chest.get_expedition_page()

func _page_text(unique_name: String) -> String:
	return (_page().get_node("%" + unique_name) as Label).text

func _page_shows(unique_name: String) -> bool:
	return (_page().get_node("%" + unique_name) as CanvasItem).visible

func _plate_text(unique_name: String) -> String:
	return (_view.vitals_plate.get_node("%" + unique_name) as Label).text.strip_edges()

## Whether the cabinet's buff socket at index (0 to 2) shows.
func _buff_socket_shows(index: int) -> bool:
	return (_view.vitals_plate.get_node("%%BuffSocket%d" % (index + 1)) as CanvasItem).visible

func _chest_title() -> String:
	return (_view.adventure_chest.get_node("%TitleLabel") as Label).text

func _clock_text() -> String:
	return (_view.adventure_chest.get_run_clock().get_node("%TimeLabel") as Label).text

## The four slots' states, Q to R.
func _slot_states() -> Array:
	var states: Array = []
	for index: int in 4:
		states.append(_view.technique_dock.get_slot(index).get_state())
	return states

## What the dock shows on the map: each equipped technique in its loadout slot,
## the rest empty.
func _loadout_states() -> Array:
	var states: Array = []
	for index: int in 4:
		states.append(Slot.PREVIEW if AbilityManager.get_ability_at_slot(index) != "" else Slot.EMPTY)
	return states

func _markers() -> AdventureMapMarkers:
	return _view.adventure_tilemap.get_node("%AdventureMapMarkers") as AdventureMapMarkers

## The coins the map's seen tiles call for, by the coin layer's own rule.
func _tiles_needing_coins() -> Array[Vector3i]:
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var tiles: Array[Vector3i] = []
	for coord: Vector3i in tilemap.get_seen_tiles():
		var visited: bool = tilemap.is_tile_visited(coord)
		var dev_revealed: bool = tilemap.is_dev_reveal_all() and not visited
		if EncounterCoin.needs_coin(tilemap.get_encounter_at(coord), visited, dev_revealed):
			tiles.append(coord)
	return tiles

## A buff the player might cast on themselves (Enforce's kind: it stacks).
func _make_buff() -> BuffEffectData:
	var buff := BuffEffectData.new()
	buff.buff_id = "enforce"
	buff.buff_icon = ENFORCE_ICON
	buff.duration = 20.0
	buff.buff_type = BuffEffectData.BuffType.OUTGOING_DAMAGE_MODIFIER
	buff.damage_multiplier = 1.5
	return buff

## Ends the first slot's opening cooldown for real, then uses its technique as
## an accepted press does: its cast starts and the cast tray shows.
func _cast_the_first_technique() -> void:
	var instance: CombatAbilityInstance = _view.technique_dock.get_slot(0).get_ability_instance()
	assert_not_null(instance, "precondition: the first slot holds a technique in the fight")
	instance.cooldown_timer.start(0.01)
	var ready: bool = await wait_for_signal(instance.cooldown_ready, 1.0)
	assert_true(ready, "precondition: its opening cooldown ended")
	_view.technique_dock.ability_selected.emit(instance)

func _remember_vitals() -> Dictionary[StringName, float]:
	var saved: Dictionary[StringName, float] = {}
	for field: StringName in VITALS_FIELDS:
		saved[field] = PlayerManager.vitals_manager.get(field)
	return saved

func _restore_vitals(saved: Dictionary[StringName, float]) -> void:
	for field: StringName in saved:
		PlayerManager.vitals_manager.set(field, saved[field])

## What a run shows right after its start, whatever the last one ended in
## (plan Review Focus 1): the dock previewing the loadout with no cast tray,
## no buff, the map and the chest on the new start tile, the clock at the new
## run's full time without the low seal, and only the new map's coins.
func _assert_a_clean_start() -> void:
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	assert_false(_view.technique_dock.is_active(), "the dock takes no presses")
	assert_eq(_slot_states(), _loadout_states(), "it previews the loadout")
	assert_false(_view.technique_dock.get_cast_tray().visible, "no cast tray")
	assert_false(_buff_socket_shows(0), "no buff in the cabinet")
	assert_true(_view.tilemap_view.visible, "the map shows")
	assert_false(_view.combat_view.visible, "the fight is gone")
	assert_eq(tilemap.get_current_tile(), START, "the run stands on its start tile")
	assert_eq(tilemap.get_visited_tile_count(), 1, "and has visited only that")
	assert_eq(_page_text("NameLabel"), "Open ground", "the chest is on the new start tile")
	assert_false(_page().get_drawer(0).visible, "with no drawer")
	var timer: Timer = _view.get_run_timer()
	assert_false(timer.is_stopped(), "the clock runs")
	assert_almost_eq(timer.time_left, TIME_LIMIT, 1.0, "from the new run's full time")
	assert_has(["5:00", "4:59"], _clock_text(), "and the chest reads it")
	assert_false(_view.adventure_chest.get_run_clock().is_low_shown(), "without the last run's low seal")
	var needing: Array[Vector3i] = _tiles_needing_coins()
	assert_gt(needing.size(), 0, "precondition: the new start tile has neighbours in view")
	assert_eq(_markers().get_coin_count(), needing.size(), "only the new map's coins")
	for coord: Vector3i in needing:
		assert_not_null(_markers().get_coin(coord), "%s has its coin" % coord)

#-----------------------------------------------------------------------------
# THE FRAME
#-----------------------------------------------------------------------------

## The three boards stand where the zone view keeps its cabinet, chest and dock,
## over the map and the fight, each taking the pointer.
func test_boards_stand_over_the_map_where_the_zone_furniture_stands() -> void:
	var boards: Dictionary[String, Vector2] = {
		"VitalsPlate": Vector2(24, 24),
		"AdventureChest": Vector2(1456, 24),
		"TechniqueDock": Vector2(722, 920),
	}
	var combat_index: int = _view.combat_view.get_index()
	assert_gt(combat_index, _view.tilemap_view.get_index(), "precondition: the fight draws over the map")
	for board_name: String in boards:
		var board: Control = _view.get_node_or_null("%" + board_name) as Control
		assert_not_null(board, "%s is in the view" % board_name)
		if board == null:
			continue
		assert_eq(board.get_parent(), _view, "%s is the view's own child" % board_name)
		assert_eq(board.position, boards[board_name], "%s stands in its place" % board_name)
		assert_gt(board.get_index(), combat_index, "%s draws over the map and the fight" % board_name)
		assert_eq(board.mouse_filter, Control.MOUSE_FILTER_STOP, "%s takes the pointer" % board_name)
	assert_same(_view.vitals_plate, _view.get_node("%VitalsPlate"))
	assert_same(_view.adventure_chest, _view.get_node("%AdventureChest"))
	assert_same(_view.technique_dock, _view.get_node("%TechniqueDock"))
	var timer: Timer = _view.get_node_or_null("%RunTimer") as Timer
	assert_not_null(timer, "the run's Timer is the view's")
	assert_same(_view.get_run_timer(), timer)
	if timer != null:
		assert_true(timer.one_shot, "it runs out once")

func test_start_fills_the_frame() -> void:
	# What a run has to change: a title left from before, and a loadout changed
	# since the dock last looked (it previews what is equipped when a run starts).
	_view.adventure_chest.set_title("")
	AbilityManager.unlock_ability("empty_palm")
	AbilityManager.equip_ability_at_slot("empty_palm", 2)
	assert_eq(_view.technique_dock.get_slot(2).get_state(), Slot.EMPTY, "precondition: the dock has not seen the new technique")

	_start_run()
	await wait_process_frames(1)

	assert_eq(_chest_title(), "The Shallow Woods", "the run's name heads the chest")
	var timer: Timer = _view.get_run_timer()
	assert_false(timer.is_stopped(), "the run's clock runs")
	assert_almost_eq(timer.time_left, TIME_LIMIT, 1.0, "from the action's time limit")
	assert_has(["5:00", "4:59"], _clock_text(), "the chest's clock reads the run's Timer")
	assert_eq(_plate_text("MadraValueLabel"), "50", "the cabinet holds the Madra the zone handed the run")
	assert_false(_view.technique_dock.is_active(), "the dock takes no presses on the map")
	assert_eq(_slot_states(), [Slot.PREVIEW, Slot.PREVIEW, Slot.PREVIEW, Slot.EMPTY], "it previews the loadout as the run starts")
	assert_eq(_page_text("NameLabel"), "Open ground", "the chest stands on the start tile")

#-----------------------------------------------------------------------------
# THE MAP AND THE CHEST
#-----------------------------------------------------------------------------

func test_arrival_fills_the_here_tray() -> void:
	_start_run()
	var encounter: AdventureEncounter = AMORPHOUS_SPIRIT_ENCOUNTER

	_view.adventure_tilemap.tile_entered.emit(FIGHT, encounter, true, "")

	assert_eq(_page_text("NameLabel"), "Amorphous Spirit Attacks!", "the Here tray names the tile's encounter")
	assert_true(_page_shows("Tag"), "with a tag")
	assert_eq(_page_text("TagLabel"), "FIGHT", "for its kind")
	assert_eq(_page_text("LineLabel"), "Fight · Amorphous Spirit", "and its line")
	var drawer: ChoiceDrawer = _page().get_drawer(0)
	assert_true(drawer.visible, "a drawer offers its choice")
	assert_eq((drawer.get_node("%Title") as Label).text, "Attack the Spirit")
	assert_eq(_chest_title(), "The Shallow Woods", "the chest keeps the run's name")

func test_resolution_shows_cleared() -> void:
	_start_run()
	await _walk_to(REST)
	assert_eq(_page_text("TagLabel"), "REST", "precondition: the rest waits for a choice")

	_view.adventure_tilemap.select_choice(AdventureMapFixture.rest_choice(_map))

	assert_eq(_page_text("TagLabel"), "CLEARED", "the Here tray reads cleared")
	assert_eq(_page_text("LineLabel"), "+10 Health", "with what the tile left behind")
	assert_eq(_page_text("LoreLabel"), "Encounter completed.", "under it the completed text")
	assert_false(_page().get_drawer(0).visible, "the choice is spent")
	# A resolution elsewhere on the map leaves the tray alone.
	_view.adventure_tilemap.encounter_resolved.emit(FIGHT, "Won · 99 gold")
	assert_eq(_page_text("LineLabel"), "+10 Health", "only the tile the player stands on shows")

func test_walk_refused_shakes_the_right_board() -> void:
	_start_run()

	_view.adventure_tilemap.walk_refused.emit(AdventureTilemap.REFUSED_STAMINA)

	assert_true(_view.vitals_plate.is_stamina_shaking(), "too tired: the cabinet's Stamina row shakes")
	assert_false(_page().is_here_shaking(), "not the Here tray")
	_run(MapGlyph.SHAKE_SECONDS + 0.1)
	assert_false(_view.vitals_plate.is_stamina_shaking(), "precondition: the shake is over")

	_view.adventure_tilemap.walk_refused.emit(AdventureTilemap.REFUSED_ENCOUNTER)

	assert_true(_page().is_here_shaking(), "a choice waits: the Here tray shakes")
	assert_false(_view.vitals_plate.is_stamina_shaking(), "not the Stamina row")

## The whole refusal, end to end: standing on a rest that waits for a choice, a
## click on another tile is refused. The Here tray shakes and the lock line, which
## says the choices hold the player, turns to the warning colour for the length of
## the shake and then back.
func test_a_refused_click_turns_the_lock_line_to_the_warning_colour_and_back() -> void:
	_start_run()
	await _walk_to(REST)
	var lock := _page().get_node("%LockLine") as Label
	assert_true(lock.is_visible_in_tree(), "precondition: the rest holds the player, and the line says so")
	assert_eq(lock.text, ExpeditionPage.LOCK_LINE)
	assert_false(lock.has_theme_color_override(&"font_color"), "precondition: its own tan")

	AdventureMapFixture.click(_view.adventure_tilemap, OPEN_NEAR)

	assert_true(_page().is_here_shaking(), "the refused click shakes the Here tray")
	assert_eq(lock.get_theme_color(&"font_color"), ExpeditionPage.LOCK_WARNING_COLOUR, "and turns the lock line to the warning colour")
	# The Here tray's shake runs in the page's _process: run it a frame at a time.
	simulate(_page(), roundi((MapGlyph.SHAKE_SECONDS + 0.15) / FRAME), FRAME)
	assert_false(_page().is_here_shaking(), "precondition: the shake is over")
	assert_false(lock.has_theme_color_override(&"font_color"), "the line is its own colour again")

## Once the choice is made the lock line goes and the walk hint takes its place.
func test_resolving_the_tile_swaps_the_lock_line_for_the_walk_hint() -> void:
	_start_run()
	await _walk_to(REST)
	assert_true((_page().get_node("%LockLine") as Label).is_visible_in_tree(), "precondition: the lock line shows")
	assert_false((_page().get_node("%WalkHint") as Label).is_visible_in_tree())

	_view.adventure_tilemap.select_choice(AdventureMapFixture.rest_choice(_map))

	assert_false((_page().get_node("%LockLine") as Label).is_visible_in_tree(), "the tile lets go of the player")
	assert_true((_page().get_node("%WalkHint") as Label).is_visible_in_tree(), "and the walk hint shows")

## A real press on the rest's drawer: the chest hands the choice to the map,
## which resolves the tile.
func test_choice_from_the_chest_reaches_the_tilemap() -> void:
	_start_run()
	await _walk_to(REST)
	# The page's containers place the new drawers at the end of the frame.
	await wait_process_frames(2)
	var drawer: ChoiceDrawer = _page().get_drawer(0)
	assert_true(drawer.is_visible_in_tree(), "precondition: the rest's drawer shows")

	_click(drawer.get_global_rect().get_center())

	assert_true(_view.adventure_tilemap.is_tile_completed(REST), "the press resolved the tile")
	assert_eq(_view.adventure_tilemap.get_tile_summary(REST), "+10 Health", "with the rest's own choice")
	assert_eq(_page_text("TagLabel"), "CLEARED", "and the chest says so")

## Presses on the cabinet, the chest and the dock stay on the boards: the map
## lives in its own viewport, which hears a press only through its container,
## and the boards draw over it and take the pointer. Each press goes in through
## the viewport with the real pointer on it, since the hex under a press is read
## from the pointer: the same presses with the boards hidden prove each would
## otherwise have clicked a hex.
func test_press_on_a_board_does_not_reach_the_map() -> void:
	await wait_process_frames(2)
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var boards: Array[Control] = [_view.vitals_plate, _view.adventure_chest, _view.technique_dock]
	var points: Array[Vector2] = []
	for board: Control in boards:
		points.append(board.get_global_rect().get_center())
	# A map with a tile under each press, every tile shown (the dev panel's Show
	# Whole Map), so that each press is over a drawn hex that would take it. The
	# camera stands where the run will start, so the tiles are found before it.
	_map = {START: NoOpEncounter.new()}
	for point: Vector2 in points:
		_map[_cube_under(point)] = NoOpEncounter.new()
	_start_run()
	_view.set_show_whole_map(true)
	await wait_process_frames(2)
	for index: int in points.size():
		assert_true(boards[index].get_global_rect().has_point(points[index]), "precondition: press %d is on its board" % index)
		assert_ne(_drawn_source_under(points[index]), -1, "precondition: a drawn hex lies under press %d" % index)
	var standing_at: Vector2 = tilemap.character_body.global_position
	watch_signals(tilemap.visible_map)

	for point: Vector2 in points:
		await _move_pointer_to(point)
		_click(point)

	assert_signal_not_emitted(tilemap.visible_map, "tile_clicked", "a press on a board stays on the board")
	await wait_physics_frames(5)
	assert_false(tilemap.character_body.is_moving, "the player does not set off")
	assert_eq(tilemap.character_body.global_position, standing_at, "and stays put")
	assert_eq(tilemap.get_current_tile(), START)
	# The same presses, the boards out of the way, land on the hexes.
	for board: Control in boards:
		board.hide()
	for point: Vector2 in points:
		await _move_pointer_to(point)
		_click(point)
	assert_signal_emit_count(tilemap.visible_map, "tile_clicked", points.size(), "with no board over them, the hexes take the presses")

func test_map_viewport_filters_nearest() -> void:
	var map_viewport: Viewport = _view.adventure_tilemap.get_viewport()
	assert_true(map_viewport is SubViewport, "precondition: the map draws in its own viewport")
	assert_eq(map_viewport.canvas_item_default_texture_filter, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "the 1x tiles and the 2x character stay sharp")

func test_old_hud_is_gone() -> void:
	for old_name: String in ["PlayerHud", "TimerPanel", "EncounterInfoPanel"]:
		assert_null(_view.get_node_or_null("%" + old_name), "no %%%s in the view" % old_name)
		assert_null(_view.adventure_tilemap.get_node_or_null("%" + old_name), "nor in the map")
		assert_eq(_view.find_children(old_name, "", true, false).size(), 0, "no %s anywhere under the view" % old_name)

#-----------------------------------------------------------------------------
# THE POINTER OVER THE MAP
#-----------------------------------------------------------------------------

## The map's viewport hears the pointer only through its container, so the hex
## layer never reports the pointer leaving a tile for a board that covers the
## container. The container's mouse_exited clears the hover instead (the rim and
## the hovered route), and the hex layer forgets the tile, so coming straight
## back onto it hovers it again. The pointer really moves, as in
## test_press_on_a_board_does_not_reach_the_map.
func test_the_hover_goes_when_the_pointer_moves_onto_a_board() -> void:
	_start_run()
	await wait_process_frames(2)
	var over_fight: Vector2 = _screen_point_of(FIGHT)
	await _move_pointer_to(over_fight)
	assert_true(_hover_rim().visible, "precondition: the pointer over a tile in view shows the rim")
	assert_eq(_route().get_dot_positions(), _dots_between(START, FIGHT), "precondition: and the route to it")

	await _move_pointer_to(_on_a_board())

	assert_false(_hover_rim().visible, "off the map, onto a board: no rim")
	assert_eq(_route().get_dot_positions().size(), 0, "and no route")

	await _move_pointer_to(over_fight)

	assert_true(_hover_rim().visible, "back onto the same tile: it hovers again")
	assert_eq(_hover_rim().position, _view.adventure_tilemap.get_tile_world_centre(FIGHT), "on that tile")
	assert_eq(_route().get_dot_positions(), _dots_between(START, FIGHT), "with its route")

## Only the hover goes with the pointer: a walk the player committed to keeps its
## rim and its route, which belong to the walk.
func test_a_committed_walk_keeps_its_rim_and_route_when_the_pointer_leaves_the_map() -> void:
	_start_run()
	await wait_process_frames(2)
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var over_fight: Vector2 = _screen_point_of(FIGHT)
	await _move_pointer_to(over_fight)
	_click(over_fight)
	assert_true(tilemap.character_body.is_moving, "precondition: the press set the walk off")

	await _move_pointer_to(_on_a_board())

	assert_true(_hover_rim().visible, "the walk's rim stays on its destination")
	assert_eq(_hover_rim().position, tilemap.get_tile_world_centre(FIGHT))
	assert_eq(_route().get_dot_positions(), _dots_between(START, FIGHT), "and so does its route")

## A walk stopped for Stamina drops its committed rim and route. What the hover
## shows then is what a fresh move of the pointer onto the cell it rests over
## would show: the rim on that tile and the route to it from where the walk
## stopped. The camera follows the character to START, a hex from where it
## stood, so the pointer rests where REST will be once it has. (The pointer has
## been over a board and come back, so the map knows it is on the map again.)
func test_a_stamina_stop_lays_the_hover_for_the_tile_under_the_pointer() -> void:
	await _stand_on_open_near_with_one_hop_of_stamina()
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var where_rest_will_be: Vector2 = _screen_point_of(OPEN_NEAR) + tilemap.get_tile_world_centre(REST) - tilemap.get_tile_world_centre(START)
	await _move_pointer_to(_screen_point_of(START))
	await _move_pointer_to(_on_a_board())
	await _move_pointer_to(where_rest_will_be)
	AdventureMapFixture.click(tilemap, FIGHT)
	assert_true(tilemap.character_body.is_moving, "precondition: the click set the walk off")

	await _wait_for_the_stamina_stop()

	assert_true(_hover_rim().visible, "the rim is on the tile under the pointer")
	assert_eq(_hover_rim().position, tilemap.get_tile_world_centre(REST), "not on the walk's unreached destination")
	assert_eq(_route().get_dot_positions(), _dots_between(START, REST), "and the route runs to it from where the walk stopped")

## The natural case: the player hovers FIGHT and presses, the walk stops at
## START, and the camera has moved a hex under the pointer, which now rests over
## no tile in view. The rim must not stay up on FIGHT with no route to it.
func test_a_stamina_stop_leaves_no_rim_behind_when_the_pointer_is_over_no_tile() -> void:
	await _stand_on_open_near_with_one_hop_of_stamina()
	var over_fight: Vector2 = _screen_point_of(FIGHT)
	await _move_pointer_to(over_fight)
	_click(over_fight)
	assert_true(_view.adventure_tilemap.character_body.is_moving, "precondition: the press set the walk off")

	await _wait_for_the_stamina_stop()

	assert_false(_hover_rim().visible, "no rim on the unreached destination")
	assert_eq(_route().get_dot_positions().size(), 0, "and no route")
	# The hex layer was told the pointer rests over no tile, so moving it onto
	# FIGHT, which the layer last heard it over, hovers FIGHT.
	await _move_pointer_to(_screen_point_of(FIGHT))
	assert_true(_hover_rim().visible, "the pointer onto a tile in view hovers it, FIGHT included")
	assert_eq(_hover_rim().position, _view.adventure_tilemap.get_tile_world_centre(FIGHT))

## With the pointer off the map (over a board), there is no hover to lay.
func test_a_stamina_stop_leaves_no_hover_with_the_pointer_off_the_map() -> void:
	await _stand_on_open_near_with_one_hop_of_stamina()
	var over_fight: Vector2 = _screen_point_of(FIGHT)
	await _move_pointer_to(over_fight)
	_click(over_fight)
	await _move_pointer_to(_on_a_board())
	assert_true(_hover_rim().visible, "precondition: the committed walk's rim stays up while it goes on")

	await _wait_for_the_stamina_stop()

	assert_false(_hover_rim().visible, "no rim")
	assert_eq(_route().get_dot_positions().size(), 0, "and no route")

## One rule holds after any walk ends: the hover shows what a fresh move of the
## pointer onto the cell it rests over would show. A walk that ends at its
## destination drops its rim and dots, and the camera, which followed the
## character, has moved under the still pointer, so the pointer rests over
## another tile in view. The hover for that tile takes the walk's place, with
## the route from where the walk ended. The pointer rests where FIGHT will be
## once the camera has followed the character to OPEN_NEAR, a hex away.
func test_a_walk_that_ends_lays_the_hover_for_the_tile_under_the_pointer() -> void:
	_start_run()
	await wait_process_frames(2)
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var where_fight_will_be: Vector2 = _screen_point_of(START) + tilemap.get_tile_world_centre(FIGHT) - tilemap.get_tile_world_centre(OPEN_NEAR)
	await _move_pointer_to(where_fight_will_be)
	assert_false(_hover_rim().visible, "precondition: before the walk the pointer rests over no tile")

	await _walk_to(OPEN_NEAR)

	assert_eq(tilemap.get_current_tile(), OPEN_NEAR, "precondition: the walk ended at its destination")
	assert_true(_hover_rim().visible, "the rim is on the tile under the pointer")
	assert_eq(_hover_rim().position, tilemap.get_tile_world_centre(FIGHT))
	var through_start: Array[Vector3i] = [OPEN_NEAR, START, FIGHT]
	assert_eq(_route().get_dot_positions(), _dots_through(through_start), "and the route runs to it from where the walk ended")

## While a choice waits, a fresh move of the pointer hovers nothing, so a walk
## that ends on an encounter lays no hover under the pointer either, though the
## pointer rests over a tile in view (START, once the camera is on FIGHT).
func test_a_walk_that_ends_on_an_encounter_lays_no_hover_under_the_pointer() -> void:
	_start_run()
	await wait_process_frames(2)
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var where_start_will_be: Vector2 = _screen_point_of(START) + tilemap.get_tile_world_centre(START) - tilemap.get_tile_world_centre(FIGHT)
	await _move_pointer_to(where_start_will_be)

	await _walk_to(FIGHT)

	assert_eq(tilemap.get_current_tile(), FIGHT, "precondition: the walk ended on the encounter")
	assert_false(_hover_rim().visible, "a choice waits: no rim")
	assert_eq(_route().get_dot_positions().size(), 0, "and no route")

#-----------------------------------------------------------------------------
# THE FIGHT AND THE RUN
#-----------------------------------------------------------------------------

func test_fight_binds_the_dock_and_buffs() -> void:
	_start_run()
	await _walk_to(FIGHT)

	_view.adventure_tilemap.select_choice(AdventureMapFixture.fight_choice(_map))

	var player: CombatantNode = _view.combat.player_combatant
	assert_not_null(player, "precondition: the fight started")
	if player == null:
		return
	assert_true(_view.technique_dock.is_active(), "the dock takes the fight's presses")
	for index: int in 4:
		if AbilityManager.get_ability_at_slot(index) == "":
			continue
		assert_has(player.ability_manager.abilities, _view.technique_dock.get_slot(index).get_ability_instance(), "slot %d holds the player's technique" % index)
	assert_true(_view.technique_dock.ability_selected.is_connected(_view.combat.on_player_ability_selected), "a press reaches the fight")
	player.buff_manager.apply_buff(_make_buff())
	assert_true(_buff_socket_shows(0), "the cabinet shows the player's buffs")

	_view.combat.trigger_combat_end.emit(true, 15)

	assert_false(_view.technique_dock.is_active(), "back on the map the dock takes no presses")
	assert_eq(_slot_states(), _loadout_states(), "and previews the loadout again")
	assert_false(_view.technique_dock.ability_selected.is_connected(_view.combat.on_player_ability_selected), "a press reaches no fight")
	assert_false(_buff_socket_shows(0), "the cabinet lets the buffs go")

func test_run_stats_follow_the_run() -> void:
	_start_run()
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var fights_total: int = tilemap.get_total_combat_count()
	var tiles_total: int = tilemap.get_total_tile_count()
	assert_eq(_page_text("FightsValue"), "0 / %d" % fights_total, "a new run has won no fight")
	assert_eq(_page_text("ExploredValue"), "1 / %d" % tiles_total, "and stands on its first tile")
	await _walk_to(FIGHT)
	assert_eq(_page_text("ExploredValue"), "2 / %d" % tiles_total, "every new tile counts")
	tilemap.select_choice(AdventureMapFixture.fight_choice(_map))
	watch_signals(_view)

	_view.combat.trigger_combat_end.emit(true, 15)

	assert_signal_emitted(_view, "run_stats_changed", "a fight's end changes the run's figures")
	assert_eq(_page_text("FightsValue"), "1 / %d" % fights_total, "the won fight counts")
	assert_eq(_page_text("GoldValue"), "15", "with its gold")
	var first_loot: TextureRect = _page().get_node("%LootIcon1") as TextureRect
	assert_false(first_loot.visible, "precondition: no loot yet")

	InventoryManager.award_items(CRUDE_SCALE, 1)

	assert_true(first_loot.visible, "an item the run awards shows in the ledger")
	assert_eq(first_loot.texture, CRUDE_SCALE.icon)

## The boss win ends the run inside the fight's end, with no redraw of the map
## after it: the ledger still counts that fight and its gold, and the run's
## teardown (which clears the map) leaves the run's last figures standing.
func test_the_ledger_keeps_the_runs_last_figures() -> void:
	_start_run()
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	await _walk_to(FIGHT)
	tilemap.select_choice(AdventureMapFixture.fight_choice(_map))
	_view.combat.trigger_combat_end.emit(true, 15)
	await _walk_to(AdventureMapFixture.BOSS)
	tilemap.select_choice(_map[AdventureMapFixture.BOSS].choices[0])
	watch_signals(_view)

	_view.combat.trigger_combat_end.emit(true, 40)

	assert_signal_emitted(_view, "adventure_completed", "precondition: the boss win ended the run")
	assert_eq(_page_text("FightsValue"), "2 / 2", "the boss fight counts")
	assert_eq(_page_text("GoldValue"), "55", "with its gold")
	assert_eq(_page_text("ExploredValue"), "3 / 6", "the cleared map takes no tile off the run")

## Plan Review Focus 1: a run ended mid-fight and mid-cast, then a new run.
func test_second_run_starts_clean() -> void:
	# A short first run, so that its clock shows the low seal.
	_start_run(SHORT_TIME_LIMIT)
	await _walk_to(FIGHT)
	_view.adventure_tilemap.select_choice(AdventureMapFixture.fight_choice(_map))
	await _cast_the_first_technique()
	_view.combat.player_combatant.buff_manager.apply_buff(_make_buff())
	await wait_process_frames(1)
	assert_true(_view.technique_dock.is_active(), "precondition: mid-fight")
	assert_true(_view.technique_dock.get_cast_tray().visible, "precondition: mid-cast")
	assert_true(_buff_socket_shows(0), "precondition: with a buff on")
	assert_true(_view.adventure_chest.get_run_clock().is_low_shown(), "precondition: the short run's clock is low")

	ActionManager.stop_action(false)
	_stop_every_action()
	_map = AdventureMapFixture.build_map()
	_start_run()
	await wait_process_frames(1)

	_assert_a_clean_start()

## Plan Review Focus 1: a run ended mid-walk, then a new run. Nothing of the old
## walk goes on into the new run.
func test_second_run_after_a_stop_mid_walk_starts_clean() -> void:
	_start_run(SHORT_TIME_LIMIT)
	await _walk_to(OPEN_NEAR)
	await _walk_partway(START, FIGHT)

	ActionManager.stop_action(false)
	_stop_every_action()
	_map = AdventureMapFixture.build_map()
	_start_run()
	await wait_process_frames(1)

	_assert_a_clean_start()
	# A hop the old run's end set off again would land within this.
	_run(1.5)
	assert_eq(_view.adventure_tilemap.get_current_tile(), START, "nobody walks on into the new run")
	assert_eq(_view.adventure_tilemap.get_visited_tile_count(), 1, "the new run has visited only its start")
	assert_false(_view.adventure_tilemap.character_body.is_moving)
