extends GutTest

## Integration tests for the Character book: what it shows and what it follows
## while it is open. The left page holds the six stats as tiles on their sides,
## each with its level, its XP toward the next level, its total and, at the
## cap, a full bar under a CAPPED seal; under them, "In a fight" lists the
## totals a fight reads. The right page describes the stat pointed at: its
## level against the cap, what it does now and at the next level (worked out
## from the stat block's own functions and the techniques the player knows),
## and where its total comes from. While shown, the book follows the stats,
## their levels and XP, the gear, and the stage, whose breakthrough lifts the
## cap. Its pages wait for the book to open. Every test runs on a fresh save,
## swapped in and restored around it, and a test that swaps in its own stages
## has them restored too.

const CharacterViewScene := preload("res://scenes/character/character_view.tscn")
const GearFixture := preload("res://tests/helpers/gear_fixture.gd")
const ANIMATION_TIMEOUT: float = 2.0
const Attribute := CharacterAttributesData.AttributeType
const Stat := StatModifierData.Stat
## The modifier source a test sets; after_each() removes it.
const TEST_SOURCE: StringName = &"test_character_book"
const BASIC_STRIKE: String = "res://resources/abilities/basic_strike.tres"
const EMPTY_PALM: String = "res://resources/abilities/empty_palm.tres"
const FOUNDATIONAL: String = "foundation_technique"
const SMOOTH_FLOW: String = "smooth_flow"
const TORRENTIAL_FLOW: String = "torrential_flow"
const STONE_LIFTING: String = "stone_lifting"
const HORSE_STANCE: String = "horse_stance"
const FALLING_LEAF: String = "falling_leaf"

var _view: CharacterView
var _previous_save: SaveGameData
var _original_stage_resources: Array[AdvancementStageResource] = []

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_stage_resources = CultivationManager.advancement_stage_resources
	_previous_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new_current()
	PersistenceManager.save_data_reset.emit()
	PersistenceManager.save_game_data.unlocked_ability_ids = ["basic_strike", "empty_palm"]
	# Other suites replace the catalog index with fakes; start from the real one.
	AbilityManager._build_catalog_index()
	_view = CharacterViewScene.instantiate() as CharacterView
	add_child_autofree(_view)

func after_each() -> void:
	CharacterManager.remove_modifier_source(TEST_SOURCE)
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	# The stages first: the restored save is read against the real ones.
	CultivationManager.advancement_stage_resources = _original_stage_resources
	PersistenceManager.save_game_data = _previous_save
	PersistenceManager.save_data_reset.emit()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _tile(tile_name: String) -> AttributeTile:
	return _view.find_child(tile_name, true, false) as AttributeTile

func _label(label_name: String) -> Label:
	return _view.find_child(label_name, true, false) as Label

func _page_title(title_name: String) -> PageTitle:
	return _view.find_child(title_name, true, false) as PageTitle

## A main-hand sword giving +10% Strength, at least +2.
func _sword() -> ItemInstanceData:
	var sword: EquipmentDefinitionData = GearFixture.item({&"strength": 0.1}, 2)
	sword.item_id = "test_character_book_sword"
	sword.slot_type = EquipmentDefinitionData.EquipmentSlot.MAIN_HAND
	var instance := ItemInstanceData.new()
	instance.item_definition = sword
	return instance

## Unlocks and equips the cycling technique with this id.
func _equip_technique(technique_id: String) -> void:
	CyclingManager.unlock_technique(technique_id)
	CyclingManager.equip_technique(technique_id)

## The parsed value of the right page's first WHAT IT DOES row.
func _first_effect_value() -> String:
	var row := _view.get_node("%EffectRows").get_child(0) as TableRow
	return (row.get_node("%Value") as RichTextLabel).get_parsed_text()

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
# THE TILES
#-----------------------------------------------------------------------------

