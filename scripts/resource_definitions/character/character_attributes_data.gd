class_name CharacterAttributesData
extends Resource

## CharacterAttributesData
## Stores and manages the player's base attribute values
## Base attributes can be modified by cultivation, equipment, and other systems

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

enum AttributeType {
	STRENGTH,    ## Physical power and damage
	BODY,        ## Health, stamina, and physical resilience
	AGILITY,     ## Speed, evasion, and cooldown reduction
	SPIRIT,      ## Mental fortitude and spiritual power
	FOUNDATION,  ## Madra capacity and regeneration
	CONTROL,     ## Technique efficiency and madra cost reduction
	RESILIENCE,  ## Defense and damage reduction
	WILLPOWER    ## Mental resistance and technique power
}

#-----------------------------------------------------------------------------
# BASE ATTRIBUTES
#-----------------------------------------------------------------------------
# These are the persistent base attribute values that are saved.
# Total attributes = base + bonuses from other systems (cultivation, equipment, etc.)

@export var attributes: Dictionary [AttributeType, float] = {}

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _init(strength: float = 10.0, body: float = 10.0, agility: float = 10.0, spirit: float = 10.0, foundation: float = 10.0, control: float = 10.0, resilience: float = 10.0, willpower: float = 10.0) -> void:
	attributes[AttributeType.STRENGTH] = strength
	attributes[AttributeType.BODY] = body
	attributes[AttributeType.AGILITY] = agility
	attributes[AttributeType.SPIRIT] = spirit
	attributes[AttributeType.FOUNDATION] = foundation
	attributes[AttributeType.CONTROL] = control
	attributes[AttributeType.RESILIENCE] = resilience
	attributes[AttributeType.WILLPOWER] = willpower
	_validate_attributes()

#-----------------------------------------------------------------------------
# VALIDATION
#-----------------------------------------------------------------------------

func _validate_attributes() -> void:
	var expected_count = AttributeType.size()
	if attributes.size() != expected_count:
		Log.error("CharacterAttributesData: Invalid attribute count. Expected %d, got %d" % [expected_count, attributes.size()])
		# Fix by ensuring all attributes exist
		for attr_type in AttributeType.values():
			if not attributes.has(attr_type):
				attributes[attr_type] = 10.0
				Log.warn("CharacterAttributesData: Added missing attribute type: %s" % AttributeType.keys()[attr_type])

#-----------------------------------------------------------------------------
# ATTRIBUTE ACCESSORS
#-----------------------------------------------------------------------------

## Get the value of a specific attribute
func get_attribute(attr_type: AttributeType) -> float:
	if attributes.has(attr_type):
		return attributes[attr_type]
	Log.error("CharacterAttributesData: Attribute type %s not found" % AttributeType.keys()[attr_type])
	return 10.0


## Add an amount to a specific attribute
func add_to_attribute(attr_type: AttributeType, amount: float) -> void:
	if attributes.has(attr_type):
		var old_value = attributes[attr_type]
		attributes[attr_type] += amount
		Log.info("CharacterAttributesData: Added %.1f to %s (%.1f -> %.1f)" % [amount, AttributeType.keys()[attr_type], old_value, attributes[attr_type]])
	else:
		Log.error("CharacterAttributesData: Cannot add to attribute type %s - not found" % AttributeType.keys()[attr_type])

#-----------------------------------------------------------------------------
# STRING REPRESENTATION
#-----------------------------------------------------------------------------

func _to_string() -> String:
	return "CharacterAttributesData(\n  Strength: %.1f\n  Body: %.1f\n  Agility: %.1f\n  Spirit: %.1f\n  Foundation: %.1f\n  Control: %.1f\n  Resilience: %.1f\n  Willpower: %.1f\n)" % [
		get_attribute(AttributeType.STRENGTH),
		get_attribute(AttributeType.BODY),
		get_attribute(AttributeType.AGILITY),
		get_attribute(AttributeType.SPIRIT),
		get_attribute(AttributeType.FOUNDATION),
		get_attribute(AttributeType.CONTROL),
		get_attribute(AttributeType.RESILIENCE),
		get_attribute(AttributeType.WILLPOWER)
	]
