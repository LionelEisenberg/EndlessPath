class_name ZonePanel
extends Control

## The zone chest at the zone view's top right (lacquer kit §5.5 and §0):
## the zone's header (tile thumbnail, name, About), the Now strip while an
## idle action runs, the Activities header with "N here", and the scrolling
## activity list.
## The chest hugs its content: max(176, list top + list height + 24) tall.
## A list too long for the space down to local 992 scrolls, folds 8 px under
## its last whole drawer, keeps 40 px under it, and the chest snaps to the
## bottom line (local 1032) when that is within 64 px. About opens the lore
## inline under the Now strip and pushes the Activities header and the list
## down 276 px; About, Esc or a click outside closes it. Esc closes it only
## while the zone view is MainView's active state: an overlay opened over the
## zone view (the inventory, say) takes Esc first.
## It rebuilds on zone_changed, action_completed and condition_unlocked, and
## scrolls to a card when ZoneManager.action_focus_requested asks.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The chest's slices: top and bottom heights; the middle tiles between.
const CHEST_TOP_HEIGHT: float = 128.0
const CHEST_BOTTOM_HEIGHT: float = 48.0
const MIN_CHEST_HEIGHT: float = 176.0
## The bottom line (screen 1056) and the lowest a list may reach (screen 1016).
const FULL_CHEST_HEIGHT: float = 1032.0
const LIST_BOTTOM_LIMIT: float = 992.0
## Snap to the bottom line when the chest ends this close to it.
const SNAP_DISTANCE: float = 64.0
## Room under a list that fits, and under a list that scrolls (the rail's
## end cap clears the corner strap).
const GAP_UNDER_LIST: float = 24.0
const GAP_UNDER_SCROLLING_LIST: float = 40.0

## The Activities header's top and the gap from it to the list, with the Now
## strip and without it (kit §0: header at screen 204 or 102, list at 232 or
## 132).
const HEADER_TOP_WITH_STRIP: float = 180.0
const HEADER_TOP_COLLAPSED: float = 78.0
const LIST_GAP_WITH_STRIP: float = 28.0
const LIST_GAP_COLLAPSED: float = 30.0
## Yatra One at 20 px is 30 px tall on the header's 24 px line: its row sits
## 3 px above the line's top, as the mock's half-leading puts it.
const HEADER_TEXT_RAISE: float = 3.0

## The lore panel's top with the strip and without it; opening it pushes the
## header and the list down by its 264 px and 12.
const LORE_TOP_WITH_STRIP: float = 182.0
const LORE_TOP_COLLAPSED: float = 80.0
const LORE_PUSH: float = 276.0
## About's word sits 2 px lower while it is pressed in (the lore is open).
const ABOUT_TEXT_DROP: float = 2.0

## Header thumbnails by tile variant (Spirit Valley's river is 6); any other
## tile shows the basic one.
const RIVER_TILE_VARIANT: int = 6
const THUMB_RIVER: Texture2D = preload("res://assets/ui/lacquer/lacquer_thumb_ai.png")
const THUMB_BASIC: Texture2D = preload("res://assets/ui/lacquer/lacquer_thumb_basic_ai.png")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _chest_mid: Control = %ChestMid
@onready var _chest_bottom: Control = %ChestBottom
@onready var _thumb: TextureRect = %Thumb
@onready var _zone_name_label: Label = %ZoneNameLabel
@onready var _about_button: TextureButton = %AboutButton
@onready var _about_label: Label = %AboutLabel
@onready var _about_hover: LacquerFrameOverlay = %AboutHover
@onready var _now_strip: NowStrip = %NowStrip
@onready var _activities_header: Control = %ActivitiesHeader
@onready var _count_label: Label = %CountLabel
@onready var _activity_list: ActivityList = %ActivityList
@onready var _lore_panel: Control = %LorePanel
@onready var _lore_text: Label = %LoreText

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The MainView whose state stack says whether the zone view is the active
## state. _ready finds it among the panel's ancestors when it is not set;
## with none, the zone view counts as active while the chest shows.
var main_view: MainView = null

