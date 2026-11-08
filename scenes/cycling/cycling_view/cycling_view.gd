class_name CyclingView
extends Control

## CyclingView
## The cycling board: a lacquer board in the zone view's map gap, with the
## carved figure and the equipped technique's groove, ball and zones on it
## (CyclingTechnique), the action's name, the technique's name and a close
## button above, and a status line and the Auto toggle below. A name or a status
## line too long for its line wraps, never cut, and the board grows under it.
## A finished cycle's result goes to CyclingManager, and the zone chest shows
## it under its Now tray.
## The cabinet on the left is the Madra, Core Density and stat readout, so the
## view has none of its own: the Madra pellets fly from the ball into the
## cabinet's Madra orb, and each payment of a stat's XP bursts into that stat's
## cell. Following pays Spirit, a puff of STAT_PELLETS from the ball; a hit pays
## the technique's other stat (Smooth Flow's Control) its tier's pellets from the
## zone, and an opened seal (Seal Flow's Mind) SEAL_PELLETS from its node.
## A capped stat takes no XP, and no pellet flies to it. The cabinet holds what
## each pellet carries out of its readout until the pellet lands, so its orbs and
## cells fill as the pellets arrive. MainView hands the cabinet over in
## cultivator_plate; with none, no pellet is sent, and none flies from a hidden
## board.
## Each zone and each seal node has a floater that pops what a hit or an opened
## seal paid, with the stat's icon and name ("PERFECT +12 [icon] Control"), or
## that the cap took it ("OPEN · Mind capped", in brass). A floater stays
## FLOATER_BOARD_MARGIN px inside the board's sides.
## The view shows and hides outright, or a transition scales it out of the cultivator
## into the board's rect (get_board_rect()) and back. While it shows it updates the status
## line, the floaters and the cursor every frame and the technique plays;
## once it hides both stop, the running cycle ends, every floater is hidden and
## the pellets in flight are freed. Opening it again forgets the last cycle's
## result, so reopening starts clean.
## The Auto toggle is locked until the equipped technique's Auto is unlocked:
## a lock beside "Auto" on a darkened toggle that takes no press, and on hover a
## tooltip board above it that says what a perfect cycle is for the technique.
## A perfect cycle (CycleResult.is_perfect()) unlocks it through CyclingManager:
## a floater over the ball, two brass flashes on the toggle and one log line.
## With Auto unlocked and on, the board starts a cycle whenever the ball is
## ready, and the running status line reads AUTO_LINE. A press on the
## ball reaches it through the board: the root and the effects layer ignore the
## mouse and the board and the figure box pass it, and only physics picking
## takes a press that no Control stopped.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The status line, always one line beside the Auto toggle (#144): the
## instruction to start while the ball waits, and while it runs FOLLOW, or
## FOLLOW_LEAD then the clause of each game the technique has, ZONES_CLAUSE for
## zones and SEALS_CLAUSE for seals. A clause names the action, not its stat:
## the floaters name the stat as it pays. It drops while that stat is capped,
## read as a cycle starts, so the line changes only as a cycle starts or ends.
const READY: String = "Click the Madra ball to begin a cycle."
const FOLLOW: String = "Follow the ball for Madra and Spirit."
const FOLLOW_LEAD: String = "Follow the ball."
## The whole running line while Auto runs, read as a cycle starts, with Auto's
## rate as a percent. It has no clause: Auto plays no zone and no seal.
const AUTO_LINE: String = "Auto cycles at %d%%. Follow for the full rate."
const ZONES_CLAUSE: String = " Click it over each zone."
const SEALS_CLAUSE: String = " Open each seal with W A S D."

## The floater of a hit or an opened seal the cap took everything from, in
## brass: the hit's tier, or SEAL_OPEN_TEXT, then the stat's name.
const CAPPED_FORMAT: String = "%s · %s capped"
const SEAL_OPEN_TEXT: String = "OPEN"

