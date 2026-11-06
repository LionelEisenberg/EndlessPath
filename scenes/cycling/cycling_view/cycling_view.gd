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
## cabinet's Madra orb, the XP pellets from a zone into its Core orb (none while
## the core is full, which takes no XP), and each payment of a stat's XP for
## following bursts from the ball into that stat's cell as a puff of STAT_PELLETS
## (none for a capped stat, which takes no XP). The cabinet holds what each pellet
## carries out of its readout until the pellet lands, so its orbs and cells fill
## as the pellets arrive. MainView hands the cabinet over in cultivator_plate;
## with none, no pellet is sent, and none flies from a hidden board.
## The view shows and hides outright, or a transition scales it out of the cultivator
## into the board's rect (get_board_rect()) and back. While it shows it updates the status
## line, the zone floaters and the cursor every frame and the technique plays;
## once it hides both stop, the running cycle ends, every floater is hidden and
## the pellets in flight are freed. Opening it again forgets the last cycle's
## result, so reopening starts clean. A press on the
## ball reaches it through the board: the root and the effects layer ignore the
## mouse and the board and the figure box pass it, and only physics picking
## takes a press that no Control stopped.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The status line: the instruction to start while the ball waits, and the
## instructions while it runs, FOLLOW_ZONES for a technique with zones. It
## changes only as a cycle starts or ends.
const READY: String = "Click the Madra ball to begin a cycle."
const FOLLOW: String = "Follow the ball for Madra and Spirit."
const FOLLOW_ZONES: String = "Follow the ball for Madra and Spirit. Click it over a zone for Core XP."

## The Auto toggle's text.
const AUTO_ON_TEXT: String = "Auto · on"
const AUTO_OFF_TEXT: String = "Auto · off"

## Px between a zone's centre and the top of its floater as it pops. The
## floater rises from there by get_rise().
const FLOATER_LIFT: float = 56.0

## A Madra pellet's flight to the cabinet's Madra orb in seconds, and how far
## its path bows off the straight line in px: the stream sways from that far to
## one side to that far to the other (PelletFlight.stream).
const MADRA_PELLET_FLIGHT: float = 0.6
const MADRA_PELLET_BOW: float = 60.0

## A hit's XP pellets pop out of the zone up to XP_BURST_REACH px, then home into
## the Core orb (PelletFlight.burst): the first lands XP_PELLET_FLIGHT s after
## the hit, each next one XP_PELLET_FLIGHT_STEP s after the one before.
const XP_PELLET_FLIGHT: float = 0.6
const XP_PELLET_FLIGHT_STEP: float = 0.04
const XP_BURST_REACH: float = 36.0

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
@onready var _effects_layer: Control = %EffectsLayer

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The cultivator cabinet the pellets fly into. MainView sets it; with none, no
## pellet is sent.
var cultivator_plate: CultivatorPlate = null

## One floater for each zone of the technique, in the order of the zones.
var _floaters: Array[LacquerFloater] = []

## How many Madra pellets the view has sent: the index that sways the stream.
var _madra_pellets_sent: int = 0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_technique.cycle_completed.connect(_on_cycle_completed)
	_technique.madra_particle_requested.connect(_on_madra_particle_requested)
	_technique.zone_scored.connect(_on_zone_scored)
	_technique.stat_xp_paid.connect(_on_stat_xp_paid)
	CyclingManager.equipped_technique_changed.connect(_on_equipped_technique_changed)
	ActionManager.stop_cycling.connect(_on_stop_cycling)
	_close_button.pressed.connect(_on_close_pressed)
	_auto_toggle.toggled.connect(_on_auto_toggled)
	_auto_toggle.mouse_entered.connect(_auto_hover.show)
	_auto_toggle.mouse_exited.connect(_auto_hover.hide)
	visibility_changed.connect(_on_visibility_changed)
	_technique.auto_cycle = _auto_toggle.button_pressed
	_show_auto_state(_auto_toggle.button_pressed)
	_load_equipped_technique()
	_on_visibility_changed()

func _process(_delta: float) -> void:
	_update_status()
	_place_floaters()
	_update_cursor(get_global_mouse_position())

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns the status line: READY while no cycle runs, and while one runs
## FOLLOW_ZONES for a technique that `has_zones`, FOLLOW for one with none.
static func status_line(running: bool, has_zones: bool) -> String:
	if not running:
		return READY
	return FOLLOW_ZONES if has_zones else FOLLOW

## Returns the status line's text.
func get_status_text() -> String:
	return _status_label.text

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
## names it; each zone gets a floater; and the last technique's cycle leaves
## no result behind.
func _apply_technique(technique: CyclingTechniqueData) -> void:
	_technique.setup(technique)
	_title_label.text = technique.technique_name
	_relayout_board()
	_rebuild_floaters()
	CyclingManager.clear_last_cycle_result()

#-----------------------------------------------------------------------------
# THE STATUS LINE AND THE CURSOR
#-----------------------------------------------------------------------------

## Shows the status line for the technique's state this frame, and lays the
## board out again when the line changes.
func _update_status() -> void:
	var line: String = status_line(_technique.is_cycling(), not _technique.cycling_zones.is_empty())
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

## Returns the XP pellets' ramp for a hit of `tier`: the tier's colour.
static func _pellet_ramp(tier: CyclingRules.Tier) -> LacquerPellet.Ramp:
	match tier:
		CyclingRules.Tier.PERFECT:
			return LacquerPellet.Ramp.BRASS
		CyclingRules.Tier.GOOD:
			return LacquerPellet.Ramp.CREAM
		_:
			return LacquerPellet.Ramp.TAN

