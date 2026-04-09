class_name Toolbar
extends PanelContainer
## Bottom toolbar with system menu buttons and gold display.

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _gold_label: Label = %GoldLabel

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	ResourceManager.gold_changed.connect(_on_gold_changed)
	_update_gold()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _update_gold() -> void:
	_gold_label.text = str(int(ResourceManager.get_gold()))

func _on_gold_changed(_new_amount: float) -> void:
	_update_gold()
