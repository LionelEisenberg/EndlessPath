class_name CombatantInfoPanel
extends Control

@export var profile_texture: Texture2D

@onready var profile_icon_rect = %ProfileIconRect
@onready var health_bar: ResourceBar = %HealthProgressBar
@onready var madra_bar: ResourceBar = %MadraProgressBar
@onready var stamina_bar: ResourceBar = %StaminaProgressBar

# Buff References
@onready var buff_info_panel: Control = %BuffInfo
@onready var buff_container: HBoxContainer = %BuffContainer

# Ability References
@onready var abilities_panel: AbilitiesPanel = %AbilitiesPanel

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal ability_selected(instance: CombatAbilityInstance)

var vitals_manager: VitalsManager
var buff_manager: CombatBuffManager
var ability_manager: CombatAbilityManager

# Dictionary to map buff_id -> BuffIcon instance
var active_buff_icons: Dictionary = {}

var buff_icon_scene: PackedScene = preload("res://scenes/ui/combat/buff_icon/buff_icon.tscn")


func _ready() -> void:
	health_bar.label_prefix = "Health"
	madra_bar.label_prefix = "Madra"
	stamina_bar.label_prefix = "Stamina"
	profile_icon_rect.texture = profile_texture
	
	# Initially hide buff panel
	if buff_info_panel:
		buff_info_panel.visible = false
	
	# Initially hide ability panel
	if abilities_panel:
		abilities_panel.visible = false

## Resets the panel completely.
func reset() -> void:
	Log.info("CombatantInfoPanel: Resetting %s" % name)
	vitals_manager = null
	_cleanup_buffs()
	_cleanup_abilities()

#-----------------------------------------------------------------------------
# SETUP METHODS
#-----------------------------------------------------------------------------

## Sets up the panel with the given vitals manager.
func setup_vitals(p_vitals_manager: VitalsManager) -> void:
	vitals_manager = p_vitals_manager
	
	if not vitals_manager:
		return
	
	# Connect signals if not already connected
	if not vitals_manager.health_changed.is_connected(update_labels):
		vitals_manager.health_changed.connect(update_labels.unbind(1))
	
	if not vitals_manager.madra_changed.is_connected(update_labels):
		vitals_manager.madra_changed.connect(update_labels.unbind(1))
	
	if not vitals_manager.stamina_changed.is_connected(update_labels):
		vitals_manager.stamina_changed.connect(update_labels.unbind(1))
	
	update_labels()

## Sets up the panel with the given buff manager.
## If null is passed, buffs are cleared and panel is hidden.
func setup_buffs(p_buff_manager: CombatBuffManager) -> void:
	# Always clean up previous state/icons first
	_cleanup_buffs()
	
	buff_manager = p_buff_manager
	
	if buff_manager:
		buff_info_panel.visible = true
		
		# Connect signals
		buff_manager.buff_applied.connect(_on_buff_applied)
		buff_manager.buff_removed.connect(_on_buff_removed)
		buff_manager.buff_refreshed.connect(_on_buff_refreshed)
		buff_manager.buff_stacked.connect(_on_buff_stacked)
		
		# Auto-cleanup when manager is destroyed
		buff_manager.tree_exiting.connect(_on_buff_manager_exiting)
		
		# Load initial buffs if any
		for buff in buff_manager.active_buffs:
			_on_buff_applied(buff.buff_data.buff_id, buff.time_left)
			if buff.stack_count > 1:
				_on_buff_stacked(buff.buff_data.buff_id, buff.stack_count)
	else:
		buff_info_panel.visible = false

func setup_abilities(p_ability_manager: CombatAbilityManager) -> void:
	# Always clean up previous state/icons first
	_cleanup_abilities()
	
	ability_manager = p_ability_manager

	if ability_manager:
		abilities_panel.visible = true

		# Connect selection signal
		if not abilities_panel.ability_selected.is_connected(_on_ability_selected):
			abilities_panel.ability_selected.connect(_on_ability_selected)

		# Auto-cleanup when manager is destroyed
		ability_manager.tree_exiting.connect(_on_ability_manager_exiting)

		# Load initial abilities if any
		for ability_instance in ability_manager.abilities:
			_register_ability(ability_instance)
	else:
		abilities_panel.visible = false
	
	pass

