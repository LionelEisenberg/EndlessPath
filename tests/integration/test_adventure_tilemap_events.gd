extends GutTest

## What AdventureTilemap tells the boards (arrivals, resolutions, refused walks,
## the boss reveal, redraws), the getters they read, the picks it takes from
## them and how a stop mid-walk ends the walk. Drives the real tilemap
## scene on the six-tile fixture map (AdventureMapFixture) and walks it by
## clicking tiles, the way the player does. A fight is not started: the tests
## answer it with handle_combat_result(), as AdventureView does when one ends.

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

## How far past the border between two hexes a walk must be to stand in the
## second one, in px of distance difference (twice the distance past it).
const PAST_THE_BORDER: float = 8.0

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _tilemap: AdventureTilemap
var _map: Dictionary[Vector3i, AdventureEncounter] = {}
## The map's choices: a combat choice against one Amorphous Spirit on FIGHT,
## and one that heals 10 Health on REST.
var _fight_choice: CombatChoice
var _rest_choice: EncounterChoice
var _original_save: SaveGameData
var _saved_vitals: Dictionary[StringName, float] = {}
## The order of the tilemap's announcements, by signal name (see _record_events()).
var _events: Array[String] = []
## For each tile_entered, whether the tile already counted as visited.
var _visited_when_entered: Array[bool] = []

func before_each() -> void:
	# Winning a fight pays gold into the save. Run on a fresh one, never the
	# developer's save loaded in memory.
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_saved_vitals = AdventureMapFixture.swap_in_known_vitals()
	_events.clear()
	_visited_when_entered.clear()
	_map = AdventureMapFixture.build_map()
	_fight_choice = AdventureMapFixture.fight_choice(_map)
	_rest_choice = AdventureMapFixture.rest_choice(_map)
	_tilemap = AdventureTilemapScene.instantiate()
	add_child_autofree(_tilemap)
	# The project's hex layer script overrides _ready() without super(), so the
	# addon only sets up its cube<->map conversions when the shared TileSet
	# emits `changed`, which happens once after it first loads. Re-emit it so
	# this fresh tilemap's map layers are initialised.
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

func _set_stamina(value: float) -> void:
	PlayerManager.vitals_manager.current_stamina = value

## Clicks a tile the way the map layer reports a click: with the tile's map cell.
func _click(coord: Vector3i) -> void:
	AdventureMapFixture.click(_tilemap, coord)

## Clicks a tile, then waits for the character to end its first hop: the whole
## walk, for a tile next door.
func _walk_to(coord: Vector3i) -> void:
	_click(coord)
	var arrived: bool = await wait_for_signal(_tilemap.character_body.movement_completed, AdventureMapFixture.HOP_TIMEOUT_SECONDS)
	assert_true(arrived, "the first hop of the walk to %s ends in time" % coord)

## Notes the order of the tilemap's announcements in _events, and whether each
## tile counted as visited when it was announced in _visited_when_entered.
func _record_events() -> void:
	_tilemap.map_changed.connect(_on_map_changed)
	_tilemap.tile_entered.connect(_on_tile_entered)
	_tilemap.walk_refused.connect(_on_walk_refused)

func _on_map_changed() -> void:
	_events.append("map_changed")

func _on_tile_entered(coord: Vector3i, _encounter: AdventureEncounter, _first_visit: bool, _summary: String) -> void:
	_events.append("tile_entered")
	_visited_when_entered.append(_tilemap.is_tile_visited(coord))

func _on_walk_refused(_reason: StringName) -> void:
	_events.append("walk_refused")

## Asserts that two lists hold the same tiles, in any order.
func _assert_same_tiles(actual: Array[Vector3i], expected: Array[Vector3i], what: String) -> void:
	assert_eq(actual.size(), expected.size(), "%s: how many tiles" % what)
	for coord in expected:
		assert_has(actual, coord, "%s: holds %s" % [what, coord])

