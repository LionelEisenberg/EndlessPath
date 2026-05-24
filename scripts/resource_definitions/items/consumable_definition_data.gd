class_name ConsumableDefinitionData
extends ItemDefinitionData

## ConsumableDefinitionData
## Definition-side data for a consumable item. use() applies the effects;
## stacking lives on InventoryData; cooldown enforcement will live on the
## future CombatConsumableInstance (see spec 2026-05-24-consumables-design.md).

@export var effects: Array[EffectData] = []

## Seconds before this consumable can be used again, *once cooldown is
## enforced by the combat-side manager*. Pure metadata in this slice —
## declared so .tres files are forward-compatible, but nothing reads it yet.
@export var cooldown_seconds: float = 0.0

func _init() -> void:
	item_type = ItemType.CONSUMABLE

## Apply the consumable's effects. Pure — caller is responsible for inventory
## decrement and cooldown handling.
func use() -> void:
	for effect: EffectData in effects:
		effect.process()

## Tooltip lines. Used by ItemInstanceData._to_description_box() to render the
## consumable's effects in the inventory description panel.
func _get_item_effects() -> Array[String]:
	var lines: Array[String] = []
	for effect: EffectData in effects:
		lines.append("[color=#7ea870]%s[/color]" % str(effect))
	if cooldown_seconds > 0.0:
		lines.append("[color=#a89070]Cooldown: %.1fs[/color]" % cooldown_seconds)
	return lines
