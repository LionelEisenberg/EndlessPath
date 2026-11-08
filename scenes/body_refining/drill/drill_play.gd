class_name DrillPlay
extends Control

## DrillPlay
## The drill being played on the body refining board: the scene of the drill's
## input (a DrillStage under Stages, one for each input kind, the drill's alone
## showing), ten rep beads under it, a brass ring on the rep the player is on, the
## beads' brass frame, and the floater a rep's bead pops on. The drill's run
## (DrillRun.for_drill()) judges, the stage draws, and this plays the set.
##
## A set is ten reps at the player's own pace (#143): no clock runs. The first
## press of the drill's input (drill_press: Space or the left mouse button) starts
## a set at that moment on clock_usec, and is its first rep's input: a lift, a
## sink, a shake of the branch, a surge sent down. Each press is judged on the
## clock as it arrives, aimed where it was made (a mouse press's point, else the
## pointer's), and each frame judges what the passing of time decided, which is
## only ever a rep's own motion (a stone dropping at the top, a stance lost, a leaf
## landing, a surge crashing through). Each judged rep restores its Health at once
## through BodyRefiningManager.pay_rep() and stores its XP on the set's result, a
## MISS included (it earns nothing), and the result notes the bead it lit. Its bead
## lights in its tier's look, and the same bead pops where the stage says, at its
## own 24 px on a token (#149): Perfect brass, Good cream, OK tan, Miss crossed in
## crimson. No word pops: a Miss's reason is the stage's to show (the stone's red
## stop line, the needle out of the arc, the leaf on the ground, the surge through
## the line), and what a rep could not pay is the pay line's and the Last set
## card's. Then rep_judged reports the rep, the Health it restored and the XP each
## stat stored, for the board's pellets, which leave from get_pellet_origin(), and,
## at the set's end, from each bead (get_bead_origin()). Every timed effect reads clock_usec.
##
## While a set runs it keeps BodyRefiningManager's set session up to date for the
## Now strip (the rep the player is on and the rep in play's motion), and the ring
## stands on the first bead not lit. Once the run is over the set ends: its XP is
## paid and it is counted (finish_set()), the beads' frame flashes twice, and
## set_completed is emitted; the next press starts another set, with its beads
## empty. The hold belongs to the kind of input that started it, key or mouse
## button: only that kind coming up lets it go, a key repeat is no press, and a
## focus loss always lets go: the window's, which every build sends (the Web build
## sends no other), or the application's. stop_set() drops a set in progress,
## paying its stored XP and counting nothing, and so do hiding the stage and
## readying a drill. Closing the window mid-set pays the stored XP and saves again,
## since the save on quit comes first.
##
## Auto (#110): with set_auto_play() on and the drill's Auto unlocked
## (is_auto_running()), the play starts a set by itself whenever none runs and
## Auto's pace allows (a set no sooner than DrillRun.get_auto_set_usec() after the
## last one's start), and the run plays it (DrillRun.play_auto()). Each rep it
## judges is paid as an AUTO rep: its bead lights Perfect's frame dimmed, and pops
## so. A press while Auto runs plays nothing. Turning Auto on or off drops a set in
## progress, and the next starts at once.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## The first press started a set.
signal set_started
## A rep was judged and paid: the Health it restored and the XP each stat stored
## for the set's end (AttributeType to float), for the board's pellets.
signal rep_judged(judgement: DrillRun.Judgement, health: float, stat_xp: Dictionary)
## A set was played to its last rep: its XP is paid and it is counted.
signal set_completed(result: DrillSetResult)

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const Tier = DrillRules.Tier
const Miss = DrillRun.Miss
const AttributeType = CharacterAttributesData.AttributeType

## The drill's input.
const PRESS_ACTION: StringName = &"drill_press"

