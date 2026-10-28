class_name DevCommands extends RefCounted

## DevCommands
## The one command API of the dev tools: the story route and the save presets, the
## dev panel and the tests all go through it. Each command is a static function that
## calls the owning manager's public API, never a private member and never a copy of
## game logic, and returns "" when it worked or the reason it refused. Each one:
##   - checks its ids before it calls a manager, since the managers push_error on an
##     unknown id;
##   - pauses the live save's play stats while it runs game code, so what it sets
##     off (an event's first time, a count, gold earned) never counts as play;
##   - logs what it did as a [DEV] line in the player's log.
## A command with nothing to do (an action already used up, an event already fired,
## a node already bought, a level already reached) returns "" and logs nothing.
## Statics only.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The prefix of every [DEV] line. The player's log keys its tone off it, and
## log_dev_line() is the one place that writes it.
const _DEV_TAG: String = "[color=magenta][DEV][/color]"

## Where the item resources live. list_item_paths() walks it.
const _ITEMS_DIR: String = "res://resources/items/"

#-----------------------------------------------------------------------------
# ACTIONS AND EVENTS
#-----------------------------------------------------------------------------

## Counts one completion of the current zone's action and runs its success effects,
## as if it had been played, without playing it. Returns "" with nothing done once
## the action has reached its max_completions. Refuses an id the zone has no action
## for, and an action that is not available now (its unlock conditions are unmet).
static func complete_action(action_id: String) -> String:
	var zone: ZoneData = ZoneManager.get_current_zone()
	if zone == null:
		return "There is no current zone"
	var action: ZoneActionData = _find_action(zone, action_id)
	if action == null:
		return "%s is not an action of %s" % [action_id, zone.zone_id]
	if ZoneManager.is_action_used_up(action, zone.zone_id):
		return ""
	if not ZoneManager.get_available_actions(zone.zone_id).has(action):
		return "%s is not available now" % action_id
	_while_paused(ActionManager.complete_without_playing.bind(action, zone.zone_id))
	return _succeed("Completed action %s" % action_id)

## Fires the event, unless it has already fired. Refuses an id the content does not
## listen to (known_event_ids()).
static func trigger_event(event_id: String) -> String:
	if not known_event_ids().has(event_id):
		return "Unknown event: %s" % event_id
	if EventManager.has_event_triggered(event_id):
		return ""
	_while_paused(EventManager.trigger_event.bind(event_id))
	return _succeed("Triggered event %s" % event_id)

#-----------------------------------------------------------------------------
# CULTIVATION AND RESOURCES
#-----------------------------------------------------------------------------

## Raises Core Density to the level, or to the stage's cap when that is lower, through
## real XP, so the milestones pay and the core fills as in play. Returns "" at or
## above the target, with nothing done. Refuses a stage whose next level costs no XP,
## where a level-up changes nothing.
static func reach_core_density(level: int) -> String:
	var target: int = mini(level, CultivationManager.get_core_density_cap())
	if CultivationManager.get_core_density_level() >= target:
		return ""
	var refusal: String = _while_paused(_raise_core_density.bind(target))
	if refusal != "":
		return refusal
	return _succeed("Raised Core Density to level %d" % int(CultivationManager.get_core_density_level()))

## Sets Madra to exactly the value. Refuses a negative value.
static func set_madra(value: float) -> String:
	if value < 0.0:
		return "Madra can't be negative"
	_while_paused(ResourceManager.set_madra.bind(value))
	return _succeed("Set Madra to %d" % int(value))

## Sets gold to exactly the value. Refuses a negative value.
static func set_gold(value: float) -> String:
	if value < 0.0:
		return "Gold can't be negative"
	_while_paused(ResourceManager.set_gold.bind(value))
	return _succeed("Set Gold to %d" % int(value))

## Adds the amount to the Path Point balance.
static func add_path_points(amount: int) -> String:
	_while_paused(PathManager.add_points.bind(amount))
	return _succeed("Granted %d Path Points" % amount)

## Adds the amount to the base value of one attribute. Refuses a value that is not
## an attribute.
static func add_attribute(attribute: CharacterAttributesData.AttributeType, amount: float) -> String:
	if not CharacterAttributesData.AttributeType.values().has(attribute):
		return "Unknown attribute: %d" % attribute
	_while_paused(CharacterManager.add_base_attribute.bind(attribute, amount))
	return _succeed("Added %s %s" % [String.num(amount), CharacterManager.get_attribute_display_name(attribute)])

