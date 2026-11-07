extends GutTest

## Unit tests for BodyRefiningManager: the drill catalog, unlocking and equipping
## a drill, the seen drills and their first pass, and pay_rep(), which pays a
## rep's Strength XP, its other stat's XP and its Health. Every test runs on a
## fresh save that the managers are re-bound to, with two drills built here in
## place of the catalog; after_each() puts the real save and catalog back.

const AttributeType = CharacterAttributesData.AttributeType
const Tier = DrillRules.Tier
const StatSources := preload("res://tests/helpers/stat_sources.gd")

## The modifier source a test lifts Strength with, removed in after_each().
const TEST_SOURCE: StringName = &"test_body_refining_manager"

var _save_data: SaveGameData
var _starting_drill: DrillData
var _body_drill: DrillData
## The real save and catalog, given back after each test.
var _original_save: SaveGameData = null
var _saved_drills_by_id: Dictionary = {}

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

## A drill that pays `strength_xp` Strength XP and `health` Health a PERFECT
## rep, and `minor_xp` of `minor` when `minor` is not -1.
func _drill(drill_id: String, strength_xp: float, health: float, minor: int = -1, minor_xp: float = 0.0) -> DrillData:
	var drill := DrillData.new()
	drill.id = drill_id
	drill.drill_name = drill_id.capitalize()
	drill.strength_xp_per_rep = strength_xp
	drill.health_per_rep = health
	drill.minor_stat = minor
	drill.minor_xp_per_rep = minor_xp
	drill.reps_per_set = 10
	return drill

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_saved_drills_by_id = BodyRefiningManager._drills_by_id
	_save_data = SaveGameData.new()
	PersistenceManager.save_game_data = _save_data
	PersistenceManager.save_data_reset.emit()
	_starting_drill = _drill("stone_lifting", 6.0, 4.0)
	_body_drill = _drill("body_drill", 8.0, 4.0, AttributeType.BODY, 4.0)
	BodyRefiningManager._drills_by_id = {
		"stone_lifting": _starting_drill,
		"body_drill": _body_drill,
	}

func after_each() -> void:
	CharacterManager.remove_modifier_source(TEST_SOURCE)
	BodyRefiningManager.end_set_session()
	BodyRefiningManager._drills_by_id = _saved_drills_by_id
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

#-----------------------------------------------------------------------------
# DEFAULT STATE
#-----------------------------------------------------------------------------

func test_a_new_save_starts_with_the_starting_drill_unlocked_and_equipped() -> void:
	assert_true(BodyRefiningManager.is_drill_unlocked("stone_lifting"), "the starting drill is unlocked")
	var equipped: DrillData = BodyRefiningManager.get_equipped_drill()
	assert_not_null(equipped, "a drill is equipped")
	if equipped:
		assert_eq(equipped.id, "stone_lifting", "and it is the starting drill")

#-----------------------------------------------------------------------------
# THE CATALOG
#-----------------------------------------------------------------------------

func test_the_catalog_lists_every_drill_and_knows_its_ids() -> void:
	assert_eq(BodyRefiningManager.get_all_drills(), [_starting_drill, _body_drill] as Array[DrillData])
	assert_true(BodyRefiningManager.has_drill("body_drill"))
	assert_false(BodyRefiningManager.has_drill("not_a_drill"), "an unknown id is not in the catalog")
	assert_eq(BodyRefiningManager.get_drill("body_drill"), _body_drill)
	assert_null(BodyRefiningManager.get_drill("not_a_drill"))

func test_the_real_catalog_holds_the_starting_drill() -> void:
	BodyRefiningManager._drills_by_id = _saved_drills_by_id
	var starting_id: String = SaveGameData.new().equipped_drill_id
	assert_true(BodyRefiningManager.has_drill(starting_id), "a new save's drill is in the catalog")

func test_get_unlocked_drills_skips_unknown_ids() -> void:
	_save_data.unlocked_drill_ids.append("not_a_drill")
	assert_eq(BodyRefiningManager.get_unlocked_drills(), [_starting_drill] as Array[DrillData])

#-----------------------------------------------------------------------------
# UNLOCK AND EQUIP
#-----------------------------------------------------------------------------

