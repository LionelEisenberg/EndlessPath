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
## The cabinet on the left is the Madra and Core Density readout, so the view
## has none of its own: the Madra pellets fly from the ball into the cabinet's
## Madra orb and the XP pellets from a zone into its Core orb (none while the
## core is full, which takes no XP). MainView hands the cabinet over in
## cultivator_plate; with none, no pellet is sent.
## The view shows and hides outright. While it shows it updates the status
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

## The status line when no cycle runs: before the first cycle, and after one.
const READY_FIRST: String = "Click the Madra ball to begin a cycle."
const READY_AGAIN: String = "Click the ball for another cycle."

## The status line while a cycle runs: the whole seconds gone and the cycle's
## length, then FOLLOW_SUFFIX while the cursor is off the ball.
const CYCLING_FORMAT: String = "Cycling · %d / %d s"
const FOLLOW_SUFFIX: String = " · follow the ball"

## The status line while a cycle runs with Madra at the cap: no Madra is drawn.
## MADRA_FULL_ZONES is for a technique whose zones still pay XP: it has zones and
## the core has room for the XP (a full core takes none).
const MADRA_FULL: String = "Madra full"
const MADRA_FULL_ZONES: String = "Madra full · zones still pay XP"

## The Auto toggle's text.
const AUTO_ON_TEXT: String = "Auto · on"
const AUTO_OFF_TEXT: String = "Auto · off"

## Px between a zone's centre and the top of its floater as it pops. The
## floater rises from there by get_rise().
const FLOATER_LIFT: float = 56.0

## A Madra pellet's flight to the cabinet's Madra orb in seconds, and how far
## its path may bow off the straight line in px.
const MADRA_PELLET_FLIGHT: float = 0.6
const MADRA_PELLET_SPREAD: float = 60.0

## The first XP pellet's flight to the Core orb in seconds and its bow in px.
## Each pellet after it flies longer and bows wider by the steps.
const XP_PELLET_FLIGHT: float = 0.55
const XP_PELLET_SPREAD: float = 40.0
const XP_PELLET_FLIGHT_STEP: float = 0.03
const XP_PELLET_SPREAD_STEP: float = 10.0

## An XP pellet starts up to this many px off the zone's centre on each axis.
const XP_PELLET_SCATTER: int = 7

## How the start of pellet k is scattered: (k * 7) % 15 - 7 across and
## (k * 11) % 15 - 7 down, 15 being the 2 * 7 + 1 offsets from -7 to 7. The
## steps are coprime to 15, so the eight pellets of a PERFECT hit all differ.
const _SCATTER_X_STEP: int = 7
const _SCATTER_Y_STEP: int = 11
const _SCATTER_SPAN: int = 2 * XP_PELLET_SCATTER + 1

const _MADRA_PELLET_SCENE: PackedScene = preload("res://scenes/common/lacquer/lacquer_pellet/lacquer_pellet.tscn")
const _FLOATER_SCENE: PackedScene = preload("res://scenes/common/lacquer/lacquer_floater/lacquer_floater.tscn")

## The XP pellets' art by tier: the tier's colour.
const _PELLET_BRASS: Texture2D = preload("res://assets/ui/lacquer/cycling/lacquer_cyc_pellet_brass_ai.png")
const _PELLET_CREAM: Texture2D = preload("res://assets/ui/lacquer/cycling/lacquer_cyc_pellet_cream_ai.png")
const _PELLET_TAN: Texture2D = preload("res://assets/ui/lacquer/cycling/lacquer_cyc_pellet_tan_ai.png")

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

## Whether a cycle has ended since the board was shown or the technique was
## switched: the ready line says "another cycle" once one has.
var _cycled_before: bool = false

## One floater for each zone of the technique, in the order of the zones.
var _floaters: Array[LacquerFloater] = []

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_technique.cycle_completed.connect(_on_cycle_completed)
	_technique.madra_particle_requested.connect(_on_madra_particle_requested)
	_technique.zone_scored.connect(_on_zone_scored)
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

## Returns the status line for the board's state. While no cycle runs it is
## READY_FIRST, or READY_AGAIN once a cycle has ended. While one runs it is
## "Cycling · 9 / 15 s" (the whole seconds gone, floored, and the cycle's
## length), with FOLLOW_SUFFIX added while the cursor is off the ball. With
## Madra at the cap it says so instead (MADRA_FULL_ZONES when `zones_pay_xp`,
## MADRA_FULL when not), whether or not the cursor follows. `zones_pay_xp` is
## true for a technique with zones while the core is not full: a full core takes
## no XP, so then its zones pay none and the line must not say they do.
static func status_line(cycled_before: bool, running: bool, elapsed: float, duration: float, tracking: bool, madra_full: bool, zones_pay_xp: bool) -> String:
	if not running:
		return READY_AGAIN if cycled_before else READY_FIRST
	if madra_full:
		return MADRA_FULL_ZONES if zones_pay_xp else MADRA_FULL
	var line: String = CYCLING_FORMAT % [floori(elapsed), roundi(duration)]
	return line if tracking else line + FOLLOW_SUFFIX

