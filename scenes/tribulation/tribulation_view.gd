class_name TribulationView
extends Control

## TribulationView
## The Tribulation board: the breathing trial a full core faces to break through to the
## next stage, on a lacquer board in the zone view's map gap. An aura sphere breathes about
## the core (TribulationStage draws it), and the player presses, Space or a click, as the
## bright sphere shrinks across the brass ring; the last breath ends in a hold.
## TribulationRun judges. The board opens on its intro, shows each judgement, applies the
## result the moment the run ends, and emits finished when the player is done.
##
## A press is judged on clock_usec as it arrives, after the beats it left behind, and each
## frame judges the beats that pass. A hit pops its word, flashes the ring and bursts
## pellets off it; a crack pops its word and reason, lights a pip and shakes the board,
## harder for the crack that fails the run. Only the newest feedback shows: a pop hides the
## pair of floaters before it. Every timed effect reads clock_usec, never a frame's delta.
##
## The root covers the screen and stops every click, so none reaches the zone chest: every
## mouse press goes to _gui_input(), which judges it and accepts it, and keys come from the
## view state through handle_press_event(). While the run goes on, a press counts wherever
## it lands. On the intro only Space or a click on the board begins the run: the second
## click of a double click on the card that opened the trial lands outside the board, and
## it must skip neither the rules nor Not yet, since a run cannot be left once it starts.
## The hold belongs to the kind of input that started it, key or mouse button: only that
## kind coming up lets it go, and a focus loss always does.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## The player is done with the board: Continue on the result panel, with whether the
## trial was passed, or Not yet on the intro (false).
signal finished(passed: bool)

#-----------------------------------------------------------------------------
# TYPES
#-----------------------------------------------------------------------------

## What the board shows: nothing (it is hidden), the intro, the run, or the result.
enum Mode { CLOSED, INTRO, RUNNING, RESULT }

const Result := TribulationRun.Result

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The trial's input: Space, or the left mouse button.
const PRESS_ACTION: StringName = &"tribulation_press"

## Where a floater stands on the stage as it pops, before it rises: a feedback's word,
## and the reason line under a miss's word. Their left edge is 2 art px clear of the
## hold arc, whose band ends 158 px right of the centre (x 608).
const WORD_AT: Vector2 = Vector2(612, 286)
const REASON_AT: Vector2 = Vector2(612, 318)

## The ring's frames, and how long it shows its lit one after a hit.
const RING_FRAME: int = 0
const RING_LIT_FRAME: int = 1
const RING_FLASH_USEC: int = 150_000

## A burst: pellets fly from the ring out to BURST_TO_PX, evenly round from BURST_ANGLE,
## over BURST_SECONDS with a BURST_BOW_PX bow. A perfect hit sends PERFECT_PELLETS, a
## good one GOOD_PELLETS, and the hold, once held, HELD_PELLETS in brass.
const BURST_TO_PX: float = 178.0
const BURST_ANGLE: float = 0.3
const BURST_SECONDS: float = 0.4
const BURST_BOW_PX: float = 12.0
const PERFECT_PELLETS: int = 8
const GOOD_PELLETS: int = 5
const HELD_PELLETS: int = 12

## The aura rush: a pellet every RUSH_INTERVAL_USEC flies from RUSH_FROM_PX out into the
## core over RUSH_SECONDS with a RUSH_BOW_PX bow. Pellet k comes from the angle
## k * RUSH_ANGLE_STEP (the golden angle), so the stream comes from all round.
const RUSH_INTERVAL_USEC: int = 100_000
const RUSH_FROM_PX: float = 460.0
const RUSH_ANGLE_STEP: float = 2.39996
const RUSH_SECONDS: float = 0.8
const RUSH_BOW_PX: float = 40.0

## The core strip: a column bigger for every HITS_PER_CORE_SIZE hits, up to its last.
## Its rows: the run's cracks (up to LAST_CRACK_ROW) while it runs, then the spent core
## of a fail or the brass core of a pass.
const HITS_PER_CORE_SIZE: int = 7
const LAST_CORE_COLUMN: int = 3
const LAST_CRACK_ROW: int = 3
const SPENT_CORE_ROW: int = 4
const PASSED_CORE_ROW: int = 5

