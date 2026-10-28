class_name PlayStatsData
extends Resource

## PlayStatsData
## What a save records about how it was played: the playtime, the playtime at
## which each event first fired and each unlock condition first latched, and a few
## counts. Each is recorded by the system that owns the moment, through the
## record_*, count_* and add_* functions below, on the live save's stats
## (SaveGameData.stats). The Foundation playthrough's pacing targets
## (docs/progression/FOUNDATION_PLAYTHROUGH.md) are read from these figures.

#-----------------------------------------------------------------------------
# PLAYTIME
#-----------------------------------------------------------------------------

## Seconds of game time while the main scene runs, scaled by the dev time speed
## (so x10 counts ten times as fast). MainGame adds each frame's delta.
@export var play_time: float = 0.0

#-----------------------------------------------------------------------------
# FIRST TIMES
#-----------------------------------------------------------------------------

## Event id to the play_time at which the event first fired.
@export var event_first_times: Dictionary[String, float] = {}

## Unlock condition id to the play_time at which the condition first latched.
@export var condition_first_times: Dictionary[String, float] = {}

#-----------------------------------------------------------------------------
# COUNTS
#-----------------------------------------------------------------------------

## Cycles that ran to their end.
@export var cycles_finished: int = 0

## Adventures started: counted when the run begins, after the Madra drain.
@export var adventures_started: int = 0

## Adventures that ended in a win (the boss fell).
@export var adventures_won: int = 0

## Adventures that ended with the player's Health at 0.
@export var adventures_lost: int = 0

## Adventures that ended when the run's time ran out.
@export var adventures_timed_out: int = 0

## Fights won, boss fights included, each counted once.
@export var fights_won: int = 0

## Gold earned: every amount added, never a set, a spend or a take-away.
@export var gold_earned: float = 0.0

#-----------------------------------------------------------------------------
# WHERE THE SAVE CAME FROM
#-----------------------------------------------------------------------------

## The preset id this save was built from, "" for real play, so a preset session's
## stats are never mistaken for a playtest.
@export var built_from_preset: String = ""

## Set by DevCommands while a dev command runs game code, so dev actions never count as play.
var recording_paused: bool = false

#-----------------------------------------------------------------------------
# PLAYTIME AND FIRST TIMES
#-----------------------------------------------------------------------------

## Adds game time to play_time. Time passes whatever a dev command does, so this
## ignores recording_paused.
func add_play_time(seconds: float) -> void:
	play_time += seconds

## Records the event's first firing at the current play_time. A repeat keeps the
## first time. Records nothing for an empty id or while recording is paused.
func record_event(event_id: String) -> void:
	if event_id.is_empty() or recording_paused or event_first_times.has(event_id):
		return
	event_first_times[event_id] = play_time

## Records the condition's first latch at the current play_time. A repeat keeps the
## first time. Records nothing for an empty id (UnlockManager announces "" on every
## save reset) or while recording is paused.
func record_condition(condition_id: String) -> void:
	if condition_id.is_empty() or recording_paused or condition_first_times.has(condition_id):
		return
	condition_first_times[condition_id] = play_time

## Returns the play_time at which the event with this id first fired, else the one
## at which the condition with this id first latched, else -1.0 (it never has).
func first_time_of(id: String) -> float:
	if event_first_times.has(id):
		return event_first_times[id]
	if condition_first_times.has(id):
		return condition_first_times[id]
	return -1.0

#-----------------------------------------------------------------------------
# COUNTS
#-----------------------------------------------------------------------------

## Counts a cycle that ran to its end. Does nothing while recording is paused.
func count_cycle_finished() -> void:
	if recording_paused:
		return
	cycles_finished += 1

## Counts an adventure whose run began. Does nothing while recording is paused.
func count_adventure_started() -> void:
	if recording_paused:
		return
	adventures_started += 1

## Counts an adventure won. Does nothing while recording is paused.
func count_adventure_won() -> void:
	if recording_paused:
		return
	adventures_won += 1

## Counts an adventure lost, its Health at 0. Does nothing while recording is paused.
func count_adventure_lost() -> void:
	if recording_paused:
		return
	adventures_lost += 1

## Counts an adventure that ran out of time. Does nothing while recording is paused.
func count_adventure_timed_out() -> void:
	if recording_paused:
		return
	adventures_timed_out += 1

## Counts a fight won. Does nothing while recording is paused.
func count_fight_won() -> void:
	if recording_paused:
		return
	fights_won += 1

## Adds gold earned. Does nothing while recording is paused.
func add_gold_earned(amount: float) -> void:
	if recording_paused:
		return
	gold_earned += amount

func _to_string() -> String:
	return "PlayStatsData(PlayTime: %.1f, Events: %d, Conditions: %d, Cycles: %d, Adventures: %d started / %d won / %d lost / %d timed out, FightsWon: %d, GoldEarned: %.1f, BuiltFromPreset: %s)" % [
		play_time,
		event_first_times.size(),
		condition_first_times.size(),
		cycles_finished,
		adventures_started,
		adventures_won,
		adventures_lost,
		adventures_timed_out,
		fights_won,
		gold_earned,
		built_from_preset,
	]
