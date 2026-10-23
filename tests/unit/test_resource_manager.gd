extends GutTest

## Unit tests for the ResourceManager autoload: Madra (stage cap clamping),
## gold, award_resource dispatch, the adventure capacity/budget/threshold
## helpers, the madra_changed / gold_changed signals, and the player-facing
## log lines. Every test calls the real singleton, bound to a fresh save and a
## stub Foundation stage so the caps never depend on the developer's save.

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

## Stub stage: the pool cap is 100 at Core Density level 0, +10 per level.
const STAGE_MAX_MADRA_BASE: float = 100.0
const STAGE_MAX_MADRA_PER_LEVEL: float = 10.0

var _save: SaveGameData
var _stage: AdvancementStageResource

var _original_resource_save: SaveGameData
var _original_cultivation_save: SaveGameData
var _original_stage_resources: Array[AdvancementStageResource]
var _original_character_save: SaveGameData
var _original_inventory_save: SaveGameData
var _original_unlock_save: SaveGameData
var _original_event_save: SaveGameData
var _original_quest_save: SaveGameData

func before_each() -> void:
	_save = SaveGameData.new()
	_save.madra = 0.0
	_save.gold = 0.0
	_save.core_density_level = 0.0
	_save.current_advancement_stage = CultivationManager.AdvancementStage.FOUNDATION
	_save.character_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)

	_stage = AdvancementStageResource.new()
	_stage.stage_name = "Test Foundation"
	_stage.stage_id = CultivationManager.AdvancementStage.FOUNDATION
	_stage.max_madra_base = STAGE_MAX_MADRA_BASE
	_stage.max_madra_per_core_density_level = STAGE_MAX_MADRA_PER_LEVEL

	# ResourceManager reads the pool cap from CultivationManager and the
	# adventure capacity from CharacterManager, whose equipment bonuses come
	# from InventoryManager. Every madra_changed / gold_changed also makes
	# UnlockManager evaluate all conditions (reading EventManager) and
	# QuestManager react to new unlocks, so those use the test save too.
	_original_resource_save = ResourceManager.live_save_data
	_original_cultivation_save = CultivationManager.live_save_data
	_original_stage_resources = CultivationManager.advancement_stage_resources
	_original_character_save = CharacterManager.live_save_data
	_original_inventory_save = InventoryManager.live_save_data
	_original_unlock_save = UnlockManager.live_save_data
	_original_event_save = EventManager.live_save_data
	_original_quest_save = QuestManager._live_save_data

	var stages: Array[AdvancementStageResource] = [_stage]
	ResourceManager.live_save_data = _save
	CultivationManager.live_save_data = _save
	CultivationManager.advancement_stage_resources = stages
	CharacterManager.live_save_data = _save
	InventoryManager.live_save_data = _save
	UnlockManager.live_save_data = _save
	EventManager.live_save_data = _save
	QuestManager._live_save_data = _save

func after_each() -> void:
	ResourceManager.live_save_data = _original_resource_save
	CultivationManager.live_save_data = _original_cultivation_save
	CultivationManager.advancement_stage_resources = _original_stage_resources
	CharacterManager.live_save_data = _original_character_save
	InventoryManager.live_save_data = _original_inventory_save
	UnlockManager.live_save_data = _original_unlock_save
	EventManager.live_save_data = _original_event_save
	QuestManager._live_save_data = _original_quest_save

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The Madra pool cap for the save's current Core Density level, from the stub stage.
func _pool_cap() -> float:
	return _stage.get_max_madra(int(_save.core_density_level))

## The adventure capacity for the save's base attributes (the test save has no equipment).
func _adventure_capacity() -> float:
	return _save.character_attributes.get_max_madra()

## The first message_logged text since watch_signals(LogManager).
func _first_log_message() -> String:
	var params: Variant = get_signal_parameters(LogManager, "message_logged", 0)
	return "" if params == null else str(params[0])

#-----------------------------------------------------------------------------
# ADD MADRA
#-----------------------------------------------------------------------------

func test_add_madra_increases_madra() -> void:
	_save.madra = 10.0
	ResourceManager.add_madra(5.0)
	assert_eq(_save.madra, 15.0)

func test_add_madra_clamps_to_stage_cap() -> void:
	_save.madra = 95.0
	ResourceManager.add_madra(20.0)
	assert_eq(_save.madra, _pool_cap(), "the stage cap at level 0 should absorb the overflow")

func test_add_madra_at_cap_stays_at_cap() -> void:
	_save.madra = _pool_cap()
	ResourceManager.add_madra(50.0)
	assert_eq(_save.madra, _pool_cap())

func test_add_madra_cap_grows_with_core_density_level() -> void:
	_save.core_density_level = 5.0
	_save.madra = 0.0
	ResourceManager.add_madra(1000.0)
	assert_eq(_save.madra, _pool_cap(), "the cap should follow CultivationManager's Core Density level")
	assert_gt(_save.madra, _stage.get_max_madra(0), "a higher level should allow more than the level-0 cap")