## The crack pips' frames.
const PIP_UNLIT: int = 0
const PIP_LIT: int = 1

## The floater words.
const PERFECT_WORD: String = "Perfect"
const GOOD_WORD: String = "Good"
const HOLD_FORMAT: String = "%s · hold"
const MISS_WORD: String = "Miss"
const ESCAPED_WORD: String = "The breath escapes you"
const EARLY_REASON: String = "Too early"
const LATE_REASON: String = "Too late"
const RELEASED_WORD: String = "Released too early"
const HELD_WORD: String = "Held"

## The result panel's counts: the perfect hits, the good ones and the cracks.
const STATS_FORMAT: String = "%d perfect · %d good · %d missed"

const _PELLET_SCENE: PackedScene = preload("res://scenes/zones/zone_transition/madra_pellet.tscn")
const _BRASS_PELLET: Texture2D = preload("res://assets/ui/lacquer/cycling/lacquer_cyc_pellet_brass_ai.png")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _board: PanelContainer = %Board
@onready var _action_label: Label = %ActionLabel
@onready var _title_label: Label = %TitleLabel
@onready var _stage: TribulationStage = %Stage
@onready var _ring: LacquerStripRect = %Ring
@onready var _core: LacquerStripRect = %Core
@onready var _pellets: Node2D = %Pellets
@onready var _floater_layer: Control = %Floaters
@onready var _intro_panel: Control = %IntroPanel
@onready var _intro_title: Label = %IntroTitle
@onready var _intro_text: Label = %IntroText
@onready var _rules_label: Label = %RulesLabel
@onready var _begin_button: TextureButton = %BeginButton
@onready var _begin_hover: LacquerFrameOverlay = %BeginHover
@onready var _not_yet_button: TextureButton = %NotYetButton
@onready var _not_yet_hover: LacquerFrameOverlay = %NotYetHover
@onready var _result_panel: Control = %ResultPanel
@onready var _result_title: Label = %ResultTitle
@onready var _result_text: Label = %ResultText
@onready var _grade_label: Label = %GradeLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _continue_button: TextureButton = %ContinueButton
@onready var _continue_hover: LacquerFrameOverlay = %ContinueHover
@onready var _phase_name_label: Label = %PhaseNameLabel
@onready var _phase_tip_label: Label = %PhaseTipLabel
@onready var _crack_pips: HBoxContainer = %CrackPips
@onready var _progress_rod: LacquerRod = %ProgressRod

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The clock every judgement and timed effect reads, in microseconds. Tests replace it.
var clock_usec: Callable = Time.get_ticks_usec

var _mode: Mode = Mode.CLOSED
var _data: TribulationData = null
var _run: TribulationRun = null
## The clock when the run began: the trial's time 0.
var _start_usec: int = 0
## Whether the run was passed, for Continue to report.
var _passed: bool = false
## Whether the last breath was held into the core: the hold counts as a hit for the core.
var _held: bool = false
## Whether the mouse button started the hold (a key did otherwise).
var _hold_by_mouse: bool = false
## How many cracks the board has shown this run.
var _cracks_shown: int = 0

## Until when the ring shows its lit frame, on the clock.
var _ring_flash_end_usec: int = 0
## The shake running (empty for none) and when it started, on the clock.
var _shake_keyframes: Array[int] = []
var _shake_start_usec: int = 0
## How many rush pellets the run has sent, and when the next may go, on the clock.
var _rush_count: int = 0
var _next_rush_usec: int = 0

## The floaters, word and reason line in turn, and the pair the newest feedback is on.
var _floaters: Array[LacquerFloater] = []
var _floater_pair: int = 0
## The crack pip sockets, in order.
var _pips: Array[LacquerStripRect] = []
## The board's sides at home, which a shake steps away from and back to.
var _board_left: float = 0.0
var _board_right: float = 0.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	for child: Node in _floater_layer.get_children():
		_floaters.append(child as LacquerFloater)
	for child: Node in _crack_pips.get_children():
		_pips.append(child as LacquerStripRect)
	_board_left = _board.offset_left
	_board_right = _board.offset_right
	_begin_button.pressed.connect(begin)
	_not_yet_button.pressed.connect(cancel)
	_continue_button.pressed.connect(_on_continue_pressed)
	_connect_hover(_begin_button, _begin_hover)
	_connect_hover(_not_yet_button, _not_yet_hover)
	_connect_hover(_continue_button, _continue_hover)
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()

