# CharacterManager.gd
# AUTOLOADED SINGLETON
extends Node

## CharacterManager
## Central manager for player character attributes, stats, and derived calculations
## Handles base attributes, bonuses, and computed stats like health, madra, and combat stats

#-----------------------------------------------------------------------------
# TYPE ALIASES
#-----------------------------------------------------------------------------

# Use the AttributeType from CharacterAttributesData
const AttributeType = CharacterAttributesData.AttributeType

## Get the display name for an attribute type
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
	Log.info("CharacterManager: Initializing")
	
	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_update_resources)
		Log.info("CharacterManager: Connected to PersistenceManager")
		_update_resources()
	else:
		Log.critical("CharacterManager: Could not get save_game_data from PersistenceManager on ready!")

func _update_resources() -> void:
	Log.info("CharacterManager: Updating resources from save data")
	
	live_save_data = PersistenceManager.save_game_data
	if live_save_data == null:
		Log.critical("CharacterManager: live_save_data is null in _update_resources!")
		return
	
	# Emit signals for all attributes to update UI
	var attributes_updated = 0
	for attr_type in AttributeType.values():
		var value = live_save_data.character_attributes.get_attribute(attr_type)
		base_attribute_changed.emit(attr_type, value)
		attributes_updated += 1
	
	Log.info("CharacterManager: Updated %d attributes" % attributes_updated)



#-----------------------------------------------------------------------------
# ATTRIBUTE GETTERS (Base + Bonuses)
#-----------------------------------------------------------------------------
# These return the total attribute value (base + bonuses from cultivation, equipment, etc.)

## Get total Strength (base + bonuses)
func get_strength() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.STRENGTH)
	var bonuses = _get_attribute_bonuses(AttributeType.STRENGTH)
	return base + bonuses

## Get total Body (base + bonuses)
func get_body() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.BODY)
	var bonuses = _get_attribute_bonuses(AttributeType.BODY)
	return base + bonuses

## Get total Agility (base + bonuses)
func get_agility() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.AGILITY)
	var bonuses = _get_attribute_bonuses(AttributeType.AGILITY)
	return base + bonuses

## Get total Spirit (base + bonuses)
func get_spirit() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.SPIRIT)
	var bonuses = _get_attribute_bonuses(AttributeType.SPIRIT)
	return base + bonuses

## Get total Foundation (base + bonuses)
func get_foundation() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.FOUNDATION)
	var bonuses = _get_attribute_bonuses(AttributeType.FOUNDATION)
	return base + bonuses

## Get total Control (base + bonuses)
func get_control() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.CONTROL)
	var bonuses = _get_attribute_bonuses(AttributeType.CONTROL)
	return base + bonuses

## Get total Resilience (base + bonuses)
func get_resilience() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.RESILIENCE)
	var bonuses = _get_attribute_bonuses(AttributeType.RESILIENCE)
	return base + bonuses

## Get total Willpower (base + bonuses)
func get_willpower() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.WILLPOWER)
	var bonuses = _get_attribute_bonuses(AttributeType.WILLPOWER)
	return base + bonuses

#-----------------------------------------------------------------------------
# DERIVED STATS (Calculated from attributes)
#-----------------------------------------------------------------------------
# These are basic stat calculations. Combat systems use these for their own logic.

## Calculate maximum health based on Body attribute
func get_max_health() -> float:
	return 100.0 + (get_body() * 10.0)

## Calculate maximum stamina based on Body attribute
func get_max_stamina() -> float:
	return 50.0 + (get_body() * 5.0)

## Calculate maximum madra based on Foundation attribute
func get_max_madra() -> float:
	return 50.0 + (get_foundation() * 10.0)

## Calculate accuracy chance based on Agility attribute (capped at 95%)
func get_accuracy() -> float:
	return min(0.95, 0.75 + (get_agility() * 0.01))

## Calculate evasion chance based on Agility attribute (capped at 50%)
func get_evasion() -> float:
	return min(0.50, 0.05 + (get_agility() * 0.005))

## Calculate cooldown multiplier based on Agility attribute (lower is better)
func get_cooldown_multiplier() -> float:
	return 1.0 / (1.0 + get_agility() * 0.02)

## Calculate madra cost multiplier based on Control attribute (lower is better)
func get_madra_cost_multiplier() -> float:
	return 1.0 / (1.0 + get_control() * 0.03)

#-----------------------------------------------------------------------------
# BASE ATTRIBUTE MODIFICATION FUNCTIONS
#-----------------------------------------------------------------------------

## Add a value to a base attribute and emit change signal
func add_base_attribute(attr_type: AttributeType, amount: float) -> void:
	if live_save_data == null or live_save_data.character_attributes == null:
		Log.error("CharacterManager: Cannot add to attribute - live_save_data or character_attributes is null")
		return
	
	var old_value = live_save_data.character_attributes.get_attribute(attr_type)
	live_save_data.character_attributes.add_to_attribute(attr_type, amount)
	var new_value = live_save_data.character_attributes.get_attribute(attr_type)
	
	base_attribute_changed.emit(attr_type, new_value)
	Log.info("CharacterManager: Modified %s: %.1f -> %.1f (change: %+.1f)" % [get_attribute_display_name(attr_type), old_value, new_value, amount])


#-----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS
#-----------------------------------------------------------------------------

## Calculate total bonuses for an attribute from equipment, buffs, etc.
func _get_attribute_bonuses(attr_type: AttributeType) -> float:
	var total_bonus = 0.0
	
	# TODO: Add bonuses from equipment when inventory system is complete
	# TODO: Add bonuses from active buffs/effects
	# TODO: Add bonuses from cultivation techniques
	# TODO: Add bonuses from temporary effects
	
	return total_bonus
