extends Control

## QuestItemsTab
## The Journal tab, pressed into the book's two pages at 1x. Left page: the
## caption "QUEST ITEMS" and the list of quest items (JournalRow), one
## row every 80 px, each with the quest it belongs to
## (QuestManager.get_quest_id_for_item()): a DONE seal once that quest is
## finished, the step the player is on while it is under way. Past six rows the
## list scrolls. The list sits in ListFrame, which clips the rows in its place:
## the list itself does not clip, so the printer's marks round a row show whole.
## Right page: the item's name as the title and, under its last line, the
## details (JournalDetails): the item's panel and its quest's panel. The details
## show the item last pointed at and keep to it while the bag changes; printer's
## marks sit round its row. With no quest item, the page says so and the right
## page stays blank. Quest items can't be dragged or discarded.

const _ROW_SCENE: PackedScene = preload("res://scenes/inventory/inventory_view/quest_items_tab/journal_row.tscn")

## What a row prints at the right while its quest is under way.
const _STEP: String = "Step %d of %d"

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var list: InventoryList = %JournalList
@onready var empty_label: Label = %EmptyLabel
@onready var right_title: PageTitle = %RightTitle
@onready var details: JournalDetails = %JournalDetails

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## Content hash of the quest items at the last rebuild. Equipment, consumable
## and material changes (foraging every 5 s) leave them alone, so they skip it.
var _last_quest_items_hash: int = 0
## The list's rows, top to bottom.
var _rows: Array[JournalRow] = []
## The row the printer's marks sit round; null when none.
var _marked: JournalRow = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_rebuild(InventoryManager.get_quest_items())

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Opens the page on its first item: rebuilds the list, then shows the first
## quest item, or hides the details when the journal is empty. The rebuild
## reads each quest afresh, so a step reached since the page last showed is
## printed. Called whenever the page is opened.
func open_page() -> void:
	_rebuild(InventoryManager.get_quest_items())
	_show_first()

#-----------------------------------------------------------------------------
# REBUILD
#-----------------------------------------------------------------------------

## Rebuilds the list, one row per quest item in inventory order, the last
## without its rule, then keeps the details on the item they show.
func _rebuild(quest_items: Dictionary[ItemDefinitionData, int]) -> void:
	_last_quest_items_hash = quest_items.hash()
	_marked = null
	list.clear_slots()
	_rows.clear()
	for item: ItemDefinitionData in quest_items.keys():
		_add_row(item)
	if not _rows.is_empty():
		_rows[-1].set_rule_visible(false)
	empty_label.visible = _rows.is_empty()
	_follow_shown(quest_items)

## Adds one row for `item`. Under its name, the name of the quest it belongs
## to, or where it came from when it belongs to none; at the right, the seal of
## a finished quest or the step of one under way.
func _add_row(item: ItemDefinitionData) -> void:
	var row: JournalRow = _ROW_SCENE.instantiate() as JournalRow
	list.add_slot(row)
	var quest_id: String = QuestManager.get_quest_id_for_item(item)
	var quest: QuestData = QuestManager.get_quest_data(quest_id)
	var done: bool = quest != null and QuestManager.has_completed_quest(quest_id)
	var step_text: String = ""
	if quest != null and not done:
		step_text = _STEP % [QuestManager.get_current_step_index(quest_id) + 1, quest.steps.size()]
	row.setup(item, _second_line(item, quest), done, step_text)
	row.hovered.connect(_on_row_hovered)
	row.clicked.connect(_on_row_clicked)
	_rows.append(row)

## The line under an item's name: its quest's name, or where it came from
## when it belongs to no quest.
static func _second_line(item: ItemDefinitionData, quest: QuestData) -> String:
	if quest != null:
		return quest.quest_name
	if item is QuestItemDefinitionData:
		return (item as QuestItemDefinitionData).from_source
	return ""

#-----------------------------------------------------------------------------
# THE SHOWN ITEM
#-----------------------------------------------------------------------------

## Shows `item` in the details and its name as the right page's title, and
## marks `row`, unmarking the one before.
func _show(item: ItemDefinitionData, row: JournalRow) -> void:
	_mark(row)
	right_title.title = item.item_name
	right_title.visible = true
	details.show_item(item)

## Shows the first quest item, or clears the details, the title and the marks
## when the journal is empty.
func _show_first() -> void:
	if _rows.is_empty():
		_mark(null)
		details.clear()
		right_title.visible = false
		return
	_show(_rows[0].get_item(), _rows[0])

## Keeps the details and the marks on the item shown after the bag changed,
## printing it again. When it has left the bag, the page shows its first item.
func _follow_shown(quest_items: Dictionary[ItemDefinitionData, int]) -> void:
	var shown: ItemDefinitionData = details.get_item()
	if shown == null or not quest_items.has(shown):
		_show_first()
		return
	_show(shown, _row_of(shown))

## Moves the printer's marks to `row`. Null leaves nothing marked.
func _mark(row: JournalRow) -> void:
	if _marked != null and _marked != row and is_instance_valid(_marked):
		_marked.set_marked(false)
	_marked = row
	if row != null:
		row.set_marked(true)

## The row showing `item`, or null.
func _row_of(item: ItemDefinitionData) -> JournalRow:
	for row: JournalRow in _rows:
		if row.get_item() == item:
			return row
	return null

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## Pointing at a row shows its item.
func _on_row_hovered(row: JournalRow) -> void:
	_show(row.get_item(), row)

## A left press on a row shows its item, as pointing at it does.
func _on_row_clicked(row: JournalRow) -> void:
	_show(row.get_item(), row)

func _on_inventory_changed(inv: InventoryData) -> void:
	# Only the quest items drive the page: skip the rebuild when an equipment,
	# consumable or material change left them as they were.
	if inv.quest_items.hash() != _last_quest_items_hash:
		_rebuild(inv.quest_items)