func _process(_delta: float) -> void:
	if _mode == Mode.CLOSED:
		return
	var now: int = clock_usec.call()
	if _mode == Mode.RUNNING:
		_run_frame(now)
	var ring_frame: int = RING_LIT_FRAME if now < _ring_flash_end_usec else RING_FRAME
	if _ring.get_frame().x != ring_frame:
		_ring.set_frame(ring_frame)
	_step_shake(now)
	_place_floaters()

## Every mouse event that reaches the root, on the board or anywhere around it, is the
## board's: a press of the trial's button is judged (on the intro, only one on the board
## begins the run), and nothing passes beneath.
func _gui_input(event: InputEvent) -> void:
	handle_press_event(event)
	accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _mode == Mode.RUNNING and _run.is_holding():
		_let_go(_trial_time())

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Opens the board on its intro for `data`, the trial of the zone named `zone_name`: the
## title, the intro text and the rules line, a pip socket for each of cracks_to_fail
## (unlit), the first phase's name and tip, an empty rod and the smallest whole core.
## Nothing of what the board showed before is left.
func setup(data: TribulationData, zone_name: String) -> void:
	_data = data
	_run = null
	_mode = Mode.INTRO
	_clear_effects()
	_action_label.text = zone_name
	_title_label.text = data.title
	_intro_title.text = data.title
	_intro_text.text = data.intro_text
	_rules_label.text = data.get_rules_line()
	if data.phases.is_empty():
		_show_phase(data.last_breath_name, data.last_breath_tip)
	else:
		_show_phase(data.phases[0].phase_name, data.phases[0].tip)
	for index: int in _pips.size():
		_pips[index].visible = index < data.cracks_to_fail
	_show_pips(0)
	_progress_rod.set_fraction(0.0)
	_core.set_frame(0, 0)
	for hover: LacquerFrameOverlay in [_begin_hover, _not_yet_hover, _continue_hover]:
		hover.hide()
	_result_panel.hide()
	_intro_panel.show()
	show()

## Begins the run, when the intro shows: the trial's time 0 is now, on clock_usec.
func begin() -> void:
	if _mode != Mode.INTRO:
		return
	_run = TribulationRun.new(_data)
	_start_usec = clock_usec.call()
	_passed = false
	_held = false
	_hold_by_mouse = false
	_cracks_shown = 0
	_rush_count = 0
	_next_rush_usec = 0
	_mode = Mode.RUNNING
	_intro_panel.hide()

## Turns the trial down from the intro: finished(false), with nothing changed.
func cancel() -> void:
	if _mode == Mode.INTRO:
		finished.emit(false)

## Hides the board. A run in progress is dropped, and nothing of it is applied.
func close() -> void:
	_mode = Mode.CLOSED
	_run = null
	_clear_effects()
	hide()

## Takes an event of the trial's input (tribulation_press) and returns true for each one
## of them, false for any other event. A key's repeats are not presses. On the intro a key
## press begins the run, wherever the pointer is, and a mouse press begins it only on the
## board (see _press_begins_the_run()); a click anywhere else on the intro does nothing,
## though _gui_input() still accepts it, so it reaches nothing beneath. While the run goes
## on, a press is judged wherever it lands, and a release lets go of the hold when it comes
## from the kind of input that started it, each on clock_usec as it arrives. On the result
## panel nothing happens: only Continue closes it.
func handle_press_event(event: InputEvent) -> bool:
	if not event.is_action(PRESS_ACTION):
		return false
	if event.is_action_pressed(PRESS_ACTION):
		if _mode == Mode.INTRO:
			if _press_begins_the_run(event):
				begin()
		elif _mode == Mode.RUNNING:
			_on_press(event)
	elif event.is_action_released(PRESS_ACTION) and _mode == Mode.RUNNING:
		_on_release(event)
	return true

