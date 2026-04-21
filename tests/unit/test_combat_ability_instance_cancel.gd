extends GutTest

## Tests for CombatAbilityInstance.cancel_cast() behavior.
## Verifies mid-cast cancellation, signal emission, and post-cancel cooldown.

var _ability_data: AbilityData
var _instance: CombatAbilityInstance

func before_each() -> void:
	_ability_data = AbilityData.new()
	_ability_data.ability_id = "test_cast"
	_ability_data.ability_name = "Test Cast"
	_ability_data.cast_time = 2.0
	_ability_data.base_cooldown = 5.0

	# Owner is passed as null: these tests exercise cancel_cast() in isolation,
	# which never dereferences owner_combatant. If a future change to cancel_cast()
	# starts reading owner_combatant.combatant_data (e.g. for logs), this test
	# will crash and must be updated to pass a real CombatantNode with stubbed data.
	_instance = CombatAbilityInstance.new(_ability_data, null)
	add_child_autofree(_instance)

func test_cancel_cast_while_casting_stops_timer() -> void:
	_instance.is_casting = true
	_instance.cast_timer.start(2.0)
	_instance.cancel_cast()
	assert_false(_instance.is_casting, "is_casting should be false after cancel")
	assert_true(_instance.cast_timer.is_stopped(), "cast_timer should be stopped")

func test_cancel_cast_emits_signal() -> void:
	_instance.is_casting = true
	_instance.cast_timer.start(2.0)
	watch_signals(_instance)
	_instance.cancel_cast()
	assert_signal_emitted(_instance, "cast_cancelled",
		"cast_cancelled signal should fire on successful cancel")

func test_cancel_cast_starts_cooldown() -> void:
	_instance.is_casting = true
	_instance.cast_timer.start(2.0)
	_instance.cancel_cast()
	assert_false(_instance.cooldown_timer.is_stopped(),
		"cooldown_timer should start after cancel to prevent re-cast spam")

func test_cancel_cast_when_not_casting_is_noop() -> void:
	# Not casting, cooldown already stopped
	_instance.is_casting = false
	_instance.cooldown_timer.stop()
	watch_signals(_instance)
	_instance.cancel_cast()
	assert_signal_not_emitted(_instance, "cast_cancelled",
		"cast_cancelled should NOT fire when no cast in progress")
	assert_true(_instance.cooldown_timer.is_stopped(),
		"cooldown should remain untouched when no cast to cancel")

#---- CombatAbilityManager.cancel_current_cast() ----

func test_manager_cancel_current_cast_cancels_casting_instance() -> void:
	var manager := CombatAbilityManager.new()
	add_child_autofree(manager)
	# Directly populate abilities array to bypass setup() data dependency
	manager.abilities = [_instance]

	_instance.is_casting = true
	_instance.cast_timer.start(2.0)
	watch_signals(_instance)

	var cancelled: bool = manager.cancel_current_cast()

	assert_true(cancelled, "cancel_current_cast should return true when a cast was cancelled")
	assert_false(_instance.is_casting, "casting instance should be cancelled")
	assert_signal_emitted(_instance, "cast_cancelled")

func test_manager_cancel_current_cast_noop_when_nothing_casting() -> void:
	var manager := CombatAbilityManager.new()
	add_child_autofree(manager)
	manager.abilities = [_instance]

	_instance.is_casting = false
	var cancelled: bool = manager.cancel_current_cast()
	assert_false(cancelled, "cancel_current_cast should return false when nothing is casting")