func test_the_tiles_are_the_six_stats_on_their_sides() -> void:
	var sides: Dictionary[String, Array] = {
		"PhysicalTiles": StatDisplay.PHYSICAL,
		"SpiritualTiles": StatDisplay.SPIRITUAL,
	}
	for grid_name: String in sides:
		var stats: Array[CharacterAttributesData.AttributeType] = []
		for tile: AttributeTile in _view.find_child(grid_name, true, false).get_children():
			stats.append(tile.attribute_type)
		assert_eq(stats, sides[grid_name], "%s holds its side's stats, in StatDisplay's order" % grid_name)

func test_a_tile_shows_its_level_xp_and_total() -> void:
	CharacterManager.set_stat_level(Attribute.SPIRIT, 4, 30.0)
	_view.refresh()
	var tile: AttributeTile = _tile("SpiritTile")
	var bar := tile.get_node("%XpBar") as LacquerRod
	assert_eq((tile.get_node("%LevelLabel") as Label).text, "Lv 4", "the tile shows Spirit's level")
	assert_eq((tile.get_node("%ValueLabel") as Label).text, "%.0f" % CharacterManager.get_stat(Stat.SPIRIT),
		"the tag shows Spirit's total")
	assert_eq(bar.get_step(), floori(30.0 / CharacterManager.get_stat_xp_to_next(Attribute.SPIRIT) * bar.steps),
		"the bar holds Spirit's XP toward its next level")
	assert_false((tile.get_node("%CapSeal") as Label).visible, "a stat under the cap shows no seal")

func test_a_capped_tile_shows_the_cap() -> void:
	CharacterManager.set_stat_level(Attribute.STRENGTH, CharacterManager.get_stat_level_cap())
	_view.refresh()
	var strength_tile: AttributeTile = _tile("StrengthTile")
	var bar := strength_tile.get_node("%XpBar") as LacquerRod
	assert_true((strength_tile.get_node("%CapSeal") as Label).visible, "Strength at the cap shows the seal")
	assert_eq(bar.get_step(), bar.steps, "the bar of a capped stat is full, though it holds 0 XP")
	assert_false((_tile("BodyTile").get_node("%CapSeal") as Label).visible, "Body, under the cap, shows no seal")
	CharacterManager.set_stat_level(Attribute.STRENGTH, 1)
	_view.refresh()
	assert_false((strength_tile.get_node("%CapSeal") as Label).visible, "the seal goes once Strength is under the cap again")

func test_the_xp_fraction_both_bars_share() -> void:
	var cases: Array[Array] = [
		# xp, xp_to_next, capped, expected
		[0.0, 100.0, false, 0.0],
		[25.0, 100.0, false, 0.25],
		[155.6, 156.0, false, 155.6 / 156.0],
		[10.0, 0.0, false, 0.0],
		[0.0, 156.0, true, 1.0],
	]
	for case: Array in cases:
		assert_almost_eq(AttributeTile.xp_fraction(case[0], case[1], case[2]), case[3], 0.0001,
			"%s of %s XP, capped %s" % [case[0], case[1], case[2]])

## Just short of a level, neither XP bar reads full: each shows only the steps
## the XP has earned.
func test_the_bars_never_read_full_short_of_a_level() -> void:
	CharacterManager.set_stat_level(Attribute.BODY, 3)
	CharacterManager.add_stat_xp(Attribute.BODY, CharacterManager.get_stat_xp_to_next(Attribute.BODY) - 0.4)
	assert_eq(CharacterManager.get_stat_level(Attribute.BODY), 3, "precondition: Body is still Lv 3")
	_view.select_attribute(Attribute.BODY)
	_view.refresh()
	for bar: LacquerRod in [_tile("BodyTile").get_node("%XpBar"), _view.get_node("%DetailXpBar")]:
		assert_lt(bar.get_step(), bar.steps, "%s is not full 0.4 XP short of the level" % bar.get_parent().name)