## The Auto toggle's text: on, off, and beside the lock while it is locked.
const AUTO_ON_TEXT: String = "Auto · on"
const AUTO_OFF_TEXT: String = "Auto · off"
const AUTO_LOCKED_TEXT: String = "Auto"

## The locked toggle's tooltip: UNLOCK_TITLE, then UNLOCK_HINT_FORMAT with the
## share of the cycle a perfect one follows, a part for each game the technique
## has (ZONES_HINT, SEALS_HINT) and a full stop.
const UNLOCK_TITLE: String = "Unlock Auto"
const UNLOCK_HINT_FORMAT: String = "Play a perfect cycle: follow the ball for %d%% of the cycle"
const ZONES_HINT: String = " and press every zone PERFECT"
const SEALS_HINT: String = " and open every seal"

## The unlock: the floater over the ball, in brass, and the log line, with the
## technique's name.
const UNLOCK_FLOATER_TEXT: String = "PERFECT CYCLE · Auto unlocked"
const UNLOCK_LOG_FORMAT: String = "[color=yellow]%s · Auto unlocked[/color]"

## Px between the top of the Auto toggle and the bottom of its tooltip.
const TOOLTIP_GAP: float = 6.0

## Px between a zone's or a seal node's centre and the top of its floater as it
## pops. The floater rises from there by get_rise().
const FLOATER_LIFT: float = 56.0

## A floater keeps this many px inside the board's left and right sides, so the
## floater of a zone near a side stays on the board.
const FLOATER_BOARD_MARGIN: float = 22.0

## A Madra pellet's flight to the cabinet's Madra orb in seconds, and how far
## its path bows off the straight line in px: the stream sways from that far to
## one side to that far to the other (PelletFlight.stream).
const MADRA_PELLET_FLIGHT: float = 0.6
const MADRA_PELLET_BOW: float = 60.0

## A hit's or an opened seal's pellets pop out of the zone or the seal node up
## to XP_BURST_REACH px, then home into the cell of the technique's other stat
## (PelletFlight.burst): the first lands XP_PELLET_FLIGHT s after the hit, each
## next one XP_PELLET_FLIGHT_STEP s after the one before. A hit sends its tier's
## CyclingRules.pellet_count(), an opened seal SEAL_PELLETS.
const XP_PELLET_FLIGHT: float = 0.6
const XP_PELLET_FLIGHT_STEP: float = 0.04
const XP_BURST_REACH: float = 36.0
const SEAL_PELLETS: int = 5

## A payment of a stat's XP is a puff of STAT_PELLETS pellets in the stat's ramp:
## they pop out of the ball up to STAT_BURST_REACH px, then home into the stat's
## cell on the cabinet, the first STAT_PELLET_FLIGHT s after the payment and each
## next one STAT_PELLET_FLIGHT_STEP s after the one before (PelletFlight.burst).
const STAT_PELLETS: int = 3
const STAT_PELLET_FLIGHT: float = 0.6
const STAT_PELLET_FLIGHT_STEP: float = 0.05
const STAT_BURST_REACH: float = 28.0

const _PELLET_SCENE: PackedScene = preload("res://scenes/common/lacquer/lacquer_pellet/lacquer_pellet.tscn")
const _FLOATER_SCENE: PackedScene = preload("res://scenes/common/lacquer/lacquer_floater/lacquer_floater.tscn")

## The Auto label sits this many px lower while the toggle is pressed in.
const _AUTO_PRESS_DROP: float = 2.0
## The locked toggle: its art darkened, its label faded and moved right of the
## lock, so the whole button reads as disabled.
const _AUTO_LOCKED_ART: Color = Color(0.42, 0.42, 0.42, 1.0)
const _AUTO_LOCKED_LABEL_ALPHA: float = 0.6
const _AUTO_LOCKED_LABEL_SHIFT: float = 10.0

