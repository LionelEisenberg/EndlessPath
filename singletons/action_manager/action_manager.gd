# ActionManager.gd
# AUTOLOADED SINGLETON
extends Node

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## current action signals
signal current_action_changed(action_data)

## foraging signals
signal foraging_completed(item_amount: int, item_definition: ItemDefinitionData)
signal stop_foraging()
signal start_foraging()

## cycling signals
signal stop_cycling()

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
		printerr("ActionManager: ZoneManager is not found")

func _on_zone_changed(_zone_data : ZoneData) -> void:
	stop_action()

#-----------------------------------------------------------------------------
# PUBLIC ACTION METHODS
#-----------------------------------------------------------------------------

## Select an action to execute.
func select_action(action_data: ZoneActionData) -> void:
	if not action_data:
		printerr("ActionManager: select_action called with null action_data")
		return

	_stop_executing_current_action()
	_set_current_action(action_data)
	_execute_action(action_data)

## Stop action
func stop_action() -> void:
	_stop_executing_current_action()
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
				printerr("ActionManager: Forage action data is not a ForageActionData: %s" % action_data.action_name)
		ZoneActionData.ActionType.CYCLING:
			_execute_cycling_action(action_data)
		ZoneActionData.ActionType.NPC_DIALOGUE:
			if action_data is NpcDialogueActionData:
				_execute_dialogue_action(action_data as NpcDialogueActionData)
			else:
				printerr("ActionManager: Dialogue action data is not NpcDialogueActionData")
		_:
			printerr("ActionManager: Unknown action type: %s" % action_data.action_type)

## Stop executing the current action.
func _stop_executing_current_action() -> void:
	if current_action:
		ZoneManager.increment_zone_progression_for_action(current_action.action_id)

		match current_action.action_type:
			ZoneActionData.ActionType.FORAGE:
				_stop_forage_action()
			ZoneActionData.ActionType.CYCLING:
				_stop_cycling_action()
			ZoneActionData.ActionType.NPC_DIALOGUE:
				_stop_dialogue_action()
			_:
				printerr("ActionManager: Unknown action type: %s" % current_action.action_type)
	

#-----------------------------------------------------------------------------
# ACTION EXECUTION HANDLERS
#-----------------------------------------------------------------------------

## Handle forage action - toggle foraging for zone.
func _execute_forage_action(action_data: ForageActionData) -> void:
	print("ActionManager: Executing foraging action: %s" % action_data.action_name)
	start_foraging.emit()
	
	action_timer.name = "ForageTimer"
	action_timer.timeout.connect(_on_forage_timer_finished.bind(action_data))
	action_timer.wait_time = action_data.foraging_interval_in_sec
	action_timer.autostart = true
	action_timer.start()

func _on_forage_timer_finished(action_data: ForageActionData) -> void:
	var resource = _select_forage_resource(action_data.forage_resources)
	var item_amount = 0
	if resource:
		item_amount = randi_range(resource.min_generation_amount, resource.max_generation_amount)
		_award_item(item_amount, resource.item_definition)
	
	foraging_completed.emit(item_amount, resource.item_definition)

func _select_forage_resource(resources: Array[ForageResourceData]) -> ForageResourceData:
	if resources.is_empty():
		return null
	var roll := randf()
	var cumulative := 0.0
	for resource in resources:
		cumulative += resource.drop_chance
		if roll <= cumulative:
			return resource
	return null

func _award_item(item_amount: int, item_definition: ItemDefinitionData) -> void:
	if item_amount <= 0 or not item_definition:
		return
	
	if not InventoryManager:
		printerr("ActionManager: InventoryManager not available, cannot award item")
		return
	
	InventoryManager.award_items(item_definition, item_amount)

## Handle cycling action - switch to cycling view.
func _execute_cycling_action(action_data: ZoneActionData) -> void:
	print("ActionManager: Executing cycling action: %s" % action_data.action_name)
	var main_view = _get_main_view()
	
	if main_view:
		if main_view.has_method("show_and_initialize_action_popup"):
			main_view.show_and_initialize_action_popup(action_data)
	else:
		printerr("ActionManager: Could not find MainView for cycling action")

## Handle dialogue action - show dialogue.
func _execute_dialogue_action(action_data: NpcDialogueActionData) -> void:
	print("ActionManager: Executing dialogue action: %s" % action_data.action_name)
	
	if not DialogueManager:
		printerr("ActionManager: DialogueManager is not initialized")
		return
	
	DialogueManager.dialogue_ended.connect(
		stop_action, 
		CONNECT_ONE_SHOT
	)

	DialogueManager.start_timeline(action_data.dialogue_timeline_name)

## Attempt to fetch the main view node from the scene tree.
func _get_main_view() -> Node:
	if get_tree():
		return get_node("/root/MainGame/MainView")
	else:
		return null

#-----------------------------------------------------------------------------
# ACTION STOP EXECUTION HANDLERS
#-----------------------------------------------------------------------------

## Handle forage action - stop foraging.
func _stop_forage_action() -> void:
	print("ActionManager: Stopping foraging action")
	stop_foraging.emit()
	remove_child(action_timer)
	action_timer = Timer.new()

## Handle cycling action - stop cycling.
func _stop_cycling_action() -> void:
	print("ActionManager: Stopping cycling action")
	stop_cycling.emit()

## Handle dialogue action - stop dialogue.
func _stop_dialogue_action() -> void:
	print("ActionManager: Dialogue completed, processing effects for: %s" % current_action.action_name)
	
	if not EventManager:
		printerr("ActionManager: EventManager not found. Cannot process effects.")
		return

	for effect in current_action.effects:
		match effect.effect_type:
			EffectData.EffectType.TRIGGER_EVENT:
				effect = effect as TriggerEventEffectData
				var event_id = effect.event_id
				if event_id:
					print("ActionManager: Triggering event: %s" % event_id)
					EventManager.trigger_event(event_id)
				else:
					printerr("ActionManager: TRIGGER_EVENT effect has no 'event_id' in effect_data")
					
			EffectData.EffectType.AWARD_RESOURCE:
				pass

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
