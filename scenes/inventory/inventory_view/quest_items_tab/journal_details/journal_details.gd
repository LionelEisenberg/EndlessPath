class_name JournalDetails
extends VBoxContainer

## JournalDetails
## The Journal's details, pressed into the right page under the item's name:
## the item's panel and its quest's panel, 16 px apart, each growing downward
## with its text.
##
## The item's panel holds the quest item in a deep slot beside "QUEST ITEM" and
## where it came from ("From Old Vesh, in the broken shrine", left out when
## unknown), the name of the zone it belongs to on a paper tag at the panel's
## top right ("SPIRIT VALLEY", on QUEST ITEM's baseline; left out when it has
## none), then its description.
##
## The quest's panel shows the quest the item belongs to
## (QuestManager.get_quest_id_for_item()) the way the Goals board shows a quest:
## "QUEST", with a DONE seal at the top right once it is finished, the quest's
## name, its description as flavour text, a pressed rule, then the steps reached
## so far, each in a tick box (QuestStepRow). A finished quest ticks every step.
## An active one ticks the steps before the one the player is on, which shows
## how far along it is; later steps are not shown. The panel is left out for an
## item that belongs to no quest.
##
## Laid out to the mockup's Refugee Camp Map, whose panels fill the spec's
## (1008, 300) to (1476, 496) and (1008, 512) to (1476, 776). Down the item
## panel's content, "QUEST ITEM"'s and the tag's baselines sit at 34 and the
## source's at 64; the description's from 120, 26 px apart; the panel ends 34 px
## under the description's last baseline. Down the quest panel's content, "QUEST"'s baseline sits at 16 and
## the seal 2 px over the content's top, as the mockup draws it; the name's
## baseline at 52, the flavour's from 82, 22 px apart; the rule 30 px under the
## flavour's last line, the steps from 14 px under the rule, 34 px apart, and
## 14 px under the last step the content ends.
##
## Every block grows by an even number of px a line, so the panels and their
## art stay on even pixels when text wraps: the source and the quest's name,
## whose single lines are an odd 17 and 39 px, are padded 1 px underneath
## (wrap_pad.tres), and the flavour's top margin is 1 px short to match.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const _STEP_ROW_SCENE: PackedScene = preload("res://scenes/inventory/inventory_view/quest_items_tab/quest_step_row/quest_step_row.tscn")

## Where the item came from, as the panel prints it.
const _FROM: String = "From %s"

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _icon: TextureRect = %Icon
@onready var _from_label: Label = %FromLabel
@onready var _zone_tag: PaperTag = %ZoneTag
@onready var _description_block: Control = %DescriptionBlock
@onready var _description: Label = %Description
@onready var _quest_panel: Control = %QuestPanel
@onready var _seal: Label = %Seal
@onready var _quest_name: Label = %QuestName
@onready var _flavor_block: Control = %FlavorBlock
@onready var _flavor: Label = %Flavor
@onready var _steps_block: Control = %StepsBlock
@onready var _steps: VBoxContainer = %Steps

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _item: ItemDefinitionData = null

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Shows `item` and the quest it belongs to, read afresh from QuestManager, and
## makes the details visible. A null `item` clears them.
func show_item(item: ItemDefinitionData) -> void:
	if item == null:
		clear()
		return
	_item = item
	_print_item(item)
	_print_quest(QuestManager.get_quest_id_for_item(item))
	visible = true

## Empties the details and hides them.
func clear() -> void:
	_item = null
	visible = false

## Returns the item the details show, or null while they are cleared.
func get_item() -> ItemDefinitionData:
	return _item

#-----------------------------------------------------------------------------
# THE ITEM'S PANEL
#-----------------------------------------------------------------------------

## Prints the item: its icon, where it came from, its zone and its description.
func _print_item(item: ItemDefinitionData) -> void:
	_icon.texture = item.icon
	var quest_item: QuestItemDefinitionData = item as QuestItemDefinitionData
	var from_source: String = quest_item.from_source if quest_item else ""
	_from_label.text = _FROM % from_source
	_from_label.visible = not from_source.is_empty()
	_print_zone(quest_item.zone_id if quest_item else "")
	_description.text = item.description
	_description_block.visible = not item.description.is_empty()

## Prints the zone's name on the tag, in capitals, or leaves the tag out when
## the item names no zone the game knows.
func _print_zone(zone_id: String) -> void:
	var known: bool = not zone_id.is_empty() and ZoneManager.has_zone(zone_id)
	_zone_tag.visible = known
	if known:
		_zone_tag.set_label(ZoneManager.get_zone_by_id(zone_id).zone_name.to_upper())

#-----------------------------------------------------------------------------
# THE QUEST'S PANEL
#-----------------------------------------------------------------------------

## Prints the quest `quest_id`, or leaves the panel out when there is none: its
## seal, name and flavour text, then the steps reached so far.
func _print_quest(quest_id: String) -> void:
	var quest: QuestData = QuestManager.get_quest_data(quest_id)
	_quest_panel.visible = quest != null
	if quest == null:
		return
	var done: bool = QuestManager.has_completed_quest(quest_id)
	_seal.visible = done
	_quest_name.text = quest.quest_name
	_flavor.text = quest.description
	_flavor_block.visible = not quest.description.is_empty()
	# A finished quest has reached past its last step; an active one is on its current step.
	var current: int = quest.steps.size() if done else QuestManager.get_current_step_index(quest_id)
	_set_steps(quest, current)

## Replaces the step rows with the steps up to `current`: the ones before it
## ticked and read at their target, `current` itself (if the quest has it)
## unticked and read as it stands. Hides the rule and the steps when there are
## none.
func _set_steps(quest: QuestData, current: int) -> void:
	for row: Node in _steps.get_children():
		_steps.remove_child(row)
		row.queue_free()
	for index: int in mini(current + 1, quest.steps.size()):
		var step: QuestStepData = quest.steps[index]
		var finished: bool = index < current
		var row: QuestStepRow = _STEP_ROW_SCENE.instantiate() as QuestStepRow
		_steps.add_child(row)
		row.setup(step.description, finished, step.get_progress_text(finished))
	_steps_block.visible = _steps.get_child_count() > 0