## Returns where XP pellet `index` starts, as an offset from its zone's centre:
## up to XP_PELLET_SCATTER px either way on each axis, a different spot for each
## index.
static func xp_pellet_offset(index: int) -> Vector2:
	return Vector2(
		(index * _SCATTER_X_STEP) % _SCATTER_SPAN - XP_PELLET_SCATTER,
		(index * _SCATTER_Y_STEP) % _SCATTER_SPAN - XP_PELLET_SCATTER)

## Returns the status line's text.
func get_status_text() -> String:
	return _status_label.text

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
## names it; each zone gets a floater; and nothing is left of the last
## technique's cycle, neither its result nor its ready text.
func _apply_technique(technique: CyclingTechniqueData) -> void:
	_technique.setup(technique)
	_title_label.text = technique.technique_name
	_relayout_board()
	_rebuild_floaters()
	CyclingManager.clear_last_cycle_result()
	_cycled_before = false

#-----------------------------------------------------------------------------
# THE STATUS LINE AND THE CURSOR
#-----------------------------------------------------------------------------

## Shows the status line for the technique's state this frame, and lays the
## board out again when the line changes.
func _update_status() -> void:
	var madra_full: bool = ResourceManager.get_madra() >= CultivationManager.get_max_madra()
	var zones_pay_xp: bool = not _technique.cycling_zones.is_empty() and not CultivationManager.is_core_full()
	var line: String = status_line(
		_cycled_before,
		_technique.is_cycling(),
		CyclingManager.get_cycle_elapsed(),
		CyclingManager.get_cycle_duration(),
		_technique.is_tracking(),
		madra_full,
		zones_pay_xp)
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

## Instances a pellet into the effects layer, which draws over the board.
func _add_pellet() -> LacquerPellet:
	var pellet: LacquerPellet = _MADRA_PELLET_SCENE.instantiate() as LacquerPellet
	_effects_layer.add_child(pellet)
	return pellet

## Frees every pellet in flight. Each leaves the effects layer at once, so the
## layer holds none even before the frees land.
func _free_pellets() -> void:
	for child: Node in _effects_layer.get_children():
		if child is LacquerPellet:
			_effects_layer.remove_child(child)
			child.queue_free()

## Returns the XP pellets' art for a hit of `tier`.
static func _pellet_texture(tier: CyclingRules.Tier) -> Texture2D:
	match tier:
		CyclingRules.Tier.PERFECT:
			return _PELLET_BRASS
		CyclingRules.Tier.GOOD:
			return _PELLET_CREAM
		_:
			return _PELLET_TAN

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
## the last session's result and ready text are gone.
func _on_shown() -> void:
	var action: ZoneActionData = ActionManager.get_current_action()
	if action != null:
		_action_label.text = action.action_name
	if _technique.technique_data != null:
		_title_label.text = _technique.technique_data.technique_name
	CyclingManager.clear_last_cycle_result()
	_cycled_before = false
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

## A cycle ran to its end: its result goes to CyclingManager for the chest, one
## line goes to the log and the ready line reads "another cycle".
func _on_cycle_completed(result: CycleResult) -> void:
	CyclingManager.set_last_cycle_result(result)
	LogManager.log_message("[color=cyan]%s[/color]" % result.log_line())
	_cycled_before = true

## A step of Madra left the ball: a pellet flies to the cabinet's Madra orb.
func _on_madra_particle_requested(from_pos: Vector2) -> void:
	if cultivator_plate == null:
		return
	var pellet: LacquerPellet = _add_pellet()
	pellet.launch(from_pos, cultivator_plate.get_madra_orb_global_position(), MADRA_PELLET_FLIGHT, MADRA_PELLET_SPREAD)

## A zone scored: its floater pops with the hit and its XP in the tier's colour,
## and the tier's pellets fly from the zone to the cabinet's Core orb. A full
## core takes no XP, so the floater says "Core full" where the XP would be
## ("PERFECT · Core full") and no pellet flies.
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
	var target: Vector2 = cultivator_plate.get_core_orb_global_position()
	var texture: Texture2D = _pellet_texture(tier)
	for k: int in CyclingRules.pellet_count(tier):
		var pellet: LacquerPellet = _add_pellet()
		pellet.set_texture(texture)
		pellet.launch(
			zone.global_position + xp_pellet_offset(k),
			target,
			XP_PELLET_FLIGHT + XP_PELLET_FLIGHT_STEP * k,
			XP_PELLET_SPREAD + XP_PELLET_SPREAD_STEP * k)

func _on_auto_toggled(on: bool) -> void:
	_technique.auto_cycle = on
	_show_auto_state(on)

func _on_close_pressed() -> void:
	ActionManager.stop_action()

func _on_stop_cycling() -> void:
	_technique.stop_cycling()
