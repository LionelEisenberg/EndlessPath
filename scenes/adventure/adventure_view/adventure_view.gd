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
## refused walk) and the chest's picks to the map, binds the dock (techniques
## and hotbar consumables) and the cabinet's buff sockets to the player's
## combatant for a fight, and keeps the run's Timer and the figures the Run
## ledger and the end card show. When a reward deepens the core (a kill's Core
## Density), its beads burst out of the hex the player stands on and home into the
## cabinet's Core row, over every board, in the effects layer.
## A fight has a way in and a way out (#138), which FightTransition plays: from the
## pick, the map pushes in and dissolves into the fight while both fighters arrive,
## and the fight starts once they land; from the hit that decides it, the kill is
## paid at once, the loser falls, and the fight dissolves back into the map. The
## run clock holds through both edges. The boards' news of a fight's end (the
## tile's line, the Run ledger, the beads) waits for the map to be whole, and so
## does the end of a run that a lost fight or the boss's win ends. A run that ends
## any other way cuts a fight under way at once.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal adventure_completed(result_data: AdventureResultData)
## The run's figures changed (fights, gold, Core Density, tiles explored, loot):
## after the map changes, a fight ends, the boss falls or an item is awarded, while
## a run is on. The chest's Run ledger shows them.
signal run_stats_changed

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## A reward's beads pop out of the player's hex up to BEAD_BURST_REACH px, then
## home into the cabinet's Core orb (PelletFlight.burst): the first lands
## BEAD_FLIGHT s after the reward, each next one BEAD_FLIGHT_STEP s after the one
## before. The flight crosses most of the screen, so it takes longer than
## cycling's.
const BEAD_FLIGHT: float = 0.8
const BEAD_FLIGHT_STEP: float = 0.04
const BEAD_BURST_REACH: float = 48.0
## One bead carries about this much Core Density XP; a burst has 1 to MAX_BEADS.
const BEAD_XP: float = 4.0
const MAX_BEADS: int = 16
## Fired as each run ends, however it ends: First Steps Out's first step, the
## first adventure, is done.
const ADVENTURE_ENDED_EVENT: String = "q_first_steps_adventure_ended"
const _BEAD_SCENE: PackedScene = preload("res://scenes/common/lacquer/lacquer_pellet/lacquer_pellet.tscn")

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
@onready var _effects_layer: Control = %EffectsLayer
@onready var _fight_transition: FightTransition = %FightTransition

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------
var current_action_data: AdventureActionData = null

## Whether a fight is under way, from its pick until the map is whole again.
var is_in_combat: bool = false

# Adventure result tracking
var _combats_fought: int = 0
var _gold_earned: int = 0
var _loot_items: Array[Resource] = []
var _adventure_start_time: float = 0.0
## The Core Density level when the run started, for the end card's stars.
var _core_level_at_start: int = 0
var _pending_victory: bool = false
## Set when the run's fight is lost. Only a lost fight marks a lost run: a run may
## start at 0 Health, and one that times out or is left early then is no loss.
var _fight_lost: bool = false

