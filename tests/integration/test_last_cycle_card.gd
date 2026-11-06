extends GutTest

## Integration tests for the zone chest's last cycle card (LastCycleCard): a
## chip for each thing the cycle paid, the score of studs for its zones or its
## seal nodes, and a row that wraps and grows rather than trims.

const CARD_SCENE: PackedScene = preload("res://scenes/zones/zone_panel/last_cycle_card/last_cycle_card.tscn")
const MADRA_ICON: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_madra_ai.png")

const SPIRIT: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.SPIRIT
const MIND: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.MIND
const CONTROL: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.CONTROL

const CHIP_NAMES: Array[String] = ["MadraChip", "SpiritChip", "MindChip", "ControlChip"]

var _card: LastCycleCard = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_card = CARD_SCENE.instantiate() as LastCycleCard
	add_child_autofree(_card)

func after_each() -> void:
	_card = null

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A cycle's result: `madra` Madra, the XP each stat in `stats` took
## (AttributeType to XP), and its zones' or seal nodes' states.
func _result(madra: float, stats: Dictionary, zone_states: Array[int] = [], seal_states: Array[int] = []) -> CycleResult:
	var result := CycleResult.new()
	result.madra_added = madra
	for stat: CharacterAttributesData.AttributeType in stats:
		result.record_stat_xp(stat, stats[stat], false)
	result.zone_states = zone_states
	result.seal_states = seal_states
	return result

func _chip(chip_name: String) -> Control:
	return _card.get_node("%" + chip_name) as Control

func _amount(chip_name: String) -> Label:
	return _chip(chip_name).get_node("%Amount") as Label

func _icon(chip_name: String) -> Texture2D:
	return (_chip(chip_name).get_node("%Icon") as TextureRect).texture

## The frame of each stud in the score, in order.
func _stud_frames() -> Array[int]:
	var frames: Array[int] = []
	for stud: Node in _card.get_node("%Score").get_children():
		frames.append((stud as LacquerStripRect).get_frame().x)
	return frames

#-----------------------------------------------------------------------------
# CHIPS
#-----------------------------------------------------------------------------

func test_the_chips_show_what_the_cycle_paid() -> void:
	_card.show_result(_result(79.6, {SPIRIT: 30.0, CONTROL: 21.0}))
	assert_eq(_amount("MadraChip").text, "+80", "the Madra, rounded")
	assert_eq(_icon("MadraChip"), MADRA_ICON, "the Madra's mini icon")
	for row: Array in [["SpiritChip", SPIRIT, "+30"], ["ControlChip", CONTROL, "+21"]]:
		assert_true(_chip(row[0]).visible, "%s shows" % row[0])
		assert_eq(_amount(row[0]).text, row[2])
		assert_eq(_icon(row[0]), StatDisplay.icon_of(row[1]), "%s shows its stat's icon" % row[0])
	assert_false(_chip("MindChip").visible, "a stat the cycle did not pay has no chip")

func test_a_capped_stat_reads_capped() -> void:
	var result: CycleResult = _result(80.0, {SPIRIT: 30.0})
	result.record_stat_xp(CONTROL, 0.0, true)
	_card.show_result(result)
	assert_true(_chip("ControlChip").visible, "a capped stat keeps its chip")
	assert_eq(_amount("ControlChip").text, "capped")
	assert_eq(_amount("SpiritChip").text, "+30", "the others keep their XP")

#-----------------------------------------------------------------------------
# THE SCORE
#-----------------------------------------------------------------------------

func test_the_studs_follow_the_zones() -> void:
	var states: Array[int] = [CyclingZone.State.PERFECT, CyclingZone.State.GOOD, CyclingZone.State.SPENT, CyclingZone.State.OK]
	_card.show_result(_result(80.0, {}, states))
	assert_eq(_stud_frames(), [0, 1, 3, 2] as Array[int], "PERFECT, GOOD, a missed zone, OK")

func test_the_seals_show_as_seal_nodes() -> void:
	var states: Array[int] = [SealNode.State.OPEN, SealNode.State.SPENT, SealNode.State.OPEN]
	_card.show_result(_result(50.0, {}, [], states))
	assert_eq(_stud_frames(), [4, 5, 4] as Array[int], "opened, missed, opened")

func test_the_foundational_card_has_no_score() -> void:
	_card.show_result(_result(80.0, {}, [CyclingZone.State.PERFECT] as Array[int]))
	_card.show_result(_result(30.0, {SPIRIT: 12.0}))
	assert_eq(_stud_frames(), [] as Array[int], "no zones or seals, no studs: the last result's are gone")

#-----------------------------------------------------------------------------
# LONG TEXT
#-----------------------------------------------------------------------------

## A row too crowded for one line wraps its chips onto another rather than trim
## any, and the card grows with it.
func test_a_crowded_card_wraps_and_grows() -> void:
	var zones: Array[int] = [CyclingZone.State.PERFECT, CyclingZone.State.PERFECT, CyclingZone.State.GOOD, CyclingZone.State.OK]
	_card.show_result(_result(80.0, {SPIRIT: 30.0, CONTROL: 21.0}, zones))
	await wait_process_frames(2)
	assert_eq(_card.size.y, LastCycleCard.ONE_LINE_HEIGHT, "precondition: one line")
	watch_signals(_card)
	_card.show_result(_result(12345.0, {SPIRIT: 12345.0, MIND: 12345.0, CONTROL: 12345.0}, zones))
	await wait_process_frames(2)
	assert_gt(_card.size.y, LastCycleCard.ONE_LINE_HEIGHT, "the card grows")
	assert_signal_emitted(_card, "height_changed")
	var chips: Control = _card.get_node("%Chips") as Control
	assert_true(_card.get_global_rect().encloses(chips.get_global_rect()), "the chips stay on the card")
	for chip_name: String in CHIP_NAMES:
		assert_true(chips.get_global_rect().encloses(_chip(chip_name).get_global_rect()), "%s shows whole" % chip_name)
		assert_gte(_amount(chip_name).size.x, _amount(chip_name).get_minimum_size().x, "%s's amount is not cut" % chip_name)