func test_unlock_drill_adds_it_and_announces_it() -> void:
	watch_signals(BodyRefiningManager)
	BodyRefiningManager.unlock_drill("body_drill")
	assert_true(BodyRefiningManager.is_drill_unlocked("body_drill"))
	assert_eq(BodyRefiningManager.get_unlocked_drills(), [_starting_drill, _body_drill] as Array[DrillData])
	assert_signal_emitted_with_parameters(BodyRefiningManager, "drill_unlocked", [_body_drill])

func test_unlock_drill_is_idempotent() -> void:
	BodyRefiningManager.unlock_drill("body_drill")
	watch_signals(BodyRefiningManager)
	BodyRefiningManager.unlock_drill("body_drill")
	assert_eq(_save_data.unlocked_drill_ids.count("body_drill"), 1, "the save holds it once")
	assert_signal_not_emitted(BodyRefiningManager, "drill_unlocked", "an unlock already made is not announced again")

func test_unlock_drill_refuses_an_unknown_id() -> void:
	BodyRefiningManager.unlock_drill("not_a_drill")
	assert_push_error("unknown drill_id")
	assert_false(_save_data.unlocked_drill_ids.has("not_a_drill"))

func test_equip_drill_saves_it_and_announces_it() -> void:
	BodyRefiningManager.unlock_drill("body_drill")
	watch_signals(BodyRefiningManager)
	BodyRefiningManager.equip_drill("body_drill")
	assert_eq(BodyRefiningManager.get_equipped_drill(), _body_drill)
	assert_eq(_save_data.equipped_drill_id, "body_drill", "the save holds the equipped id")
	assert_signal_emitted_with_parameters(BodyRefiningManager, "equipped_drill_changed", [_body_drill])

func test_equip_drill_refuses_an_unknown_and_a_locked_drill() -> void:
	BodyRefiningManager.equip_drill("not_a_drill")
	assert_push_error("unknown drill_id")
	BodyRefiningManager.equip_drill("body_drill")
	assert_push_error("cannot equip locked drill")
	assert_eq(_save_data.equipped_drill_id, "stone_lifting", "the equipped drill stays")

#-----------------------------------------------------------------------------
# AUTO
#-----------------------------------------------------------------------------

func test_auto_is_locked_on_a_new_save() -> void:
	assert_false(BodyRefiningManager.is_auto_unlocked("stone_lifting"))
	assert_eq(_save_data.auto_drill_ids, [] as Array[String])

func test_auto_unlock_is_saved_per_drill() -> void:
	BodyRefiningManager.unlock_auto("body_drill")
	assert_true(BodyRefiningManager.is_auto_unlocked("body_drill"))
	assert_false(BodyRefiningManager.is_auto_unlocked("stone_lifting"), "a perfect set unlocks only its own drill")
	assert_eq(_save_data.auto_drill_ids, ["body_drill"] as Array[String])

func test_unlock_auto_announces_the_drill_once() -> void:
	watch_signals(BodyRefiningManager)
	BodyRefiningManager.unlock_auto("body_drill")
	BodyRefiningManager.unlock_auto("body_drill")
	assert_signal_emit_count(BodyRefiningManager, "auto_unlocked", 1)
	assert_signal_emitted_with_parameters(BodyRefiningManager, "auto_unlocked", [_body_drill])
	assert_eq(_save_data.auto_drill_ids.count("body_drill"), 1, "unlocking twice changes nothing")

func test_unlock_auto_refuses_an_unknown_id() -> void:
	watch_signals(BodyRefiningManager)
	BodyRefiningManager.unlock_auto("not_a_drill")
	assert_push_error("unknown drill_id")
	assert_false(BodyRefiningManager.is_auto_unlocked("not_a_drill"))
	assert_signal_not_emitted(BodyRefiningManager, "auto_unlocked")
	assert_true(_save_data.auto_drill_ids.is_empty())

#-----------------------------------------------------------------------------
# SEEN DRILLS
#-----------------------------------------------------------------------------

func test_mark_seen_records_a_drill_once() -> void:
	BodyRefiningManager.mark_drill_seen("body_drill")
	BodyRefiningManager.mark_drill_seen("body_drill")
	assert_true(BodyRefiningManager.is_drill_seen("body_drill"))
	assert_eq(_save_data.seen_drill_ids.count("body_drill"), 1)

