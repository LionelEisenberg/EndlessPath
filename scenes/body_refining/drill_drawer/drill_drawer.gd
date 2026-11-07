class_name DrillDrawer
extends Control
## A drill drawer in the zone chest while the body refining board is up: a
## lacquer drawer with one learned drill's icon, name, NEW seal, IN USE tag, how
## it plays and its rep ("Keep the needle in the brass · 4 s reps"), and what it
## trains, each stat by its mini icon and name ("Trains [arm] Strength and [heart]
## Body"). It copies TechniqueDrawer's layout in a scene of its own (lacquer kit
## §5.5, positions local to the drawer) and shares no code with it. It is 392 x 92
## while its name and its two lines fit a line each. A longer one wraps, never
## cut, and the drawer grows by its extra lines, never wider, on the cards' faces
## (ZoneActionButton.fit_face), and the list that holds it re-measures.
##
## The drawer in use (the equipped drill, the one the board plays) is pulled out to
## (-2, -2) on the running face and tagged IN USE. A left press on any other drawer
## equips its drill through BodyRefiningManager, which saves it, and flashes the
## brass frame; a press on the drawer in use does nothing. Hover shows the hover
## frame. The NEW seal clears when the pointer leaves the drawer (the drill is
## marked seen then), or at once on a press that equips it, but never as the
## pointer arrives: the chest turns to the drawers under the cursor that has just
## clicked the training card, so its first move could land on a seal the player
## never saw.
##
## The drawer does not listen to BodyRefiningManager: the list that holds the
## drawers calls refresh() on every one of them when the equipped drill changes.

## Emitted when the drawer's height changes: its name or one of its lines took
## more lines or fewer.
signal height_changed

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const AttributeType = CharacterAttributesData.AttributeType

const IN_USE_TAG_TEXT: String = "IN USE"
const FLASH_TIMES: int = 2
## Where the drawer in use is drawn, pulled out of the list.
const IN_USE_OFFSET: Vector2 = Vector2(-2, -2)

## The drawer's width, and its height with one line of name, one of detail and
## one of what it trains.
const DRAWER_WIDTH: float = 392.0
const SHORT_HEIGHT: float = 92.0
## The detail line starts this far under the name's last line, the Trains line
## this far under the detail's, and the drawer ends this far under the Trains
## line's last line.
const DETAIL_GAP: float = 4.0
const TRAINS_GAP: float = 2.0
const ROOM_UNDER_TRAINS: float = 16.0

## The detail line: how the drill plays, then its rep.
const DETAIL_FORMAT: String = "%s · %s s reps"
## The Trains line's words, and its stat icons' size.
const TRAINS_LEAD: String = "Trains "
const TRAINS_JOIN: String = " and "
const ICON_SIZE: int = 16

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The drill the drawer shows (set by setup). The list finds a drawer by its id.
var drill: DrillData = null

@onready var _drawer: Control = %Drawer
@onready var _face: NinePatchRect = %Face
@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _new_seal: TextureRect = %NewSeal
@onready var _tag: TextureRect = %Tag
@onready var _tag_label: Label = %TagLabel
@onready var _detail: Label = %Detail
@onready var _trains: RichTextLabel = %Trains
@onready var _hover_frame: LacquerFrameOverlay = %HoverFrame
@onready var _flash_frame: LacquerFrameOverlay = %FlashFrame

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	if drill != null:
		_apply_drill()

## Shows the drill on the drawer: its icon, name and lines, then what depends on
## state (refresh). Before the drawer is ready it is applied in _ready.
func setup(data: DrillData) -> void:
	drill = data
	if is_node_ready() and drill != null:
		_apply_drill()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns a drill's detail line: how it plays and its rep, "Keep the needle in
## the brass · 4 s reps".
static func detail_text(data: DrillData) -> String:
	var seconds: float = data.rep_seconds
	var seconds_text: String = str(roundi(seconds)) if is_equal_approx(seconds, roundf(seconds)) else String.num(seconds, 1)
	return DETAIL_FORMAT % [data.play_hint, seconds_text]

