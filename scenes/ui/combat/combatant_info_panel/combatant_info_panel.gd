class_name CombatantInfoPanel
extends Panel

@onready var health_bar: ResourceBar = %HealthProgressBar
@onready var madra_bar: ResourceBar = %MadraProgressBar
@onready var stamina_bar: ResourceBar = %StaminaProgressBar

var resource_manager: CombatResourceManager

func _ready() -> void:
	pass # Replace with function body.

## Resets the panel.
func reset() -> void:
	Log.info("CombatantInfoPanel: Resetting %s" % name)
	
	resource_manager = null

## Sets up the panel with the given resource manager.
func setup(p_resource_manager: CombatResourceManager) -> void:
	resource_manager = p_resource_manager
	
	if not resource_manager.health_changed.is_connected(update_labels):
		resource_manager.health_changed.connect(update_labels.unbind(1))
	
	if not resource_manager.madra_changed.is_connected(update_labels):
		resource_manager.madra_changed.connect(update_labels.unbind(1))
	
	if not resource_manager.stamina_changed.is_connected(update_labels):
		resource_manager.stamina_changed.connect(update_labels.unbind(1))
	
	update_labels()

## Updates the labels with current resource values.
func update_labels() -> void:
	if resource_manager:
		health_bar.update_values(resource_manager.current_health, resource_manager.max_health)
		madra_bar.update_values(resource_manager.current_madra, resource_manager.max_madra)
		stamina_bar.update_values(resource_manager.current_stamina, resource_manager.max_stamina)