var _zone_id: String = ""
var _rebuild_queued: bool = false

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	ZoneManager.zone_changed.connect(_on_zone_changed)
	ZoneManager.action_completed.connect(_on_action_completed)
	ZoneManager.action_focus_requested.connect(scroll_to_action)
	UnlockManager.condition_unlocked.connect(_on_condition_unlocked)
	_about_button.toggled.connect(_on_about_toggled)
	_about_button.mouse_entered.connect(_about_hover.show)
	_about_button.mouse_exited.connect(_about_hover.hide)
	_now_strip.visibility_changed.connect(_relayout)
	_now_strip.strip_pressed.connect(_on_strip_pressed)
	_activity_list.layout_changed.connect(_relayout)
	_activity_list.card_pressed_while_running.connect(_now_strip.flash)
	if main_view == null:
		main_view = find_main_view()
	_set_lore_open(false)
	_rebuild()

## Esc closes the lore while the player can see it: the chest shows and the
## zone view is the active state. Otherwise Esc goes on to MainView, which
## hands it to the overlay on top.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if not _lore_panel.is_visible_in_tree() or not _is_zone_view_active():
		return
	_close_lore()
	get_viewport().set_input_as_handled()

## A left click anywhere outside the lore and About closes the lore; the
## wheel does not. The click still reaches what it was aimed at: the lore
## closes at the end of the frame, after the GUI has hit-tested this press
## against the layout the player saw (closing moves the list up 276 px).
func _input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if _contains_event(_lore_panel, press) or _contains_event(_about_button, press):
		return
	_close_lore.call_deferred()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Scrolls the list until the action's card shows whole with 24 px around
## it, then flashes the card. Does nothing when the zone has no such card.
func scroll_to_action(action_id: String) -> void:
	_activity_list.scroll_to_action(action_id)

## Returns the action's card, or null when the list has none.
func get_card(action_id: String) -> Control:
	return _activity_list.get_card(action_id)

## Returns true while the Now strip shows (an idle action runs).
func is_now_strip_shown() -> bool:
	return _now_strip.visible

## Returns the nearest MainView among the panel's ancestors, or null.
func find_main_view() -> MainView:
	var node: Node = get_parent()
	while node != null:
		if node is MainView:
			return node as MainView
		node = node.get_parent()
	return null

#-----------------------------------------------------------------------------
# BUILD
#-----------------------------------------------------------------------------

## Rebuilds once at the end of the frame however many signals asked.
func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()

## Shows the current zone's header and cards. A new zone starts its list at
## the top; the same zone keeps its scroll.
func _rebuild() -> void:
	_rebuild_queued = false
	var zone: ZoneData = ZoneManager.get_current_zone()
	if zone == null:
		return
	var same_zone: bool = zone.zone_id == _zone_id
	_zone_id = zone.zone_id
	_zone_name_label.text = zone.zone_name
	_thumb.texture = THUMB_RIVER if zone.tile_variant_index == RIVER_TILE_VARIANT else THUMB_BASIC
	_lore_text.text = _lore_paragraphs(zone.description)
	_about_button.visible = zone.description != ""
	if not _about_button.visible:
		_close_lore()
	var actions: Array[ZoneActionData] = ZoneManager.get_available_actions(zone.zone_id)
	_count_label.text = "%d here" % actions.size()
	_activity_list.build(actions, same_zone)
	_relayout()

#-----------------------------------------------------------------------------
# LAYOUT
#-----------------------------------------------------------------------------