# The boards' news a fight's way out holds until the map is whole: the tile's
# resolved line, the run's figures, and each burst of beads, whose Core Density
# the cabinet already holds back.
var _news_held: bool = false
var _has_held_resolved: bool = false
var _held_resolved_coord: Vector3i = Vector3i.ZERO
var _held_resolved_summary: String = ""
var _held_stats: bool = false
var _held_bursts: Array[float] = []
## Whether the deciding hit came while the play stats were paused (a dev
## force-win), so the run's end after the close counts as no play either.
var _close_unrecorded: bool = false

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
		adventure_tilemap.core_density_earned.connect(_on_core_density_earned)
		# The chest's picks for the map
		_expedition_page.choice_selected.connect(adventure_tilemap.select_choice)
	else:
		Log.error("AdventureView: AdventureTilemap reference is missing!")
	
	run_stats_changed.connect(_on_run_stats_changed)
	_run_timer.timeout.connect(_on_adventure_timer_timeout)
	_fight_transition.landed.connect(_on_fight_landed)
	_fight_transition.fight_hidden.connect(_on_fight_hidden)
	_fight_transition.map_whole.connect(_on_map_whole)

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Start an adventure with the given action data
func start_adventure(action_data: AdventureActionData) -> void:
	Log.info("AdventureView: Starting adventure - %s" % action_data.action_name)

	if LogManager:
		LogManager.log_message("[color=cyan]Adventure Started: %s[/color]" % action_data.action_name)

	current_action_data = action_data
	# Beads the last run left in flight land now, so the cabinet starts whole.
	_land_beads()

	# Reset result tracking (the map's first redraw below shows them in the ledger)
	_combats_fought = 0
	_gold_earned = 0
	_loot_items.clear()
	_adventure_start_time = Time.get_ticks_msec() / 1000.0
	_core_level_at_start = floori(CultivationManager.get_core_density_level())
	_pending_victory = false
	_fight_lost = false

	# Listen for item awards during this adventure
	if InventoryManager and not InventoryManager.item_awarded.is_connected(_on_item_awarded):
		InventoryManager.item_awarded.connect(_on_item_awarded)

	# Fill Health and Stamina; the run plays on the saved Madra pool as it stands
	_initialize_combat_resources()
	
	if PlayerManager.vitals_manager:
		_update_stamina_regen(action_data.stamina_regen_modifier)

	adventure_chest.set_title(action_data.action_name)
	
	# Start the run's clock
	var time_limit: float = action_data.time_limit_seconds if action_data.time_limit_seconds > 0 else 10
	_run_timer.paused = false
	_run_timer.start(time_limit)
	adventure_chest.get_run_clock().bind_timer(_run_timer)
	
	adventure_tilemap.start_adventure(action_data)
	
	# Connect to the combat node
	if not combat.trigger_combat_end.is_connected(_on_combat_decided):
		combat.trigger_combat_end.connect(_on_combat_decided)

	# Ensure we're showing the tilemap view
	tilemap_view.visible = true
	combat_view.visible = false
	
## Stop the current adventure and cleanup
func stop_adventure() -> void:
	Log.info("AdventureView: Stopping adventure")

	if LogManager:
		LogManager.log_message("[color=cyan]Adventure Ended[/color]")

	# Determine end condition from current state. The save's play stats count a win,
	# a lost fight and a timeout; a retreat counts nothing. Neither does a stop with
	# no run on: the adventure action is current while the start's zoom runs, before the
	# run starts, and a save switch can stop it then, with the timer stopped. Health is
	# no clue: a run may start at 0, and only a lost fight ends one as a loss.
	var is_victory: bool = false
	var defeat_reason: String = ""
	var stats: PlayStatsData = PersistenceManager.save_game_data.stats
	var run_is_on: bool = is_adventure_running()

	if _pending_victory:
		is_victory = true
		if run_is_on:
			stats.count_adventure_won()
	elif _fight_lost:
		defeat_reason = "Your health reached zero"
		if run_is_on:
			stats.count_adventure_lost()
	elif _run_timer.is_stopped() or _run_timer.time_left <= 0.0:
		defeat_reason = "Time ran out"
		if run_is_on:
			stats.count_adventure_timed_out()
	else:
		defeat_reason = "You retreated from the adventure"

	if run_is_on:
		EventManager.trigger_event(ADVENTURE_ENDED_EVENT)

	# Build result before cleanup clears the data
	var result_data := _build_result_data(is_victory, defeat_reason)

	# Disconnect item tracking before cleanup
	if InventoryManager and InventoryManager.item_awarded.is_connected(_on_item_awarded):
		InventoryManager.item_awarded.disconnect(_on_item_awarded)

	# A fight under way goes at once, edges and all, while the run is still on and
	# its map still there: the boards show what a kill made before won, beside the
	# end card.
	if is_in_combat:
		_cut_fight()

	# The run is over before the map clears: its teardown changes no figure of the
	# run's (the ledger keeps the run's last ones) and ends no run again.
	current_action_data = null
	adventure_tilemap.stop_adventure()
	_run_timer.stop()
	_run_timer.paused = false
	_update_stamina_regen(0.0)
	_release_fight_boards()

	_pending_victory = false
	_fight_lost = false

	adventure_completed.emit(result_data)