## Returns a drill's Trains line in BBCode: Strength, then the drill's other stat,
## each by its mini icon and its name.
static func trains_bbcode(data: DrillData) -> String:
	var stats: Array[AttributeType] = [AttributeType.STRENGTH]
	if data.has_minor_stat():
		stats.append(data.minor_stat as AttributeType)
	var parts: PackedStringArray = []
	for stat: AttributeType in stats:
		var mini: Texture2D = StatDisplay.mini_icon_of(stat)
		var icon: String = "[img=%dx%d]%s[/img] " % [ICON_SIZE, ICON_SIZE, mini.resource_path] if mini != null else ""
		parts.append(icon + StatDisplay.name_of(stat))
	return TRAINS_LEAD + TRAINS_JOIN.join(parts)

## Re-applies what depends on state: the drawer's offset, the IN USE tag and its
## colour, and the NEW seal with the text and the face laid out around it. The
## list calls it on every drawer when the equipped drill changes.
func refresh() -> void:
	if not is_node_ready() or drill == null:
		return
	var in_use: bool = is_in_use()
	_drawer.position = IN_USE_OFFSET if in_use else Vector2.ZERO
	_tag.visible = in_use
	_tag_label.text = IN_USE_TAG_TEXT
	if in_use:
		_tag_label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_CREAM)
	else:
		_tag_label.remove_theme_color_override(&"font_color")
	_refresh_new_seal()

## Returns true when the drawer's drill is the equipped one.
func is_in_use() -> bool:
	return drill != null and BodyRefiningManager.get_equipped_drill() == drill

## Returns true while the NEW seal shows (the drill has not been seen).
func is_new_shown() -> bool:
	return _new_seal.visible

## Flashes the brass frame over the drawer twice (300 ms on, 300 ms off).
func flash() -> void:
	_flash_frame.flash(FLASH_TIMES)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _apply_drill() -> void:
	_icon.texture = drill.icon
	_title.text = drill.drill_name
	_detail.text = detail_text(drill)
	_trains.text = trains_bbcode(drill)
	refresh()

## Shows the NEW seal while the drill is unseen, then lays the text out around it.
func _refresh_new_seal() -> void:
	_new_seal.visible = not BodyRefiningManager.is_drill_seen(drill.id)
	_layout_text()

## Lays the text out: the title row the activity cards share, wrapping, then the
## detail line under the name's last line and the Trains line under the detail's,
## each wrapping inside its width, and the drawer tall enough for all three, on
## even px. Tells the list when the height changes.
func _layout_text() -> void:
	ZoneActionButton.layout_title_row(_title, _new_seal, _tag)
	_detail.position.y = _title.position.y + _title.size.y + DETAIL_GAP
	_detail.size = Vector2(_detail.size.x, 2.0 * ceilf(_detail.get_minimum_size().y / 2.0))
	_trains.position.y = _detail.position.y + _detail.size.y + TRAINS_GAP
	_trains.size = Vector2(_trains.size.x, 2.0 * ceilf(_trains.get_content_height() / 2.0))
	var height: float = maxf(SHORT_HEIGHT, _trains.position.y + _trains.size.y + ROOM_UNDER_TRAINS)
	var changed: bool = height != custom_minimum_size.y
	custom_minimum_size = Vector2(DRAWER_WIDTH, height)
	size = custom_minimum_size
	_drawer.size = custom_minimum_size
	ZoneActionButton.fit_face(_face, is_in_use(), custom_minimum_size)
	if changed:
		height_changed.emit()

func _mark_seen() -> void:
	if drill == null:
		return
	BodyRefiningManager.mark_drill_seen(drill.id)
	_refresh_new_seal()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT or drill == null:
		return
	if is_in_use():
		return
	BodyRefiningManager.equip_drill(drill.id)
	# The equipped drill only counts as seen while it is equipped: record it so
	# its NEW seal stays cleared once another drill is in use.
	BodyRefiningManager.mark_drill_seen(drill.id)
	refresh()
	flash()

func _on_mouse_entered() -> void:
	_hover_frame.show()

func _on_mouse_exited() -> void:
	_hover_frame.hide()
	_mark_seen()
