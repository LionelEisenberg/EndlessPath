## Manages the inventory book: tab switching with the page turn, and returning
## anything held in a trash slot when the book closes. Opening and closing the
## book is shared with the other menu books (MenuBookView).
extends MenuBookView

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

@onready var tab_switcher: Control = %TabSwitcher
@onready var tabs: Array[Control] = [%EquipmentTab, %ConsumablesTab, %MaterialsTab, %QuestItemsTab]

## Tracks the previously-shown tab index so _on_tab_changed can decide whether
## to play the page-turn animation forward (going to a later tab) or backwards
## (going to an earlier tab).
var _last_tab_index: int = 0

## The tab to show once the running page turn lands.
var _pending_tab_index: int = 0


func _ready() -> void:
	super._ready()
	tab_switcher.tab_changed.connect(_on_tab_changed)
	book_frame.page_turned.connect(_on_page_turned)

	# Initialize visibility
	for i in range(tabs.size()):
		tabs[i].visible = false
	tabs[0].visible = true

## Handle tab changes by playing page turn animation.
## Plays forward when moving to a later tab, backwards when moving to an earlier
## tab so the flipping direction matches the direction of travel through the book.
func _on_tab_changed(index: int) -> void:
	# Set all tabs to invisible, play animation, set tab to visible
	for i in range(tabs.size()):
		tabs[i].visible = false
	_pending_tab_index = index
	book_frame.turn_page(index > _last_tab_index)
	_last_tab_index = index

## Show the new tab content when page turn animation finishes.
func _on_page_turned() -> void:
	tabs[_pending_tab_index].visible = true

## Return anything held in a trash slot to the inventory once the book closes.
func _after_close() -> void:
	for trash in get_tree().get_nodes_in_group("TrashSlots"):
		if trash.has_method("flush_to_inventory"):
			trash.flush_to_inventory()
