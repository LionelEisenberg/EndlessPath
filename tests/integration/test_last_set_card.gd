extends GutTest

## Integration tests for the zone chest's last set card (LastSetCard, #149): a
## chip for the Health the set restored, one for Strength's XP and one for the
## drill's other stat's for a set played by hand, "capped" and "full" where the
## cap or a full pool took the pay, the set's beads in bead order, and chips that
## wrap and grow rather than trim.

const CARD_SCENE: PackedScene = preload("res://scenes/zones/zone_panel/last_set_card/last_set_card.tscn")
const HEALTH_ICON: Texture2D = preload("res://assets/ui/lacquer/lacquer_pool_health_ai.png")
const BODY_STEEL_ICON: Texture2D = preload("res://assets/ui/lacquer/lacquer_stat_body_steel_ai.png")

const AttributeType = CharacterAttributesData.AttributeType
const Tier = DrillRules.Tier

var _card: LastSetCard = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_card = CARD_SCENE.instantiate() as LastSetCard
	add_child_autofree(_card)

func after_each() -> void:
	_card = null

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A set of `drill_id` whose reps were `tiers`, in bead order, each restoring
## `health_each`, and the XP each stat in `stats` took (AttributeType to XP).
func _result(drill_id: String, tiers: Array, health_each: float, stats: Dictionary) -> DrillSetResult:
	var result := DrillSetResult.new(BodyRefiningManager.get_drill(drill_id))
	for bead: int in tiers.size():
		result.add_rep(tiers[bead], health_each if tiers[bead] != Tier.MISS else 0.0)
		result.place_last_rep(bead)
	for stat: AttributeType in stats:
		result.record_stat_xp(stat, stats[stat], false)
	return result

func _ten(tier: Tier) -> Array:
	var tiers: Array = []
	tiers.resize(10)
	tiers.fill(tier)
	return tiers

func _chip(chip_name: String) -> Control:
	return _card.get_node("%" + chip_name) as Control

func _amount(chip_name: String) -> Label:
	return _chip(chip_name).get_node("%Amount") as Label

func _icon(chip_name: String) -> Texture2D:
	return (_chip(chip_name).get_node("%Icon") as TextureRect).texture

func _is_brass(chip_name: String) -> bool:
	return _amount(chip_name).has_theme_color_override(&"font_color")

## Each bead's frame, in order.
func _bead_frames() -> Array[int]:
	var frames: Array[int] = []
	for bead: Node in _card.get_node("%Beads").get_children():
		frames.append((bead as LacquerStripRect).get_frame().x)
	return frames

#-----------------------------------------------------------------------------
# CHIPS
#-----------------------------------------------------------------------------

func test_the_chips_show_what_a_set_paid() -> void:
	_card.show_result(_result("stone_lifting", _ten(Tier.PERFECT), 3.96, {AttributeType.STRENGTH: 47.6}))
	assert_eq(_icon("HealthChip"), HEALTH_ICON, "the Health pool heart")
	assert_eq(_amount("HealthChip").text, "+40", "what the set restored, rounded")
	assert_eq(_icon("StrengthChip"), StatDisplay.icon_of(AttributeType.STRENGTH))
	assert_eq(_amount("StrengthChip").text, "+48", "Strength's XP, rounded, no XP word")
	assert_false(_chip("MinorChip").visible, "Stone Lifting trains Strength alone")
	assert_false(_is_brass("HealthChip") or _is_brass("StrengthChip"), "figures in the chip's own colour")

## A full pool reads "full" and a capped stat "capped", both in brass.
func test_full_and_capped_read_in_brass() -> void:
	var result: DrillSetResult = _result("stone_lifting", _ten(Tier.PERFECT), 0.0, {})
	result.record_stat_xp(AttributeType.STRENGTH, 0.0, true)
	_card.show_result(result)
	assert_eq(_amount("HealthChip").text, "full")
	assert_true(_is_brass("HealthChip"))
	assert_eq(_amount("StrengthChip").text, "capped")
	assert_true(_is_brass("StrengthChip"))
	_card.show_result(_result("stone_lifting", _ten(Tier.PERFECT), 4.0, {AttributeType.STRENGTH: 60.0}))
	assert_false(_is_brass("HealthChip") or _is_brass("StrengthChip"), "the next set's figures lose the brass")