#-----------------------------------------------------------------------------
# ARRIVALS
#-----------------------------------------------------------------------------

func test_start_enters_the_start_tile() -> void:
	watch_signals(_tilemap)

	_start()

	assert_signal_emit_count(_tilemap, "tile_entered", 1, "the start is one arrival")
	assert_signal_emitted_with_parameters(_tilemap, "tile_entered", [START, _map[START], true, ""])
	assert_eq(_tilemap.get_current_tile(), START)

func test_arrival_emits_tile_entered_and_map_changed() -> void:
	_start()
	_record_events()
	watch_signals(_tilemap)

	await _walk_to(OPEN_NEAR)

	assert_signal_emit_count(_tilemap, "tile_entered", 1, "one arrival")
	assert_signal_emitted_with_parameters(_tilemap, "tile_entered", [OPEN_NEAR, _map[OPEN_NEAR], true, ""])
	assert_signal_emitted(_tilemap, "map_changed")
	assert_eq(_tilemap.get_current_tile(), OPEN_NEAR)
	assert_almost_eq(_tilemap.character_body.global_position, _tilemap.get_tile_world_centre(OPEN_NEAR), Vector2(0.01, 0.01),
		"the character stands on the tile's world centre")
	assert_eq(_visited_when_entered.size(), 1, "one arrival was recorded")
	if _visited_when_entered.size() == 1:
		assert_true(_visited_when_entered[0], "the tile counts as visited when it is announced")
	assert_true(_events.has("map_changed"), "the map is redrawn on the way in")
	assert_lt(_events.find("map_changed"), _events.find("tile_entered"), "the map is redrawn before the arrival is announced")

#-----------------------------------------------------------------------------
# REFUSED WALKS
#-----------------------------------------------------------------------------

func test_low_stamina_click_is_refused() -> void:
	_start()
	_set_stamina(0.0)
	var standing_at: Vector2 = _tilemap.character_body.global_position
	watch_signals(_tilemap)
	watch_signals(LogManager)

	_click(OPEN_NEAR)

	assert_signal_emit_count(_tilemap, "walk_refused", 1)
	assert_signal_emitted_with_parameters(_tilemap, "walk_refused", [&"stamina"])
	assert_signal_emitted_with_parameters(LogManager, "message_logged", ["Too tired to walk · 5 Stamina a step"])
	# A walk that had started would have moved the character by now.
	await wait_physics_frames(5)
	assert_false(_tilemap.character_body.is_moving, "the character does not set off")
	assert_eq(_tilemap.character_body.global_position, standing_at, "the character does not move")
	assert_eq(_tilemap.get_current_tile(), START)

func test_walk_stopped_by_stamina_is_refused() -> void:
	_start()
	# Only tiles in view can be clicked, and OPEN_FAR is not in view from START.
	# FIGHT is two hops from OPEN_NEAR, through START.
	await _walk_to(OPEN_NEAR)
	_set_stamina(5.0)
	_record_events()
	watch_signals(_tilemap)
	watch_signals(LogManager)

	# One step's worth of Stamina pays for the first hop only.
	await _walk_to(FIGHT)

	assert_signal_emit_count(_tilemap, "walk_refused", 1)
	assert_signal_emitted_with_parameters(_tilemap, "walk_refused", [&"stamina"])
	assert_signal_emitted_with_parameters(LogManager, "message_logged", ["Too tired to walk · 5 Stamina a step"])
	assert_lt(_events.find("tile_entered"), _events.find("walk_refused"), "the refusal comes after the first arrival")
	assert_eq(_tilemap.get_current_tile(), START, "the walk stopped on the first hop's tile")
	await wait_physics_frames(5)
	assert_false(_tilemap.character_body.is_moving, "the walk does not go on")
	assert_signal_emit_count(_tilemap, "tile_entered", 1, "no second arrival")

