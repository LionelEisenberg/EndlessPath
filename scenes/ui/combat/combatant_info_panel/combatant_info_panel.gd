class_name CombatantInfoPanel
extends Panel

@onready var health_bar: ResourceBar = %HealthProgressBar
@onready var madra_bar: ResourceBar = %MadraProgressBar
@onready var stamina_bar: ResourceBar = %StaminaProgressBar

var vitals_manager: VitalsManager

func _ready() -> void:
	health_bar.label_prefix = "Health"
	madra_bar.label_prefix = "Madra"
	stamina_bar.label_prefix = "Stamina"

## Resets the panel.
func reset() -> void:
	Log.info("CombatantInfoPanel: Resetting %s" % name)
	
	vitals_manager = null

## Sets up the panel with the given resource manager.
func setup(p_vitals_manager: VitalsManager) -> void:
	vitals_manager = p_vitals_manager
	
	if not vitals_manager.health_changed.is_connected(update_labels):
		vitals_manager.health_changed.connect(update_labels.unbind(1))
	
	if not vitals_manager.madra_changed.is_connected(update_labels):
		vitals_manager.madra_changed.connect(update_labels.unbind(1))
	
	if not vitals_manager.stamina_changed.is_connected(update_labels):
		vitals_manager.stamina_changed.connect(update_labels.unbind(1))
	
	update_labels()

## Updates the labels with current resource values.
func update_labels() -> void:
	if vitals_manager:
		health_bar.update_values(vitals_manager.current_health, vitals_manager.max_health, vitals_manager.health_regen)
		madra_bar.update_values(vitals_manager.current_madra, vitals_manager.max_madra, vitals_manager.madra_regen)
		stamina_bar.update_values(vitals_manager.current_stamina, vitals_manager.max_stamina, vitals_manager.stamina_regen)
