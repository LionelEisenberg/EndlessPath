class_name DrillPlay
extends Control

## DrillPlay
## The drill being played on the body refining board: the scene of the drill's
## input (a DrillStage under Stages, one for each input kind, the drill's alone
## showing), ten rep beads under it and a pair of floaters. The drill's run
## (DrillRun.for_drill()) judges, the stage draws, and this plays the set.
##
## The first press of the drill's input (drill_press: Space or the left mouse
## button) starts a set at that moment on clock_usec. On the hold drills that press
## is also the first lift or sink; on the others it only starts the set. Each press
## after it is judged on the clock as it arrives, aimed where it was made (a mouse
## press's point, else the pointer's), and each frame judges what the passing of
## time decided (a drop at the top, a leaf landing, a rep nobody played). Each
## judged rep is paid at once through BodyRefiningManager.pay_rep() into the set's
## result, a MISS included (it pays nothing), so a set stopped midway keeps what its
## reps paid. Its bead lights in its tier's colour, its tier pops where the stage
## says in that colour, and under it a Miss's reason, or, in tan, the part a scored
## rep could not pay: Strength's icon with "capped", the Health heart with "full".
## Then rep_judged reports the rep, the Health it restored and the XP each stat
## took, for the board's pellets, which leave from get_pellet_origin(). Every timed
## effect reads clock_usec.
##
## While a set runs it keeps BodyRefiningManager's set session up to date for the
## Now strip. Once the run is over it counts the set (finish_set()) and emits
## set_completed; the next press starts another set, with its beads empty. The hold
## belongs to the kind of input that started it, key or mouse button: only that
## kind coming up lets it go, a key repeat is no press, and a focus loss always lets
## go: the window's, which every build sends (the Web build sends no other), or the
## application's. stop_set() drops a set in progress, counting nothing, and so do
## hiding the stage and readying a drill.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## The first press started a set.
signal set_started
## A rep was judged and paid: what it restored and the XP each stat took
## (AttributeType to float), for the board's pellets.
signal rep_judged(judgement: DrillRun.Judgement, health: float, stat_xp: Dictionary)
## A set was played to its last rep, and counted.
signal set_completed(result: DrillSetResult)

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const Tier = DrillRules.Tier
const Miss = DrillRun.Miss
const AttributeType = CharacterAttributesData.AttributeType
const InputKind = DrillData.InputKind

## The drill's input.
const PRESS_ACTION: StringName = &"drill_press"

## How far under the tier word its second line stands.
const LINE_DROP: float = 30.0

## Each tier's word and colour (a hit's as cycling's; a Miss in the warning
## colour, as the Tribulation's), and a Miss's reasons.
const TIER_WORDS: Dictionary = {Tier.PERFECT: "Perfect", Tier.GOOD: "Good", Tier.OK: "OK", Tier.MISS: "Miss"}
const MISS_REASONS: Dictionary = {
	Miss.TOO_LOW: "Too low",
	Miss.DROPPED: "Dropped",
	Miss.TOO_LATE: "Too late",
	Miss.TOO_DEEP: "Too deep",
	Miss.TOO_SHALLOW: "Too shallow",
	Miss.TOO_EARLY: "Too early",
	Miss.TOO_FAR: "Too far",
	Miss.LANDED: "Landed",
	Miss.BUCKLED: "Buckled",
}

## What a scored rep could not pay, after its icon, and the gap between two parts.
const CAPPED_TEXT: String = " capped"
const FULL_TEXT: String = " full"
const PART_GAP: String = "  "
const HEALTH_ICON: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_health_ai.png")

## The bead strip's frame for each tier; frame 0 is the empty socket.
const EMPTY_BEAD: int = 0
const BEAD_FRAMES: Dictionary = {Tier.PERFECT: 1, Tier.GOOD: 2, Tier.OK: 3, Tier.MISS: 4}

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _stages_box: Control = %Stages
@onready var _beads_box: HBoxContainer = %Beads
@onready var _word_floater: LacquerFloater = %WordFloater
@onready var _line_floater: LacquerFloater = %LineFloater

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The clock every judgement and timed effect reads, in microseconds. Tests replace it.
var clock_usec: Callable = Time.get_ticks_usec
## Makes a set's run of the drill, seeded with the clock at its first press. Tests
## replace it.
var run_for: Callable = DrillRun.for_drill