## The board's rows from its top. The figure box stands at FIGURE_TOP, or lower
## to stay FIGURE_GAP under the title's last line, and the footer (the status
## line beside the Auto toggle) FOOTER_GAP under the figure. The board keeps its
## art's height until the footer comes within BOARD_ROOM of its bottom (the
## bottom frame, the corner brackets and the shadow), then grows to keep that
## room, so a two-line name and a two-line status line together still end on
## screen.
const FIGURE_TOP: float = 104.0
const FIGURE_GAP: float = 14.0
const FOOTER_GAP: float = 6.0
const BOARD_ROOM: float = 30.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _board: NinePatchRect = %Board
@onready var _action_label: Label = %ActionLabel
@onready var _title_label: Label = %TitleLabel
@onready var _close_button: TextureButton = %CloseButton
@onready var _figure_box: Control = %FigureBox
@onready var _technique: CyclingTechnique = %CyclingTechnique
@onready var _status_label: Label = %StatusLabel
@onready var _auto_toggle: TextureButton = %AutoToggle
@onready var _auto_label: Label = %AutoLabel
@onready var _auto_hover: LacquerFrameOverlay = %AutoHover
@onready var _auto_flash: LacquerFrameOverlay = %AutoFlash
@onready var _auto_lock: TextureRect = %AutoLock
@onready var _auto_tooltip: StatTooltip = %AutoTooltip
@onready var _unlock_floater: LacquerFloater = %UnlockFloater
@onready var _effects_layer: Control = %EffectsLayer

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The cultivator cabinet the pellets fly into. MainView sets it; with none, no
## pellet is sent.
var cultivator_plate: CultivatorPlate = null

## One floater for each zone of the technique, in the order of the zones.
var _floaters: Array[LacquerFloater] = []

## One floater for each seal node of the technique, in the order of the nodes.
var _seal_floaters: Array[LacquerFloater] = []

## Whether the technique's other stat was capped as the running cycle started:
## its clause stays off the status line until the next cycle starts.
var _other_capped: bool = false

## How many Madra pellets the view has sent: the index that sways the stream.
var _madra_pellets_sent: int = 0

## Whether Auto ran as the running cycle started: the status line reads
## AUTO_LINE until the next cycle starts.
var _auto_line: bool = false

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_technique.cycling_started.connect(_on_cycling_started)
	_technique.cycle_completed.connect(_on_cycle_completed)
	_technique.madra_particle_requested.connect(_on_madra_particle_requested)
	_technique.zone_scored.connect(_on_zone_scored)
	_technique.stat_xp_paid.connect(_on_stat_xp_paid)
	_technique.seal_burst.connect(_on_seal_burst)
	CyclingManager.equipped_technique_changed.connect(_on_equipped_technique_changed)
	CyclingManager.auto_unlocked.connect(_on_auto_unlocked)
	ActionManager.stop_cycling.connect(_on_stop_cycling)
	_close_button.pressed.connect(_on_close_pressed)
	_auto_toggle.toggled.connect(_on_auto_toggled)
	_auto_toggle.mouse_entered.connect(_on_auto_hovered)
	_auto_toggle.mouse_exited.connect(_on_auto_unhovered)
	visibility_changed.connect(_on_visibility_changed)
	_load_equipped_technique()
	_refresh_auto()
	_on_visibility_changed()

func _process(_delta: float) -> void:
	_start_auto_cycle()
	_update_status()
	_place_floaters()
	_update_cursor(get_global_mouse_position())

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns the status line: READY while no cycle runs; while one runs,
## AUTO_LINE when `auto` runs; else FOLLOW_LEAD then ZONES_CLAUSE if `technique`
## has zones and SEALS_CLAUSE if it has seals, or FOLLOW when it has no clause
## to add: no other stat, that stat `other_capped`, or no zones and no seals.
static func status_line(running: bool, technique: CyclingTechniqueData, other_capped: bool, auto: bool = false) -> String:
	if not running:
		return READY
	if auto:
		return AUTO_LINE % roundi(CyclingRules.AUTO_RATE * 100.0)
	if technique == null or technique.minor_stat < 0 or other_capped:
		return FOLLOW
	var clauses: String = ""
	if not technique.cycling_zones.is_empty():
		clauses += ZONES_CLAUSE
	if not technique.seal_seconds.is_empty():
		clauses += SEALS_CLAUSE
	return FOLLOW if clauses.is_empty() else FOLLOW_LEAD + clauses

