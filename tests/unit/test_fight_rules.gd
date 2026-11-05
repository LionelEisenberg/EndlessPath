extends GutTest

## The rules a fight runs on: an enemy's max Health
## (CharacterAttributesData.get_max_health(), Body x 10), the gold a win pays
## (AdventureCombat.gold_reward_for()) and the Core Density XP it pays by its tier
## (AdventureActionData.get_core_density_xp_for()). The chest's Here tray and choice drawers
## no longer quote either figure (the developer asked for less in the chest), but
## the rules stay for what may bring them back: the Health as an unlockable, the
## gold on the opponent page's reward row. The last test runs a real
## AdventureCombat fight, as test_adventure_combat_victory_event.gd does, and
## checks that the gold the win reports is the rule's.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const AdventureCombatScene := preload("res://scenes/combat/adventure_combat/adventure_combat.tscn")
const AMORPHOUS_SPIRIT := preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
## More damage than any health pool, so one hit always leaves 0 HP.
const LETHAL_DAMAGE := -1000000.0

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _combat: AdventureCombat
var _original_save: SaveGameData
var _original_player_health: float
## One entry per trigger_combat_end emission: [is_successful, gold_earned].
var _combat_ends: Array[Array] = []

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_original_player_health = PlayerManager.vitals_manager.current_health
	_combat_ends.clear()

func after_each() -> void:
	# Free a fight first so restoring the player's health below does not reach
	# its PlayerManager.vitals_manager connections.
	if is_instance_valid(_combat):
		_combat.free()
	_combat = null
	PlayerManager.vitals_manager.current_health = _original_player_health
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# A save reset starts the zone's idle action: stop what it started.
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _enemy(base_gold: int) -> CombatantData:
	var enemy := CombatantData.new()
	enemy.base_gold_drop = base_gold
	return enemy

func _choice(enemy: CombatantData, gold_multiplier: float = 1.0) -> CombatChoice:
	var choice := CombatChoice.new()
	var pool: Array[CombatantData] = [enemy]
	choice.enemy_pool = pool
	choice.gold_multiplier = gold_multiplier
	return choice

func _action(gold_multiplier: float) -> AdventureActionData:
	var action := AdventureActionData.new()
	action.gold_multiplier = gold_multiplier
	return action

## Starts a real fight over `choice`, as AdventureView._on_start_combat() does,
## and ends it in the same frame by dropping the enemy's real vitals to 0 HP,
## before the enemy AI's first _process() can act.
func _win_fight_over(choice: CombatChoice, adventure_action: AdventureActionData) -> void:
	_combat = AdventureCombatScene.instantiate()
	add_child_autofree(_combat)
	_combat.trigger_combat_end.connect(_on_combat_end)
	_combat.initialize_combat(choice, adventure_action)
	_combat.start()
	_combat.enemy_combatant.vitals_manager.apply_vitals_change(LETHAL_DAMAGE)

func _on_combat_end(is_successful: bool, gold_earned: int) -> void:
	_combat_ends.append([is_successful, gold_earned])

#-----------------------------------------------------------------------------
# MAX HEALTH
#-----------------------------------------------------------------------------

func test_max_health_is_body_times_ten() -> void:
	var attributes := CharacterAttributesData.new()
	attributes.body = 12.0
	assert_eq(attributes.get_max_health(), 120.0, "Body 12 is 120 Health")

	var vitals := VitalsManager.new()
	vitals.character_attributes_data = attributes
	add_child_autofree(vitals)
	assert_eq(vitals.max_health, 120.0, "the manager's max Health, once it is ready")
	assert_eq(vitals.max_health, attributes.get_max_health(), "is the rule's answer")

func test_max_health_reads_only_body() -> void:
	var attributes := CharacterAttributesData.make({
		&"strength": 99.0, &"body": 7.5, &"agility": 99.0, &"spirit": 99.0, &"mind": 99.0, &"control": 99.0,
	})
	assert_eq(attributes.get_max_health(), 75.0, "Body 7.5 is 75 Health, whatever the rest is")

func test_a_manager_follows_the_rule_when_its_attributes_change() -> void:
	var vitals := VitalsManager.new()
	add_child_autofree(vitals)
	var attributes := CharacterAttributesData.new()
	attributes.body = 8.5
	vitals.character_attributes_data = attributes
	assert_eq(vitals.max_health, 85.0)
	attributes = CharacterAttributesData.new()
	attributes.body = 20.0
	vitals.character_attributes_data = attributes
	assert_eq(vitals.max_health, attributes.get_max_health())
	assert_eq(vitals.max_health, 200.0)

#-----------------------------------------------------------------------------
# GOLD REWARD
#-----------------------------------------------------------------------------

## Base x the choice's multiplier x the action's x the character's, floored.
## Each factor is moved on its own, so a dropped one shows.
func test_gold_reward_multiplies_every_factor() -> void:
	var choice: CombatChoice = _choice(_enemy(15), 1.5)
	var action: AdventureActionData = _action(1.5)
	assert_eq(CharacterManager.get_gold_multiplier(), 1.0, "precondition: the character's own multiplier is 1 for now")
	assert_eq(AdventureCombat.gold_reward_for(choice, action), 33, "15 x 1.5 x 1.5 = 33.75, floored")

	assert_eq(AdventureCombat.gold_reward_for(_choice(_enemy(20), 1.5), action), 45, "the base moves it")
	assert_eq(AdventureCombat.gold_reward_for(_choice(_enemy(15), 2.0), action), 45, "the choice's multiplier moves it")
	assert_eq(AdventureCombat.gold_reward_for(choice, _action(2.0)), 45, "the action's multiplier moves it")