func test_the_book_follows_stats_while_open() -> void:
	_view.show()
	_view.refresh()
	var tile: AttributeTile = _tile("SpiritTile")
	CharacterManager.add_stat_levels(Attribute.SPIRIT, 1)
	assert_eq((tile.get_node("%LevelLabel") as Label).text, "Lv 2", "a level gained shows on the open book")
	CharacterManager.add_stat_xp(Attribute.SPIRIT, 10.0)
	var bar := tile.get_node("%XpBar") as LacquerRod
	assert_eq(bar.get_step(), floori(10.0 / CharacterManager.get_stat_xp_to_next(Attribute.SPIRIT) * bar.steps),
		"XP gained moves the open book's bar")

func test_the_book_follows_gear_while_open() -> void:
	_view.show()
	_view.select_attribute(Attribute.STRENGTH)
	_view.refresh()
	InventoryManager.equip_item(_sword(), EquipmentDefinitionData.EquipmentSlot.MAIN_HAND)
	assert_gt(CharacterManager.get_gear_bonus(Attribute.STRENGTH), 0.0, "precondition: the sword raises Strength")
	assert_eq(_label("DetailValue").text, "%.0f" % CharacterManager.get_stat(Stat.STRENGTH),
		"the open page's total counts the sword just put on")

## The cap comes from the stage, so a breakthrough while the book is open lifts
## it there and then.
func test_the_book_follows_a_breakthrough_while_open() -> void:
	_use_stat_caps(3, 6)
	_view.show()
	CharacterManager.set_stat_level(Attribute.STRENGTH, 3)
	var seal := _tile("StrengthTile").get_node("%CapSeal") as Label
	assert_true(seal.visible, "precondition: Strength is capped at Foundation's 3")
	assert_true(CultivationManager.advance_to_next_stage(), "precondition: the breakthrough lands")
	assert_false(seal.visible, "Copper's cap of 6 leaves room, so the open book drops the seal")

#-----------------------------------------------------------------------------
# THE DETAIL PAGE
#-----------------------------------------------------------------------------

func test_opening_shows_strength() -> void:
	_view.select_attribute(Attribute.CONTROL)
	_view.animate_open()
	assert_eq(_view.get_selected_attribute(), Attribute.STRENGTH, "the book opens on Strength")
	assert_eq(_page_title("DetailPlaque").title, "Strength", "the right page is headed Strength")
	assert_true(_tile("StrengthTile").is_selected(), "Strength's tile wears the printer's marks")

func test_pointing_at_a_tile_describes_it() -> void:
	_view.animate_open()
	var body_tile: AttributeTile = _tile("BodyTile")
	body_tile.hovered.emit(body_tile)
	assert_eq(_page_title("DetailPlaque").title, "Body", "the right page is headed with the stat pointed at")
	assert_eq(_label("DetailGroup").text, StatDisplay.side_name(Attribute.BODY).to_upper(), "the page names Body's side")
	assert_eq(_label("DetailDescription").text, CharacterView.STAT_DESCRIPTIONS[Attribute.BODY], "the page describes Body")
	for tile_name: String in ["StrengthTile", "BodyTile", "AgilityTile", "SpiritTile", "MindTile", "ControlTile"]:
		assert_eq(_tile(tile_name).is_selected(), tile_name == "BodyTile", "only BodyTile is selected: %s" % tile_name)

func test_every_stat_has_a_description() -> void:
	for stat: int in Attribute.values():
		assert_ne(CharacterView.STAT_DESCRIPTIONS.get(stat, ""), "", "%s has a description" % CharacterAttributesData.stat_key(stat))

