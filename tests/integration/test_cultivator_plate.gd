extends GutTest

## Integration tests for the lacquer cultivator cabinet (CultivatorPlate,
## lacquer kit §5.1): what it reads from the managers on _ready, how it follows
## their signals, the fills it hands the two orb shaders, the beads it lights,
## the Madra and XP it leaves out of its figures while pellets fly, and its six
## stat cells: each stat's level and its XP ring, the flowing channel at the
## cap, following CharacterManager; where stat pellets land, the stat XP held
## while they fly, when a cell plays its level-up look and hops, and the hover
## figure.

const PLATE_SCENE_PATH: String = "res://scenes/zones/cultivator_plate/cultivator_plate.tscn"
const CAPPED_STRIP: Texture2D = preload("res://assets/ui/lacquer/lacquer_stat_ring_capped_strip_ai.png")

const AURA_WELL_ID: String = "aura_well_training"
const CYCLING_ID: String = "wilderness_cycling_action"
const AURA_WELL_EVENT: String = "aura_well_discovered"
## The modifier source the Madra tests raise the max Madra stat under.
const TEST_SOURCE: StringName = &"test_cultivator_plate"

const Attribute := CharacterAttributesData.AttributeType

## The six stat cells' unique names, Physical then Spiritual, apex first.
const CELL_NAMES: Array[String] = ["StrengthCell", "BodyCell", "AgilityCell", "SpiritCell", "MindCell", "ControlCell"]

var _plate: CultivatorPlate = null
var _original_stage_resources: Array[AdvancementStageResource] = []
var _original_save: SaveGameData = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_stage_resources = CultivationManager.advancement_stage_resources
	_original_save = PersistenceManager.save_game_data
	_use_fresh_save()
	_plate = _add_plate()

func after_each() -> void:
	CharacterManager.remove_modifier_source(TEST_SOURCE)
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	# A cycle session left running would leak into later files.
	CyclingManager.end_cycle_session()
	# The stages first: the restored save is read against the real ones.
	CultivationManager.advancement_stage_resources = _original_stage_resources
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

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

## A modifier source that adds `amount` to the max Madra stat.
func _max_madra_source(amount: float) -> Callable:
	return func() -> Array[StatModifierData]:
		var modifiers: Array[StatModifierData] = [StatModifierData.new(StatModifierData.Stat.MAX_MADRA, StatModifierData.Kind.FLAT, amount)]
		return modifiers

## A stat cell, by its unique name in the cabinet.
func _cell(unique_name: String) -> StatCell:
	return _node(unique_name) as StatCell

## The text of a stat cell's Label, by the Label's unique name in the cell.
func _cell_text(cell_name: String, label_name: String) -> String:
	return (_cell(cell_name).get_node("%" + label_name) as Label).text.strip_edges()

## The frame a stat cell's XP ring shows: column n lights n beads.
func _ring(cell_name: String) -> Vector2i:
	return (_cell(cell_name).get_node("%XpRing") as LacquerStripRect).get_frame()

## The strip a stat cell's ring draws from: the beads, or the capped channel.
func _ring_strip(cell_name: String) -> Texture2D:
	return (_cell(cell_name).get_node("%XpRing") as LacquerStripRect).strip

func _capped(cell_name: String) -> bool:
	return _ring_strip(cell_name) == CAPPED_STRIP

func _tooltip() -> StatTooltip:
	return _node("StatTooltip") as StatTooltip

func _tooltip_text(label_name: String) -> String:
	return (_tooltip().get_node("%" + label_name) as Label).text

## Swaps in a Foundation whose stats cap at `foundation_cap`, leading to a Copper
## whose stats cap at `copper_cap`. after_each() restores the real stages.
func _use_stat_caps(foundation_cap: int, copper_cap: int) -> void:
	var copper := AdvancementStageResource.new()
	copper.stage_id = CultivationManager.AdvancementStage.COPPER
	copper.stage_name = "Test Copper"
	copper.stat_level_cap = copper_cap
	var foundation := AdvancementStageResource.new()
	foundation.stage_id = CultivationManager.AdvancementStage.FOUNDATION
	foundation.stage_name = "Test Foundation"
	foundation.stat_level_cap = foundation_cap
	foundation.next_stage = copper
	var stages: Array[AdvancementStageResource] = [foundation, copper]
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

