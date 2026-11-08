class_name BodyRefiningView
extends Control

## BodyRefiningView
## The body refining board: a lacquer board in the zone view's map gap, the
## cycling board's frame, where the player plays sets of the equipped drill. Above,
## the action's name, the drill's name, Esc and a close button, and under them
## what a Perfect rep of the drill pays at the player's Strength, with Strength's
## icon and the Health heart in place of the words ("Perfect rep · [arm] +6 XP ·
## [heart] +4", "[arm] capped" in brass at the cap): the place a player sees
## Strength's second job, the Health a rep restores. Then the drill's own scene
## (DrillPlay), and a footer line: the drill's own words for how to start, and for
## how to play while a set runs. A finished set goes to the zone chest's Last set
## card (#149: BodyRefiningManager.set_last_set_result()), which opening the board
## and picking another drill forget, and writes one line to the log, in words. A
## name or a line too long for its width wraps, never cut, and the board grows
## under it.
##
## Each scored rep sends its Health from where its stage says (the stone, the leaf
## caught) into the cultivator cabinet: a burst of PELLETS_BY_TIER pellets in the
## Health ramp to the Health orb, each carrying an even share of what the rep
## restored. Its XP waits in its bead for the set's end (#143), and when the set
## ends each bead that stored some sends a pellet in each trained stat's ramp to
## that stat's cell, carrying its share of what the stat took. The cabinet holds
## what a pellet carries out of its readout until it lands. A part that paid
## nothing sends nothing: no Strength pellets at the cap, no Health pellets at full
## Health. A set stopped short pays its XP with no pellets. MainView hands the
## cabinet over in cultivator_plate; with none, or while the board is hidden, no
## pellet flies.
##
## The root covers the screen and stops every click, as the Tribulation board's
## does, so none reaches the map while the board is up: a mouse press anywhere is
## the drill's (_gui_input()), but on the chest, which takes its own clicks while
## it shows (_has_point()) so that a drill drawer picks its drill and never plays.
## Keys come from the view state through handle_press_event(). The close button
## and Esc stop the action.
## halt() stops a set in progress and frees the pellets in flight, which show
## what they carried at once, leaving the board drawn for a transition to shrink
## it away; close() also hides it. get_board_rect() says where the board stands.
##
## Auto (#110): the footer's line sits beside an Auto toggle, cycling's. It is
## locked until the drill in use has played a perfect set: a lock beside a faded
## "Auto" on darkened art that takes no press, and on hover a tooltip says what
## unlocks it. A perfect set unlocks it: a brass floater over the stage, two flashes
## on the toggle (which stays off), and a yellow log line. With it on, DrillPlay
## plays sets by itself, the footer reading AUTO_LINE from an Auto set's start,
## through its end and the wait for the next. Toggling it ends a set in progress.
## The toggle's state is not saved.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const Tier = DrillRules.Tier
const AttributeType = CharacterAttributesData.AttributeType

## The pay line's words.
const PAY_LEAD: String = "Perfect rep"
const XP_FORMAT: String = " %s XP"
const CAPPED_TEXT: String = " capped"
## The footer while Auto plays, with Auto's rate. Like the drills' own lines
## (DrillData.ready_line, play_line), one line beside the Auto toggle (#144).
const AUTO_LINE: String = "Auto drills at %d%%. Turn it off for 100%%."
## The Auto toggle's text: on, off, and beside the lock while it is locked.
const AUTO_ON_TEXT: String = "Auto · on"
const AUTO_OFF_TEXT: String = "Auto · off"
const AUTO_LOCKED_TEXT: String = "Auto"
## The locked toggle's tooltip.
const UNLOCK_TITLE: String = "Unlock Auto"
const UNLOCK_HINT: String = "Play a perfect set: all ten reps Perfect."
## The unlock's floater and log line.
const UNLOCK_FLOATER_TEXT: String = "PERFECT SET · Auto unlocked"
const UNLOCK_LOG_FORMAT: String = "[color=yellow]%s · Auto unlocked[/color]"
## Px between the top of the Auto toggle and the bottom of its tooltip.
const TOOLTIP_GAP: float = 6.0
## How far under the figure box's top the unlock floater pops, centred on the board.
const UNLOCK_FLOATER_DROP: float = 286.0
## Joins the parts of a line: a space, a middle dot (U+00B7) and a space.
const SEPARATOR: String = " · "
## The colours the pay line sets apart from its tan: a figure in cream, capped in brass.
const VALUE_COLOR: String = "#F0E8D8"
const CAPPED_COLOR: String = "#D4A84A"
## The icons stand 16 px in a line, as the other mini icons do.
const ICON_SIZE: int = 16
const HEALTH_ICON: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_health_ai.png")

