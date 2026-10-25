extends GutTest

## Unit tests for CombatConsumableManager: a combatant's hotbar consumables in a
## fight. setup() builds one CombatConsumableInstance per filled hotbar slot, in
## slot order and for the player only. The gate takes the manager's own
## instances when they are ready and some are left, and never looks at the
## technique being cast. Runs on a fresh save, restored after each test, with
## the player's vitals put back.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const MANAGER_SCENE_PATH: String = "res://scenes/combat/combatant/combat_consumable_manager/combat_consumable_manager.tscn"
const COMBATANT_SCENE_PATH: String = "res://scenes/combat/combatant/combatant_node.tscn"
const PLAYER_TEXTURE_PATH: String = "res://assets/sprites/combat/test_character_sprite.png"
const ENEMY_DATA: CombatantData = preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
const BASIC_STRIKE: AbilityData = preload("res://resources/abilities/basic_strike.tres")

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## An effect that counts how often it fires, so no test touches the vitals.
class CountingEffect extends EffectData:
	var call_count: int = 0

	func process() -> void:
		call_count += 1

	func _to_string() -> String:
		return "CountingEffect"

var _original_save: SaveGameData = null
var _vitals: VitalsManager = null
var _original_vitals: Array[float] = []

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_vitals = PlayerManager.vitals_manager
	_original_vitals = [
		_vitals.current_health, _vitals.max_health,
		_vitals.current_madra, _vitals.max_madra,
		_vitals.current_stamina, _vitals.max_stamina,
	]
	_vitals.max_stamina = 50.0
	_vitals.current_stamina = 50.0

func after_each() -> void:
	_vitals.max_health = _original_vitals[1]
	_vitals.max_madra = _original_vitals[3]
	_vitals.max_stamina = _original_vitals[5]
	_vitals.current_health = _original_vitals[0]
	_vitals.current_madra = _original_vitals[2]
	_vitals.current_stamina = _original_vitals[4]
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

## A consumable with a counting effect and a 10 s cooldown.
func _make_consumable(id: String) -> ConsumableDefinitionData:
	var def := ConsumableDefinitionData.new()
	def.item_id = id
	def.item_name = id.capitalize()
	def.effects = [CountingEffect.new()]
	def.cooldown_seconds = 10.0
	return def

## Puts def on hotbar slot slot_index with held of it in the inventory.
func _equip(def: ConsumableDefinitionData, slot_index: int, held: int) -> void:
	if held > 0:
		InventoryManager.award_items(def, held)
	InventoryManager.equip_consumable(def, slot_index)

## A manager set up for an owner that is (or is not) the player. The owner is a
## bare CombatantNode out of the tree: the manager reads only is_player.
func _make_manager(is_player: bool = true) -> CombatConsumableManager:
	var owner: CombatantNode = autofree(CombatantNode.new())
	owner.is_player = is_player
	var manager: CombatConsumableManager = load(MANAGER_SCENE_PATH).instantiate()
	add_child_autofree(manager)
	manager.setup(owner)
	return manager

## The player's combatant, set up as AdventureCombat sets one up.
func _make_player(abilities: Array[AbilityData]) -> CombatantNode:
	var player: CombatantNode = load(COMBATANT_SCENE_PATH).instantiate()
	add_child_autofree(player)
	var data := CombatantData.new()
	data.character_name = "Player"
	data.attributes = CharacterManager.get_total_attributes_data()
	data.abilities = abilities
	data.texture = load(PLAYER_TEXTURE_PATH)
	player.setup(data, _vitals, true)
	return player

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func test_setup_builds_one_instance_per_filled_slot() -> void:
	var scale_def := _make_consumable("scale")
	var pill := _make_consumable("pill")
	_equip(pill, 2, 1)
	_equip(scale_def, 0, 3)

	var manager := _make_manager()

	assert_eq(manager.consumables.size(), 2, "one instance per filled slot")
	assert_eq(manager.consumables[0].slot_index, 0, "in slot order")
	assert_eq(manager.consumables[0].consumable_data, scale_def)
	assert_eq(manager.consumables[1].slot_index, 2)
	assert_eq(manager.consumables[1].consumable_data, pill)
	for instance: CombatConsumableInstance in manager.consumables:
		assert_eq(instance.get_parent(), manager, "each instance is the manager's child")

