extends GutTest

## Integration tests for the lacquer cultivator cabinet (CultivatorPlate,
## lacquer kit §5.1): what it reads from the managers on _ready, how it follows
## their signals, the fills it hands the two orb shaders, the frames it picks
## from the core orb and bead strips, and where the gold row sits.

const PLATE_SCENE_PATH: String = "res://scenes/zones/cultivator_plate/cultivator_plate.tscn"
const MADRA_ORB_SHADER_PATH: String = "res://assets/shaders/lacquer_madra_orb.gdshader"
const CORE_ORB_SHADER_PATH: String = "res://assets/shaders/lacquer_core_orb.gdshader"
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
	# A cycle session left running would leak into later files.
	CyclingManager.end_cycle_session()

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

#-----------------------------------------------------------------------------
# MADRA
#-----------------------------------------------------------------------------

func test_shows_madra_over_max() -> void:
	assert_eq(_text("MadraValueLabel"), "25")
	assert_eq(_text("MadraMaxLabel"), "/ 100")

func test_madra_follows_its_signal() -> void:
	ResourceManager.set_madra(46.0)
	assert_eq(_text("MadraValueLabel"), "46")

## The orb is the strip's empty socket (frame 0) under the flowing-liquid
## shader, which draws the fill inside the brass rim.
func test_madra_orb_draws_the_liquid_shader_on_the_empty_socket() -> void:
	var orb: TextureRect = _node("MadraOrb")
	var socket: AtlasTexture = orb.texture as AtlasTexture
	assert_not_null(socket, "the empty frame of the strip")
	assert_eq(socket.atlas.resource_path, "res://assets/ui/lacquer/lacquer_orb_madra_strip_ai.png")
	assert_eq(socket.region, Rect2(0.0, 0.0, 80.0, 80.0))
	assert_eq(((orb.material as ShaderMaterial).shader as Shader).resource_path, MADRA_ORB_SHADER_PATH)

func test_fresh_save_madra_fill() -> void:
	assert_almost_eq(_fill("MadraOrb"), 0.25, 0.0001, "25 of 100 Madra")

func test_madra_fill_follows_ratio() -> void:
	ResourceManager.set_madra(50.0)
	assert_almost_eq(_fill("MadraOrb"), 0.5, 0.0001)

func test_madra_orb_is_full_above_max() -> void:
	ResourceManager.set_madra(250.0)
	assert_almost_eq(_fill("MadraOrb"), 1.0, 0.0001)

func test_madra_orb_is_empty_without_madra() -> void:
	ResourceManager.set_madra(0.0)
	assert_almost_eq(_fill("MadraOrb"), 0.0, 0.0001)

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

## Each cabinet fills its own materials, so one scene instance never moves
## another's orbs.
func test_orb_materials_are_per_cabinet() -> void:
	var other: CultivatorPlate = _add_plate()
	assert_ne((_node("MadraOrb") as CanvasItem).material, (other.get_node("%MadraOrb") as CanvasItem).material)
	assert_ne((_node("CoreOrb") as CanvasItem).material, (other.get_node("%CoreOrb") as CanvasItem).material)

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

## A rate that reads +0 a second hides the label instead of showing "+0 / s".
func test_rate_hides_when_it_rounds_to_nothing() -> void:
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	CyclingManager.start_cycle_session(15.0)
	CyclingManager.update_cycle_session(5.0, 13.3)
	var rate: RichTextLabel = _node("RateLabel")
	assert_true(rate.visible, "precondition: shown while the ball draws Madra")

	CyclingManager.update_cycle_session(6.0, 0.04)
	assert_false(rate.visible, "0.04 a second reads +0")

#-----------------------------------------------------------------------------
# CORE DENSITY
#-----------------------------------------------------------------------------

func test_level_and_stage_text() -> void:
	assert_eq(_text("LevelLabel"), "Level 0")
	assert_eq(_text("StageLabel"), "Foundation")

func test_core_orb_draws_the_spiral_shader() -> void:
	var orb: CanvasItem = _node("CoreOrb")
	assert_eq(((orb.material as ShaderMaterial).shader as Shader).resource_path, CORE_ORB_SHADER_PATH)

func test_core_orb_position_is_orb_centre() -> void:
	var orb: Control = _node("CoreOrb")
	var centre: Vector2 = _plate.get_core_orb_global_position()
	assert_true(orb.get_global_rect().has_point(centre), "inside the orb's rect")
	assert_eq(centre, orb.global_position + Vector2(40.0, 40.0))

## Level 0 keeps the strip's dormant pebble (column 0) and draws no fill.
func test_fresh_save_shows_the_dormant_core() -> void:
	assert_eq((_node("CoreOrb") as LacquerStripRect).get_frame(), Vector2i(0, 0))
	assert_almost_eq(_fill("CoreOrb"), 0.0, 0.0001)

## From level 1 the orb is the empty socket (column 1, whose seed dot the
## fill covers) and the spiral grows from the centre to level / 100.
func test_core_fill_follows_level() -> void:
	_load_core_density(32.0, 0.0)
	assert_eq((_node("CoreOrb") as LacquerStripRect).get_frame(), Vector2i(1, 0))
	assert_almost_eq(_fill("CoreOrb"), 0.32, 0.0001)
	assert_eq(_text("LevelLabel"), "Level 32")

func test_core_fill_follows_a_level_up() -> void:
	CultivationManager.add_core_density_xp(CultivationManager.get_xp_for_next_level())
	assert_eq(_text("LevelLabel"), "Level 1", "precondition: one level up")
	assert_eq((_node("CoreOrb") as LacquerStripRect).get_frame(), Vector2i(1, 0))
	assert_almost_eq(_fill("CoreOrb"), 0.01, 0.0001)

func test_core_fill_stops_at_breakthrough_level() -> void:
	_load_core_density(140.0, 0.0)
	assert_almost_eq(_fill("CoreOrb"), 1.0, 0.0001)

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
