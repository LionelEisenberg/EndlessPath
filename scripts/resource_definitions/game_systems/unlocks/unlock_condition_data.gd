class_name UnlockConditionData
extends Resource

enum ConditionType {
	CULTIVATION_STAGE,      # Check advancement stage
	CULTIVATION_LEVEL,      # Check core density level
	ZONE_UNLOCKED,         # Check if zone is unlocked
	ADVENTURE_COMPLETED,   # Check dungeon/adventure completion
	EVENT_TRIGGERED,       # Check if event occurred
	ITEM_OWNED,            # Check inventory for item
	RESOURCE_AMOUNT,       # Check resource quantity (madra/gold)
	STAT_VALUE,            # Check adventure stat value
	GAME_SYSTEM_UNLOCKED   # Check if system is unlocked
}

@export var condition_id: String = ""  # Unique identifier for this condition
@export var condition_type: ConditionType = ConditionType.CULTIVATION_STAGE
@export var target_value: Variant  # What to check against
@export var comparison_op: String = ">="  # ">=", "==", "<=", etc.
@export var optional_params: Dictionary = {}  # Type-specific params

func evaluate() -> bool:
	# Evaluates condition against current game state via manager queries
	match condition_type:
		ConditionType.CULTIVATION_STAGE:
			var current_stage = CultivationManager.get_current_advancement_stage()
			return _compare_values(current_stage, target_value, comparison_op)
		
		ConditionType.CULTIVATION_LEVEL:
			var current_level = CultivationManager.get_core_density_level()
			return _compare_values(current_level, target_value, comparison_op)
		
		ConditionType.ZONE_UNLOCKED:
			# Will be implemented in ZoneManager
			printerr("UnlockConditionData: ZONE_UNLOCKED not yet implemented")
			return false
		
		ConditionType.ADVENTURE_COMPLETED:
			# Will be implemented in AdventureManager
			printerr("UnlockConditionData: ADVENTURE_COMPLETED not yet implemented")
			return false
		
		ConditionType.EVENT_TRIGGERED:
			if not EventManager:
				printerr("UnlockConditionData: EventManager is not initialized")
				return false
			else:
				return EventManager.has_event_triggered(target_value)
		
		ConditionType.ITEM_OWNED:
			# Will be implemented in InventoryManager
			printerr("UnlockConditionData: ITEM_OWNED not yet implemented")
			return false
		
		ConditionType.RESOURCE_AMOUNT:
			var resource_type = optional_params.get("resource_type", "madra")
			var current_amount = 0.0
			if resource_type == "madra":
				current_amount = ResourceManager.get_madra()
			elif resource_type == "gold":
				current_amount = ResourceManager.get_gold()
			return _compare_values(current_amount, target_value, comparison_op)
		
		ConditionType.STAT_VALUE:
			# Will be implemented in AdventureManager
			printerr("UnlockConditionData: STAT_VALUE not yet implemented")
			return false
		
		ConditionType.GAME_SYSTEM_UNLOCKED:
			var system = UnlockManager.GameSystem.get(target_value)
			return UnlockManager.is_game_system_unlocked(system)
	
	return false


# Compares current value (a) with target value (b) using the comparison operator (op)
func _compare_values(a: Variant, b: Variant, op: String) -> bool:
	match op:
		">=": return a >= b
		">":  return a > b
		"<=": return a <= b
		"<":  return a < b
		"==": return a == b
		"!=": return a != b
		_: return false