func test_click_during_a_walk_stays_silent() -> void:
	_start()
	await _walk_to(OPEN_NEAR)
	_set_stamina(5.0)
	watch_signals(_tilemap)

	# A two-hop walk to FIGHT, paid for one hop at a time.
	_click(FIGHT)
	# Mid-hop with no Stamina left: a click that starts nothing, and says nothing.
	_click(REST)

	assert_signal_not_emitted(_tilemap, "walk_refused")
	await wait_for_signal(_tilemap.character_body.movement_completed, AdventureMapFixture.HOP_TIMEOUT_SECONDS)
	assert_signal_emit_count(_tilemap, "walk_refused", 1, "only the walk's own stop is refused")

func test_click_while_a_choice_waits_is_refused() -> void:
	_start()
	await _walk_to(FIGHT)
	# Out of Stamina too: the waiting encounter is checked first, so it is the reason given.
	_set_stamina(0.0)
	watch_signals(_tilemap)
	watch_signals(LogManager)

	_click(OPEN_NEAR)

	assert_signal_emit_count(_tilemap, "walk_refused", 1)
	assert_signal_emitted_with_parameters(_tilemap, "walk_refused", [&"encounter"])
	assert_signal_emitted_with_parameters(LogManager, "message_logged", ["Choose what to do here first"])
	assert_false(_tilemap.character_body.is_moving, "the character stays put")
	assert_eq(_tilemap.get_current_tile(), FIGHT)

#-----------------------------------------------------------------------------
# RESOLUTIONS
#-----------------------------------------------------------------------------

func test_rest_choice_resolves_with_its_effects() -> void:
	_start()
	await _walk_to(REST)
	watch_signals(_tilemap)
	assert_false(_tilemap.is_tile_completed(REST), "unresolved until a choice is made")

	_tilemap.select_choice(_rest_choice)

	assert_signal_emit_count(_tilemap, "encounter_resolved", 1)
	assert_signal_emitted_with_parameters(_tilemap, "encounter_resolved", [REST, "+10 Health"])
	assert_true(_tilemap.is_tile_completed(REST))
	assert_eq(_tilemap.get_tile_summary(REST), "+10 Health")
	assert_eq(PlayerManager.vitals_manager.current_health, 60.0, "the choice's effect was applied")

func test_won_fight_summary() -> void:
	_start()
	await _walk_to(FIGHT)
	watch_signals(_tilemap)

	_tilemap.select_choice(_fight_choice)

	assert_signal_emitted_with_parameters(_tilemap, "start_combat", [_fight_choice])
	assert_signal_not_emitted(_tilemap, "encounter_resolved")

	_tilemap.handle_combat_result(true, 15)

	assert_signal_emit_count(_tilemap, "encounter_resolved", 1)
	assert_signal_emitted_with_parameters(_tilemap, "encounter_resolved", [FIGHT, "Won · 15 gold"])
	assert_true(_tilemap.is_tile_completed(FIGHT))
	assert_eq(_tilemap.get_tile_summary(FIGHT), "Won · 15 gold")
	assert_eq(ResourceManager.live_save_data.gold, 15.0, "the fight paid its gold")

func test_dialogue_end_resolves_the_tile_with_its_summary() -> void:
	# A tile with a dialogue on it, in place of REST.
	var heal := ChangeVitalsEffectData.new()
	heal.health_change = 10.0
	var heal_effects: Array[EffectData] = [heal]
	var talk := DialogueChoice.new()
	talk.label = "Talk"
	talk.success_effects = heal_effects
	_map[REST] = AdventureMapFixture.encounter(AdventureEncounter.EncounterType.REST_SITE, talk)
	_start()
	await _walk_to(REST)
	watch_signals(_tilemap)

	# Picking the choice would start a real Dialogic timeline, and a second one
	# started in the same run fails the next test that starts one
	# (test_idle_action_resolution). So stand in for the timeline: leave what
	# select_choice() leaves while it plays, then call what DialogueManager's
	# dialogue_ended reaches when it ends.
	_tilemap._current_dialogue_choice = talk
	_tilemap._on_dialogue_ended()

	assert_signal_emit_count(_tilemap, "encounter_resolved", 1)
	assert_signal_emitted_with_parameters(_tilemap, "encounter_resolved", [REST, "+10 Health"])
	assert_eq(PlayerManager.vitals_manager.current_health, 60.0, "the dialogue's effect was applied")

