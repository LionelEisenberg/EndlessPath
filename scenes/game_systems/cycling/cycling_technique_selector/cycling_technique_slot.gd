extends MarginContainer

signal slot_selected(data)

var technique_data: CyclingTechniqueData = null
var is_selected: bool = false

@onready var panel_container: PanelContainer = %CyclingTechniquePanelContainer
@onready var icon_texture_rect: TextureRect = %CyclingTechniqueIcon
@onready var info_label: RichTextLabel = %CyclingTechniqueInfo

const COLOR_SELECTED := Color(0.3, 0.5, 1.0, 1.0)
const COLOR_HOVER := Color(0.85, 0.85, 0.95, 1.0)
const COLOR_NORMAL := Color(1.0, 1.0, 1.0, 1.0)

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(data: CyclingTechniqueData):
	technique_data = data
	_update_info()
	_set_selected(false)

func _update_info():
	if not info_label:
		return
	if technique_data == null:
		info_label.text = "[b]Unknown Technique[/b]"
		return
	var technique_name := technique_data.technique_name if technique_data.has_method("technique_name") else "Technique"
	var rate := technique_data.base_madra_per_second if technique_data.has_method("base_madra_per_second") else 0.0
	var duration := technique_data.cycle_duration if technique_data.has_method("cycle_duration") else 0.0
	info_label.text = "[b]%s[/b]\nMadra/sec: %.1f\nDuration: %.0f s" % [technique_name, rate, duration]
	print(info_label.text)

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_selected.emit(technique_data)
		_set_selected(true)

func _set_selected(selected: bool):
	is_selected = selected
	if panel_container:
		panel_container.modulate = COLOR_SELECTED if selected else COLOR_NORMAL

func _on_mouse_entered():
	if not is_selected and panel_container:
		panel_container.modulate = COLOR_HOVER

func _on_mouse_exited():
	if not is_selected and panel_container:
		panel_container.modulate = COLOR_NORMAL
