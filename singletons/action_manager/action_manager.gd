# ActionManager.gd
# AUTOLOADED SINGLETON
extends Node

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## current action signals
signal current_action_changed(action_data)

## foraging signals
signal foraging_completed(items: Dictionary) # Dictionary[ItemDefinitionData, int]
signal start_foraging(action_data: ForageActionData)
signal stop_foraging()

## cycling signals
signal start_cycling(action_data: CyclingActionData)
signal stop_cycling()

## adventure signals
signal adventure_start_requested(action_data: AdventureActionData)
signal start_adventure(action_data: AdventureActionData, madra_budget: float)
signal stop_adventure()

## training signals
signal start_training(action_data: TrainingActionData)
signal stop_training()
signal training_tick_processed(action_data: TrainingActionData, new_tick_count: int)
signal training_level_gained(action_data: TrainingActionData, new_level: int)

## merchant signals
signal start_merchant(action_data: MerchantActionData)
signal stop_merchant()

## tribulation signals
signal start_tribulation(action_data: TribulationActionData)
signal stop_tribulation()

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

var current_action: ZoneActionData = null

## The save the current action started under. A save reset swaps the save
## before ActionManager hears of it, so stopping that action then must not
## count a completion or run its effects in the new save.
var _current_action_save: SaveGameData = null

## The zone the current action started in. Travel stops the action after the
## current zone already changed, so its completion counts here instead.
var _current_action_zone_id: String = ""

## The zone the last zone_changed was handled for. It tells travel ("Travelled
## to …") from a repeat signal for the same zone (the load sends two).
var _last_resolved_zone_id: String = ""

@onready var action_timer: Timer = Timer.new()

func _ready() -> void:
	action_timer.name = "ActionTimer"
	add_child(action_timer)

	if ZoneManager:
		ZoneManager.zone_changed.connect(_on_zone_changed)
	else:
		Log.critical("ActionManager: ZoneManager is not found")

	if UnlockManager:
		UnlockManager.condition_unlocked.connect(_on_condition_unlocked)
	else:
		Log.critical("ActionManager: UnlockManager is not found")

## Arriving in a zone (travel, the load, a save reset) stops what runs and
## starts the zone's idle action. A repeat signal for the zone whose idle
## action already runs in the live save changes nothing; after a save reset
## the same idle action restarts, bound to the new save.
func _on_zone_changed(zone_data: ZoneData) -> void:
	var zone_id: String = zone_data.zone_id if zone_data else ""
	var previous_zone_id: String = _last_resolved_zone_id
	_last_resolved_zone_id = zone_id
	if zone_id == previous_zone_id and _is_current_action_in_live_save() and _is_resolved_idle_running(zone_id):
		return

	_stop_executing_current_action()
	clear_current_action()
	var idle_action: ZoneActionData = resolve_idle_action(zone_id)
	if idle_action:
		select_action(idle_action)

	var travelled: bool = zone_data != null and previous_zone_id != "" and zone_id != previous_zone_id
	if travelled and idle_action:
		_log("Travelled to %s · resumed %s" % [zone_data.zone_name, idle_action.action_name])
	elif travelled:
		_log("Travelled to %s" % zone_data.zone_name)
	elif idle_action:
		_log("Resumed %s" % idle_action.action_name)

## When a condition unlocks while nothing runs, the zone's idle action (the
## first one to unlock) starts on its own. The save reset's empty ping is not
## an unlock.
func _on_condition_unlocked(condition_id: String) -> void:
	if condition_id == "" or current_action != null:
		return
	var idle_action: ZoneActionData = resolve_idle_action(_get_current_zone_id())
	if idle_action == null:
		return
	select_action(idle_action)
	_log("Started %s" % idle_action.action_name)

#-----------------------------------------------------------------------------
# PUBLIC ACTION METHODS
#-----------------------------------------------------------------------------