func test_an_empty_id_is_never_recorded_or_seen() -> void:
	BodyRefiningManager.mark_drill_seen("")
	assert_false(_save_data.seen_drill_ids.has(""), "an empty id is not a drill")
	_save_data.equipped_drill_id = ""
	assert_false(BodyRefiningManager.is_drill_seen(""), "even with nothing equipped")

func test_an_unlocked_drill_is_new_until_seen_or_equipped() -> void:
	BodyRefiningManager.unlock_drill("body_drill")
	assert_false(BodyRefiningManager.is_drill_seen("body_drill"), "a new unlock shows NEW")
	BodyRefiningManager.equip_drill("body_drill")
	assert_true(BodyRefiningManager.is_drill_seen("body_drill"), "the drill in use counts as seen")

func test_the_first_pass_marks_the_drills_unlocked_then_seen_once() -> void:
	var save := SaveGameData.new()
	save.unlocked_drill_ids.append("body_drill")
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()
	assert_true(save.seen_drills_initialized, "binding a save runs the first pass")
	assert_true(save.seen_drill_ids.has("body_drill"), "a drill unlocked before it is seen")
	save.unlocked_drill_ids.append("later_drill")
	BodyRefiningManager._initialize_seen_drills()
	assert_false(save.seen_drill_ids.has("later_drill"), "the pass runs once, so a later unlock stays NEW")

#-----------------------------------------------------------------------------
# PAYING A REP
#-----------------------------------------------------------------------------

func test_a_rep_pays_strength_the_minor_and_health() -> void:
	ResourceManager.set_health(50.0)
	var restored: float = BodyRefiningManager.pay_rep(_body_drill, Tier.PERFECT)
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 8.0, "Strength XP")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.BODY), 4.0, "the drill's other stat's XP")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.AGILITY), 0.0, "and no other stat's")
	assert_eq(ResourceManager.get_health(), 54.0, "Health at Strength Lv 1 is the drill's own amount")
	assert_eq(restored, 4.0, "it returns what it restored")

## Each stat gets one add_stat_xp() call a rep, so XP lands once and levels are
## announced once.
func test_a_rep_pays_each_stat_once() -> void:
	var paid: Array = []
	var record: Callable = func(stat: AttributeType, _xp: float, _to_next: float) -> void: paid.append(stat)
	CharacterManager.stat_xp_changed.connect(record)
	BodyRefiningManager.pay_rep(_body_drill, Tier.PERFECT)
	CharacterManager.stat_xp_changed.disconnect(record)
	assert_eq(paid, [AttributeType.STRENGTH, AttributeType.BODY])

func test_a_drill_with_no_minor_pays_strength_alone() -> void:
	var paid: Array = []
	var record: Callable = func(stat: AttributeType, _xp: float, _to_next: float) -> void: paid.append(stat)
	CharacterManager.stat_xp_changed.connect(record)
	BodyRefiningManager.pay_rep(_starting_drill, Tier.PERFECT)
	CharacterManager.stat_xp_changed.disconnect(record)
	assert_eq(paid, [AttributeType.STRENGTH])

## The tier scales the XP and the Health alike, and a MISS pays nothing.
func test_the_tier_scales_what_a_rep_pays() -> void:
	var cases: Array[Dictionary] = [
		{"tier": Tier.PERFECT, "strength_xp": 8.0, "body_xp": 4.0, "health": 4.0},
		{"tier": Tier.GOOD, "strength_xp": 6.0, "body_xp": 3.0, "health": 3.0},
		{"tier": Tier.OK, "strength_xp": 4.0, "body_xp": 2.0, "health": 2.0},
		{"tier": Tier.MISS, "strength_xp": 0.0, "body_xp": 0.0, "health": 0.0},
	]
	for case: Dictionary in cases:
		CharacterManager.set_stat_level(AttributeType.STRENGTH, 1)
		CharacterManager.set_stat_level(AttributeType.BODY, 1)
		ResourceManager.set_health(50.0)
		var tier_name: String = Tier.keys()[case["tier"]]
		BodyRefiningManager.pay_rep(_body_drill, case["tier"])
		assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), case["strength_xp"], "%s: Strength XP" % tier_name)
		assert_eq(CharacterManager.get_stat_xp(AttributeType.BODY), case["body_xp"], "%s: Body XP" % tier_name)
		assert_eq(ResourceManager.get_health(), 50.0 + case["health"], "%s: Health" % tier_name)

