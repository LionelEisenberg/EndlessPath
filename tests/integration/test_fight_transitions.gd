extends GutTest

## A fight's two edges in the real AdventureView (#138, as its canvas "Into and
## out of a fight" was approved): the way in (the map's push in on the player's
## hex, the dissolve, both fighters' arrival, the fight starting once they land)
## and the way out (the deciding hit paid at once, the loser's fall, the beat, the
## dissolve back, the boards' news with the map), the run clock held through both,
## a run that ends in a fight ending after its close, and an Exit cutting any edge.
## The view is instanced as test_adventure_view_frame.gd does, on a canvas layer
## above GUT's own window, and each run starts through ActionManager on the
## shared fixture map (AdventureMapFixture), with real walks.

const AdventureViewScene := preload("res://scenes/adventure/adventure_view/adventure_view.tscn")
const AdventureMapFixture := preload("res://tests/integration/adventure_map_fixture.gd")
const CRUDE_SCALE: ItemDefinitionData = preload("res://resources/items/consumables/crude_scale.tres")
const ADVENTURE_ACTION := AdventureMapFixture.ADVENTURE_ACTION
const START := AdventureMapFixture.START
const FIGHT := AdventureMapFixture.FIGHT
const BOSS := AdventureMapFixture.BOSS
## GUT draws its own window on this canvas layer; the view goes above it.
const GUT_LAYER: int = 128
## One 60 FPS frame, for stepping the walk by hand.
const FRAME: float = 1.0 / 60.0
## More damage than any health pool, so one hit always leaves 0 HP.
const LETHAL_DAMAGE: float = -1000000.0
## A wait that ends safely past a beat, on a busy machine too.
const MARGIN: float = 0.1
## What the fight on FIGHT and the boss pay in Core Density.
const FIGHT_XP: float = 20.0
const BOSS_XP: float = 50.0

var _view: AdventureView = null
var _map: Dictionary[Vector3i, AdventureEncounter] = {}
var _original_save: SaveGameData = null
var _saved_vitals: Dictionary[StringName, float] = {}
var _results: Array[AdventureResultData] = []

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_saved_vitals = AdventureMapFixture.swap_in_known_vitals()
	_results.clear()
	_map = AdventureMapFixture.build_map()
	var award := AwardCoreDensityXpEffectData.new()
	award.amount = FIGHT_XP
	_fight().success_effects.append(award)
	var boss_award := AwardCoreDensityXpEffectData.new()
	boss_award.amount = BOSS_XP
	_map[BOSS].choices[0].success_effects.append(boss_award)
	var layer := CanvasLayer.new()
	layer.layer = GUT_LAYER + 1
	add_child_autofree(layer)
	_view = AdventureViewScene.instantiate() as AdventureView
	layer.add_child(_view)
	_view.adventure_completed.connect(func(result: AdventureResultData) -> void: _results.append(result))
	await get_tree().process_frame

func after_each() -> void:
	# A hit-stop or the boss reveal slows time for a moment; the next test starts
	# at full speed.
	Engine.time_scale = 1.0
	_stop_every_action()
	if is_instance_valid(_view) and is_instance_valid(_view.adventure_tilemap.adventure_map_generator):
		_view.adventure_tilemap.adventure_map_generator.free()
	AdventureMapFixture.restore_vitals(_saved_vitals)
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	_stop_every_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Hands out the fixture map in place of a generated one.
class FixedMapGenerator extends AdventureMapGenerator:
	var map: Dictionary[Vector3i, AdventureEncounter] = {}

	## Returns the given map.
	func generate_adventure_map() -> Dictionary[Vector3i, AdventureEncounter]:
		return map

## Starts the Shallow Woods on the fixture map the way the zone does once the
## start's zoom ends.
func _start_run() -> void:
	var tilemap: AdventureTilemap = _view.adventure_tilemap
	var generator := FixedMapGenerator.new()
	generator.map = _map
	tilemap.adventure_map_generator.free()
	tilemap.adventure_map_generator = generator
	var action: AdventureActionData = ADVENTURE_ACTION.duplicate()
	ActionManager._set_current_action(action)
	ActionManager.confirm_adventure_start(action)