## Returns what the board shows.
func get_mode() -> Mode:
	return _mode

## Returns the run being played or just ended, or null before Begin and after close().
func get_run() -> TribulationRun:
	return _run

#-----------------------------------------------------------------------------
# JUDGING
#-----------------------------------------------------------------------------

## Returns whether a press of the trial's input begins the run from the intro. A key does,
## wherever the pointer is. A mouse button does only when it lands on the board. Its position
## is the one the event carries (in the view's canvas, as the board's global rect is), not
## where the pointer is by now. A click on what lies around the board, the card that opened
## the trial among it, begins nothing.
func _press_begins_the_run(event: InputEvent) -> bool:
	var click := event as InputEventMouseButton
	return click == null or _board.get_global_rect().has_point(click.global_position)

## Returns the trial's time now, in seconds from its start.
func _trial_time() -> float:
	return _trial_time_at(clock_usec.call())

func _trial_time_at(usec: int) -> float:
	return (usec - _start_usec) / 1_000_000.0

## One frame of the run: the beats that passed are judged (before the run is asked
## whether it failed or is over), and the run ends if so. Otherwise the rush streams,
## the stage draws and the HUD follows the run.
func _run_frame(now: int) -> void:
	var t: float = _trial_time_at(now)
	if not _pass_time(t):
		return
	if _run.is_finished(t):
		_end(true)
		return
	if _run.aura_rush_at(t):
		_stream_rush(now)
	_stage.show_frame(_run, t)
	_update_hud(t)

## Judges a press now. The beats it left behind are judged first, so their misses show
## before its own result. A hit on the last beat starts the hold, which this kind of
## input owns.
func _on_press(event: InputEvent) -> void:
	var t: float = _trial_time()
	if not _pass_time(t):
		return
	var judgement: Dictionary = _run.press(t)
	if judgement["last"] and _run.is_holding():
		_hold_by_mouse = event is InputEventMouseButton
	_show_judgement(judgement)
	_after_input(t)

## Lets go of the hold now, when `event` is the kind of input that started it.
func _on_release(event: InputEvent) -> void:
	if _run.is_holding() and (event is InputEventMouseButton) == _hold_by_mouse:
		_let_go(_trial_time())

## Ends the hold at `t`: held, or released too early.
func _let_go(t: float) -> void:
	if not _pass_time(t):
		return
	_show_judgement(_run.release(t))
	_after_input(t)

## Judges the passing of time to `t` and shows what it brought. Returns false when that
## failed the run, which it then ends.
func _pass_time(t: float) -> bool:
	_show_judgements(_run.advance(t))
	if _run.is_failed():
		_end(false)
		return false
	return true

## After a press or a release: when it failed the run, the run ends once advance() has
## handed over any misses the run queued meanwhile (TribulationRun queues the late misses
## a press settles; _pass_time() has judged those first, so none are left today).
## Otherwise the HUD shows the new counts.
func _after_input(t: float) -> void:
	if _run.is_failed():
		_show_judgements(_run.advance(t))
		_end(false)
	else:
		_update_hud(t)

func _show_judgements(judgements: Array[Dictionary]) -> void:
	for judgement: Dictionary in judgements:
		_show_judgement(judgement)

## Shows one of TribulationRun's judgements, {result, last}. An ignored press or release
## shows nothing.
func _show_judgement(judgement: Dictionary) -> void:
	var last: bool = judgement["last"]
	match judgement["result"]:
		Result.PERFECT:
			_show_hit(PERFECT_WORD, ThemeConstants.LACQUER_BRASS, PERFECT_PELLETS, last)
		Result.GOOD:
			_show_hit(GOOD_WORD, ThemeConstants.LACQUER_MADRA, GOOD_PELLETS, last)
		Result.EARLY_MISS:
			_show_crack(ESCAPED_WORD if last else MISS_WORD, EARLY_REASON)
		Result.LATE_MISS:
			_show_crack(ESCAPED_WORD if last else MISS_WORD, LATE_REASON)
		Result.RELEASED_EARLY:
			_show_crack(RELEASED_WORD, "")
		Result.HELD:
			_held = true
			_pop_floaters(HELD_WORD, ThemeConstants.LACQUER_BRASS, "")
			_burst(HELD_PELLETS, _BRASS_PELLET)