## Breaks through to the next stage, as a passed Tribulation does. Refuses when the
## stage has no next stage.
static func advance_stage() -> String:
	if not CultivationManager.has_next_stage():
		return "%s has no next stage" % CultivationManager.get_current_advancement_stage_name()
	_while_paused(CultivationManager.advance_to_next_stage)
	return _succeed("Advanced to %s" % CultivationManager.get_current_advancement_stage_name())

#-----------------------------------------------------------------------------
# PATH
#-----------------------------------------------------------------------------

## Buys a node of the current path tree, granting only the Path Points the balance is
## short of, then buying through PathManager. Returns "" once the node has been
## bought, with nothing done. Refuses a node the tree does not have, a stage too low
## for it, and a prerequisite not yet bought (it names it).
static func buy_path_node(node_id: String) -> String:
	var tree: PathTreeData = PathManager.get_current_tree()
	if tree == null:
		return "No path is chosen"
	var node: PathNodeData = tree.get_node_by_id(node_id)
	if node == null:
		return "%s is not a node of the %s path" % [node_id, tree.path_name]
	if PathManager.get_node_purchase_count(node_id) >= 1:
		return ""
	if not PathManager.is_stage_reached(node.required_stage):
		return "%s needs the %s stage" % [node_id, CultivationManager.get_advancement_stage_name(node.required_stage)]
	var unmet: PathNodeData = PathManager.get_unmet_prerequisite(node)
	if unmet != null:
		return "%s needs %s first" % [node_id, unmet.id]
	var missing: int = maxi(node.point_cost - PathManager.get_point_balance(), 0)
	var bought: bool = _while_paused(_grant_and_buy.bind(node_id, missing))
	if not bought:
		return "%s could not be bought" % node_id
	var granted: String = (" (granted %d Path Points)" % missing) if missing > 0 else ""
	return _succeed("Bought path node %s%s" % [node_id, granted])

#-----------------------------------------------------------------------------
# TECHNIQUES AND ABILITIES
#-----------------------------------------------------------------------------

## Unlocks a cycling technique, unless it is unlocked already. Refuses an unknown id.
static func unlock_technique(technique_id: String) -> String:
	if not CyclingManager.has_technique(technique_id):
		return "Unknown technique: %s" % technique_id
	if CyclingManager.is_technique_unlocked(technique_id):
		return ""
	_while_paused(CyclingManager.unlock_technique.bind(technique_id))
	return _succeed("Unlocked technique %s" % technique_id)

## Equips a cycling technique, replacing the equipped one. Refuses an unknown id and a
## locked technique.
static func equip_technique(technique_id: String) -> String:
	if not CyclingManager.has_technique(technique_id):
		return "Unknown technique: %s" % technique_id
	if not CyclingManager.is_technique_unlocked(technique_id):
		return "%s is locked" % technique_id
	_while_paused(CyclingManager.equip_technique.bind(technique_id))
	return _succeed("Equipped technique %s" % technique_id)

## Unlocks a combat ability, unless it is unlocked already. Refuses an unknown id.
static func unlock_ability(ability_id: String) -> String:
	if not AbilityManager.has_ability(ability_id):
		return "Unknown ability: %s" % ability_id
	if AbilityManager.is_ability_unlocked(ability_id):
		return ""
	_while_paused(AbilityManager.unlock_ability.bind(ability_id))
	return _succeed("Unlocked ability %s" % ability_id)

## Equips a combat ability in a slot, replacing what is there. `slot` counts from 1,
## as the player sees the slots. Refuses an unknown ability, a locked one, and a slot
## that is not 1 to the slot count.
static func equip_ability(ability_id: String, slot: int) -> String:
	if not AbilityManager.has_ability(ability_id):
		return "Unknown ability: %s" % ability_id
	if not AbilityManager.is_ability_unlocked(ability_id):
		return "%s is locked" % ability_id
	var slot_count: int = AbilityManager.get_max_slots()
	if slot < 1 or slot > slot_count:
		return "Slot must be 1 to %d, not %d" % [slot_count, slot]
	_while_paused(AbilityManager.equip_ability_at_slot.bind(ability_id, slot - 1))
	return _succeed("Equipped ability %s in slot %d" % [ability_id, slot])