func test_setup_builds_none_for_an_enemy() -> void:
	_equip(_make_consumable("scale"), 0, 3)

	var manager := _make_manager(false)

	assert_eq(manager.consumables.size(), 0, "an enemy uses no consumables")

func test_setup_builds_an_instance_for_a_slot_with_none_left() -> void:
	_equip(_make_consumable("scale"), 1, 0)

	var manager := _make_manager()

	assert_eq(manager.consumables.size(), 1, "the slot still holds its consumable")
	assert_false(manager.can_use_consumable_instance(manager.consumables[0]), "but none are left to use")

func test_setup_again_replaces_the_instances() -> void:
	_equip(_make_consumable("scale"), 0, 3)
	var manager := _make_manager()
	var first: CombatConsumableInstance = manager.consumables[0]

	manager.setup(manager.owner_combatant)

	assert_eq(manager.consumables.size(), 1, "still one instance")
	assert_ne(manager.consumables[0], first, "a fresh one")

#-----------------------------------------------------------------------------
# USE
#-----------------------------------------------------------------------------

func test_use_goes_through_the_gate_and_emits() -> void:
	_equip(_make_consumable("scale"), 0, 3)
	var manager := _make_manager()
	var instance: CombatConsumableInstance = manager.consumables[0]
	watch_signals(manager)

	assert_true(manager.use_consumable_instance(instance), "used")
	assert_signal_emitted_with_parameters(manager, "consumable_used", [instance])
	assert_eq(instance.get_count(), 2)

	assert_false(manager.can_use_consumable_instance(instance), "recharging")
	assert_false(manager.use_consumable_instance(instance), "refused while recharging")
	assert_signal_emit_count(manager, "consumable_used", 1, "emitted only for the use that fired")
	assert_eq(instance.get_count(), 2, "the refusal took nothing")

func test_an_instance_from_elsewhere_is_refused() -> void:
	var scale_def := _make_consumable("scale")
	_equip(scale_def, 0, 3)
	var manager := _make_manager()
	var stray := CombatConsumableInstance.new(scale_def, 0)
	add_child_autofree(stray)

	assert_false(manager.can_use_consumable_instance(stray), "not this manager's")
	assert_false(manager.use_consumable_instance(stray))
	assert_eq(stray.get_count(), 3, "nothing used")

func test_get_instance_at_slot() -> void:
	_equip(_make_consumable("scale"), 3, 1)
	var manager := _make_manager()

	assert_eq(manager.get_instance_at_slot(3), manager.consumables[0])
	assert_null(manager.get_instance_at_slot(0), "an empty slot has none")
	assert_null(manager.get_instance_at_slot(7), "nor has a slot past the hotbar")

func test_casting_does_not_block_a_consumable() -> void:
	_equip(_make_consumable("scale"), 0, 3)
	var player := _make_player([BASIC_STRIKE] as Array[AbilityData])
	var enemy: CombatantNode = load(COMBATANT_SCENE_PATH).instantiate()
	add_child_autofree(enemy)
	enemy.setup(ENEMY_DATA, null, false)
	var strike: CombatAbilityInstance = player.ability_manager.abilities[0]
	strike.cooldown_timer.start(0.01)
	assert_true(await wait_for_signal(strike.cooldown_ready, 1.0), "precondition: Basic Strike is ready")
	assert_true(player.ability_manager.use_ability_instance(strike, enemy), "precondition: the cast starts")
	assert_true(player.ability_manager.is_casting(), "precondition: casting")

	var instance: CombatConsumableInstance = player.consumable_manager.consumables[0]

	assert_true(player.consumable_manager.can_use_consumable_instance(instance), "a cast does not lock the consumables")
	assert_true(player.consumable_manager.use_consumable_instance(instance))
	assert_true(player.ability_manager.is_casting(), "and using one does not stop the cast")

func test_the_combatant_mounts_the_manager() -> void:
	_equip(_make_consumable("scale"), 0, 3)

	var player := _make_player([] as Array[AbilityData])

	assert_not_null(player.consumable_manager, "the combatant has a consumable manager")
	assert_eq(player.consumable_manager.consumables.size(), 1, "built from the hotbar at setup")
	assert_eq(player.consumable_manager.owner_combatant, player)
