class_name CyclingTechnique
extends Node2D

## CyclingTechnique
## The play of one cycling technique. The Madra ball travels the technique's path
## once per cycle, easing in and out with a sine, and the carved groove lights
## behind it. While the cursor follows the ball it draws Madra, one step every
## MADRA_PARTICLE_INTERVAL. Following is being in the gold ring around the ball,
## out to its edge (CURSOR_REACH), once it has started: the press that starts a
## cycle starts it, and so does a cursor moving in the ring
## (CyclingRules.is_following(), over a FollowWindow). A cursor resting on the
## path never starts, so it follows nothing as the ball passes. With Auto a
## streak carries from one cycle into the next.
## Auto chains cycles. Once the technique's Auto is unlocked (a perfect cycle,
## CycleResult.is_perfect()), an Auto cycle that nobody follows still pays, at
## CyclingRules.AUTO_RATE of the full rate for Madra and Spirit alike, and its
## ball moves at an even speed, so chained cycles never slow at their ends.
## Following pays the full rate, Auto or not. Auto plays no zone and no seal.
## Following also trains Spirit: a second clock gathers the time followed, and
## every STAT_XP_INTERVAL of it pays Spirit XP through CharacterManager, the
## technique's spirit_xp_per_cycle over a fully followed cycle, Madra full or not.
## The cycle's end pays what is left, and so does a stop that cuts the cycle
## short. A switch drops it, so no pellet flies from a technique the board has
## left. Each payment that the stat took XP from is announced on stat_xp_paid,
## for the view's pellets.
## The zones along the path turn active as the ball reaches them. The ball is
## the only thing the player presses: from ready a press
## starts a cycle, and during one a press while the ball is over an active zone
## scores that zone by how near the ball's centre is to the zone's (see
## CyclingRules), paying the technique's other stat (Control) its tier's XP.
## Seal nodes sit on the path where the ball reaches each of the technique's
## seal_seconds. CyclingRules.SEAL_LEAD before the ball arrives, a node shows a
## seal of arrows drawn from seal_rng, and press_seal() keys them. As the ball
## arrives an open node bursts, paying the other stat (Mind) seal_xp, and one
## still showing fizzles. A stop or a switch before the ball arrives drops an
## open seal.
## Everything steps: the ball is drawn at its path position snapped to even px,
## its swirl steps through SWIRL_FRAMES frames at SWIRL_FPS, and a zone shows its
## state as a frame. While the ball waits for a press it breathes: it and its
## brass ring step through three sizes and back once every BREATH_SECONDS.
## advance() moves the play on by one frame. _process() feeds it the mouse, and
## tests feed it a chosen cursor.
## Between cycles the groove shows lit, as a full cycle leaves it, so the path
## stands out from the carved figure. A cycle's start sweeps that light away in
## GROOVE_SWEEP_SECONDS, running along the path ahead of the ball, and the ball's
## trail lights the groove again behind it.
## The ball has two positions. The drawn one, snapped to the 2 px grid, is what
## the player sees, so whether the cursor is on the ball, the ring and the pellets
## use it. The true one, the PathFollow2D's, is where the ball is on the path, so
## which zones it overlaps and how near a click was use it, and the groove lights
## to its travelled length (_follow.progress).
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
## global centre, for the view to fly a pellet from, and the Madra the step
## added, which the pellet carries.
signal madra_particle_requested(from_pos: Vector2, amount: float)
## Emitted when a press scores a zone, with how well, the XP of the technique's
## other stat the zone was worth and the XP that stat took: all of it short of
## the cap, less once it reaches the cap, none at the cap or for a technique that
## trains Spirit alone. The XP is in the stat by then.
signal zone_scored(zone: CyclingZone, tier: CyclingRules.Tier, xp: int, taken: float)
## Emitted after a payment of stat XP that the stat took XP from, with the drawn
## ball's global centre, for the view to fly pellets from, and the XP the stat
## took (all of the payment short of the cap, never 0). The XP is in the stat by
## then. A capped stat takes none, and nothing is emitted.
signal stat_xp_paid(stat: CharacterAttributesData.AttributeType, from_pos: Vector2, amount: float)
## Emitted when a seal node shows its seal, SEAL_LEAD before the ball arrives.
signal seal_shown(seal: SealNode)
## Emitted when the ball bursts through an open seal node, after the payment,
## with the XP of the technique's other stat the seal was worth and the XP that
## stat took (none at its cap).
signal seal_burst(seal: SealNode, xp: float, taken: float)
## Emitted when the ball reaches a seal node whose seal was not keyed in time.
signal seal_missed(seal: SealNode)

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The ball's own radius in px (its art reaches 29.8): a zone opens when the
## ball's edge reaches the zone's.
const BALL_RADIUS: float = 29.5

