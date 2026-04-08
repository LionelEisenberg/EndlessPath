extends Control
## Collapsible log window that shows/hides on toggle.

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _rich_text_label: RichTextLabel = %RichTextLabel
@onready var _log_panel: PanelContainer = %LogPanel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _is_collapsed: bool = true

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	if LogManager:
		LogManager.message_logged.connect(_on_message_logged)
		LogManager.visibility_toggled.connect(toggle_log)
	_log_panel.visible = false

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Toggles the log panel visibility.
func toggle_log() -> void:
	_is_collapsed = not _is_collapsed
	_log_panel.visible = not _is_collapsed

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _on_message_logged(bbcode: String) -> void:
	_rich_text_label.append_text(bbcode + "\n")
