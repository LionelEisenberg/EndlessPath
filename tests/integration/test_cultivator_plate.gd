extends GutTest

## Integration tests for the lacquer cultivator cabinet (CultivatorPlate,
## lacquer kit §5.1): what it reads from the managers on _ready, how it follows
## their signals, the fills it hands the two orb shaders, the beads it lights,
## and the Madra and XP it leaves out of its figures while pellets fly.

const PLATE_SCENE_PATH: String = "res://scenes/zones/cultivator_plate/cultivator_plate.tscn"

const AURA_WELL_ID: String = "aura_well_training"
const CYCLING_ID: String = "wilderness_cycling_action"
const AURA_WELL_EVENT: String = "aura_well_discovered"

var _plate: CultivatorPlate = null
var _original_stage_resources: Array[AdvancementStageResource] = []

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_stage_resources = CultivationManager.advancement_stage_resources
	_use_fresh_save()
	_plate = _add_plate()

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	# A cycle session left running would leak into later files.
	CyclingManager.end_cycle_session()
	CultivationManager.advancement_stage_resources = _original_stage_resources

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _use_fresh_save(save: SaveGameData = SaveGameData.new()) -> void:
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()

func _add_plate() -> CultivatorPlate:
	var scene: PackedScene = load(PLATE_SCENE_PATH)
	var plate: CultivatorPlate = scene.instantiate()
	add_child_autofree(plate)
	return plate

func _node(unique_name: String) -> Node:
	return _plate.get_node("%" + unique_name)

func _text(unique_name: String) -> String:
	return (_node(unique_name) as Label).text.strip_edges()

## The fill an orb's shader draws, 0 to 1.
func _fill(unique_name: String) -> float:
	return ((_node(unique_name) as CanvasItem).material as ShaderMaterial).get_shader_parameter("progress")

## A fresh save standing at a Core Density level and XP, loaded the way a save
## loads (the managers announce it through save_data_reset).
func _load_core_density(level: float, xp: float) -> void:
	var save := SaveGameData.new()
	save.core_density_level = level
	save.core_density_xp = xp
	_use_fresh_save(save)

## Swaps in a Foundation that fills at `cap`. Call it before the save loads;
## after_each() restores the real stages.
func _use_a_short_stage(cap: int) -> void:
	var short_stage := AdvancementStageResource.new()
	short_stage.stage_id = CultivationManager.AdvancementStage.FOUNDATION
	short_stage.stage_name = "Short Foundation"
	short_stage.max_core_density_level = cap
	var stages: Array[AdvancementStageResource] = [short_stage]
	CultivationManager.advancement_stage_resources = stages

#-----------------------------------------------------------------------------
# MADRA
#-----------------------------------------------------------------------------

func test_shows_madra_over_max() -> void:
	assert_eq(_text("MadraValueLabel"), "25")
	assert_eq(_text("MadraMaxLabel"), "/ 100")

func test_madra_follows_its_signal() -> void:
	ResourceManager.set_madra(46.0)
	assert_eq(_text("MadraValueLabel"), "46")

## The max follows the Core Density level, so a level-up refills the orb
## against the new max.
func test_madra_fill_follows_max() -> void:
	_load_core_density(32.0, 0.0)
	ResourceManager.set_madra(130.0)
	assert_almost_eq(_fill("MadraOrb"), 0.5, 0.0001, "130 of 260 Madra")
	CultivationManager.add_core_density_xp(CultivationManager.get_xp_for_next_level())
	var max_madra: float = CultivationManager.get_max_madra()
	assert_gt(max_madra, 260.0, "precondition: the level-up raised the max")
	assert_almost_eq(_fill("MadraOrb"), 130.0 / max_madra, 0.0001)

#-----------------------------------------------------------------------------
# MADRA RATE
#-----------------------------------------------------------------------------

func test_rate_shows_while_aura_well_runs() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	assert_eq(ActionManager.get_current_action().action_id, AURA_WELL_ID, "precondition: the Aura Well runs")
	var rate: RichTextLabel = _node("RateLabel")
	assert_true(rate.visible, "shown while the Aura Well runs")
	assert_eq(rate.get_parsed_text(), "+1.5 / s")

	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	assert_false(rate.visible, "hidden while cycling runs")

