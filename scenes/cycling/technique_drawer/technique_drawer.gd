class_name TechniqueDrawer
extends Control
## A technique drawer in the zone chest while the player cycles: a lacquer
## drawer with one learned technique's icon, name, NEW seal, IN USE tag and one
## detail line. It copies ZoneActionButton's nodes and positions (lacquer kit
## §5.5 › Card internals, positions local to the drawer). It is 392 x 72 while
## its name and its detail line fit a line each. A longer one wraps, never cut,
## and the drawer grows by its extra lines, never wider: its face stretches the
## plain band under the icon socket, and the list that holds it re-measures.
##
## The drawer in use (the equipped technique) is pulled out to (-2, -2) on the
## running face and tagged IN USE. A left press on any other drawer equips its
## technique through CyclingManager and flashes the brass frame; a press on the
## drawer in use does nothing. Hover shows the hover frame. The NEW seal clears
## when the pointer leaves the drawer (the technique is marked seen then), or at
## once on a press that equips it, but never as the pointer arrives: the chest
## turns to the drawers under the cursor that has just clicked the Wilderness
## Cycling card, so its first move could land on a seal the player never saw.
##
## The drawer does not listen to CyclingManager: the list that holds the
## drawers calls refresh() on every one of them when the equipped technique
## changes.

## Emitted when the drawer's height changes: its name or its detail line took
## more lines or fewer.
signal height_changed

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const IN_USE_TAG_TEXT: String = "IN USE"
const FLASH_TIMES: int = 2
## Where the drawer in use is drawn, pulled out of the list.
const IN_USE_OFFSET: Vector2 = Vector2(-2, -2)

## The drawer's width, and its height with one line of name and one of detail.
const DRAWER_WIDTH: float = 392.0
const SHORT_HEIGHT: float = 72.0
## The detail line starts this far under the name's last line, and the drawer
## ends this far under the detail line's (kit §5.5: the name at y 14, the
## detail at 38).
const DETAIL_GAP: float = 4.0
const ROOM_UNDER_DETAIL: float = 16.0
## The faces grow by stretching their rows 60 and 61, the plain band under the
## icon socket, which match: the rows above and under them show as drawn.
const FACE_STRETCH_ROW: int = 60
const FACE_STRETCH_ROWS: int = 2

const DRAWER_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/lacquer_drawer_ai.png")
const DRAWER_RUN_TEXTURE: Texture2D = preload("res://assets/ui/lacquer/lacquer_drawer_run_ai.png")

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The technique the drawer shows (set by setup). The list finds a drawer by its
## id.
var technique: CyclingTechniqueData = null

@onready var _drawer: Control = %Drawer
@onready var _face: NinePatchRect = %Face
@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _new_seal: TextureRect = %NewSeal
@onready var _tag: TextureRect = %Tag
@onready var _tag_label: Label = %TagLabel
@onready var _detail: Label = %Detail
@onready var _hover_frame: LacquerFrameOverlay = %HoverFrame
@onready var _flash_frame: LacquerFrameOverlay = %FlashFrame

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	if technique != null:
		_apply_technique()

## Shows the technique on the drawer: its icon, name and detail line, then what
## depends on state (refresh). Before the drawer is ready it is applied in
## _ready.
func setup(data: CyclingTechniqueData) -> void:
	technique = data
	if is_node_ready() and technique != null:
		_apply_technique()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns a technique's detail line: "200 Madra · 15 s cycle · 4 zones", with
## "no zones" or "1 zone" where the count is 0 or 1.
static func detail_text(data: CyclingTechniqueData) -> String:
	var zones: String
	match data.cycling_zones.size():
		0:
			zones = "no zones"
		1:
			zones = "1 zone"
		var count:
			zones = "%d zones" % count
	return "%d Madra · %d s cycle · %s" % [roundi(data.base_madra_per_cycle), roundi(data.cycle_duration), zones]

## Re-applies what depends on state: the face and its offset, the IN USE tag and
## its colour, and the NEW seal with the text laid out around it. The list
## calls it on every drawer when the equipped technique changes.
func refresh() -> void:
	if not is_node_ready() or technique == null:
		return
	var in_use: bool = is_in_use()
	_drawer.position = IN_USE_OFFSET if in_use else Vector2.ZERO
	_face.texture = DRAWER_RUN_TEXTURE if in_use else DRAWER_TEXTURE
	_tag.visible = in_use
	_tag_label.text = IN_USE_TAG_TEXT
	if in_use:
		_tag_label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_CREAM)
	else:
		_tag_label.remove_theme_color_override(&"font_color")
	_refresh_new_seal()

## Returns true when the drawer's technique is the equipped one.
func is_in_use() -> bool:
	return technique != null and CyclingManager.get_equipped_technique() == technique

## Returns true while the NEW seal shows (the technique has not been seen).
func is_new_shown() -> bool:
	return _new_seal.visible

## Flashes the brass frame over the drawer twice (300 ms on, 300 ms off).
func flash() -> void:
	_flash_frame.flash(FLASH_TIMES)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _apply_technique() -> void:
	_icon.texture = technique.icon
	_title.text = technique.technique_name
	_detail.text = detail_text(technique)
	refresh()

## Shows the NEW seal while the technique is unseen, then lays the text out
## around it.
func _refresh_new_seal() -> void:
	_new_seal.visible = not CyclingManager.is_technique_seen(technique.id)
	_layout_text()

## Lays the text out: the title row the activity cards share, wrapping, then the
## detail line under the name's last line, wrapping inside its width, and the
## drawer tall enough for both, on even px. Tells the list when the height
## changes.
func _layout_text() -> void:
	ZoneActionButton.layout_title_row(_title, _new_seal, _tag, true)
	_detail.position.y = _title.position.y + _title.size.y + DETAIL_GAP
	_detail.size = Vector2(_detail.size.x, 2.0 * ceilf(_detail.get_minimum_size().y / 2.0))
	var height: float = maxf(SHORT_HEIGHT, _detail.position.y + _detail.size.y + ROOM_UNDER_DETAIL)
	var changed: bool = height != custom_minimum_size.y
	custom_minimum_size = Vector2(DRAWER_WIDTH, height)
	size = custom_minimum_size
	_drawer.size = custom_minimum_size
	_fit_face()
	if changed:
		height_changed.emit()

## Fits the face to the drawer: its texture at file size, taller by what the
## drawer grew, which the band under the socket takes.
func _fit_face() -> void:
	var texture_size: Vector2 = _face.texture.get_size()
	_face.patch_margin_top = FACE_STRETCH_ROW
	_face.patch_margin_bottom = int(texture_size.y) - FACE_STRETCH_ROW - FACE_STRETCH_ROWS
	_face.size = texture_size + Vector2(0.0, custom_minimum_size.y - SHORT_HEIGHT)

func _mark_seen() -> void:
	if technique == null:
		return
	CyclingManager.mark_technique_seen(technique.id)
	_refresh_new_seal()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT or technique == null:
		return
	if is_in_use():
		return
	CyclingManager.equip_technique(technique.id)
	# The equipped technique only counts as seen while it is equipped: record it
	# so its NEW seal stays cleared once another technique is in use.
	CyclingManager.mark_technique_seen(technique.id)
	refresh()
	flash()

func _on_mouse_entered() -> void:
	_hover_frame.show()

func _on_mouse_exited() -> void:
	_hover_frame.hide()
	_mark_seen()
