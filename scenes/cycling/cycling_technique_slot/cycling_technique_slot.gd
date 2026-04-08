extends Control

## CyclingTechniqueSlot
## A compact technique slot for the Techniques tab list.
## Click to equip. Shows equipped state with gold border.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal slot_selected(data: CyclingTechniqueData)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _name_label: Label = %TechniqueNameLabel
@onready var _stats_label: Label = %TechniqueStatsLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var technique_data: CyclingTechniqueData = null
var _is_equipped: bool = false

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Initialize the slot with technique data.
func setup(data: CyclingTechniqueData) -> void:
	technique_data = data
	_update_display()

## Set whether this technique is currently equipped.
func set_equipped(equipped: bool) -> void:
	_is_equipped = equipped
	_update_visual_state()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _update_display() -> void:
	if technique_data == null:
		_name_label.text = "Unknown"
		_stats_label.text = ""
		return

	_name_label.text = technique_data.technique_name
	var zones_count: int = technique_data.cycling_zones.size()
	_stats_label.text = "%.0f/cycle  %.0fs  %d zones" % [
		technique_data.base_madra_per_cycle,
		technique_data.cycle_duration,
		zones_count
	]

func _update_visual_state() -> void:
	if _name_label == null:
		return
	if _is_equipped:
		_name_label.add_theme_color_override("font_color", ThemeConstants.ACCENT_GOLD)
	else:
		_name_label.remove_theme_color_override("font_color")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_selected.emit(technique_data)

func _on_mouse_entered() -> void:
	if not _is_equipped and _name_label:
		_name_label.add_theme_color_override("font_color", ThemeConstants.ACCENT_GOLD)

func _on_mouse_exited() -> void:
	if not _is_equipped and _name_label:
		_name_label.remove_theme_color_override("font_color")
