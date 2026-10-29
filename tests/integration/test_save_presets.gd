extends GutTest

## The starting presets (resources/dev/save_presets/), "Save this game as a preset" and
## the pin, against the real managers. The shipped presets are read from their own
## folder (_use_shipped_presets(): preset_dir_override at DevManager.PRESET_DIR, so a
## preset an exported build keeps in user:// is never read): each must validate against
## the route and build on a fresh save, and the ones the spec names must land where it
## says. Every test starts with preset_dir_override at a temp folder, so a save can
## never reach the repository's folder. The pin test points
## LaunchOptions.pin_path_override at a temp file, never the checkout's
## .dev_settings.cfg.
##
## Each test binds a fresh in-memory save, starts from the real path tree, ability
## index, quest catalog and stages (other files swap in stubs), and gives everything it
## changed back afterwards: the save, the stages, the player's log, the preset folder
## and the pin file.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const Stage := CultivationManager.AdvancementStage

const PURE_MADRA_TREE: String = "res://resources/path_progression/pure_madra/pure_madra_tree.tres"
const QUEST_LIST: String = "res://resources/quests/quest_list.tres"
const FOUNDATION_STAGE: String = "res://resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres"
const COPPER_STAGE: String = "res://resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres"

## A consumable, a material and a piece of equipment: the inventory keys each by the
## shared item resource, which a snapshot has to carry.
const CRUDE_SCALE: String = "res://resources/items/consumables/crude_scale.tres"
const SPIRIT_FERN: String = "res://resources/items/materials/spirit_fern.tres"
const IRON_SHORTSWORD: String = "res://resources/items/equipment/spirit_valley/iron_shortsword.tres"

## The folder "Save this game as a preset" writes to in these tests. after_each()
## deletes it.
const SAVED_PRESET_DIR: String = "user://__test_save_presets/"
## A save file the snapshot test plays a game back from. after_each() deletes it.
const SESSION_SAVE_PATH: String = "user://__test_save_presets_session.tres"
## The pin file the pin test writes. after_each() deletes it.
const PIN_PATH: String = "user://__test_save_presets_pin.cfg"

## Offered once the core is full, and gone once the Tribulation is passed.
const TRIBULATION_ACTION: String = "spirit_valley_tribulation"
## Opens once merchant_discovered fires, the last step of beat_3b.
const MERCHANT_ACTION: String = "spirit_valley_merchant"

## The starting presets the spec names: each id with the beat it starts through ("" for
## none).
const STARTING_PRESETS: Dictionary = {
	"fresh": {"story_through": ""},
	"adventure_open": {"story_through": "beat_1"},
	"path_open": {"story_through": "beat_2"},
	"merchant_open": {"story_through": "beat_3b"},
	"tribulation_ready": {"story_through": "beat_9_ready"},
	"copper": {"story_through": "beat_9"},
}

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _original_save_path: String
var _original_tree: PathTreeData
var _original_stage_override: int
var _original_stages: Array[AdvancementStageResource]
var _original_history: Array[String]
var _original_preset_dir_override: String
var _original_pin_path_override: String

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_save_path = PersistenceManager.save_path
	_original_tree = PathManager.get_current_tree()
	_original_stage_override = PathManager._test_stage_override
	_original_stages = CultivationManager.advancement_stage_resources
	_original_history = LogManager._history.duplicate()
	_original_preset_dir_override = DevManager.preset_dir_override
	_original_pin_path_override = LaunchOptions.pin_path_override
	ActionManager.cancel_current_action()
	PersistenceManager.use_save(SaveGameData.new_current(), "")
	# The real state, whatever an earlier file left behind (as test_story_route.gd
	# does). The tree comes after the save, since binding a save drops the tree and
	# picks it up again from the trees PathManager holds. The override at -1 makes
	# PathManager read the player's stage.
	PathManager._current_tree = load(PURE_MADRA_TREE)
	PathManager._test_stage_override = -1
	AbilityManager._build_catalog_index()
	QuestManager._quest_catalog = load(QUEST_LIST)
	QuestManager._build_catalog_index()
	var stages: Array[AdvancementStageResource] = []
	stages.append(load(FOUNDATION_STAGE))
	stages.append(load(COPPER_STAGE))
	CultivationManager.advancement_stage_resources = stages
	# Where a save lands unless a test says otherwise: never the repository's folder.
	_use_temp_preset_dir()

