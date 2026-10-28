extends GutTest

## MaterialSources (spec: Data the tabs read): where a material is gathered.
## Only sources the player can already see are listed: activities they have
## unlocked, in zones the map shows them. Today the only one is Spring Forest
## Foraging in Spirit Valley, which unlocks when "Awaken Your Core" completes.

const SPIRIT_FERN_PATH: String = "res://resources/items/materials/spirit_fern.tres"
const DEWDROP_TEAR_PATH: String = "res://resources/items/materials/dewdrop_tear.tres"
## The condition Spring Forest Foraging unlocks on.
const FORAGING_UNLOCK_ID: String = "q_fill_core_completed"

var _saved_save: SaveGameData = null

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

func before_each() -> void:
	_saved_save = PersistenceManager.save_game_data
	_use_save(SaveGameData.new())

func after_each() -> void:
	_use_save(_saved_save)

## Swaps in `save` and tells the managers to re-bind, as a fresh save does.
func _use_save(save: SaveGameData) -> void:
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()

func _unlock_foraging() -> void:
	PersistenceManager.save_game_data.unlock_progression.unlocked_condition_ids.append(FORAGING_UNLOCK_ID)

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_spirit_fern_comes_from_spring_forest_foraging_once_unlocked() -> void:
	_unlock_foraging()
	var sources: Array[MaterialSources.Source] = MaterialSources.find(load(SPIRIT_FERN_PATH))
	assert_eq(sources.size(), 1)
	assert_eq(sources[0].activity_name, "Spring Forest Foraging")
	assert_eq(sources[0].zone_name, "Spirit Valley")
	assert_eq([sources[0].min_quantity, sources[0].max_quantity], [2, 6])
	assert_eq(sources[0].interval_seconds, 5.0)

func test_dewdrop_yields_one_to_five() -> void:
	_unlock_foraging()
	var sources: Array[MaterialSources.Source] = MaterialSources.find(load(DEWDROP_TEAR_PATH))
	assert_eq(sources.size(), 1)
	assert_eq(sources[0].activity_name, "Spring Forest Foraging")
	assert_eq([sources[0].min_quantity, sources[0].max_quantity], [1, 5])

func test_locked_activities_are_not_listed() -> void:
	assert_eq(MaterialSources.find(load(SPIRIT_FERN_PATH)).size(), 0)

func test_sources_match_the_item_id() -> void:
	_unlock_foraging()
	var same_id: MaterialDefinitionData = MaterialDefinitionData.new()
	same_id.item_id = "SpiritFern"
	assert_eq(MaterialSources.find(same_id).size(), 1, "a loot entry names its item by id")
	var unknown: MaterialDefinitionData = MaterialDefinitionData.new()
	unknown.item_id = "moon_moss"
	assert_eq(MaterialSources.find(unknown).size(), 0, "no loot table lists it")

func test_zone_names_list_each_zone_once() -> void:
	_unlock_foraging()
	assert_eq(MaterialSources.zone_names(load(SPIRIT_FERN_PATH)), ["Spirit Valley"] as Array[String])

func test_zone_names_are_empty_while_nothing_yields_it() -> void:
	assert_eq(MaterialSources.zone_names(load(SPIRIT_FERN_PATH)), [] as Array[String], "foraging is still locked")
	assert_eq(MaterialSources.zone_names(null), [] as Array[String])
