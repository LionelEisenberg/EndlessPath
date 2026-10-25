class_name DevStepData extends Resource

## DevStepData
## One step of a dev recipe: a kind, the id it acts on and an amount. A story beat is a
## list of steps and so is a save preset. A step never touches a manager itself:
## apply() calls the matching DevCommands command, and validate() asks the managers'
## own quiet lookups, so checking a step never trips a manager's push_error.

#-----------------------------------------------------------------------------
# DATA
#-----------------------------------------------------------------------------

## What a step does, with the fields it reads (the rest are ignored):
##   COMPLETE_ACTION      target_id: an action id
##   TRIGGER_EVENT        target_id: an event id
##   REACH_CORE_DENSITY   amount: the level
##   SET_MADRA            amount: the value
##   SET_GOLD             amount: the value
##   BUY_PATH_NODE        target_id: a node id of the current path tree
##   UNLOCK_TECHNIQUE     target_id: a technique id
##   EQUIP_TECHNIQUE      target_id: a technique id
##   UNLOCK_ABILITY       target_id: an ability id
##   EQUIP_ABILITY        target_id: an ability id; amount: the slot, 1 to 4
##   AWARD_ITEM           target_id: an item resource path; amount: the quantity
##   ADVANCE_STAGE        nothing
##   TRAVEL               target_id: a zone id
## A kind is stored as an int in .tres files: append a kind, never insert or reorder one.
enum Kind {
	COMPLETE_ACTION,
	TRIGGER_EVENT,
	REACH_CORE_DENSITY,
	SET_MADRA,
	SET_GOLD,
	BUY_PATH_NODE,
	UNLOCK_TECHNIQUE,
	EQUIP_TECHNIQUE,
	UNLOCK_ABILITY,
	EQUIP_ABILITY,
	AWARD_ITEM,
	ADVANCE_STAGE,
	TRAVEL,
}

@export var kind: Kind = Kind.COMPLETE_ACTION
## The id or path the step acts on. Kind lists which kinds read it.
@export var target_id: String = ""
## The level, value, slot or quantity. A level, a slot and a quantity are whole numbers:
## the part after the point is dropped. Kind lists which kinds read it.
@export var amount: float = 0.0

#-----------------------------------------------------------------------------
# APPLY
#-----------------------------------------------------------------------------

## Runs the step through its DevCommands command. Returns "" when it worked or had
## nothing to do, or the reason the command refused.
func apply() -> String:
	match kind:
		Kind.COMPLETE_ACTION:
			return DevCommands.complete_action(target_id)
		Kind.TRIGGER_EVENT:
			return DevCommands.trigger_event(target_id)
		Kind.REACH_CORE_DENSITY:
			return DevCommands.reach_core_density(_whole_amount())
		Kind.SET_MADRA:
			return DevCommands.set_madra(amount)
		Kind.SET_GOLD:
			return DevCommands.set_gold(amount)
		Kind.BUY_PATH_NODE:
			return DevCommands.buy_path_node(target_id)
		Kind.UNLOCK_TECHNIQUE:
			return DevCommands.unlock_technique(target_id)
		Kind.EQUIP_TECHNIQUE:
			return DevCommands.equip_technique(target_id)
		Kind.UNLOCK_ABILITY:
			return DevCommands.unlock_ability(target_id)
		Kind.EQUIP_ABILITY:
			return DevCommands.equip_ability(target_id, _whole_amount())
		Kind.AWARD_ITEM:
			return DevCommands.award_item(target_id, _whole_amount())
		Kind.ADVANCE_STAGE:
			return DevCommands.advance_stage()
		Kind.TRAVEL:
			return DevCommands.travel_to_zone(target_id)
	return "Unknown step kind: %d" % kind

#-----------------------------------------------------------------------------
# READING
#-----------------------------------------------------------------------------

