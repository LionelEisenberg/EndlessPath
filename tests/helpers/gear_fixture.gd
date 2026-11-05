extends RefCounted

## Gear for tests: equipment with stat percents, a floor, armor and Ward, and
## the Spirit Charm the reprint tests wear.
## Preload it: const GearFixture := preload("res://tests/helpers/gear_fixture.gd").

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## A new item with these fields. `percents` maps stat keys to fractions of the
## trained value ({&"strength": 0.5} is +50% Strength), copied key by key: the
## typed stat_percent_bonuses refuses an untyped Dictionary.
static func item(percents: Dictionary, bonus_floor: int = 1, armor: float = 0.0, ward: float = 0.0) -> EquipmentDefinitionData:
	var gear := EquipmentDefinitionData.new()
	for key: StringName in percents:
		gear.stat_percent_bonuses[key] = percents[key]
	gear.stat_bonus_floor = bonus_floor
	gear.armor = armor
	gear.ward = ward
	return gear

## A new HEAD item giving +50% Spirit: +5 at Spirit Lv 1 (10) and +7 at Lv 5
## (14). Spirit is the stat the Aura Well levels while a book or the shop is
## open, so the reprint tests level it.
static func spirit_charm() -> EquipmentDefinitionData:
	var charm: EquipmentDefinitionData = item({&"spirit": 0.5})
	charm.item_id = "test_spirit_charm"
	charm.item_name = "Spirit Charm"
	charm.slot_type = EquipmentDefinitionData.EquipmentSlot.HEAD
	return charm
