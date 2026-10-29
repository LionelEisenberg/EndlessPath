# CharacterManager.gd
# AUTOLOADED SINGLETON
extends Node

## CharacterManager
## Central manager for the player's attributes and the stats derived from them.
## Base attributes live in the save; every bonus (gear today, path perks and
## elixirs later) is a source in a StatModifierStack, asked when a stat is
## read. get_stat() is the one read: an attribute is its base with its
## modifiers; a derived vital is CharacterAttributesData's formula over the
## total attributes, then its own modifiers.

#-----------------------------------------------------------------------------
# TYPE ALIASES
#-----------------------------------------------------------------------------

# Use the AttributeType from CharacterAttributesData
const AttributeType = CharacterAttributesData.AttributeType
const Stat = StatModifierData.Stat

## The source name the equipped gear's bonuses are under.
const GEAR_SOURCE: StringName = &"gear"

## Get the display name for an attribute type
static func get_attribute_display_name(attr_type: AttributeType) -> String:
	return CharacterAttributesData.AttributeType.keys()[attr_type].capitalize()

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal base_attribute_changed(attribute_type: AttributeType, new_value: float)

## Emitted when any total stat may have changed: after a base attribute
## changes, after any inventory change (equipping or removing gear moves the
## bonuses), after a save reset, and after a modifier source is set or removed.
## Listeners re-read get_stat() or get_total_attributes_data().
signal stats_changed

#-----------------------------------------------------------------------------
# PLAYER DATA (Held by this manager)
#-----------------------------------------------------------------------------

# --- Persistent State (via shared SaveGameData) ---
var live_save_data: SaveGameData = null # Reference set in _ready

## Every bonus to the player's stats, by source.
var _modifiers: StatModifierStack = StatModifierStack.new()

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	Log.info("CharacterManager: Initializing")
	_modifiers.set_source(GEAR_SOURCE, _gear_modifiers)

	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_update_resources)
		_update_resources()
	else:
		Log.critical("CharacterManager: Could not get save_game_data from PersistenceManager on ready!")
	InventoryManager.inventory_changed.connect(_on_inventory_changed)

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
	stats_changed.emit()

	Log.info("CharacterManager: Updated %d attributes" % attributes_updated)

func _on_inventory_changed(_inventory: InventoryData) -> void:
	stats_changed.emit()


#-----------------------------------------------------------------------------
# STATS (Base + Modifiers)
#-----------------------------------------------------------------------------

## Returns the stat's total. An attribute is its base from the save with its
## modifiers. A derived vital is its formula on CharacterAttributesData over
## the total attributes, then its own modifiers.
func get_stat(stat: Stat) -> float:
	return _modifiers.apply(stat, _get_base_stat(stat))

## Returns the eight total attributes (base + modifiers) as one data object,
## a snapshot that does not follow later changes.
func get_total_attributes_data() -> CharacterAttributesData:
	var totals := CharacterAttributesData.new()
	for attr_type: AttributeType in AttributeType.values():
		totals.set_attribute(attr_type, get_stat(StatModifierData.for_attribute(attr_type)))
	return totals

## Adds a modifier source, or replaces the one under that name. The provider
## takes no arguments and returns Array[StatModifierData]; it is asked each
## time a stat is read. "gear" is taken by the equipped gear.
func set_modifier_source(source: StringName, provider: Callable) -> void:
	_modifiers.set_source(source, provider)
	stats_changed.emit()

## Removes a modifier source, if there is one under that name.
func remove_modifier_source(source: StringName) -> void:
	_modifiers.remove_source(source)
	stats_changed.emit()

#-----------------------------------------------------------------------------
# DERIVED STATS (Calculated from attributes)
#-----------------------------------------------------------------------------
# These are basic stat calculations. Combat systems use these for their own logic.

## Get the character's gold multiplier from stats/equipment/cultivation
## Returns: float multiplier (1.0 = no bonus)
## Future: Can be affected by luck stat, equipment bonuses, cultivation stage, etc.
func get_gold_multiplier() -> float:
	# TODO: Implement based on character stats/equipment/cultivation
	# Example: return 1.0 + (get_attribute(AttributeType.LUCK) * 0.01)
	return 1.0

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
	stats_changed.emit()
	Log.info("CharacterManager: Modified %s: %.1f -> %.1f (change: %+.1f)" % [get_attribute_display_name(attr_type), old_value, new_value, amount])


#-----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS
#-----------------------------------------------------------------------------

## The stat before its modifiers: an attribute's base from the save, or a
## derived vital's formula over the total attributes.
func _get_base_stat(stat: Stat) -> float:
	match stat:
		Stat.MAX_HEALTH:
			return get_total_attributes_data().get_max_health()
		Stat.MAX_STAMINA:
			return get_total_attributes_data().get_max_stamina()
		Stat.MAX_MADRA:
			return get_total_attributes_data().get_max_madra()
	return live_save_data.character_attributes.get_attribute(StatModifierData.attribute_of(stat))

## The gear source: the bonuses of every equipped item and accessory. It
## reads this manager's own save, not InventoryManager's, so during a save
## reset it already sees the new save (CharacterManager hears the reset
## first).
func _gear_modifiers() -> Array[StatModifierData]:
	var modifiers: Array[StatModifierData] = []
	if live_save_data == null or live_save_data.inventory == null:
		return modifiers
	var inventory: InventoryData = live_save_data.inventory
	for instance: ItemInstanceData in inventory.equipped_gear.values() + inventory.equipped_accessories.values():
		if instance == null:
			continue
		var equipment := instance.item_definition as EquipmentDefinitionData
		if equipment != null:
			modifiers.append_array(equipment.get_stat_modifiers())
	return modifiers