## Mind, gear and any modifier source move the max, and the orb fills against it.
func test_the_madra_max_follows_the_max_madra_stat() -> void:
	ResourceManager.set_madra(100.0)
	CharacterManager.set_modifier_source(TEST_SOURCE, _max_madra_source(100.0))
	assert_eq(_text("MadraMaxLabel"), "/ 200")
	assert_almost_eq(_fill("MadraOrb"), 0.5, 0.0001, "100 of 200 Madra")

## Core Density sets no Madra cap any more.
func test_a_core_density_level_up_leaves_the_madra_max_alone() -> void:
	_load_core_density(32.0, 0.0)
	CultivationManager.add_core_density_xp(CultivationManager.get_xp_for_next_level())
	assert_eq(CultivationManager.get_core_density_level(), 33.0, "precondition: the core levelled")
	assert_eq(_text("MadraMaxLabel"), "/ 100")
	assert_almost_eq(_fill("MadraOrb"), 0.25, 0.0001, "25 of 100 Madra")

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
	assert_eq(_text("XpLabel"), "0 / %d XP" % ceili(need))
	assert_eq((_node("XpBeads") as LacquerStripRect).get_frame(), Vector2i(0, 0))
	assert_almost_eq(_fill("CoreOrb"), 0.95, 0.0001)

func test_beads_follow_xp() -> void:
	# Level 0 needs 10 XP for level 1: 5 XP lights half the 18 beads.
	CultivationManager.add_core_density_xp(5.0)
	assert_eq((_node("XpBeads") as LacquerStripRect).get_frame(), Vector2i(0, 9))
	assert_eq(_text("XpLabel"), "5 / 10 XP")

## The figure floors the XP and rounds the threshold up, so an unmet threshold
## never reads as met: level 6 costs 10 × 1.02^5 = 11.04 XP, and 11 XP of it
## reads 11 / 12, never 11 / 11.
func test_the_xp_figure_never_shows_an_unmet_threshold_as_met() -> void:
	_load_core_density(5.0, 11.0)
	var need: float = CultivationManager.get_xp_for_next_level()
	assert_ne(need, floorf(need), "precondition: level 6's threshold has decimals")
	assert_lt(CultivationManager.get_core_density_xp(), need, "precondition: the threshold is not met")
	var text: String = _text("XpLabel")
	assert_string_contains(text, "/ %d" % ceili(need), "the figure holds the threshold rounded up")
	assert_false(text.contains("/ %d " % floori(need)), "never the threshold rounded down")

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
	assert_eq(_text("XpLabel"), "8 / %d XP" % ceili(need))
	assert_almost_eq(_fill("CoreOrb"), 0.05, 0.0001, "and the old level's spiral")
	_plate.release_core_xp(need - 8.0)
	assert_eq(_text("LevelLabel"), "Level 6", "crossed once enough has landed")
	_plate.release_core_xp(8.0)
	assert_eq(_text("XpLabel"), "8 / %d XP" % ceili(CultivationManager.get_xp_for_next_level()))

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
# STATS
#-----------------------------------------------------------------------------
# A ring lights floor(xp × 24 / the next level's cost) of its 24 beads. On the
# shipped curve, Lv L to L + 1 costs 100 × 1.25^(L − 1) XP: a retune of
# stat_progression.tres moves the frames pinned below.

## The StatCells under each side, in child order (apex, below left, below
## right), are that side's stats in the book's order.
func test_the_cells_are_the_six_stats_in_two_triangles() -> void:
	var cases: Array[Dictionary] = [
		{"side": "PhysicalCells", "stats": StatDisplay.PHYSICAL},
		{"side": "SpiritualCells", "stats": StatDisplay.SPIRITUAL},
	]
	for case: Dictionary in cases:
		var stats: Array[CharacterAttributesData.AttributeType] = []
		for child: Node in _node(case["side"]).get_children():
			if child is StatCell:
				stats.append((child as StatCell).attribute_type)
		assert_eq(stats, case["stats"], "%s holds its side's stats, apex first" % case["side"])

