class_name CharacterAttributesData
extends Resource

## CharacterAttributesData
## Stores the player's base attribute values. Total attributes (with bonuses
## from equipment, cultivation, etc.) are computed by CharacterManager.

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

@export var strength: float = 10.0
@export var body: float = 10.0
@export var agility: float = 10.0
@export var spirit: float = 10.0
@export var foundation: float = 10.0
@export var control: float = 10.0
@export var resilience: float = 10.0
@export var willpower: float = 10.0

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _init(
	strength_value: float = 10.0,
	body_value: float = 10.0,
	agility_value: float = 10.0,
	spirit_value: float = 10.0,
	foundation_value: float = 10.0,
	control_value: float = 10.0,
	resilience_value: float = 10.0,
	willpower_value: float = 10.0,
) -> void:
	strength = strength_value
	body = body_value
	agility = agility_value
	spirit = spirit_value
	foundation = foundation_value
	control = control_value
	resilience = resilience_value
	willpower = willpower_value

#-----------------------------------------------------------------------------
# ATTRIBUTE ACCESSORS
#-----------------------------------------------------------------------------

## Get the value of a specific attribute by type.
func get_attribute(attr_type: AttributeType) -> float:
	match attr_type:
		AttributeType.STRENGTH: return strength
		AttributeType.BODY: return body
		AttributeType.AGILITY: return agility
		AttributeType.SPIRIT: return spirit
		AttributeType.FOUNDATION: return foundation
		AttributeType.CONTROL: return control
		AttributeType.RESILIENCE: return resilience
		AttributeType.WILLPOWER: return willpower
	Log.error("CharacterAttributesData: Unknown attribute type %s" % attr_type)
	return 0.0

## Set the value of a specific attribute by type.
func set_attribute(attr_type: AttributeType, value: float) -> void:
	match attr_type:
		AttributeType.STRENGTH: strength = value
		AttributeType.BODY: body = value
		AttributeType.AGILITY: agility = value
		AttributeType.SPIRIT: spirit = value
		AttributeType.FOUNDATION: foundation = value
		AttributeType.CONTROL: control = value
		AttributeType.RESILIENCE: resilience = value
		AttributeType.WILLPOWER: willpower = value
		_: Log.error("CharacterAttributesData: Unknown attribute type %s" % attr_type)

## Add an amount to a specific attribute by type.
func add_to_attribute(attr_type: AttributeType, amount: float) -> void:
	var old_value := get_attribute(attr_type)
	set_attribute(attr_type, old_value + amount)
	Log.info("CharacterAttributesData: Added %.1f to %s (%.1f -> %.1f)" % [
		amount,
		AttributeType.keys()[attr_type],
		old_value,
		get_attribute(attr_type),
	])

## Maximum madra pool derived from the Foundation attribute.
func get_max_madra() -> float:
	return foundation * 10.0

#-----------------------------------------------------------------------------
# STRING REPRESENTATION
#-----------------------------------------------------------------------------

func _to_string() -> String:
	return "CharacterAttributesData(\n  Strength: %.1f\n  Body: %.1f\n  Agility: %.1f\n  Spirit: %.1f\n  Foundation: %.1f\n  Control: %.1f\n  Resilience: %.1f\n  Willpower: %.1f\n)" % [
		strength, body, agility, spirit, foundation, control, resilience, willpower
	]