var _drill: DrillData = null
var _run: DrillRun = null
var _result: DrillSetResult = null
var _set_running: bool = false
## Each input kind's stage, and the one showing.
var _stages: Dictionary = {}
var _stage: DrillStage = null
## The clock at the set's first press: the set's time 0.
var _start_usec: int = 0
## Whether the input is held, and whether the mouse button holds it (a key otherwise).
var _holding: bool = false
var _hold_by_mouse: bool = false
## Where the tier word popped, before its rise.
var _word_at: Vector2 = Vector2.ZERO
var _beads: Array[LacquerStripRect] = []

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	for child: Node in _beads_box.get_children():
		_beads.append(child as LacquerStripRect)
	for child: Node in _stages_box.get_children():
		var stage := child as DrillStage
		if stage != null:
			_stages[stage.input_kind] = stage
	_show_stage()
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()

func _process(_delta: float) -> void:
	if _stage != null:
		_stage.tick(clock_usec.call())
	if _set_running:
		var t: int = _set_time()
		_apply(_run.advance(t))
		if _set_running:
			_stage.show_run(_run, t)
			BodyRefiningManager.update_set_session(_run.rep_at(t) + 1, _run.rep_progress_at(t))
			var end_usec: int = _run.get_end_usec()
			if end_usec >= 0 and t >= end_usec:
				_finish()
	_place_floaters()

func _notification(what: int) -> void:
	var focus_lost: bool = what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT
	if focus_lost and _holding:
		_let_go()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Readies the play for `drill`: its input's stage showing at rest, no set, the
## beads empty and no floater. A set in progress is dropped.
func setup(drill: DrillData) -> void:
	stop_set()
	_drill = drill
	_run = null
	_result = null
	if is_node_ready():
		_show_stage()
	for bead: LacquerStripRect in _beads:
		bead.set_frame(EMPTY_BEAD)

## Takes an event of the drill's input and returns true for each one of them,
## false for any other event. A press starts a set when none runs, and plays; a
## release lets go when it comes from the kind of input that holds; a key repeat
## does nothing. Each is judged on clock_usec as it arrives.
func handle_press_event(event: InputEvent) -> bool:
	if not event.is_action(PRESS_ACTION):
		return false
	var key := event as InputEventKey
	if key != null and key.echo:
		return true
	if event.is_action_pressed(PRESS_ACTION):
		_on_press(event)
	elif event.is_action_released(PRESS_ACTION):
		_on_release(event)
	return true

## Drops a set in progress: its reps stay paid, but it is neither counted nor
## reported. The session ends, the hold is let go, the floaters hide and the stage
## goes back to rest. The beads keep what they showed.
func stop_set() -> void:
	if _set_running:
		_set_running = false
		BodyRefiningManager.end_set_session()
	_holding = false
	if is_node_ready():
		_word_floater.stop()
		_line_floater.stop()
		if _stage != null:
			_stage.show_rest()

## Returns whether a set is being played.
func is_set_running() -> bool:
	return _set_running

## Returns the set being played, or the last one played, or null before the first.
func get_result() -> DrillSetResult:
	return _result

## Returns the run of the set being played or last played, or null before the first.
func get_run() -> DrillRun:
	return _run

## Returns the stage showing, the drill's input's, or null before a drill is readied.
func get_stage() -> DrillStage:
	return _stage

## Returns where a judged rep's pellets leave from, in the screen's space.
func get_pellet_origin(judgement: DrillRun.Judgement) -> Vector2:
	return _stage.get_global_transform() * _stage.get_pellet_origin(judgement)

#-----------------------------------------------------------------------------
# INPUT
#-----------------------------------------------------------------------------

func _on_press(event: InputEvent) -> void:
	if _drill == null or _holding:
		return
	_holding = true
	_hold_by_mouse = event is InputEventMouseButton
	var starts: bool = not _set_running
	if starts:
		_start_set()
	if not starts or _run.judges_starting_press():
		_apply(_run.press_at(_set_time(), _press_point(event)))

func _on_release(event: InputEvent) -> void:
	if _holding and (event is InputEventMouseButton) == _hold_by_mouse:
		_let_go()

func _let_go() -> void:
	_holding = false
	if _set_running:
		_apply(_run.release(_set_time()))

## Where a press was aimed, in the stage's space: a mouse press's point, else the
## pointer's.
func _press_point(event: InputEvent) -> Vector2:
	var mouse := event as InputEventMouseButton
	if mouse == null:
		return _stage.get_local_mouse_position()
	return _stage.get_global_transform().affine_inverse() * mouse.global_position

#-----------------------------------------------------------------------------
# THE SET
#-----------------------------------------------------------------------------

## Shows the stage of the drill's input at rest and hides the others. An input
## with no stage of its own yet plays Stone Lifting's.
func _show_stage() -> void:
	_stage = null
	if _drill != null:
		_stage = _stages.get(_drill.input_kind, _stages.get(InputKind.HOLD_RELEASE))
	for stage: DrillStage in _stages.values():
		stage.visible = stage == _stage
	if _stage != null:
		_stage.setup(_drill)
		_stage.show_rest()