## How far from the drawn ball's centre the cursor counts as on the ball: there
## it can follow the ball, a press lands on the ball, and the hand cursor shows.
## It is the solid following ring's outer edge, so what counts is what the player
## sees. The ball's press area, its CircleShape2D, has the same radius.
const CURSOR_REACH: float = 36.0

## Seconds between two steps of Madra while the cursor follows the ball.
const MADRA_PARTICLE_INTERVAL: float = 0.08

## Seconds of following one payment of Spirit XP covers. A frame that gathers
## several (a hitch) pays them together, so a payment comes once a frame at most.
const STAT_XP_INTERVAL: float = 0.5

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

## The seconds a cycle's start takes to sweep the last cycle's light off the
## groove, at an even pace along the path. The ball eases in, so the sweep runs
## well ahead of it.
const GROOVE_SWEEP_SECONDS: float = 0.5

## The seconds of one breath of the waiting ball: up from 60 px through 64 to
## 68 and back (see breath_level()).
const BREATH_SECONDS: float = 2.0

## The ball ring's frames: the steady ring around a ready ball, and the solid tan
## ring while the cursor follows it.
const _RING_READY: int = 0
const _RING_FOLLOWING: int = 1
## The ready ring's frame for each breath level: it grows with the ball.
const _RING_READY_BY_BREATH: Array[int] = [_RING_READY, 2, 3]

const _ZONE_SCENE: PackedScene = preload("res://scenes/cycling/cycling_technique/cycling_zone.tscn")
const _SEAL_SCENE: PackedScene = preload("res://scenes/cycling/cycling_technique/seal_node.tscn")

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

## How much larger than its data the path is drawn, about path_pivot: its points,
## their handles and the zones all scale, so the play fits a figure drawn larger
## than the footprint the techniques were authored on. The ball, the zones' size
## and the scoring radii do not scale. setup() applies it.
@export var path_scale: float = 1.0

## The point of the technique's space that stays put when path_scale scales the
## path: the figure's top-left corner on the board.
@export var path_pivot: Vector2 = Vector2.ZERO

## When on, the next cycle starts as soon as one ends, and once the technique's
## Auto is unlocked, cycles nobody follows pay at the Auto rate
## (is_auto_running()).
var auto_cycle: bool = false

## The technique being played. Null until setup() is given one.
var technique_data: CyclingTechniqueData = null

## The technique's zones, in the order of its data.
var cycling_zones: Array[CyclingZone] = []

## The technique's seal nodes, in the order of its seal_seconds.
var seal_nodes: Array[SealNode] = []

## Draws each seal's arrows (CyclingRules.random_seal()).
var seal_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _cycling: bool = false
## Whether the cursor follows the ball this frame: the follow window's verdict.
var _following: bool = false
## Whether every frame of the running cycle so far has followed the ball.
var _followed_throughout: bool = false
## Whether the running cycle moves the ball at an even speed: an Auto cycle.
## Decided as the cycle starts, so turning Auto on or off mid-cycle never makes
## the ball jump.
var _flat: bool = false
## The last quarter second of the running cycle, which judges following.
var _follow_window: FollowWindow = FollowWindow.new()
## Seconds the cursor has followed the ball this cycle.
var _followed_seconds: float = 0.0
## Seconds followed that no Spirit payment has covered yet.
var _unpaid_spirit_seconds: float = 0.0
## Seconds into the running cycle.
var _elapsed: float = 0.0
## The path's length in px, which the groove's sweep runs over.
var _path_length: float = 0.0
## Seconds the swirl has run. It runs whether or not a cycle does.
var _swirl_clock: float = 0.0
## Seconds the ball has waited for a press, which set its breath. It starts at 0
## each time the ball comes back to wait.
var _breath_clock: float = 0.0
## Seconds toward the next Madra step. It keeps its remainder between steps.
var _madra_timer: float = 0.0
## Spirit's factor on the Madra a cycle draws, read from the player's total
## stats on ready and again on every stats change, not on every step.
var _madra_multiplier: float = 1.0
## The frames the Madra rate is measured over, oldest first: the newest frames that
## cover RATE_WINDOW seconds of the cycle. x is the frame's seconds and y the Madra
## the cursor drew in it: the technique's Madra per second times those seconds while
## the cursor followed the ball with room under the max, otherwise 0. It carries into
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
	CharacterManager.stats_changed.connect(_on_stats_changed)
	_on_stats_changed()
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

