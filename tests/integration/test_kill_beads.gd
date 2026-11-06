extends GutTest

## A reward's Core Density flies to the run cabinet's Core row as beads
## (AdventureView): one burst per choice that pays, out of the hex the player
## stands on, each bead carrying an even share of what the core gained, which the
## row counts in as the bead lands. Drives the real AdventureView scene through
## ActionManager, as test_adventure_end_flow.gd does, on a fresh save at Core
## Density 0, where level 1 costs 10.

const AdventureViewScene := preload("res://scenes/adventure/adventure_view/adventure_view.tscn")
const ADVENTURE_ACTION := preload("res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres")
const AMORPHOUS_SPIRIT := preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
const CoreCurve := preload("res://tests/helpers/core_curve.gd")

var _view: AdventureView
var _original_save: SaveGameData
## The real stages, put back after each test (CoreCurve).
var _original_stages: Array[AdvancementStageResource]

func before_each() -> void:
	_original_stages = CoreCurve.use_fixed_curve()
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_view = AdventureViewScene.instantiate()
	add_child_autofree(_view)
	await get_tree().process_frame

func after_each() -> void:
	if ActionManager.get_current_action() is AdventureActionData:
		ActionManager.clear_current_action()
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	# AdventureTilemap creates its AdventureMapGenerator node with .new() and
	# never frees it; free it here so these tests don't leave orphans.
	if is_instance_valid(_view) and is_instance_valid(_view.adventure_tilemap.adventure_map_generator):
		_view.adventure_tilemap.adventure_map_generator.free()
	CoreCurve.restore(_original_stages)
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Starts the Shallow Woods adventure the way the zone does once the Madra drain
## finishes.
func _start_adventure() -> void:
	var action: AdventureActionData = ADVENTURE_ACTION.duplicate()
	action.time_limit_seconds = 300
	ActionManager._set_current_action(action)
	ActionManager.confirm_adventure_start(action, 50.0)

## A fight against one Amorphous Spirit whose win pays `xp` Core Density XP.
func _fight_paying(xp: float, is_boss: bool = false) -> CombatChoice:
	var choice := CombatChoice.new()
	choice.is_boss = is_boss
	var pool: Array[CombatantData] = [AMORPHOUS_SPIRIT]
	choice.enemy_pool = pool
	var award := AwardCoreDensityXpEffectData.new()
	award.amount = xp
	choice.success_effects.append(award)
	return choice

## Picks the fight, as the chest's drawer does, and wins it.
func _win(choice: CombatChoice) -> void:
	_view.adventure_tilemap._current_combat_choice = choice
	_view._on_start_combat(choice)
	_view.combat.trigger_combat_end.emit(true, 0)

## The beads in flight.
func _beads() -> Array[LacquerPellet]:
	var beads: Array[LacquerPellet] = []
	for child: Node in _view.get_node("%EffectsLayer").get_children():
		if child is LacquerPellet:
			beads.append(child)
	return beads

func _core_xp_text() -> String:
	return (_view.vitals_plate.get_node("%XpLabel") as Label).text

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

## One bead per BEAD_XP, at least one and at most MAX_BEADS.
func test_bead_count_follows_the_xp() -> void:
	var cases: Array[Dictionary] = [
		{"xp": 1.0, "beads": 1},
		{"xp": 4.0, "beads": 1},
		{"xp": 20.0, "beads": 5},
		{"xp": 50.0, "beads": 12},
		{"xp": 64.0, "beads": 16},
		{"xp": 120.0, "beads": 16},
	]
	for case: Dictionary in cases:
		assert_eq(AdventureView.bead_count_for(case.xp), case.beads, "%s XP" % case.xp)

## AdventureCombat reports a win again on each hit at 0 Health: the fight sends
## one burst.
func test_a_won_fight_sends_one_burst() -> void:
	_start_adventure()

	_win(_fight_paying(20.0))
	_view.combat.trigger_combat_end.emit(true, 0)

	assert_eq(_beads().size(), 5, "20 XP's 5 beads, once")

## The beads start out of the hex the player stands on.
func test_the_beads_start_at_the_players_hex() -> void:
	_start_adventure()
	var hex: Vector2 = _view.adventure_tilemap.get_tile_screen_position(_view.adventure_tilemap.get_current_tile())

	_win(_fight_paying(8.0))

	for bead: LacquerPellet in _beads():
		assert_almost_eq(bead.global_position, hex, Vector2(2.0, 2.0), "on the hex, to the even-px grid")

func test_the_core_row_counts_each_bead_in_as_it_lands() -> void:
	_start_adventure()

	_win(_fight_paying(9.0))

	var beads: Array[LacquerPellet] = _beads()
	assert_eq(beads.size(), 2, "precondition: 9 XP flies as 2 beads")
	assert_eq(_core_xp_text(), "0 / 10 XP", "the XP is held back while the beads fly")
	beads[0].free()
	assert_eq(_core_xp_text(), "4 / 10 XP", "the first bead's 4.5, floored")
	beads[1].free()
	assert_eq(_core_xp_text(), "9 / 10 XP", "every bead landed")

## A full core takes no XP, so no bead flies.
func test_a_kill_at_a_full_core_sends_no_beads() -> void:
	PersistenceManager.save_game_data.core_density_level = CultivationManager.get_core_density_cap()
	_start_adventure()

	_win(_fight_paying(20.0))

	assert_eq(_beads().size(), 0)

## The kill that fills the core sends what the core took, so the row climbs from
## where it stood to full, never below it.
func test_the_kill_that_fills_the_core_sends_what_the_core_took() -> void:
	var cap: int = CultivationManager.get_core_density_cap()
	PersistenceManager.save_game_data.core_density_level = cap - 1
	_start_adventure()
	var to_full: float = CultivationManager.get_xp_for_level(cap)

	_win(_fight_paying(to_full + 30.0))

	var level := _view.vitals_plate.get_node("%LevelLabel") as Label
	assert_eq(level.text, "Level %d" % (cap - 1), "the row shows the core before the kill")
	for bead: LacquerPellet in _beads():
		bead.free()
	assert_eq(_core_xp_text(), CultivationManager.CORE_FULL_TEXT, "and full once every bead landed")

## The boss's beads fly though its win ends the run: the cabinet stays in sight
## beside the end card.
func test_the_boss_sends_its_beads_as_the_run_ends() -> void:
	var results: Array[AdventureResultData] = []
	_view.adventure_completed.connect(func(result: AdventureResultData) -> void: results.append(result))
	_start_adventure()

	_win(_fight_paying(9.0, true))

	assert_eq(results.size(), 1, "precondition: the boss's win ended the run")
	assert_eq(_beads().size(), 2, "its beads are on their way")

## A new run lands any bead the last one left in flight.
func test_a_new_run_lands_the_last_runs_beads() -> void:
	_start_adventure()
	_win(_fight_paying(9.0, true))

	_start_adventure()
	await get_tree().process_frame

	assert_eq(_beads().size(), 0, "no bead left in flight")
	assert_eq(_core_xp_text(), "9 / 10 XP", "and the row shows all it carried")