## Returns what the locked Auto toggle's tooltip says unlocks `technique`'s
## Auto: UNLOCK_HINT_FORMAT with CyclingRules.PERFECT_FOLLOWED_SHARE, then
## ZONES_HINT if it has zones and SEALS_HINT if it has seals, and a full stop.
static func unlock_hint(technique: CyclingTechniqueData) -> String:
	var hint: String = UNLOCK_HINT_FORMAT % roundi(CyclingRules.PERFECT_FOLLOWED_SHARE * 100.0)
	if technique != null and not technique.cycling_zones.is_empty():
		hint += ZONES_HINT
	if technique != null and not technique.seal_seconds.is_empty():
		hint += SEALS_HINT
	return hint + "."

## Returns the status line's text.
func get_status_text() -> String:
	return _status_label.text

## Returns whether the Auto toggle is locked: the equipped technique's Auto is
## not unlocked yet, or no technique is set up.
func is_auto_locked() -> bool:
	var technique: CyclingTechniqueData = _technique.technique_data
	return technique == null or not CyclingManager.is_auto_unlocked(technique.id)

## The player keyed `arrow` (a CyclingRules.Arrow) on the seal that shows, if
## any (CyclingTechnique.press_seal()). CyclingViewState hands it the seal keys.
## Returns whether the seal took it as its next arrow.
func press_seal(arrow: int) -> bool:
	return _technique.press_seal(arrow)

## Returns the board's rect in the screen's space, as laid out now: where a transition
## scales the view out of the cultivator to, and back into.
func get_board_rect() -> Rect2:
	return _board.get_global_rect()

#-----------------------------------------------------------------------------
# THE TECHNIQUE
#-----------------------------------------------------------------------------

## Plays the equipped technique. With none equipped, equips the first one
## unlocked, which CyclingManager announces like any other switch.
func _load_equipped_technique() -> void:
	var equipped: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	if equipped != null:
		_apply_technique(equipped)
		return
	var unlocked: Array[CyclingTechniqueData] = CyclingManager.get_unlocked_techniques()
	if not unlocked.is_empty():
		CyclingManager.equip_technique(unlocked[0].id)

## Sets the board up for `technique`: the technique plays it, ready; the title
## names it; each zone and each seal node gets a floater; and the last
## technique's cycle leaves no result behind.
func _apply_technique(technique: CyclingTechniqueData) -> void:
	_technique.setup(technique)
	_title_label.text = technique.technique_name
	_relayout_board()
	_rebuild_floaters()
	_refresh_auto()
	CyclingManager.clear_last_cycle_result()

#-----------------------------------------------------------------------------
# THE STATUS LINE AND THE CURSOR
#-----------------------------------------------------------------------------

## Shows the status line for the technique's state this frame, and lays the
## board out again when the line changes.
func _update_status() -> void:
	var line: String = status_line(_technique.is_cycling(), _technique.technique_data, _other_capped, _auto_line)
	if line == _status_label.text:
		return
	_status_label.text = line
	_relayout_board()

## Gives the figure box the pointing hand while a click at `cursor_global` would
## do something (start a cycle or score a zone), the arrow otherwise.
func _update_cursor(cursor_global: Vector2) -> void:
	var shape: Control.CursorShape = Control.CURSOR_POINTING_HAND if _technique.wants_pointer(cursor_global) else Control.CURSOR_ARROW
	if _figure_box.mouse_default_cursor_shape != shape:
		_figure_box.mouse_default_cursor_shape = shape

#-----------------------------------------------------------------------------
# THE BOARD'S LAYOUT
#-----------------------------------------------------------------------------

