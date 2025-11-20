class_name CombatantInfoPanel
extends Panel

@onready var label = $Label
@onready var label2 = $Label2
@onready var label3 = $Label3

var resource_manager: CombatResourceManager

func _ready() -> void:
	pass # Replace with function body.

func reset() -> void:
	Log.info("CombatantInfoPanel: Resetting %s" % name)
	
	resource_manager = null

func setup(p_resource_manager: CombatResourceManager) -> void:
	resource_manager = p_resource_manager
	
	if not resource_manager.health_changed.is_connected(update_labels):
		resource_manager.health_changed.connect(update_labels.unbind(1))
	
	if not resource_manager.madra_changed.is_connected(update_labels):
		resource_manager.madra_changed.connect(update_labels.unbind(1))
	
	if not resource_manager.stamina_changed.is_connected(update_labels):
		resource_manager.stamina_changed.connect(update_labels.unbind(1))
	
	update_labels()

func update_labels() -> void:
	if resource_manager:
		label.text = "Health: %s / %s" % [resource_manager.current_health, resource_manager.max_health]
		label2.text = "Madra: %s / %s" % [resource_manager.current_madra, resource_manager.max_madra]
		label3.text = "Stamina: %s / %s" % [resource_manager.current_stamina, resource_manager.max_stamina]
