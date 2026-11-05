extends GutTest

## Unit tests for the ResourceManager autoload: the one Madra pool and its max
## (the max Madra stat), the over-max rule, gold, award_resource dispatch, the
## adventure threshold, the madra_changed / gold_changed signals and the
## player-facing log lines. Every test calls the real singleton, bound to a
## fresh save the way a load binds one.

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

const AttributeType = CharacterAttributesData.AttributeType
const TEST_SOURCE: StringName = &"test_resource_manager"
## A new character's max: Mind Lv 1 (10) x 10.
const NEW_MAX_MADRA: float = 100.0

var _save: SaveGameData
var _original_save: SaveGameData

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_use_save(SaveGameData.new_current())
	_save.madra = 0.0
	_save.gold = 0.0

func after_each() -> void:
	CharacterManager.remove_modifier_source(TEST_SOURCE)
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Binds a save as a load does: every manager hears save_data_reset.
func _use_save(save: SaveGameData) -> void:
	_save = save
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()

## Puts a flat bonus on the max Madra stat.
func _raise_max_by(amount: float) -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, _max_madra_source(amount))

## A modifier source that adds `amount` to the max Madra stat.
func _max_madra_source(amount: float) -> Callable:
	return func() -> Array[StatModifierData]:
		var modifiers: Array[StatModifierData] = [StatModifierData.new(StatModifierData.Stat.MAX_MADRA, StatModifierData.Kind.FLAT, amount)]
		return modifiers

## The first message_logged text since watch_signals(LogManager).
func _first_log_message() -> String:
	var params: Variant = get_signal_parameters(LogManager, "message_logged", 0)
	return "" if params == null else str(params[0])

#-----------------------------------------------------------------------------
# MAX MADRA
#-----------------------------------------------------------------------------

## The max is the max Madra stat: Mind x 10, then its modifiers.
func test_max_madra_is_the_max_madra_stat() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a new character", "mind_level": 1, "bonus": 0.0, "max": 100.0},
		{"name": "Mind Lv 3", "mind_level": 3, "bonus": 0.0, "max": 120.0},
		{"name": "a +50 bonus on max Madra", "mind_level": 1, "bonus": 50.0, "max": 150.0},
	]
	for case: Dictionary in cases:
		CharacterManager.set_stat_level(AttributeType.MIND, case.mind_level)
		_raise_max_by(case.bonus)
		assert_eq(ResourceManager.get_max_madra(), case.max, case.name)

## Core Density sets no Madra cap any more.
func test_core_density_leaves_the_max_alone() -> void:
	_save.core_density_level = 50.0
	assert_eq(ResourceManager.get_max_madra(), NEW_MAX_MADRA)

#-----------------------------------------------------------------------------
# ADD MADRA
#-----------------------------------------------------------------------------

## add_madra() keeps the pool between 0 and the max: an add with room lands in
## full, one past the max or at it stops at the max, and a negative amount
## past the pool stops at 0.
func test_add_madra_keeps_the_pool_between_zero_and_the_max() -> void:
	var cases: Array[Dictionary] = [
		{"name": "an add with room", "madra": 10.0, "amount": 5.0, "expected": 15.0},
		{"name": "the max absorbs the overflow", "madra": 95.0, "amount": 20.0, "expected": NEW_MAX_MADRA},
		{"name": "an add at the max stays at the max", "madra": NEW_MAX_MADRA, "amount": 50.0, "expected": NEW_MAX_MADRA},
		{"name": "a negative amount past the pool stops at 0", "madra": 10.0, "amount": -50.0, "expected": 0.0},
	]
	for case: Dictionary in cases:
		_save.madra = case.madra
		ResourceManager.add_madra(case.amount)
		assert_eq(_save.madra, case.expected, case.name)

func test_add_madra_emits_madra_changed_with_new_total() -> void:
	_save.madra = 10.0
	watch_signals(ResourceManager)
	ResourceManager.add_madra(5.0)
	assert_signal_emit_count(ResourceManager, "madra_changed", 1)
	assert_signal_emitted_with_parameters(ResourceManager, "madra_changed", [15.0])

