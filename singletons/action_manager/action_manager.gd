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
signal start_adventure(action_data: AdventureActionData)
signal stop_adventure()

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

var current_action: ZoneActionData = null

@onready var action_timer: Timer = Timer.new()

func _ready() -> void:
	action_timer.name = "ActionTimer"
	add_child(action_timer)
	
	if ZoneManager:
		ZoneManager.zone_changed.connect(_on_zone_changed)
	else:
		Log.critical("ActionManager: ZoneManager is not found")

func _on_zone_changed(_zone_data: ZoneData) -> void:
	stop_action()

#-----------------------------------------------------------------------------
# PUBLIC ACTION METHODS
#-----------------------------------------------------------------------------

## Select an action to execute.
func select_action(action_data: ZoneActionData) -> void:
	if not action_data:
		Log.error("ActionManager: select_action called with null action_data")
		return

	_stop_executing_current_action()
	_set_current_action(action_data)
	_execute_action(action_data)

## Stop action
func stop_action(successful: bool = true) -> void:
	_stop_executing_current_action(successful)
	clear_current_action()

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
		_:
			Log.error("ActionManager: Unknown action type: %s" % action_data.action_type)

## Stop executing the current action.
func _stop_executing_current_action(successful: bool = true) -> void:
	if current_action:
		ZoneManager.increment_zone_progression_for_action(current_action.action_id)

		match current_action.action_type:
			ZoneActionData.ActionType.FORAGE:
				_stop_forage_action(successful)
			ZoneActionData.ActionType.ADVENTURE:
				_stop_adventure_action(successful)
			ZoneActionData.ActionType.CYCLING:
				_stop_cycling_action(successful)
			ZoneActionData.ActionType.NPC_DIALOGUE:
				_stop_dialogue_action(successful)
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


## Handle adventure action - switch to adventure view.
func _execute_adventure_action(action_data: AdventureActionData) -> void:
	Log.info("ActionManager: Executing adventure action: %s" % action_data.action_name)
	start_adventure.emit(action_data)

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

	DialogueManager.start_timeline(action_data.dialogue_timeline_name)

#-----------------------------------------------------------------------------
# ACTION STOP EXECUTION HANDLERS
#-----------------------------------------------------------------------------

## Handle forage action - stop foraging.
func _stop_forage_action(successful: bool) -> void:
	Log.info("ActionManager: Stopping foraging action")
	stop_foraging.emit()
	remove_child(action_timer)
	action_timer = Timer.new()
	
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

func _process_completion_effects(successful: bool) -> void:
	var effects = current_action.success_effects if successful else current_action.failure_effects
	for effect in effects:
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
	current_action_changed.emit(current_action)
