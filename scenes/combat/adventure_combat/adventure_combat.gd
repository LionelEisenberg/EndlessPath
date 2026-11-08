class_name AdventureCombat
extends Node2D

## AdventureCombat
## Handles combat encounters during adventure mode
## This scene manages the combat UI, enemy spawning, and combat resolution.
## A fight is live only between its start and the hit that decides it (#138):
## start() makes both fighters held (CombatantNode.set_held()), waiting off their
## spots with the enemy's name hidden, while AdventureView plays the way in;
## begin() lets both act in one frame, so their openings start together. The hit
## that takes a side to 0 Health decides the fight: both fighters are held again,
## so nothing in it acts while its close plays, and trigger_combat_end reports the
## end once. Only a live fight hears the player's presses.

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

## Whether the fight has begun and its deciding hit has not landed.
var _live: bool = false
## Whether the deciding hit has landed.
var _decided: bool = false

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

	# The player's Health ends the fight at 0 until stop() lets it go
	if not PlayerManager.vitals_manager.health_changed.is_connected(_on_player_health_changed):
		PlayerManager.vitals_manager.health_changed.connect(_on_player_health_changed)

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Sets the fight up held: both fighters made, waiting off their spots
## (CombatantVisual.place_for_entrance()) with nothing of theirs running, and the
## enemy's name hidden. begin() starts it.
func start() -> void:
	Log.info("AdventureCombat: Starting combat")

	if not current_combat_choice:
		Log.error("AdventureCombat: No combat choice set!")
		return

	if not PlayerManager.vitals_manager:
		Log.error("AdventureCombat: No player resource manager set!")
		return

	_live = false
	_decided = false
	_create_combatants()
	for fighter: CombatantNode in _fighters():
		fighter.set_held(true)
	enemy_nameplate.visible = false

## Slides both fighters in from their sides to their spots
## (CombatantVisual.play_enter()).
func play_enter() -> void:
	for fighter: CombatantNode in _fighters():
		fighter.visual.play_enter()

## Starts the fight: both fighters act from this frame, so the player's techniques
## and the enemy's AI start their openings together, and the enemy's name shows.
## Does nothing once the fight has begun or been decided.
func begin() -> void:
	if _live or _decided:
		return
	_live = true
	for fighter: CombatantNode in _fighters():
		fighter.set_held(false)
	enemy_nameplate.visible = true

## Whether the fight has begun and its deciding hit has not landed.
func is_live() -> bool:
	return _live

## The loser's fall (CombatantVisual.play_defeat()): the enemy on a win, the
## player on a loss. The enemy's name goes as its fall starts.
func play_defeat(won: bool) -> void:
	var loser: CombatantNode = enemy_combatant if won else player_combatant
	if won:
		enemy_nameplate.visible = false
	if is_instance_valid(loser):
		loser.visual.play_defeat()

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

## Stops the combat and cleans up. The fight stops listening to the player's
## Health, so Health reaching 0 once it is over reports no fight.
func stop() -> void:
	enemy_nameplate.reset()
	enemy_nameplate.visible = false
	_live = false
	_decided = false
	_let_go_of_player_health()

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

## The fight's fighters that are there. Each is checked before it goes in, since a
## freed one cannot go into a typed array.
func _fighters() -> Array[CombatantNode]:
	var fighters: Array[CombatantNode] = []
	if is_instance_valid(player_combatant):
		fighters.append(player_combatant)
	if is_instance_valid(enemy_combatant):
		fighters.append(enemy_combatant)
	return fighters

## The hit that took a side to 0 Health decides the fight: from it nothing in the
## fight acts (both fighters are held), and the end is reported once.
func _decide(won: bool, gold: int) -> void:
	_live = false
	_decided = true
	for fighter: CombatantNode in _fighters():
		fighter.set_held(true)
	trigger_combat_end.emit(won, gold)

## Disconnects the player's Health handler initialize_combat() connected. The
## player's vitals manager may have been replaced (PlayerManager.reset_vitals()).
func _let_go_of_player_health() -> void:
	var vitals: VitalsManager = PlayerManager.vitals_manager
	if is_instance_valid(vitals) and vitals.health_changed.is_connected(_on_player_health_changed):
		vitals.health_changed.disconnect(_on_player_health_changed)
	
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
	player_combatant.visual.place_for_entrance()

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

	enemy_combatant.visual.place_for_entrance()

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

## Health at 0 decides a live fight. Before it begins (only the dev panel writes
## Health then) and once it is decided, Health decides nothing.
func _on_player_health_changed(health: float) -> void:
	if health <= 0.0 and _live:
		Log.info("AdventureCombat: Player died")
		_decide(false, 0) # No gold on defeat

func _on_enemy_health_changed(health: float) -> void:
	if health <= 0.0 and _live:
		Log.info("AdventureCombat: Enemy died")
		var gold = _calculate_gold_reward()
		# Fire the q_first_steps_enemy_defeated event before the win is reported.
		# EventManager deduplicates — subsequent victories are no-ops on this event.
		if EventManager:
			EventManager.trigger_event("q_first_steps_enemy_defeated")
		_decide(true, gold)

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

## Uses a technique the player pressed on the technique dock on the enemy. Does
## nothing unless the fight is live.
func on_player_ability_selected(instance: CombatAbilityInstance) -> void:
	if not _live:
		return
	if enemy_combatant:
		player_combatant.ability_manager.use_ability_instance(instance, enemy_combatant)
	else:
		Log.warn("AdventureCombat: No enemy to target!")

## Uses a hotbar consumable the player pressed on the technique dock. A
## consumable needs no target. Does nothing unless the fight is live.
func on_player_consumable_selected(instance: CombatConsumableInstance) -> void:
	if not _live:
		return
	if player_combatant:
		player_combatant.consumable_manager.use_consumable_instance(instance)
	else:
		Log.warn("AdventureCombat: No player to use a consumable!")