## The beads' strip, a frame each: the empty socket, then each tier's bead.
const BEAD_STRIP: Texture2D = preload("res://assets/ui/lacquer/body_refining/lacquer_drill_beads_ai.png")
const BEAD_SIZE: Vector2 = Vector2(24, 24)
## The bead strip's frame for each tier; frame 0 is the empty socket.
const EMPTY_BEAD: int = 0
## An Auto rep lights Perfect's frame, dimmed by AUTO_BEAD_TINT.
const BEAD_FRAMES: Dictionary = {Tier.PERFECT: 1, Tier.GOOD: 2, Tier.OK: 3, Tier.MISS: 4, Tier.AUTO: 1}
const AUTO_BEAD_TINT: Color = Color(0.62, 0.62, 0.62, 1.0)
## The ring stands this far up and left of the bead it marks, around it.
const MARK_OFFSET: Vector2 = Vector2(-2, -2)
## How many times the beads' frame flashes as a set ends.
const SET_FLASH_TIMES: int = 2

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _stages_box: Control = %Stages
@onready var _beads_box: HBoxContainer = %Beads
@onready var _bead_mark: TextureRect = %BeadMark
@onready var _set_frame: LacquerFrameOverlay = %SetFrame
@onready var _rep_floater: LacquerFloater = %RepFloater

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
## Where the rep's bead popped, before its rise.
var _pop_at: Vector2 = Vector2.ZERO
var _beads: Array[LacquerStripRect] = []
## Whether each bead is lit in the set running or last run.
var _lit: Array[bool] = []
## Whether Auto is on (the board's toggle), and whether Auto plays the set running
## or last run.
var _auto_play: bool = false
var _auto_set: bool = false
## When Auto's pace lets its next set start, on clock_usec: 0 when it may start at
## once.
var _auto_ready_usec: int = 0

## Each bead frame's texture, for the pop and the Last set card: frame to
## AtlasTexture, made once.
static var _bead_textures: Dictionary = {}

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	for child: Node in _beads_box.get_children():
		_beads.append(child as LacquerStripRect)
		_lit.append(false)
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
	if not _set_running and is_auto_running() and clock_usec.call() >= _auto_ready_usec:
		_start_set(true)
	if _set_running:
		var t: int = _set_time()
		_apply(_run.play_auto(t) if _auto_set else _run.advance(t))
		if _set_running:
			_stage.show_run(_run, t)
			BodyRefiningManager.update_set_session(mini(_run.get_judged_count() + 1, _drill.reps_per_set), _run.rep_progress_at(t))
			var end_usec: int = _run.get_end_usec()
			if end_usec >= 0 and t >= end_usec:
				_finish()
	_place_mark()
	_place_floater()

func _notification(what: int) -> void:
	var focus_lost: bool = what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT
	if focus_lost and _holding:
		_let_go()
	# The save on quit runs first (PersistenceManager is an earlier autoload), so a
	# set's stored XP is paid here and saved again.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _set_running:
		BodyRefiningManager.pay_stored_xp(_result)
		PersistenceManager.autosave()

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
	_empty_beads()

## Takes an event of the drill's input and returns true for each one of them,
## false for any other event. A press starts a set when none runs, and plays; a
## release lets go when it comes from the kind of input that holds; a key repeat
## does nothing, and while Auto runs nothing does. Each is judged on clock_usec as
## it arrives.
func handle_press_event(event: InputEvent) -> bool:
	if not event.is_action(PRESS_ACTION):
		return false
	var key := event as InputEventKey
	if (key != null and key.echo) or is_auto_running():
		return true
	if event.is_action_pressed(PRESS_ACTION):
		_on_press(event)
	elif event.is_action_released(PRESS_ACTION):
		_on_release(event)
	return true

## Drops a set in progress: its reps' Health stays, the XP they stored is paid,
## and it is neither counted nor reported. A set whose last rep has landed, its
## piece still coming back to rest, is finished instead: paid, counted and
## reported. The session ends, the hold is let go, the floater and the ring hide
## and the stage goes back to rest. The beads keep what they showed. Auto's next
## set may start at once.
func stop_set() -> void:
	if _set_running and _result.is_complete():
		_finish()
	elif _set_running:
		_set_running = false
		BodyRefiningManager.pay_stored_xp(_result)
		BodyRefiningManager.end_set_session()
	_holding = false
	_auto_ready_usec = 0
	if is_node_ready():
		_rep_floater.stop()
		_bead_mark.hide()
		if _stage != null:
			_stage.show_rest()

