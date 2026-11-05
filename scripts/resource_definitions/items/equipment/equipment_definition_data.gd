class_name EquipmentDefinitionData
extends ItemDefinitionData

## EquipmentDefinitionData
## Base data for all equippable items. The slot decides where the item is worn;
## its stat percents (never below the floor), armor and Ward decide what it
## gives.

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

enum EquipmentSlot {
	MAIN_HAND,
	OFF_HAND,
	HEAD,
	ARMOR,
	ACCESSORY,
}

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export var slot_type: EquipmentSlot = EquipmentSlot.MAIN_HAND

## Stat key (CharacterAttributesData.stat_key()) to the fraction of that stat's
## trained value the item adds while worn: 0.1 is +10%.
@export var stat_percent_bonuses: Dictionary[StringName, float] = {}

## The least each of the item's stat percents gives, in whole points.
@export var stat_bonus_floor: int = 1

## Flat: cuts physical damage taken.
@export var armor: float = 0.0

## Flat: cuts Spirit damage taken.
@export var ward: float = 0.0

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _init() -> void:
	item_type = ItemType.EQUIPMENT

#-----------------------------------------------------------------------------
# STAT BONUSES
#-----------------------------------------------------------------------------

## The points the item adds to the stat: its percent of the trained value,
## rounded down and never below stat_bonus_floor, or 0 when it has no percent
## above 0 for the stat. Not held to the stat's level cap: the cap limits
## training only, so gear lifts a capped stat past it.
func get_stat_bonus(stat: CharacterAttributesData.AttributeType, trained_value: float) -> float:
	var percent: float = stat_percent_bonuses.get(CharacterAttributesData.stat_key(stat), 0.0)
	if percent <= 0.0:
		return 0.0
	return maxf(stat_bonus_floor, floorf(trained_value * percent))

## The item's bonuses as FLAT modifiers, for CharacterManager's gear source:
## one per stat whose get_stat_bonus() is above 0, counted on that stat's
## value in trained_values (AttributeType to float; a stat it lacks counts as
## STAT_BASELINE, its Lv 1 value), then armor and Ward, each when above 0. A
## key that names no stat is logged and skipped.
func get_stat_modifiers(trained_values: Dictionary) -> Array[StatModifierData]:
	var modifiers: Array[StatModifierData] = []
	for key: StringName in stat_percent_bonuses:
		var stat: int = CharacterAttributesData.stat_from_key(key)
		if stat == -1:
			Log.error("EquipmentDefinitionData: '%s' skips the unknown stat key '%s'" % [item_id, key])
			continue
		var attribute := stat as CharacterAttributesData.AttributeType
		var bonus: float = get_stat_bonus(attribute, trained_values.get(attribute, CharacterAttributesData.STAT_BASELINE))
		if bonus > 0.0:
			modifiers.append(StatModifierData.new(
				StatModifierData.for_attribute(attribute), StatModifierData.Kind.FLAT, bonus))
	if armor > 0.0:
		modifiers.append(StatModifierData.new(StatModifierData.Stat.ARMOR, StatModifierData.Kind.FLAT, armor))
	if ward > 0.0:
		modifiers.append(StatModifierData.new(StatModifierData.Stat.WARD, StatModifierData.Kind.FLAT, ward))
	return modifiers

#-----------------------------------------------------------------------------
# TOOLTIP
#-----------------------------------------------------------------------------

## Tooltip lines: the item's BookText.gear_bonus_lines() at the player's
## trained values, each in the effect ink ("+30% Strength (+3)", "Armor 6",
## "Ward 4"). The item tooltip (ItemDescriptionPanel) and the shop
## (MerchantStockRow) print these. Every call reads the training afresh, so a
## reader that calls it again prints each bonus as it stands.
func _get_item_effects() -> Array[String]:
	var effects: Array[String] = []
	for line: String in BookText.gear_bonus_lines(self, CharacterManager.get_trained_values()):
		effects.append("[color=#a89070]%s[/color]" % line)
	return effects