func test_each_cell_names_its_stat() -> void:
	var cases: Array[Dictionary] = [
		{"cell": "StrengthCell", "stat": Attribute.STRENGTH},
		{"cell": "BodyCell", "stat": Attribute.BODY},
		{"cell": "AgilityCell", "stat": Attribute.AGILITY},
		{"cell": "SpiritCell", "stat": Attribute.SPIRIT},
		{"cell": "MindCell", "stat": Attribute.MIND},
		{"cell": "ControlCell", "stat": Attribute.CONTROL},
	]
	for case: Dictionary in cases:
		var cell_name: String = case["cell"]
		var stat: CharacterAttributesData.AttributeType = case["stat"]
		assert_eq(_cell_text(cell_name, "NameLabel"), StatDisplay.name_of(stat), "%s names its stat" % cell_name)
		var icon: TextureRect = _cell(cell_name).get_node("%Icon") as TextureRect
		assert_eq(icon.texture, StatDisplay.icon_of(stat), "%s shows its stat's icon" % cell_name)

func test_a_new_save_shows_every_stat_at_level_one() -> void:
	for cell_name: String in CELL_NAMES:
		assert_eq(_cell_text(cell_name, "LevelLabel"), "Lv 1", "%s reads Lv 1" % cell_name)
		assert_eq(_ring(cell_name), Vector2i(0, 0), "%s's ring is empty" % cell_name)

func test_a_cell_shows_its_level_and_xp() -> void:
	CharacterManager.set_stat_level(Attribute.SPIRIT, 4, 120.0)
	assert_eq(_cell_text("SpiritCell", "LevelLabel"), "Lv 4", "Spirit's cell reads its level")
	assert_eq(_ring("SpiritCell"), Vector2i(14, 0), "120 of Lv 4's 195.3125 XP: 120 × 24 / 195.3125 = 14.75, floored to 14; a bead lights once its share is earned")
	assert_eq(_cell_text("MindCell", "LevelLabel"), "Lv 1", "only Spirit's cell moved")

## XP that buys no level comes through stat_xp_changed alone.
func test_a_cell_follows_xp() -> void:
	CharacterManager.add_stat_xp(Attribute.BODY, 50.0)
	assert_eq(CharacterManager.get_stat_level(Attribute.BODY), 1, "precondition: 50 of Lv 2's 100 buys no level")
	assert_eq(_ring("BodyCell"), Vector2i(12, 0), "50 of 100 XP: 50 × 24 / 100 = 12")
	assert_eq(_cell_text("BodyCell", "LevelLabel"), "Lv 1", "Body's cell keeps its level")

func test_a_cell_follows_levels() -> void:
	CharacterManager.add_stat_levels(Attribute.BODY, 2)
	assert_eq(_cell_text("BodyCell", "LevelLabel"), "Lv 3", "whole levels, the Aura Well's way")
	CharacterManager.add_stat_xp(Attribute.BODY, CharacterManager.get_stat_xp_to_next(Attribute.BODY) + 100.0)
	assert_eq(_cell_text("BodyCell", "LevelLabel"), "Lv 4", "XP that pays for a level raises it")
	assert_eq(_ring("BodyCell"), Vector2i(12, 0), "the 100 over, into Lv 4's 195.3125: 100 × 24 / 195.3125 = 12.29, floored to 12")

func test_a_capped_cell_shows_the_cap() -> void:
	CharacterManager.set_stat_level(Attribute.STRENGTH, CharacterManager.get_stat_level_cap())
	assert_eq(_cell_text("StrengthCell", "LevelLabel"), "Lv %d" % CharacterManager.get_stat_level_cap(), "Strength's cell reads the cap")
	assert_true(_capped("StrengthCell"), "the flowing channel at the cap")
	assert_false(_capped("BodyCell"), "only the capped stat's ring changes")

func test_xp_at_the_cap_keeps_the_cap() -> void:
	CharacterManager.set_stat_level(Attribute.SPIRIT, CharacterManager.get_stat_level_cap())
	CharacterManager.add_stat_xp(Attribute.SPIRIT, 50.0)
	assert_eq(CharacterManager.get_stat_xp(Attribute.SPIRIT), 0.0, "precondition: the 50 is lost at the cap")
	assert_true(_capped("SpiritCell"), "the 0 XP that arrives at the cap leaves the cell capped")