func after_each() -> void:
	ActionManager.cancel_current_action()
	CultivationManager.advancement_stage_resources = _original_stages
	PersistenceManager.use_save(_original_save, _original_save_path)
	PathManager._current_tree = _original_tree
	PathManager._test_stage_override = _original_stage_override
	LogManager._history = _original_history
	DevManager.preset_dir_override = _original_preset_dir_override
	LaunchOptions.pin_path_override = _original_pin_path_override
	# Binding the original save again resumes its idle action, if it has one.
	# Stop it, so its tick timer does not run on into the next test.
	ActionManager.cancel_current_action()
	_remove_temp_files()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Builds the shipped preset on a fresh session, asserting that it is there and that it
## builds. True when it built. It leaves the preset list on the shipped folder.
func _build_shipped(preset_id: String) -> bool:
	_use_shipped_presets()
	var preset: SavePresetData = DevManager.find_preset(preset_id)
	assert_not_null(preset, "%s is in the preset folder" % preset_id)
	if preset == null:
		return false
	var failure: String = DevManager.build_preset(preset)
	assert_eq(failure, "", "%s builds" % preset_id)
	return failure == ""

## Points "Save this game as a preset", and the preset list, at the temp folder.
func _use_temp_preset_dir() -> void:
	DevManager.preset_dir_override = SAVED_PRESET_DIR

## Points the preset list at the repository's folder, the presets the game ships. A
## save made while it is set would land there, so no test saves before it points back
## with _use_temp_preset_dir().
func _use_shipped_presets() -> void:
	DevManager.preset_dir_override = DevManager.PRESET_DIR

## True when some zone offers the action right now.
func _is_available(action_id: String) -> bool:
	for zone: ZoneData in ZoneManager.get_all_zones():
		for action: ZoneActionData in ZoneManager.get_available_actions(zone.zone_id):
			if action.action_id == action_id:
				return true
	return false

## The inventory as item id → how many: stacks of materials, quest items and
## consumables, and one per piece of equipment, in the grid or worn.
func _inventory_counts() -> Dictionary:
	var counts: Dictionary = {}
	var inventory: InventoryData = InventoryManager.get_inventory()
	for stacks: Dictionary in [inventory.materials, inventory.quest_items, inventory.consumables]:
		for item: ItemDefinitionData in stacks:
			counts[item.item_id] = counts.get(item.item_id, 0) + int(stacks[item])
	for pieces: Dictionary in [inventory.equipment, inventory.equipped_gear, inventory.equipped_accessories]:
		for key: Variant in pieces:
			var piece: ItemInstanceData = pieces[key]
			if piece != null and piece.item_definition != null:
				counts[piece.item_definition.item_id] = counts.get(piece.item_definition.item_id, 0) + 1
	return counts

## What the managers hold of the story and the inventory, read through their public
## functions.
func _story_and_inventory() -> Dictionary:
	return {
		"core_density_level": CultivationManager.get_core_density_level(),
		"stage": CultivationManager.get_current_advancement_stage(),
		"gold": ResourceManager.get_gold(),
		"completed_quests": QuestManager.get_completed_quest_ids(),
		"triggered_events": EventManager.get_triggered_events(),
		"merchant_open": _is_available(MERCHANT_ACTION),
		"inventory": _inventory_counts(),
	}

