extends GutTest

## Integration tests for the Character book's In a fight Madra row: the saved
## pool over its max, live while the book is open. Every test runs on a fresh
## save holding 25 Madra, swapped in and restored around it.

const CharacterViewScene := preload("res://scenes/character/character_view.tscn")
## The modifier source a test sets; after_each() removes it.
const TEST_SOURCE: StringName = &"test_character_book_madra"

var _view: CharacterView
var _original_save: SaveGameData

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new_current()
	PersistenceManager.save_data_reset.emit()
	ResourceManager.set_madra(25.0)
	# Other suites replace the catalog index with fakes; start from the real one.
	AbilityManager._build_catalog_index()
	_view = CharacterViewScene.instantiate() as CharacterView
	add_child_autofree(_view)

func after_each() -> void:
	CharacterManager.remove_modifier_source(TEST_SOURCE)
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func _max_madra_source(amount: float) -> Callable:
	return func() -> Array[StatModifierData]:
		var modifiers: Array[StatModifierData] = [StatModifierData.new(StatModifierData.Stat.MAX_MADRA, StatModifierData.Kind.FLAT, amount)]
		return modifiers

## The In a fight block's Madra entry, found by its label.
func _madra_entry() -> Dictionary:
	for line: Dictionary in CharacterView.fight_lines():
		if line.label == "Madra":
			return line
	return {}

## The Madra row as the open book prints it: the row of either column captioned
## "MADRA", found by its caption; "" when no row has it.
func _madra_row_text() -> String:
	for column: String in ["%FightLeftColumn", "%FightRightColumn"]:
		for row: TableRow in _view.get_node(column).get_children():
			if (row.get_node("%Label") as Label).text == "MADRA":
				return (row.get_node("%Value") as RichTextLabel).get_parsed_text()
	return ""

func test_the_madra_line_shows_the_pool_over_its_max() -> void:
	ResourceManager.set_madra(46.0)
	assert_eq(_madra_entry().get("value"), "46 / 100")

func test_the_madra_row_follows_the_pool_and_its_max_while_open() -> void:
	_view.show()
	_view.refresh()
	ResourceManager.add_madra(1.5, true)
	assert_eq(_madra_row_text(), "26 / 100", "the Aura Well's trickle: 25 + 1.5")
	CharacterManager.set_modifier_source(TEST_SOURCE, _max_madra_source(50.0))
	assert_eq(_madra_row_text(), "26 / 150", "a bonus on max Madra")