## A hit: its word ("· hold" after it on the last beat), the ring's flash and a burst.
func _show_hit(word: String, color: Color, pellets: int, last: bool) -> void:
	_pop_floaters(HOLD_FORMAT % word if last else word, color, "")
	_ring_flash_end_usec = clock_usec.call() + RING_FLASH_USEC
	_ring.set_frame(RING_LIT_FRAME)
	_burst(pellets, null)

## A crack: its word and its reason in the warning colour, and the board shakes, by the
## full shake for the crack that fails the run. Its pip lights with the HUD.
func _show_crack(word: String, reason: String) -> void:
	_cracks_shown += 1
	_pop_floaters(word, ThemeConstants.LACQUER_HEALTH, reason)
	var failing: bool = _cracks_shown >= _data.cracks_to_fail
	_start_shake(MapGlyph.SHAKE_KEYFRAMES if failing else MapGlyph.SOFT_SHAKE_KEYFRAMES)

#-----------------------------------------------------------------------------
# THE END
#-----------------------------------------------------------------------------

## Ends the run and applies its result at once: the breakthrough to the next stage, or
## the levels a failure costs (the level before and after go in the fail line). The
## result panel shows the copy, the grade and the counts; the core turns brass or
## spent, and the stage empties.
func _end(passed: bool) -> void:
	_mode = Mode.RESULT
	_passed = passed
	_update_hud(_trial_time())
	if passed:
		if not CultivationManager.advance_to_next_stage():
			Log.warn("TribulationView: the trial was passed, but the stage has no next stage")
		_result_title.text = _data.pass_title
		_result_text.text = _data.pass_text
	else:
		var before: int = int(CultivationManager.get_core_density_level())
		CultivationManager.lose_core_density_levels(_data.failure_level_loss)
		_result_title.text = _data.fail_title
		_result_text.text = _data.get_fail_line(before, int(CultivationManager.get_core_density_level()))
	_grade_label.text = _run.grade()
	_stats_label.text = STATS_FORMAT % [_run.perfect_count, _run.good_count, _run.cracks]
	_core.set_frame(_core_column(), PASSED_CORE_ROW if passed else SPENT_CORE_ROW)
	_stage.clear()
	_result_panel.show()

func _on_continue_pressed() -> void:
	if _mode == Mode.RESULT:
		finished.emit(_passed)

#-----------------------------------------------------------------------------
# HUD
#-----------------------------------------------------------------------------

## Shows the run at `t`: the phase's name and tip (the last breath's during the last
## breath), the rod, a lit pip for each crack, and the core's size and cracks.
func _update_hud(t: float) -> void:
	var phase: TribulationPhaseData = _run.phase_at(t)
	if phase == null:
		_show_phase(_data.last_breath_name, _data.last_breath_tip)
	else:
		_show_phase(phase.phase_name, phase.tip)
	_progress_rod.set_fraction(_run.progress(t))
	_show_pips(_run.cracks)
	_core.set_frame(_core_column(), mini(_run.cracks, LAST_CRACK_ROW))

func _show_phase(phase_name: String, tip: String) -> void:
	_phase_name_label.text = phase_name
	_phase_tip_label.text = tip

## Lights the first `lit` pips.
func _show_pips(lit: int) -> void:
	for index: int in _pips.size():
		_pips[index].set_frame(PIP_LIT if index < lit else PIP_UNLIT)

## Returns the core's column: a size for every HITS_PER_CORE_SIZE hits, the hold one of them.
func _core_column() -> int:
	var hits: int = _run.perfect_count + _run.good_count + (1 if _held else 0)
	@warning_ignore("integer_division")
	return mini(hits / HITS_PER_CORE_SIZE, LAST_CORE_COLUMN)

#-----------------------------------------------------------------------------
# EFFECTS
#-----------------------------------------------------------------------------

