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

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var player_vitals_manager: VitalsManager = null
var current_combat_choice: CombatChoice = null
var current_adventure_action: AdventureActionData = null

var player_combatant: CombatantNode
var enemy_combatant: CombatantNode

#-----------------------------------------------------------------------------
# TODO: DELETE DEBUG
#-----------------------------------------------------------------------------

@export var debug_abilities: Array[AbilityData] = []
@export var enable_ai: bool = true

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

@onready var ability_panel: Panel = %AbilitiesPanel
@onready var enemy_info_panel: CombatantInfoPanel = %EnemyInfoPanel

func _ready() -> void:
	Log.info("AdventureCombat: Initialized")

## Initializes the combat with the chosen encounter, player resources, and adventure context.
func initialize_combat(
	choice: CombatChoice,
	prm: VitalsManager,
	adventure_action: AdventureActionData
) -> void:
	self.current_combat_choice = choice
	self.player_vitals_manager = prm
	self.current_adventure_action = adventure_action

	# Connect player_vitals_manager to the trigger_combat_end signal
	if not player_vitals_manager.health_changed.is_connected(_on_player_health_changed):
		player_vitals_manager.health_changed.connect(_on_player_health_changed)

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Starts the combat encounter.
func start() -> void:
	Log.info("AdventureCombat: Starting combat")
	
	if not current_combat_choice:
		Log.error("AdventureCombat: No combat choice set!")
		return
		
	if not player_vitals_manager:
		Log.error("AdventureCombat: No player resource manager set!")
		return

	_create_combatants()

## Stops the combat and cleans up.
func stop() -> void:
	# Reset EnemyInfoPanel & AbilitiesPanel
	ability_panel.reset()
	enemy_info_panel.reset()
	
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
	add_child(player_combatant)

	var player_data = CombatantData.new()
	player_data.character_name = "Player"
	player_data.attributes = CharacterManager.get_total_attributes_data()
	player_data.abilities = debug_abilities
	# player_data.abilities = CharacterManager.get_abilities_data()
	player_data.texture = load("res://assets/sprites/combat/test_character_sprite.png")
	player_combatant.position = Vector2(400, 1000)

	# Connect signals BEFORE setup so we catch ability registration
	player_combatant.ability_manager.ability_registered.connect(_on_ability_registered)

	player_combatant.setup(player_data, player_vitals_manager, true)

func _create_enemy_combatant() -> void:
	if current_combat_choice.enemy_pool.is_empty():
		Log.error("AdventureCombat: Enemy pool is empty!")
		return

	# TODO: Handle multiple enemies or random selection from pool
	var enemy_data: CombatantData = current_combat_choice.enemy_pool[0]
	
	enemy_combatant = combatant_scene.instantiate()
	enemy_combatant.name = "EnemyCombatant"
	enemy_combatant.position = Vector2(1100, 300)
	add_child(enemy_combatant)
		
	# Enemy gets a new internal resource manager created by setup()
	enemy_combatant.setup(enemy_data, null, false)
	
	# Setup CombatantInfoPanel
	enemy_info_panel.setup(enemy_combatant.vitals_manager)
	
	# Setup AI
	var ai = SimpleEnemyAI.new()
	ai.name = "EnemyAI"
	if enable_ai:
		enemy_combatant.add_child(ai)
		ai.setup(enemy_combatant, player_combatant)
	
	# Connect player_resource_manager to the trigger_combat_end signal
	enemy_combatant.vitals_manager.health_changed.connect(_on_enemy_health_changed)
	

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
	
	# Get all multipliers
	var base_gold: int = enemy_data.base_gold_drop
	var combat_mult: float = current_combat_choice.gold_multiplier
	var adventure_mult: float = current_adventure_action.gold_multiplier if current_adventure_action else 1.0
	var char_mult: float = CharacterManager.get_gold_multiplier()
	
	# Calculate final gold
	var final_gold: int = int(floor(base_gold * combat_mult * adventure_mult * char_mult))
	
	Log.info("AdventureCombat: Gold calculated - Base: %d, Combat×%.1f, Adv×%.1f, Char×%.1f = %d" % [
		base_gold, combat_mult, adventure_mult, char_mult, final_gold
	])
	
	return final_gold


#-----------------------------------------------------------------------------
# UI HANDLERS
#-----------------------------------------------------------------------------

var ability_button_scene: PackedScene = preload("res://scenes/ui/combat/ability_button/ability_button.tscn")

func _on_ability_registered(instance: CombatAbilityInstance) -> void:
	if not ability_panel:
		Log.warn("AdventureCombat: No ability_bar assigned!")
		return
		
	var button = ability_button_scene.instantiate()
	ability_panel.add_button(button)
	button.setup(instance)
	button.pressed.connect(_on_ability_button_pressed.bind(instance))
	Log.info("AdventureCombat: Added button for " + instance.ability_data.ability_name)

func _on_ability_button_pressed(instance: CombatAbilityInstance) -> void:
	# Find enemy target (simplification: assume first enemy found)
	if enemy_combatant:
		player_combatant.ability_manager.use_ability_instance(instance, enemy_combatant)
	else:
		Log.warn("AdventureCombat: No enemy to target!")