func test_the_breakthrough_lifts_the_cap() -> void:
	_use_stat_caps(3, 6)
	CharacterManager.set_stat_level(Attribute.STRENGTH, 3)
	assert_true(_capped("StrengthCell"), "precondition: capped at Foundation's 3")
	assert_true(CultivationManager.advance_to_next_stage(), "precondition: the breakthrough lands")
	assert_false(_capped("StrengthCell"), "Copper's cap of 6 lifts the capped look")
	assert_eq(_ring("StrengthCell"), Vector2i(0, 0), "Copper's cap of 6 leaves room, and the set Lv 3 holds no XP")
	assert_eq(_cell_text("StrengthCell", "LevelLabel"), "Lv 3", "Copper's cap of 6 leaves room, and the set Lv 3 holds no XP")

## The one test of the read on _ready: the first cabinet takes the load through
## stats_changed, and the second, made after the save loaded, as at boot, reads
## it in _ready().
func test_a_loaded_save_shows_its_levels() -> void:
	var save := SaveGameData.new()
	save.stat_training.set_level(Attribute.MIND, 6)
	save.stat_training.set_xp(Attribute.MIND, 200.0)
	_use_fresh_save(save)
	assert_eq(_cell_text("MindCell", "LevelLabel"), "Lv 6", "the loaded level")
	assert_eq(_ring("MindCell"), Vector2i(15, 0), "200 of Lv 6's 305.18 XP: 200 × 24 / 305.18 = 15.73, floored to 15")
	_plate = _add_plate()
	assert_eq(_cell_text("MindCell", "LevelLabel"), "Lv 6", "read on _ready")
	assert_eq(_ring("MindCell"), Vector2i(15, 0), "read on _ready")

## Each side's label row is the zone chest's group row, named for its side.
func test_the_side_rows_are_the_shared_group_row() -> void:
	var cases: Array[Dictionary] = [
		{"side": "PhysicalCells", "text": "Physical"},
		{"side": "SpiritualCells", "text": "Spiritual"},
	]
	for case: Dictionary in cases:
		var row: Node = _node(case.side).get_node("SideRow")
		assert_true(row is LacquerGroupRow, "%s's row is a LacquerGroupRow" % case.side)
		assert_eq((row.get_node("%GroupLabel") as Label).text, case.text, "%s's row names its side" % case.side)

#-----------------------------------------------------------------------------
# STAT PELLETS
#-----------------------------------------------------------------------------

## A stat's pellets land on its ring's centre, which a hop does not move.
func test_each_stat_pellet_lands_on_its_cells_ring() -> void:
	for cell_name: String in CELL_NAMES:
		var cell: StatCell = _cell(cell_name)
		assert_eq(_plate.get_stat_cell_global_position(cell.attribute_type), cell.global_position + Vector2(40, 40), "%s's ring centre" % cell_name)

## A stat at the cap takes no pellets; the others do.
func test_a_capped_stat_takes_no_pellets() -> void:
	CharacterManager.set_stat_level(Attribute.SPIRIT, CharacterManager.get_stat_level_cap())
	assert_false(_plate.accepts_stat_xp(Attribute.SPIRIT), "Spirit at the cap refuses")
	assert_true(_plate.accepts_stat_xp(Attribute.MIND), "Mind under the cap takes them")

## XP on its way to a cell is left out of its ring until it lands. Spirit Lv 4
## costs 195.3125 XP: 25 of it lights floor(25 × 24 / 195.3125) = 3 beads.
func test_held_stat_xp_shows_once_released() -> void:
	CharacterManager.set_stat_level(Attribute.SPIRIT, 4)
	CharacterManager.add_stat_xp(Attribute.SPIRIT, 50.0)
	_plate.hold_stat_xp(Attribute.SPIRIT, 50.0)
	assert_eq(_ring("SpiritCell"), Vector2i(0, 0), "nothing has landed")
	_plate.release_stat_xp(Attribute.SPIRIT, 25.0)
	assert_eq(_ring("SpiritCell"), Vector2i(3, 0), "half has landed")
	_plate.release_stat_xp(Attribute.SPIRIT, 25.0)
	assert_eq(_ring("SpiritCell"), Vector2i(6, 0), "all of it has landed")