func test_a_capped_strength_still_refills_health() -> void:
	CharacterManager.set_stat_level(AttributeType.STRENGTH, CharacterManager.get_stat_level_cap())
	ResourceManager.set_health(10.0)
	BodyRefiningManager.pay_rep(_body_drill, Tier.PERFECT)
	assert_gt(ResourceManager.get_health(), 10.0, "the rep refills Health")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 0.0, "the Strength XP is lost at the cap")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.BODY), 4.0, "the other stat still trains")

func test_a_rep_pays_xp_at_full_health() -> void:
	ResourceManager.set_health(ResourceManager.get_max_health())
	var restored: float = BodyRefiningManager.pay_rep(_body_drill, Tier.PERFECT)
	assert_eq(restored, 0.0, "a full pool takes no Health")
	assert_eq(ResourceManager.get_health(), ResourceManager.get_max_health(), "and stays at the max")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 8.0, "the XP is paid all the same")

## Health a rep reads the Strength total: Lv 1 is 10, and +5 from a modifier
## makes 15, half as much again.
func test_health_per_rep_reads_strength_with_gear() -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, StatSources.flat(StatModifierData.Stat.STRENGTH, 5.0))
	ResourceManager.set_health(50.0)
	BodyRefiningManager.pay_rep(_body_drill, Tier.PERFECT)
	assert_eq(ResourceManager.get_health(), 56.0, "4 x 1.5")

## The Health comes before the XP, at the Strength the rep was played with: a rep
## whose XP raises Strength a level restores the old level's Health.
func test_health_is_paid_at_the_strength_before_the_reps_xp() -> void:
	CharacterManager.set_stat_level(AttributeType.STRENGTH, 1, CharacterManager.get_stat_xp_to_next(AttributeType.STRENGTH) - 1.0)
	ResourceManager.set_health(50.0)
	BodyRefiningManager.pay_rep(_body_drill, Tier.PERFECT)
	assert_eq(CharacterManager.get_stat_level(AttributeType.STRENGTH), 2, "precondition: the rep raised Strength")
	assert_eq(ResourceManager.get_health(), 54.0, "the Health is Lv 1's")

func test_a_rep_is_recorded_in_the_set_result() -> void:
	ResourceManager.set_health(50.0)
	var result := DrillSetResult.new(_body_drill)
	BodyRefiningManager.pay_rep(_body_drill, Tier.PERFECT, result)
	BodyRefiningManager.pay_rep(_body_drill, Tier.GOOD, result)
	assert_eq(result.get_rep_count(), 2)
	assert_eq(result.count_of(Tier.PERFECT), 1)
	assert_eq(result.count_of(Tier.GOOD), 1)
	assert_eq(result.get_health_restored(), 7.0, "4 + 3")

func test_a_rep_records_the_xp_each_stat_took() -> void:
	var result := DrillSetResult.new(_body_drill)
	BodyRefiningManager.pay_rep(_body_drill, Tier.PERFECT, result)
	BodyRefiningManager.pay_rep(_body_drill, Tier.PERFECT, result)
	assert_eq(result.get_stat_xp(AttributeType.STRENGTH), 16.0)
	assert_eq(result.get_stat_xp(AttributeType.BODY), 8.0)
	assert_false(result.is_stat_capped(AttributeType.STRENGTH))

## A rep that reaches the cap pays Strength only what reaches it: the result
## holds what Strength took, and that the cap took the rest.
func test_a_rep_that_reaches_the_cap_records_what_strength_took() -> void:
	var cap: int = CharacterManager.get_stat_level_cap()
	CharacterManager.set_stat_level(AttributeType.STRENGTH, cap - 1)
	CharacterManager.set_stat_level(AttributeType.STRENGTH, cap - 1, CharacterManager.get_stat_xp_to_next(AttributeType.STRENGTH) - 1.0)
	var result := DrillSetResult.new(_starting_drill)
	BodyRefiningManager.pay_rep(_starting_drill, Tier.PERFECT, result)
	assert_true(CharacterManager.is_stat_capped(AttributeType.STRENGTH), "precondition: the rep reached the cap")
	assert_almost_eq(result.get_stat_xp(AttributeType.STRENGTH), 1.0, 0.0001, "Strength took the 1 XP that reached the cap")
	assert_true(result.is_stat_capped(AttributeType.STRENGTH), "and the cap took the rest")

