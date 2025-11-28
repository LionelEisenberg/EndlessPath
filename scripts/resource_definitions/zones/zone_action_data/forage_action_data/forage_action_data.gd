class_name ForageActionData
extends ZoneActionData

## ForageActionData
## Defines a foraging action that awards items from a loot table at regular intervals.

#-----------------------------------------------------------------------------
# EXPORTED PROPERTIES
#-----------------------------------------------------------------------------
	
## The loot table to roll when foraging completes
@export var loot_table: LootTable

## Cost in madra per second while foraging is active
@export var madra_cost_per_second: float = 0.0

## How often to roll the loot table (in seconds)
@export var foraging_interval_in_sec: float = 5.0
