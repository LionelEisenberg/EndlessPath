# CharacterManager.gd
# AUTOLOADED SINGLETON
extends Node

#-----------------------------------------------------------------------------
# TYPE ALIASES
#-----------------------------------------------------------------------------
# Use the AttributeType from CharacterAttributesData
const AttributeType = CharacterAttributesData.AttributeType

# Helper to get display name for an attribute type
static func get_attribute_display_name(attr_type: AttributeType) -> String:
	return CharacterAttributesData.AttributeType.keys()[attr_type].capitalize()

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------
signal base_attribute_changed(attribute_type: AttributeType, new_value: float)

#-----------------------------------------------------------------------------
# PLAYER DATA (Held by this manager)
#-----------------------------------------------------------------------------

# --- Persistent State (via shared SaveGameData) ---
var live_save_data: SaveGameData = null # Reference set in _ready

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_update_resources)
		_update_resources()
	else:
		Log.critical("CharacterManager: Could not get save_game_data from PersistenceManager on ready!")

func _update_resources() -> void:
	live_save_data = PersistenceManager.save_game_data
	if live_save_data == null:
		Log.critical("CharacterManager: live_save_data is null in _update_resources!")
		return
	
	# Emit signals for all attributes to update UI
	for attr_type in AttributeType.values():
		var value = live_save_data.character_attributes.get_attribute(attr_type)
		base_attribute_changed.emit(attr_type, value)



#-----------------------------------------------------------------------------
# ATTRIBUTE GETTERS (Base + Bonuses)
#-----------------------------------------------------------------------------
# These return the total attribute value (base + bonuses from cultivation, equipment, etc.)

func get_strength() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.STRENGTH)
	var bonuses = _get_attribute_bonuses(AttributeType.STRENGTH)
	return base + bonuses

func get_body() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.BODY)
	var bonuses = _get_attribute_bonuses(AttributeType.BODY)
	return base + bonuses

func get_agility() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.AGILITY)
	var bonuses = _get_attribute_bonuses(AttributeType.AGILITY)
	return base + bonuses

func get_spirit() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.SPIRIT)
	var bonuses = _get_attribute_bonuses(AttributeType.SPIRIT)
	return base + bonuses

func get_foundation() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.FOUNDATION)
	var bonuses = _get_attribute_bonuses(AttributeType.FOUNDATION)
	return base + bonuses

func get_control() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.CONTROL)
	var bonuses = _get_attribute_bonuses(AttributeType.CONTROL)
	return base + bonuses

func get_resilience() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.RESILIENCE)
	var bonuses = _get_attribute_bonuses(AttributeType.RESILIENCE)
	return base + bonuses

func get_willpower() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.WILLPOWER)
	var bonuses = _get_attribute_bonuses(AttributeType.WILLPOWER)
	return base + bonuses

#-----------------------------------------------------------------------------
# DERIVED STATS (Calculated from attributes)
#-----------------------------------------------------------------------------
# These are basic stat calculations. Combat systems use these for their own logic.

func get_max_health() -> float:
	return 100.0 + (get_body() * 10.0)

func get_max_fatigue() -> float:
	return 50.0 + (get_body() * 5.0)

func get_max_madra() -> float:
	return 50.0 + (get_foundation() * 10.0)

func get_accuracy() -> float:
	return min(0.95, 0.75 + (get_agility() * 0.01))

func get_evasion() -> float:
	return min(0.50, 0.05 + (get_agility() * 0.005))

func get_cooldown_multiplier() -> float:
	return 1.0 / (1.0 + get_agility() * 0.02)

func get_madra_cost_multiplier() -> float:
	return 1.0 / (1.0 + get_control() * 0.03)

#-----------------------------------------------------------------------------
# BASE ATTRIBUTE MODIFICATION FUNCTIONS
#-----------------------------------------------------------------------------

## Add a value to a base attribute
func add_base_attribute(attr_type: AttributeType, amount: float) -> void:
	if live_save_data == null or live_save_data.character_attributes == null:
		Log.error("CharacterManager: Cannot add to attribute - live_save_data or character_attributes is null")
		return
	
	live_save_data.character_attributes.add_to_attribute(attr_type, amount)
	var new_value = live_save_data.character_attributes.get_attribute(attr_type)
	
	base_attribute_changed.emit(attr_type, new_value)
	Log.info("CharacterManager: Added %.1f to %s (new value: %.1f)" % [amount, get_attribute_display_name(attr_type), new_value])


#-----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS
#-----------------------------------------------------------------------------

func _get_attribute_bonuses(attr_type: AttributeType) -> float:
	var total_bonus = 0.0
	
	# TODO: Add bonuses from equipment, buffs, etc. when those systems are implemented
	
	return total_bonus
