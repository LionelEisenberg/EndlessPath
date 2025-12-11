class_name AdventureView
extends Control

## AdventureView
## Main controller for the adventure mode, managing transitions between
## tilemap exploration and combat encounters

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var adventure_tilemap: AdventureTilemap = %AdventureTilemap
@onready var combat: AdventureCombat = %AdventureCombat

@onready var tilemap_view: Control = %TilemapView
@onready var combat_view: Control = %CombatView

@onready var player_info_panel: CombatantInfoPanel = %PlayerInfoPanel

@onready var adventure_timer: Timer = Timer.new()
@onready var timer_label: Label = Label.new()

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------
var current_encounter: AdventureEncounter = null
var current_action_data: AdventureActionData = null

var is_in_combat: bool = false # Whether the player is currently in combat

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	Log.info("AdventureView: Initializing")
	if ActionManager:
		ActionManager.start_adventure.connect(start_adventure)
		ActionManager.stop_adventure.connect(stop_adventure)
	else:
		Log.critical("AdventureView: ActionManager is missing!")
	
	if adventure_tilemap:
		adventure_tilemap.start_combat.connect(_on_start_combat)
	else:
		Log.error("AdventureView: AdventureTilemap reference is missing!")
	
	# TODO: Remove this temporary debug button
	$Button2.pressed.connect(_on_stop_combat.bind(true))

	# Setup Timer
	adventure_timer.name = "AdventureTimer"
	adventure_timer.one_shot = true
	adventure_timer.timeout.connect(_on_adventure_timer_timeout)
	add_child(adventure_timer)

	# Setup Timer Label (Temporary UI)
	timer_label.name = "TimerLabel"
	timer_label.position = Vector2(50, 50)
	timer_label.add_theme_font_size_override("font_size", 32)
	add_child(timer_label)

func _process(_delta: float) -> void:
	if current_action_data and not adventure_timer.is_stopped():
		# Update Timer Label
		var time_left = adventure_timer.time_left
		var minutes = floor(time_left / 60)
		var seconds = int(time_left) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Start an adventure with the given action data
func start_adventure(action_data: AdventureActionData) -> void:
	Log.info("AdventureView: Starting adventure - %s" % action_data.action_name)
	
	if LogManager:
		LogManager.log_message("[color=cyan]Adventure Started: %s[/color]" % action_data.action_name)
	
	current_action_data = action_data

	# Initialize resource values
	_initialize_combat_resources()
	
	if PlayerManager.vitals_manager:
		_update_stamina_regen(action_data.stamina_regen_modifier)

	
	# Start Timer
	var time_limit = action_data.time_limit_seconds if action_data.time_limit_seconds > 0 else 10
	adventure_timer.start(time_limit)
	timer_label.visible = true
	
	adventure_tilemap.start_adventure(action_data)
	
	# Connect to the combat node
	if not combat.trigger_combat_end.is_connected(_on_stop_combat):
		combat.trigger_combat_end.connect(_on_stop_combat)

	# Ensure we're showing the tilemap view
	tilemap_view.visible = true
	combat_view.visible = false
	
## Stop the current adventure and cleanup
func stop_adventure() -> void:
	Log.info("AdventureView: Stopping adventure")
	
	if LogManager:
		LogManager.log_message("[color=cyan]Adventure Ended[/color]")
		
	adventure_tilemap.stop_adventure()
	adventure_timer.stop()
	timer_label.visible = false
	current_action_data = null
	_update_stamina_regen(0.0)
	if is_in_combat:
		_on_stop_combat()

#-----------------------------------------------------------------------------
# PRIVATE METHODS - View Management
#-----------------------------------------------------------------------------

## Transition from tilemap view to combat view
func _on_start_combat(choice: CombatChoice) -> void:
	if choice == null:
		Log.error("AdventureView: Cannot start combat with null choice")
		return
	

	# Start the combat encounter
	if combat:
		combat.initialize_combat(
			choice,
			current_action_data # Pass adventure action data for gold multiplier
		)
		combat.start()
		# Enable buffs and abilities for player
		if combat.player_combatant:
			player_info_panel.setup_buffs(combat.player_combatant.buff_manager)
			player_info_panel.setup_abilities(combat.player_combatant.ability_manager)
			player_info_panel.position = Vector2(200, 225)
			
			if not player_info_panel.ability_selected.is_connected(combat.on_player_ability_selected):
				player_info_panel.ability_selected.connect(combat.on_player_ability_selected)
		
	is_in_combat = true
	
	Log.info("AdventureView: Transitioning to combat view - %s" % choice.label)
	if LogManager:
		LogManager.log_message("[color=orange]Encounter: %s[/color]" % choice.label)
		
	tilemap_view.visible = false
	combat_view.visible = true

## Transition from combat view back to tilemap view
func _on_stop_combat(successful: bool = false, gold_earned: int = 0) -> void:
	Log.info("AdventureView: Combat ended - Success: %s, Gold: %d" % [successful, gold_earned])
	
	if LogManager:
		if successful:
			LogManager.log_message("[color=green]Combat Victory![/color]")
		else:
			LogManager.log_message("[color=red]Combat Defeat...[/color]")
	
	# Disconnect player ability signal
	if combat and player_info_panel.ability_selected.is_connected(combat.on_player_ability_selected):
		player_info_panel.ability_selected.disconnect(combat.on_player_ability_selected)
	
	tilemap_view.visible = true
	combat_view.visible = false
	
	# Notify the tilemap that combat has ended (tilemap handles reward processing)
	combat.stop()
	adventure_tilemap.handle_combat_result(successful, gold_earned)
	
	is_in_combat = false
	
	player_info_panel.position = Vector2(50, 700)
	
	if current_action_data:
		if not successful:
			ActionManager.stop_action(successful)

#-----------------------------------------------------------------------------
# PRIVATE METHODS - Resource Management
#-----------------------------------------------------------------------------

## Initialize resource values
func _initialize_combat_resources() -> void:
	PlayerManager.vitals_manager.initialize_current_values()
	player_info_panel.setup_vitals(PlayerManager.vitals_manager)

## Updates the stamina regeneration based on the given modifier
## TODO: This will be expanded later to include more complex calculation logic
func _update_stamina_regen(modifier: float) -> void:
	if PlayerManager.vitals_manager:
		PlayerManager.vitals_manager.stamina_regen = 1.0 * modifier

func _on_adventure_timer_timeout() -> void:
	Log.info("AdventureView: Time limit reached!")
	ActionManager.stop_action(false)