## Sets the technique up: its path scaled by path_scale, its groove and its zones,
## all ready. A cycle that runs ends without a result. A null technique leaves
## nothing to play.
func setup(data: CyclingTechniqueData) -> void:
	# A switch drops the Spirit XP of the half second not yet paid: no pellet
	# flies from a technique the board has left.
	_unpaid_spirit_seconds = 0.0
	technique_data = data
	var curve: Curve2D = _scaled_curve(data.path_curve) if data != null else null
	_path.curve = curve if curve != null else Curve2D.new()
	_path_length = _path.curve.get_baked_length() if _path.curve.point_count > 0 else 0.0
	_groove.setup(curve)
	_build_zones()
	_build_seals()
	_return_to_ready()

## Starts a cycle, from ready only. Every zone goes back to IDLE (clearing the
## last cycle's studs), and the groove keeps the last cycle's light for the
## sweep to clear. The cycle's first frame follows if the cursor is on the ball
## and `starts_following`: a press does, and an Auto restart carries the last
## frame's verdict. Returns whether a cycle started.
func start_cycle(starts_following: bool = true) -> bool:
	if _cycling or technique_data == null:
		return false
	_cycling = true
	_elapsed = 0.0
	_madra_timer = 0.0
	_followed_seconds = 0.0
	_unpaid_spirit_seconds = 0.0
	_follow_window.reset(starts_following)
	_followed_throughout = true
	_flat = is_auto_running()
	_result = _new_result()
	for zone: CyclingZone in cycling_zones:
		zone.set_state(CyclingZone.State.IDLE)
	for seal: SealNode in seal_nodes:
		seal.reset()
	_groove.set_lit_length(-1.0)
	_groove.set_swept_length(-1.0)
	_ball_ring.visible = false
	CyclingManager.start_cycle_session(technique_data.cycle_duration)
	cycling_started.emit()
	return true

## Ends a running cycle without a result and puts everything back to ready: the
## zones IDLE, the groove lit, the ball at the start of the path and the cycle's
## session over. It does this after a finished cycle too, which clears its studs.
func stop_cycling() -> void:
	_return_to_ready()

## Moves the play on by `delta` seconds, with the cursor at `cursor_global`.
## While no cycle runs only the swirl moves and the ball waits at the start. While
## one runs, in this order: the ball moves and is drawn, the follow window judges
## the frame and the cursor draws Madra if it follows (or Auto draws at its rate
## if nobody follows), the zones turn active or spent, the groove's sweep and
## trail move on, the frame joins the rate window and the session is updated.
## The cycle ends once its time is up. A frame that runs past the end counts
## only the time left in the cycle, so a long hitch draws no Madra beyond it.
func advance(delta: float, cursor_global: Vector2) -> void:
	_swirl_clock += delta
	if not _cycling:
		_breath_clock += delta
		_show_ready()
		return
	_show_ball_frame(0)
	var duration: float = technique_data.cycle_duration
	var cycle_delta: float = minf(delta, duration - _elapsed)
	_elapsed = minf(_elapsed + delta, duration)
	_follow.progress_ratio = _ball_ratio()
	_draw_ball()
	var on_ball: bool = cursor_global.distance_to(_ball_drawn) <= CURSOR_REACH
	_following = _follow_window.judge(cycle_delta, on_ball, cursor_global)
	_ball_ring.visible = _following
	if not _following:
		_followed_throughout = false
	# The share of the full rate the frame pays: all of it while followed,
	# Auto's while nobody follows, nothing otherwise.
	var share: float = 1.0 if _following else (CyclingRules.AUTO_RATE if is_auto_running() else 0.0)
	# Whether the frame draws is judged before its steps can fill the pool.
	var drawing: bool = share > 0.0 and not _madra_full()
	if _following:
		_set_ring_frame(_RING_FOLLOWING)
		_draw_madra(cycle_delta)
		_follow_spirit(cycle_delta)
	elif share > 0.0:
		_draw_madra(cycle_delta * share)
		_gather_spirit(cycle_delta * share)
	_result.followed_ratio = _followed_seconds / duration if duration > 0.0 else 0.0
	_update_zones()
	_update_seals(cycle_delta)
	_groove.set_swept_length(_path_length * minf(_elapsed / GROOVE_SWEEP_SECONDS, 1.0))
	_groove.set_lit_length(_follow.progress)
	_record_rate(cycle_delta, share if drawing else 0.0)
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

