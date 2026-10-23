class_name CyclingTechnique
extends Node2D

## CyclingTechnique
## The play of one cycling technique. The Madra ball travels the technique's path
## once per cycle, easing in and out with a sine, and the carved groove lights
## behind it. While the cursor is inside the ball it draws Madra, one step every
## MADRA_PARTICLE_INTERVAL. The zones along the path turn active as the ball
## reaches them. The ball is the only thing the player presses: from ready a press
## starts a cycle, and during one a press while the ball is over an active zone
## scores that zone by how near the ball's centre is to the zone's (see
## CyclingRules).
## Everything steps: the ball is drawn at its path position snapped to even px,
## its swirl steps through SWIRL_FRAMES frames at SWIRL_FPS, and a zone shows its
## state as a frame. advance() moves the play on by one frame. _process() feeds it
## the mouse, and tests feed it a chosen cursor.
## The ball has two positions. The drawn one, snapped to the 2 px grid, is what
## the player sees, so tracking, the ring and the pellets use it. The true one,
## the PathFollow2D's, is where the ball is on the path, so which zones it
## overlaps and how near a click was use it, and the groove lights to its
## travelled length (_follow.progress).
## While a cycle runs the technique writes CyclingManager's session snapshot, for
## the cabinet and the Now tray to read. The session belongs to the technique that
## started it: only that technique ends it, when its cycle ends, is stopped or cut
## off by a switch, or when it leaves the tree mid-cycle.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted when a cycle starts.
signal cycling_started
## Emitted when a cycle runs to its end, with what it came to. A cycle that is
## stopped, or cut off by switching technique, emits nothing.
signal cycle_completed(result: CycleResult)
## Emitted each time the cursor draws a step of Madra, with the drawn ball's
## global centre, for the view to fly a pellet from.
signal madra_particle_requested(from_pos: Vector2)
## Emitted when a press scores a zone, with how well and the Core Density XP the
## zone paid.
signal zone_scored(zone: CyclingZone, tier: CyclingRules.Tier, xp: int)

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The ball's radius in px: how near the cursor must be to draw Madra, and the
## radius of the ball's click area.
const BALL_RADIUS: float = 29.5

## Seconds between two steps of Madra while the cursor follows the ball.
const MADRA_PARTICLE_INTERVAL: float = 0.08

## How far short of MADRA_PARTICLE_INTERVAL the Madra timer may be and still pay
## its step. It absorbs float error: an 8 s cycle holds exactly 100 steps, so its
## last step falls on the cycle's last instant, and the frames' sum can miss it
## by a hair at some frame rates.
const _STEP_EPSILON: float = 0.000001

## The frames of the ball's swirl, and how many of them play each second.
const SWIRL_FRAMES: int = 8
const SWIRL_FPS: float = 10.0

## The seconds of cycle time the Madra rate is measured over: the Madra the cursor
## drew in the newest frames that cover this long, over the time they cover.
const RATE_WINDOW: float = 1.0

## The ball ring's frames: the steady ring around a ready ball, and the dotted
## ring while the cursor follows it.
const _RING_READY: int = 0
const _RING_TRACKING: int = 1

const _ZONE_SCENE: PackedScene = preload("res://scenes/cycling/cycling_technique/cycling_zone.tscn")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _groove: CyclingGroove = %CyclingGroove
@onready var _path: Path2D = %CyclingPath2D
@onready var _follow: PathFollow2D = %PathFollow2D
@onready var _ball: Area2D = %MadraBall
@onready var _ball_ring: LacquerStripRect = %BallRing
@onready var _ball_sprite: LacquerStripRect = %BallSprite

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The technique to set up when the scene loads. Left empty, whoever owns the
## node calls setup().
@export var technique_data_input: CyclingTechniqueData = null

## When on, the next cycle starts as soon as one ends.
var auto_cycle: bool = false

## The technique being played. Null until setup() is given one.
var technique_data: CyclingTechniqueData = null

## The technique's zones, in the order of its data.
var cycling_zones: Array[CyclingZone] = []

var _cycling: bool = false
var _tracking: bool = false
## Seconds into the running cycle.
var _elapsed: float = 0.0
## Seconds the swirl has run. It runs whether or not a cycle does.
var _swirl_clock: float = 0.0
## Seconds toward the next Madra step. It keeps its remainder between steps.
var _madra_timer: float = 0.0
## The frames the Madra rate is measured over, oldest first: the newest frames that
## cover RATE_WINDOW seconds of the cycle. x is the frame's seconds and y the Madra
## the cursor drew in it: the technique's Madra per second times those seconds while
## the cursor followed the ball with room under the cap, otherwise 0. It carries into
## an auto cycle and is empty after any other ending.
var _rate_window: Array[Vector2] = []
## The ball's centre as the player sees it: the true one snapped to even px.
var _ball_drawn: Vector2 = Vector2.ZERO
var _result: CycleResult = CycleResult.new()

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_ball.input_event.connect(_on_ball_input_event)
	setup(technique_data_input)