func _remove_temp_files() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SAVED_PRESET_DIR)):
		for file_name: String in DirAccess.get_files_at(SAVED_PRESET_DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED_PRESET_DIR + file_name))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED_PRESET_DIR))
	for path: String in [SESSION_SAVE_PATH, PIN_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

#-----------------------------------------------------------------------------
# THE STARTING PRESETS
#-----------------------------------------------------------------------------

func test_the_starting_presets_exist() -> void:
	_use_shipped_presets()
	for preset_id: String in STARTING_PRESETS:
		assert_not_null(DevManager.find_preset(preset_id), "%s is in the preset folder" % preset_id)

## The spec fixes each preset's beat, so the panel and a launch start where it says.
func test_the_starting_presets_start_where_the_spec_says() -> void:
	_use_shipped_presets()
	for preset_id: String in STARTING_PRESETS:
		var preset: SavePresetData = DevManager.find_preset(preset_id)
		if preset == null:
			continue
		assert_eq(preset.story_through, STARTING_PRESETS[preset_id]["story_through"], "%s: the beat it starts through" % preset_id)

## Every preset in the folder, a committed snapshot included: a content or format
## change that breaks one fails here and not at the next launch.
func test_every_preset_validates_and_builds() -> void:
	_use_shipped_presets()
	var route: StoryRouteData = DevManager.get_route()
	var presets: Array[SavePresetData] = DevManager.get_presets()
	assert_gte(presets.size(), STARTING_PRESETS.size(), "precondition: the folder holds the starting presets, so the loop below runs")
	for preset: SavePresetData in presets:
		assert_eq(preset.validate(route), PackedStringArray(), "%s validates" % preset.preset_id)
		assert_eq(DevManager.build_preset(preset), "", "%s builds" % preset.preset_id)

func test_tribulation_ready_has_a_full_core() -> void:
	if not _build_shipped("tribulation_ready"):
		return
	assert_eq(CultivationManager.get_core_density_level(), 100.0, "Core Density is 100")
	assert_true(CultivationManager.is_core_full(), "the core is full")
	assert_true(_is_available(TRIBULATION_ACTION), "the Tribulation waits")

func test_copper_is_copper() -> void:
	if not _build_shipped("copper"):
		return
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.COPPER, "the stage is Copper")
	assert_false(_is_available(TRIBULATION_ACTION), "the Tribulation is passed, so it is not offered again")

func test_merchant_open_has_the_merchant_and_700_gold() -> void:
	if not _build_shipped("merchant_open"):
		return
	assert_true(_is_available(MERCHANT_ACTION), "the Traveling Merchant is in Spirit Valley")
	assert_eq(ResourceManager.get_gold(), 700.0, "with gold for every piece")

#-----------------------------------------------------------------------------
# SAVE THIS GAME AS A PRESET
#-----------------------------------------------------------------------------

func test_save_as_preset_round_trips() -> void:
	_use_temp_preset_dir()
	ResourceManager.set_gold(321.0)
	assert_eq(DevManager.save_as_preset("Round trip", "Gold 321."), "", "the preset is written")
	var preset: SavePresetData = DevManager.find_preset("round_trip")
	assert_not_null(preset, "the saved file loads as a preset")
	if preset == null:
		return
	assert_eq(preset.title, "Round trip")
	assert_eq(preset.description, "Gold 321.")
	assert_eq(preset.validate(DevManager.get_route()), PackedStringArray(), "it validates, so the panel can play it")
	ResourceManager.set_gold(5.0)
	assert_eq(DevManager.build_preset(preset), "", "it builds")
	assert_eq(ResourceManager.get_gold(), 321.0, "on the game as it was saved, not the one it is built over")

## A snapshot is for the states no recipe describes. Here a game that has the story
## through the merchant, and an inventory with each kind of item in it, comes back whole
## from a preset built on another game: the inventory keys its stacks by the shared item
## resources, which the copy and the file have to keep as the cached ones. The game
## saved is one played back from a file, as a developer's own save is: its sub-resources
## are built into that file, which the copy must not share with the session.
func test_save_as_preset_keeps_the_story_and_the_inventory() -> void:
	if not _build_shipped("merchant_open"):
		return
	assert_eq(DevCommands.award_item(CRUDE_SCALE, 3), "", "precondition: a consumable is awarded")
	assert_eq(DevCommands.award_item(SPIRIT_FERN, 2), "", "precondition: a material is awarded")
	assert_eq(DevCommands.award_item(IRON_SHORTSWORD, 1), "", "precondition: a piece of equipment is awarded")
	assert_eq(SaveFiles.write_atomically(PersistenceManager.save_game_data, SESSION_SAVE_PATH), OK, "precondition: the game is written to a file")
	var loaded: SaveGameData = SaveFiles.load_save(SESSION_SAVE_PATH)
	assert_not_null(loaded, "precondition: the file loads")
	if loaded == null:
		return
	PersistenceManager.use_save(loaded, "")
	var saved: Dictionary = _story_and_inventory()
	_use_temp_preset_dir()
	assert_eq(DevManager.save_as_preset("Odd state", ""), "", "the preset is written")
	var preset: SavePresetData = DevManager.find_preset("odd_state")
	assert_not_null(preset, "the saved file loads as a preset")
	if preset == null:
		return

	PersistenceManager.use_save(SaveGameData.new_current(), "")
	assert_ne(_story_and_inventory(), saved, "precondition: the game moved on to a fresh one")
	assert_eq(DevManager.build_preset(preset), "", "the snapshot builds")
	assert_eq_deep(_story_and_inventory(), saved)