## Returns how many beads carry `xp` Core Density XP to the cabinet: one per
## BEAD_XP, at least one and at most MAX_BEADS.
static func bead_count_for(xp: float) -> int:
	return clampi(floori(xp / BEAD_XP), 1, MAX_BEADS)

## Returns the run's Timer: one shot, started at the run's time limit when a
## run starts; the chest's clock reads it and its timeout ends the run.
func get_run_timer() -> Timer:
	return _run_timer

## DEV-only: immediately decide the current combat as a win, by taking all of the
## enemy's Health, so the fight ends as in play: AdventureCombat works out the
## fight's gold, fires q_first_steps_enemy_defeated and reports the win, the map
## pays, and the fight's way out plays.
## No-op unless the fight is live (is_fight_live(): not on its way in or out), or if
## the enemy is gone or already down.
## Called by DevCommands.force_win_fight(); do not call from gameplay code.
func force_win_combat() -> void:
	if not is_fight_live():
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

## Whether a fight is on and live: both fighters have landed and the hit that
## decides it has not.
func is_fight_live() -> bool:
	return is_in_combat and combat.is_live()

## Plays the rest of the fight's edge under way at once, every beat in order: the
## way in ends with the fight live, the way out with the map whole (and the run
## ended, if the fight ended it). Gameplay never calls it; the tests step over the
## edges' timing with it.
func finish_fight_transition() -> void:
	_fight_transition.finish_now()

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

## The player picked a fight: its way in plays. The fight is set up held, the run
## clock stops, and the fight starts once both fighters have landed
## (_on_fight_landed()). A pick while a fight is under way does nothing.
func _on_start_combat(choice: CombatChoice) -> void:
	if choice == null:
		Log.error("AdventureView: Cannot start combat with null choice")
		return
	if is_in_combat:
		return

	# The adventure's action carries the gold multiplier.
	combat.initialize_combat(choice, current_action_data)
	combat.start()
	is_in_combat = true
	_run_timer.paused = true

	Log.info("AdventureView: Transitioning to combat view - %s" % choice.label)
	if LogManager:
		LogManager.log_message("[color=orange]Encounter: %s[/color]" % choice.label)

	_fight_transition.play_way_in()

## Both fighters stand on their spots: the fight starts, the dock takes the
## player's techniques and consumables and the cabinet their buffs, and the run
## clock runs again.
func _on_fight_landed() -> void:
	combat.begin()
	_bind_fight_boards()
	_run_timer.paused = false

## The hit that decides the fight: its way out plays. The kill is paid now, as the
## result goes to the map (AdventureTilemap.handle_combat_result()), while the
## boards' news of it waits for the map to be whole. The dock and the cabinet let
## go, the run clock stops and time slows for the hit-stop. A fight's end counts
## once: a report while the way out plays, or with no fight on, does nothing. A
## report on the way in (only the tests send one) plays the way in out first.
func _on_combat_decided(successful: bool = false, gold_earned: int = 0) -> void:
	if not is_in_combat or _fight_transition.is_closing():
		return
	if _fight_transition.is_playing():
		_fight_transition.finish_now()
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

	_release_fight_boards()
	_run_timer.paused = true
	_news_held = true
	_close_unrecorded = PersistenceManager.save_game_data.stats.recording_paused
	# The map pays the kill and resolves its tile; the boss's win says so.
	adventure_tilemap.handle_combat_result(successful, gold_earned)
	if not successful:
		_fight_lost = true
	_announce_run_stats()

	GameSpeed.hit_stop(get_tree())
	_fight_transition.play_way_out(successful)

## The fight's view has gone: its fighters go with it.
func _on_fight_hidden() -> void:
	combat.stop()

## The map is back and whole: the fight is over. The boards show what it won, the
## run clock runs again, and a lost fight or the boss's win ends the run, under the
## play-stat pause its deciding hit came under.
func _on_map_whole() -> void:
	is_in_combat = false
	_release_board_news()
	_run_timer.paused = false
	if current_action_data == null or not (_fight_lost or _pending_victory):
		return
	var stats: PlayStatsData = PersistenceManager.save_game_data.stats
	var was_paused: bool = stats.recording_paused
	stats.recording_paused = was_paused or _close_unrecorded
	ActionManager.stop_action(_pending_victory)
	stats.recording_paused = was_paused