## The player keyed `arrow` (a CyclingRules.Arrow): the seal that shows takes it
## (SealNode.press()). Returns whether a seal took it as its next arrow: false
## for a wrong key, and while no seal shows.
func press_seal(arrow: int) -> bool:
	if not _cycling:
		return false
	for seal: SealNode in seal_nodes:
		if seal.get_state() == SealNode.State.SHOWING:
			return seal.press(arrow)
	return false

## Scores `zone`, which succeeds only while a cycle runs and the zone is ACTIVE.
## The tier comes from how far the true ball is from the zone's centre. Its XP
## goes to the technique's other stat through CharacterManager (a capped stat
## takes none, and the result notes it), the zone takes its stud and zone_scored
## is emitted. Cycling pays no Core Density. Returns whether it scored.
func try_score_zone(zone: CyclingZone) -> bool:
	if not _cycling or not cycling_zones.has(zone) or zone.get_state() != CyclingZone.State.ACTIVE:
		return false
	var distance: float = _follow.global_position.distance_to(zone.global_position)
	var tier: CyclingRules.Tier = CyclingRules.tier_for_distance(distance)
	var xp: int = CyclingRules.xp_for_tier(zone.zone_data, tier)
	var taken: float = _pay_other_stat(xp)
	_result.zones_scored += 1
	if tier == CyclingRules.Tier.PERFECT:
		_result.perfect_count += 1
	zone.set_state(CyclingZone.state_for_tier(tier))
	zone_scored.emit(zone, tier, xp, taken)
	return true

## Returns the waiting ball's breath level `seconds` into its wait: 0, 1 or 2,
## the ball at 60, 64 or 68 px. Each BREATH_SECONDS it steps up from 0 to 2 and
## back, holding each size about a third of the time, the largest at the middle.
static func breath_level(seconds: float) -> int:
	return roundi(1.0 - cos(TAU * seconds / BREATH_SECONDS))

## Returns whether a press at `cursor_global` would do something: the cursor is on
## the ball, and either no cycle runs (the press starts one) or a zone is ACTIVE
## (the press scores it). The view shows the pointer cursor then.
func wants_pointer(cursor_global: Vector2) -> bool:
	if technique_data == null or cursor_global.distance_to(_ball_drawn) > CURSOR_REACH:
		return false
	return not _cycling or _active_zone() != null

## Returns true while a cycle runs.
func is_cycling() -> bool:
	return _cycling

## Returns true while Auto runs this technique: auto_cycle is on and the
## technique's Auto is unlocked (CyclingManager). Only then does a cycle nobody
## follows pay, at CyclingRules.AUTO_RATE, and move the ball at an even speed.
## A locked technique never pays unattended, whatever auto_cycle says.
func is_auto_running() -> bool:
	return auto_cycle and technique_data != null and CyclingManager.is_auto_unlocked(technique_data.id)

## Returns true while a cycle runs and the cursor follows the ball: in its gold
## ring, since the press or since it moved there.
func is_following() -> bool:
	return _following

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

## Returns the ball's share of the path at the elapsed time, 0 at the start and
## 1 once the cycle's time is up: eased in and out with a sine, or at an even
## speed in a flat (Auto) cycle, so chained Auto cycles never slow at their ends.
func _ball_ratio() -> float:
	return _cycle_fraction(_elapsed) if _flat else _eased_ratio_at(_elapsed)

## Returns the eased ball's share of the path `seconds` into a cycle, which
## places the seal nodes.
func _eased_ratio_at(seconds: float) -> float:
	return 0.5 - 0.5 * cos(PI * _cycle_fraction(seconds))

