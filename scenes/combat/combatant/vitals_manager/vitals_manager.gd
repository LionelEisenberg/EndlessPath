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
var health_regen: float = 0.0 # Amount per second
var current_health: float:
	set(value):
		current_health = value
		health_changed.emit(current_health)
	
var max_madra: float = 100.0
var madra_regen: float = 0.0 # Amount per second
var current_madra: float:
	set(value):
		current_madra = value
		madra_changed.emit(current_madra)
	
var max_stamina: float = 100.0
var stamina_regen: float = 0.0 # Amount per second
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

func _process(delta: float) -> void:
	if health_regen != 0:
		_apply_health_change(health_regen * delta)
	if stamina_regen != 0:
		_apply_stamina_change(stamina_regen * delta)
	if madra_regen != 0:
		_apply_madra_change(madra_regen * delta)

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

func apply_vitals_change(health_amount: float = 0.0, stamina_amount: float = 0.0, madra_amount: float = 0.0) -> void:
	_apply_health_change(health_amount)
	_apply_stamina_change(stamina_amount)
	_apply_madra_change(madra_amount)


#-----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS
#-----------------------------------------------------------------------------

## Adds or subtracts health, clamping to 0 and max health
func _apply_health_change(amount: float) -> void:
	var new_health = min(max_health, max(0.0, current_health + amount))
	if is_player:
		if abs(current_health - new_health) > 1.0:
			Log.info("VitalsManager: Health changed by %.1f from %.1f to %.1f" % [amount, current_health, new_health])
	current_health = new_health

## Adds or subtracts stamina, clamping to 0 and max stamina
func _apply_stamina_change(amount: float) -> void:
	var new_stamina = min(max_stamina, max(0.0, current_stamina + amount))
	if is_player:
		if abs(current_stamina - new_stamina) > 1.0:
			Log.info("VitalsManager: Stamina changed by %.1f from %.1f to %.1f" % [amount, current_stamina, new_stamina])
	current_stamina = new_stamina

## Adds or subtracts madra, clamping to 0 and max madra
func _apply_madra_change(amount: float) -> void:
	var new_madra = min(max_madra, max(0.0, current_madra + amount))
	if is_player:
		if abs(current_madra - new_madra) > 1.0:
			Log.info("VitalsManager: Madra changed by %.1f from %.1f to %.1f" % [amount, current_madra, new_madra])
	current_madra = new_madra

## Calculate maximum health based on Body attribute
func _get_max_health() -> float:
	return 100.0 + (character_attributes_data.get_attribute(AttributeType.BODY) * 10.0)

## Calculate maximum stamina based on Body attribute
func _get_max_stamina() -> float:
	return 50.0 + (character_attributes_data.get_attribute(AttributeType.BODY) * 5.0)

## Calculate maximum madra based on Foundation attribute
func _get_max_madra() -> float:
	return 50.0 + (character_attributes_data.get_attribute(AttributeType.FOUNDATION) * 10.0)