## The chest stays up through a fight, so its drawer can be pressed again while
## the fight runs: the second pick starts no second fight.
func test_a_second_pick_while_the_fight_is_on_is_ignored() -> void:
	_start()
	await _walk_to(FIGHT)
	watch_signals(_tilemap)

	_tilemap.select_choice(_fight_choice)
	_tilemap.select_choice(_fight_choice)

	assert_signal_emit_count(_tilemap, "start_combat", 1, "one fight, however often it is picked")

## While a talk plays, a pick is ignored as well.
func test_a_pick_while_a_talk_plays_is_ignored() -> void:
	_start()
	await _walk_to(REST)
	# Picking a dialogue choice would start a real Dialogic timeline (see
	# test_dialogue_end_resolves_the_tile_with_its_summary), so stand in for one
	# that plays: leave what select_choice() leaves while it does.
	_tilemap._current_dialogue_choice = DialogueChoice.new()
	watch_signals(_tilemap)

	_tilemap.select_choice(_rest_choice)

	assert_signal_not_emitted(_tilemap, "encounter_resolved", "the talk holds the tile")
	assert_eq(PlayerManager.vitals_manager.current_health, 50.0, "the rest did not heal")

## Once the tile is resolved its choices are spent: a second press on its
## drawer does nothing.
func test_a_pick_on_a_resolved_tile_is_ignored() -> void:
	_start()
	await _walk_to(REST)
	_tilemap.select_choice(_rest_choice)
	watch_signals(_tilemap)

	_tilemap.select_choice(_rest_choice)

	assert_signal_not_emitted(_tilemap, "encounter_resolved", "the tile is resolved once")
	assert_eq(PlayerManager.vitals_manager.current_health, 60.0, "the rest healed once")

## A boss win ends the run before the fight lets go of its choice. The next
## run's picks must still count.
func test_a_new_run_takes_picks_after_a_boss_win() -> void:
	_start()
	await _walk_to(FIGHT)
	_tilemap.select_choice(_fight_choice)
	_tilemap.handle_combat_result(true, 0)
	await _walk_to(BOSS)
	_tilemap.select_choice(_map[BOSS].choices[0])
	_tilemap.handle_combat_result(true, 0)
	# What the view does when the boss win ends the run.
	_tilemap.stop_adventure()
	_start()
	await _walk_to(FIGHT)
	watch_signals(_tilemap)

	_tilemap.select_choice(_fight_choice)

	assert_signal_emit_count(_tilemap, "start_combat", 1, "the new run's fight starts")

func test_revisit_carries_the_summary() -> void:
	_start()
	await _walk_to(REST)
	_tilemap.select_choice(_rest_choice)
	await _walk_to(START)
	watch_signals(_tilemap)

	await _walk_to(REST)

	assert_signal_emit_count(_tilemap, "tile_entered", 1)
	assert_signal_emitted_with_parameters(_tilemap, "tile_entered", [REST, _map[REST], false, "+10 Health"])
	# A resolved tile holds the player no longer: the next click walks.
	await _walk_to(START)
	assert_signal_not_emitted(_tilemap, "walk_refused")
	assert_eq(_tilemap.get_current_tile(), START)

#-----------------------------------------------------------------------------
# BOSS REVEAL
#-----------------------------------------------------------------------------