func test_save_as_preset_refuses_an_empty_title() -> void:
	_use_temp_preset_dir()
	for title: String in ["", "   ", "#!?"]:
		var refusal: String = DevManager.save_as_preset(title, "Nothing to name it by.")
		assert_ne(refusal, "", "'%s' makes no id to save under, so it is refused" % title)
	assert_true(DevManager.get_presets().is_empty(), "nothing is written")

func test_save_as_preset_refuses_a_taken_id() -> void:
	_use_temp_preset_dir()
	ResourceManager.set_gold(10.0)
	assert_eq(DevManager.save_as_preset("Taken", "The first."), "", "precondition: the first preset is written")
	ResourceManager.set_gold(20.0)
	var refusal: String = DevManager.save_as_preset("TAKEN!", "The second.")
	assert_string_contains(refusal, "taken", "another title that makes the same id is refused, and the refusal names the id")
	assert_eq(DevManager.get_presets().size(), 1, "no second file is written")
	var kept: SavePresetData = DevManager.find_preset("taken")
	assert_not_null(kept, "the first preset is still there")
	if kept == null:
		return
	assert_eq(kept.description, "The first.", "the first preset is not overwritten")
	assert_not_null(kept.snapshot, "and still embeds the game it was saved from")
	if kept.snapshot != null:
		assert_eq(kept.snapshot.gold, 10.0, "which is the game at the time, not the later one")

func test_save_as_preset_slug() -> void:
	_use_temp_preset_dir()
	assert_eq(DevManager.save_as_preset("Weird State #2!", ""), "", "the preset is written")
	var preset: SavePresetData = DevManager.find_preset("weird_state_2")
	assert_not_null(preset, "the id is the title lowercased, each run of characters outside a-z and 0-9 turned into _")
	if preset != null:
		assert_eq(preset.title, "Weird State #2!", "the title stays as it was typed")
	assert_true(FileAccess.file_exists(SAVED_PRESET_DIR + "weird_state_2.tres"), "the file is named after the id")
	assert_eq(DevManager.save_as_preset("  --Tidy   up--  ", ""), "", "a second title is written")
	assert_not_null(DevManager.find_preset("tidy_up"), "_ is trimmed from both ends, and a run of characters makes one _")

## A run from the editor binary saves into the repository's folder, so the new file shows
## in git status; an exported build saves into user://, and a test points the folder at a
## temp one. Only the folder is read here: nothing is written.
func test_an_editor_run_saves_into_the_repository_folder() -> void:
	DevManager.preset_dir_override = ""
	assert_true(OS.has_feature("editor"), "precondition: the suite runs on the editor binary")
	assert_eq(DevManager._preset_save_folder(), DevManager.PRESET_DIR)
	_use_temp_preset_dir()
	assert_eq(DevManager._preset_save_folder(), SAVED_PRESET_DIR, "a test's folder replaces it")

#-----------------------------------------------------------------------------
# THE PIN
#-----------------------------------------------------------------------------

func test_pin_round_trips() -> void:
	LaunchOptions.pin_path_override = PIN_PATH
	assert_eq(DevManager.get_pinned_preset_id(), "", "nothing is pinned yet")
	assert_eq(DevManager.pin_preset("merchant_open"), OK, "the pin is written")
	assert_eq(DevManager.get_pinned_preset_id(), "merchant_open")
	assert_eq(DevManager.pin_preset("copper"), OK, "another pin replaces it")
	assert_eq(DevManager.get_pinned_preset_id(), "copper")
	assert_eq(DevManager.pin_preset(""), OK, "an empty id unpins")
	assert_eq(DevManager.get_pinned_preset_id(), "")