#-----------------------------------------------------------------------------
# VITALS UPDATES
#-----------------------------------------------------------------------------

## Updates the labels with current resource values.
func update_labels() -> void:
	if vitals_manager:
		health_bar.update_values(vitals_manager.current_health, vitals_manager.max_health, vitals_manager.health_regen)
		madra_bar.update_values(vitals_manager.current_madra, vitals_manager.max_madra, vitals_manager.madra_regen)
		stamina_bar.update_values(vitals_manager.current_stamina, vitals_manager.max_stamina, vitals_manager.stamina_regen)

#-----------------------------------------------------------------------------
# BUFF HANDLERS
#-----------------------------------------------------------------------------

func _on_buff_applied(buff_id: String, duration: float) -> void:
	if not buff_manager: return
	
	var buff: ActiveBuff = buff_manager._find_buff_by_id(buff_id)
	if not buff: return
	
	# Check if icon already exists (shouldn't usually happen on applied, but safe to check)
	if active_buff_icons.has(buff_id):
		_on_buff_refreshed(buff_id, duration)
		return
		
	var icon = buff_icon_scene.instantiate() as BuffIcon
	buff_container.add_child(icon)
	icon.setup(buff.buff_data, duration, buff.stack_count)
	
	active_buff_icons[buff_id] = icon

func _on_buff_removed(buff_id: String) -> void:
	if active_buff_icons.has(buff_id):
		var icon = active_buff_icons[buff_id]
		icon.queue_free()
		active_buff_icons.erase(buff_id)

func _on_buff_refreshed(buff_id: String, new_duration: float) -> void:
	if active_buff_icons.has(buff_id):
		var icon = active_buff_icons[buff_id]
		icon.max_duration = new_duration # Reset max for bar scaling
		icon.update_duration(new_duration)

func _on_buff_stacked(buff_id: String, stack_count: int) -> void:
	if active_buff_icons.has(buff_id):
		var icon = active_buff_icons[buff_id]
		icon.update_stacks(stack_count)

func _on_buff_manager_exiting() -> void:
	_cleanup_buffs()
	buff_info_panel.visible = false

func _cleanup_buffs() -> void:
	# Disconnect signals if manager still valid
	if buff_manager and is_instance_valid(buff_manager):
		if buff_manager.buff_applied.is_connected(_on_buff_applied):
			buff_manager.buff_applied.disconnect(_on_buff_applied)
		if buff_manager.buff_removed.is_connected(_on_buff_removed):
			buff_manager.buff_removed.disconnect(_on_buff_removed)
		if buff_manager.buff_refreshed.is_connected(_on_buff_refreshed):
			buff_manager.buff_refreshed.disconnect(_on_buff_refreshed)
		if buff_manager.buff_stacked.is_connected(_on_buff_stacked):
			buff_manager.buff_stacked.disconnect(_on_buff_stacked)
		if buff_manager.tree_exiting.is_connected(_on_buff_manager_exiting):
			buff_manager.tree_exiting.disconnect(_on_buff_manager_exiting)
	
	buff_manager = null
	
	# Clear icons - use get_children for safety to remove anything in the container
	for child in buff_container.get_children():
		child.queue_free()
	active_buff_icons.clear()

#-----------------------------------------------------------------------------
# ABILITY HANDLERS
#-----------------------------------------------------------------------------

func _cleanup_abilities() -> void:
	if abilities_panel:
		abilities_panel.reset()
		if abilities_panel.ability_selected.is_connected(_on_ability_selected):
			abilities_panel.ability_selected.disconnect(_on_ability_selected)

func _on_ability_manager_exiting() -> void:
	_cleanup_abilities()
	abilities_panel.visible = false

func _register_ability(instance: CombatAbilityInstance) -> void:
	if not abilities_panel:
		Log.warn("AdventureCombat: No ability_bar assigned!")
		return
		
	abilities_panel.register_ability(instance)
	Log.info("AdventureCombat: Registered ability " + instance.ability_data.ability_name)

func _on_ability_selected(instance: CombatAbilityInstance) -> void:
	ability_selected.emit(instance)
