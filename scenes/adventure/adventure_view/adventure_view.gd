class_name AdventureView
extends Control

signal adventure_completed(result_data: AdventureResultData)

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

@onready var timer_panel: TimerPanel = %TimerPanel

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------
var current_encounter: AdventureEncounter = null
var current_action_data: AdventureActionData = null

var is_in_combat: bool = false # Whether the player is currently in combat

# Adventure result tracking
var _combats_fought: int = 0
var _gold_earned: int = 0
var _madra_budget: float = 0.0
var _loot_items: Array[Resource] = []
var _adventure_start_time: float = 0.0
var _pending_victory: bool = false

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
	
	# Setup Timer
	timer_panel.timer.timeout.connect(_on_adventure_timer_timeout)

	# Listen for boss victory from tilemap
	if adventure_tilemap:
		adventure_tilemap.boss_defeated.connect(_on_boss_defeated)

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Start an adventure with the given action data
func start_adventure(action_data: AdventureActionData, madra_budget: float = -1.0) -> void:
	Log.info("AdventureView: Starting adventure - %s" % action_data.action_name)

	if LogManager:
		LogManager.log_message("[color=cyan]Adventure Started: %s[/color]" % action_data.action_name)

	current_action_data = action_data

	# Reset result tracking
	_combats_fought = 0
	_gold_earned = 0
	_madra_budget = madra_budget
	_loot_items.clear()
	_adventure_start_time = Time.get_ticks_msec() / 1000.0
	_pending_victory = false

	# Listen for item awards during this adventure
	if InventoryManager and not InventoryManager.item_awarded.is_connected(_on_item_awarded):
		InventoryManager.item_awarded.connect(_on_item_awarded)

	# Initialize resource values with the actual budget drained from zone pool
	_initialize_combat_resources(madra_budget)
	
	if PlayerManager.vitals_manager:
		_update_stamina_regen(action_data.stamina_regen_modifier)

	
	# Start Timer
	var time_limit = action_data.time_limit_seconds if action_data.time_limit_seconds > 0 else 10
	timer_panel.start(time_limit)
	timer_panel.visible = true
	
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

	# Determine end condition from current state
	var is_victory: bool = false
	var defeat_reason: String = ""

	if _pending_victory:
		is_victory = true
	elif PlayerManager.vitals_manager.current_health <= 0.0:
		defeat_reason = "Your health reached zero"
	elif timer_panel.timer.is_stopped() or timer_panel.timer.time_left <= 0.0:
		defeat_reason = "Time ran out"
	else:
		defeat_reason = "You retreated from the adventure"

	# Build result before cleanup clears the data
	var result_data := _build_result_data(is_victory, defeat_reason)

	# Disconnect item tracking before cleanup
	if InventoryManager and InventoryManager.item_awarded.is_connected(_on_item_awarded):
		InventoryManager.item_awarded.disconnect(_on_item_awarded)

	adventure_tilemap.stop_adventure()
	timer_panel.stop()
	timer_panel.visible = false
	current_action_data = null
	_update_stamina_regen(0.0)
	if is_in_combat:
		_on_stop_combat()

	_pending_victory = false

	adventure_completed.emit(result_data)

## DEV-only: immediately resolve the current combat as a win.
## No-op if not currently in combat.
## Used by the dev panel; do not call from gameplay code.
func force_win_combat() -> void:
	if not is_in_combat:
		return
	if combat == null:
		return
	combat.trigger_combat_end.emit(true, 0)

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
			player_info_panel.position = Vector2(390.0, 500.0)
			
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

	# Track combat stats
	_combats_fought += 1
	if successful:
		_gold_earned += gold_earned

	# Disconnect player ability signal
	if combat and player_info_panel.ability_selected.is_connected(combat.on_player_ability_selected):
		player_info_panel.ability_selected.disconnect(combat.on_player_ability_selected)
	
	tilemap_view.visible = true
	combat_view.visible = false
	
	# Notify the tilemap that combat has ended (tilemap handles reward processing)
	combat.stop()
	adventure_tilemap.handle_combat_result(successful, gold_earned)
	
	is_in_combat = false
	
	player_info_panel.position = Vector2(170.0, 872.0)
	
	if current_action_data:
		if not successful:
			ActionManager.stop_action(successful)

#-----------------------------------------------------------------------------
# PRIVATE METHODS - Resource Management
#-----------------------------------------------------------------------------

## Initialize resource values. Madra already spent by drain animation in ZoneResourcePanel.
func _initialize_combat_resources(madra_budget: float) -> void:
	PlayerManager.vitals_manager.initialize_current_values(madra_budget)
	player_info_panel.setup_name("Player")
	player_info_panel.setup_vitals(PlayerManager.vitals_manager)
	Log.info("AdventureView: Adventure budget: %.1f Madra" % madra_budget)

## Builds the adventure result data from accumulated stats.
func _build_result_data(is_victory: bool, defeat_reason: String) -> AdventureResultData:
	var result := AdventureResultData.new()
	result.is_victory = is_victory
	result.defeat_reason = defeat_reason
	result.combats_fought = _combats_fought
	result.combats_total = adventure_tilemap.get_total_combat_count()
	result.gold_earned = _gold_earned
	result.time_elapsed = (Time.get_ticks_msec() / 1000.0) - _adventure_start_time
	result.health_remaining = PlayerManager.vitals_manager.current_health
	result.health_max = PlayerManager.vitals_manager.max_health
	result.tiles_explored = adventure_tilemap.get_visited_tile_count()
	result.tiles_total = adventure_tilemap.get_total_tile_count()
	result.madra_spent = _madra_budget
	result.loot_items = _loot_items.duplicate()
	return result

func _on_boss_defeated() -> void:
	_pending_victory = true

func _on_item_awarded(item: ItemDefinitionData, _quantity: int) -> void:
	_loot_items.append(item)

## Updates the stamina regeneration based on the given modifier
## TODO: This will be expanded later to include more complex calculation logic
func _update_stamina_regen(modifier: float) -> void:
	if PlayerManager.vitals_manager:
		PlayerManager.vitals_manager.stamina_regen = 1.0 * modifier

func _on_adventure_timer_timeout() -> void:
	Log.info("AdventureView: Time limit reached!")
	ActionManager.stop_action(false)
