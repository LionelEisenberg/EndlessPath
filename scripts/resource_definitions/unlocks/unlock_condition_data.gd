class_name UnlockConditionData
extends Resource

const AttributeType = CharacterAttributesData.AttributeType

enum ConditionType {
	CULTIVATION_STAGE, # Check advancement stage
	CULTIVATION_LEVEL, # Check core density level
	ZONE_UNLOCKED, # Check if zone is unlocked
	ADVENTURE_COMPLETED, # Check dungeon/adventure completion
	EVENT_TRIGGERED, # Check if event occurred
	ITEM_OWNED, # Check inventory for item
	RESOURCE_AMOUNT, # Check resource quantity (madra/gold)
	ATTRIBUTE_VALUE, # Check attribute value
}

@export var condition_id: String = "" # Unique identifier for this condition
@export var condition_type: ConditionType = ConditionType.CULTIVATION_STAGE
@export var target_value: Variant # What to check against
@export var comparison_op: String = ">=" # ">=", "==", "<=", etc.
@export var optional_params: Dictionary = {} # Type-specific params

## Evaluates condition against current game state via manager queries.
func evaluate() -> bool:
	match condition_type:
		ConditionType.CULTIVATION_STAGE:
			var current_stage = CultivationManager.get_current_advancement_stage()
			return _compare_values(current_stage, target_value, comparison_op)

		ConditionType.CULTIVATION_LEVEL:
			return _compare_values(get_current_value(), target_value, comparison_op)

		ConditionType.ZONE_UNLOCKED:
			Log.warn("UnlockConditionData: ZONE_UNLOCKED not yet implemented")
			return false

		ConditionType.ADVENTURE_COMPLETED:
			Log.warn("UnlockConditionData: ADVENTURE_COMPLETED not yet implemented")
			return false

		ConditionType.EVENT_TRIGGERED:
			if not EventManager:
				Log.error("UnlockConditionData: EventManager is not initialized")
				return false
			else:
				return EventManager.has_event_triggered(target_value)

		ConditionType.ITEM_OWNED:
			if not InventoryManager:
				Log.error("UnlockConditionData: InventoryManager is not initialized")
				return false
			return InventoryManager.has_item(str(target_value))

		ConditionType.RESOURCE_AMOUNT:
			return _compare_values(get_current_value(), target_value, comparison_op)

		ConditionType.ATTRIBUTE_VALUE:
			var attribute_type: AttributeType = optional_params.get("attribute_type", AttributeType.STRENGTH)
			var current_value = CharacterManager.get_total_attributes_data().get_attribute(attribute_type)
			return _compare_values(current_value, target_value, comparison_op)

	return false

## True when progress toward this condition can be shown as current / target:
## RESOURCE_AMOUNT and CULTIVATION_LEVEL conditions.
func is_measurable() -> bool:
	return condition_type == ConditionType.RESOURCE_AMOUNT \
		or condition_type == ConditionType.CULTIVATION_LEVEL

## The value evaluate() compares against the target: the Madra or gold amount,
## or the Core Density level. 0.0 for a condition that is not measurable.
func get_current_value() -> float:
	match condition_type:
		ConditionType.CULTIVATION_LEVEL:
			return CultivationManager.get_core_density_level()
		ConditionType.RESOURCE_AMOUNT:
			var resource_type: String = str(optional_params.get("resource_type", "madra"))
			if resource_type == "madra":
				return ResourceManager.get_madra()
			if resource_type == "gold":
				return ResourceManager.get_gold()
	return 0.0

## The target as a number. 0.0 for a condition that is not measurable or has no
## numeric target.
func get_target_value() -> float:
	if not is_measurable():
		return 0.0
	if typeof(target_value) != TYPE_INT and typeof(target_value) != TYPE_FLOAT:
		return 0.0
	return float(target_value)

# Compares current value (a) with target value (b) using the comparison operator (op)
func _compare_values(a: Variant, b: Variant, op: String) -> bool:
	match op:
		">=": return a >= b
		">": return a > b
		"<=": return a <= b
		"<": return a < b
		"==": return a == b
		"!=": return a != b
		_: return false
