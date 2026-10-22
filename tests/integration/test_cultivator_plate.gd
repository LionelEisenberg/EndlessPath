extends GutTest

## Integration tests for the lacquer cultivator cabinet (CultivatorPlate,
## lacquer kit §5.1): what it reads from the managers on _ready, how it follows
## their signals, and the frames it picks from the orb and bead strips.

const PLATE_SCENE_PATH: String = "res://scenes/zones/cultivator_plate/cultivator_plate.tscn"
## The cabinet's right text edge, local (kit §5.1: screen 446).
const TEXT_RIGHT_EDGE: float = 422.0

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
	# 17.6 XP of the 18.8 level 32 needs is 16.8 beads' worth of the 18: 16
	# light, since a bead lights only once its whole share is earned.
	assert_almost_eq(need, 18.84, 0.01, "precondition: level 32 needs 18.84 XP")
	assert_eq((_node("XpBeads") as LacquerStripRect).get_frame(), Vector2i(0, 16))

## A bead lights only once its share of the XP is earned, so the beads never
## run ahead of the figure: 0.9 of 22 XP reads "0 / 22 XP" and lights none.
func test_beads_light_only_for_earned_xp() -> void:
	_load_core_density(40.0, 0.9)
	assert_eq(floori(CultivationManager.get_xp_for_next_level()), 22, "precondition: level 40 needs 22.08 XP")
	assert_eq(_text("XpLabel"), "0 / 22 XP")
	assert_eq((_node("XpBeads") as LacquerStripRect).get_frame(), Vector2i(0, 0))

func test_bead_lights_at_its_share() -> void:
	# Level 0 needs 10 XP, so each of the 18 beads is 10 / 18 XP.
	CultivationManager.add_core_density_xp(10.0 / 18.0 - 0.01)
	assert_eq((_node("XpBeads") as LacquerStripRect).get_frame(), Vector2i(0, 0), "just short of one bead")
	CultivationManager.add_core_density_xp(0.01)
	assert_eq((_node("XpBeads") as LacquerStripRect).get_frame(), Vector2i(0, 1), "one bead's share")

#-----------------------------------------------------------------------------
# GOLD
#-----------------------------------------------------------------------------

func test_gold_text() -> void:
	assert_eq(_text("GoldValueLabel"), "0")
	ResourceManager.set_gold(120.0)
	assert_eq(_text("GoldValueLabel"), "120")
	assert_eq(_text("GoldWordLabel"), "gold")

## The gold row sits at the right of the bottom row: coin, number, "gold",
## ending on the cabinet's right text edge whatever the number's width.
func test_gold_row_ends_on_the_right_text_edge() -> void:
	for gold: float in [0.0, 120.0, 98765.0]:
		ResourceManager.set_gold(gold)
		await wait_process_frames(2)
		var coin: Rect2 = (_node("GoldIcon") as Control).get_global_rect()
		var value: Rect2 = (_node("GoldValueLabel") as Control).get_global_rect()
		var word: Rect2 = (_node("GoldWordLabel") as Control).get_global_rect()
		var right_edge: float = _plate.global_position.x + TEXT_RIGHT_EDGE
		assert_almost_eq(word.end.x, right_edge, 0.5, "the word ends on the right text edge (%d gold)" % gold)
		assert_lt(coin.end.x, value.position.x, "the coin comes first")
		assert_lt(value.position.x, word.position.x, "then the number, then the word")
		assert_eq(coin.size, Vector2(32.0, 32.0), "the coin shows at 32x32")

#-----------------------------------------------------------------------------
# ROOT
#-----------------------------------------------------------------------------

func test_root_is_the_cabinet_and_stops_clicks() -> void:
	assert_eq(_plate.size, Vector2(440.0, 252.0))
	assert_eq(_plate.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(_plate.theme, load("res://assets/themes/lacquer/lacquer_theme.tres"))