## Drops the fight under way at once, as a run's end cuts it: the edge under way
## goes, the map shows outright, the fighters go, the dock and the cabinet let go,
## and the boards show what a kill made before won. A fight not yet decided goes
## to the map as a loss, as it always has: its defeat line goes in the log and its
## choice's failure effects run. It ends no run.
func _cut_fight() -> void:
	var decided: bool = _fight_transition.is_closing()
	_fight_transition.cut()
	_release_fight_boards()
	combat.stop()
	is_in_combat = false
	if not decided:
		if LogManager:
			LogManager.log_message("[color=red]Combat Defeat...[/color]")
		adventure_tilemap.handle_combat_result(false, 0)
	_release_board_news()

## The dock takes the player's techniques and consumables, and the cabinet their
## buffs.
func _bind_fight_boards() -> void:
	var player: CombatantNode = combat.player_combatant
	if player == null:
		return
	technique_dock.bind(player.ability_manager, PlayerManager.vitals_manager, player.consumable_manager)
	vitals_plate.bind_buffs(player.buff_manager)
	if not technique_dock.ability_selected.is_connected(combat.on_player_ability_selected):
		technique_dock.ability_selected.connect(combat.on_player_ability_selected)
	if not technique_dock.consumable_selected.is_connected(combat.on_player_consumable_selected):
		technique_dock.consumable_selected.connect(combat.on_player_consumable_selected)

## The dock and the cabinet let go of the fight: no press reaches it, the dock
## previews the loadout and the hotbar again (its cast tray hidden) and the buff
## sockets clear. Safe to call when no fight is bound.
func _release_fight_boards() -> void:
	if combat and technique_dock.ability_selected.is_connected(combat.on_player_ability_selected):
		technique_dock.ability_selected.disconnect(combat.on_player_ability_selected)
	if combat and technique_dock.consumable_selected.is_connected(combat.on_player_consumable_selected):
		technique_dock.consumable_selected.disconnect(combat.on_player_consumable_selected)
	technique_dock.reset()
	vitals_plate.unbind_buffs()

## Shows the news a fight's way out held since its deciding hit, if any: the tile's
## line, each burst of beads out of the player's hex, and the run's figures.
func _release_board_news() -> void:
	if not _news_held:
		return
	_news_held = false
	if _has_held_resolved:
		_has_held_resolved = false
		_on_encounter_resolved(_held_resolved_coord, _held_resolved_summary)
	for xp: float in _held_bursts:
		_burst_beads(xp, true)
	_held_bursts.clear()
	if _held_stats:
		_held_stats = false
		_announce_run_stats()

#-----------------------------------------------------------------------------
# PRIVATE METHODS - The map's news for the boards
#-----------------------------------------------------------------------------

## The chest shows the tile the player arrived on.
func _on_tile_entered(_coord: Vector3i, encounter: AdventureEncounter, _first_visit: bool, summary: String) -> void:
	_expedition_page.show_tile(encounter, summary, current_action_data)

## The chest shows the tile resolved, when it is the one the player stands on; a
## fight's tile, once the map is whole again.
func _on_encounter_resolved(coord: Vector3i, summary: String) -> void:
	if _news_held:
		_has_held_resolved = true
		_held_resolved_coord = coord
		_held_resolved_summary = summary
		return
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

## A reward deepened the core by `xp`: its beads burst out of the hex the player
## stands on and home into the cabinet's Core orb. A fight's kill bursts them once
## the map is whole again; the cabinet holds its Core Density back from the hit, so
## its Core row stands still until they land. They fly on after a boss's win ends
## the run: the cabinet stays in sight beside the end card.
func _on_core_density_earned(xp: float) -> void:
	if _news_held:
		vitals_plate.hold_core_xp(xp)
		_held_bursts.append(xp)
		return
	_burst_beads(xp, false)