## The step in a few plain words, for the panel and for a failed build to name it by:
## "Complete celestial_intervener_dialogue_1", "Set gold to 700". An item is named by
## its file, not its whole path.
func describe() -> String:
	match kind:
		Kind.COMPLETE_ACTION:
			return "Complete %s" % target_id
		Kind.TRIGGER_EVENT:
			return "Trigger event %s" % target_id
		Kind.REACH_CORE_DENSITY:
			return "Reach Core Density %d" % _whole_amount()
		Kind.SET_MADRA:
			return "Set Madra to %s" % _value_text()
		Kind.SET_GOLD:
			return "Set gold to %s" % _value_text()
		Kind.BUY_PATH_NODE:
			return "Buy path node %s" % target_id
		Kind.UNLOCK_TECHNIQUE:
			return "Unlock technique %s" % target_id
		Kind.EQUIP_TECHNIQUE:
			return "Equip technique %s" % target_id
		Kind.UNLOCK_ABILITY:
			return "Unlock ability %s" % target_id
		Kind.EQUIP_ABILITY:
			return "Equip ability %s in slot %d" % [target_id, _whole_amount()]
		Kind.AWARD_ITEM:
			return "Award %dx %s" % [_whole_amount(), target_id.get_file().get_basename()]
		Kind.ADVANCE_STAGE:
			return "Advance to the next stage"
		Kind.TRAVEL:
			return "Travel to %s" % target_id
	return "Unknown step kind %d" % kind

## Everything wrong with the step, one line each; empty when it is sound. A line starts
## with describe(), then says what is wrong: an id the content does not have, a level
## below 1, a slot outside 1 to the slot count, a quantity below 1, a negative Madra or
## gold value. It reads the managers' catalogs and the current path tree, never the
## save, so what a step needs the save to hold (an action available now, a node's
## prerequisite) is checked when it is applied, not here.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for problem: String in [_problem_with_target(), _problem_with_amount()]:
		if problem != "":
			errors.append("%s: %s" % [describe(), problem])
	return errors

#-----------------------------------------------------------------------------
# PRIVATE HELPERS
#-----------------------------------------------------------------------------

## `amount` as the whole number a level, a slot or a quantity is.
func _whole_amount() -> int:
	return int(amount)

## `amount` as a Madra or gold value is written: "700", or "12.5" when it has a fraction.
func _value_text() -> String:
	if amount == floorf(amount):
		return str(int(amount))
	return String.num(amount)

## Why `target_id` is no good for this kind: an id the content does not have. "" when it
## is fine, or when the kind reads no target.
func _problem_with_target() -> String:
	match kind:
		Kind.COMPLETE_ACTION:
			if ZoneManager.get_action_by_id(target_id) == null:
				return "unknown action"
		Kind.TRIGGER_EVENT:
			if not DevCommands.known_event_ids().has(target_id):
				return "unknown event"
		Kind.BUY_PATH_NODE:
			var tree: PathTreeData = PathManager.get_current_tree()
			if tree == null:
				return "no current path tree"
			if tree.get_node_by_id(target_id) == null:
				return "not a node of the %s path" % tree.path_name
		Kind.UNLOCK_TECHNIQUE, Kind.EQUIP_TECHNIQUE:
			if not CyclingManager.has_technique(target_id):
				return "unknown technique"
		Kind.UNLOCK_ABILITY, Kind.EQUIP_ABILITY:
			if not AbilityManager.has_ability(target_id):
				return "unknown ability"
		Kind.AWARD_ITEM:
			if not _is_item_path(target_id):
				return "%s is not an item" % target_id
		Kind.TRAVEL:
			if not ZoneManager.has_zone(target_id):
				return "unknown zone"
		Kind.REACH_CORE_DENSITY, Kind.SET_MADRA, Kind.SET_GOLD, Kind.ADVANCE_STAGE:
			pass
		_:
			return "this build has no such step kind"
	return ""

## Why `amount` is no good for this kind. "" when it is fine, or when the kind reads no
## amount.
func _problem_with_amount() -> String:
	match kind:
		Kind.REACH_CORE_DENSITY:
			if _whole_amount() < 1:
				return "the level must be at least 1"
		Kind.SET_MADRA:
			if amount < 0.0:
				return "Madra can't be negative"
		Kind.SET_GOLD:
			if amount < 0.0:
				return "gold can't be negative"
		Kind.EQUIP_ABILITY:
			var slot: int = _whole_amount()
			var slot_count: int = AbilityManager.get_max_slots()
			if slot < 1 or slot > slot_count:
				return "the slot must be 1 to %d" % slot_count
		Kind.AWARD_ITEM:
			if _whole_amount() < 1:
				return "the quantity must be at least 1"
	return ""

## True when the path is a resource that loads as an item. Looks before it loads, as
## DevCommands.award_item() does.
func _is_item_path(path: String) -> bool:
	return ResourceLoader.exists(path) and load(path) is ItemDefinitionData
