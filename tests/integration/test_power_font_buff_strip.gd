extends GutTest

## Integration test: Power Font's STRIP_BUFFS effect removes every active buff
## on the target while still dealing damage.

const POWER_FONT_PATH := "res://resources/abilities/power_font.tres"

var _target: CombatantNode
var _source_attributes: CharacterAttributesData

func before_each() -> void:
	_target = CombatantNode.new()
	add_child_autofree(_target)

	var ability_manager := CombatAbilityManager.new()
	var buff_manager := CombatBuffManager.new()
	var effect_manager := CombatEffectManager.new()
	var vitals_manager := VitalsManager.new()
	_target.add_child(ability_manager)
	_target.add_child(buff_manager)
	_target.add_child(effect_manager)
	_target.add_child(vitals_manager)
	_target.ability_manager = ability_manager
	_target.buff_manager = buff_manager
	_target.effect_manager = effect_manager
	_target.vitals_manager = vitals_manager

	var combatant_data := CombatantData.new()
	combatant_data.character_name = "Dummy"
	combatant_data.attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	_target.combatant_data = combatant_data
	vitals_manager.character_attributes_data = combatant_data.attributes
	vitals_manager.initialize_current_values()
	effect_manager.setup(_target)

	_source_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 20.0, 10.0, 10.0, 10.0)

	# Seed two buffs on the target
	var b1 := BuffEffectData.new()
	b1.buff_id = "power_buff"
	b1.effect_name = "Power Buff"
	b1.duration = 30.0
	b1.buff_type = BuffEffectData.BuffType.OUTGOING_DAMAGE_MODIFIER
	b1.damage_multiplier = 2.0
	buff_manager.apply_buff(b1)

	var b2 := BuffEffectData.new()
	b2.buff_id = "armor_buff"
	b2.effect_name = "Armor Buff"
	b2.duration = 30.0
	b2.buff_type = BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE
	b2.attribute_modifiers = {CharacterAttributesData.AttributeType.RESILIENCE: 2.0}
	buff_manager.apply_buff(b2)

	assert_eq(buff_manager.active_buffs.size(), 2, "setup: 2 buffs seeded")

func test_power_font_strips_all_buffs_and_deals_damage() -> void:
	var ability: AbilityData = load(POWER_FONT_PATH)
	assert_not_null(ability, "power_font.tres must load")

	var starting_health: float = _target.vitals_manager.current_health

	for effect in ability.effects:
		_target.receive_effect(effect, _source_attributes, 1.0)

	assert_eq(_target.buff_manager.active_buffs.size(), 0,
		"Power Font should strip all buffs from the target")
	assert_lt(_target.vitals_manager.current_health, starting_health,
		"Power Font should deal damage in addition to stripping buffs")

func test_power_font_on_unbuffed_target_only_damages() -> void:
	_target.buff_manager.strip_all_buffs()  # Clear the setup buffs
	assert_eq(_target.buff_manager.active_buffs.size(), 0)

	var starting_health: float = _target.vitals_manager.current_health
	var ability: AbilityData = load(POWER_FONT_PATH)
	for effect in ability.effects:
		_target.receive_effect(effect, _source_attributes, 1.0)

	assert_lt(_target.vitals_manager.current_health, starting_health,
		"Power Font should still deal damage when no buffs to strip")
