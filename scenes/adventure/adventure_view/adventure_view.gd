class_name AdventureView
extends Control

## AdventureView
## Main controller for the adventure mode, managing transitions between
## tilemap exploration and combat encounters, and the lacquer frame around
## them: the vitals cabinet (VitalsPlate) at the top left, the chest
## (AdventureChest: the run's name, the run clock, the expedition page) at the
## top right and the technique dock (TechniqueDock) at the bottom centre, where
## the zone view keeps its cabinet, chest and dock. The boards draw over the
## map and the fight and take the pointer, so a press on a board never reaches
## the hexes under it (the map's viewport hears the pointer only through its
## container).
## The view passes the map's news to the boards (an arrival, a resolution, a
## refused walk) and the chest's picks to the map, binds the dock and the
## cabinet's buff sockets to the player's combatant for a fight, and keeps the
## run's Timer and the figures the Run ledger and the end card show.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal adventure_completed(result_data: AdventureResultData)
## The run's figures changed (fights, gold, tiles explored, loot): after the map
## changes, a fight ends or an item is awarded, while a run is on. The chest's
## Run ledger shows them.
signal run_stats_changed

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var adventure_tilemap: AdventureTilemap = %AdventureTilemap
@onready var combat: AdventureCombat = %AdventureCombat

@onready var tilemap_view: Control = %TilemapView
@onready var combat_view: Control = %CombatView

@onready var vitals_plate: VitalsPlate = %VitalsPlate
@onready var adventure_chest: AdventureChest = %AdventureChest
@onready var technique_dock: TechniqueDock = %TechniqueDock

@onready var _expedition_page: ExpeditionPage = adventure_chest.get_expedition_page()
@onready var _run_timer: Timer = %RunTimer

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------
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
		# Listen for boss victory from tilemap
		adventure_tilemap.boss_defeated.connect(_on_boss_defeated)
		# The map's news for the boards
		adventure_tilemap.tile_entered.connect(_on_tile_entered)
		adventure_tilemap.encounter_resolved.connect(_on_encounter_resolved)
		adventure_tilemap.walk_refused.connect(_on_walk_refused)
		adventure_tilemap.map_changed.connect(_on_map_changed)
		# The chest's picks for the map
		_expedition_page.choice_selected.connect(adventure_tilemap.select_choice)
	else:
		Log.error("AdventureView: AdventureTilemap reference is missing!")
	
	run_stats_changed.connect(_on_run_stats_changed)
	_run_timer.timeout.connect(_on_adventure_timer_timeout)

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Start an adventure with the given action data
func start_adventure(action_data: AdventureActionData, madra_budget: float = -1.0) -> void:
	Log.info("AdventureView: Starting adventure - %s" % action_data.action_name)

	if LogManager:
		LogManager.log_message("[color=cyan]Adventure Started: %s[/color]" % action_data.action_name)

	current_action_data = action_data

	# Reset result tracking (the map's first redraw below shows them in the ledger)
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

	adventure_chest.set_title(action_data.action_name)
	
	# Start the run's clock
	var time_limit: float = action_data.time_limit_seconds if action_data.time_limit_seconds > 0 else 10
	_run_timer.start(time_limit)
	adventure_chest.get_run_clock().bind_timer(_run_timer)
	
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

	# Determine end condition from current state. The save's play stats count a win,
	# Health at 0 and a timeout; a retreat counts nothing. Neither does a stop with
	# no run on: the adventure action is current while its Madra drains, before the
	# run starts, and a save switch can stop it then, with the timer stopped and
	# Health as the last run left it.
	var is_victory: bool = false
	var defeat_reason: String = ""
	var stats: PlayStatsData = PersistenceManager.save_game_data.stats
	var run_is_on: bool = is_adventure_running()

	if _pending_victory:
		is_victory = true
		if run_is_on:
			stats.count_adventure_won()
	elif PlayerManager.vitals_manager.current_health <= 0.0:
		defeat_reason = "Your health reached zero"
		if run_is_on:
			stats.count_adventure_lost()
	elif _run_timer.is_stopped() or _run_timer.time_left <= 0.0:
		defeat_reason = "Time ran out"
		if run_is_on:
			stats.count_adventure_timed_out()
	else:
		defeat_reason = "You retreated from the adventure"

	# Build result before cleanup clears the data
	var result_data := _build_result_data(is_victory, defeat_reason)

	# Disconnect item tracking before cleanup
	if InventoryManager and InventoryManager.item_awarded.is_connected(_on_item_awarded):
		InventoryManager.item_awarded.disconnect(_on_item_awarded)

	# The run is over before the map clears: its teardown, and a fight it cuts
	# short, change no figure of the run's (the ledger keeps the run's last ones)
	# and end no run again.
	current_action_data = null
	adventure_tilemap.stop_adventure()
	_run_timer.stop()
	_update_stamina_regen(0.0)
	if is_in_combat:
		_on_stop_combat()
	_release_fight_boards()

	_pending_victory = false

	adventure_completed.emit(result_data)