func test_gold_reward_floors() -> void:
	assert_eq(AdventureCombat.gold_reward_for(_choice(_enemy(15), 1.5), null), 22, "22.5 pays 22")
	assert_eq(AdventureCombat.gold_reward_for(_choice(_enemy(15), 0.99), null), 14, "14.85 pays 14, not 15")

func test_gold_reward_without_an_action() -> void:
	assert_eq(AdventureCombat.gold_reward_for(_choice(_enemy(15), 1.0), null), 15, "no action counts as x1")
	assert_eq(AdventureCombat.gold_reward_for(_choice(_enemy(15), 2.0), null), 30)
	assert_eq(AdventureCombat.gold_reward_for(_choice(_enemy(15), 2.0), _action(1.0)), 30, "an action of x1 is the same as none")

func test_gold_reward_empty_pool_is_zero() -> void:
	var choice := CombatChoice.new()
	assert_true(choice.enemy_pool.is_empty(), "precondition: nobody to fight")
	assert_eq(AdventureCombat.gold_reward_for(choice, null), 0)
	assert_eq(AdventureCombat.gold_reward_for(choice, _action(3.0)), 0, "whatever the action's multiplier")
	assert_eq(AdventureCombat.gold_reward_for(null, null), 0, "and no choice at all")

## The enemy is enemy_pool[0], the one AdventureCombat fights.
func test_gold_reward_asks_the_first_enemy() -> void:
	var choice := CombatChoice.new()
	var pool: Array[CombatantData] = [_enemy(10), _enemy(500)]
	choice.enemy_pool = pool
	assert_eq(AdventureCombat.gold_reward_for(choice, null), 10)

#-----------------------------------------------------------------------------
# CORE DENSITY REWARD
#-----------------------------------------------------------------------------

## An action paying 7 for a regular fight, 9 for an elite and 13 for the boss.
func _paying_action() -> AdventureActionData:
	var action := AdventureActionData.new()
	action.core_density_xp_regular = 7.0
	action.core_density_xp_elite = 9.0
	action.core_density_xp_boss = 13.0
	return action

## The tier is the tile's encounter type, and the combat choice's boss flag marks
## the boss wherever it stands. Only fights pay.
func test_core_density_reward_by_encounter_type() -> void:
	var action: AdventureActionData = _paying_action()
	var cases: Array[Dictionary] = [
		{"name": "a regular fight", "type": AdventureEncounter.EncounterType.COMBAT_REGULAR, "is_boss": false, "xp": 7.0},
		{"name": "an ambush pays as a regular fight", "type": AdventureEncounter.EncounterType.COMBAT_AMBUSH, "is_boss": false, "xp": 7.0},
		{"name": "an elite", "type": AdventureEncounter.EncounterType.COMBAT_ELITE, "is_boss": false, "xp": 9.0},
		{"name": "the boss's tile", "type": AdventureEncounter.EncounterType.COMBAT_BOSS, "is_boss": false, "xp": 13.0},
		{"name": "the boss's choice on a regular tile", "type": AdventureEncounter.EncounterType.COMBAT_REGULAR, "is_boss": true, "xp": 13.0},
		{"name": "the boss's choice on open ground", "type": AdventureEncounter.EncounterType.NONE, "is_boss": true, "xp": 13.0},
		{"name": "a rest site", "type": AdventureEncounter.EncounterType.REST_SITE, "is_boss": false, "xp": 0.0},
		{"name": "a trap", "type": AdventureEncounter.EncounterType.TRAP, "is_boss": false, "xp": 0.0},
		{"name": "a treasure", "type": AdventureEncounter.EncounterType.TREASURE, "is_boss": false, "xp": 0.0},
		{"name": "open ground", "type": AdventureEncounter.EncounterType.NONE, "is_boss": false, "xp": 0.0},
	]
	for case: Dictionary in cases:
		assert_eq(action.get_core_density_xp_for(case.type, case.is_boss), case.xp, case.name)

## The class pays nothing: an adventure action's file writes its amounts out.
func test_an_action_pays_nothing_unless_its_file_says_so() -> void:
	var action := AdventureActionData.new()
	assert_eq(action.get_core_density_xp_for(AdventureEncounter.EncounterType.COMBAT_REGULAR, false), 0.0, "regular")
	assert_eq(action.get_core_density_xp_for(AdventureEncounter.EncounterType.COMBAT_ELITE, false), 0.0, "elite")
	assert_eq(action.get_core_density_xp_for(AdventureEncounter.EncounterType.COMBAT_BOSS, true), 0.0, "boss")

## A real fight won over a x1.5 choice pays what the rule says, with an action
## of x2 (15 x 1.5 x 2.0 = 45) and with no action (15 x 1.5 = 22.5, floored).
func test_fight_pays_the_rule() -> void:
	assert_eq(AMORPHOUS_SPIRIT.base_gold_drop, 15, "precondition: the shipped spirit's drop")
	var cases: Array[Dictionary] = [
		{"name": "an action of x2", "action": _action(2.0), "gold": 45},
		{"name": "no action", "action": null, "gold": 22},
	]
	for case: Dictionary in cases:
		var choice: CombatChoice = _choice(AMORPHOUS_SPIRIT, 1.5)
		_combat_ends.clear()

		_win_fight_over(choice, case.action)

		assert_eq(_combat_ends.size(), 1, "%s: the fight ends once" % case.name)
		if _combat_ends.size() == 1:
			assert_true(_combat_ends[0][0], "%s: as a win" % case.name)
			assert_eq(_combat_ends[0][1], AdventureCombat.gold_reward_for(choice, case.action), "%s: paying what the rule says" % case.name)
			assert_eq(_combat_ends[0][1], case.gold, case.name)
		# The next case starts a fight of its own.
		_combat.free()