## Returns whether a set is being played.
func is_set_running() -> bool:
	return _set_running

## Turns Auto on or off (the board's toggle). A change drops a set in progress,
## which keeps its paid reps and is neither counted nor reported. On, the play
## runs Auto only while the drill's Auto is unlocked.
func set_auto_play(on: bool) -> void:
	if on == _auto_play:
		return
	_auto_play = on
	stop_set()

## Returns whether Auto is on, whatever the drill's unlock.
func is_auto_play() -> bool:
	return _auto_play

## Returns whether Auto plays the drill: it is on and the drill's Auto is
## unlocked. The play checks the unlock itself, so a locked drill never plays
## unattended.
func is_auto_running() -> bool:
	return _auto_play and _drill != null and BodyRefiningManager.is_auto_unlocked(_drill.id)

## Returns whether Auto plays the set running, or played the last one.
func is_auto_set() -> bool:
	return _auto_set

## Returns the set being played, or the last one played, or null before the first.
func get_result() -> DrillSetResult:
	return _result

## Returns the run of the set being played or last played, or null before the first.
func get_run() -> DrillRun:
	return _run

## Returns the stage showing, the drill's input's, or null before a drill is readied.
func get_stage() -> DrillStage:
	return _stage

## Returns the bead a rep of `tier` lights, at 24 px: the pop's icon and the Last
## set card's beads. An AUTO rep's is Perfect's, which is dimmed by
## AUTO_BEAD_TINT where it shows.
static func bead_icon(tier: Tier) -> Texture2D:
	return bead_frame_texture(BEAD_FRAMES[tier])

## Returns the bead strip's frame `frame` as a texture (EMPTY_BEAD: the socket).
static func bead_frame_texture(frame: int) -> Texture2D:
	if not _bead_textures.has(frame):
		var atlas := AtlasTexture.new()
		atlas.atlas = BEAD_STRIP
		atlas.region = Rect2(Vector2(BEAD_SIZE.x * frame, 0.0), BEAD_SIZE)
		_bead_textures[frame] = atlas
	return _bead_textures[frame]

## Returns where a judged rep's pellets leave from, in the screen's space.
func get_pellet_origin(judgement: DrillRun.Judgement) -> Vector2:
	return _stage.get_global_transform() * _stage.get_pellet_origin(judgement)

## Returns bead `rep`'s middle, in the screen's space: where the XP a rep stored
## leaves from when its set ends.
func get_bead_origin(rep: int) -> Vector2:
	var bead: LacquerStripRect = _beads[rep]
	return bead.get_global_transform() * (bead.size / 2.0)

#-----------------------------------------------------------------------------
# INPUT
#-----------------------------------------------------------------------------

func _on_press(event: InputEvent) -> void:
	if _drill == null or _holding:
		return
	_holding = true
	_hold_by_mouse = event is InputEventMouseButton
	if not _set_running:
		_start_set()
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

## Shows the stage of the drill's input at rest and hides the others.
func _show_stage() -> void:
	_stage = null
	if _drill != null:
		_stage = _stages.get(_drill.input_kind)
	for stage: DrillStage in _stages.values():
		stage.visible = stage == _stage
	if _stage != null:
		_stage.setup(_drill)
		_stage.show_rest()

## Starts a set now, played by Auto when `auto`: a new run and result, the beads
## empty and the floater hidden, and the session running.
func _start_set(auto: bool = false) -> void:
	_start_usec = clock_usec.call()
	_run = run_for.call(_drill, _start_usec)
	_result = DrillSetResult.new(_drill)
	_set_running = true
	_auto_set = auto
	_empty_beads()
	_rep_floater.stop()
	BodyRefiningManager.start_set_session(_drill.reps_per_set)
	set_started.emit()

