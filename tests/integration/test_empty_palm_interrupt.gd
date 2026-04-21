extends GutTest

## Integration test: Empty Palm's CANCEL_CAST effect cancels an enemy cast.
## Uses the real combat effect pipeline end-to-end.

const EMPTY_PALM_PATH := "res://resources/abilities/empty_palm.tres"

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

	# Give the target a dummy long-cast ability and simulate mid-cast
	var long_cast_data := AbilityData.new()
	long_cast_data.ability_id = "enemy_long_cast"
	long_cast_data.ability_name = "Enemy Long Cast"
	long_cast_data.cast_time = 3.0
	long_cast_data.base_cooldown = 5.0
	var long_cast := CombatAbilityInstance.new(long_cast_data, _target)
	ability_manager.add_child(long_cast)
	ability_manager.abilities = [long_cast]
	long_cast.is_casting = true
	long_cast.cast_timer.start(3.0)

	# Attach minimal combatant_data so log strings work
	var combatant_data := CombatantData.new()
	combatant_data.character_name = "Enemy"
	combatant_data.attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	_target.combatant_data = combatant_data
	vitals_manager.character_attributes_data = combatant_data.attributes
	vitals_manager.initialize_current_values()
	effect_manager.setup(_target)

	_source_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 15.0, 10.0, 10.0, 10.0)

func test_empty_palm_applied_to_casting_target_cancels_cast() -> void:
	var ability: AbilityData = load(EMPTY_PALM_PATH)
	assert_not_null(ability, "empty_palm.tres must load")

	# Apply each of Empty Palm's effects to the target
	for effect in ability.effects_on_target:
		_target.receive_effect(effect, _source_attributes, 1.0)

	var long_cast: CombatAbilityInstance = _target.ability_manager.abilities[0]
	assert_false(long_cast.is_casting,
		"Target's cast should be cancelled after Empty Palm's effects apply")
	assert_false(_target.vitals_manager.current_health == _target.vitals_manager.max_health,
		"Target should also have taken damage from Empty Palm")

func test_empty_palm_applied_to_noncasting_target_only_damages() -> void:
	var long_cast: CombatAbilityInstance = _target.ability_manager.abilities[0]
	long_cast.is_casting = false
	long_cast.cast_timer.stop()

	var starting_health: float = _target.vitals_manager.current_health
	var ability: AbilityData = load(EMPTY_PALM_PATH)
	for effect in ability.effects_on_target:
		_target.receive_effect(effect, _source_attributes, 1.0)

	assert_lt(_target.vitals_manager.current_health, starting_health,
		"Target should take damage even when not casting")