func _stop_every_action() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

## Steps frames until the character ends the hop it is on, the walk taken off the
## physics clock so only the test moves it, then lets a frame run.
func _walk_to(coord: Vector3i) -> void:
	var character: CharacterBody2D = _view.adventure_tilemap.character_body
	var ended: Array[bool] = [false]
	character.movement_completed.connect(func() -> void: ended[0] = true, CONNECT_ONE_SHOT)
	AdventureMapFixture.click(_view.adventure_tilemap, coord)
	character.set_physics_process(false)
	for _frame: int in roundi(AdventureMapFixture.HOP_TIMEOUT_SECONDS / FRAME):
		if ended[0]:
			break
		simulate(character, 1, FRAME)
	character.set_physics_process(true)
	await get_tree().process_frame
	assert_true(ended[0], "precondition: the walk to %s ends" % coord)

## The fixture map's fight, on FIGHT.
func _fight() -> CombatChoice:
	return AdventureMapFixture.fight_choice(_map)

## Walks to FIGHT and picks its fight, as its drawer does.
func _pick_the_fight() -> void:
	await _walk_to(FIGHT)
	_view.adventure_tilemap.select_choice(_fight())

## Walks on to BOSS from a won FIGHT and picks the boss's fight.
func _pick_the_boss() -> void:
	await _walk_to(BOSS)
	_view.adventure_tilemap.select_choice(_map[BOSS].choices[0])

## Picks the fight and plays its way in to the landing at once.
func _pick_and_land() -> void:
	await _pick_the_fight()
	_view.finish_fight_transition()

func _kill_the_enemy() -> void:
	_view.combat.enemy_combatant.vitals_manager.apply_vitals_change(LETHAL_DAMAGE)

func _press_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)

func _page_text(unique_name: String) -> String:
	return _view.adventure_chest.get_expedition_page().get_node("%" + unique_name).get("text")

func _beads() -> int:
	var count: int = 0
	for child: Node in _view.get_node("%EffectsLayer").get_children():
		if child is LacquerPellet:
			count += 1
	return count

func _stats() -> PlayStatsData:
	return PersistenceManager.save_game_data.stats

#-----------------------------------------------------------------------------
# THE WAY IN
#-----------------------------------------------------------------------------

func test_the_way_in_shows_the_fight_at_the_swap_and_starts_it_at_the_landing() -> void:
	_start_run()

	await _pick_the_fight()

	assert_true(_view.tilemap_view.visible, "the map shows while it pushes in")
	assert_false(_view.combat_view.visible, "the fight waits")
	assert_true(_view.adventure_tilemap.is_pushed_in(), "the map's camera pushes in on the hex")
	assert_false(_view.is_fight_live(), "nothing is live yet")
	await wait_seconds(FightTransition.PUSH_SECONDS + MARGIN)
	assert_false(_view.tilemap_view.visible, "the map gives way")
	assert_true(_view.combat_view.visible, "to the fight")
	assert_false(_view.adventure_tilemap.is_pushed_in(), "its camera back for the way out")
	assert_false(_view.is_fight_live(), "the fighters are still arriving")
	await wait_seconds(FightTransition.WAY_IN_SECONDS - FightTransition.PUSH_SECONDS)
	assert_true(_view.is_fight_live(), "both have landed: the fight is live")
	assert_true(_view.technique_dock.is_active(), "the dock takes the fight's presses")
	assert_true(_view.combat.enemy_nameplate.visible, "the enemy's name shows")

