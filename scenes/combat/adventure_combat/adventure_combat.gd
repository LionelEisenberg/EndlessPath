class_name AdventureCombat
extends Node2D

## AdventureCombat
## Handles combat encounters during adventure mode
## This scene manages the combat UI, enemy spawning, and combat resolution

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal trigger_combat_end(is_successful: bool, gold_earned: int)

#-----------------------------------------------------------------------------
# SCENES
#-----------------------------------------------------------------------------

var combatant_scene: PackedScene = preload("res://scenes/combat/combatant/combatant_node.tscn")
var atmosphere_scene: PackedScene = preload("res://scenes/atmosphere/atmosphere.tscn")

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var current_combat_choice: CombatChoice = null
var current_adventure_action: AdventureActionData = null

var player_combatant: CombatantNode
var enemy_combatant: CombatantNode
var _atmosphere: Node

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

@onready var enemy_nameplate: EnemyNameplate = %EnemyNameplate
@onready var _player_spot: Marker2D = %PlayerSpot
@onready var _enemy_spot: Marker2D = %EnemySpot

## Gap (px) between the top of the enemy sprite and its nameplate.
const NAMEPLATE_GAP: float = 18.0

func _ready() -> void:
	Log.info("AdventureCombat: Initialized")
	_setup_atmosphere()

func _setup_atmosphere() -> void:
	_atmosphere = atmosphere_scene.instantiate()
	# Match adventure tilemap settings
	_atmosphere.vignette_radius = 0.5
	_atmosphere.vignette_softness = 0.35
	_atmosphere.vignette_color = Color(0.0, 0.005, 0.025, 1.0)
	_atmosphere.cyan_mote_count = 25
	_atmosphere.warm_mote_count = 8
	# Insert at index 0 so it renders behind everything
	add_child(_atmosphere)
	move_child(_atmosphere, 0)

## Initializes the combat with the chosen encounter, and adventure context.
func initialize_combat(
	choice: CombatChoice,
	adventure_action: AdventureActionData
) -> void:
	self.current_combat_choice = choice
	self.current_adventure_action = adventure_action

	# Connect PlayerManager.vitals_manager to the trigger_combat_end signal
	if not PlayerManager.vitals_manager.health_changed.is_connected(_on_player_health_changed):
		PlayerManager.vitals_manager.health_changed.connect(_on_player_health_changed)

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Starts the combat encounter.
func start() -> void:
	Log.info("AdventureCombat: Starting combat")
	
	if not current_combat_choice:
		Log.error("AdventureCombat: No combat choice set!")
		return
		
	if not PlayerManager.vitals_manager:
		Log.error("AdventureCombat: No player resource manager set!")
		return

	_create_combatants()

## Returns the gold a win over the choice's enemy pays: the enemy's base gold
## drop (enemy_pool[0], the one the fight is against) x the choice's gold
## multiplier x the adventure action's (1 when there is no action) x the
## character's, rounded down. 0 for a choice with nobody in its pool. The fight
## pays this, and the adventure chest quotes it before the fight, so both read
## the one rule.
static func gold_reward_for(choice: CombatChoice, adventure_action: AdventureActionData) -> int:
	if choice == null or choice.enemy_pool.is_empty() or choice.enemy_pool[0] == null:
		return 0
	var base_gold: int = choice.enemy_pool[0].base_gold_drop
	return floori(base_gold * choice.gold_multiplier * _adventure_gold_multiplier(adventure_action) * CharacterManager.get_gold_multiplier())

## Stops the combat and cleans up.
func stop() -> void:
	enemy_nameplate.reset()
	
	# Clear all buffs before freeing combatants
	if player_combatant and player_combatant.buff_manager:
		player_combatant.buff_manager.clear_all_buffs()
	if enemy_combatant and enemy_combatant.buff_manager:
		enemy_combatant.buff_manager.clear_all_buffs()
	
	if player_combatant:
		player_combatant.queue_free()
	if enemy_combatant:
		enemy_combatant.queue_free()

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _create_combatants() -> void:
	_create_player_combatant()
	_create_enemy_combatant()
	
func _create_player_combatant() -> void:
	player_combatant = combatant_scene.instantiate()
	player_combatant.name = "PlayerCombatant"
	player_combatant.position = _player_spot.position
	add_child(player_combatant)

	var player_data = CombatantData.new()
	player_data.character_name = "Player"
	player_data.attributes = CharacterManager.get_total_attributes_data()
	player_data.abilities = AbilityManager.get_equipped_abilities()
	player_data.texture = load("res://assets/sprites/combat/test_character_sprite.png")

	player_combatant.setup(player_data, PlayerManager.vitals_manager, true)
	player_combatant.visual.play_enter()