## A scored rep's pellets of each kind, by its tier: a burst from its stage that
## pops up to BURST_REACH px, then homes in, the first landing PELLET_FLIGHT s
## after the rep and each next one PELLET_FLIGHT_STEP s after (as cycling's stat
## puffs).
const PELLETS_BY_TIER: Dictionary = {Tier.PERFECT: 4, Tier.GOOD: 3, Tier.OK: 2, Tier.AUTO: 2}
const PELLET_FLIGHT: float = 0.6
const PELLET_FLIGHT_STEP: float = 0.05
const BURST_REACH: float = 28.0

const _PELLET_SCENE: PackedScene = preload("res://scenes/common/lacquer/lacquer_pellet/lacquer_pellet.tscn")

## The board's rows from the screen's top. The figure box stands at FIGURE_TOP, or
## lower to stand under the pay line's last line (the figure's art leaves its top
## empty, so the box may reach FIGURE_OVERLAP px up under it), and the footer
## FOOTER_GAP under the figure, so a footer line of two lines beside the Auto
## toggle still fits the art. The board keeps its art's height until the footer
## comes within BOARD_ROOM of its bottom (the bottom frame, the corner brackets
## and the shadow), then grows to keep that room.
const FIGURE_TOP: float = 104.0
const FIGURE_OVERLAP: float = 6.0
const FOOTER_GAP: float = 12.0
const BOARD_ROOM: float = 30.0

## The locked toggle: its art darkened, its label faded and moved right of the lock;
## pressed in, the label sits this many px lower. Cycling's.
const _AUTO_LOCKED_ART: Color = Color(0.42, 0.42, 0.42, 1.0)
const _AUTO_LOCKED_LABEL_ALPHA: float = 0.6
const _AUTO_LOCKED_LABEL_SHIFT: float = 10.0
const _AUTO_PRESS_DROP: float = 2.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _board: NinePatchRect = %Board
@onready var _action_label: Label = %ActionLabel
@onready var _title_label: Label = %TitleLabel
@onready var _close_button: TextureButton = %CloseButton
@onready var _pay_line: RichTextLabel = %PayLine
@onready var _figure_box: Control = %FigureBox
@onready var _drill_play: DrillPlay = %DrillPlay
@onready var _status_text: RichTextLabel = %StatusText
@onready var _effects_layer: Control = %EffectsLayer
@onready var _auto_toggle: TextureButton = %AutoToggle
@onready var _auto_label: Label = %AutoLabel
@onready var _auto_lock: TextureRect = %AutoLock
@onready var _auto_hover: LacquerFrameOverlay = %AutoHover
@onready var _auto_flash: LacquerFrameOverlay = %AutoFlash
@onready var _auto_tooltip: StatTooltip = %AutoTooltip
@onready var _unlock_floater: LacquerFloater = %UnlockFloater

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The cultivator cabinet the pellets fly into. MainView sets it; with none, no
## pellet is sent.
var cultivator_plate: CultivatorPlate = null
## The zone chest, which takes its own clicks while it shows. MainView sets it;
## with none, every click is the board's.
var chest: Control = null