func test_each_stat_names_what_it_does() -> void:
	var abilities: Array[AbilityData] = [load(BASIC_STRIKE) as AbilityData, load(EMPTY_PALM) as AbilityData]
	var technique: CyclingTechniqueData = CyclingManager.get_technique(SMOOTH_FLOW)
	var cases: Array[Dictionary] = [
		{"stat": Attribute.STRENGTH, "labels": ["Basic Strike damage"]},
		{"stat": Attribute.BODY, "labels": ["Max Health"]},
		{"stat": Attribute.AGILITY, "labels": ["Max Stamina", "Stamina regen", "Dodge chance"]},
		{"stat": Attribute.SPIRIT, "labels": ["Madra per cycle", "Empty Palm damage"]},
		{"stat": Attribute.MIND, "labels": ["Max Madra"]},
		{"stat": Attribute.CONTROL, "labels": ["Technique cost cut", "Cooldown cut"]},
	]
	for case: Dictionary in cases:
		var labels: Array[String] = []
		var lines: Array[Dictionary] = CharacterView.effect_lines(case.stat, CharacterAttributesData.make(), CharacterAttributesData.make(), abilities, technique)
		for line: Dictionary in lines:
			labels.append(line.label)
		assert_eq(labels, case.labels, "%s names what it does" % StatDisplay.name_of(case.stat))

func test_now_and_next_come_from_the_blocks_functions() -> void:
	var now := CharacterAttributesData.make()
	var next := CharacterAttributesData.make({&"body": 11.0, &"spirit": 11.0})
	var empty_palm := load(EMPTY_PALM) as AbilityData
	var abilities: Array[AbilityData] = [empty_palm]
	var health: Dictionary = CharacterView.effect_lines(Attribute.BODY, now, next, abilities)[0]
	assert_eq(health.now, AbilityRow.format_number(now.get_max_health()), "Max Health now is the now block's get_max_health()")
	assert_eq(health.next, AbilityRow.format_number(next.get_max_health()), "Max Health next is the next block's get_max_health()")
	var palm_effect: CombatEffectData = empty_palm.effects_on_target[0]
	var palm: Dictionary = CharacterView.effect_lines(Attribute.SPIRIT, now, next, abilities)[0]
	assert_eq(palm.now, AbilityRow.format_number(palm_effect.calculate_value(now)), "Empty Palm's damage now is calculate_value() on the now block")
	assert_eq(palm.next, AbilityRow.format_number(palm_effect.calculate_value(next)), "Empty Palm's damage next is calculate_value() on the next block")

## Spirit's first line is the Madra a cycle of the technique draws, now and one
## level up, each figure the one the technique's drawer prints at that Spirit.
func test_spirit_reads_madra_per_cycle_first() -> void:
	var now := CharacterAttributesData.make({&"spirit": 12.0})
	var next := CharacterAttributesData.make({&"spirit": 13.0})
	var no_abilities: Array[AbilityData] = []
	for technique_id: String in [FOUNDATIONAL, SMOOTH_FLOW, TORRENTIAL_FLOW]:
		var technique: CyclingTechniqueData = CyclingManager.get_technique(technique_id)
		var line: Dictionary = CharacterView.effect_lines(Attribute.SPIRIT, now, next, no_abilities, technique)[0]
		assert_eq(line.label, "Madra per cycle", "%s: Madra per cycle comes first" % technique_id)
		assert_string_starts_with(TechniqueDrawer.detail_text(technique, now.get_cycling_madra_multiplier()), "%s Madra " % line.now,
			"%s: the now figure is the drawer's" % technique_id)
		assert_string_starts_with(TechniqueDrawer.detail_text(technique, next.get_cycling_madra_multiplier()), "%s Madra " % line.next,
			"%s: the next figure is the drawer's one level up" % technique_id)

## With no technique there is no Madra per cycle line.
func test_spirit_without_a_technique_has_no_madra_per_cycle() -> void:
	var abilities: Array[AbilityData] = [load(EMPTY_PALM) as AbilityData]
	var lines: Array[Dictionary] = CharacterView.effect_lines(Attribute.SPIRIT, CharacterAttributesData.make(), CharacterAttributesData.make(), abilities)
	assert_eq(lines.size(), 1, "only Empty Palm's line")

