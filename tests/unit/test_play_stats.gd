extends GutTest

## Unit tests for PlayStatsData, what a save records about how it was played:
## playtime, the playtime at which each event first fired and each unlock
## condition first latched, and a few counts. The first time is kept, an empty id
## is no moment, and nothing is recorded while recording is paused (a dev command
## runs game code with it paused, so dev actions never count as play). Where each
## stat is recorded is test_play_stats_recording.gd's.

const EVENT_ID: String = "play_stats_test_event"
const CONDITION_ID: String = "play_stats_test_condition"

var _stats: PlayStatsData

func before_each() -> void:
	_stats = PlayStatsData.new()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Every count and the gold, in one list, in the order the resource declares them.
func _counts(stats: PlayStatsData) -> Array:
	return [
		stats.cycles_finished, stats.adventures_started, stats.adventures_won,
		stats.adventures_lost, stats.adventures_timed_out, stats.fights_won,
		stats.gold_earned,
	]

## Records one of everything.
func _record_everything(stats: PlayStatsData) -> void:
	stats.record_event(EVENT_ID)
	stats.record_condition(CONDITION_ID)
	stats.count_cycle_finished()
	stats.count_adventure_started()
	stats.count_adventure_won()
	stats.count_adventure_lost()
	stats.count_adventure_timed_out()
	stats.count_fight_won()
	stats.add_gold_earned(25.0)

#-----------------------------------------------------------------------------
# A NEW RESOURCE
#-----------------------------------------------------------------------------

func test_a_new_resource_is_empty() -> void:
	assert_eq(_stats.play_time, 0.0)
	assert_true(_stats.event_first_times.is_empty())
	assert_true(_stats.condition_first_times.is_empty())
	assert_eq(_counts(_stats), [0, 0, 0, 0, 0, 0, 0.0])
	assert_eq(_stats.built_from_preset, "", "real play is built from no preset")
	assert_false(_stats.recording_paused)

#-----------------------------------------------------------------------------
# PLAYTIME
#-----------------------------------------------------------------------------

func test_play_time_adds_up() -> void:
	_stats.add_play_time(1.5)
	_stats.add_play_time(2.25)
	assert_eq(_stats.play_time, 3.75)

#-----------------------------------------------------------------------------
# FIRST TIMES
#-----------------------------------------------------------------------------

func test_record_event_keeps_the_first_time() -> void:
	_stats.play_time = 12.5
	_stats.record_event(EVENT_ID)
	_stats.play_time = 40.0
	_stats.record_event(EVENT_ID)
	assert_eq(_stats.event_first_times.size(), 1)
	assert_eq(_stats.event_first_times.get(EVENT_ID), 12.5, "a second firing does not move the time")
	assert_true(_stats.condition_first_times.is_empty(), "an event is not a condition")

func test_record_condition() -> void:
	_stats.play_time = 7.0
	_stats.record_condition(CONDITION_ID)
	_stats.play_time = 30.0
	_stats.record_condition(CONDITION_ID)
	assert_eq(_stats.condition_first_times.size(), 1)
	assert_eq(_stats.condition_first_times.get(CONDITION_ID), 7.0, "a second latch does not move the time")
	assert_true(_stats.event_first_times.is_empty(), "a condition is not an event")

func test_first_time_of_reads_events_then_conditions() -> void:
	_stats.play_time = 1.0
	_stats.record_event("shared_id")
	_stats.play_time = 2.0
	_stats.record_condition("shared_id")
	_stats.record_condition(CONDITION_ID)
	assert_eq(_stats.first_time_of("shared_id"), 1.0, "the event's time wins over the condition's")
	assert_eq(_stats.first_time_of(CONDITION_ID), 2.0, "an id only a condition has reads the condition's")
	assert_eq(_stats.first_time_of("never_fired"), -1.0, "an id that never fired has no time")

func test_empty_ids_are_ignored() -> void:
	_stats.record_event("")
	_stats.record_condition("")
	assert_true(_stats.event_first_times.is_empty(), "the empty id is no event")
	assert_true(_stats.condition_first_times.is_empty(), "the empty id is no condition (UnlockManager pings it on every reset)")
	assert_eq(_stats.first_time_of(""), -1.0)

#-----------------------------------------------------------------------------
# COUNTS
#-----------------------------------------------------------------------------

func test_each_count_adds_one_to_its_own_field() -> void:
	_stats.count_cycle_finished()
	assert_eq(_counts(_stats), [1, 0, 0, 0, 0, 0, 0.0], "a finished cycle")
	_stats.count_adventure_started()
	assert_eq(_counts(_stats), [1, 1, 0, 0, 0, 0, 0.0], "a started adventure")
	_stats.count_adventure_won()
	assert_eq(_counts(_stats), [1, 1, 1, 0, 0, 0, 0.0], "a won adventure")
	_stats.count_adventure_lost()
	assert_eq(_counts(_stats), [1, 1, 1, 1, 0, 0, 0.0], "a lost adventure")
	_stats.count_adventure_timed_out()
	assert_eq(_counts(_stats), [1, 1, 1, 1, 1, 0, 0.0], "a timed-out adventure")
	_stats.count_fight_won()
	assert_eq(_counts(_stats), [1, 1, 1, 1, 1, 1, 0.0], "a won fight")
	_stats.count_fight_won()
	assert_eq(_stats.fights_won, 2, "a count keeps adding")

func test_gold_earned_adds_up() -> void:
	_stats.add_gold_earned(15.0)
	_stats.add_gold_earned(2.5)
	assert_eq(_stats.gold_earned, 17.5)

#-----------------------------------------------------------------------------
# PAUSED RECORDING
#-----------------------------------------------------------------------------

func test_nothing_is_recorded_while_paused() -> void:
	_stats.recording_paused = true
	_record_everything(_stats)
	assert_true(_stats.event_first_times.is_empty(), "no event")
	assert_true(_stats.condition_first_times.is_empty(), "no condition")
	assert_eq(_counts(_stats), [0, 0, 0, 0, 0, 0, 0.0], "no count and no gold")

func test_recording_resumes_when_unpaused() -> void:
	_stats.recording_paused = true
	_record_everything(_stats)
	_stats.recording_paused = false
	_record_everything(_stats)
	assert_true(_stats.event_first_times.has(EVENT_ID), "the event a paused call skipped can still be recorded")
	assert_true(_stats.condition_first_times.has(CONDITION_ID), "so can the condition")
	assert_eq(_counts(_stats), [1, 1, 1, 1, 1, 1, 25.0], "only the unpaused calls counted")