func _create_enemy_combatant() -> void:
	if current_combat_choice.enemy_pool.is_empty():
		Log.error("AdventureCombat: Enemy pool is empty!")
		return

	# TODO: Handle multiple enemies or random selection from pool
	var enemy_data: CombatantData = current_combat_choice.enemy_pool[0]
	
	enemy_combatant = combatant_scene.instantiate()
	enemy_combatant.name = "EnemyCombatant"
	enemy_combatant.position = _enemy_spot.position
	add_child(enemy_combatant)
		
	# Enemy gets a new internal resource manager created by setup()
	enemy_combatant.setup(enemy_data, null, false)

	enemy_combatant.visual.play_enter()

	enemy_nameplate.setup(enemy_combatant)
	_place_nameplate.call_deferred()
	
	# Setup AI
	var ai = SimpleEnemyAI.new()
	ai.name = "EnemyAI"
	enemy_combatant.add_child(ai)
	ai.setup(enemy_combatant, player_combatant)
	
	# Connect player_resource_manager to the trigger_combat_end signal
	enemy_combatant.vitals_manager.health_changed.connect(_on_enemy_health_changed)
	
## Centers the enemy nameplate just above the enemy sprite.
func _place_nameplate() -> void:
	if not enemy_combatant:
		return
	enemy_nameplate.reset_size()
	var plate_size: Vector2 = enemy_nameplate.get_combined_minimum_size()
	var top_of_sprite: float = _enemy_spot.position.y - enemy_combatant.visual.get_visual_height()
	enemy_nameplate.position = Vector2(
		_enemy_spot.position.x - plate_size.x / 2.0,
		top_of_sprite - plate_size.y - NAMEPLATE_GAP
	)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_player_health_changed(health: float) -> void:
	if health <= 0.0:
		Log.info("AdventureCombat: Player died")
		trigger_combat_end.emit(false, 0) # No gold on defeat

func _on_enemy_health_changed(health: float) -> void:
	if health <= 0.0:
		Log.info("AdventureCombat: Enemy died")
		var gold = _calculate_gold_reward()
		# Fire the q_first_steps_enemy_defeated event so Foundation Beat 2's
		# quest step advances. EventManager deduplicates — subsequent victories
		# are no-ops on this event.
		if EventManager:
			EventManager.trigger_event("q_first_steps_enemy_defeated")
		trigger_combat_end.emit(true, gold)

## Calculate gold reward using multi-factor formula
func _calculate_gold_reward() -> int:
	if not enemy_combatant or not current_combat_choice:
		Log.warn("AdventureCombat: Cannot calculate gold - missing enemy or combat choice")
		return 0
	
	# Get enemy data from combat choice
	var enemy_data: CombatantData = current_combat_choice.enemy_pool[0] if not current_combat_choice.enemy_pool.is_empty() else null
	if not enemy_data:
		Log.warn("AdventureCombat: No enemy data in combat choice")
		return 0
	
	# The formula is gold_reward_for(); the factors are read here for the log line
	var base_gold: int = enemy_data.base_gold_drop
	var combat_mult: float = current_combat_choice.gold_multiplier
	var adventure_mult: float = _adventure_gold_multiplier(current_adventure_action)
	var char_mult: float = CharacterManager.get_gold_multiplier()
	var final_gold: int = gold_reward_for(current_combat_choice, current_adventure_action)

	Log.info("AdventureCombat: Gold calculated - Base: %d, Combat×%.1f, Adv×%.1f, Char×%.1f = %d" % [
		base_gold, combat_mult, adventure_mult, char_mult, final_gold
	])
	
	return final_gold

## The adventure action's gold multiplier, 1 when there is no action.
static func _adventure_gold_multiplier(adventure_action: AdventureActionData) -> float:
	return adventure_action.gold_multiplier if adventure_action else 1.0

#-----------------------------------------------------------------------------
# UI HANDLERS
#-----------------------------------------------------------------------------

func on_player_ability_selected(instance: CombatAbilityInstance) -> void:
	# Player used an ability from their UI panel
	if enemy_combatant:
		player_combatant.ability_manager.use_ability_instance(instance, enemy_combatant)
	else:
		Log.warn("AdventureCombat: No enemy to target!")
