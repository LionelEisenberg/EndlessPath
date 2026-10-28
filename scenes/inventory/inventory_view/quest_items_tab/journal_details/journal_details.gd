class_name JournalDetails
extends VBoxContainer

## JournalDetails
## The Journal's details, pressed into the right page under the item's name:
## the item's panel and its quest's panel, 16 px apart, each growing downward
## with its text.
##
## The item's panel holds the quest item in a deep slot beside "QUEST ITEM" and
## where it came from ("From Old Vesh, in the broken shrine", left out when
## unknown), then its description under a vermilion drop cap two lines tall:
## the words that fit beside the cap run in a narrow column, the rest at full
## width under it (BookText.split_for_drop_cap()).
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
## panel's content, "QUEST ITEM"'s baseline sits at 34 and the source's at 64;
## the narrow column's baselines from 120, 26 px apart, beside the cap's at 136.
## The column is two lines tall whatever its text, and the full-width lines
## carry on at the same pitch; the panel ends 34 px under the description's last
## baseline. Down the quest panel's content, "QUEST"'s baseline sits at 16 and
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
## The narrow column beside the drop cap: the mockup's width, and the two lines
## the cap stands. A capital too wide to leave the column that much room
## narrows it, so the column never runs past the text's right edge.
const _NARROW_WIDTH: float = 390.0
const _NARROW_LINES: int = 2

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _icon: TextureRect = %Icon
@onready var _from_label: Label = %FromLabel
@onready var _description_block: Control = %DescriptionBlock
@onready var _cap_row: HBoxContainer = %CapRow
@onready var _drop_cap: Label = %DropCap
@onready var _narrow_text: Label = %NarrowText
@onready var _rest_text: Label = %RestText
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

## Prints the item: its icon, where it came from and its description.
func _print_item(item: ItemDefinitionData) -> void:
	_icon.texture = item.icon
	var from_source: String = (item as QuestItemDefinitionData).from_source if item is QuestItemDefinitionData else ""
	_from_label.text = _FROM % from_source
	_from_label.visible = not from_source.is_empty()
	_print_description(item.description)

## Prints the description under its drop cap, its first letter. The words that
## fit in two lines beside the cap fill the narrow column and the rest run on
## at full width. The split measures the words in the column's own font, at the
## column's own width, so it breaks where the column wraps. The description is
## left out when there is none.
func _print_description(description: String) -> void:
	_description_block.visible = not description.is_empty()
	if description.is_empty():
		return
	_drop_cap.text = description.left(1)
	# The column takes what the cap leaves of the text's width, up to the mockup's.
	var room: float = _rest_text.custom_minimum_size.x - _cap_row.get_theme_constant(&"separation") - _drop_cap.get_minimum_size().x
	var narrow_width: float = minf(_NARROW_WIDTH, room)
	_narrow_text.custom_minimum_size.x = narrow_width
	_narrow_text.size.x = narrow_width
	var parts: PackedStringArray = BookText.split_for_drop_cap(description,
			_narrow_text.get_theme_font(&"font"), _narrow_text.get_theme_font_size(&"font_size"),
			narrow_width, _NARROW_LINES)
	_narrow_text.text = parts[1]
	_rest_text.text = parts[2]
	_rest_text.visible = not parts[2].is_empty()

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