## Returns the run's Timer: one shot, started at the run's time limit when a
## run starts; the chest's clock reads it and its timeout ends the run.
func get_run_timer() -> Timer:
	return _run_timer

## DEV-only: immediately resolve the current combat as a win, by taking all of the
## enemy's Health, so the fight ends as in play: AdventureCombat pays the fight's
## gold and fires q_first_steps_enemy_defeated, then the view and the map end it.
## No-op if not currently in combat, or if the enemy is gone or already down: the
## Health setter reports 0 again, which would pay the fight's gold a second time.
## Called by DevCommands.force_win_fight(); do not call from gameplay code.
func force_win_combat() -> void:
	if not is_in_combat:
		return
	if combat == null:
		return
	var enemy := combat.enemy_combatant
	if not is_instance_valid(enemy) or enemy.vitals_manager.current_health <= 0.0:
		return
	enemy.vitals_manager.apply_vitals_change(-enemy.vitals_manager.max_health)

## DEV-only: end the running adventure at once, as a victory (the boss-win
## path: success effects, the victory end card) or a defeat (failure effects,
## a retreat end card). No-op if no adventure is running.
## Called by DevCommands.exit_adventure(); do not call from gameplay code.
func force_end_adventure(victory: bool) -> void:
	if current_action_data == null:
		return
	_pending_victory = victory
	ActionManager.stop_action(victory)

## Whether an adventure is running.
func is_adventure_running() -> bool:
	return current_action_data != null

## DEV-only: toggle a visual fog-of-war override that reveals every tile
## on the current adventure map. Purely visual — progression state is
## unaffected. Used by the dev panel; do not call from gameplay code.
func set_show_whole_map(enabled: bool) -> void:
	if adventure_tilemap == null:
		return
	adventure_tilemap.set_dev_reveal_all(enabled)

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
		# The dock takes the player's techniques and the cabinet their buffs
		if combat.player_combatant:
			technique_dock.bind(combat.player_combatant.ability_manager, PlayerManager.vitals_manager)
			vitals_plate.bind_buffs(combat.player_combatant.buff_manager)
			if not technique_dock.ability_selected.is_connected(combat.on_player_ability_selected):
				technique_dock.ability_selected.connect(combat.on_player_ability_selected)
		
	is_in_combat = true
	
	Log.info("AdventureView: Transitioning to combat view - %s" % choice.label)
	if LogManager:
		LogManager.log_message("[color=orange]Encounter: %s[/color]" % choice.label)
		
	tilemap_view.visible = false
	combat_view.visible = true
	_fade_in_combat_view()

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
	_announce_run_stats()

	# The dock and the cabinet let go of the fight
	_release_fight_boards()
	
	tilemap_view.visible = true
	combat_view.visible = false

	# Mark the fight over before its result is handled: a boss win ends the
	# whole adventure synchronously inside handle_combat_result(), and
	# stop_adventure() must not see a fight still running and end it again as
	# a defeat.
	is_in_combat = false

	# Notify the tilemap that combat has ended (tilemap handles reward processing)
	combat.stop()
	adventure_tilemap.handle_combat_result(successful, gold_earned)

	if current_action_data:
		if not successful:
			ActionManager.stop_action(successful)