## The drill the board plays: the equipped one.
var _drill: DrillData = null
## The set running's reps that stored XP, as [bead, the XP each stat stored]: what
## the beads pour when the set ends.
var _stored_by_bead: Array = []

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_drill_play.set_started.connect(_on_set_started)
	_drill_play.rep_judged.connect(_on_rep_judged)
	_drill_play.set_completed.connect(_on_set_completed)
	CharacterManager.stats_changed.connect(_refresh_pay_line)
	BodyRefiningManager.equipped_drill_changed.connect(_on_equipped_drill_changed)
	BodyRefiningManager.auto_unlocked.connect(_on_auto_unlocked)
	_auto_toggle.toggled.connect(_on_auto_toggled)
	_auto_toggle.mouse_entered.connect(_on_auto_hovered)
	_auto_toggle.mouse_exited.connect(_on_auto_unhovered)
	visibility_changed.connect(_on_visibility_changed)
	_refresh_auto()
	_show_ready_line()

## Keeps the unlock floater on its spot as it rises.
func _process(_delta: float) -> void:
	if _unlock_floater.visible:
		_place_unlock_floater()

## Every mouse event that reaches the root, on the board or anywhere around it, is
## the board's: a press of the drill's button plays, and nothing passes beneath.
func _gui_input(event: InputEvent) -> void:
	_drill_play.handle_press_event(event)
	accept_event()

## The root covers the screen but the chest while it shows, so the chest's drawers
## take their own clicks.
func _has_point(point: Vector2) -> bool:
	if chest != null and chest.is_visible_in_tree() and chest.get_global_rect().has_point(get_global_transform() * point):
		return false
	return Rect2(Vector2.ZERO, size).has_point(point)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Readies the board for `action`: its name over the equipped drill's, the pay
## line, the drill's stage at rest and the drill's line before a set on the
## footer. The last set is forgotten, so reopening starts clean.
func setup(action: ZoneActionData) -> void:
	_action_label.text = action.action_name if action != null else ""
	_load_equipped_drill()
	_show_ready_line()

## Stops a set in progress (its reps stay paid) and frees the pellets in flight,
## which show what they carried at once. The board stays drawn.
func halt() -> void:
	_drill_play.stop_set()
	_free_pellets()
	_unlock_floater.stop()
	_auto_tooltip.hide()

## Hides the board: halt(), then hide().
func close() -> void:
	halt()
	hide()

## Takes an event of the drill's input (drill_press) for the drill's stage and
## returns true for each one of them, false for any other event.
func handle_press_event(event: InputEvent) -> bool:
	return _drill_play.handle_press_event(event)

## Returns the board's rect in the screen's space, as laid out now: where a
## transition scales the view out of the cultivator to, and back into.
func get_board_rect() -> Rect2:
	return _board.get_global_rect()

## Returns the footer's text, without its icons.
func get_status_text() -> String:
	return _status_text.get_parsed_text()

## Returns whether the Auto toggle is locked: the drill in use has not played a
## perfect set yet.
func is_auto_locked() -> bool:
	return _drill == null or not BodyRefiningManager.is_auto_unlocked(_drill.id)

## Returns the pay line for a PERFECT rep of `drill`, as BBCode: "Perfect rep · ",
## Strength's icon and its XP, the drill's other stat's part when it has one, then
## the Health heart and `perfect_health`. A stat in `capped_stats` reads "capped"
## in brass in place of its XP. A stat with no mini icon yet goes by its name.
static func pay_line(drill: DrillData, capped_stats: Array, perfect_health: float) -> String:
	var parts: PackedStringArray = [PAY_LEAD]
	parts.append(_pay_stat_part(AttributeType.STRENGTH, drill.strength_xp_per_rep, capped_stats.has(AttributeType.STRENGTH)))
	if drill.has_minor_stat():
		var minor: AttributeType = drill.minor_stat as AttributeType
		parts.append(_pay_stat_part(minor, drill.minor_xp_per_rep, capped_stats.has(minor)))
	parts.append(_icon(HEALTH_ICON) + _value(" " + LacquerText.rate(perfect_health), VALUE_COLOR))
	return SEPARATOR.join(parts)

#-----------------------------------------------------------------------------
# THE DRILL AND THE LINES
#-----------------------------------------------------------------------------