## Stacks the board from its top: the action's name, the technique's name, the
## figure, then the footer, where the status line sits beside the Auto toggle,
## the shorter centred on the taller. A name or a status line too long for its
## line wraps and pushes what is under it down, and the board grows by as much
## from its art's height (its plain middle stretches). With a line each, the
## rows stand where the scene puts them.
func _relayout_board() -> void:
	_fit_lines(_action_label)
	_title_label.position.y = _action_label.position.y + _action_label.size.y
	_fit_lines(_title_label)
	var title_bottom: float = _title_label.position.y + _title_label.size.y
	_figure_box.position.y = maxf(FIGURE_TOP, 2.0 * ceilf((title_bottom + FIGURE_GAP) / 2.0))
	var footer_top: float = _figure_box.position.y + _figure_box.size.y + FOOTER_GAP
	_fit_lines(_status_label)
	var footer_height: float = maxf(_auto_toggle.size.y, _status_label.size.y)
	_auto_toggle.position.y = footer_top + (footer_height - _auto_toggle.size.y) / 2.0
	_status_label.position.y = footer_top + (footer_height - _status_label.size.y) / 2.0
	var board_bottom: float = footer_top + footer_height + BOARD_ROOM
	_board.size.y = maxf(_board.texture.get_size().y, board_bottom - _board.position.y)

## Makes a label as tall as its lines at its width.
static func _fit_lines(label: Label) -> void:
	label.size.y = label.get_minimum_size().y

#-----------------------------------------------------------------------------
# PELLETS AND FLOATERS
#-----------------------------------------------------------------------------

## Instances a pellet into the effects layer, which draws over the board, and
## sends it along `flight` in `ramp`.
func _send_pellet(flight: PelletFlight, ramp: LacquerPellet.Ramp) -> LacquerPellet:
	var pellet: LacquerPellet = _PELLET_SCENE.instantiate() as LacquerPellet
	_effects_layer.add_child(pellet)
	pellet.set_ramp(ramp)
	pellet.fly(flight)
	return pellet

## Frees every pellet in flight. Each leaves the effects layer at once, so the
## layer holds none even before the frees land.
func _free_pellets() -> void:
	for child: Node in _effects_layer.get_children():
		if child is LacquerPellet:
			_effects_layer.remove_child(child)
			child.queue_free()

## Returns whether stat pellets fly: the board shows and has a cabinet. None
## flies from a hidden board: the XP is in the stat already, and its cell shows
## it at once.
func _sends_pellets() -> bool:
	return cultivator_plate != null and is_visible_in_tree()

## Bursts `count` pellets in `stat`'s ramp from `from_pos` to the stat's cell, as
## a hit's or an opened seal's (the XP_PELLET_ and XP_BURST_ constants),
## together carrying `amount`. None from a hidden board.
func _send_xp_burst(stat: CharacterAttributesData.AttributeType, from_pos: Vector2, count: int, amount: float) -> void:
	if not _sends_pellets():
		return
	var cell: Vector2 = cultivator_plate.get_stat_cell_global_position(stat)
	_send_stat_pellets(stat, PelletFlight.burst(from_pos, cell, count, XP_PELLET_FLIGHT, XP_PELLET_FLIGHT_STEP, XP_BURST_REACH), amount)

## Sends `stat`'s pellets along `flights`, each carrying an even share of
## `amount`, which the cabinet holds out of the stat's cell until it lands.
func _send_stat_pellets(stat: CharacterAttributesData.AttributeType, flights: Array[PelletFlight], amount: float) -> void:
	var share: float = amount / flights.size()
	for flight: PelletFlight in flights:
		var pellet: LacquerPellet = _send_pellet(flight, LacquerPellet.stat_ramp(stat))
		cultivator_plate.hold_stat_xp(stat, share)
		pellet.delivered.connect(cultivator_plate.release_stat_xp.bind(stat, share))

## Replaces the floaters with one for each zone and one for each seal node of
## the technique, all hidden.
func _rebuild_floaters() -> void:
	for floater: LacquerFloater in _floaters + _seal_floaters:
		_effects_layer.remove_child(floater)
		floater.queue_free()
	_floaters = _new_floaters(_technique.cycling_zones.size())
	_seal_floaters = _new_floaters(_technique.seal_nodes.size())

