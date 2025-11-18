class_name CharacterAttributesData
extends Resource

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------
enum AttributeType {
	STRENGTH,
	BODY,
	AGILITY,
	SPIRIT,
	FOUNDATION,
	CONTROL,
	RESILIENCE,
	WILLPOWER
}

#-----------------------------------------------------------------------------
# BASE ATTRIBUTES
#-----------------------------------------------------------------------------
# These are the persistent base attribute values that are saved.
# Total attributes = base + bonuses from other systems (cultivation, equipment, etc.)

@export var attributes: Dictionary = {}

func _init() -> void:
	# Initialize all attributes if empty
	if attributes.is_empty():
		for attr_type in AttributeType.values():
			attributes[attr_type] = 10.0
	
	# Validate we have exactly 8 attributes
	_validate_attributes()

func _validate_attributes() -> void:
	var expected_count = AttributeType.size()
	if attributes.size() != expected_count:
		push_error("CharacterAttributesData: Invalid attribute count. Expected %d, got %d" % [expected_count, attributes.size()])
		# Fix by ensuring all attributes exist
		for attr_type in AttributeType.values():
			if not attributes.has(attr_type):
				attributes[attr_type] = 10.0

func get_attribute(attr_type: AttributeType) -> float:
	if attributes.has(attr_type):
		return attributes[attr_type]
	push_error("CharacterAttributesData: Attribute type %s not found" % attr_type)
	return 10.0

func set_attribute(attr_type: AttributeType, value: float) -> void:
	attributes[attr_type] = value

func add_to_attribute(attr_type: AttributeType, amount: float) -> void:
	if attributes.has(attr_type):
		attributes[attr_type] += amount
	else:
		push_error("CharacterAttributesData: Cannot add to attribute type %s - not found" % attr_type)

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