func test_a_capped_strength_takes_nothing_and_is_recorded_capped() -> void:
	CharacterManager.set_stat_level(AttributeType.STRENGTH, CharacterManager.get_stat_level_cap())
	var result := DrillSetResult.new(_starting_drill)
	BodyRefiningManager.pay_rep(_starting_drill, Tier.PERFECT, result)
	assert_eq(result.get_stat_xp(AttributeType.STRENGTH), 0.0)
	assert_true(result.is_stat_capped(AttributeType.STRENGTH))

## What a PERFECT rep restores at the player's Strength total: the board's pay
## line and the Now strip show it.
func test_perfect_rep_health_follows_strength() -> void:
	assert_eq(BodyRefiningManager.perfect_rep_health(_starting_drill), 4.0, "Strength Lv 1 (10)")
	CharacterManager.set_stat_level(AttributeType.STRENGTH, 10)
	assert_almost_eq(BodyRefiningManager.perfect_rep_health(_starting_drill), 7.6, 0.0001, "Strength Lv 10 (19)")

#-----------------------------------------------------------------------------
# THE SET SESSION
#-----------------------------------------------------------------------------

func test_the_set_session_snapshot() -> void:
	assert_false(BodyRefiningManager.is_set_running(), "no set runs at first")
	BodyRefiningManager.start_set_session(10)
	assert_true(BodyRefiningManager.is_set_running())
	assert_eq(BodyRefiningManager.get_set_rep(), 1, "a set starts on its first rep")
	assert_eq(BodyRefiningManager.get_set_reps(), 10)
	assert_eq(BodyRefiningManager.get_rep_progress(), 0.0)
	BodyRefiningManager.update_set_session(4, 0.5)
	assert_eq(BodyRefiningManager.get_set_rep(), 4)
	assert_eq(BodyRefiningManager.get_rep_progress(), 0.5)
	assert_almost_eq(BodyRefiningManager.get_set_progress(), 0.35, 0.0001, "three reps and a half of ten")
	BodyRefiningManager.end_set_session()
	assert_false(BodyRefiningManager.is_set_running())
	assert_eq(BodyRefiningManager.get_set_rep(), 0)
	assert_eq(BodyRefiningManager.get_rep_progress(), 0.0)
	assert_eq(BodyRefiningManager.get_set_progress(), 0.0)

func test_an_update_without_a_session_does_nothing() -> void:
	BodyRefiningManager.update_set_session(3, 0.5)
	assert_false(BodyRefiningManager.is_set_running())
	assert_eq(BodyRefiningManager.get_set_rep(), 0)

## A set played to its last rep counts once in the play stats; a set stopped
## short counts nothing. Either ends the session.
func test_finish_set_counts_a_complete_set_only() -> void:
	var full := DrillSetResult.new(_starting_drill)
	for i: int in 10:
		full.add_rep(Tier.PERFECT, 4.0)
	BodyRefiningManager.start_set_session(10)
	BodyRefiningManager.finish_set(full)
	assert_eq(_save_data.stats.sets_finished, 1, "a set played to its last rep counts")
	assert_false(BodyRefiningManager.is_set_running(), "and the session ends")
	var short := DrillSetResult.new(_starting_drill)
	for i: int in 4:
		short.add_rep(Tier.PERFECT, 4.0)
	BodyRefiningManager.start_set_session(10)
	BodyRefiningManager.finish_set(short)
	assert_eq(_save_data.stats.sets_finished, 1, "a short set counts nothing")
	assert_false(BodyRefiningManager.is_set_running())

func test_a_rep_of_no_drill_pays_nothing() -> void:
	ResourceManager.set_health(50.0)
	assert_eq(BodyRefiningManager.pay_rep(null, Tier.PERFECT), 0.0)
	assert_push_error("cannot pay a rep of no drill")
	assert_eq(ResourceManager.get_health(), 50.0)
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 0.0)
