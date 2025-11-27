extends Control

signal slot_selected(data)

var technique_data: CyclingTechniqueData = null
var is_selected: bool = false

@onready var panel_container: PanelContainer = %CyclingTechniquePanelContainer
@onready var icon_texture_rect: TextureRect = %CyclingTechniqueIcon
@onready var info_label: RichTextLabel = %CyclingTechniqueInfo

const COLOR_SELECTED := Color(0.3, 0.5, 1.0, 1.0)
const COLOR_HOVER := Color(0.85, 0.85, 0.95, 1.0)
const COLOR_NORMAL := Color(1.0, 1.0, 1.0, 1.0)

func _ready() -> void:
	self.mouse_entered.connect(_on_mouse_entered)
	self.mouse_exited.connect(_on_mouse_exited)

## Sets up the slot with the given technique data.
func setup(data: CyclingTechniqueData) -> void:
	technique_data = data
	_update_info()
	_set_selected(false)

## Sets the selected state of the slot.
func _set_selected(selected: bool) -> void:
	is_selected = selected
	if panel_container:
		panel_container.modulate = COLOR_SELECTED if selected else COLOR_NORMAL

func _update_info() -> void:
	if not info_label:
		return
	if technique_data == null:
		info_label.text = "[b]Unknown Technique[/b]"
		return
	var technique_name := technique_data.technique_name
	var madra_per_cycle := technique_data.base_madra_per_cycle
	var duration := technique_data.cycle_duration
	info_label.text = "[b]%s[/b]\nMadra/cycle: %.1f\nDuration: %.0f s" % [technique_name, madra_per_cycle, duration]

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_selected.emit(technique_data)

func _on_mouse_entered() -> void:
	if not is_selected and panel_container:
		panel_container.modulate = COLOR_HOVER

func _on_mouse_exited() -> void:
	if not is_selected and panel_container:
		panel_container.modulate = COLOR_NORMAL
