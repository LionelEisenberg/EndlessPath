# ActionManager.gd
# AUTOLOADED SINGLETON
extends Node

#-----------------------------------------------------------------------------
# ACTION EXECUTION
#-----------------------------------------------------------------------------

func execute_action(action_data: ZoneActionData) -> void:
	"""Execute a zone action. Routes to appropriate handler based on action type."""
	if not action_data:
		printerr("ActionManager: execute_action called with null action_data")
		return
	
	# Route to appropriate handler based on action type
	match action_data.action_type:
		ZoneActionData.ActionType.FORAGE:
			_execute_forage_action(action_data)
		ZoneActionData.ActionType.CYCLING:
			_execute_cycling_action(action_data)
		ZoneActionData.ActionType.DUNGEON:
			_execute_dungeon_action(action_data)
		ZoneActionData.ActionType.NPC_DIALOGUE:
			_execute_npc_action(action_data)
		ZoneActionData.ActionType.MERCHANT:
			_execute_merchant_action(action_data)
		ZoneActionData.ActionType.TRAIN_STATS:
			_execute_train_stats_action(action_data)
		ZoneActionData.ActionType.ZONE_EVENT:
			_execute_zone_event_action(action_data)
		ZoneActionData.ActionType.QUEST_GIVER:
			_execute_quest_giver_action(action_data)
		_:
			printerr("ActionManager: Unknown action type: %s" % action_data.action_type)

#-----------------------------------------------------------------------------
# ACTION HANDLERS
#-----------------------------------------------------------------------------

func _execute_forage_action(action_data: ZoneActionData) -> void:
	"""Handle forage action - toggle foraging for zone"""
	var current_zone = ZoneManager.get_current_zone()
	if not current_zone:
		printerr("ActionManager: No current zone for forage action")
		return
	
	# TODO: Check if foraging is already active and toggle
	ZoneManager.forage_started.emit(current_zone.zone_id)
	print("ActionManager: Started foraging in zone: %s" % current_zone.zone_id)

func _execute_cycling_action(action_data: ZoneActionData) -> void:
	"""Handle cycling action - switch to cycling view"""
	print("ActionManager: Executing cycling action: %s" % action_data.action_name)
	# Attempt to get the MainView node in the scene tree
	var main_view = _get_main_view()
	
	if main_view:
		# Call initalize_system_with_action to do any needed setup for cycling
		if main_view.has_method("initalize_system_with_action"):
			main_view.initalize_system_with_action(UnlockManager.GameSystem.CYCLING, action_data)
		# Also call show_system to switch views
		if main_view.has_method("show_system"):
			main_view.show_system(UnlockManager.GameSystem.CYCLING)
	else:
		printerr("ActionManager: Could not find MainView for cycling action")

func _execute_dungeon_action(action_data: ZoneActionData) -> void:
	"""Handle dungeon action - start dungeon encounter"""
	print("ActionManager: Executing dungeon action: %s" % action_data.action_name)
	# TODO: Load and start dungeon

func _execute_npc_action(action_data: ZoneActionData) -> void:
	"""Handle NPC dialogue action - show dialogue panel"""
	print("ActionManager: Executing NPC dialogue action: %s" % action_data.action_name)
	# TODO: Show ActionDetailPanel with dialogue

func _execute_merchant_action(action_data: ZoneActionData) -> void:
	"""Handle merchant action - show merchant panel"""
	print("ActionManager: Executing merchant action: %s" % action_data.action_name)
	# TODO: Show ActionDetailPanel with merchant UI

func _execute_train_stats_action(action_data: ZoneActionData) -> void:
	"""Handle stat training action"""
	print("ActionManager: Executing train stats action: %s" % action_data.action_name)
	# TODO: Implement stat training

func _execute_zone_event_action(action_data: ZoneActionData) -> void:
	"""Handle zone event/story action"""
	print("ActionManager: Executing zone event action: %s" % action_data.action_name)
	# TODO: Trigger zone event/story

func _execute_quest_giver_action(action_data: ZoneActionData) -> void:
	"""Handle quest giver action"""
	print("ActionManager: Executing quest giver action: %s" % action_data.action_name)
	# TODO: Show quest giver UI

func _get_main_view() -> Node:
	for child in get_node("/root/").get_children():
		print(child.name)
	if get_tree():
		return get_node("/root/MainGame/MainView")
	else:
		return null
	