## While the cycling action runs, the rate is the Madra the ball is drawing,
## read to a tenth (13.333 reads +13.3), and it goes when the cycle ends.
func test_rate_shows_the_cycling_rate() -> void:
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	var rate: RichTextLabel = _node("RateLabel")
	assert_false(rate.visible, "precondition: no cycle draws Madra yet")

	CyclingManager.start_cycle_session(15.0)
	CyclingManager.update_cycle_session(5.0, 13.333)
	assert_true(rate.visible, "shown while the ball draws Madra")
	assert_eq(rate.get_parsed_text(), "+13.3 / s")

	CyclingManager.end_cycle_session()
	assert_false(rate.visible, "hidden once the cycle ends")

#-----------------------------------------------------------------------------
# CORE DENSITY
#-----------------------------------------------------------------------------

func test_level_and_stage_text() -> void:
	assert_eq(_text("LevelLabel"), "Level 0")
	assert_eq(_text("StageLabel"), "Foundation")

func test_core_fill_follows_a_level_up() -> void:
	CultivationManager.add_core_density_xp(CultivationManager.get_xp_for_next_level())
	assert_eq(_text("LevelLabel"), "Level 1", "precondition: one level up")
	assert_almost_eq(_fill("CoreOrb"), 0.01, 0.0001)

## The core fills against the stage's own cap, not a fixed 100.
func test_core_fill_reads_the_stages_cap() -> void:
	_use_a_short_stage(40)
	_load_core_density(20.0, 0.0)
	assert_almost_eq(_fill("CoreOrb"), 0.5, 0.0001, "20 of the stage's 40 levels")
	assert_ne(_text("XpLabel"), "Core full", "precondition: not full at 20 of 40")
	_load_core_density(40.0, 0.0)
	assert_almost_eq(_fill("CoreOrb"), 1.0, 0.0001)
	assert_eq(_text("XpLabel"), "Core full")

## A failed Tribulation takes levels back: the core is no longer full, and the
## figure and the beads go back to counting XP.
func test_losing_levels_ends_core_full() -> void:
	_load_core_density(100.0, 0.0)
	assert_eq(_text("XpLabel"), "Core full", "precondition: the core is full")
	CultivationManager.lose_core_density_levels(5)
	var need: float = CultivationManager.get_xp_for_next_level()
	assert_eq(_text("LevelLabel"), "Level 95")
	assert_eq(_text("XpLabel"), "0 / %d XP" % int(need))
	assert_eq((_node("XpBeads") as LacquerStripRect).get_frame(), Vector2i(0, 0))
	assert_almost_eq(_fill("CoreOrb"), 0.95, 0.0001)

func test_beads_follow_xp() -> void:
	# Level 0 needs 10 XP for level 1: 5 XP lights half the 18 beads.
	CultivationManager.add_core_density_xp(5.0)
	assert_eq((_node("XpBeads") as LacquerStripRect).get_frame(), Vector2i(0, 9))
	assert_eq(_text("XpLabel"), "5 / 10 XP")

#-----------------------------------------------------------------------------
# PELLETS IN FLIGHT
#-----------------------------------------------------------------------------

## The cost of each level of the fresh Foundation stage, for rewind_core.
func _cost(level: int) -> float:
	return CultivationManager.get_xp_for_level(level)

## Madra on its way to the orb is left out of the figure and the fill until it
## lands.
func test_held_madra_shows_once_released() -> void:
	ResourceManager.set_madra(46.0)
	_plate.hold_madra(6.0)
	assert_eq(_text("MadraValueLabel"), "40", "the 6 in flight is not in the orb yet")
	assert_almost_eq(_fill("MadraOrb"), 0.40, 0.0001)
	_plate.release_madra(4.0)
	assert_eq(_text("MadraValueLabel"), "44")
	_plate.release_madra(2.0)
	assert_eq(_text("MadraValueLabel"), "46", "all of it landed")
	assert_almost_eq(_fill("MadraOrb"), 0.46, 0.0001)