## Select an action to execute, replacing the current one, and mark it seen.
## An idle action becomes its zone's last idle action. An adventure the player
## can't afford and a Tribulation the core isn't ready for are refused before
## anything stops, so the current action runs on.
func select_action(action_data: ZoneActionData) -> void:
	if not action_data:
		Log.error("ActionManager: select_action called with null action_data")
		return

	ZoneManager.mark_action_seen(action_data.action_id)
	if action_data.action_type == ZoneActionData.ActionType.ADVENTURE and not ResourceManager.can_start_adventure():
		Log.info("ActionManager: Cannot start adventure - need %.0f Madra, have %.0f" % [
			ResourceManager.get_adventure_madra_threshold(), ResourceManager.get_madra()])
		return
	var tribulation := action_data as TribulationActionData
	if tribulation != null and not tribulation.can_attempt():
		Log.info("ActionManager: Cannot start the Tribulation - Core Density %d / %d (%s)" % [
			int(CultivationManager.get_core_density_level()), CultivationManager.get_core_density_cap(),
			CultivationManager.get_current_advancement_stage_name()])
		return

	_stop_executing_current_action()
	_set_current_action(action_data)
	if is_idle_action(action_data):
		var zone_id: String = _get_current_zone_id()
		if zone_id != "":
			ZoneManager.set_last_idle_action_id(zone_id, action_data.action_id)
	_execute_action(action_data)

## Stop the current action. When a session action (cycling, an adventure,
## dialogue, the merchant, the Tribulation, a zone event) stops, the zone's idle
## action resumes. Stopping an idle action resumes nothing.
func stop_action(successful: bool = true) -> void:
	var stopped_action := current_action
	_stop_executing_current_action(successful)
	clear_current_action()
	if stopped_action != null and not is_idle_action(stopped_action):
		_resume_idle_action()

## Counts one completion of the action in zone_id, then runs its success
## effects, in that order, as a played stop does. Nothing starts or stops: an
## action that runs goes on running. It checks nothing, so the caller makes sure
## the action is available. The dev tools use it to reach a story moment without
## playing the action.
func complete_without_playing(action_data: ZoneActionData, zone_id: String) -> void:
	if not action_data:
		Log.error("ActionManager: complete_without_playing called with null action_data")
		return
	_count_completion(action_data, zone_id)
	_run_completion_effects(action_data, true)

## Stops the current action as if it had never run: no completion counts, no
## effect runs and no idle action resumes. The rest of its stop still happens
## (its stop_* signal closes its view, its timer stops), and a dialogue's
## timeline ends at once. The dev tools call it before they switch sessions.
func cancel_current_action() -> void:
	if current_action == null:
		return
	if current_action.action_type == ZoneActionData.ActionType.NPC_DIALOGUE:
		# Dialogic's timeline_ended arrives a frame late, and would stop whatever
		# action runs by then.
		if DialogueManager.dialogue_ended.is_connected(stop_action):
			DialogueManager.dialogue_ended.disconnect(stop_action)
		DialogueManager.end_dialogue_now()
	# The stale-save guard then skips the completion and the effects.
	_current_action_save = null
	_stop_executing_current_action()
	clear_current_action()

## The idle action the zone runs when nothing else does: its saved last idle
## action while that is still available, else the first available idle action
## in activity list order (ZoneActionGroups), else null.
func resolve_idle_action(zone_id: String) -> ZoneActionData:
	if zone_id == "" or ZoneManager.get_zone_by_id(zone_id) == null:
		return null
	var available: Array[ZoneActionData] = ZoneManager.get_available_actions(zone_id)
	var last_idle_id: String = ZoneManager.get_last_idle_action_id(zone_id)
	if last_idle_id != "":
		for action: ZoneActionData in available:
			if action.action_id == last_idle_id and is_idle_action(action):
				return action
	for action: ZoneActionData in ZoneActionGroups.sort_actions(available):
		if is_idle_action(action):
			return action
	return null

## True for an idle action: foraging and training. It runs in the background, and the
## zone resumes it when a session action ends. Every other action is a session the
## player plays through.
func is_idle_action(action_data: ZoneActionData) -> bool:
	return action_data != null and action_data.action_type in [
		ZoneActionData.ActionType.FORAGE,
		ZoneActionData.ActionType.TRAIN_STATS,
	]

## Madra per second the running action earns: the running cycle's measured rate
## while the cycling action runs (0 while no cycle is drawing Madra), a training
## action's trickle (the Aura Well's 1.5), or 0 when anything else or nothing runs.
func get_current_madra_per_second() -> float:
	if current_action != null and current_action.action_type == ZoneActionData.ActionType.CYCLING:
		return CyclingManager.get_madra_rate()
	var training := current_action as TrainingActionData
	return training.get_madra_per_second() if training else 0.0