func _process(delta: float) -> void:
	advance(delta, get_global_mouse_position())

## A technique that leaves the tree mid-cycle ends its session, so the snapshot
## never outlives the technique that writes it.
func _exit_tree() -> void:
	if _cycling:
		CyclingManager.end_cycle_session()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Sets the technique up: its path, its groove and its zones, all ready. A cycle
## that runs ends without a result. A null technique leaves nothing to play.
func setup(data: CyclingTechniqueData) -> void:
	technique_data = data
	var curve: Curve2D = data.path_curve if data != null else null
	_path.curve = curve if curve != null else Curve2D.new()
	_groove.setup(curve)
	_build_zones()
	_return_to_ready()

## Starts a cycle, from ready only. Every zone goes back to IDLE (clearing the
## last cycle's studs) and the groove goes dark. Returns whether a cycle started.
func start_cycle() -> bool:
	if _cycling or technique_data == null:
		return false
	_cycling = true
	_elapsed = 0.0
	_madra_timer = 0.0
	_result = _new_result()
	for zone: CyclingZone in cycling_zones:
		zone.set_state(CyclingZone.State.IDLE)
	_groove.set_lit_length(-1.0)
	_ball_ring.visible = false
	CyclingManager.start_cycle_session(technique_data.cycle_duration)
	cycling_started.emit()
	return true

## Ends a running cycle without a result and puts everything back to ready: the
## zones IDLE, the groove dark, the ball at the start of the path and the cycle's
## session over. It does this after a finished cycle too, which clears its studs.
func stop_cycling() -> void:
	_return_to_ready()

## Moves the play on by `delta` seconds, with the cursor at `cursor_global`.
## While no cycle runs only the swirl moves and the ball waits at the start. While
## one runs, in this order: the ball moves and is drawn, the cursor draws Madra if
## it is on the ball, the zones turn active or spent, the groove lights, the frame
## joins the rate window and the session is updated. The cycle ends once its time
## is up. A frame that runs past the end counts only the time left in the cycle,
## so a long hitch draws no Madra beyond it.
func advance(delta: float, cursor_global: Vector2) -> void:
	_swirl_clock += delta
	_show_swirl_frame()
	if not _cycling:
		_show_ready()
		return
	var duration: float = technique_data.cycle_duration
	var cycle_delta: float = minf(delta, duration - _elapsed)
	_elapsed = minf(_elapsed + delta, duration)
	_follow.progress_ratio = _eased_ratio()
	_draw_ball()
	_tracking = cursor_global.distance_to(_ball_drawn) <= BALL_RADIUS
	_ball_ring.visible = _tracking
	# Whether the frame draws is judged before its steps can fill the cap.
	var drawing: bool = _tracking and not _madra_full()
	if _tracking:
		_set_ring_frame(_RING_TRACKING)
		_draw_madra(cycle_delta)
	_update_zones()
	_groove.set_lit_length(_follow.progress)
	_record_rate(cycle_delta, drawing)
	_update_session()
	if _elapsed >= duration:
		_finish_cycle()

## The player pressed the ball. From ready it starts a cycle. During one it scores
## the ACTIVE zone nearest the true ball, if any. Returns whether the press did
## either.
func press_ball() -> bool:
	if not _cycling:
		return start_cycle()
	var zone: CyclingZone = _active_zone()
	return zone != null and try_score_zone(zone)

## Scores `zone`, which succeeds only while a cycle runs and the zone is ACTIVE.
## The tier comes from how far the true ball is from the zone's centre. The XP
## goes to Core Density, the zone takes its stud and zone_scored is emitted.
## Returns whether it scored.
func try_score_zone(zone: CyclingZone) -> bool:
	if not _cycling or not cycling_zones.has(zone) or zone.get_state() != CyclingZone.State.ACTIVE:
		return false
	var distance: float = _follow.global_position.distance_to(zone.global_position)
	var tier: CyclingRules.Tier = CyclingRules.tier_for_distance(distance)
	var xp: int = CyclingRules.xp_for_tier(zone.zone_data, tier)
	CultivationManager.add_core_density_xp(xp)
	_result.zones_scored += 1
	_result.xp += xp
	if tier == CyclingRules.Tier.PERFECT:
		_result.perfect_count += 1
	zone.set_state(CyclingZone.state_for_tier(tier))
	zone_scored.emit(zone, tier, xp)
	return true