## XP on its way to the Core orb is left out of the figure and the beads.
func test_held_xp_shows_once_released() -> void:
	CultivationManager.add_core_density_xp(5.0)
	_plate.hold_core_xp(5.0)
	assert_eq(_text("XpLabel"), "0 / 10 XP")
	assert_eq((_node("XpBeads") as LacquerStripRect).get_frame(), Vector2i(0, 0))
	_plate.release_core_xp(2.5)
	assert_eq(_text("XpLabel"), "2 / 10 XP")
	assert_eq((_node("XpBeads") as LacquerStripRect).get_frame(), Vector2i(0, 4), "a pellet's share lights its beads")
	_plate.release_core_xp(2.5)
	assert_eq(_text("XpLabel"), "5 / 10 XP")
	assert_eq((_node("XpBeads") as LacquerStripRect).get_frame(), Vector2i(0, 9))

## A hit that levels the core up shows the old level, its beads filling, until
## enough of its pellets land to cross it. 8.5 XP, so float dust in the sums
## still floors to 8.
func test_held_xp_holds_back_a_level_up() -> void:
	_load_core_density(5.0, 8.5)
	var need: float = CultivationManager.get_xp_for_next_level()
	CultivationManager.add_core_density_xp(need)
	assert_eq(_text("LevelLabel"), "Level 6", "precondition: the hit levelled the core up")
	_plate.hold_core_xp(need)
	assert_eq(_text("LevelLabel"), "Level 5", "still the old level while the XP flies")
	assert_eq(_text("XpLabel"), "8 / %d XP" % floori(need))
	assert_almost_eq(_fill("CoreOrb"), 0.05, 0.0001, "and the old level's spiral")
	_plate.release_core_xp(need - 8.0)
	assert_eq(_text("LevelLabel"), "Level 6", "crossed once enough has landed")
	_plate.release_core_xp(8.0)
	assert_eq(_text("XpLabel"), "8 / %d XP" % floori(CultivationManager.get_xp_for_next_level()))

func test_rewind_core_within_a_level() -> void:
	assert_eq(CultivatorPlate.rewind_core(4, 7.0, 3.0, _cost), Vector2(4, 4.0))
	assert_eq(CultivatorPlate.rewind_core(4, 7.0, 0.0, _cost), Vector2(4, 7.0))
	assert_eq(CultivatorPlate.rewind_core(4, 7.0, 7.0, _cost), Vector2(4, 0.0), "the start of the level is still the level")

## XP back past the start of a level comes off the level below's cost, and on
## down through as many levels as it takes.
func test_rewind_core_steps_back_through_levels() -> void:
	var back: Vector2 = CultivatorPlate.rewind_core(4, 2.0, 5.0, _cost)
	assert_eq(back.x, 3.0)
	assert_almost_eq(back.y, _cost(4) - 3.0, 0.0001, "3 short of level 4")
	back = CultivatorPlate.rewind_core(4, 2.0, 2.0 + _cost(4) + _cost(3) + 1.0, _cost)
	assert_eq(back.x, 1.0, "levels 4 and 3 undone, and 1 XP into level 2's cost")
	assert_almost_eq(back.y, _cost(2) - 1.0, 0.0001)

func test_rewind_core_stops_at_nothing() -> void:
	assert_eq(CultivatorPlate.rewind_core(1, 2.0, 500.0, _cost), Vector2(0, 0.0))
	assert_eq(CultivatorPlate.rewind_core(0, 2.0, 5.0, _cost), Vector2(0, 0.0))

#-----------------------------------------------------------------------------
# GOLD
#-----------------------------------------------------------------------------

func test_gold_text() -> void:
	assert_eq(_text("GoldValueLabel"), "0")
	ResourceManager.set_gold(120.0)
	assert_eq(_text("GoldValueLabel"), "120")

#-----------------------------------------------------------------------------
# ROOT
#-----------------------------------------------------------------------------

func test_root_stops_clicks() -> void:
	assert_eq(_plate.mouse_filter, Control.MOUSE_FILTER_STOP)