## XP that pays a level shows the old level, its beads filling, until enough of
## it lands to cross it; the crossing plays the level-up look. 190 of Lv 4's
## 195.3125, plus 20: Lv 5 with 14.6875.
func test_held_stat_xp_holds_back_a_level_up() -> void:
	CharacterManager.set_stat_level(Attribute.SPIRIT, 4, 190.0)
	CharacterManager.add_stat_xp(Attribute.SPIRIT, 20.0)
	assert_eq(CharacterManager.get_stat_level(Attribute.SPIRIT), 5, "precondition: the 20 pays the level")
	_plate.hold_stat_xp(Attribute.SPIRIT, 20.0)
	await wait_process_frames(1)
	assert_eq(_cell_text("SpiritCell", "LevelLabel"), "Lv 4", "the old level while the XP flies")
	assert_false(_cell("SpiritCell").is_flashing(), "XP paid and held in one frame plays nothing yet")
	_plate.release_stat_xp(Attribute.SPIRIT, 5.0)
	await wait_process_frames(1)
	assert_eq(_cell_text("SpiritCell", "LevelLabel"), "Lv 4", "195 of 195.3125: still short")
	assert_eq(_ring("SpiritCell"), Vector2i(23, 0), "195 × 24 / 195.3125 = 23.96, floored to 23")
	assert_false(_cell("SpiritCell").is_flashing(), "a landing short of the level plays nothing")
	_plate.release_stat_xp(Attribute.SPIRIT, 15.0)
	assert_eq(_cell_text("SpiritCell", "LevelLabel"), "Lv 5", "the level shows as its pellet lands")
	await wait_process_frames(1)
	assert_true(_cell("SpiritCell").is_flashing(), "and plays the level-up look then")

## The pellet that reaches the cap shows the stat uncapped until it lands.
func test_held_stat_xp_holds_back_the_cap() -> void:
	var cap: int = CharacterManager.get_stat_level_cap()
	CharacterManager.set_stat_level(Attribute.MIND, cap - 1)
	var cost: float = CharacterManager.get_stat_xp_to_next(Attribute.MIND)
	CharacterManager.add_stat_xp(Attribute.MIND, cost)
	assert_true(CharacterManager.is_stat_capped(Attribute.MIND), "precondition: the XP reaches the cap")
	_plate.hold_stat_xp(Attribute.MIND, cost)
	assert_false(_capped("MindCell"), "not capped while its XP flies")
	assert_eq(_cell_text("MindCell", "LevelLabel"), "Lv %d" % (cap - 1), "the level below the cap")
	_plate.release_stat_xp(Attribute.MIND, cost)
	assert_true(_capped("MindCell"), "capped once it lands")

## Every landing hops its cell.
func test_a_landing_hops_its_cell() -> void:
	_plate.hold_stat_xp(Attribute.BODY, 10.0)
	assert_false(_cell("BodyCell").is_hopping(), "a hold does not hop")
	_plate.release_stat_xp(Attribute.BODY, 10.0)
	assert_true(_cell("BodyCell").is_hopping(), "the landing does")
	assert_false(_cell("MindCell").is_hopping(), "only the cell it landed on")

## The level-up look plays when a level is gained or set with nothing in flight.
func test_a_gain_or_a_set_plays_the_level_up_look() -> void:
	await wait_process_frames(1)
	CharacterManager.add_stat_levels(Attribute.BODY, 1)
	CharacterManager.set_stat_level(Attribute.AGILITY, 5)
	CharacterManager.add_stat_xp(Attribute.STRENGTH, 10.0)
	await wait_process_frames(1)
	assert_true(_cell("BodyCell").is_flashing(), "a level gained")
	assert_true(_cell("AgilityCell").is_flashing(), "a level set")
	assert_false(_cell("StrengthCell").is_flashing(), "XP that buys no level")
	assert_false(_cell("MindCell").is_flashing(), "a stat nothing touched")