## A drill's other stat has its chip for a set played by hand, Body with its heart
## in steel apart from the Health heart; an Auto set pays Strength alone.
func test_the_other_stat_shows_for_a_set_by_hand() -> void:
	var cases: Array[Dictionary] = [
		{"drill": "horse_stance", "stat": AttributeType.BODY, "icon": BODY_STEEL_ICON},
		{"drill": "falling_leaf", "stat": AttributeType.AGILITY, "icon": StatDisplay.icon_of(AttributeType.AGILITY)},
	]
	for case: Dictionary in cases:
		_card.show_result(_result(case["drill"], _ten(Tier.GOOD), 3.0, {AttributeType.STRENGTH: 30.0, case["stat"]: 15.0}))
		assert_true(_chip("MinorChip").visible, "%s: its other stat's chip" % case["drill"])
		assert_eq(_icon("MinorChip"), case["icon"], "%s: its icon" % case["drill"])
		assert_eq(_amount("MinorChip").text, "+15", case["drill"])
		_card.show_result(_result(case["drill"], _ten(Tier.AUTO), 1.6, {AttributeType.STRENGTH: 24.0}))
		assert_false(_chip("MinorChip").visible, "%s: none for an Auto set" % case["drill"])

#-----------------------------------------------------------------------------
# THE BEADS
#-----------------------------------------------------------------------------

## The beads show each rep's tier in bead order, an Auto rep's Perfect bead dimmed,
## and the next set's beads replace the last's.
func test_the_beads_follow_the_set() -> void:
	var tiers: Array = [Tier.PERFECT, Tier.GOOD, Tier.OK, Tier.MISS, Tier.PERFECT, Tier.PERFECT, Tier.PERFECT, Tier.PERFECT, Tier.PERFECT, Tier.PERFECT]
	_card.show_result(_result("stone_lifting", tiers, 4.0, {AttributeType.STRENGTH: 50.0}))
	var frames: Array[int] = []
	for tier: Tier in tiers:
		frames.append(DrillPlay.BEAD_FRAMES[tier])
	assert_eq(_bead_frames(), frames)
	_card.show_result(_result("stone_lifting", _ten(Tier.AUTO), 1.6, {AttributeType.STRENGTH: 24.0}))
	await wait_process_frames(1)
	assert_eq(_bead_frames().size(), 10, "the last set's beads are gone")
	for bead: Node in _card.get_node("%Beads").get_children():
		assert_eq((bead as LacquerStripRect).get_frame().x, DrillPlay.BEAD_FRAMES[Tier.AUTO])
		assert_eq((bead as CanvasItem).self_modulate, DrillPlay.AUTO_BEAD_TINT, "dimmed")

#-----------------------------------------------------------------------------
# LONG TEXT
#-----------------------------------------------------------------------------

## Chips too wide for one line wrap onto another rather than trim, the beads stand
## under them, and the card grows round both.
func test_crowded_chips_wrap_and_the_card_grows() -> void:
	_card.show_result(_result("horse_stance", _ten(Tier.PERFECT), 4.0, {AttributeType.STRENGTH: 60.0, AttributeType.BODY: 30.0}))
	await wait_process_frames(2)
	assert_eq(_card.size.y, LastSetCard.ONE_LINE_HEIGHT, "precondition: one line")
	watch_signals(_card)
	_card.show_result(_result("horse_stance", _ten(Tier.PERFECT), 12345678.9, {AttributeType.STRENGTH: 1234567890.0, AttributeType.BODY: 1234567890.0}))
	await wait_process_frames(2)
	assert_gt(_card.size.y, LastSetCard.ONE_LINE_HEIGHT, "the card grows")
	assert_signal_emitted(_card, "height_changed")
	var chips: Control = _card.get_node("%Chips") as Control
	var beads: Control = _card.get_node("%Beads") as Control
	assert_true(_card.get_global_rect().encloses(chips.get_global_rect()), "the chips stay on the card")
	assert_true(_card.get_global_rect().encloses(beads.get_global_rect()), "and the beads")
	assert_gte(beads.position.y, chips.position.y + chips.size.y, "the beads stand under the chips")