#-----------------------------------------------------------------------------
# ACTION EXECUTION
#-----------------------------------------------------------------------------

## Execute a zone action. Routes to appropriate handler based on action type.
func _execute_action(action_data: ZoneActionData) -> void:
	# Route to appropriate handler based on action type
	match action_data.action_type:
		ZoneActionData.ActionType.FORAGE:
			if action_data is ForageActionData:
				_execute_forage_action(action_data as ForageActionData)
			else:
				Log.error("ActionManager: Forage action data is not a ForageActionData: %s" % action_data.action_name)
		ZoneActionData.ActionType.ADVENTURE:
			if action_data is AdventureActionData:
				_execute_adventure_action(action_data as AdventureActionData)
			else:
				Log.error("ActionManager: Adventure action data is not an AdventureActionData: %s" % action_data.action_name)
		ZoneActionData.ActionType.CYCLING:
			if action_data is CyclingActionData:
				_execute_cycling_action(action_data as CyclingActionData)
			else:
				Log.error("ActionManager: Cycling action data is not a CyclingActionData: %s" % action_data.action_name)
		ZoneActionData.ActionType.NPC_DIALOGUE:
			if action_data is NpcDialogueActionData:
				_execute_dialogue_action(action_data as NpcDialogueActionData)
			else:
				Log.error("ActionManager: Dialogue action data is not NpcDialogueActionData")
		ZoneActionData.ActionType.TRAIN_STATS:
			if action_data is TrainingActionData:
				_execute_train_action(action_data as TrainingActionData)
			else:
				Log.error("ActionManager: Training action data is not a TrainingActionData: %s" % action_data.action_name)
		ZoneActionData.ActionType.MERCHANT:
			if action_data is MerchantActionData:
				_execute_merchant_action(action_data as MerchantActionData)
			else:
				Log.error("ActionManager: Merchant action data is not a MerchantActionData: %s" % action_data.action_name)
		ZoneActionData.ActionType.TRIBULATION:
			if action_data is TribulationActionData:
				_execute_tribulation_action(action_data as TribulationActionData)
			else:
				Log.error("ActionManager: Tribulation action data is not a TribulationActionData: %s" % action_data.action_name)
		_:
			Log.error("ActionManager: Unknown action type: %s" % action_data.action_type)

## Stop executing the current action. It counts a completion only in the save
## it started under (see _current_action_save), in the zone it started in.
func _stop_executing_current_action(successful: bool = true) -> void:
	if current_action:
		if _is_current_action_in_live_save():
			_count_completion(current_action, _current_action_zone_id)

		match current_action.action_type:
			ZoneActionData.ActionType.FORAGE:
				_stop_forage_action(successful)
			ZoneActionData.ActionType.ADVENTURE:
				_stop_adventure_action(successful)
			ZoneActionData.ActionType.CYCLING:
				_stop_cycling_action(successful)
			ZoneActionData.ActionType.NPC_DIALOGUE:
				_stop_dialogue_action(successful)
			ZoneActionData.ActionType.TRAIN_STATS:
				_stop_train_action(successful)
			ZoneActionData.ActionType.MERCHANT:
				_stop_merchant_action(successful)
			ZoneActionData.ActionType.TRIBULATION:
				_stop_tribulation_action(successful)
			_:
				Log.error("ActionManager: Unknown action type: %s" % current_action.action_type)
	

#-----------------------------------------------------------------------------
# ACTION EXECUTION HANDLERS
#-----------------------------------------------------------------------------

## Handle forage action - toggle foraging for zone.
func _execute_forage_action(action_data: ForageActionData) -> void:
	Log.info("ActionManager: Executing foraging action: %s" % action_data.action_name)
	start_foraging.emit()
	
	action_timer.name = "ForageTimer"
	action_timer.timeout.connect(_on_forage_timer_finished.bind(action_data))
	action_timer.wait_time = action_data.foraging_interval_in_sec
	action_timer.autostart = true
	action_timer.start()