## Returns `count` new floaters in the effects layer, all hidden.
func _new_floaters(count: int) -> Array[LacquerFloater]:
	var made: Array[LacquerFloater] = []
	for _index: int in count:
		var floater: LacquerFloater = _FLOATER_SCENE.instantiate() as LacquerFloater
		_effects_layer.add_child(floater)
		made.append(floater)
	return made

## Places every floater that shows over its zone or seal node.
func _place_floaters() -> void:
	for index: int in mini(_floaters.size(), _technique.cycling_zones.size()):
		if _floaters[index].visible:
			_place_floater(_floaters[index], _technique.cycling_zones[index].global_position)
	for index: int in mini(_seal_floaters.size(), _technique.seal_nodes.size()):
		if _seal_floaters[index].visible:
			_place_floater(_seal_floaters[index], _technique.seal_nodes[index].global_position)
	if _unlock_floater.visible:
		_place_floater(_unlock_floater, _technique.get_ball_global_position())

## Puts `floater` FLOATER_LIFT px above `centre` and raises it by its rise,
## centred on it on the 2 px grid, but kept FLOATER_BOARD_MARGIN px inside the
## board's left and right sides. The floater does not move itself.
func _place_floater(floater: LacquerFloater, centre: Vector2) -> void:
	var half_width: float = snappedf(floater.get_token_width() / 2.0, 2.0)
	var board: Rect2 = get_board_rect()
	var leftmost: float = 2.0 * ceilf((board.position.x + FLOATER_BOARD_MARGIN) / 2.0)
	var rightmost: float = 2.0 * floorf((board.end.x - FLOATER_BOARD_MARGIN - floater.size.x) / 2.0)
	var x: float = clampf(centre.x - half_width, leftmost, maxf(leftmost, rightmost))
	floater.global_position = Vector2(x, centre.y - FLOATER_LIFT - floater.get_rise())

#-----------------------------------------------------------------------------
# AUTO
#-----------------------------------------------------------------------------

## Gates the toggle on the equipped technique's unlock. Locked, it is off and
## takes no press, and the technique's auto_cycle is off; unlocked, the
## technique follows the toggle. Then shows the state.
func _refresh_auto() -> void:
	var locked: bool = is_auto_locked()
	if locked:
		_auto_toggle.set_pressed_no_signal(false)
	_auto_toggle.disabled = locked
	_auto_toggle.mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	_technique.auto_cycle = _auto_toggle.button_pressed
	if locked:
		_auto_hover.hide()
	else:
		_auto_tooltip.hide()
	_show_auto_state(locked, _auto_toggle.button_pressed)

## Shows the toggle's state: locked, the lock beside a faded AUTO_LOCKED_TEXT on
## darkened art; unlocked, its text on its label, cream pressed in (2 px lower)
## or tan.
func _show_auto_state(locked: bool, on: bool) -> void:
	_auto_lock.visible = locked
	_auto_toggle.self_modulate = _AUTO_LOCKED_ART if locked else Color.WHITE
	if locked:
		_auto_label.text = AUTO_LOCKED_TEXT
		_auto_label.add_theme_color_override(&"font_color", Color(ThemeConstants.LACQUER_DIM, _AUTO_LOCKED_LABEL_ALPHA))
		_auto_label.position = Vector2(_AUTO_LOCKED_LABEL_SHIFT, 0.0)
		return
	_auto_label.text = AUTO_ON_TEXT if on else AUTO_OFF_TEXT
	_auto_label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_CREAM if on else ThemeConstants.LACQUER_TAN)
	_auto_label.position = Vector2(0.0, _AUTO_PRESS_DROP if on else 0.0)

## Starts a cycle while Auto runs and the ball is ready: as Auto is turned on,
## as the board opens, after a switch or a stop.
func _start_auto_cycle() -> void:
	if _technique.is_auto_running() and not _technique.is_cycling():
		_technique.start_cycle(false)