## Pops a feedback on the next pair of floaters, `word` with `reason` under it unless it
## is empty, both in `color`, and hides the feedback before it.
func _pop_floaters(word: String, color: Color, reason: String) -> void:
	for floater: LacquerFloater in _floaters:
		floater.stop()
	@warning_ignore("integer_division")
	_floater_pair = (_floater_pair + 1) % (_floaters.size() / 2)
	_floaters[2 * _floater_pair].pop(word, color)
	if not reason.is_empty():
		_floaters[2 * _floater_pair + 1].pop(reason, color)
	_place_floaters()

## Stands each floater that shows on its spot, a word's or a reason line's, raised by its rise.
func _place_floaters() -> void:
	for index: int in _floaters.size():
		var floater: LacquerFloater = _floaters[index]
		if floater.visible:
			var spot: Vector2 = WORD_AT if index % 2 == 0 else REASON_AT
			floater.position = spot - Vector2(0, floater.get_rise())

## Sends `count` pellets off the ring, evenly round, in `texture` (the Madra pellet's own
## art when null).
func _burst(count: int, texture: Texture2D) -> void:
	var centre: Vector2 = _stage.centre_global()
	for index: int in count:
		var direction: Vector2 = Vector2.from_angle(float(index) / count * TAU + BURST_ANGLE)
		var start: Vector2 = centre + direction * TribulationStage.RING_RADIUS_PX
		_add_pellet(texture).launch(start, centre + direction * BURST_TO_PX, BURST_SECONDS, BURST_BOW_PX)

## Streams the next rush pellet into the core, once RUSH_INTERVAL_USEC has passed since the
## last. After a long frame the stream picks up from now, with no burst of catching up.
func _stream_rush(now: int) -> void:
	if now < _next_rush_usec:
		return
	var centre: Vector2 = _stage.centre_global()
	var start: Vector2 = centre + Vector2.from_angle(_rush_count * RUSH_ANGLE_STEP) * RUSH_FROM_PX
	_add_pellet(null).launch(start, centre, RUSH_SECONDS, RUSH_BOW_PX)
	_rush_count += 1
	_next_rush_usec += RUSH_INTERVAL_USEC
	if _next_rush_usec <= now:
		_next_rush_usec = now + RUSH_INTERVAL_USEC

## Instances a pellet on the stage, over the core and under the floaters, in `texture`
## (the Madra pellet's own art when null).
func _add_pellet(texture: Texture2D) -> MadraPellet:
	var pellet: MadraPellet = _PELLET_SCENE.instantiate() as MadraPellet
	_pellets.add_child(pellet)
	if texture != null:
		pellet.set_texture(texture)
	return pellet

## Starts the board's shake over `keyframes`, now; a new shake restarts it.
func _start_shake(keyframes: Array[int]) -> void:
	_shake_keyframes = keyframes
	_shake_start_usec = clock_usec.call()

## Steps the shake to `now`: the board stands its keyframe's px off home, then home again
## once MapGlyph.SHAKE_SECONDS have passed.
func _step_shake(now: int) -> void:
	if _shake_keyframes.is_empty():
		return
	var elapsed: float = (now - _shake_start_usec) / 1_000_000.0
	if elapsed >= MapGlyph.SHAKE_SECONDS:
		_stop_shake()
	else:
		_shift_board(MapGlyph.shake_offset_at(elapsed, _shake_keyframes))

func _stop_shake() -> void:
	_shake_keyframes = []
	_shift_board(0)

## Stands the board `shift` px across from home. Only its sides move: its height follows
## what it holds.
func _shift_board(shift: int) -> void:
	_board.offset_left = _board_left + shift
	_board.offset_right = _board_right + shift

## Hides what the effects left: the floaters, the pellets in flight (freed), the shake,
## the ring's flash and the stage's spheres and arc.
func _clear_effects() -> void:
	for floater: LacquerFloater in _floaters:
		floater.stop()
	for pellet: Node in _pellets.get_children():
		_pellets.remove_child(pellet)
		pellet.queue_free()
	_stop_shake()
	_ring_flash_end_usec = 0
	_ring.set_frame(RING_FRAME)
	_stage.clear()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _connect_hover(button: TextureButton, hover: LacquerFrameOverlay) -> void:
	button.mouse_entered.connect(hover.show)
	button.mouse_exited.connect(hover.hide)

## The board runs its frames only while it shows.
func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree())
