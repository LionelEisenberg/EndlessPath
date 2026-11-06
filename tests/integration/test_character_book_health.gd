extends GutTest

## Integration tests for the Character book's In a fight Health row: the saved
## pool over its max, printed as every Health readout prints it (VitalsText),
## live while the book is open. Every test runs on a fresh save at full Health,
## 100, swapped in and restored around it.

const CharacterViewScene := preload("res://scenes/character/character_view.tscn")
## The modifier source a test sets; after_each() removes it.
const TEST_SOURCE: StringName = &"test_character_book_health"

var _view: CharacterView
var _original_save: SaveGameData

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new_current()
	PersistenceManager.save_data_reset.emit()
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

func _max_health_source(amount: float) -> Callable:
	return func() -> Array[StatModifierData]:
		var modifiers: Array[StatModifierData] = [StatModifierData.new(StatModifierData.Stat.MAX_HEALTH, StatModifierData.Kind.FLAT, amount)]
		return modifiers

## The In a fight block's Health entry, found by its label.
func _health_entry() -> Dictionary:
	for line: Dictionary in CharacterView.fight_lines():
		if line.label == "Health":
			return line
	return {}

## The Health row as the open book prints it: the row of either column captioned
## "HEALTH", found by its caption; "" when no row has it.
func _health_row_text() -> String:
	for column: String in ["%FightLeftColumn", "%FightRightColumn"]:
		for row: TableRow in _view.get_node(column).get_children():
			if (row.get_node("%Label") as Label).text == "HEALTH":
				return (row.get_node("%Value") as RichTextLabel).get_parsed_text()
	return ""

## The figure rounds up and the max down, as on the cabinet and the vitals plate.
func test_the_health_line_shows_the_saved_pool() -> void:
	ResourceManager.set_health(61.3)
	assert_eq(_health_entry().get("value"), "62 / 100")

func test_the_health_row_follows_the_pool_and_its_max_while_open() -> void:
	_view.show()
	_view.refresh()
	ResourceManager.set_health(40.0)
	assert_eq(_health_row_text(), "40 / 100", "the dev panel's Set Health")
	CharacterManager.set_modifier_source(TEST_SOURCE, _max_health_source(40.0))
	assert_eq(_health_row_text(), "40 / 140", "a bonus on max Health")