## A save loading, a lowered level and a hold play no level-up look.
func test_a_load_a_lowered_level_or_a_hold_plays_no_look() -> void:
	var save := SaveGameData.new()
	save.stat_training.set_level(Attribute.MIND, 6)
	await wait_process_frames(1)
	_use_fresh_save(save)
	await wait_process_frames(1)
	assert_eq(_cell_text("MindCell", "LevelLabel"), "Lv 6", "precondition: the load shows")
	assert_false(_cell("MindCell").is_flashing(), "a load")
	CharacterManager.set_stat_level(Attribute.MIND, 3)
	_plate.hold_stat_xp(Attribute.CONTROL, 1.0)
	_plate.release_stat_xp(Attribute.CONTROL, 0.5)
	await wait_process_frames(1)
	assert_false(_cell("MindCell").is_flashing(), "a lowered level")
	assert_false(_cell("ControlCell").is_flashing(), "a hold and a landing that cross no level")

#-----------------------------------------------------------------------------
# HOVER FIGURE
#-----------------------------------------------------------------------------

## The figure line, under the cap and at it, with and without a stage to break
## through to.
func test_the_figure_line() -> void:
	var cases: Array[Dictionary] = [
		{"name": "the XP floors and the cost rounds up", "level": 4, "xp": 105.9, "cost": 195.3125, "capped": false, "next": true, "text": "105 / 196 XP to Lv 5"},
		{"name": "the cap with a stage to come", "level": 10, "xp": 0.0, "cost": 100.0, "capped": true, "next": true, "text": "Lv 10 is Foundation's cap. Break through to train it further."},
		{"name": "the last stage's cap", "level": 20, "xp": 0.0, "cost": 100.0, "capped": true, "next": false, "text": "Lv 20 is Copper's cap."},
	]
	for case: Dictionary in cases:
		var stage: String = "Foundation" if case.next else "Copper"
		assert_eq(StatTooltip.figure_text(case.level, case.xp, case.cost, case.capped, stage, case.next), case.text, case.name)

## Pointing at a cell shows its figure beside the cabinet, level with the cell;
## the figure follows the cell as XP lands, and leaving the cell hides it.
func test_the_hover_figure_follows_the_cell() -> void:
	CharacterManager.set_stat_level(Attribute.SPIRIT, 4, 100.0)
	_plate.hold_stat_xp(Attribute.SPIRIT, 50.0)
	var cell: StatCell = _cell("SpiritCell")
	cell.hover_changed.emit(true)
	assert_true(_tooltip().visible, "the figure shows")
	assert_eq(_tooltip_text("TitleLabel"), "Spirit Lv 4", "the stat and its level")
	assert_eq(_tooltip_text("FigureLabel"), "50 / 196 XP to Lv 5", "the XP the cell shows, less what flies")
	assert_eq(_tooltip().global_position, Vector2(_plate.global_position.x + CultivatorPlate.TOOLTIP_X, cell.global_position.y + CultivatorPlate.TOOLTIP_DROP), "beside the cabinet, level with the cell")
	_plate.release_stat_xp(Attribute.SPIRIT, 50.0)
	assert_eq(_tooltip_text("FigureLabel"), "100 / 196 XP to Lv 5", "it follows the landing")
	cell.hover_changed.emit(false)
	assert_false(_tooltip().visible, "leaving the cell hides it")

## A long figure wraps and the board grows to an even height.
func test_the_hover_board_grows_with_its_figure() -> void:
	var cell: StatCell = _cell("ControlCell")
	cell.hover_changed.emit(true)
	var one_line: float = _tooltip().size.y
	CharacterManager.set_stat_level(Attribute.CONTROL, CharacterManager.get_stat_level_cap())
	assert_gt(_tooltip().size.y, one_line, "the cap's two sentences wrap and the board grows")
	assert_eq(fmod(_tooltip().size.y, 2.0), 0.0, "an even height, on the 2 px grid")

#-----------------------------------------------------------------------------
# ROOT
#-----------------------------------------------------------------------------

func test_root_stops_clicks() -> void:
	assert_eq(_plate.mouse_filter, Control.MOUSE_FILTER_STOP)
