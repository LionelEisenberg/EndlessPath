class_name ConsumableDefinitionData
extends ItemDefinitionData

## ConsumableDefinitionData
## Definition-side data for a consumable item. use() applies the effects;
## stacking lives on InventoryData; in a fight, CombatConsumableInstance
## enforces the cooldown.

@export var effects: Array[EffectData] = []

## Seconds before this consumable can be used again in a fight. Each hotbar
## slot's CombatConsumableInstance enforces it, afresh every fight.
@export var cooldown_seconds: float = 0.0

func _init() -> void:
	item_type = ItemType.CONSUMABLE

## Apply the consumable's effects. Pure — caller is responsible for inventory
## decrement and cooldown handling.
func use() -> void:
	for effect: EffectData in effects:
		effect.process()

## Tooltip lines: the consumable's effects, as the item description panels
## and merchant rows show them.
func _get_item_effects() -> Array[String]:
	var lines: Array[String] = []
	for effect: EffectData in effects:
		lines.append("[color=#7ea870]%s[/color]" % effect.describe())
	if cooldown_seconds > 0.0:
		lines.append("[color=#a89070]Cooldown: %.1fs[/color]" % cooldown_seconds)
	return lines