func test_nothing_acts_on_the_way_in() -> void:
	InventoryManager.award_items(CRUDE_SCALE, 3)
	InventoryManager.equip_consumable(CRUDE_SCALE as ConsumableDefinitionData, 0)
	_start_run()
	await _pick_the_fight()
	await wait_seconds(FightTransition.PUSH_SECONDS + MARGIN)
	assert_true(_view.combat_view.visible, "precondition: the fighters are arriving")
	var player: CombatantNode = _view.combat.player_combatant

	_press_action(&"ability_slot_1")
	_press_action(&"consumable_slot_1")
	await wait_process_frames(2)

	assert_false(_view.technique_dock.is_active(), "the dock still previews the loadout")
	assert_eq(player.ability_manager.abilities[0].use_count, 0, "a technique key does nothing")
	assert_eq(InventoryManager.get_consumable_count(CRUDE_SCALE as ConsumableDefinitionData), 3, "nor does a consumable key")
	assert_false(_view.combat.enemy_combatant.ability_manager.is_casting(), "the enemy starts no cast")
	assert_almost_eq(player.ability_manager.abilities[0].cooldown_timer.time_left, CombatAbilityInstance.INITIAL_COOLDOWN, 0.001, "and the opening waits for the landing")

func test_the_run_clock_holds_through_both_edges() -> void:
	_start_run()
	var timer: Timer = _view.get_run_timer()

	await _pick_the_fight()
	assert_true(timer.paused, "held from the press")
	_view.finish_fight_transition()
	assert_false(timer.paused, "running through the fight")
	_kill_the_enemy()
	assert_true(timer.paused, "held from the deciding hit")
	_view.finish_fight_transition()
	assert_false(timer.paused, "running again on the map")

#-----------------------------------------------------------------------------
# THE WAY OUT
#-----------------------------------------------------------------------------

func test_the_way_out_pays_at_the_hit_and_shows_it_with_the_map() -> void:
	_start_run()
	await _pick_and_land()
	var gold_before: float = ResourceManager.get_gold()
	var fights_before: String = _page_text("FightsValue")
	var line_before: String = _page_text("LineLabel")
	var enemy: CombatantNode = _view.combat.enemy_combatant

	_kill_the_enemy()

	assert_gt(ResourceManager.get_gold(), gold_before, "the gold is paid at the hit")
	assert_eq(_view.adventure_tilemap.get_core_density_xp_earned(), FIGHT_XP, "and the Core Density")
	assert_eq(_stats().fights_won, 1, "and the fight counted")
	assert_false(_view.technique_dock.is_active(), "the dock lets go at the hit")
	assert_true(_view.combat_view.visible, "the fight still shows")
	assert_eq(_page_text("FightsValue"), fights_before, "the ledger waits for the map")
	assert_eq(_page_text("LineLabel"), line_before, "so does the tile's line")
	assert_eq(_beads(), 0, "and the beads")
	await wait_seconds(FightTransition.WAY_OUT_SECONDS + MARGIN)
	assert_true(_view.tilemap_view.visible, "the map is back")
	assert_false(_view.combat_view.visible, "the fight is gone")
	assert_false(is_instance_valid(enemy), "with its fighters")
	assert_ne(_page_text("FightsValue"), fights_before, "the ledger counts the fight")
	assert_ne(_page_text("LineLabel"), line_before, "the tile's line reads won")
	assert_eq(_beads(), AdventureView.bead_count_for(FIGHT_XP), "the beads leave the hex")

func test_a_win_reported_again_pays_once() -> void:
	_start_run()
	await _pick_and_land()
	var gold_before: float = ResourceManager.get_gold()

	_view.combat.trigger_combat_end.emit(true, 15)
	_view.combat.trigger_combat_end.emit(true, 15)
	_view.finish_fight_transition()

	assert_eq(ResourceManager.get_gold(), gold_before + 15.0, "the gold is paid once")
	assert_eq(_stats().fights_won, 1, "the fight counts once")
	assert_eq(_view.adventure_tilemap.get_core_density_xp_earned(), FIGHT_XP, "its Core Density is paid once")
	assert_eq(_page_text("FightsValue"), "1 / %d" % _view.adventure_tilemap.get_total_combat_count(), "and the ledger counts it once")

#-----------------------------------------------------------------------------
# RUNS THAT END IN A FIGHT
#-----------------------------------------------------------------------------