## Returns `seconds` as a share of the cycle, 0 to 1.
func _cycle_fraction(seconds: float) -> float:
	var duration: float = technique_data.cycle_duration
	return 1.0 if duration <= 0.0 else minf(seconds / duration, 1.0)

## Returns the second of the running cycle at which the ball reaches `seal`'s
## node: its own second, or in a flat cycle the one at which the even ball
## reaches the share of the path where the eased ball meets the node.
func _seal_arrival(seal: SealNode) -> float:
	if not _flat:
		return seal.arrive_seconds
	return _eased_ratio_at(seal.arrive_seconds) * technique_data.cycle_duration

## Adds the Madra the cursor draws in `delta` seconds: a step for every
## MADRA_PARTICLE_INTERVAL the timer has gathered, to within _STEP_EPSILON. The
## timer keeps the remainder, which a step paid a hair early leaves just below 0.
func _draw_madra(delta: float) -> void:
	_madra_timer += delta
	while _madra_timer >= MADRA_PARTICLE_INTERVAL - _STEP_EPSILON:
		_madra_timer -= MADRA_PARTICLE_INTERVAL
		_draw_madra_step()

## Gathers `seconds` of following on the Spirit clock and pays it
## (_gather_spirit()).
func _follow_spirit(seconds: float) -> void:
	_followed_seconds += seconds
	_gather_spirit(seconds)

## Gathers `seconds` on the Spirit clock, followed or Auto's share of time
## nobody followed, and pays every whole STAT_XP_INTERVAL it holds, to within
## _STEP_EPSILON, in one payment.
func _gather_spirit(seconds: float) -> void:
	_unpaid_spirit_seconds += seconds
	var intervals: int = floori((_unpaid_spirit_seconds + _STEP_EPSILON) / STAT_XP_INTERVAL)
	if intervals > 0:
		var paid_seconds: float = intervals * STAT_XP_INTERVAL
		_unpaid_spirit_seconds -= paid_seconds
		_pay_spirit(paid_seconds)

## Pays the followed time no payment has covered yet, if any: at a cycle's end,
## and when a stop cuts one short.
func _pay_unpaid_spirit() -> void:
	if _unpaid_spirit_seconds > _STEP_EPSILON:
		_pay_spirit(_unpaid_spirit_seconds)
	_unpaid_spirit_seconds = 0.0

## Pays the Spirit XP `seconds` of following earn on this technique. The result
## records what Spirit took, and whether the cap took the rest; stat_xp_paid
## carries what it took, unless that is nothing.
func _pay_spirit(seconds: float) -> void:
	var xp: float = technique_data.get_spirit_xp_per_second() * seconds
	if xp <= 0.0:
		return
	var spirit := CharacterAttributesData.AttributeType.SPIRIT
	var taken: float = CharacterManager.add_stat_xp(spirit, xp)
	_result.record_stat_xp(spirit, taken, taken < xp - _STEP_EPSILON)
	if taken > 0.0:
		stat_xp_paid.emit(spirit, _ball_drawn, taken)

## Pays `xp` to the technique's other stat and records it on the result, capped
## when the stat took less. Returns what the stat took: 0 for a technique that
## trains Spirit alone.
func _pay_other_stat(xp: float) -> float:
	if technique_data.minor_stat < 0 or xp <= 0.0:
		return 0.0
	var stat := technique_data.minor_stat as CharacterAttributesData.AttributeType
	var taken: float = CharacterManager.add_stat_xp(stat, xp)
	_result.record_stat_xp(stat, taken, taken < xp - _STEP_EPSILON)
	return taken

## Returns true when the pool is at its max, so the cursor adds nothing.
func _madra_full() -> bool:
	return ResourceManager.get_madra() >= ResourceManager.get_max_madra()

## Draws one step of Madra. Nothing is added or requested at the max. The step
## counts only for the Madra it really added, which is less than a full step
## when the max cuts it short.
func _draw_madra_step() -> void:
	if _madra_full():
		return
	var before: float = ResourceManager.get_madra()
	if ResourceManager.add_madra(_madra_per_step(), true) <= 0.0:
		return
	# What the pool gained, not add_madra()'s figure: that is snapped to 0.001,
	# and the snaps add up (Smooth Flow's 187 steps sum to 199.53 for the 199.47
	# they add, which the result line would round to +200).
	var added: float = ResourceManager.get_madra() - before
	_result.madra_added += added
	madra_particle_requested.emit(_ball_drawn, added)

