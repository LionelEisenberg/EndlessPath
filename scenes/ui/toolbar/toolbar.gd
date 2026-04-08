class_name Toolbar
extends PanelContainer
## Bottom toolbar with system menu buttons, gold display, and log toggle.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal log_toggled

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _gold_label: Label = %GoldLabel
@onready var _log_toggle_button: Button = %LogToggleButton

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	ResourceManager.gold_changed.connect(_on_gold_changed)
	_log_toggle_button.pressed.connect(_on_log_toggle_pressed)
	_update_gold()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _update_gold() -> void:
	_gold_label.text = str(int(ResourceManager.get_gold()))

func _on_gold_changed(_new_amount: float) -> void:
	_update_gold()

func _on_log_toggle_pressed() -> void:
	log_toggled.emit()
