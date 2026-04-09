class_name LogWindow
extends PanelContainer
## Draggable, collapsible log window.
## Always visible as a title bar. Expand to see log messages.
## Drag the title bar to reposition anywhere on screen.

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _title_bar: PanelContainer = %TitleBar
@onready var _content_panel: PanelContainer = %ContentPanel
@onready var _rich_text_label: RichTextLabel = %RichTextLabel
@onready var _collapse_button: Button = %CollapseButton

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _is_collapsed: bool = true
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	LogManager.message_logged.connect(_on_message_logged)
	LogManager.visibility_toggled.connect(toggle_collapse)
	_collapse_button.pressed.connect(_on_collapse_pressed)
	_title_bar.gui_input.connect(_on_titlebar_input)
	_content_panel.visible = false

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Toggles the log content panel visibility.
func toggle_collapse() -> void:
	_is_collapsed = not _is_collapsed
	_content_panel.visible = not _is_collapsed
	_collapse_button.text = "▲" if not _is_collapsed else "▼"

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _on_titlebar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging = true
			_drag_offset = event.global_position - global_position
		else:
			_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		global_position = event.global_position - _drag_offset

func _on_collapse_pressed() -> void:
	toggle_collapse()

func _on_message_logged(bbcode: String) -> void:
	if _rich_text_label:
		_rich_text_label.append_text(bbcode + "\n")
