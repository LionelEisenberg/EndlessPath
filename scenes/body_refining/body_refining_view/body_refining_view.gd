class_name BodyRefiningView
extends Control

## BodyRefiningView
## The body refining board: a lacquer board in the zone view's map gap, the
## cycling board's frame, where the player plays sets of the equipped drill. Above,
## the action's name, the drill's name, Esc and a close button, and under them
## what a Perfect rep of the drill pays at the player's Strength, with Strength's
## icon and the Health heart in place of the words ("Perfect rep · [arm] +6 XP ·
## [heart] +4", "[arm] capped" in brass at the cap): the place a player sees
## Strength's second job, the Health a rep restores. Then the carved figure with
## its arms rimmed in brass, what the drill trains, with the drill's stage over it
## (DrillPlay), and a footer line: how to start, how to play while a set runs, and
## what the last set paid once it ends ("Last set · [arm] +48 XP · [heart] +32 ·
## 6 / 10 perfect"), until the next lift. A finished set also writes one line to
## the log, in words. A name or a line too long for its width wraps, never cut,
## and the board grows under it.
##
## Each scored rep sends its pellets from the stone into the cultivator cabinet:
## a burst of PELLETS_BY_TIER pellets in each trained stat's ramp to that stat's
## cell, and as many in the Health ramp to the Health orb, each carrying an even
## share of what the stat took or the rep restored, which the cabinet holds out of
## its readout until each lands. A part that paid nothing sends nothing: no
## Strength pellets at the cap, no Health pellets at full Health. MainView hands
## the cabinet over in cultivator_plate; with none, or while the board is hidden,
## no pellet flies.
##
## The root covers the screen and stops every click, as the Tribulation board's
## does, so none reaches the chest or the map while the board is up: a mouse press
## anywhere is the drill's (_gui_input()), and keys come from the view state
## through handle_press_event(). The close button and Esc stop the action.
## halt() stops a set in progress and frees the pellets in flight, which show
## what they carried at once, leaving the board drawn for a transition to shrink
## it away; close() also hides it. get_board_rect() says where the board stands.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const Tier = DrillRules.Tier
const AttributeType = CharacterAttributesData.AttributeType

## The footer before a set, and while one runs.
const READY: String = "Hold Space or the mouse button to lift the stone."
const LIFT: String = "Let go with the stone in the brass band."

## The pay line's and the result line's words.
const PAY_LEAD: String = "Perfect rep"
const RESULT_LEAD: String = "Last set"
const PERFECT_SET_TEXT: String = "Perfect set"
const XP_FORMAT: String = " %s XP"
const CAPPED_TEXT: String = " capped"
const FULL_TEXT: String = " full"
const PERFECT_COUNT_FORMAT: String = "%d / %d perfect"
## Joins the parts of a line: a space, a middle dot (U+00B7) and a space.
const SEPARATOR: String = " · "
## The colours the pay line sets apart from its tan: a figure in cream, capped in brass.
const VALUE_COLOR: String = "#F0E8D8"
const CAPPED_COLOR: String = "#D4A84A"
## The icons stand 16 px in a line, as the other mini icons do.
const ICON_SIZE: int = 16
const HEALTH_ICON: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_health_ai.png")

## A scored rep's pellets of each kind, by its tier: a burst from the stone that
## pops up to BURST_REACH px, then homes in, the first landing PELLET_FLIGHT s
## after the rep and each next one PELLET_FLIGHT_STEP s after (as cycling's stat
## puffs).
const PELLETS_BY_TIER: Dictionary = {Tier.PERFECT: 4, Tier.GOOD: 3, Tier.OK: 2}
const PELLET_FLIGHT: float = 0.6
const PELLET_FLIGHT_STEP: float = 0.05
const BURST_REACH: float = 28.0

const _PELLET_SCENE: PackedScene = preload("res://scenes/common/lacquer/lacquer_pellet/lacquer_pellet.tscn")

## The board's rows from the screen's top. The figure box stands at FIGURE_TOP, or
## lower to stand under the pay line's last line (the figure's art leaves its top
## empty, so the box may reach FIGURE_OVERLAP px up under it), and the footer
## FOOTER_GAP under the figure. The board keeps its art's height until the footer
## comes within BOARD_ROOM of its bottom (the bottom frame, the corner brackets
## and the shadow), then grows to keep that room.
const FIGURE_TOP: float = 104.0
const FIGURE_OVERLAP: float = 6.0
const FOOTER_GAP: float = 14.0
const BOARD_ROOM: float = 30.0

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

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The cultivator cabinet the pellets fly into. MainView sets it; with none, no
## pellet is sent.
var cultivator_plate: CultivatorPlate = null

## The drill the board plays: the equipped one.
var _drill: DrillData = null

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
	visibility_changed.connect(_on_visibility_changed)
	_show_status(READY)