## Returns whether a press at `cursor_global` would do something: the cursor is on
## the ball, and either no cycle runs (the press starts one) or a zone is ACTIVE
## (the press scores it). The view shows the pointer cursor then.
func wants_pointer(cursor_global: Vector2) -> bool:
	if technique_data == null or cursor_global.distance_to(_ball_drawn) > BALL_RADIUS:
		return false
	return not _cycling or _active_zone() != null

## Returns true while a cycle runs.
func is_cycling() -> bool:
	return _cycling

## Returns true while a cycle runs and the cursor is on the ball.
func is_tracking() -> bool:
	return _tracking

## Returns the ball's drawn centre in global coordinates, on even px. It is the
## start of the path while no cycle runs.
func get_ball_global_position() -> Vector2:
	return _ball_drawn

## Returns what the cycle has come to: the running cycle's result so far, or the
## last finished cycle's until the technique goes back to ready.
func get_current_result() -> CycleResult:
	return _result

#-----------------------------------------------------------------------------
# CYCLE
#-----------------------------------------------------------------------------

## Returns the ball's share of the path at the elapsed time: a sine ease in and
## out, 0 at the start and 1 once the cycle's time is up.
func _eased_ratio() -> float:
	var duration: float = technique_data.cycle_duration
	var fraction: float = 1.0 if duration <= 0.0 else minf(_elapsed / duration, 1.0)
	return 0.5 - 0.5 * cos(PI * fraction)

## Adds the Madra the cursor draws in `delta` seconds: a step for every
## MADRA_PARTICLE_INTERVAL the timer has gathered, to within _STEP_EPSILON. The
## timer keeps the remainder, which a step paid a hair early leaves just below 0.
func _draw_madra(delta: float) -> void:
	_madra_timer += delta
	while _madra_timer >= MADRA_PARTICLE_INTERVAL - _STEP_EPSILON:
		_madra_timer -= MADRA_PARTICLE_INTERVAL
		_draw_madra_step()

## Returns true when Madra is at or over the cap, so the cursor adds nothing.
func _madra_full() -> bool:
	return ResourceManager.get_madra() >= CultivationManager.get_max_madra()

## Draws one step of Madra. Nothing is added or requested at the cap, and Madra
## already over it is left alone. The step counts only for the Madra it really
## added, which is less than a full step when the cap cuts it short.
func _draw_madra_step() -> void:
	if _madra_full():
		return
	var before: float = ResourceManager.get_madra()
	if ResourceManager.add_madra(_madra_per_step(), true) <= 0.0:
		return
	# What the pool gained, not add_madra()'s figure: that is snapped to 0.001,
	# and the snaps add up (Smooth Flow's 187 steps sum to 199.53 for the 199.47
	# they add, which the result line would round to +200).
	_result.madra_added += ResourceManager.get_madra() - before
	madra_particle_requested.emit(_ball_drawn)

## Returns the Madra one step adds: the technique's Madra per cycle spread over
## the steps of a cycle.
func _madra_per_step() -> float:
	if technique_data.cycle_duration <= 0.0:
		return 0.0
	return technique_data.base_madra_per_cycle * MADRA_PARTICLE_INTERVAL / technique_data.cycle_duration

## Returns the ACTIVE zone nearest the true ball, or null when none is active.
func _active_zone() -> CyclingZone:
	var nearest: CyclingZone = null
	var nearest_distance: float = INF
	for zone: CyclingZone in cycling_zones:
		if zone.get_state() != CyclingZone.State.ACTIVE:
			continue
		var distance: float = _follow.global_position.distance_to(zone.global_position)
		if distance < nearest_distance:
			nearest = zone
			nearest_distance = distance
	return nearest

## Turns each open zone ACTIVE while the true ball is within reach of it (the
## ball's radius and the zone's, centres 49.5 px apart), and SPENT when an active
## one is left behind unscored. A zone the ball has not reached stays IDLE.
func _update_zones() -> void:
	var reach: float = BALL_RADIUS + CyclingRules.ZONE_RADIUS
	var ball: Vector2 = _follow.global_position
	for zone: CyclingZone in cycling_zones:
		if not zone.is_open():
			continue
		if ball.distance_to(zone.global_position) <= reach:
			zone.set_state(CyclingZone.State.ACTIVE)
		elif zone.get_state() == CyclingZone.State.ACTIVE:
			zone.set_state(CyclingZone.State.SPENT)

## Adds a running frame to the rate window: its `delta` seconds and the Madra the
## cursor drew in it, which is the technique's Madra per second over those seconds
## when `drawing`, else 0. Then drops the oldest frames while the rest still cover
## RATE_WINDOW, which leaves the shortest run of the newest frames that does.
func _record_rate(delta: float, drawing: bool) -> void:
	var drawn: float = (_madra_per_step() / MADRA_PARTICLE_INTERVAL * delta) if drawing else 0.0
	_rate_window.append(Vector2(delta, drawn))
	var covered: float = 0.0
	for frame: Vector2 in _rate_window:
		covered += frame.x
	while not _rate_window.is_empty() and covered - _rate_window[0].x >= RATE_WINDOW:
		covered -= _rate_window[0].x
		_rate_window.pop_front()