## The dock and the cabinet let go of the fight: no press reaches it, the dock
## previews the loadout again (its cast tray hidden) and the buff sockets clear.
## Safe to call when no fight is bound.
func _release_fight_boards() -> void:
	if combat and technique_dock.ability_selected.is_connected(combat.on_player_ability_selected):
		technique_dock.ability_selected.disconnect(combat.on_player_ability_selected)
	technique_dock.reset()
	vitals_plate.unbind_buffs()

func _fade_in_combat_view() -> void:
	combat_view.modulate.a = 0.0
	create_tween().tween_property(combat_view, "modulate:a", 1.0, 0.25)

#-----------------------------------------------------------------------------
# PRIVATE METHODS - The map's news for the boards
#-----------------------------------------------------------------------------

## The chest shows the tile the player arrived on.
func _on_tile_entered(_coord: Vector3i, encounter: AdventureEncounter, _first_visit: bool, summary: String) -> void:
	_expedition_page.show_tile(encounter, summary, current_action_data)

## The chest shows the tile resolved, when it is the one the player stands on.
func _on_encounter_resolved(coord: Vector3i, summary: String) -> void:
	if coord == adventure_tilemap.get_current_tile():
		_expedition_page.show_resolved(summary)

## A refused walk shakes the board that says why: the cabinet's Stamina row
## when the player is too tired, the chest's Here tray while a choice waits.
func _on_walk_refused(reason: StringName) -> void:
	match reason:
		AdventureTilemap.REFUSED_STAMINA:
			vitals_plate.shake_stamina()
		AdventureTilemap.REFUSED_ENCOUNTER:
			_expedition_page.shake_here()
		_:
			Log.warn("AdventureView: Unknown walk refusal '%s'" % reason)

func _on_map_changed() -> void:
	_announce_run_stats()

#-----------------------------------------------------------------------------
# PRIVATE METHODS - Resource Management
#-----------------------------------------------------------------------------

## Initialize resource values. Madra already spent by the drain animation in
## ZoneTransition. The cabinet shows them and the dock previews the loadout.
func _initialize_combat_resources(madra_budget: float) -> void:
	PlayerManager.vitals_manager.initialize_current_values(madra_budget)
	vitals_plate.setup_vitals(PlayerManager.vitals_manager)
	technique_dock.show_loadout()
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

## Tells the boards the run's figures changed, while a run is on.
func _announce_run_stats() -> void:
	if current_action_data != null:
		run_stats_changed.emit()

## The chest's Run ledger shows the run so far: the fights fought (a lost one
## ends the run) of the map's fights, gold earned, tiles explored of the map's
## tiles, and the run's loot, newest last.
func _on_run_stats_changed() -> void:
	var loot: Array[ItemDefinitionData] = []
	loot.assign(_loot_items)
	_expedition_page.set_run_stats(
		_combats_fought,
		adventure_tilemap.get_total_combat_count(),
		_gold_earned,
		adventure_tilemap.get_visited_tile_count(),
		adventure_tilemap.get_total_tile_count(),
		loot
	)

func _on_boss_defeated() -> void:
	_pending_victory = true

func _on_item_awarded(item: ItemDefinitionData, _quantity: int) -> void:
	_loot_items.append(item)
	_announce_run_stats()

## Updates the stamina regeneration based on the given modifier
## TODO: This will be expanded later to include more complex calculation logic
func _update_stamina_regen(modifier: float) -> void:
	if PlayerManager.vitals_manager:
		PlayerManager.vitals_manager.stamina_regen = 1.0 * modifier

func _on_adventure_timer_timeout() -> void:
	Log.info("AdventureView: Time limit reached!")
	ActionManager.stop_action(false)