## Bursts `xp`'s beads out of the player's hex, each carrying an even share, which
## the cabinet counts in as the bead lands. `held`: the cabinet already holds the
## XP back; otherwise each bead's share is held as it sets off.
func _burst_beads(xp: float, held: bool) -> void:
	var flights: Array[PelletFlight] = PelletFlight.burst(
		adventure_tilemap.get_tile_screen_position(adventure_tilemap.get_current_tile()),
		vitals_plate.get_core_orb_global_position(),
		bead_count_for(xp),
		BEAD_FLIGHT,
		BEAD_FLIGHT_STEP,
		BEAD_BURST_REACH)
	var share: float = xp / flights.size()
	for flight: PelletFlight in flights:
		var bead: LacquerPellet = _BEAD_SCENE.instantiate() as LacquerPellet
		_effects_layer.add_child(bead)
		bead.set_ramp(LacquerPellet.Ramp.BRASS)
		bead.fly(flight)
		if not held:
			vitals_plate.hold_core_xp(share)
		bead.delivered.connect(vitals_plate.release_core_xp.bind(share))

## Takes every bead in flight out of the effects layer; each delivers its share to
## the cabinet as it goes.
func _land_beads() -> void:
	for child: Node in _effects_layer.get_children():
		if child is LacquerPellet:
			_effects_layer.remove_child(child)
			child.queue_free()

#-----------------------------------------------------------------------------
# PRIVATE METHODS - Resource Management
#-----------------------------------------------------------------------------

## Fills Stamina; Health and Madra are the saved pools as they stand, so a run
## starts on the Health the last one left. The cabinet shows them and the dock
## previews the loadout.
func _initialize_combat_resources() -> void:
	PlayerManager.vitals_manager.initialize_current_values()
	vitals_plate.setup_vitals(PlayerManager.vitals_manager)
	technique_dock.show_loadout()
	Log.info("AdventureView: The run starts on %.1f Madra" % ResourceManager.get_madra())

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
	result.madra_left = ResourceManager.get_madra()
	result.madra_max = ResourceManager.get_max_madra()
	result.core_density_xp_earned = adventure_tilemap.get_core_density_xp_earned()
	result.core_density_level_before = _core_level_at_start
	result.core_density_level_after = floori(CultivationManager.get_core_density_level())
	result.loot_items = _loot_items.duplicate()
	return result

## Tells the boards the run's figures changed, while a run is on: during a fight's
## way out, once the map is whole again.
func _announce_run_stats() -> void:
	if current_action_data == null:
		return
	if _news_held:
		_held_stats = true
		return
	run_stats_changed.emit()

## The chest's Run ledger shows the run so far: the fights fought (a lost one
## ends the run) of the map's fights, gold earned, tiles explored of the map's
## tiles, the run's loot, newest last, and the Core Density XP the map counted.
func _on_run_stats_changed() -> void:
	var loot: Array[ItemDefinitionData] = []
	loot.assign(_loot_items)
	_expedition_page.set_run_stats(
		_combats_fought,
		adventure_tilemap.get_total_combat_count(),
		_gold_earned,
		adventure_tilemap.get_visited_tile_count(),
		adventure_tilemap.get_total_tile_count(),
		loot,
		adventure_tilemap.get_core_density_xp_earned()
	)

## The boss fell: the run ends a victory once its close has played. Its win
## resolves no tile, so the ledger is told the run's figures from here (once the
## map is whole), with the boss's Core Density in them; the chest stays in sight
## beside the end card.
func _on_boss_defeated() -> void:
	_pending_victory = true
	_announce_run_stats()

func _on_item_awarded(item: ItemDefinitionData, _quantity: int) -> void:
	_loot_items.append(item)
	_announce_run_stats()

## Sets the Stamina the run regenerates a second: the player's STAMINA_REGEN
## (from Agility, with its modifiers) times `modifier`, the run's own. It is set
## at every run start, so a run keeps the rate the player had when it started;
## the run's end passes 0, which stops it.
func _update_stamina_regen(modifier: float) -> void:
	if PlayerManager.vitals_manager:
		PlayerManager.vitals_manager.stamina_regen = CharacterManager.get_stat(StatModifierData.Stat.STAMINA_REGEN) * modifier

func _on_adventure_timer_timeout() -> void:
	Log.info("AdventureView: Time limit reached!")
	ActionManager.stop_action(false)
