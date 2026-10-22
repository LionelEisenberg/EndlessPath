extends GutTest

## Integration tests for the lacquer cultivator cabinet (CultivatorPlate,
## lacquer kit §5.1): what it reads from the managers on _ready, how it follows
## their signals, and the frames it picks from the orb and bead strips.

const PLATE_SCENE_PATH: String = "res://scenes/zones/cultivator_plate/cultivator_plate.tscn"

const AURA_WELL_ID: String = "aura_well_training"
const CYCLING_ID: String = "wilderness_cycling_action"
const AURA_WELL_EVENT: String = "aura_well_discovered"

var _plate: CultivatorPlate = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_use_fresh_save()
	_plate = _add_plate()

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

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

## A fresh save standing at a Core Density level and XP, loaded the way a save
## loads (the managers announce it through save_data_reset).
func _load_core_density(level: float, xp: float) -> void:
	var save := SaveGameData.new()
	save.core_density_level = level
	save.core_density_xp = xp
	_use_fresh_save(save)

#-----------------------------------------------------------------------------
# MADRA
#-----------------------------------------------------------------------------

func test_shows_madra_over_max() -> void:
	assert_eq(_text("MadraValueLabel"), "25")
	assert_eq(_text("MadraMaxLabel"), "/ 100")

func test_madra_follows_its_signal() -> void:
	ResourceManager.set_madra(46.0)
	assert_eq(_text("MadraValueLabel"), "46")

func test_madra_orb_frame_follows_ratio() -> void:
	ResourceManager.set_madra(50.0)
	assert_eq((_node("MadraOrb") as LacquerStripRect).get_frame(), Vector2i(16, 0))

func test_madra_orb_is_full_above_max() -> void:
	ResourceManager.set_madra(250.0)
	assert_eq((_node("MadraOrb") as LacquerStripRect).get_frame(), Vector2i(32, 0))

func test_max_madra_follows_level() -> void:
	_load_core_density(32.0, 0.0)
	assert_eq(_text("MadraMaxLabel"), "/ 260")

func test_madra_orb_position_is_orb_centre() -> void:
	var orb: Control = _node("MadraOrb")
	var centre: Vector2 = _plate.get_madra_orb_global_position()
	assert_true(orb.get_global_rect().has_point(centre), "inside the orb's rect")
	assert_eq(centre, orb.global_position + Vector2(40.0, 40.0))

#-----------------------------------------------------------------------------
# MADRA RATE
#-----------------------------------------------------------------------------

func test_rate_hidden_without_madra_action() -> void:
	assert_null(ActionManager.get_current_action(), "precondition: nothing runs on a fresh save")
	assert_false((_node("RateLabel") as CanvasItem).visible)

func test_rate_shows_while_aura_well_runs() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	assert_eq(ActionManager.get_current_action().action_id, AURA_WELL_ID, "precondition: the Aura Well runs")
	var rate: RichTextLabel = _node("RateLabel")
	assert_true(rate.visible, "shown while the Aura Well runs")
	assert_eq(rate.get_parsed_text(), "+1.5 / s")

	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	assert_false(rate.visible, "hidden while cycling runs")

#-----------------------------------------------------------------------------
# CORE DENSITY
#-----------------------------------------------------------------------------

func test_level_and_stage_text() -> void:
	assert_eq(_text("LevelLabel"), "Level 0")
	assert_eq(_text("StageLabel"), "Foundation")

func test_fresh_save_shows_the_dormant_core() -> void:
	assert_eq((_node("CoreOrb") as LacquerStripRect).get_frame().x, 0)

func test_core_orb_column_follows_level() -> void:
	_load_core_density(32.0, 0.0)
	assert_eq((_node("CoreOrb") as LacquerStripRect).get_frame().x, 5)
	assert_eq(_text("LevelLabel"), "Level 32")

func test_core_orb_column_stops_at_breakthrough_level() -> void:
	_load_core_density(140.0, 0.0)
	assert_eq((_node("CoreOrb") as LacquerStripRect).get_frame().x, 16)

func test_swirl_steps_every_one_and_a_half_seconds() -> void:
	var timer: Timer = _node("SwirlTimer")
	assert_almost_eq(timer.wait_time, 1.5, 0.001)
	assert_false(timer.is_stopped(), "the swirl runs")
	var core: LacquerStripRect = _node("CoreOrb")
	assert_eq(core.get_frame().y, 0)
	for phase: int in [1, 2, 3, 0]:
		timer.timeout.emit()
		assert_eq(core.get_frame().y, phase, "swirl phase after a step")

func test_beads_follow_xp() -> void:
	# Level 0 needs 10 XP for level 1: 5 XP lights half the 18 beads.
	CultivationManager.add_core_density_xp(5.0)
	assert_eq((_node("XpBeads") as LacquerStripRect).get_frame(), Vector2i(0, 9))
	assert_eq(_text("XpLabel"), "5 / 10 XP")

func test_xp_figures_round_down() -> void:
	_load_core_density(32.0, 17.6)
	var need: float = CultivationManager.get_xp_for_next_level()
	assert_eq(_text("XpLabel"), "17 / %d XP" % int(need))
	# 17.6 XP of the more than 18.2 level 32 needs lights 17 of the 18 beads,
	# as in the mock.
	assert_eq((_node("XpBeads") as LacquerStripRect).get_frame(), Vector2i(0, 17))

#-----------------------------------------------------------------------------
# GOLD
#-----------------------------------------------------------------------------

func test_gold_text() -> void:
	assert_eq(_text("GoldValueLabel"), "0")
	ResourceManager.set_gold(120.0)
	assert_eq(_text("GoldValueLabel"), "120")
	assert_eq(_text("GoldWordLabel"), "gold")

#-----------------------------------------------------------------------------
# ROOT
#-----------------------------------------------------------------------------

func test_root_is_the_cabinet_and_stops_clicks() -> void:
	assert_eq(_plate.size, Vector2(440.0, 252.0))
	assert_eq(_plate.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(_plate.theme, load("res://assets/themes/lacquer/lacquer_theme.tres"))