## The next figures read the stat's total one level up, the worn gear counted
## again: +15% Spirit gives +1 at Lv 4 (13) and +2 at Lv 5 (14).
func test_next_figures_count_the_gear_the_next_level_adds() -> void:
	CharacterManager.set_stat_level(Attribute.SPIRIT, 4)
	var cowl: EquipmentDefinitionData = GearFixture.item({&"spirit": 0.15})
	cowl.item_id = "test_character_book_cowl"
	cowl.slot_type = EquipmentDefinitionData.EquipmentSlot.HEAD
	var instance := ItemInstanceData.new()
	instance.item_definition = cowl
	InventoryManager.equip_item(instance, EquipmentDefinitionData.EquipmentSlot.HEAD)
	_equip_technique(SMOOTH_FLOW)
	_view.select_attribute(Attribute.SPIRIT)
	_view.refresh()
	assert_eq(_first_effect_value(), "112 → 128", "Spirit 14 now and 16 at Lv 5: 80 Madra x 1.4, then x 1.6")

func test_a_capped_spirit_shows_madra_per_cycle_alone() -> void:
	CharacterManager.set_stat_level(Attribute.SPIRIT, CharacterManager.get_stat_level_cap())
	_equip_technique(SMOOTH_FLOW)
	_view.select_attribute(Attribute.SPIRIT)
	_view.refresh()
	var multiplier: float = CharacterManager.get_total_attributes_data().get_cycling_madra_multiplier()
	assert_eq(_first_effect_value(), "%d" % roundi(CyclingManager.get_technique(SMOOTH_FLOW).get_madra_per_cycle(multiplier)),
		"at the cap, Madra per cycle shows its current figure alone")

## The cycles to the next level are the XP it still needs over what one
## perfect cycle of the technique pays the stat, rounded up: none while the
## stat is capped, with no technique, or when the technique pays it nothing.
func test_cycles_to_next_level_reads_the_equipped_technique() -> void:
	var smooth: CyclingTechniqueData = CyclingManager.get_technique(SMOOTH_FLOW)
	var torrential: CyclingTechniqueData = CyclingManager.get_technique(TORRENTIAL_FLOW)
	CharacterManager.set_stat_level(Attribute.SPIRIT, 3, 40.0)
	CharacterManager.set_stat_level(Attribute.CONTROL, 2, 30.0)
	var cases: Array[Array] = [
		# stat, technique, cycles
		[Attribute.SPIRIT, smooth, ceili((CharacterManager.get_stat_xp_to_next(Attribute.SPIRIT) - 40.0) / 30.0)],
		[Attribute.CONTROL, smooth, 4],
		[Attribute.MIND, smooth, 0],
		[Attribute.MIND, torrential, 7],
		[Attribute.STRENGTH, smooth, 0],
		[Attribute.SPIRIT, null, 0],
	]
	for case: Array in cases:
		var technique_name: String = case[1].technique_name if case[1] != null else "no technique"
		assert_eq(CharacterView.cycles_to_next_level(case[0], case[1]), case[2],
			"%s with %s" % [StatDisplay.name_of(case[0]), technique_name])
	CharacterManager.set_stat_level(Attribute.SPIRIT, CharacterManager.get_stat_level_cap())
	assert_eq(CharacterView.cycles_to_next_level(Attribute.SPIRIT, smooth), 0, "a capped stat counts no cycles")

## One cycle reads in the singular.
func test_a_count_of_one_reads_in_the_singular() -> void:
	assert_eq(CharacterView.cycles_line(1, 4), "1 perfect cycle to Lv 4")
	assert_eq(CharacterView.cycles_line(4, 4), "4 perfect cycles to Lv 4")