## Returns the Madra one step adds: the technique's Madra per cycle at Spirit's
## multiplier, spread over the steps of a cycle.
func _madra_per_step() -> float:
	if technique_data.cycle_duration <= 0.0:
		return 0.0
	return technique_data.get_madra_per_cycle(_madra_multiplier) * MADRA_PARTICLE_INTERVAL / technique_data.cycle_duration

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

## Moves each seal node on by the frame's `delta` seconds of cycle: its flash and
## plate timers run (SealNode.advance()), an IDLE node shows its seal once the
## elapsed time reaches SEAL_LEAD before its second, and a node the ball reaches
## this frame bursts if open, paying the other stat seal_xp, or fizzles if its
## seal still shows. One long frame can show a seal and fizzle it.
func _update_seals(delta: float) -> void:
	var before: float = _elapsed - delta
	for seal: SealNode in seal_nodes:
		seal.advance(delta)
		var arrival: float = _seal_arrival(seal)
		if seal.get_state() == SealNode.State.IDLE and _elapsed >= arrival - CyclingRules.SEAL_LEAD - _STEP_EPSILON:
			seal.show_seal(CyclingRules.random_seal(seal_rng))
			seal_shown.emit(seal)
		var arrives_now: bool = before < arrival - _STEP_EPSILON and _elapsed >= arrival - _STEP_EPSILON
		if not arrives_now:
			continue
		if seal.get_state() == SealNode.State.OPEN:
			seal.burst()
			var taken: float = _pay_other_stat(technique_data.seal_xp)
			seal_burst.emit(seal, technique_data.seal_xp, taken)
		elif seal.get_state() == SealNode.State.SHOWING:
			seal.fizzle()
			seal_missed.emit(seal)

## Adds a running frame to the rate window: its `delta` seconds and the Madra the
## cursor drew in it, which is `share` of the technique's Madra per second over
## those seconds: 1 while it followed with room under the max, Auto's rate
## while Auto drew for nobody, else 0. Then drops the oldest frames while the
## rest still cover RATE_WINDOW, which leaves the shortest run of the newest
## frames that does.
func _record_rate(delta: float, share: float) -> void:
	var drawn: float = _madra_per_step() / MADRA_PARTICLE_INTERVAL * delta * share
	_rate_window.append(Vector2(delta, drawn))
	var covered: float = 0.0
	for frame: Vector2 in _rate_window:
		covered += frame.x
	while not _rate_window.is_empty() and covered - _rate_window[0].x >= RATE_WINDOW:
		covered -= _rate_window[0].x
		_rate_window.pop_front()

## Writes the session snapshot: the time elapsed and the Madra rate, which is the
## Madra drawn over the rate window divided by the time it covers (0 with nothing
## in it). Steady tracking with room under the max reads the technique's Madra per
## second at Spirit's multiplier, get_madra_per_second(), at any frame rate. Within
## RATE_WINDOW seconds of the cursor starting or stopping, or of the max being
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
## result. The groove stays lit until the next cycle's sweep. With auto_cycle on,
## the next cycle starts at once, following if this one ended following, and the
## rate window carries into it: the session is updated again in the same frame,
## so the rate does not read 0 for a frame between two cycles. Otherwise the
## window is emptied.
func _finish_cycle() -> void:
	for zone: CyclingZone in cycling_zones:
		if zone.is_open():
			zone.set_state(CyclingZone.State.SPENT)
	for zone: CyclingZone in cycling_zones:
		_result.zone_states.append(zone.get_state())
	for seal: SealNode in seal_nodes:
		_result.seal_states.append(seal.get_state())
	_result.followed_throughout = _followed_throughout
	var carried: bool = _following
	_pay_unpaid_spirit()
	_cycling = false
	_following = false
	CyclingManager.end_cycle_session()
	_breath_clock = 0.0
	_show_ready()
	cycle_completed.emit(_result)
	if auto_cycle:
		start_cycle(carried)
		_update_session()
	else:
		_rate_window.clear()

