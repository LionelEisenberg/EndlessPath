class_name CombatChoice
extends EncounterChoice

## CombatChoice
## A choice that initiates combat.

@export var enemy_pool: Array[CombatantData] = []
@export var is_boss: bool = false
