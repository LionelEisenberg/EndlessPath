class_name CombatResourceManager
extends Node

#-----------------------------------------------------------------------------
# CHARACTER ADVENTURE DATA REFERENCES
#-----------------------------------------------------------------------------
@export var character_attributes_data: CharacterAttributesData:
	set(value):
		character_attributes_data = value
		_update_combat_resources()

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal health_changed(new_health: float)
signal madra_changed(new_madra: float)
signal stamina_changed(new_stamina: float)

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var max_health: float = 100.0
var current_health: float:
	set(value):
		current_health = value
		health_changed.emit(current_health)
	
var max_madra: float = 100.0
var current_madra: float:
	set(value):
		current_madra = value
		madra_changed.emit(current_madra)
	
var max_stamina: float = 100.0
var current_stamina: float:
	set(value):
		current_stamina = value
		stamina_changed.emit(current_stamina)

func _ready() -> void:
	_update_combat_resources()

func _update_combat_resources() -> void:
	max_health = _get_max_health()
	current_health = max_health

	max_stamina = _get_max_stamina()
	current_stamina = max_stamina
	
	max_madra = _get_max_madra()
	current_madra = max_madra

#-----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS
#-----------------------------------------------------------------------------

## Calculate maximum health based on Body attribute
func _get_max_health() -> float:
	var body = CharacterManager.get_body()
	if character_attributes_data != null:
		body = character_attributes_data.body
	return 100.0 + (body * 10.0)

## Calculate maximum stamina based on Body attribute
func _get_max_stamina() -> float:
	var body = CharacterManager.get_body()
	if character_attributes_data != null:
		body = character_attributes_data.body
	return 50.0 + (body * 5.0)

## Calculate maximum madra based on Foundation attribute
func _get_max_madra() -> float:
	var foundation = CharacterManager.get_foundation()
	if character_attributes_data != null:
		foundation = character_attributes_data.foundation
	return 50.0 + (foundation * 10.0)
