class_name AdventureCombat
extends Node2D

## AdventureCombat
## Handles combat encounters during adventure mode
## This scene manages the combat UI, enemy spawning, and combat resolution

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# SCENES
#-----------------------------------------------------------------------------

var combatant_scene: PackedScene = preload("res://scenes/game_systems/combat/combatant/combatant_node.tscn")

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var player_resource_manager: CombatResourceManager = null
var encounter: CombatEncounter = null

var player_combatant : CombatantNode
var enemy_combatant : CombatantNode

#-----------------------------------------------------------------------------
# TODO: DELETE DEBUG
#-----------------------------------------------------------------------------

@export var debug_abilities: Array[AbilityData] = []

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

@onready var ability_panel: Panel = %AbilitiesPanel
@onready var enemy_info_panel : CombatantInfoPanel = %EnemyInfoPanel

func _ready() -> void:
	Log.info("AdventureCombat: Initialized")

func initialize_with_player_resource_manager(e: CombatEncounter, prm: CombatResourceManager) -> void:
	self.encounter = e
	self.player_resource_manager = prm

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

func start() -> void:
	Log.info("AdventureCombat: Starting combat")
	
	if not encounter:
		Log.error("AdventureCombat: No encounter set!")
		return
		
	if not player_resource_manager:
		Log.error("AdventureCombat: No player resource manager set!")
		return

	_create_combatants()

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
	player_data.texture = load("res://assets/sprites/combat/test_character_sprite.png")
	player_combatant.position = Vector2(400, 1000)
	# player_data.abilities = CharacterManager.get_abilities_data()

	# Connect signals BEFORE setup so we catch ability registration
	player_combatant.ability_manager.ability_registered.connect(_on_ability_registered)

	player_combatant.setup(player_data, player_resource_manager, true)
	

func _create_enemy_combatant() -> void:
	var enemy_data : CombatantData = encounter.enemy_pool[0]
	
	enemy_combatant = combatant_scene.instantiate()
	enemy_combatant.name = "EnemyCombatant"
	enemy_combatant.position = Vector2(1100, 300)
	add_child(enemy_combatant)
		
	# Enemy gets a new internal resource manager created by setup()
	enemy_combatant.setup(enemy_data, null, false)
	
	# Setup AI
	var ai = SimpleEnemyAI.new()
	ai.name = "EnemyAI"
	enemy_combatant.add_child(ai)
	ai.setup(enemy_combatant, player_combatant)
	
	# Setup CombatantInfoPanel
	enemy_info_panel.setup(enemy_combatant.resource_manager)


#-----------------------------------------------------------------------------
# UI HANDLERS
#-----------------------------------------------------------------------------

var ability_button_scene : PackedScene = preload("res://scenes/ui/combat/ability_button/ability_button.tscn")

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
