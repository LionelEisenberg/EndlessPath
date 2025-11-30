class_name VitalsManager
extends Node

#-----------------------------------------------------------------------------
# TYPE ALIASES
#-----------------------------------------------------------------------------

# Use the AttributeType from CharacterAttributesData
const AttributeType = CharacterAttributesData.AttributeType

#-----------------------------------------------------------------------------
# CHARACTER ADVENTURE DATA REFERENCES
#-----------------------------------------------------------------------------
@export var character_attributes_data: CharacterAttributesData:
	set(value):
		character_attributes_data = value
		_update_combat_max()

@export var is_player: bool = false

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

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if is_player and character_attributes_data:
		Log.warn("VitalsManager: is_player and character_attributes_data should never be set at the same time")
	
	if is_player:
		var f = func(): character_attributes_data = CharacterManager.get_total_attributes_data()
		CharacterManager.base_attribute_changed.connect(f)
		f.call()

func _update_combat_max() -> void:
	max_health = _get_max_health()
	max_stamina = _get_max_stamina()
	max_madra = _get_max_madra()

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

func initialize_current_values() -> void:
	current_health = max_health
	current_stamina = max_stamina
	current_madra = max_madra

## Apply damage to current health
func apply_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)

## Apply healing to current health
func apply_healing(amount: float) -> void:
	current_health = min(max_health, current_health + amount)

#-----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS
#-----------------------------------------------------------------------------

## Calculate maximum health based on Body attribute
func _get_max_health() -> float:
	return 100.0 + (character_attributes_data.get_attribute(AttributeType.BODY) * 10.0)

## Calculate maximum stamina based on Body attribute
func _get_max_stamina() -> float:
	return 50.0 + (character_attributes_data.get_attribute(AttributeType.BODY) * 5.0)

## Calculate maximum madra based on Foundation attribute
func _get_max_madra() -> float:
	return 50.0 + (character_attributes_data.get_attribute(AttributeType.FOUNDATION) * 10.0)