## Unlocks every cycling technique, and logs how many were new.
static func unlock_all_techniques() -> String:
	var newly_unlocked: int = _while_paused(_unlock_every_technique)
	return _succeed("Unlocked all techniques (%d new)" % newly_unlocked)

## Unlocks every combat ability, and logs how many were new.
static func unlock_all_abilities() -> String:
	var newly_unlocked: int = _while_paused(_unlock_every_ability)
	return _succeed("Unlocked all abilities (%d new)" % newly_unlocked)

#-----------------------------------------------------------------------------
# ITEMS
#-----------------------------------------------------------------------------

## Awards copies of the item at `item_path`. Refuses a path that is not an item and a
## quantity below 1. Equipment needs a free grid slot for every copy: InventoryManager
## would drop one that has none and still log "Looted", so a full grid is refused here.
static func award_item(item_path: String, quantity: int) -> String:
	var item: ItemDefinitionData = null
	if ResourceLoader.exists(item_path):
		item = load(item_path) as ItemDefinitionData
	if item == null:
		return "%s is not an item" % item_path
	if quantity < 1:
		return "Quantity must be at least 1"
	if item.item_type == ItemDefinitionData.ItemType.EQUIPMENT:
		if InventoryManager.get_inventory().free_equipment_slots().size() < quantity:
			return "Equipment is full"
	_while_paused(InventoryManager.award_items.bind(item, quantity))
	return _succeed("Gave %dx %s" % [quantity, item.item_id])

## Grants one more equipment page.
static func grant_equipment_page() -> String:
	_while_paused(InventoryManager.grant_equipment_page)
	return _succeed("Granted an equipment page (%d now)" % InventoryManager.get_inventory().unlocked_equipment_pages)

#-----------------------------------------------------------------------------
# WORLD AND ADVENTURE
#-----------------------------------------------------------------------------

## Makes the zone the current one. Refuses an id that is not a zone, and travel while
## anything but an idle action (foraging or training) runs: travel makes ActionManager
## stop whatever runs with success, which counts a completion and runs its success
## effects. That is right for the action a player leaves by moving on, and wrong for a
## dialogue, a cycle, an adventure, the shop or the Tribulation, which would be cashed
## in unplayed.
static func travel_to_zone(zone_id: String) -> String:
	if not ZoneManager.has_zone(zone_id):
		return "Unknown zone: %s" % zone_id
	var running: ZoneActionData = ActionManager.get_current_action()
	if running != null and not ActionManager.is_idle_action(running):
		return "Can't travel while %s runs" % running.action_id
	_while_paused(ZoneManager.set_current_zone_by_id.bind(zone_id))
	return _succeed("Travelled to %s" % zone_id)

## Fills the player's Health and Stamina, and keeps the Madra the run has left.
## Refuses unless an adventure runs.
static func refill_vitals() -> String:
	var running: ZoneActionData = ActionManager.get_current_action()
	if running == null or running.action_type != ZoneActionData.ActionType.ADVENTURE:
		return "No adventure is running"
	var vitals: VitalsManager = PlayerManager.vitals_manager
	_while_paused(vitals.initialize_current_values.bind(vitals.current_madra))
	return _succeed("Refilled Health and Stamina")

## Wins the fight that is on by killing its enemy through its Health, so the fight
## ends as in play: it pays its gold, fires q_first_steps_enemy_defeated and resolves
## its tile. Refuses without a view or a fight.
static func force_win_fight(view: AdventureView) -> String:
	if not is_instance_valid(view) or not view.is_in_combat:
		return "No fight is on"
	_while_paused(view.force_win_combat)
	return _succeed("Won the fight")

## Ends the adventure that runs at once, as a victory (the boss-win path: its success
## effects and the victory end card) or as a defeat (its failure effects and a retreat
## end card). Refuses without a view or a run.
static func exit_adventure(view: AdventureView, victory: bool) -> String:
	if not is_instance_valid(view) or not view.is_adventure_running():
		return "No adventure is running"
	_while_paused(view.force_end_adventure.bind(victory))
	return _succeed("Ended the adventure as a %s" % ("victory" if victory else "defeat"))

#-----------------------------------------------------------------------------
# CATALOGS
#-----------------------------------------------------------------------------

