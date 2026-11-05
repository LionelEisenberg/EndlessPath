class_name AdventureActionData
extends ZoneActionData

@export var adventure_data: AdventureData  # The actual adventure configuration

@export_group("Action Modifiers")
@export var experience_multiplier: float = 1.0  # Multiplies the adventure's base XP reward
@export var gold_multiplier: float = 1.0  # Multiplies the adventure's base gold reward
@export var difficulty_modifier: float = 1.0  # Modifies encounter difficulty (1.0 = normal, 1.5 = 50% harder)
@export var completion_time_modifier: float = 1.0  # Modifies how long the adventure takes
@export var time_limit_seconds: int = 10 # Time limit for the adventure
@export var stamina_regen_modifier: float = 1.0 # Modifier for passive stamina regen

## Core Density XP a won fight pays, by its tier (get_core_density_xp_for()).
## They default to 0, so an action pays nothing unless its file writes them out.
@export_group("Core Density")
@export var core_density_xp_regular: float = 0.0
@export var core_density_xp_elite: float = 0.0
@export var core_density_xp_boss: float = 0.0

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

## Returns the Core Density XP a won fight pays. The tier comes from the fight's
## tile and its combat choice, never from the enemy (the boss reuses a regular
## spirit) or its gold (an elite can drop none): the boss amount for a boss
## choice or a boss tile, the elite one for an elite tile, the regular one for a
## regular fight or an ambush, and 0 for any other tile.
func get_core_density_xp_for(encounter_type: AdventureEncounter.EncounterType, is_boss: bool) -> float:
	if is_boss or encounter_type == AdventureEncounter.EncounterType.COMBAT_BOSS:
		return core_density_xp_boss
	match encounter_type:
		AdventureEncounter.EncounterType.COMBAT_ELITE:
			return core_density_xp_elite
		AdventureEncounter.EncounterType.COMBAT_REGULAR, AdventureEncounter.EncounterType.COMBAT_AMBUSH:
			return core_density_xp_regular
	return 0.0