## Shows the locked toggle's tooltip above it, right edges aligned, with what
## unlocks the equipped technique's Auto.
func _show_auto_tooltip() -> void:
	_auto_tooltip.set_text(UNLOCK_TITLE, unlock_hint(_technique.technique_data))
	var toggle: Rect2 = _auto_toggle.get_global_rect()
	_auto_tooltip.show_at(Vector2(toggle.end.x - _auto_tooltip.size.x, toggle.position.y - TOOLTIP_GAP - _auto_tooltip.size.y))

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## The view shows or hides, itself or with an ancestor. While it shows the
## technique plays and the view updates every frame; otherwise neither runs.
func _on_visibility_changed() -> void:
	var showing: bool = is_visible_in_tree()
	set_process(showing)
	_technique.set_process(showing)
	if showing:
		_on_shown()
	else:
		_on_hidden()

## The board shows: the labels name the running action and the technique, and
## the last session's result is gone.
func _on_shown() -> void:
	var action: ZoneActionData = ActionManager.get_current_action()
	if action != null:
		_action_label.text = action.action_name
	if _technique.technique_data != null:
		_title_label.text = _technique.technique_data.technique_name
	CyclingManager.clear_last_cycle_result()
	_update_status()
	_relayout_board()

## The board hides: the running cycle ends without a result, so reopening finds
## the zones idle, the groove dark and the ball at the start, every floater
## hides and the pellets in flight are freed, so none shows up mid-flight.
func _on_hidden() -> void:
	_technique.stop_cycling()
	for floater: LacquerFloater in _floaters + _seal_floaters:
		floater.stop()
	_unlock_floater.stop()
	_auto_tooltip.hide()
	_free_pellets()

func _on_equipped_technique_changed(technique: CyclingTechniqueData) -> void:
	_apply_technique(technique)

## A cycle started: whether the technique's other stat is capped is read now, so
## the status line keeps or drops its clause for the whole cycle.
func _on_cycling_started() -> void:
	var stat: int = _technique.technique_data.minor_stat
	_other_capped = stat >= 0 and CharacterManager.is_stat_capped(stat as CharacterAttributesData.AttributeType)
	_auto_line = _technique.is_auto_running()

## A cycle ran to its end: its result goes to CyclingManager for the chest, and
## one line goes to the log. A perfect cycle unlocks its technique's Auto.
func _on_cycle_completed(result: CycleResult) -> void:
	CyclingManager.set_last_cycle_result(result)
	LogManager.log_message("[color=cyan]%s[/color]" % result.log_line())
	var technique: CyclingTechniqueData = _technique.technique_data
	if result.is_perfect() and not CyclingManager.is_auto_unlocked(technique.id):
		CyclingManager.unlock_auto(technique.id)

## A technique's Auto unlocked. For the technique on the board: the floater pops
## over the ball, the toggle unlocks and flashes its brass frame twice (it stays
## off), and the log gets one line.
func _on_auto_unlocked(technique: CyclingTechniqueData) -> void:
	if technique != _technique.technique_data:
		return
	_refresh_auto()
	_auto_flash.flash(TechniqueDrawer.FLASH_TIMES)
	_unlock_floater.pop(UNLOCK_FLOATER_TEXT, ThemeConstants.LACQUER_BRASS)
	_place_floater(_unlock_floater, _technique.get_ball_global_position())
	LogManager.log_message(UNLOCK_LOG_FORMAT % technique.technique_name)

## A step of Madra left the ball: the stream's next pellet carries it to the
## cabinet's Madra orb, which shows it once the pellet lands.
func _on_madra_particle_requested(from_pos: Vector2, amount: float) -> void:
	if cultivator_plate == null:
		return
	var orb: Vector2 = cultivator_plate.get_madra_orb_global_position()
	var pellet: LacquerPellet = _send_pellet(PelletFlight.stream(from_pos, orb, MADRA_PELLET_FLIGHT, MADRA_PELLET_BOW, _madra_pellets_sent), LacquerPellet.Ramp.MADRA)
	_madra_pellets_sent += 1
	cultivator_plate.hold_madra(amount)
	pellet.delivered.connect(cultivator_plate.release_madra.bind(amount))

