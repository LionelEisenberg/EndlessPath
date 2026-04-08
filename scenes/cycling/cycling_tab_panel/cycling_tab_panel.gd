class_name CyclingTabPanel
extends TabContainer

## CyclingTabPanel
## TabContainer with Resources and Techniques tabs.
## Resources tab holds the CyclingResourcePanel. Techniques tab holds a scrollable technique list.
## Style via CyclingTabContainer theme type variation in PixelTheme.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal technique_change_request(data: CyclingTechniqueData)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _technique_list_container: VBoxContainer = %TechniqueListContainer

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _technique_slot_scene: PackedScene = preload("res://scenes/cycling/cycling_technique_slot/cycling_technique_slot.tscn")
var _technique_list: CyclingTechniqueList = null
var _current_technique_data: CyclingTechniqueData = null
var _list_dirty: bool = true

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	set_tab_title(0, "Resources")
	set_tab_title(1, "Techniques")
	tab_alignment = TabBar.ALIGNMENT_CENTER
	tab_changed.connect(_on_tab_changed)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Initialize with technique list data.
func setup(technique_list: CyclingTechniqueList) -> void:
	_technique_list = technique_list
	_populate_technique_list()

## Update which technique is currently equipped (for highlight state).
func set_current_technique(data: CyclingTechniqueData) -> void:
	_current_technique_data = data
	_update_technique_slot_states()

## Switch to the Resources tab (index 0).
func show_resources_tab() -> void:
	current_tab = 0

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _on_tab_changed(tab_index: int) -> void:
	if tab_index == 1 and _list_dirty:
		_populate_technique_list()

func _populate_technique_list() -> void:
	if _technique_list == null:
		return

	_list_dirty = false

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