func _on_forage_timer_finished(action_data: ForageActionData) -> void:
	if not action_data.loot_table:
		Log.error("ActionManager: ForageActionData has no loot table")
		return
	
	# Roll the loot table (independent drops)
	var rolled_items: Dictionary = action_data.loot_table.roll_loot()
	
	# Award all rolled items
	for item in rolled_items:
		var quantity: int = rolled_items[item]
		InventoryManager.award_items(item, quantity)
		Log.info("ActionManager: Foraging awarded %s x%d" % [item.item_name, quantity])
	
	# Emit completion signal with the dictionary of items
	foraging_completed.emit(rolled_items)


## Handle adventure action - request start (zone view plays drain animation first).
## select_action() has already checked the Madra threshold.
func _execute_adventure_action(action_data: AdventureActionData) -> void:
	Log.info("ActionManager: Adventure start requested: %s" % action_data.action_name)
	adventure_start_requested.emit(action_data)

## Confirm adventure start after drain animation completes. This is the real
## start, so it is the one that counts in the save's play stats: the request
## (adventure_start_requested) can repeat.
func confirm_adventure_start(action_data: AdventureActionData, madra_budget: float) -> void:
	Log.info("ActionManager: Confirming adventure start: %s (budget: %.1f)" % [action_data.action_name, madra_budget])
	PersistenceManager.save_game_data.stats.count_adventure_started()
	start_adventure.emit(action_data, madra_budget)

## Handle cycling action - switch to cycling view.
func _execute_cycling_action(action_data: CyclingActionData) -> void:
	Log.info("ActionManager: Executing cycling action: %s" % action_data.action_name)
	start_cycling.emit(action_data)

## Handle dialogue action - show dialogue.
func _execute_dialogue_action(action_data: NpcDialogueActionData) -> void:
	Log.info("ActionManager: Executing dialogue action: %s" % action_data.action_name)

	if not DialogueManager:
		Log.critical("ActionManager: DialogueManager is not initialized")
		return

	DialogueManager.dialogue_ended.connect(
		stop_action,
		CONNECT_ONE_SHOT
	)

	DialogueManager.start_timeline(action_data.dialogue_timeline_name, action_data.dialogue_timeline_label_jump)

## Handle training action - start periodic tick timer.
func _execute_train_action(action_data: TrainingActionData) -> void:
	Log.info("ActionManager: Executing training action: %s" % action_data.action_name)
	start_training.emit(action_data)

	action_timer.name = "TrainingTimer"
	action_timer.timeout.connect(_on_train_timer_finished.bind(action_data))
	action_timer.wait_time = action_data.tick_interval_seconds
	action_timer.autostart = true
	action_timer.start()

func _on_train_timer_finished(action_data: TrainingActionData) -> void:
	var prev_ticks: int = ZoneManager.get_training_ticks(action_data.action_id)
	var prev_level: int = action_data.get_current_level(prev_ticks)

	var new_ticks: int = ZoneManager.increment_training_ticks(action_data.action_id)
	var new_level: int = action_data.get_current_level(new_ticks)

	for effect in action_data.effects_per_tick:
		effect.process()

	training_tick_processed.emit(action_data, new_ticks)

	for level in range(prev_level + 1, new_level + 1):
		for effect in action_data.effects_on_level:
			effect.process()
		training_level_gained.emit(action_data, level)

## Handle merchant action - open the shop. The action stays current until the
## shop closes it with stop_action() (Leave or Escape), the way cycling does.
func _execute_merchant_action(action_data: MerchantActionData) -> void:
	Log.info("ActionManager: Executing merchant action: %s" % action_data.action_name)
	start_merchant.emit(action_data)

## Handle tribulation action - open the Tribulation board. select_action() has
## already checked the core is full. The action stays current until the board
## closes it with stop_action() (the trial ended, or Escape), the way the shop does.
func _execute_tribulation_action(action_data: TribulationActionData) -> void:
	Log.info("ActionManager: Executing tribulation action: %s" % action_data.action_name)
	start_tribulation.emit(action_data)

#-----------------------------------------------------------------------------
# ACTION STOP EXECUTION HANDLERS
#-----------------------------------------------------------------------------

## Handle forage action - stop foraging.
func _stop_forage_action(successful: bool) -> void:
	Log.info("ActionManager: Stopping foraging action")
	stop_foraging.emit()
	_reset_action_timer()

	_process_completion_effects(successful)