func test_a_lost_fight_ends_the_run_after_its_close() -> void:
	_start_run()
	await _pick_and_land()

	PlayerManager.vitals_manager.apply_vitals_change(LETHAL_DAMAGE)

	assert_eq(_results.size(), 0, "the close plays before the run ends")
	assert_true(_view.combat_view.visible, "with the fight in sight")
	_view.finish_fight_transition()
	assert_eq(_results.size(), 1, "then the run ends, once")
	if _results.size() == 1:
		assert_eq(_results[0].defeat_reason, "Your health reached zero")
	assert_eq(_stats().adventures_lost, 1, "as a loss")

func test_the_boss_win_ends_the_run_after_its_close() -> void:
	_start_run()
	await _pick_and_land()
	_kill_the_enemy()
	_view.finish_fight_transition()
	await _pick_the_boss()
	_view.finish_fight_transition()
	var xp_before: float = _view.adventure_tilemap.get_core_density_xp_earned()

	_kill_the_enemy()

	assert_eq(_results.size(), 0, "the close plays before the run ends")
	assert_eq(_view.adventure_tilemap.get_core_density_xp_earned(), xp_before + BOSS_XP, "the boss pays at the hit")
	_view.finish_fight_transition()
	assert_eq(_results.size(), 1, "then the run ends, once")
	if _results.size() == 1:
		assert_true(_results[0].is_victory, "as a victory")
	assert_eq(_stats().adventures_won, 1, "counted once")

## An Exit cuts the fight at once, on either edge or in between: the screen is the
## map's, nothing of the fight is left, the camera is back, the clock is not left
## paused, a kill made before stays paid, and the next run opens clean.
func test_an_exit_cuts_every_edge() -> void:
	var cases: Array[Dictionary] = [
		{"name": "on the way in", "at": "in"},
		{"name": "mid-fight", "at": "live"},
		{"name": "on the way out", "at": "out"},
	]
	for case: Dictionary in cases:
		_start_run()
		await _pick_the_fight()
		match case.at:
			"in":
				await wait_seconds(FightTransition.PUSH_SECONDS * 0.5)
			"live":
				_view.finish_fight_transition()
			"out":
				_view.finish_fight_transition()
				_kill_the_enemy()
		var enemy: CombatantNode = _view.combat.enemy_combatant
		var gold_before: float = ResourceManager.get_gold()
		var fights_total: int = _view.adventure_tilemap.get_total_combat_count()

		_view.force_end_adventure(false)

		assert_true(_view.tilemap_view.visible, "%s: the map shows" % case.name)
		assert_false(_view.combat_view.visible, "%s: the fight is gone" % case.name)
		assert_true(not is_instance_valid(enemy) or enemy.is_queued_for_deletion(), "%s: with its fighters" % case.name)
		assert_false(_view.is_in_combat, "%s: no fight is under way" % case.name)
		assert_false(_view.adventure_tilemap.is_pushed_in(), "%s: the camera is back" % case.name)
		assert_false(_view.get_run_timer().paused, "%s: the clock is not left paused" % case.name)
		assert_eq(ResourceManager.get_gold(), gold_before, "%s: the Exit pays nothing more" % case.name)
		if case.at == "out":
			assert_eq(_stats().fights_won, 1, "%s: the kill made before stays paid" % case.name)
			assert_eq(_page_text("FightsValue"), "1 / %d" % fights_total, "%s: and the ledger shows it" % case.name)
		await wait_seconds(FightTransition.WAY_OUT_SECONDS + MARGIN)
		_start_run()
		assert_true(_view.tilemap_view.visible, "%s: the next run opens on its map" % case.name)
		assert_false(_view.combat_view.visible, "%s: with no fight" % case.name)
		assert_false(_view.get_run_timer().paused, "%s: and its clock running" % case.name)
		assert_false(_view.technique_dock.is_active(), "%s: and the dock previewing" % case.name)
		_stop_every_action()

func test_force_win_waits_for_the_fight_to_start() -> void:
	_start_run()
	await _pick_the_fight()

	assert_eq(DevCommands.force_win_fight(_view), "No fight is on", "on the way in")
	_view.finish_fight_transition()
	assert_eq(DevCommands.force_win_fight(_view), "", "once it is live")
	assert_eq(DevCommands.force_win_fight(_view), "No fight is on", "and in its close")