## The sets to the next level are the XP it still needs over what one perfect
## set of the drill pays the stat (DrillRules.perfect_set_xp()), rounded up:
## none while the stat is capped, with no drill, or when the drill pays it
## nothing. Every drill pays Strength.
func test_sets_to_next_level_reads_the_equipped_drill() -> void:
	var stone: DrillData = BodyRefiningManager.get_drill(STONE_LIFTING)
	var horse: DrillData = BodyRefiningManager.get_drill(HORSE_STANCE)
	var leaf: DrillData = BodyRefiningManager.get_drill(FALLING_LEAF)
	CharacterManager.set_stat_level(Attribute.STRENGTH, 3, 40.0)
	CharacterManager.set_stat_level(Attribute.BODY, 2, 30.0)
	CharacterManager.set_stat_level(Attribute.AGILITY, 2, 10.0)
	var strength_left: float = CharacterManager.get_stat_xp_to_next(Attribute.STRENGTH) - 40.0
	var cases: Array[Array] = [
		# stat, drill, sets
		[Attribute.STRENGTH, stone, ceili(strength_left / DrillRules.perfect_set_xp(stone, Attribute.STRENGTH))],
		[Attribute.STRENGTH, leaf, ceili(strength_left / DrillRules.perfect_set_xp(leaf, Attribute.STRENGTH))],
		[Attribute.BODY, horse, 3],
		[Attribute.BODY, stone, 0],
		[Attribute.BODY, leaf, 0],
		[Attribute.AGILITY, leaf, 6],
		[Attribute.AGILITY, horse, 0],
		[Attribute.SPIRIT, stone, 0],
		[Attribute.STRENGTH, null, 0],
	]
	for case: Array in cases:
		var drill_name: String = case[1].drill_name if case[1] != null else "no drill"
		assert_eq(CharacterView.sets_to_next_level(case[0], case[1]), case[2],
			"%s with %s" % [StatDisplay.name_of(case[0]), drill_name])
	CharacterManager.set_stat_level(Attribute.STRENGTH, CharacterManager.get_stat_level_cap())
	assert_eq(CharacterView.sets_to_next_level(Attribute.STRENGTH, stone), 0, "a capped stat counts no sets")

## One perfect set lowers the count by exactly one, and a count never reads 0
## while XP is still needed.
func test_one_perfect_set_lowers_the_count_by_one() -> void:
	var stone: DrillData = BodyRefiningManager.get_drill(STONE_LIFTING)
	var per_set: float = DrillRules.perfect_set_xp(stone, Attribute.STRENGTH)
	CharacterManager.set_stat_level(Attribute.STRENGTH, 5, 1.0)
	var before: int = CharacterView.sets_to_next_level(Attribute.STRENGTH, stone)
	assert_gt(before, 1, "precondition: Lv 5 takes more than one set")
	CharacterManager.add_stat_xp(Attribute.STRENGTH, per_set)
	assert_eq(CharacterView.sets_to_next_level(Attribute.STRENGTH, stone), before - 1, "one perfect set's XP lowers it by one")
	var left: float = CharacterManager.get_stat_xp_to_next(Attribute.STRENGTH) - CharacterManager.get_stat_xp(Attribute.STRENGTH)
	CharacterManager.add_stat_xp(Attribute.STRENGTH, left - 0.01)
	assert_eq(CharacterView.sets_to_next_level(Attribute.STRENGTH, stone), 1, "a sliver short of the level still takes one set")

## One set reads in the singular.
func test_a_set_count_of_one_reads_in_the_singular() -> void:
	assert_eq(CharacterView.sets_line(1, 4), "1 perfect set to Lv 4")
	assert_eq(CharacterView.sets_line(2, 4), "2 perfect sets to Lv 4")

func test_the_cycles_line_follows_the_equipped_technique() -> void:
	CharacterManager.set_stat_level(Attribute.CONTROL, 2, 30.0)
	_equip_technique(SMOOTH_FLOW)
	_view.show()
	_view.select_attribute(Attribute.CONTROL)
	_view.refresh()
	assert_true((_view.get_node("%CyclesRow") as Control).visible, "Smooth Flow trains Control, so its page counts cycles")
	assert_eq(_label("CyclesLabel").text, CharacterView.cycles_line(4, 3))
	_equip_technique(FOUNDATIONAL)
	assert_false((_view.get_node("%CyclesRow") as Control).visible,
		"equipping a technique that pays Control nothing hides the line at once")

