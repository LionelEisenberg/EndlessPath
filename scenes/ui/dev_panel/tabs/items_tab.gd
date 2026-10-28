extends ScrollContainer

## The dev panel's Items tab: give the player any item the game has, and grant one more
## equipment page, each through DevCommands, which logs it and says why it refused.
## The picker lists every item resource under res://resources/items/ by its name, each
## item's metadata its path. Two items that share a name also read their file name, so
## the developer can tell which is which. Give awards the quantity picked, 1 to 99, of
## the item picked; equipment needs a free grid slot for every copy, and a full grid is
## refused. A refusal shows in the status line under the controls until a command works.

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _item_option: OptionButton = %ItemOption
@onready var _quantity_spin: SpinBox = %QuantitySpin
@onready var _give_button: Button = %GiveButton
@onready var _status: Label = %ItemsStatus
@onready var _grant_page_button: Button = %GrantPageButton

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## Lists the items in the picker, each item's metadata its path, and connects the two
## buttons.
func _ready() -> void:
	_fill_items()
	_give_button.pressed.connect(_on_give_pressed)
	_grant_page_button.pressed.connect(_on_grant_page_pressed)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## Gives the quantity picked of the item picked. A refusal shows in the status line until
## a command works.
func _on_give_pressed() -> void:
	if _item_option.selected < 0:
		return
	var item_path: String = _item_option.get_item_metadata(_item_option.selected)
	_show_result(DevCommands.award_item(item_path, int(_quantity_spin.value)))

## Grants one more equipment page. A refusal shows in the status line until a command
## works.
func _on_grant_page_pressed() -> void:
	_show_result(DevCommands.grant_equipment_page())

#-----------------------------------------------------------------------------
# PRIVATE HELPERS
#-----------------------------------------------------------------------------

## Lists each item DevCommands knows in the picker, in the order of its paths, as its
## name, or as "<name> (<file name>)" when another item has the same name. The item's
## metadata is its path.
func _fill_items() -> void:
	var paths: PackedStringArray = DevCommands.list_item_paths()
	var names := PackedStringArray()
	for path: String in paths:
		names.append((load(path) as ItemDefinitionData).item_name)
	for index: int in paths.size():
		var text: String = names[index]
		if names.count(text) > 1:
			text = "%s (%s)" % [text, paths[index].get_file()]
		_item_option.add_item(text)
		_item_option.set_item_metadata(index, paths[index])

## Shows why a command refused, under the controls, and hides the line once a command
## works (it returns "").
func _show_result(refusal: String) -> void:
	_status.text = refusal
	_status.visible = refusal != ""