## Every mouse event that reaches the root, on the board or anywhere around it, is
## the board's: a press of the drill's button lifts, and nothing passes beneath.
func _gui_input(event: InputEvent) -> void:
	_drill_play.handle_press_event(event)
	accept_event()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Readies the board for `action`: its name over the equipped drill's, the pay
## line, the drill's stage empty and the footer's READY line. The last set's line
## is forgotten, so reopening starts clean.
func setup(action: ZoneActionData) -> void:
	_action_label.text = action.action_name if action != null else ""
	_load_equipped_drill()
	_show_status(READY)

## Stops a set in progress (its reps stay paid) and frees the pellets in flight,
## which show what they carried at once. The board stays drawn.
func halt() -> void:
	_drill_play.stop_set()
	_free_pellets()

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

## Returns the footer's line for a finished set, as BBCode: "Last set · ",
## "Perfect set · " for ten Perfect reps, then each trained stat's icon and the XP
## it took (or "capped"), the Health heart and what the set restored (or "full"),
## and, short of a perfect set, how many reps were Perfect.
static func result_line(result: DrillSetResult) -> String:
	var parts: PackedStringArray = [RESULT_LEAD]
	if result.is_perfect():
		parts.append(PERFECT_SET_TEXT)
	parts.append(_result_stat_part(result, AttributeType.STRENGTH))
	if result.drill != null and result.drill.has_minor_stat():
		parts.append(_result_stat_part(result, result.drill.minor_stat as AttributeType))
	var health_text: String = FULL_TEXT if result.is_health_full() else " +%d" % roundi(result.get_health_restored())
	parts.append(_icon(HEALTH_ICON) + health_text)
	if not result.is_perfect():
		parts.append(PERFECT_COUNT_FORMAT % [result.count_of(Tier.PERFECT), result.get_rep_count()])
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

## Sets the board up for `drill`: its name, its stage and the pay line.
func _apply_drill(drill: DrillData) -> void:
	_drill = drill
	_title_label.text = drill.drill_name if drill != null else ""
	_drill_play.setup(drill)
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

static func _pay_stat_part(stat: AttributeType, xp: float, capped: bool) -> String:
	if capped:
		return _stat_label(stat) + _value(CAPPED_TEXT, CAPPED_COLOR)
	return _stat_label(stat) + _value(XP_FORMAT % LacquerText.rate(xp), VALUE_COLOR)

static func _result_stat_part(result: DrillSetResult, stat: AttributeType) -> String:
	if result.is_stat_capped(stat):
		return _stat_label(stat) + CAPPED_TEXT
	return _stat_label(stat) + XP_FORMAT % ("+%d" % roundi(result.get_stat_xp(stat)))

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
## line, the figure, then the footer. A line too long for its width wraps and
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
	_status_text.position.y = _figure_box.position.y + _figure_box.size.y + FOOTER_GAP
	_fit_rich(_status_text)
	var board_bottom: float = _status_text.position.y + _status_text.size.y + BOARD_ROOM
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
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_set_started() -> void:
	_show_status(LIFT)

## A rep was judged and paid: a burst of its tier's pellets for each stat that took
## XP, to the stat's cell, and for the Health it restored, to the Health orb, each
## pellet holding its share out of the cabinet until it lands. A hidden board sends
## nothing: what was paid is in the stats and the pool already, and shows at once.
func _on_rep_judged(judgement: DrillRun.Judgement, health: float, stat_xp: Dictionary) -> void:
	var count: int = PELLETS_BY_TIER.get(judgement.tier, 0)
	if cultivator_plate == null or count == 0 or not is_visible_in_tree():
		return
	var from: Vector2 = _drill_play.get_stone_global_center()
	for stat: AttributeType in stat_xp:
		var xp: float = stat_xp[stat]
		if xp <= 0.0:
			continue
		var share: float = xp / count
		for pellet: LacquerPellet in _burst(from, cultivator_plate.get_stat_cell_global_position(stat), count, LacquerPellet.stat_ramp(stat)):
			cultivator_plate.hold_stat_xp(stat, share)
			pellet.delivered.connect(cultivator_plate.release_stat_xp.bind(stat, share))
	if health > 0.0:
		var health_share: float = health / count
		for pellet: LacquerPellet in _burst(from, cultivator_plate.get_health_orb_global_position(), count, LacquerPellet.Ramp.HEALTH):
			cultivator_plate.hold_health(health_share)
			pellet.delivered.connect(cultivator_plate.release_health.bind(health_share))

## A set was played to its last rep: the footer shows what it paid, and one line
## goes to the log.
func _on_set_completed(result: DrillSetResult) -> void:
	_status_text.text = result_line(result)
	_relayout_board()
	LogManager.log_message("[color=cyan]%s[/color]" % result.log_line())

func _on_equipped_drill_changed(drill: DrillData) -> void:
	_apply_drill(drill)
	_show_status(READY)

func _on_close_pressed() -> void:
	ActionManager.stop_action()

## The board hides: the pellets in flight are freed, so none shows up mid-flight
## when it opens again.
func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_free_pellets()