func test_boss_reveal_emits_once() -> void:
	watch_signals(_tilemap)
	_start()
	assert_signal_not_emitted(_tilemap, "boss_revealed")

	await _walk_to(FIGHT)

	assert_signal_emit_count(_tilemap, "boss_revealed", 1)
	assert_signal_emitted_with_parameters(_tilemap, "boss_revealed", [BOSS])

	# Resolving the fight redraws the map; the boss is not revealed a second time.
	_tilemap.select_choice(_fight_choice)
	_tilemap.handle_combat_result(true, 0)
	assert_signal_emit_count(_tilemap, "boss_revealed", 1)

#-----------------------------------------------------------------------------
# GETTERS
#-----------------------------------------------------------------------------

func test_seen_tiles_and_dev_reveal() -> void:
	_start()
	var at_start: Array[Vector3i] = [START, FIGHT, OPEN_NEAR, REST]
	var whole_map: Array[Vector3i] = [START, FIGHT, OPEN_NEAR, OPEN_FAR, REST, BOSS]
	_assert_same_tiles(_tilemap.get_seen_tiles(), at_start, "at the start: the start tile and its map neighbours")
	assert_true(_tilemap.is_tile_visited(START))
	assert_false(_tilemap.is_tile_revealed(START), "a visited tile is not merely revealed")
	assert_true(_tilemap.is_tile_revealed(FIGHT))
	assert_false(_tilemap.is_tile_visited(FIGHT))
	assert_false(_tilemap.is_tile_revealed(BOSS), "the boss is out of sight until FIGHT is visited")
	assert_false(_tilemap.is_dev_reveal_all())
	watch_signals(_tilemap)

	_tilemap.set_dev_reveal_all(true)

	assert_true(_tilemap.is_dev_reveal_all())
	_assert_same_tiles(_tilemap.get_seen_tiles(), whole_map, "dev reveal on: every map tile")
	assert_false(_tilemap.is_tile_revealed(BOSS), "dev reveal leaves the game's own reveal alone")
	assert_false(_tilemap.is_tile_visited(BOSS))

	_tilemap.set_dev_reveal_all(false)

	assert_false(_tilemap.is_dev_reveal_all())
	_assert_same_tiles(_tilemap.get_seen_tiles(), at_start, "dev reveal off: back to the game's own")
	assert_signal_emit_count(_tilemap, "map_changed", 2, "each toggle redraws the map")

func test_encounter_lookup() -> void:
	_start()

	assert_same(_tilemap.get_encounter_at(START), _map[START])
	assert_same(_tilemap.get_encounter_at(FIGHT), _map[FIGHT])
	assert_same(_tilemap.get_encounter_at(BOSS), _map[BOSS], "also a tile that is not revealed yet")
	assert_null(_tilemap.get_encounter_at(Vector3i(5, -5, 0)), "off the map")

#-----------------------------------------------------------------------------
# SUMMARIES
#-----------------------------------------------------------------------------

func test_summary_for() -> void:
	var fight := CombatChoice.new()
	assert_eq(AdventureTilemap.summary_for(fight, 15), "Won · 15 gold", "a won fight names its gold")
	assert_eq(AdventureTilemap.summary_for(fight, 0), "Won", "a fight that paid nothing is just won")

	var heal := ChangeVitalsEffectData.new()
	heal.health_change = 10.0
	var rest := EncounterChoice.new()
	var heal_only: Array[EffectData] = [heal]
	rest.success_effects = heal_only
	assert_eq(AdventureTilemap.summary_for(rest, 0), "+10 Health", "an effect's own words")

	var tire := ChangeVitalsEffectData.new()
	tire.stamina_change = -5.0
	var heal_then_tire: Array[EffectData] = [heal, tire]
	rest.success_effects = heal_then_tire
	assert_eq(AdventureTilemap.summary_for(rest, 0), "+10 Health · -5 Stamina", "effects are joined with a dot")

	# An effect with only a debug string to show leaves no words.
	var trigger := TriggerEventEffectData.new()
	trigger.event_id = "some_event"
	var silent_only: Array[EffectData] = [trigger]
	var quiet := EncounterChoice.new()
	quiet.success_effects = silent_only
	assert_eq(AdventureTilemap.summary_for(quiet, 0), "Done", "an effect with nothing to say")
	var heal_and_silent: Array[EffectData] = [trigger, heal]
	rest.success_effects = heal_and_silent
	assert_eq(AdventureTilemap.summary_for(rest, 0), "+10 Health", "the silent effect is left out")

	assert_eq(AdventureTilemap.summary_for(EncounterChoice.new(), 0), "Done", "no effects")
	assert_eq(AdventureTilemap.summary_for(null, 0), "Done", "no choice")