## A zone scored: its floater pops the tier and what the hit was worth, with the
## other stat's icon and name, in the tier's colour, and the tier's pellets fly
## from the zone to that stat's cell carrying what it took. A hit the cap took
## everything from pops the tier and the cap in brass, and sends none.
func _on_zone_scored(zone: CyclingZone, tier: CyclingRules.Tier, xp: int, taken: float) -> void:
	var zone_index: int = _technique.cycling_zones.find(zone)
	if zone_index < 0 or zone_index >= _floaters.size():
		return
	var floater: LacquerFloater = _floaters[zone_index]
	var stat := _technique.technique_data.minor_stat as CharacterAttributesData.AttributeType
	var tier_name: String = CyclingRules.tier_name(tier)
	if taken > 0.0:
		floater.pop_stat("%s +%d" % [tier_name, xp], stat, CyclingRules.tier_color(tier))
		_send_xp_burst(stat, zone.global_position, CyclingRules.pellet_count(tier), taken)
	else:
		floater.pop(CAPPED_FORMAT % [tier_name, StatDisplay.name_of(stat)], ThemeConstants.LACQUER_BRASS)
	_place_floater(floater, zone.global_position)

## The ball burst through an opened seal: its node's floater pops the seal's XP
## with the other stat's icon and name in Mind's green, and SEAL_PELLETS pellets
## fly from the node to that stat's cell carrying what it took. A seal the cap
## took everything from pops "OPEN" and the cap in brass, and sends none.
func _on_seal_burst(seal: SealNode, xp: float, taken: float) -> void:
	var seal_index: int = _technique.seal_nodes.find(seal)
	if seal_index < 0 or seal_index >= _seal_floaters.size():
		return
	var floater: LacquerFloater = _seal_floaters[seal_index]
	var stat := _technique.technique_data.minor_stat as CharacterAttributesData.AttributeType
	if taken > 0.0:
		floater.pop_stat("+%d" % roundi(xp), stat, ThemeConstants.LACQUER_MIND)
		_send_xp_burst(stat, seal.global_position, SEAL_PELLETS, taken)
	else:
		floater.pop(CAPPED_FORMAT % [SEAL_OPEN_TEXT, StatDisplay.name_of(stat)], ThemeConstants.LACQUER_BRASS)
	_place_floater(floater, seal.global_position)

## A payment of a stat's XP for following landed in the stat: a puff of
## STAT_PELLETS pellets in the stat's ramp bursts from the ball and homes into the
## stat's cell, each carrying an even share of what the stat took, which the
## cabinet holds out of the cell until each lands. A hidden board sends nothing:
## the XP is in the stat already, and its cell shows it at once.
func _on_stat_xp_paid(stat: CharacterAttributesData.AttributeType, from_pos: Vector2, amount: float) -> void:
	if not _sends_pellets():
		return
	var cell: Vector2 = cultivator_plate.get_stat_cell_global_position(stat)
	_send_stat_pellets(stat, PelletFlight.burst(from_pos, cell, STAT_PELLETS, STAT_PELLET_FLIGHT, STAT_PELLET_FLIGHT_STEP, STAT_BURST_REACH), amount)

## The toggle was pressed, or set: a locked toggle stays off (_refresh_auto()).
func _on_auto_toggled(_on: bool) -> void:
	_refresh_auto()

## The pointer reached the toggle: the hover frame, or while it is locked the
## tooltip that says what unlocks Auto.
func _on_auto_hovered() -> void:
	if is_auto_locked():
		_show_auto_tooltip()
	else:
		_auto_hover.show()

func _on_auto_unhovered() -> void:
	_auto_hover.hide()
	_auto_tooltip.hide()

func _on_close_pressed() -> void:
	ActionManager.stop_action()

func _on_stop_cycling() -> void:
	_technique.stop_cycling()