## Replaces the floaters with one for each zone of the technique, all hidden.
func _rebuild_floaters() -> void:
	for floater: LacquerFloater in _floaters:
		_effects_layer.remove_child(floater)
		floater.queue_free()
	_floaters.clear()
	for _zone: CyclingZone in _technique.cycling_zones:
		var floater: LacquerFloater = _FLOATER_SCENE.instantiate() as LacquerFloater
		_effects_layer.add_child(floater)
		_floaters.append(floater)

## Places every floater that shows over its zone.
func _place_floaters() -> void:
	for index: int in mini(_floaters.size(), _technique.cycling_zones.size()):
		if _floaters[index].visible:
			_place_floater(index)

## Puts the floater of zone `index` FLOATER_LIFT px above the zone's centre and
## raises it by its rise, centred on the zone on the 2 px grid. The floater does
## not move itself.
func _place_floater(index: int) -> void:
	var floater: LacquerFloater = _floaters[index]
	var half_width: float = snappedf(floater.get_token_width() / 2.0, 2.0)
	floater.global_position = _technique.cycling_zones[index].global_position - Vector2(half_width, FLOATER_LIFT + floater.get_rise())

#-----------------------------------------------------------------------------
# AUTO
#-----------------------------------------------------------------------------

## Shows the toggle's state on its label: its text, cream pressed in (2 px
## lower) or tan.
func _show_auto_state(on: bool) -> void:
	_auto_label.text = AUTO_ON_TEXT if on else AUTO_OFF_TEXT
	_auto_label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_CREAM if on else ThemeConstants.LACQUER_TAN)
	_auto_label.position.y = _AUTO_PRESS_DROP if on else 0.0

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
	for floater: LacquerFloater in _floaters:
		floater.stop()
	_free_pellets()

func _on_equipped_technique_changed(technique: CyclingTechniqueData) -> void:
	_apply_technique(technique)

## A cycle ran to its end: its result goes to CyclingManager for the chest, and
## one line goes to the log.
func _on_cycle_completed(result: CycleResult) -> void:
	CyclingManager.set_last_cycle_result(result)
	LogManager.log_message("[color=cyan]%s[/color]" % result.log_line())

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

## A zone scored: its floater pops with the hit and its XP in the tier's colour,
## and the tier's pellets burst out of the zone and home into the cabinet's Core
## orb, each carrying an even share of the XP, which the cabinet shows as each
## lands. A full core takes no XP, so the floater says "Core full" where the XP
## would be ("PERFECT · Core full") and no pellet flies. Short of full the core
## took every XP of the hit, so the shares add up to what it gained.
func _on_zone_scored(zone: CyclingZone, tier: CyclingRules.Tier, xp: int) -> void:
	var core_full: bool = CultivationManager.is_core_full()
	var zone_index: int = _technique.cycling_zones.find(zone)
	if zone_index >= 0 and zone_index < _floaters.size():
		var hit_text: String = "%s +%d XP" % [CyclingRules.tier_name(tier), xp]
		if core_full:
			hit_text = "%s · %s" % [CyclingRules.tier_name(tier), CultivationManager.CORE_FULL_TEXT]
		_floaters[zone_index].pop(hit_text, CyclingRules.tier_color(tier))
		_place_floater(zone_index)
	if cultivator_plate == null or core_full:
		return
	var flights: Array[PelletFlight] = PelletFlight.burst(
		zone.global_position,
		cultivator_plate.get_core_orb_global_position(),
		CyclingRules.pellet_count(tier),
		XP_PELLET_FLIGHT,
		XP_PELLET_FLIGHT_STEP,
		XP_BURST_REACH)
	var share: float = float(xp) / flights.size()
	for flight: PelletFlight in flights:
		var pellet: LacquerPellet = _send_pellet(flight, _pellet_ramp(tier))
		cultivator_plate.hold_core_xp(share)
		pellet.delivered.connect(cultivator_plate.release_core_xp.bind(share))

## A payment of a stat's XP for following landed in the stat: a puff of
## STAT_PELLETS pellets in the stat's ramp bursts from the ball and homes into the
## stat's cell, each carrying an even share of what the stat took, which the
## cabinet holds out of the cell until each lands. A hidden board sends nothing:
## the XP is in the stat already, and its cell shows it at once.
func _on_stat_xp_paid(stat: CharacterAttributesData.AttributeType, from_pos: Vector2, amount: float) -> void:
	if cultivator_plate == null or not is_visible_in_tree():
		return
	var flights: Array[PelletFlight] = PelletFlight.burst(
		from_pos,
		cultivator_plate.get_stat_cell_global_position(stat),
		STAT_PELLETS,
		STAT_PELLET_FLIGHT,
		STAT_PELLET_FLIGHT_STEP,
		STAT_BURST_REACH)
	var share: float = amount / flights.size()
	for flight: PelletFlight in flights:
		var pellet: LacquerPellet = _send_pellet(flight, LacquerPellet.stat_ramp(stat))
		cultivator_plate.hold_stat_xp(stat, share)
		pellet.delivered.connect(cultivator_plate.release_stat_xp.bind(stat, share))

func _on_auto_toggled(on: bool) -> void:
	_technique.auto_cycle = on
	_show_auto_state(on)

func _on_close_pressed() -> void:
	ActionManager.stop_action()

func _on_stop_cycling() -> void:
	_technique.stop_cycling()