## The ids of the events the content listens to, sorted, each once: the event every
## EVENT_TRIGGERED unlock condition waits for, and every quest step's completion
## event. Firing any other event changes nothing in the game.
static func known_event_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for condition: UnlockConditionData in UnlockManager.unlock_condition_list.list:
		if condition.condition_type == UnlockConditionData.ConditionType.EVENT_TRIGGERED:
			_add_id(ids, str(condition.target_value))
	for quest: QuestData in QuestManager.get_all_quests():
		for step: QuestStepData in quest.steps:
			_add_id(ids, step.completion_event_id)
	ids.sort()
	return ids

## The path of every item resource under res://resources/items/, nested folders
## included, sorted.
static func list_item_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	_collect_item_paths(_ITEMS_DIR, paths)
	paths.sort()
	return paths

#-----------------------------------------------------------------------------
# THE DEV LINE
#-----------------------------------------------------------------------------

## Logs `what` as a [DEV] line in the player's log: the tag, a space, then the text.
## Every command logs its success through it, and so do the dev tools that are not
## commands (DevManager's session lines, the dev panel's toggles).
static func log_dev_line(what: String) -> void:
	LogManager.log_message("%s %s" % [_DEV_TAG, what])

#-----------------------------------------------------------------------------
# PRIVATE HELPERS
#-----------------------------------------------------------------------------

## Runs `work` with the live save's play stats paused, and returns what it returned.
## Nothing that `work` sets off counts as play. The pause is put back as it was
## found, so a command run inside a longer pause leaves that pause on. Every call a
## command makes that changes the game goes through here, so no early return can
## leave the stats paused.
static func _while_paused(work: Callable) -> Variant:
	var stats: PlayStatsData = PersistenceManager.save_game_data.stats
	var was_paused: bool = stats.recording_paused
	stats.recording_paused = true
	var result: Variant = work.call()
	stats.recording_paused = was_paused
	return result

## Logs what a command did as a [DEV] line, and returns "": the value every command
## that worked returns.
static func _succeed(what: String) -> String:
	log_dev_line(what)
	return ""

## The zone's action with this id, or null when it has none.
static func _find_action(zone: ZoneData, action_id: String) -> ZoneActionData:
	for action: ZoneActionData in zone.all_actions:
		if action.action_id == action_id:
			return action
	return null

## Adds the XP for the next level until the target is reached. Each add crosses one
## level. Returns the reason it stopped when an add changed nothing, "" when the
## target is reached.
static func _raise_core_density(target: int) -> String:
	while CultivationManager.get_core_density_level() < target:
		var before: float = CultivationManager.get_core_density_level()
		CultivationManager.add_core_density_xp(CultivationManager.get_xp_for_next_level())
		if CultivationManager.get_core_density_level() <= before:
			return "Core Density stays at level %d: the next level costs no XP" % int(before)
	return ""

## Grants `missing` Path Points, when it is more than 0, and buys the node.
static func _grant_and_buy(node_id: String, missing: int) -> bool:
	if missing > 0:
		PathManager.add_points(missing)
	return PathManager.purchase_node(node_id)

## Unlocks each technique still locked. Returns how many it unlocked.
static func _unlock_every_technique() -> int:
	var newly_unlocked: int = 0
	for technique: CyclingTechniqueData in CyclingManager.get_all_techniques():
		if not CyclingManager.is_technique_unlocked(technique.id):
			CyclingManager.unlock_technique(technique.id)
			newly_unlocked += 1
	return newly_unlocked

## Unlocks each ability still locked. Returns how many it unlocked.
static func _unlock_every_ability() -> int:
	var newly_unlocked: int = 0
	for ability: AbilityData in AbilityManager.get_all_abilities():
		if not AbilityManager.is_ability_unlocked(ability.ability_id):
			AbilityManager.unlock_ability(ability.ability_id)
			newly_unlocked += 1
	return newly_unlocked

## Adds the id to the array, unless it is empty or already there.
static func _add_id(ids: PackedStringArray, id: String) -> void:
	if id != "" and not ids.has(id):
		ids.append(id)

## Adds the path of each item resource in the folder, and in the folders under it,
## to the array. ResourceLoader.list_directory() ends a folder's name with "/".
static func _collect_item_paths(directory: String, paths: PackedStringArray) -> void:
	for entry: String in ResourceLoader.list_directory(directory):
		if entry.ends_with("/"):
			_collect_item_paths(directory + entry, paths)
		elif entry.ends_with(".tres") and load(directory + entry) is ItemDefinitionData:
			paths.append(directory + entry)
