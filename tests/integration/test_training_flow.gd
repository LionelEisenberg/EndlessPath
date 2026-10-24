extends GutTest

## Integration test: TRAIN_STATS action drives ZoneProgressionData ticks,
## fires effects_per_tick every tick, and effects_on_level once per level crossed.
## Progress persists across stop/restart. The test is the clock: it holds
## ActionManager's tick timer and times it out by hand, one tick each.

var _save_data: SaveGameData
var _training_data: TrainingActionData
var _spirit_award_effect: AwardAttributeEffectData
var _madra_trickle_effect: AwardResourceEffectData

var _original_character_live: SaveGameData
var _original_zone_live: SaveGameData
var _original_resource_live: SaveGameData
var _original_event_live: SaveGameData

var _tick_signal_count: int = 0
var _level_signal_levels: Array[int] = []

func before_each() -> void:
	_save_data = SaveGameData.new()
	_save_data.character_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	_save_data.madra = 0.0
	_save_data.current_selected_zone_id = "SpiritValley"

	_original_character_live = CharacterManager.live_save_data
	_original_zone_live = ZoneManager.live_save_data
	_original_resource_live = ResourceManager.live_save_data
	_original_event_live = EventManager.live_save_data

	CharacterManager.live_save_data = _save_data
	ZoneManager.live_save_data = _save_data
	ResourceManager.live_save_data = _save_data
	EventManager.live_save_data = _save_data

	_spirit_award_effect = AwardAttributeEffectData.new()
	_spirit_award_effect.attribute_type = CharacterAttributesData.AttributeType.SPIRIT
	_spirit_award_effect.amount = 1.0

	_madra_trickle_effect = AwardResourceEffectData.new()
	_madra_trickle_effect.resource_type = ResourceManager.ResourceType.MADRA
	_madra_trickle_effect.amount = 1.0

	_training_data = TrainingActionData.new()
	_training_data.action_id = "test_training"
	_training_data.action_name = "Test Training"
	_training_data.tick_interval_seconds = 0.05
	_training_data.ticks_per_level = [3, 3] as Array[int]
	_training_data.tail_growth_multiplier = 2.0
	_training_data.effects_per_tick = [_madra_trickle_effect] as Array[EffectData]
	_training_data.effects_on_level = [_spirit_award_effect] as Array[EffectData]

	_tick_signal_count = 0
	_level_signal_levels = []
	ActionManager.training_tick_processed.connect(_on_tick)
	ActionManager.training_level_gained.connect(_on_level)

func after_each() -> void:
	# Let the held tick timer go, or no later tick would ever come.
	ActionManager.action_timer.paused = false
	if ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	ActionManager.training_tick_processed.disconnect(_on_tick)
	ActionManager.training_level_gained.disconnect(_on_level)
	CharacterManager.live_save_data = _original_character_live
	ZoneManager.live_save_data = _original_zone_live
	ResourceManager.live_save_data = _original_resource_live
	EventManager.live_save_data = _original_event_live

func _on_tick(_data: TrainingActionData, _count: int) -> void:
	_tick_signal_count += 1

func _on_level(_data: TrainingActionData, level: int) -> void:
	_level_signal_levels.append(level)

func _get_spirit() -> float:
	return _save_data.character_attributes.get_attribute(CharacterAttributesData.AttributeType.SPIRIT)

## Times the held tick timer out `count` times, as it does once every
## tick_interval_seconds while training runs.
func _tick(count: int) -> void:
	for _i: int in count:
		ActionManager.action_timer.timeout.emit()

## ActionManager's Timer fires at most once a frame, so on a busy machine (frames
## longer than the 0.05 s tick) the ticks lag the clock: the test holds the timer
## and times it out itself, never waiting on a window of time.
func test_training_ticks_fire_effects_and_level_up() -> void:
	ActionManager.select_action(_training_data)
	var timer: Timer = ActionManager.action_timer
	timer.paused = true
	assert_false(timer.is_stopped(), "the tick timer runs while training")
	assert_eq(timer.wait_time, _training_data.tick_interval_seconds, "it times out once per tick_interval_seconds")
	assert_false(timer.one_shot, "and repeats")

	_tick(4)

	assert_eq(_tick_signal_count, 4, "each time-out is one tick")
	assert_eq(_save_data.madra, float(_tick_signal_count), "madra should equal tick count (1.0 per tick)")
	assert_eq(_level_signal_levels, [1] as Array[int], "level 1 should have been gained exactly once (not yet level 2)")
	assert_eq(_get_spirit(), 11.0, "Spirit should be 10 + 1 = 11 after one level-up")

	ActionManager.stop_action()

	assert_eq(ZoneManager.get_training_ticks("test_training", "SpiritValley"), _tick_signal_count,
		"accumulated_ticks should persist after stop and match tick count")

	ActionManager.select_action(_training_data)
	assert_false(timer.is_stopped(), "the tick timer runs again after the restart")
	_tick(2)

	assert_eq(_tick_signal_count, 6, "tick signal should have fired more times after restart")
	assert_true(_level_signal_levels.has(2), "level 2 should have been gained after tick 6")
	# A restart that started over would cross level 1 again on its way to level 2.
	assert_eq(_level_signal_levels, [1, 2] as Array[int], "the restart counts on from the kept ticks")
	assert_eq(ZoneManager.get_training_ticks("test_training", "SpiritValley"), _tick_signal_count,
		"every tick, before and after the restart, is kept")
	assert_eq(_get_spirit(), 12.0, "Spirit should be 12 after two level-ups")

	ActionManager.stop_action()
