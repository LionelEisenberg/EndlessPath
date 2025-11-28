class_name CombatChoice
extends EncounterChoice

## CombatChoice
## A choice that initiates combat.

@export var enemy_pool: Array[CombatantData] = []
@export var is_boss: bool = false

@export_group("Rewards")
@export var gold_multiplier: float = 1.0 ## Multiplier for gold rewards from this combat
