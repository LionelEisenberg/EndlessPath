class_name DevPanel
extends Control

## The dev panel: a floating board of tabs over the game, which Ctrl+Shift+D opens
## and closes. The panel covers the screen and lets the mouse through; only its
## body, the title bar and the tabs under it, takes the mouse. The title bar drags
## the body, which always stays wholly on screen, and holds the time-speed picker.
## Closing the panel hides the body only, so the badge at the top centre still shows
## any time speed but ×1, and the warning stacked under it still shows
## "Not saving: <reason>" while saving is blocked (PersistenceManager), which no
## other screen says.
##
## The shell owns only the frame: the open state, the drag, the tab, the time
## speed, the badge, the warning and the two hotkeys, Ctrl+Shift+D and
## Ctrl+Shift+R, which restarts a preset session. Each tab is a scene of its own
## that calls the dev tools itself; the one thing the shell hands a tab is the
## adventure view, to the Adventure tab. The panel lives in the main scene, which a session switch
## frees and loads again, so its open state, place and tab live on DevManager and
## come back when the panel is built. Exempt from the lacquer look (STYLE_GUIDE.md,
## G11): it takes pixel_theme.tres from MainView, and its own dev_panel_theme.tres
## sizes its controls' text to match its labels.

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The adventure view, which _ready() hands to the Adventure tab.
@export var adventure_view: AdventureView

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _body: PanelContainer = %Body
@onready var _title_bar: PanelContainer = %TitleBar
@onready var _speed_option: OptionButton = %SpeedOption
@onready var _close_button: Button = %CloseButton
@onready var _tabs: TabContainer = %Tabs
@onready var _adventure_tab: DevAdventureTab = %AdventureTab
@onready var _speed_badge: PanelContainer = %SpeedBadge
@onready var _speed_badge_label: Label = %SpeedBadgeLabel
@onready var _save_warning: PanelContainer = %SaveWarning
@onready var _save_warning_label: Label = %SaveWarningLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## Where the pointer took hold of the body, from the body's top-left corner.
var _drag_offset: Vector2 = Vector2.ZERO

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	for speed: float in DevManager.TIME_SPEEDS:
		_speed_option.add_item(DevManager.time_speed_label(speed))
		_speed_option.set_item_metadata(_speed_option.item_count - 1, speed)
	_body.visible = DevManager.panel_open
	_move_body(_kept_on_screen(DevManager.panel_position))
	_tabs.current_tab = clampi(DevManager.panel_tab, 0, _tabs.get_tab_count() - 1)
	_show_speed(DevManager.get_time_speed())
	_show_save_block()
	_adventure_tab.set_adventure_view(adventure_view)
	_title_bar.gui_input.connect(_on_title_bar_input)
	_body.resized.connect(_on_body_resized)
	_close_button.pressed.connect(set_open.bind(false))
	_tabs.tab_changed.connect(_on_tab_changed)
	_speed_option.item_selected.connect(_on_speed_selected)
	DevManager.time_speed_changed.connect(_show_speed)
	PersistenceManager.save_block_changed.connect(_show_save_block)

## The two hotkeys, whatever view the game is in: Ctrl+Shift+D opens and closes the
## panel, and Ctrl+Shift+R restarts the preset in a preset session, open panel or
## not. Outside a preset session Ctrl+Shift+R is left alone and goes on as plain R,
## the fourth ability slot; a key the panel handles never reaches it (TechniqueDock
## reads it in _unhandled_input).
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not (key.ctrl_pressed and key.shift_pressed):
		return
	if key.keycode == KEY_D:
		toggle()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_R and DevManager.get_session_kind() == DevManager.SessionKind.PRESET:
		DevManager.restart_preset()
		get_viewport().set_input_as_handled()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Opens the panel when it is closed, and closes it when it is open.
func toggle() -> void:
	set_open(not is_open())

## Opens or closes the panel: shows or hides its body, and keeps the choice on
## DevManager for the panel built after a session switch. The badge stays.
func set_open(open: bool) -> void:
	_body.visible = open
	DevManager.panel_open = open

## True while the panel's body shows.
func is_open() -> bool:
	return _body.visible

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## Drags the body by its title bar: a left press takes hold of it where the pointer
## is, and each move with the left button held carries it along, on whole pixels.
func _on_title_bar_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		_drag_offset = press.global_position - _body.global_position
		return
	var motion := event as InputEventMouseMotion
	if motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_move_body(_kept_on_screen((motion.global_position - _drag_offset - global_position).round()))
		DevManager.panel_position = _body.position

## Keeps the body wholly on screen when it changes size. A wider tab makes it grow
## from its top-left corner, which could push its right or bottom edge past the
## screen's. Only a body that would stand past an edge is moved, and the place it
## moves to is kept on DevManager, as a drag's is.
func _on_body_resized() -> void:
	var kept: Vector2 = _kept_on_screen(_body.position)
	if kept == _body.position:
		return
	_move_body(kept)
	DevManager.panel_position = _body.position

## Keeps the tab on DevManager for the panel built after a session switch.
func _on_tab_changed(tab: int) -> void:
	DevManager.panel_tab = tab

## Sets the picked speed. DevManager then emits time_speed_changed, which shows it.
## A speed it refused (no speed the picker offers) leaves the one in force showing.
func _on_speed_selected(index: int) -> void:
	var speed: float = _speed_option.get_item_metadata(index)
	var refusal: String = DevManager.set_time_speed(speed)
	if refusal != "":
		Log.warn("DevPanel: %s" % refusal)
		_show_speed(DevManager.get_time_speed())

#-----------------------------------------------------------------------------
# PRIVATE HELPERS
#-----------------------------------------------------------------------------

## Shows the time speed in the picker, and in the badge, which hides at ×1.
func _show_speed(speed: float) -> void:
	_speed_option.select(_speed_index(speed))
	_speed_badge_label.text = DevManager.time_speed_label(speed)
	_speed_badge.visible = speed != 1.0

## Shows "Not saving: <reason>" while PersistenceManager has saving blocked, with
## the panel open or closed, and hides it otherwise. A session in memory is not
## blocked: it writes nothing by design, and the Saves tab says so.
func _show_save_block() -> void:
	_save_warning_label.text = "Not saving: %s" % PersistenceManager.get_block_reason()
	_save_warning.visible = PersistenceManager.is_save_blocked()

## The index of the picker's item for the speed, or -1 when it offers none.
func _speed_index(speed: float) -> int:
	for index: int in _speed_option.item_count:
		if _speed_option.get_item_metadata(index) == speed:
			return index
	return -1

## The body's place moved as little as it takes for the whole body to stand inside
## the panel, which covers the screen: a place kept at a larger window, or a drag
## past an edge, never leaves the title bar out of reach.
func _kept_on_screen(place: Vector2) -> Vector2:
	return place.clamp(Vector2.ZERO, (size - _body.size).max(Vector2.ZERO))

## Moves the body's top-left corner to `place` and keeps its own size, the size its
## offsets give it. Setting `position` alone sizes the offsets to the body's size
## now, which a wider tab may have grown, and the body would then stay that wide on
## a narrower tab. The end offsets come back to the resting size, which the grown
## content still overrides while it is there.
func _move_body(place: Vector2) -> void:
	var resting_size: Vector2 = Vector2(_body.offset_right - _body.offset_left, _body.offset_bottom - _body.offset_top)
	_body.position = place
	_body.set_end(place + resting_size)