## Plays the equipped drill. With none equipped, equips the first one unlocked,
## which BodyRefiningManager announces like any other switch.
func _load_equipped_drill() -> void:
	var equipped: DrillData = BodyRefiningManager.get_equipped_drill()
	if equipped == null:
		var unlocked: Array[DrillData] = BodyRefiningManager.get_unlocked_drills()
		if not unlocked.is_empty():
			BodyRefiningManager.equip_drill(unlocked[0].id)
			return
	_apply_drill(equipped)

## Sets the board up for `drill`: its name, its stage and the pay line. The last
## set is forgotten after the play is readied, since readying it finishes a set
## whose last rep had landed.
func _apply_drill(drill: DrillData) -> void:
	_drill = drill
	_title_label.text = drill.drill_name if drill != null else ""
	_drill_play.setup(drill)
	BodyRefiningManager.clear_last_set_result()
	_refresh_auto()
	_refresh_pay_line()

## The pay line for the drill at the player's Strength now.
func _refresh_pay_line() -> void:
	if _drill == null:
		_pay_line.text = ""
	else:
		var trained: Array[AttributeType] = [AttributeType.STRENGTH]
		if _drill.has_minor_stat():
			trained.append(_drill.minor_stat as AttributeType)
		var capped: Array = []
		for stat: AttributeType in trained:
			if CharacterManager.is_stat_capped(stat):
				capped.append(stat)
		_pay_line.text = pay_line(_drill, capped, BodyRefiningManager.perfect_rep_health(_drill))
	_relayout_board()

## Shows `text`, plain copy, on the footer.
func _show_status(text: String) -> void:
	_status_text.text = LacquerText.decimal_bbcode(text)
	_relayout_board()

## Shows the drill's line before a set on the footer.
func _show_ready_line() -> void:
	_show_status(_drill.ready_line if _drill != null else "")

## Shows Auto's line on the footer, while Auto plays.
func _show_auto_line() -> void:
	_show_status(AUTO_LINE % roundi(DrillRules.AUTO_RATE * 100.0))

static func _pay_stat_part(stat: AttributeType, xp: float, capped: bool) -> String:
	if capped:
		return _stat_label(stat) + _value(CAPPED_TEXT, CAPPED_COLOR)
	return _stat_label(stat) + _value(XP_FORMAT % LacquerText.rate(xp), VALUE_COLOR)

## The stat's mini icon, or its name while it has none.
static func _stat_label(stat: AttributeType) -> String:
	var mini: Texture2D = StatDisplay.mini_icon_of(stat)
	return _icon(mini) if mini != null else StatDisplay.name_of(stat)

static func _icon(texture: Texture2D) -> String:
	return "[img=%dx%d]%s[/img]" % [ICON_SIZE, ICON_SIZE, texture.resource_path]

## Plain `text` (its decimal points in Yatra) in `color`.
static func _value(text: String, color: String) -> String:
	return "[color=%s]%s[/color]" % [color, LacquerText.decimal_bbcode(text)]

#-----------------------------------------------------------------------------
# THE BOARD'S LAYOUT
#-----------------------------------------------------------------------------

## Stacks the board from its top: the action's name, the drill's name, the pay
## line, the figure, then the footer, where the footer's line sits beside the
## Auto toggle, the shorter centred on the taller. A line too long for its width
## wraps and
## pushes what is under it down, and the board grows by as much from its art's
## height (its plain middle stretches).
func _relayout_board() -> void:
	if not is_node_ready():
		return
	_fit_lines(_action_label)
	_title_label.position.y = _action_label.position.y + _action_label.size.y
	_fit_lines(_title_label)
	_pay_line.position.y = _title_label.position.y + _title_label.size.y
	_fit_rich(_pay_line)
	var pay_bottom: float = _pay_line.position.y + _pay_line.size.y
	_figure_box.position.y = maxf(FIGURE_TOP, 2.0 * ceilf((pay_bottom - FIGURE_OVERLAP) / 2.0))
	var footer_top: float = _figure_box.position.y + _figure_box.size.y + FOOTER_GAP
	_fit_rich(_status_text)
	var footer_height: float = maxf(_auto_toggle.size.y, _status_text.size.y)
	_auto_toggle.position.y = footer_top + (footer_height - _auto_toggle.size.y) / 2.0
	_status_text.position.y = footer_top + (footer_height - _status_text.size.y) / 2.0
	var board_bottom: float = footer_top + footer_height + BOARD_ROOM
	_board.size.y = maxf(_board.texture.get_size().y, board_bottom - _board.position.y)

