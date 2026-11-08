class_name FightTransition
extends Node

## FightTransition
## A fight's two edges on the adventure view, as #138's canvas "Into and out of a
## fight" settled them, each played as beats at set times. The cabinet, the chest
## and the dock stay where they are; only the map and the fight under them change.
## The way in (play_way_in()): the map's camera pushes in on the player's hex
## (AdventureTilemap.push_in_on_player()); then a still of the pushed-in map
## dissolves away over the fight (FightDissolve, a ViewDissolve), which shows as
## the map hides, and both fighters slide to their spots
## (AdventureCombat.play_enter()); once they stand there, `landed`.
## The way out (play_way_out()), from the hit that decides the fight, once the
## hit-stop the view starts has run out: the loser falls
## (AdventureCombat.play_defeat()), the winner stands alone for a beat, then a
## still of the fight dissolves away over the map as the fight hides
## (`fight_hidden`), and once the dissolve has played, `map_whole`.
## The beats run on a tween that ignores the time scale, so a hit-stop slows the
## fight's own motion but not the edges. finish_now() runs every beat still to
## come at once; cut() runs none and shows the map outright.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Both fighters stand on their spots: the fight may start.
signal landed
## The fight's view has gone, with the map back under the dissolve: its fighters
## may go.
signal fight_hidden
## The map is back and whole: the way out is over.
signal map_whole

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How long the map's camera pushes in on the player's hex.
const PUSH_SECONDS: float = 0.3
## How long the winner stands alone between the loser's fall and the map's return.
const BEAT_SECONDS: float = 0.3
## How long a dissolve takes: ViewDissolve's two steps.
const DISSOLVE_SECONDS: float = ViewDissolve.STEP_SECONDS * 2.0
## From the press to the landing (0.7 s).
const WAY_IN_SECONDS: float = PUSH_SECONDS + CombatantVisual.ENTER_SECONDS
## From the deciding hit until the map is whole (1.13 s).
const WAY_OUT_SECONDS: float = GameSpeed.HIT_STOP_SECONDS + CombatantVisual.DEFEAT_SECONDS + BEAT_SECONDS + DISSOLVE_SECONDS

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _tilemap_view: Control = %TilemapView
@onready var _combat_view: Control = %CombatView
@onready var _map: AdventureTilemap = %AdventureTilemap
@onready var _combat: AdventureCombat = %AdventureCombat
@onready var _dissolve: ViewDissolve = %FightDissolve

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The tween that times the beats, while an edge plays.
var _tween: Tween = null
## The beats still to run, in order.
var _beats: Array[Callable] = []
## Whether the edge under way is the way out.
var _closing: bool = false

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Plays the way in from the map to the fight, from the press: the push in starts
## at once.
func play_way_in() -> void:
	_closing = false
	_map.push_in_on_player(PUSH_SECONDS)
	_play([
		[PUSH_SECONDS, _show_the_fight],
		[CombatantVisual.ENTER_SECONDS, _land],
	])

## Plays the way out from the fight to the map, from the hit that decided it:
## `won` says which fighter falls.
func play_way_out(won: bool) -> void:
	_closing = true
	_play([
		[GameSpeed.HIT_STOP_SECONDS, _combat.play_defeat.bind(won)],
		[CombatantVisual.DEFEAT_SECONDS + BEAT_SECONDS, _show_the_map],
		[DISSOLVE_SECONDS, _end_the_way_out],
	])

## Runs every beat still to come at once, in order, and stops the clock that
## timed them.
func finish_now() -> void:
	_kill_tween()
	while not _beats.is_empty():
		var beat: Callable = _beats.pop_front()
		beat.call()

## Drops the edge under way: no beat still to come runs, the camera's push ends,
## a dissolve under way goes, and the map shows outright, the fight hidden.
func cut() -> void:
	_kill_tween()
	_beats.clear()
	_closing = false
	_map.end_push_in()
	_dissolve.stop()
	_combat_view.visible = false
	_tilemap_view.visible = true

## Whether an edge plays.
func is_playing() -> bool:
	return not _beats.is_empty()

## Whether the way out plays.
func is_closing() -> bool:
	return _closing and is_playing()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## Plays `beats`, pairs of [seconds after the beat before, Callable], on a tween
## that ignores the time scale.
func _play(beats: Array) -> void:
	_kill_tween()
	_beats.clear()
	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	for beat: Array in beats:
		_beats.append(beat[1])
		_tween.tween_interval(beat[0])
		_tween.tween_callback(_run_next_beat)

func _run_next_beat() -> void:
	if _beats.is_empty():
		return
	var beat: Callable = _beats.pop_front()
	beat.call()

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

## The map gives way to the fight: a still of the map dissolves over it, the
## map's camera comes back for its return, and the fighters set off.
func _show_the_fight() -> void:
	_dissolve.play()
	_tilemap_view.visible = false
	_combat_view.visible = true
	_map.end_push_in()
	_combat.play_enter()

func _land() -> void:
	landed.emit()

## The fight gives way to the map: a still of the fight dissolves over it.
func _show_the_map() -> void:
	_dissolve.play()
	_combat_view.visible = false
	_tilemap_view.visible = true
	fight_hidden.emit()

func _end_the_way_out() -> void:
	_closing = false
	map_whole.emit()