func test_add_madra_negative_amount_clamps_to_zero() -> void:
	_save.madra = 10.0
	ResourceManager.add_madra(-50.0)
	assert_eq(_save.madra, 0.0)

func test_add_madra_emits_madra_changed_with_new_total() -> void:
	_save.madra = 10.0
	watch_signals(ResourceManager)
	ResourceManager.add_madra(5.0)
	assert_signal_emit_count(ResourceManager, "madra_changed", 1)
	assert_signal_emitted_with_parameters(ResourceManager, "madra_changed", [15.0])

func test_add_madra_emits_capped_total() -> void:
	_save.madra = 95.0
	watch_signals(ResourceManager)
	ResourceManager.add_madra(20.0)
	assert_signal_emitted_with_parameters(ResourceManager, "madra_changed", [_pool_cap()])

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

func test_spend_madra_deducts_and_returns_true() -> void:
	_save.madra = 50.0
	assert_true(ResourceManager.spend_madra(30.0))
	assert_eq(_save.madra, 20.0)

func test_spend_madra_exact_amount_succeeds() -> void:
	_save.madra = 25.0
	assert_true(ResourceManager.spend_madra(25.0))
	assert_eq(_save.madra, 0.0)

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

func test_set_madra_sets_value() -> void:
	ResourceManager.set_madra(75.0)
	assert_eq(_save.madra, 75.0)
	assert_eq(ResourceManager.get_madra(), 75.0)

func test_set_madra_negative_clamps_to_zero() -> void:
	_save.madra = 40.0
	ResourceManager.set_madra(-10.0)
	assert_eq(_save.madra, 0.0)

func test_set_madra_emits_madra_changed() -> void:
	watch_signals(ResourceManager)
	ResourceManager.set_madra(75.0)
	assert_signal_emitted_with_parameters(ResourceManager, "madra_changed", [75.0])

#-----------------------------------------------------------------------------
# GOLD
#-----------------------------------------------------------------------------

func test_add_gold_increases_gold() -> void:
	_save.gold = 10.0
	ResourceManager.add_gold(5.0)
	assert_eq(_save.gold, 15.0)

func test_add_gold_is_uncapped() -> void:
	ResourceManager.add_gold(1000000.0)
	assert_eq(_save.gold, 1000000.0)

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

func test_spend_gold_deducts_and_returns_true() -> void:
	_save.gold = 100.0
	assert_true(ResourceManager.spend_gold(30.0))
	assert_eq(_save.gold, 70.0)

func test_spend_gold_exact_amount_succeeds() -> void:
	_save.gold = 30.0
	assert_true(ResourceManager.spend_gold(30.0))
	assert_eq(_save.gold, 0.0)

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

func test_set_gold_sets_value() -> void:
	ResourceManager.set_gold(200.0)
	assert_eq(_save.gold, 200.0)
	assert_eq(ResourceManager.get_gold(), 200.0)

func test_set_gold_negative_clamps_to_zero() -> void:
	_save.gold = 40.0
	ResourceManager.set_gold(-5.0)
	assert_eq(_save.gold, 0.0)

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

func test_award_resource_madra_adds_capped_madra() -> void:
	_save.madra = 95.0
	ResourceManager.award_resource(ResourceManager.ResourceType.MADRA, 20.0)
	assert_eq(_save.madra, _pool_cap(), "awarded Madra goes through add_madra and its cap")
	assert_eq(_save.gold, 0.0)

func test_award_resource_gold_adds_gold() -> void:
	ResourceManager.award_resource(ResourceManager.ResourceType.GOLD, 20.0)
	assert_eq(_save.gold, 20.0)
	assert_eq(_save.madra, 0.0)

#-----------------------------------------------------------------------------
# ADVENTURE MADRA
#-----------------------------------------------------------------------------

func test_adventure_capacity_follows_foundation_not_stage_cap() -> void:
	_save.character_attributes.foundation = 12.0
	assert_ne(_adventure_capacity(), _pool_cap(), "precondition: the two caps differ")
	assert_eq(ResourceManager.get_adventure_madra_capacity(), _adventure_capacity())

func test_adventure_budget_is_current_madra_below_capacity() -> void:
	_save.madra = _adventure_capacity() - 20.0
	assert_eq(ResourceManager.get_adventure_madra_budget(), _save.madra)

func test_adventure_budget_is_capacity_when_madra_exceeds_it() -> void:
	_save.madra = _adventure_capacity() + 25.0
	assert_eq(ResourceManager.get_adventure_madra_budget(), _adventure_capacity())

func test_adventure_threshold_is_half_capacity() -> void:
	assert_eq(ResourceManager.get_adventure_madra_threshold(), _adventure_capacity() * 0.5)

func test_can_start_adventure_at_threshold() -> void:
	_save.madra = ResourceManager.get_adventure_madra_threshold()
	assert_true(ResourceManager.can_start_adventure())

func test_cannot_start_adventure_below_threshold() -> void:
	_save.madra = ResourceManager.get_adventure_madra_threshold() - 0.1
	assert_false(ResourceManager.can_start_adventure())
