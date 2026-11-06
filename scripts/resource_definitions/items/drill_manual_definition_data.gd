class_name DrillManualDefinitionData
extends ItemDefinitionData

## DrillManualDefinitionData
## A manual that teaches one body refining drill. It teaches the moment it
## arrives, however it arrives (loot, a quest reward, the dev panel), so the
## teaching belongs to the manual: InventoryManager.award_items() calls teach()
## and keeps nothing. Once its drill is known it stops dropping (can_drop()), and
## a copy that still arrives teaches nothing.

## The colour of the line a manual logs.
const LOG_COLOR: String = "#D4A84A"

## The id of the drill the manual teaches (a DrillData id).
@export var drill_id: String = ""

func _init() -> void:
	item_type = ItemType.DRILL_MANUAL

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## The drill the manual teaches, or null when the catalog has no such drill.
func get_drill() -> DrillData:
	return BodyRefiningManager.get_drill(drill_id)

## Whether the player already knows the manual's drill.
func is_known() -> bool:
	return BodyRefiningManager.is_drill_unlocked(drill_id)

## Teaches the manual's drill. Returns true when it taught it, false when the
## drill was known already (or doesn't exist).
func teach() -> bool:
	if is_known():
		return false
	BodyRefiningManager.unlock_drill(drill_id)
	return is_known()

## The log line for reading the manual: what it taught, or that the drill was
## known already. One log line either way.
func log_line(taught: bool) -> String:
	var text: String = "Learned %s from its manual" % _drill_name() if taught else "You know %s already" % _drill_name()
	return "[color=%s]%s[/color]" % [LOG_COLOR, text]

## A manual drops only while its drill is unknown: a second copy would teach
## nothing.
func can_drop() -> bool:
	return not is_known()

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _get_item_effects() -> Array[String]:
	return ["Teaches %s" % _drill_name()]

func _drill_name() -> String:
	var drill: DrillData = get_drill()
	return drill.drill_name if drill != null else drill_id
