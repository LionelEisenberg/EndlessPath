class_name CyclingTabPanel
extends PanelContainer

## CyclingTabPanel
## Manages tab switching between Resources and Techniques content.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal technique_change_request(data: CyclingTechniqueData)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _resources_tab_button: Button = %ResourcesTabButton
@onready var _techniques_tab_button: Button = %TechniquesTabButton
@onready var _resources_content: Control = %ResourcesContent
@onready var _techniques_content: Control = %TechniquesContent
@onready var _technique_list_container: VBoxContainer = %TechniqueListContainer

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

enum Tab { RESOURCES, TECHNIQUES }
var _active_tab: Tab = Tab.RESOURCES

var _technique_slot_scene: PackedScene = preload("res://scenes/cycling/cycling_technique_selector/cycling_technique_slot.tscn")
var _technique_list: CyclingTechniqueList = null
var _current_technique_data: CyclingTechniqueData = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_resources_tab_button.pressed.connect(_on_resources_tab_pressed)
	_techniques_tab_button.pressed.connect(_on_techniques_tab_pressed)
	_switch_tab(Tab.RESOURCES)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Initialize with technique list data.
func setup(technique_list: CyclingTechniqueList) -> void:
	_technique_list = technique_list

## Update which technique is currently equipped (for highlight state).
func set_current_technique(data: CyclingTechniqueData) -> void:
	_current_technique_data = data
	_update_technique_slot_states()

## Switch to the Resources tab.
func show_resources_tab() -> void:
	_switch_tab(Tab.RESOURCES)

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _on_resources_tab_pressed() -> void:
	_switch_tab(Tab.RESOURCES)

func _on_techniques_tab_pressed() -> void:
	_switch_tab(Tab.TECHNIQUES)
	_populate_technique_list()

func _switch_tab(tab: Tab) -> void:
	_active_tab = tab
	_resources_content.visible = (tab == Tab.RESOURCES)
	_techniques_content.visible = (tab == Tab.TECHNIQUES)

	_resources_tab_button.add_theme_color_override("font_color",
		ThemeConstants.ACCENT_GOLD if tab == Tab.RESOURCES else ThemeConstants.TEXT_MUTED)
	_techniques_tab_button.add_theme_color_override("font_color",
		ThemeConstants.ACCENT_GOLD if tab == Tab.TECHNIQUES else ThemeConstants.TEXT_MUTED)

func _populate_technique_list() -> void:
	if _technique_list == null:
		return

	for child in _technique_list_container.get_children():
		child.queue_free()

	for technique_data: CyclingTechniqueData in _technique_list.cycling_techniques:
		var slot: Control = _technique_slot_scene.instantiate()
		_technique_list_container.add_child(slot)
		slot.setup(technique_data)
		slot.set_equipped(_current_technique_data == technique_data)
		slot.slot_selected.connect(_on_technique_slot_selected)

func _update_technique_slot_states() -> void:
	for slot in _technique_list_container.get_children():
		if slot.has_method("set_equipped"):
			slot.set_equipped(slot.technique_data == _current_technique_data)

func _on_technique_slot_selected(data: CyclingTechniqueData) -> void:
	technique_change_request.emit(data)