func test_add_madra_emits_the_total_at_the_max() -> void:
	_save.madra = 95.0
	watch_signals(ResourceManager)
	ResourceManager.add_madra(20.0)
	assert_signal_emitted_with_parameters(ResourceManager, "madra_changed", [NEW_MAX_MADRA])

func test_add_madra_logs_whole_gains() -> void:
	watch_signals(LogManager)
	ResourceManager.add_madra(5.0)
	assert_signal_emit_count(LogManager, "message_logged", 1)
	assert_string_contains(_first_log_message(), "Gained 5 Madra")

func test_add_madra_does_not_log_fractional_gains() -> void:
	watch_signals(LogManager)
	ResourceManager.add_madra(0.5)
	assert_signal_not_emitted(LogManager, "message_logged", "per-tick cycling gains below 1 Madra stay out of the log")
	assert_eq(_save.madra, 0.5, "the fractional gain is still applied")

#-----------------------------------------------------------------------------
# SPEND MADRA
#-----------------------------------------------------------------------------

## A spend the pool covers deducts and returns true, down to a spend of the
## exact amount held.
func test_spend_madra_deducts_and_returns_true() -> void:
	var cases: Array[Dictionary] = [
		{"name": "30 of 50", "madra": 50.0, "amount": 30.0, "left": 20.0},
		{"name": "the exact amount held", "madra": 25.0, "amount": 25.0, "left": 0.0},
	]
	for case: Dictionary in cases:
		_save.madra = case.madra
		assert_true(ResourceManager.spend_madra(case.amount), "%s: succeeds" % case.name)
		assert_eq(_save.madra, case.left, "%s: Madra left" % case.name)

func test_spend_madra_insufficient_returns_false_and_keeps_madra() -> void:
	_save.madra = 10.0
	assert_false(ResourceManager.spend_madra(50.0))
	assert_eq(_save.madra, 10.0, "a failed spend is all or nothing")

func test_spend_madra_emits_madra_changed() -> void:
	_save.madra = 50.0
	watch_signals(ResourceManager)
	ResourceManager.spend_madra(30.0)
	assert_signal_emitted_with_parameters(ResourceManager, "madra_changed", [20.0])

func test_failed_spend_madra_does_not_emit() -> void:
	_save.madra = 10.0
	watch_signals(ResourceManager)
	ResourceManager.spend_madra(50.0)
	assert_signal_not_emitted(ResourceManager, "madra_changed")

#-----------------------------------------------------------------------------
# SET MADRA
#-----------------------------------------------------------------------------

## set_madra() sets the pool, held to [0, max].
func test_set_madra_sets_value() -> void:
	var cases: Array[Dictionary] = [
		{"name": "75", "value": 75.0, "expected": 75.0},
		{"name": "a negative value clamps to 0", "value": -10.0, "expected": 0.0},
		{"name": "a value past the max stops at the max", "value": 150.0, "expected": NEW_MAX_MADRA},
	]
	for case: Dictionary in cases:
		_save.madra = 40.0
		ResourceManager.set_madra(case.value)
		assert_eq(_save.madra, case.expected, "%s: the save" % case.name)
		assert_eq(ResourceManager.get_madra(), case.expected, "%s: get_madra()" % case.name)

func test_set_madra_emits_madra_changed() -> void:
	watch_signals(ResourceManager)
	ResourceManager.set_madra(75.0)
	assert_signal_emitted_with_parameters(ResourceManager, "madra_changed", [75.0])

#-----------------------------------------------------------------------------
# ONE OVER-MAX RULE
#-----------------------------------------------------------------------------

## Mind gear off, say.
func test_a_falling_max_brings_the_pool_down() -> void:
	_raise_max_by(50.0)
	ResourceManager.set_madra(150.0)
	watch_signals(ResourceManager)
	CharacterManager.remove_modifier_source(TEST_SOURCE)
	assert_eq(ResourceManager.get_madra(), NEW_MAX_MADRA)
	assert_signal_emit_count(ResourceManager, "madra_changed", 1, "announced once")
	assert_signal_emitted_with_parameters(ResourceManager, "madra_changed", [NEW_MAX_MADRA])

