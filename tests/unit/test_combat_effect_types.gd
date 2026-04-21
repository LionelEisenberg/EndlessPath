extends GutTest

## Tests that CombatEffectManager routes CANCEL_CAST and STRIP_BUFFS
## effects to the correct target-side managers.

var _target_node: CombatantNode
var _effect_manager: CombatEffectManager
var _ability_manager: CombatAbilityManager
var _buff_manager: CombatBuffManager
var _source_attributes: CharacterAttributesData

func before_each() -> void:
	_target_node = CombatantNode.new()
	add_child_autofree(_target_node)

	# Stub the managers the effect manager reaches into
	_ability_manager = CombatAbilityManager.new()
	_buff_manager = CombatBuffManager.new()
	_target_node.add_child(_ability_manager)
	_target_node.add_child(_buff_manager)
	_target_node.ability_manager = _ability_manager
	_target_node.buff_manager = _buff_manager
	# vitals_manager is queried for non-cancel/strip paths; stub enough to not crash
	var vitals := VitalsManager.new()
	_target_node.add_child(vitals)
	_target_node.vitals_manager = vitals

	# combatant_data.character_name is referenced in the new match cases' log lines
	var data := CombatantData.new()
	data.character_name = "Test"
	_target_node.combatant_data = data

	_effect_manager = CombatEffectManager.new()
	add_child_autofree(_effect_manager)
	_effect_manager.setup(_target_node)

	_source_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)

func test_cancel_cast_effect_calls_cancel_current_cast() -> void:
	# Fake a casting ability on the target
	var ability_data := AbilityData.new()
	ability_data.ability_id = "dummy"
	ability_data.cast_time = 2.0
	var ability_instance := CombatAbilityInstance.new(ability_data, _target_node)
	_ability_manager.add_child(ability_instance)
	_ability_manager.abilities = [ability_instance]
	ability_instance.is_casting = true
	ability_instance.cast_timer.start(2.0)

	var cancel_effect := CombatEffectData.new()
	cancel_effect.effect_type = CombatEffectData.EffectType.CANCEL_CAST
	cancel_effect.effect_name = "Test Cancel"

	_effect_manager.process_effect(cancel_effect, _source_attributes, 1.0)

	assert_false(ability_instance.is_casting,
		"Target's casting ability should be cancelled by CANCEL_CAST effect")

func test_cancel_cast_effect_noop_when_target_not_casting() -> void:
	var cancel_effect := CombatEffectData.new()
	cancel_effect.effect_type = CombatEffectData.EffectType.CANCEL_CAST

	# No abilities casting — should not crash, no side effects
	_effect_manager.process_effect(cancel_effect, _source_attributes, 1.0)
	pass_test("CANCEL_CAST no-ops safely when nothing is casting")

func test_strip_buffs_effect_removes_active_buffs() -> void:
	var b := BuffEffectData.new()
	b.buff_id = "pre_existing"
	b.effect_name = "Pre"
	b.duration = 10.0
	b.buff_type = BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE
	_buff_manager.apply_buff(b)
	assert_eq(_buff_manager.active_buffs.size(), 1)

	var strip_effect := CombatEffectData.new()
	strip_effect.effect_type = CombatEffectData.EffectType.STRIP_BUFFS
	strip_effect.effect_name = "Test Strip"

	_effect_manager.process_effect(strip_effect, _source_attributes, 1.0)

	assert_eq(_buff_manager.active_buffs.size(), 0,
		"STRIP_BUFFS effect should remove all active buffs on the target")