## Makes a label as tall as its lines at its width.
static func _fit_lines(label: Label) -> void:
	label.size.y = label.get_minimum_size().y

## Makes a rich text line as tall as its lines at its width.
static func _fit_rich(rich: RichTextLabel) -> void:
	rich.size.y = rich.get_content_height()

#-----------------------------------------------------------------------------
# PELLETS
#-----------------------------------------------------------------------------

## Sends `count` pellets in `ramp` from `from` to `to` (PelletFlight.burst).
func _burst(from: Vector2, to: Vector2, count: int, ramp: LacquerPellet.Ramp) -> Array[LacquerPellet]:
	var pellets: Array[LacquerPellet] = []
	for flight: PelletFlight in PelletFlight.burst(from, to, count, PELLET_FLIGHT, PELLET_FLIGHT_STEP, BURST_REACH):
		var pellet: LacquerPellet = _PELLET_SCENE.instantiate() as LacquerPellet
		_effects_layer.add_child(pellet)
		pellet.set_ramp(ramp)
		pellet.fly(flight)
		pellets.append(pellet)
	return pellets

## Frees every pellet in flight. Each leaves the effects layer at once, so the
## layer holds none even before the frees land, and each delivers on leaving: the
## cabinet shows what it carried.
func _free_pellets() -> void:
	for child: Node in _effects_layer.get_children():
		if child is LacquerPellet:
			_effects_layer.remove_child(child)
			child.queue_free()

#-----------------------------------------------------------------------------
# AUTO
#-----------------------------------------------------------------------------

## Gates the toggle on the drill's unlock. Locked, it is off and takes no press;
## then DrillPlay follows the toggle, and the state shows.
func _refresh_auto() -> void:
	var locked: bool = is_auto_locked()
	if locked:
		_auto_toggle.set_pressed_no_signal(false)
	_auto_toggle.disabled = locked
	_auto_toggle.mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	_drill_play.set_auto_play(_auto_toggle.button_pressed)
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

## Shows the locked toggle's tooltip above it, right edges aligned.
func _show_auto_tooltip() -> void:
	_auto_tooltip.set_text(UNLOCK_TITLE, UNLOCK_HINT)
	var toggle: Rect2 = _auto_toggle.get_global_rect()
	_auto_tooltip.show_at(Vector2(toggle.end.x - _auto_tooltip.size.x, toggle.position.y - TOOLTIP_GAP - _auto_tooltip.size.y))

## Stands the unlock floater UNLOCK_FLOATER_DROP under the figure box's top,
## centred on the board on the 2 px grid, raised by its rise.
func _place_unlock_floater() -> void:
	var board: Rect2 = get_board_rect()
	var x: float = 2.0 * roundf((board.get_center().x - _unlock_floater.get_token_width() / 2.0) / 2.0)
	var y: float = _figure_box.get_global_rect().position.y + UNLOCK_FLOATER_DROP
	_unlock_floater.global_position = Vector2(x, y - _unlock_floater.get_rise())

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## A set started: the drill's line during a set, or AUTO_LINE for a set Auto plays.
func _on_set_started() -> void:
	_stored_by_bead.clear()
	if _drill_play.is_auto_set():
		_show_auto_line()
	else:
		_show_status(_drill.play_line)

## A rep was judged and paid: a burst of its tier's pellets for the Health it
## restored, to the Health orb, each pellet holding its share out of the cabinet
## until it lands. The XP it stored is noted for its bead to pour when the set
## ends. A hidden board sends nothing: what was paid is in the pool already, and
## shows at once.
func _on_rep_judged(judgement: DrillRun.Judgement, health: float, stat_xp: Dictionary) -> void:
	if stat_xp.values().any(func(xp: float) -> bool: return xp > 0.0):
		_stored_by_bead.append([judgement.rep, stat_xp])
	var count: int = PELLETS_BY_TIER.get(judgement.tier, 0)
	if cultivator_plate == null or count == 0 or not is_visible_in_tree():
		return
	if health > 0.0:
		var health_share: float = health / count
		for pellet: LacquerPellet in _burst(_drill_play.get_pellet_origin(judgement), cultivator_plate.get_health_orb_global_position(), count, LacquerPellet.Ramp.HEALTH):
			cultivator_plate.hold_health(health_share)
			pellet.delivered.connect(cultivator_plate.release_health.bind(health_share))