func test_a_falling_max_above_the_pool_leaves_it_alone() -> void:
	_raise_max_by(50.0)
	ResourceManager.set_madra(80.0)
	watch_signals(ResourceManager)
	CharacterManager.remove_modifier_source(TEST_SOURCE)
	assert_eq(ResourceManager.get_madra(), 80.0)
	assert_signal_not_emitted(ResourceManager, "madra_changed")

## A save from before this rule can hold 600, from the old Core Density cap.
func test_a_save_loads_with_its_pool_at_most_the_max() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a pool from the old Core Density cap", "madra": 600.0, "expected": NEW_MAX_MADRA},
		{"name": "a pool under the max", "madra": 45.0, "expected": 45.0},
	]
	for case: Dictionary in cases:
		var save := SaveGameData.new_current()
		save.madra = case.madra
		_use_save(save)
		assert_eq(ResourceManager.get_madra(), case.expected, "%s: the pool" % case.name)
		assert_eq(save.madra, case.expected, "%s: the save, so the next write keeps it" % case.name)

## The screens and the unlock sweep re-read the pool on the bind's signal.
func test_every_bind_announces_the_pool() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a pool under the max", "madra": 45.0, "announced": 45.0},
		{"name": "a pool cut to the max", "madra": 600.0, "announced": NEW_MAX_MADRA},
	]
	for case: Dictionary in cases:
		var save := SaveGameData.new_current()
		save.madra = case.madra
		watch_signals(ResourceManager)
		_use_save(save)
		assert_signal_emit_count(ResourceManager, "madra_changed", 1, "%s: once" % case.name)
		assert_eq(get_signal_parameters(ResourceManager, "madra_changed"), [case.announced], "%s: the pool announced" % case.name)
		clear_signal_watcher()

## On a save reset CharacterManager announces the new save's stats while this
## manager still holds the old save: the old save is not cut to the new max.
func test_a_save_reset_leaves_the_old_saves_pool_alone() -> void:
	var old := SaveGameData.new_current()
	old.stat_training.set_level(AttributeType.MIND, 6)
	old.madra = 150.0
	_use_save(old)
	assert_eq(ResourceManager.get_madra(), 150.0, "precondition: Mind Lv 6 holds 150")
	_use_save(SaveGameData.new_current())
	assert_eq(old.madra, 150.0, "the save left behind is not cut to the new save's max of 100")

#-----------------------------------------------------------------------------
# GOLD
#-----------------------------------------------------------------------------

## add_gold() adds the amount, with no cap however much it is.
func test_add_gold_increases_gold() -> void:
	var cases: Array[Dictionary] = [
		{"name": "5 onto 10", "gold": 10.0, "amount": 5.0, "expected": 15.0},
		{"name": "no cap on a million", "gold": 0.0, "amount": 1000000.0, "expected": 1000000.0},
	]
	for case: Dictionary in cases:
		_save.gold = case.gold
		ResourceManager.add_gold(case.amount)
		assert_eq(_save.gold, case.expected, case.name)

func test_add_gold_emits_gold_changed() -> void:
	_save.gold = 10.0
	watch_signals(ResourceManager)
	ResourceManager.add_gold(5.0)
	assert_signal_emit_count(ResourceManager, "gold_changed", 1)
	assert_signal_emitted_with_parameters(ResourceManager, "gold_changed", [15.0])

func test_add_gold_logs_gain() -> void:
	watch_signals(LogManager)
	ResourceManager.add_gold(15.0)
	assert_signal_emit_count(LogManager, "message_logged", 1)
	assert_string_contains(_first_log_message(), "Gained 15 Gold")

## A spend the purse covers deducts and returns true, down to a spend of the
## exact amount held.
func test_spend_gold_deducts_and_returns_true() -> void:
	var cases: Array[Dictionary] = [
		{"name": "30 of 100", "gold": 100.0, "amount": 30.0, "left": 70.0},
		{"name": "the exact amount held", "gold": 30.0, "amount": 30.0, "left": 0.0},
	]
	for case: Dictionary in cases:
		_save.gold = case.gold
		assert_true(ResourceManager.spend_gold(case.amount), "%s: succeeds" % case.name)
		assert_eq(_save.gold, case.left, "%s: gold left" % case.name)