## Starts a set now: a new run and result, the beads empty and the floaters
## hidden, and the session running.
func _start_set() -> void:
	_start_usec = clock_usec.call()
	_run = run_for.call(_drill, _start_usec) if _stages.has(_drill.input_kind) else StoneLiftingRun.new(_drill)
	_result = DrillSetResult.new(_drill)
	_set_running = true
	for bead: LacquerStripRect in _beads:
		bead.set_frame(EMPTY_BEAD)
	_word_floater.stop()
	_line_floater.stop()
	BodyRefiningManager.start_set_session(_drill.reps_per_set)
	set_started.emit()

## The set's time now, in microseconds from its first press.
func _set_time() -> int:
	return clock_usec.call() - _start_usec

## Pays and shows each judged rep, in order. A listener of rep_judged can stop the
## action, and the stop drops the set: nothing more is shown after that.
func _apply(judgements: Array[DrillRun.Judgement]) -> void:
	for judgement: DrillRun.Judgement in judgements:
		var before: Dictionary = _stat_xp_now()
		var health: float = BodyRefiningManager.pay_rep(_drill, judgement.tier, _result)
		var stat_xp: Dictionary = {}
		for stat: AttributeType in before:
			stat_xp[stat] = _result.get_stat_xp(stat) - before[stat]
		_beads[judgement.rep].set_frame(BEAD_FRAMES[judgement.tier])
		_stage.show_judgement(judgement)
		_pop(judgement, health, stat_xp)
		rep_judged.emit(judgement, health, stat_xp)
		if not _set_running:
			return

## The XP each stat the drill trains has taken this set so far.
func _stat_xp_now() -> Dictionary:
	var xp: Dictionary = {AttributeType.STRENGTH: _result.get_stat_xp(AttributeType.STRENGTH)}
	if _drill.has_minor_stat():
		xp[_drill.minor_stat as AttributeType] = _result.get_stat_xp(_drill.minor_stat as AttributeType)
	return xp

## The run is over: the set is counted and reported.
func _finish() -> void:
	_set_running = false
	_stage.show_rest()
	BodyRefiningManager.finish_set(_result)
	set_completed.emit(_result)

#-----------------------------------------------------------------------------
# DRAWING
#-----------------------------------------------------------------------------

## Pops the rep's tier where the stage says, in its colour, and under it a Miss's
## reason, or what a scored rep could not pay; hides the line when there is none.
func _pop(judgement: DrillRun.Judgement, health: float, stat_xp: Dictionary) -> void:
	_word_at = _stage.position + _stage.get_floater_anchor(judgement)
	_word_floater.pop(TIER_WORDS[judgement.tier], _tier_color(judgement.tier))
	if judgement.tier == Tier.MISS:
		_line_floater.pop(MISS_REASONS[judgement.miss], ThemeConstants.LACQUER_HEALTH)
	else:
		var parts: Array = _unpaid_parts(health, stat_xp)
		if parts.is_empty():
			_line_floater.stop()
		else:
			_line_floater.pop_parts(parts, ThemeConstants.LACQUER_TAN)
	_place_floaters()

## What a scored rep could not pay: Strength's icon with "capped" when Strength
## took none of its XP, the Health heart with "full" when it restored no Health.
func _unpaid_parts(health: float, stat_xp: Dictionary) -> Array:
	var parts: Array = []
	if stat_xp.get(AttributeType.STRENGTH, 0.0) <= 0.0:
		parts.append_array([StatDisplay.mini_icon_of(AttributeType.STRENGTH), CAPPED_TEXT])
	if health <= 0.0:
		if not parts.is_empty():
			parts.append(PART_GAP)
		parts.append_array([HEALTH_ICON, FULL_TEXT])
	return parts

## Stands each floater that shows on its spot, raised by its rise.
func _place_floaters() -> void:
	if _word_floater.visible:
		_word_floater.position = _word_at - Vector2(0, _word_floater.get_rise())
	if _line_floater.visible:
		_line_floater.position = _word_at + Vector2(0, LINE_DROP - _line_floater.get_rise())

static func _tier_color(tier: Tier) -> Color:
	match tier:
		Tier.PERFECT:
			return ThemeConstants.LACQUER_BRASS
		Tier.GOOD:
			return ThemeConstants.LACQUER_CREAM
		Tier.OK:
			return ThemeConstants.LACQUER_TAN
	return ThemeConstants.LACQUER_HEALTH

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## The play runs only while it shows; hiding it drops a set in progress.
func _on_visibility_changed() -> void:
	var showing: bool = is_visible_in_tree()
	set_process(showing)
	if not showing:
		stop_set()
