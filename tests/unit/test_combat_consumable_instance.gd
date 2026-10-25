extends GutTest

## Unit tests for CombatConsumableInstance: one hotbar consumable in a fight,
## with its own cooldown. It is ready as the fight opens, fires through
## InventoryManager.use_consumable() (the effects, then one off the stack) and
## refuses while it recharges or when none are left. Runs on a fresh save,
## restored after each test.

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## An effect that counts how often it fires, so no test touches the vitals.
const CountingEffect := preload("res://tests/unit/counting_effect.gd")

var _original_save: SaveGameData = null
var _effect: CountingEffect = null

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_effect = CountingEffect.new()

func after_each() -> void:
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

## A consumable that fires _effect, with the given cooldown.
func _make_consumable(cooldown_seconds: float) -> ConsumableDefinitionData:
	var def := ConsumableDefinitionData.new()
	def.item_id = "test_scale"
	def.item_name = "Test Scale"
	def.effects = [_effect]
	def.cooldown_seconds = cooldown_seconds
	return def

## An instance for hotbar slot 0, in the tree so its timer exists.
func _make_instance(def: ConsumableDefinitionData, held: int) -> CombatConsumableInstance:
	if held > 0:
		InventoryManager.award_items(def, held)
	var instance := CombatConsumableInstance.new(def, 0)
	add_child_autofree(instance)
	return instance

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_ready_as_the_fight_opens() -> void:
	var instance := _make_instance(_make_consumable(10.0), 3)

	assert_true(instance.is_ready(), "no opening cooldown")
	assert_true(instance.cooldown_timer.is_stopped())
	assert_eq(instance.slot_index, 0)

func test_use_fires_the_effects_and_takes_one() -> void:
	var instance := _make_instance(_make_consumable(10.0), 3)

	assert_true(instance.use(), "used")
	assert_eq(_effect.call_count, 1, "the effects fired once")
	assert_eq(instance.get_count(), 2, "one came off the stack")
	assert_eq(instance.use_count, 1)

func test_use_starts_the_cooldown() -> void:
	var instance := _make_instance(_make_consumable(10.0), 3)
	watch_signals(instance)

	instance.use()

	assert_false(instance.is_ready(), "recharging")
	assert_eq(instance.cooldown_timer.wait_time, 10.0, "for the consumable's own cooldown")
	assert_signal_emitted_with_parameters(instance, "cooldown_started", [10.0])

func test_use_is_refused_while_recharging() -> void:
	var instance := _make_instance(_make_consumable(10.0), 3)
	instance.use()

	assert_false(instance.use(), "refused while recharging")
	assert_eq(_effect.call_count, 1, "the effects fired only once")
	assert_eq(instance.get_count(), 2, "only one came off the stack")

func test_use_is_refused_with_none_left() -> void:
	var instance := _make_instance(_make_consumable(10.0), 0)

	assert_false(instance.use(), "refused with none held")
	assert_eq(_effect.call_count, 0, "the effects never fired")
	assert_true(instance.cooldown_timer.is_stopped(), "no cooldown started")

func test_no_cooldown_means_ready_at_once() -> void:
	var instance := _make_instance(_make_consumable(0.0), 2)

	assert_true(instance.use())
	assert_true(instance.is_ready(), "a consumable with no cooldown stays ready")
	assert_true(instance.use(), "and fires again")
	assert_eq(instance.get_count(), 0, "two uses took two")

func test_cooldown_ready_fires_when_it_ends() -> void:
	var instance := _make_instance(_make_consumable(0.05), 2)
	instance.use()

	var fired: bool = await wait_for_signal(instance.cooldown_ready, 1.0)

	assert_true(fired, "cooldown_ready fired")
	assert_true(instance.is_ready(), "ready again")