func test_the_cycles_line_names_no_technique() -> void:
	CharacterManager.set_stat_level(Attribute.SPIRIT, 3, 40.0)
	_equip_technique(SMOOTH_FLOW)
	_view.select_attribute(Attribute.SPIRIT)
	_view.refresh()
	for technique: CyclingTechniqueData in CyclingManager.get_all_techniques():
		assert_false(technique.technique_name in _label("CyclesLabel").text, "the line never names %s" % technique.technique_name)

func test_physical_and_capped_pages_show_no_cycles_line() -> void:
	_equip_technique(SMOOTH_FLOW)
	for stat: Attribute in StatDisplay.PHYSICAL:
		_view.select_attribute(stat)
		_view.refresh()
		assert_false((_view.get_node("%CyclesRow") as Control).visible, "%s shows no cycles line" % StatDisplay.name_of(stat))
	CharacterManager.set_stat_level(Attribute.SPIRIT, CharacterManager.get_stat_level_cap())
	_view.select_attribute(Attribute.SPIRIT)
	_view.refresh()
	assert_false((_view.get_node("%CyclesRow") as Control).visible, "a capped Spirit shows no cycles line")

func test_the_page_shows_a_row_per_effect() -> void:
	_view.select_attribute(Attribute.SPIRIT)
	var block: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	var technique: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	var known: Array[Dictionary] = CharacterView.effect_lines(Attribute.SPIRIT, block, block, AbilityManager.get_unlocked_abilities(), technique)
	var every: Array[Dictionary] = CharacterView.effect_lines(Attribute.SPIRIT, block, block, AbilityManager.get_all_abilities(), technique)
	assert_lt(known.size(), every.size(), "precondition: the locked Power Font stays off the page")
	assert_eq(_view.get_node("%EffectRows").get_child_count(), known.size(), "a row per line Spirit's known techniques give")

func test_a_stat_with_no_known_technique_says_so() -> void:
	PersistenceManager.save_game_data.unlocked_ability_ids = ["enforce"]
	_view.select_attribute(Attribute.STRENGTH)
	assert_true(_label("NoEffectsLabel").visible, "Strength with no physical technique known says so")
	assert_eq(_view.get_node("%EffectRows").get_child_count(), 0, "and lists no row")
	_view.select_attribute(Attribute.BODY)
	assert_false(_label("NoEffectsLabel").visible, "Body always has its Max Health line")

func test_a_capped_stats_page_has_no_next_level() -> void:
	CharacterManager.set_stat_level(Attribute.BODY, CharacterManager.get_stat_level_cap())
	_view.select_attribute(Attribute.BODY)
	_view.refresh()
	var bar := _view.find_child("DetailXpBar", true, false) as LacquerRod
	assert_true(_label("DetailCapSeal").visible, "Body at the cap shows the seal")
	assert_eq(bar.get_step(), bar.steps, "the page's bar of a capped stat is full")
	assert_false(_label("DetailXpLabel").visible, "a capped stat shows no XP figure")
	assert_false(_label("NextLevelCaption").visible, "a capped stat names no next level")
	var first_row := _view.get_node("%EffectRows").get_child(0) as TableRow
	assert_eq((first_row.get_node("%Value") as RichTextLabel).get_parsed_text(),
		AbilityRow.format_number(CharacterManager.get_total_attributes_data().get_max_health()),
		"Max Health shows its figure now alone, with no next figure")
	CharacterManager.set_stat_level(Attribute.BODY, 1)
	_view.refresh()
	assert_true(_label("NextLevelCaption").visible, "under the cap, the page names the next level")
	assert_true(_label("DetailXpLabel").visible, "under the cap, the page shows the XP figure")
	assert_string_contains(_label("NextLevelCaption").text, "2")
	assert_false(_label("DetailCapSeal").visible, "the seal goes under the cap")