## Writes the session snapshot: the time elapsed and the Madra rate, which is the
## Madra drawn over the rate window divided by the time it covers (0 with nothing
## in it). Steady tracking with room under the cap reads the technique's Madra per
## second, base_madra_per_cycle / cycle_duration, at any frame rate. Within
## RATE_WINDOW seconds of the cursor starting or stopping, or of the cap being
## met, the rate rises to that or falls to 0.
func _update_session() -> void:
	var covered: float = 0.0
	var drawn: float = 0.0
	for frame: Vector2 in _rate_window:
		covered += frame.x
		drawn += frame.y
	CyclingManager.update_cycle_session(_elapsed, drawn / covered if covered > 0.0 else 0.0)

## Ends the cycle that has run its time: every zone still open is spent, the
## session ends, the ball goes back to the start and cycle_completed carries the
## result. The groove stays lit until the next cycle starts. With auto_cycle on,
## the next cycle starts at once and the rate window carries into it: the session
## is updated again in the same frame, so the rate does not read 0 for a frame
## between two cycles. Otherwise the window is emptied.
func _finish_cycle() -> void:
	for zone: CyclingZone in cycling_zones:
		if zone.is_open():
			zone.set_state(CyclingZone.State.SPENT)
	_cycling = false
	_tracking = false
	CyclingManager.end_cycle_session()
	_show_ready()
	cycle_completed.emit(_result)
	if auto_cycle:
		start_cycle()
		_update_session()
	else:
		_rate_window.clear()

## Ends any cycle without a result and puts the play back to ready: no time, no
## Madra gathered, a fresh empty result, the zones IDLE, the groove dark and the
## ball waiting at the start of the path. The session ends only if this technique
## was cycling: a session another technique started is left running.
func _return_to_ready() -> void:
	var was_cycling: bool = _cycling
	_cycling = false
	_tracking = false
	_elapsed = 0.0
	_madra_timer = 0.0
	_rate_window.clear()
	_result = _new_result()
	if was_cycling:
		CyclingManager.end_cycle_session()
	for zone: CyclingZone in cycling_zones:
		zone.set_state(CyclingZone.State.IDLE)
	_groove.set_lit_length(-1.0)
	_show_ready()

## Returns an empty result for a cycle of this technique.
func _new_result() -> CycleResult:
	var result: CycleResult = CycleResult.new()
	result.zones_total = cycling_zones.size()
	return result

## Replaces the zones with one for each zone of the technique, IDLE and in place
## under the path. The old zones leave the tree at once, so nothing of them can
## score and their names are free.
func _build_zones() -> void:
	for zone: CyclingZone in cycling_zones:
		_path.remove_child(zone)
		zone.queue_free()
	cycling_zones.clear()
	if technique_data == null:
		return
	for index: int in technique_data.cycling_zones.size():
		var data: CyclingZoneData = technique_data.cycling_zones[index]
		var zone: CyclingZone = _ZONE_SCENE.instantiate() as CyclingZone
		zone.name = "CyclingZone%d" % (index + 1)
		_path.add_child(zone)
		zone.setup(data)
		zone.position = data.position
		cycling_zones.append(zone)

#-----------------------------------------------------------------------------
# THE BALL ON SCREEN
#-----------------------------------------------------------------------------

## Returns `point` with each coordinate rounded to the nearest even px.
static func _snap_even(point: Vector2) -> Vector2:
	return (point / 2.0).round() * 2.0

## Draws the ball and its ring centred on the true ball's position snapped to even
## px, and remembers that centre as the drawn ball.
func _draw_ball() -> void:
	_ball_drawn = _snap_even(_follow.global_position)
	_ball_sprite.global_position = _ball_drawn - Vector2(_ball_sprite.frame_size) / 2.0
	_ball_ring.global_position = _ball_drawn - Vector2(_ball_ring.frame_size) / 2.0

## Shows the ball at the start of the path inside its steady ring.
func _show_ready() -> void:
	if _follow.progress != 0.0:
		_follow.progress = 0.0
	_draw_ball()
	_ball_ring.visible = true
	_set_ring_frame(_RING_READY)

## Shows the swirl frame for the swirl clock.
func _show_swirl_frame() -> void:
	var frame: int = floori(_swirl_clock * SWIRL_FPS) % SWIRL_FRAMES
	if _ball_sprite.get_frame().x != frame:
		_ball_sprite.set_frame(frame)

func _set_ring_frame(frame: int) -> void:
	if _ball_ring.get_frame().x != frame:
		_ball_ring.set_frame(frame)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_ball_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		press_ball()