## Handle adventure action - stop adventure.
func _stop_adventure_action(successful: bool) -> void:
	Log.info("ActionManager: Stopping adventure action")
	stop_adventure.emit()
	
	_process_completion_effects(successful)

## Handle cycling action - stop cycling.
func _stop_cycling_action(successful: bool) -> void:
	Log.info("ActionManager: Stopping cycling action")
	stop_cycling.emit()
	
	_process_completion_effects(successful)

## Handle dialogue action - stop dialogue.
func _stop_dialogue_action(successful: bool) -> void:
	Log.info("ActionManager: Dialogue completed, processing effects for: %s" % current_action.action_name)

	_process_completion_effects(successful)

## Handle training action - stop and persist remaining progress.
func _stop_train_action(successful: bool) -> void:
	Log.info("ActionManager: Stopping training action")
	stop_training.emit()
	_reset_action_timer()
	_process_completion_effects(successful)

## Handle merchant action stop - close the shop, then run completion effects.
func _stop_merchant_action(successful: bool) -> void:
	Log.info("ActionManager: Stopping merchant action")
	stop_merchant.emit()
	_process_completion_effects(successful)

## Handle tribulation action stop - close the board, then run completion effects.
## The breakthrough or the penalty is applied by the board before it stops the
## action; nothing here changes Core Density.
func _stop_tribulation_action(successful: bool) -> void:
	Log.info("ActionManager: Stopping tribulation action")
	stop_tribulation.emit()
	_process_completion_effects(successful)

## Runs the current action's completion effects, only in the save it started
## under.
func _process_completion_effects(successful: bool) -> void:
	if not _is_current_action_in_live_save():
		return
	_run_completion_effects(current_action, successful)

## Counts one completion of the action in zone_id, or in the current zone when
## zone_id is "". A stop and complete_without_playing() both count here.
func _count_completion(action: ZoneActionData, zone_id: String) -> void:
	if zone_id != "":
		ZoneManager.increment_zone_progression_for_action(action.action_id, zone_id)
	else:
		ZoneManager.increment_zone_progression_for_action(action.action_id)

## Runs the action's success effects, or its failure effects when it failed. A
## stop and complete_without_playing() both run them here.
func _run_completion_effects(action: ZoneActionData, successful: bool) -> void:
	var effects: Array[EffectData] = action.success_effects if successful else action.failure_effects
	for effect: EffectData in effects:
		effect.process()

#-----------------------------------------------------------------------------
# CURRENT ACTION MANAGEMENT
#-----------------------------------------------------------------------------

func get_current_action() -> ZoneActionData:
	return current_action

func clear_current_action() -> void:
	_set_current_action(null)

func _set_current_action(action_data: ZoneActionData) -> void:
	current_action = action_data
	_current_action_save = PersistenceManager.save_game_data if action_data else null
	_current_action_zone_id = _get_current_zone_id() if action_data else ""
	current_action_changed.emit(current_action)

## False when a save reset replaced the save since the current action started.
func _is_current_action_in_live_save() -> bool:
	return _current_action_save == PersistenceManager.save_game_data

## Starts the current zone's idle action after a session action stopped and
## logs "Resumed", even for an idle action that unlocked during the session
## action or a zone with no saved last idle action. Only the auto-start on a
## first idle unlock (_on_condition_unlocked) reads "Started".
func _resume_idle_action() -> void:
	var idle_action: ZoneActionData = resolve_idle_action(_get_current_zone_id())
	if idle_action == null:
		return
	select_action(idle_action)
	_log("Resumed %s" % idle_action.action_name)

## True when the zone's resolved idle action is the one already running.
func _is_resolved_idle_running(zone_id: String) -> bool:
	if current_action == null:
		return false
	var idle_action: ZoneActionData = resolve_idle_action(zone_id)
	return idle_action != null and idle_action.action_id == current_action.action_id

func _get_current_zone_id() -> String:
	var zone: ZoneData = ZoneManager.get_current_zone()
	return zone.zone_id if zone else ""

## Writes a line to the player's log.
func _log(message: String) -> void:
	if LogManager:
		LogManager.log_message(message)

func _reset_action_timer() -> void:
	action_timer.stop()
	# Disconnect all bound callbacks from the timeout signal
	for connection in action_timer.timeout.get_connections():
		action_timer.timeout.disconnect(connection["callable"])