## Pours the set's XP from its beads: for each stat the set paid, a pellet from
## each bead that stored some of it, to the stat's cell, carrying the bead's share
## of what the stat took and holding it out of the cabinet until it lands.
func _pour(result: DrillSetResult) -> void:
	var poured: Array = _stored_by_bead
	_stored_by_bead = []
	if cultivator_plate == null or not is_visible_in_tree():
		return
	var stored: Dictionary = {}
	for entry: Array in poured:
		for stat: AttributeType in entry[1]:
			stored[stat] = stored.get(stat, 0.0) + entry[1][stat]
	for stat: AttributeType in stored:
		var taken: float = result.get_stat_xp(stat)
		if taken <= 0.0 or stored[stat] <= 0.0:
			continue
		for entry: Array in poured:
			var bead_xp: float = entry[1].get(stat, 0.0)
			if bead_xp <= 0.0:
				continue
			var share: float = taken * bead_xp / stored[stat]
			for pellet: LacquerPellet in _burst(_drill_play.get_bead_origin(entry[0]), cultivator_plate.get_stat_cell_global_position(stat), 1, LacquerPellet.stat_ramp(stat)):
				cultivator_plate.hold_stat_xp(stat, share)
				pellet.delivered.connect(cultivator_plate.release_stat_xp.bind(stat, share))

## A set was played to its last rep: its beads pour its XP, it becomes the chest's
## last set, the footer goes back to the drill's line before a set (AUTO_LINE while
## Auto plays on), and one line goes to the log. A perfect set unlocks its drill's
## Auto.
func _on_set_completed(result: DrillSetResult) -> void:
	_pour(result)
	BodyRefiningManager.set_last_set_result(result)
	if _drill_play.is_auto_running():
		_show_auto_line()
	else:
		_show_ready_line()
	LogManager.log_message("[color=cyan]%s[/color]" % result.log_line())
	if result.is_perfect() and result.drill != null and not BodyRefiningManager.is_auto_unlocked(result.drill.id):
		BodyRefiningManager.unlock_auto(result.drill.id)

## A drill's Auto unlocked. For the drill on the board: the toggle unlocks and
## flashes its brass frame twice (it stays off), the floater pops over the stage,
## and the log gets one line.
func _on_auto_unlocked(drill: DrillData) -> void:
	if drill != _drill:
		return
	_refresh_auto()
	_auto_flash.flash(DrillDrawer.FLASH_TIMES)
	_unlock_floater.pop(UNLOCK_FLOATER_TEXT, ThemeConstants.LACQUER_BRASS)
	_place_unlock_floater()
	LogManager.log_message(UNLOCK_LOG_FORMAT % drill.drill_name)

## The toggle turned: DrillPlay follows it, which ends a set in progress, and the
## footer goes back to the drill's line before a set until a set starts.
func _on_auto_toggled(_on: bool) -> void:
	_refresh_auto()
	if not _drill_play.is_set_running():
		_show_ready_line()

## The pointer reached the toggle: the tooltip while it is locked, else the
## hover frame.
func _on_auto_hovered() -> void:
	if is_auto_locked():
		_show_auto_tooltip()
	else:
		_auto_hover.show()

func _on_auto_unhovered() -> void:
	_auto_hover.hide()
	_auto_tooltip.hide()

func _on_equipped_drill_changed(drill: DrillData) -> void:
	_apply_drill(drill)
	_show_ready_line()

func _on_close_pressed() -> void:
	ActionManager.stop_action()

## The board hides: the pellets in flight are freed, so none shows up mid-flight
## when it opens again.
func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_free_pellets()
