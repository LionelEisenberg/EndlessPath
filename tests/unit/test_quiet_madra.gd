extends GutTest

## Unit tests for the quiet flag on ResourceManager's Madra and resource awards.
## The Aura Well trickles Madra every second; it must add the Madra without
## writing "Gained N Madra" to the player log each tick, and an add that the
## cap swallows writes nothing. A fresh save holds 25 Madra with a max of 100.

const AURA_WELL_TRICKLE_PATH: String = "res://resources/zones/spirit_valley_zone/zone_actions/aura_well_madra_trickle_effect.tres"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	watch_signals(LogManager)

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func _last_logged_line() -> String:
	var params: Variant = get_signal_parameters(LogManager, "message_logged")
	if params == null:
		return ""
	return str(params[0])

#-----------------------------------------------------------------------------
# ADD MADRA
#-----------------------------------------------------------------------------

func test_quiet_add_logs_nothing() -> void:
	ResourceManager.add_madra(5.0, true)
	assert_signal_not_emitted(LogManager, "message_logged")

func test_quiet_add_still_adds() -> void:
	ResourceManager.add_madra(5.0, true)
	assert_eq(ResourceManager.get_madra(), 30.0)

func test_loud_add_logs_gained_line() -> void:
	ResourceManager.add_madra(5.0)
	assert_signal_emit_count(LogManager, "message_logged", 1)
	assert_string_contains(_last_logged_line(), "Gained 5 Madra")

func test_capped_add_logs_nothing() -> void:
	ResourceManager.set_madra(100.0)
	ResourceManager.add_madra(5.0)
	assert_signal_not_emitted(LogManager, "message_logged")
	assert_eq(ResourceManager.get_madra(), 100.0)

func test_partly_capped_add_logs_the_amount_added() -> void:
	ResourceManager.set_madra(98.0)
	ResourceManager.add_madra(5.0)
	assert_string_contains(_last_logged_line(), "Gained 2 Madra")

func test_add_onto_a_fractional_balance_logs_the_whole_amount() -> void:
	# (63.1 + 1.0) - 63.1 is 0.99999... in floating point.
	ResourceManager.set_madra(63.1)
	ResourceManager.add_madra(1.0)
	assert_string_contains(_last_logged_line(), "Gained 1 Madra")

func test_sub_one_add_logs_nothing() -> void:
	ResourceManager.add_madra(0.5)
	assert_signal_not_emitted(LogManager, "message_logged")
	assert_eq(ResourceManager.get_madra(), 25.5)

#-----------------------------------------------------------------------------
# AWARD RESOURCE
#-----------------------------------------------------------------------------

func test_quiet_madra_award_logs_nothing() -> void:
	ResourceManager.award_resource(ResourceManager.ResourceType.MADRA, 5.0, true)
	assert_signal_not_emitted(LogManager, "message_logged")
	assert_eq(ResourceManager.get_madra(), 30.0)

func test_quiet_gold_award_logs_nothing() -> void:
	ResourceManager.award_resource(ResourceManager.ResourceType.GOLD, 7.0, true)
	assert_signal_not_emitted(LogManager, "message_logged")
	assert_eq(ResourceManager.get_gold(), 7.0)

func test_loud_gold_award_logs_gained_line() -> void:
	ResourceManager.award_resource(ResourceManager.ResourceType.GOLD, 7.0)
	assert_string_contains(_last_logged_line(), "Gained 7 Gold")

#-----------------------------------------------------------------------------
# AWARD RESOURCE EFFECT
#-----------------------------------------------------------------------------

func test_quiet_effect_adds_without_logging() -> void:
	var effect := AwardResourceEffectData.new()
	effect.resource_type = ResourceManager.ResourceType.MADRA
	effect.amount = 3.0
	effect.quiet = true
	effect.process()
	assert_signal_not_emitted(LogManager, "message_logged")
	assert_eq(ResourceManager.get_madra(), 28.0)

func test_loud_effect_logs() -> void:
	var effect := AwardResourceEffectData.new()
	effect.resource_type = ResourceManager.ResourceType.MADRA
	effect.amount = 3.0
	effect.process()
	assert_string_contains(_last_logged_line(), "Gained 3 Madra")

func test_aura_well_trickle_is_quiet() -> void:
	var trickle: AwardResourceEffectData = load(AURA_WELL_TRICKLE_PATH)
	trickle.process()
	assert_signal_not_emitted(LogManager, "message_logged")
	assert_eq(ResourceManager.get_madra(), 26.5, "the trickle still adds its 1.5 Madra")
