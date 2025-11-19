class_name AdventureActionData
extends ZoneActionData

@export var adventure_data: AdventureData  # The actual adventure configuration

@export_group("Action Modifiers")
@export var experience_multiplier: float = 1.0  # Multiplies the adventure's base XP reward
@export var gold_multiplier: float = 1.0  # Multiplies the adventure's base gold reward
@export var difficulty_modifier: float = 1.0  # Modifies encounter difficulty (1.0 = normal, 1.5 = 50% harder)
@export var completion_time_modifier: float = 1.0  # Modifies how long the adventure takes

@export_group("Repeatable Settings")
@export var cooldown_seconds: float = 0.0  # Cooldown before can repeat (0 = no cooldown)
@export var daily_limit: int = 0  # Max times per day (0 = unlimited)


func _init():
	action_type = ZoneActionData.ActionType.ADVENTURE

## Validate that adventure data is assigned
func is_valid() -> bool:
	if not adventure_data:
		Log.error("AdventureActionData '%s' has no adventure_data assigned!" % action_id)
		return false
	return true