## The set's time now, in microseconds from its first press.
func _set_time() -> int:
	return clock_usec.call() - _start_usec

## Pays and shows each judged rep, in order: as an AUTO rep in a set Auto plays. A
## listener of rep_judged can stop the action, and the stop drops the set: nothing
## more is shown after that.
func _apply(judgements: Array[DrillRun.Judgement]) -> void:
	for judgement: DrillRun.Judgement in judgements:
		if _auto_set:
			judgement.tier = Tier.AUTO
			judgement.miss = Miss.NONE
		var before: Dictionary = _stored_xp_now()
		var health: float = BodyRefiningManager.pay_rep(_drill, judgement.tier, _result)
		_result.place_last_rep(judgement.rep)
		var stat_xp: Dictionary = {}
		for stat: AttributeType in before:
			stat_xp[stat] = _result.get_stored_stat_xp(stat) - before[stat]
		_beads[judgement.rep].set_frame(BEAD_FRAMES[judgement.tier])
		_beads[judgement.rep].self_modulate = AUTO_BEAD_TINT if judgement.tier == Tier.AUTO else Color.WHITE
		_lit[judgement.rep] = true
		_stage.show_judgement(judgement)
		_pop(judgement)
		rep_judged.emit(judgement, health, stat_xp)
		if not _set_running:
			return

## The XP each stat the drill trains has stored this set so far. An Auto set trains
## Strength alone, so it reports no XP for the other stat.
func _stored_xp_now() -> Dictionary:
	var xp: Dictionary = {AttributeType.STRENGTH: _result.get_stored_stat_xp(AttributeType.STRENGTH)}
	if _drill.has_minor_stat() and not _auto_set:
		xp[_drill.minor_stat as AttributeType] = _result.get_stored_stat_xp(_drill.minor_stat as AttributeType)
	return xp

## Empties every bead.
func _empty_beads() -> void:
	for index: int in _beads.size():
		_beads[index].set_frame(EMPTY_BEAD)
		_beads[index].self_modulate = Color.WHITE
		_lit[index] = false

## The run is over: the set's XP is paid and it is counted, the beads' frame
## flashes, and the set is reported. After an Auto set, Auto's next waits for its
## pace.
func _finish() -> void:
	_set_running = false
	_stage.show_rest()
	_bead_mark.hide()
	BodyRefiningManager.finish_set(_result)
	_set_frame.flash(SET_FLASH_TIMES)
	if _auto_set:
		_auto_ready_usec = _start_usec + _run.get_auto_set_usec()
	set_completed.emit(_result)

## Stands the ring on the rep the player is on, the first bead not lit, while a
## set runs; hides it otherwise.
func _place_mark() -> void:
	var index: int = _lit.find(false) if _set_running else -1
	_bead_mark.visible = index >= 0
	if index >= 0:
		_bead_mark.position = _beads_box.position + _beads[index].position + MARK_OFFSET

#-----------------------------------------------------------------------------
# DRAWING
#-----------------------------------------------------------------------------

## Pops the bead the rep lit where the stage says: dimmed for an Auto rep.
func _pop(judgement: DrillRun.Judgement) -> void:
	_pop_at = _stage.position + _stage.get_floater_anchor(judgement)
	_rep_floater.pop_icon(bead_icon(judgement.tier), AUTO_BEAD_TINT if judgement.tier == Tier.AUTO else Color.WHITE)
	_place_floater()

## Stands the floater on its spot while it shows, raised by its rise, moved left as
## far as it needs to stay on the play.
func _place_floater() -> void:
	if not _rep_floater.visible:
		return
	var x: float = minf(_pop_at.x, size.x - _rep_floater.get_token_width())
	_rep_floater.position = Vector2(x, _pop_at.y - _rep_floater.get_rise())

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## The play runs only while it shows; hiding it drops a set in progress.
func _on_visibility_changed() -> void:
	var showing: bool = is_visible_in_tree()
	set_process(showing)
	if not showing:
		stop_set()