#-----------------------------------------------------------------------------
# STOP
#-----------------------------------------------------------------------------

func test_stop_clears_summaries_and_emits_map_changed() -> void:
	_start()
	await _walk_to(REST)
	_tilemap.select_choice(_rest_choice)
	assert_eq(_tilemap.get_tile_summary(REST), "+10 Health", "resolved before the stop")
	watch_signals(_tilemap)

	_tilemap.stop_adventure()

	assert_signal_emitted(_tilemap, "map_changed")
	assert_eq(_tilemap.get_tile_summary(REST), "", "the summaries are gone")
	assert_false(_tilemap.is_tile_completed(REST))
	assert_eq(_tilemap.get_seen_tiles().size(), 0, "nothing is seen on a cleared map")
	assert_eq(_tilemap.get_current_tile(), START)

## A run that stops while a walk is under way (the time runs out, the player
## retreats) ends the walk where it stands: no hop sets off during the teardown,
## and none lands after it.
func test_stop_mid_walk_leaves_nothing_behind() -> void:
	_start()
	await _walk_to(OPEN_NEAR)
	var markers: AdventureMapMarkers = _tilemap.get_node("%AdventureMapMarkers") as AdventureMapMarkers
	# A two-hop walk to FIGHT through START, stopped once the first hop stands in
	# START's hex: the stop then finishes that hop on START, where the walk
	# would go on.
	var start_centre: Vector2 = _tilemap.get_tile_world_centre(START)
	var near_centre: Vector2 = _tilemap.get_tile_world_centre(OPEN_NEAR)
	_click(FIGHT)
	for frame: int in 120:
		await wait_physics_frames(1)
		var at: Vector2 = _tilemap.character_body.global_position
		if at.distance_to(start_centre) + PAST_THE_BORDER < at.distance_to(near_centre):
			break
	var at_stop: Vector2 = _tilemap.character_body.global_position
	assert_lt(at_stop.distance_to(start_centre) + PAST_THE_BORDER, at_stop.distance_to(near_centre), "precondition: the first hop stands in START's hex")
	assert_true(_tilemap.character_body.is_moving, "precondition: the walk is under way")
	_record_events()

	_tilemap.stop_adventure()
	var events_at_stop: int = _events.size()
	# A hop set off again by the teardown would land within about a second.
	await wait_seconds(1.5)

	assert_eq(_tilemap.get_visited_tile_count(), 0, "no tile is visited after the stop")
	assert_false(_tilemap.character_body.is_moving, "the character stands still")
	assert_eq(markers.get_coin_count(), 0, "no coin is left")
	assert_false((_tilemap.get_node("%CurrentRim") as CanvasItem).visible, "no current rim")
	assert_false((_tilemap.get_node("%HoverRim") as CanvasItem).visible, "no hover rim")
	assert_eq(_events.size(), events_at_stop, "nothing is announced after the stop")
	var last_redraw: int = _events.rfind("map_changed")
	assert_ne(last_redraw, -1, "the stop redraws the map")
	assert_false(_events.slice(last_redraw + 1).has("tile_entered"), "no arrival after the stop's redraw")