## Places the header, the list and the lore under the strip (or in its
## place), and sizes the list and the chest (kit §0).
func _relayout() -> void:
	if not is_node_ready():
		return
	var strip_shown: bool = _now_strip.visible
	var lore_open: bool = _lore_panel.visible
	var header_top: float = (HEADER_TOP_WITH_STRIP if strip_shown else HEADER_TOP_COLLAPSED) \
		+ (LORE_PUSH if lore_open else 0.0)
	var list_top: float = header_top + (LIST_GAP_WITH_STRIP if strip_shown else LIST_GAP_COLLAPSED)
	_lore_panel.position.y = LORE_TOP_WITH_STRIP if strip_shown else LORE_TOP_COLLAPSED
	_activities_header.position.y = header_top - HEADER_TEXT_RAISE

	var content_height: float = _activity_list.get_content_height()
	var max_list_height: float = LIST_BOTTOM_LIMIT - list_top
	var list_height: float = content_height
	var chest_height: float = maxf(MIN_CHEST_HEIGHT, list_top + content_height + GAP_UNDER_LIST)
	if content_height > max_list_height:
		list_height = _fold_height(max_list_height)
		chest_height = list_top + list_height + GAP_UNDER_SCROLLING_LIST
		if FULL_CHEST_HEIGHT - chest_height <= SNAP_DISTANCE:
			chest_height = FULL_CHEST_HEIGHT
	_activity_list.position.y = list_top
	_activity_list.size.y = list_height
	size.y = chest_height
	_chest_mid.size.y = chest_height - CHEST_TOP_HEIGHT - CHEST_BOTTOM_HEIGHT
	_chest_bottom.position.y = chest_height - CHEST_BOTTOM_HEIGHT

## The tallest list height up to max_height that folds under a whole drawer,
## or max_height when not even the first drawer fits.
func _fold_height(max_height: float) -> float:
	var height: float = max_height
	var found: bool = false
	for fold: float in _activity_list.get_fold_heights():
		if fold <= max_height:
			height = fold
			found = true
	return height if found else max_height

#-----------------------------------------------------------------------------
# LORE
#-----------------------------------------------------------------------------

## The description's paragraphs one line break apart: the lore label adds
## the kit's 10 px between paragraphs itself, so blank lines are dropped.
func _lore_paragraphs(description: String) -> String:
	var paragraphs: PackedStringArray = []
	for line: String in description.split("\n"):
		if line.strip_edges() != "":
			paragraphs.append(line.strip_edges())
	return "\n".join(paragraphs)

func _close_lore() -> void:
	if _about_button.button_pressed:
		_about_button.button_pressed = false
	else:
		_set_lore_open(false)

## Shows or hides the lore, presses About in or out, and listens for Esc and
## outside clicks only while the lore is open.
func _set_lore_open(open: bool) -> void:
	_lore_panel.visible = open
	_about_label.position.y = ABOUT_TEXT_DROP if open else 0.0
	set_process_input(open)
	set_process_unhandled_input(open)
	_relayout()

## True when no overlay sits over the zone view: the zone view is MainView's
## base state and nothing is pushed on top of it.
func _is_zone_view_active() -> bool:
	if main_view == null:
		return true
	return main_view.state_stack.is_empty() and main_view.base_current_state == main_view.zone_view_state

func _contains_event(control: Control, press: InputEventMouseButton) -> bool:
	if not control.is_visible_in_tree():
		return false
	var local := control.make_input_local(press) as InputEventMouseButton
	return Rect2(Vector2.ZERO, control.size).has_point(local.position)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_zone_changed(_zone_data: ZoneData) -> void:
	_close_lore()
	_queue_rebuild()

func _on_action_completed(_action_id: String) -> void:
	_queue_rebuild()

func _on_condition_unlocked(_condition_id: String) -> void:
	_queue_rebuild()

func _on_about_toggled(open: bool) -> void:
	_set_lore_open(open)

func _on_strip_pressed() -> void:
	var current: ZoneActionData = ActionManager.get_current_action()
	if current != null:
		scroll_to_action(current.action_id)