func test_spend_gold_insufficient_returns_false_and_keeps_gold() -> void:
	_save.gold = 10.0
	assert_false(ResourceManager.spend_gold(50.0))
	assert_eq(_save.gold, 10.0)

func test_spend_gold_emits_gold_changed_and_logs() -> void:
	_save.gold = 100.0
	watch_signals(ResourceManager)
	watch_signals(LogManager)
	ResourceManager.spend_gold(30.0)
	assert_signal_emitted_with_parameters(ResourceManager, "gold_changed", [70.0])
	assert_signal_emit_count(LogManager, "message_logged", 1)
	assert_string_contains(_first_log_message(), "Spent 30 Gold")

func test_failed_spend_gold_does_not_emit_or_log() -> void:
	_save.gold = 10.0
	watch_signals(ResourceManager)
	watch_signals(LogManager)
	ResourceManager.spend_gold(50.0)
	assert_signal_not_emitted(ResourceManager, "gold_changed")
	assert_signal_not_emitted(LogManager, "message_logged")

## set_gold() sets the purse, and a negative value sets it to 0.
func test_set_gold_sets_value() -> void:
	var cases: Array[Dictionary] = [
		{"name": "200", "value": 200.0, "expected": 200.0},
		{"name": "a negative value clamps to 0", "value": -5.0, "expected": 0.0},
	]
	for case: Dictionary in cases:
		_save.gold = 40.0
		ResourceManager.set_gold(case.value)
		assert_eq(_save.gold, case.expected, "%s: the save" % case.name)
		assert_eq(ResourceManager.get_gold(), case.expected, "%s: get_gold()" % case.name)

func test_set_gold_emits_gold_changed() -> void:
	watch_signals(ResourceManager)
	ResourceManager.set_gold(200.0)
	assert_signal_emitted_with_parameters(ResourceManager, "gold_changed", [200.0])

func test_can_afford_gold_at_exact_amount() -> void:
	_save.gold = 50.0
	assert_true(ResourceManager.can_afford_gold(50.0))

func test_cannot_afford_gold_when_short() -> void:
	_save.gold = 49.0
	assert_false(ResourceManager.can_afford_gold(50.0))

#-----------------------------------------------------------------------------
# AWARD RESOURCE
#-----------------------------------------------------------------------------

## award_resource() sends each type to its own resource and leaves the other
## alone: awarded Madra goes through add_madra() and its max.
func test_award_resource_adds_to_its_type() -> void:
	var cases: Array[Dictionary] = [
		{"name": "MADRA", "type": ResourceManager.ResourceType.MADRA, "madra": NEW_MAX_MADRA, "gold": 0.0},
		{"name": "GOLD", "type": ResourceManager.ResourceType.GOLD, "madra": 95.0, "gold": 20.0},
	]
	for case: Dictionary in cases:
		_save.madra = 95.0
		_save.gold = 0.0
		ResourceManager.award_resource(case.type, 20.0)
		assert_eq(_save.madra, case.madra, "%s: Madra" % case.name)
		assert_eq(_save.gold, case.gold, "%s: gold" % case.name)

#-----------------------------------------------------------------------------
# ADVENTURE THRESHOLD
#-----------------------------------------------------------------------------

## Half the max, so whatever moves the max moves the threshold.
func test_adventure_threshold_is_half_the_max() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a new character", "bonus": 0.0, "threshold": 50.0},
		{"name": "a +50 bonus on max Madra", "bonus": 50.0, "threshold": 75.0},
	]
	for case: Dictionary in cases:
		_raise_max_by(case.bonus)
		assert_eq(ResourceManager.get_adventure_madra_threshold(), case.threshold, case.name)

func test_can_start_adventure_at_threshold() -> void:
	_save.madra = ResourceManager.get_adventure_madra_threshold()
	assert_true(ResourceManager.can_start_adventure())

func test_cannot_start_adventure_below_threshold() -> void:
	_save.madra = ResourceManager.get_adventure_madra_threshold() - 0.1
	assert_false(ResourceManager.can_start_adventure())
