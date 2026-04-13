class_name PathEffectsSummary
extends RefCounted

## Aggregated snapshot of all active path progression effects.
## Rebuilt by PathManager whenever a node is purchased.
## Other systems query this to apply path bonuses.

## Dictionary[CharacterAttributesData.AttributeType, float] -- flat bonus per attribute
var attribute_bonuses: Dictionary = {}

## Multiplier on Madra generated per cycle (1.0 = no change)
var madra_generation_mult: float = 1.0

## Flat bonus to max Madra capacity
var madra_capacity_bonus: float = 0.0

## Multiplier on Core Density XP earned (1.0 = no change)
var core_density_xp_mult: float = 1.0

## Multiplier on stamina recovery rate (1.0 = no change)
var stamina_recovery_mult: float = 1.0

## Flat bonus to cycling zone accuracy radius (pixels)
var cycling_accuracy_bonus: float = 0.0

## Percentage of unspent adventure Madra returned (0.0 to 1.0)
var adventure_madra_return_pct: float = 0.0

## Bonus Madra granted on Core Density level-up
var madra_on_level_up: float = 0.0

## Resource paths of combat abilities unlocked by purchased nodes.
## Not yet consumed by the ability system (wired during ability rework).
var unlocked_abilities: Array[String] = []

## Technique names/paths of cycling techniques unlocked by purchased nodes.
## Not yet consumed by the cycling system (wired during ability rework).
var unlocked_cycling_techniques: Array[String] = []