## Ends any cycle without a result and puts the play back to ready: no time, no
## Madra gathered, a fresh empty result, the zones IDLE, the groove lit and the
## ball waiting at the start of the path. A cycle a stop cuts short first pays
## the Spirit XP it followed, from where the ball was (a switch has dropped it
## already). The session ends only if this technique was cycling: a session
## another technique started is left running.
func _return_to_ready() -> void:
	if _cycling:
		_pay_unpaid_spirit()
	var was_cycling: bool = _cycling
	_cycling = false
	_following = false
	_followed_throughout = false
	_flat = false
	_elapsed = 0.0
	_madra_timer = 0.0
	_rate_window.clear()
	_result = _new_result()
	if was_cycling:
		CyclingManager.end_cycle_session()
	for zone: CyclingZone in cycling_zones:
		zone.set_state(CyclingZone.State.IDLE)
	for seal: SealNode in seal_nodes:
		seal.reset()
	_groove.light_all()
	_breath_clock = 0.0
	_show_ready()

## Returns `curve` scaled by path_scale about path_pivot: a new curve, so the
## technique's own is left as it is. At a scale of 1 it is `curve` itself.
func _scaled_curve(curve: Curve2D) -> Curve2D:
	if curve == null or is_equal_approx(path_scale, 1.0):
		return curve
	var scaled := Curve2D.new()
	scaled.bake_interval = curve.bake_interval
	for index: int in curve.point_count:
		scaled.add_point(
			_scaled_point(curve.get_point_position(index)),
			curve.get_point_in(index) * path_scale,
			curve.get_point_out(index) * path_scale)
	return scaled

## Returns `point`, in the technique's data space, scaled by path_scale about
## path_pivot.
func _scaled_point(point: Vector2) -> Vector2:
	return path_pivot + (point - path_pivot) * path_scale

## Returns an empty result for a cycle of this technique.
func _new_result() -> CycleResult:
	var result: CycleResult = CycleResult.new()
	result.zones_total = cycling_zones.size()
	return result

## Replaces the zones with one for each zone of the technique, IDLE and in place
## under the path, at their scaled positions snapped to even px. The old zones
## leave the tree at once, so nothing of them can score and their names are free.
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
		# A scaled position falls between px: snapped, the socket and its floater
		# stay on the 2 px grid.
		zone.position = _snap_even(_scaled_point(data.position))
		cycling_zones.append(zone)

## Replaces the seal nodes with one for each of the technique's seal_seconds,
## IDLE and in place under the path where the ball is at that second, snapped to
## even px. The old nodes leave the tree at once, like the zones.
func _build_seals() -> void:
	for seal: SealNode in seal_nodes:
		_path.remove_child(seal)
		seal.queue_free()
	seal_nodes.clear()
	if technique_data == null or _path_length <= 0.0:
		return
	for index: int in technique_data.seal_seconds.size():
		var seconds: float = technique_data.seal_seconds[index]
		var seal: SealNode = _SEAL_SCENE.instantiate() as SealNode
		seal.name = "SealNode%d" % (index + 1)
		_path.add_child(seal)
		seal.setup(seconds)
		seal.position = _snap_even(_path.curve.sample_baked(_eased_ratio_at(seconds) * _path_length))
		seal_nodes.append(seal)

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

## Shows the ball at the start of the path inside its steady ring, both at the
## size of the breath.
func _show_ready() -> void:
	if _follow.progress != 0.0:
		_follow.progress = 0.0
	_draw_ball()
	var level: int = breath_level(_breath_clock)
	_show_ball_frame(level)
	_ball_ring.visible = true
	_set_ring_frame(_RING_READY_BY_BREATH[level])

## Shows the swirl frame for the swirl clock, from the row of the strip for
## breath `level`: the ball at 60, 64 or 68 px.
func _show_ball_frame(level: int) -> void:
	var frame := Vector2i(floori(_swirl_clock * SWIRL_FPS) % SWIRL_FRAMES, level)
	if _ball_sprite.get_frame() != frame:
		_ball_sprite.set_frame(frame.x, frame.y)

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

## Spirit's multiplier follows every stats change: a Spirit level, Spirit gear
## put on or taken off, a save reset.
func _on_stats_changed() -> void:
	_madra_multiplier = CharacterManager.get_total_attributes_data().get_cycling_madra_multiplier()
