extends Control
## Collapsible log window that expands/collapses with a smooth tween animation.

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _rich_text_label: RichTextLabel = %RichTextLabel
@onready var _log_panel: PanelContainer = %LogPanel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _is_collapsed: bool = true
var _tween: Tween

const EXPANDED_HEIGHT: float = 180.0
const COLLAPSED_HEIGHT: float = 0.0
const TWEEN_DURATION: float = 0.35

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	if LogManager:
		LogManager.message_logged.connect(_on_message_logged)
		LogManager.visibility_toggled.connect(toggle_log)
	_log_panel.custom_minimum_size.y = COLLAPSED_HEIGHT
	_log_panel.visible = false

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Toggles the log panel between collapsed and expanded states.
func toggle_log() -> void:
	_is_collapsed = not _is_collapsed
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if _is_collapsed:
		_tween.tween_property(_log_panel, "custom_minimum_size:y", COLLAPSED_HEIGHT, TWEEN_DURATION)
		_tween.tween_callback(func() -> void: _log_panel.visible = false)
	else:
		_log_panel.visible = true
		_tween.tween_property(_log_panel, "custom_minimum_size:y", EXPANDED_HEIGHT, TWEEN_DURATION)

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _on_message_logged(bbcode: String) -> void:
	_rich_text_label.append_text(bbcode + "\n")