## A part of a cycle pays part of its XP, so XP can sit a fraction under a
## level's whole cost: the figure floors it, never reading the cost as met.
## Added as XP, not set: set_stat_level() keeps the XP a point under the cost.
func test_the_xp_figure_never_shows_an_unmet_threshold_as_met() -> void:
	CharacterManager.set_stat_level(Attribute.BODY, 3)
	CharacterManager.add_stat_xp(Attribute.BODY, 155.6)
	assert_eq(CharacterManager.get_stat_level(Attribute.BODY), 3, "precondition: Body is still Lv 3")
	assert_eq(CharacterManager.get_stat_xp_to_next(Attribute.BODY), 156.0, "precondition: Lv 3 costs 156")
	_view.select_attribute(Attribute.BODY)
	_view.refresh()
	assert_eq(_label("DetailXpLabel").text, "155 / 156 XP", "155.6 reads 155, never 156")

func test_the_page_shows_trained_plus_gear() -> void:
	InventoryManager.equip_item(_sword(), EquipmentDefinitionData.EquipmentSlot.MAIN_HAND)
	assert_gt(CharacterManager.get_gear_bonus(Attribute.STRENGTH), 0.0, "precondition: the sword raises Strength")
	var lines: Array[Dictionary] = CharacterView.source_lines(Attribute.STRENGTH)
	assert_eq(lines.size(), 2, "Strength's total comes from its training and its gear")
	if lines.size() == 2:
		assert_eq(lines[0].value, AbilityRow.format_number(CharacterManager.get_trained_value(Attribute.STRENGTH)),
			"the first line is the trained value")
		assert_eq(lines[1].value, "+%s" % AbilityRow.format_number(CharacterManager.get_gear_bonus(Attribute.STRENGTH)),
			"the second line is the gear's bonus")

#-----------------------------------------------------------------------------
# IN A FIGHT
#-----------------------------------------------------------------------------

func test_in_a_fight_lists_every_total() -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, func() -> Array[StatModifierData]:
		var modifiers: Array[StatModifierData] = [
			StatModifierData.new(Stat.ARMOR, StatModifierData.Kind.FLAT, 6.0),
			StatModifierData.new(Stat.WARD, StatModifierData.Kind.FLAT, 4.0),
		]
		return modifiers)
	var lines: Array[Dictionary] = CharacterView.fight_lines()
	var labels: Array[String] = []
	var values: Dictionary[String, String] = {}
	for line: Dictionary in lines:
		labels.append(line.label)
		values[line.label] = line.value
	assert_eq(labels, ["Health", "Madra", "Stamina", "Dodge chance", "Technique cost cut", "Cooldown cut", "Armor", "Ward"],
		"In a fight lists every total a fight reads, in order")
	assert_eq(values.get("Health"), "100 / 100", "Health is the saved pool over its max: a fresh save is full")
	assert_eq(values.get("Armor"), "6", "Armor is the armor total")
	assert_eq(values.get("Ward"), "4", "Ward is the Ward total")

func test_the_fight_block_shows_a_row_per_total() -> void:
	_view.refresh()
	var rows: int = _view.get_node("%FightLeftColumn").get_child_count() + _view.get_node("%FightRightColumn").get_child_count()
	assert_eq(rows, CharacterView.fight_lines().size(), "a row per fight total")

#-----------------------------------------------------------------------------
# OPENING
#-----------------------------------------------------------------------------

func test_pages_wait_for_the_open_book() -> void:
	var page_layer: Control = _view.find_child("PageLayer", true, false) as Control
	_view.animate_open()
	assert_false(page_layer.visible, "pages appear only once the book lies open")
	await wait_for_signal(_view.book_frame.opened, ANIMATION_TIMEOUT)
	assert_true(page_layer.visible)

func test_pages_hide_as_the_book_closes() -> void:
	var page_layer: Control = _view.find_child("PageLayer", true, false) as Control
	_view.animate_open()
	await wait_for_signal(_view.book_frame.opened, ANIMATION_TIMEOUT)
	watch_signals(_view)
	_view.animate_close()
	assert_false(page_layer.visible)
	await wait_for_signal(_view.close_finished, ANIMATION_TIMEOUT)
	assert_signal_emitted(_view, "close_finished")
