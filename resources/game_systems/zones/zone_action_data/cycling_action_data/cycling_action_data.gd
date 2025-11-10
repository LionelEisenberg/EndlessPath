class_name CyclingActionData
extends ZoneActionData

@export var madra_multiplier: float = 1.0  # Multiplies base madra per cycle (1.0 = no change, 1.5 = 50% bonus)
@export var cycle_duration_modifier: float = 1.0  # Modifies cycle duration (1.0 = no change, 0.8 = 20% faster, 1.2 = 20% slower)
@export var xp_multiplier: float = 1.0  # Multiplies XP gained from zone clicks
@export var madra_cost_per_cycle: float = 0.0  # Optional madra cost per cycle (0 = free)
