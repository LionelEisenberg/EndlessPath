extends GutTest

## Unit tests for the data the cycling view's technique drawers read: the icon on
## every technique in the catalog, the Madra a second of drawing pays, and the
## SaveGameData fields that remember which techniques the player has already seen.

const TECHNIQUE_LIST_PATH: String = "res://resources/cycling/cycling_techniques/cycling_technique_list.tres"
const TMP_SAVE_PATH: String = "user://test_seen_techniques.tres"

## The icons are 16 art px, shown at 32.
const TECH_ICON_SIZE: Vector2 = Vector2(32, 32)

## Each shipped technique's id and the icon it must point at.
const ICON_PATHS_BY_ID: Dictionary[String, String] = {
	"foundation_technique": "res://assets/ui/lacquer/icons/lacquer_ic_tech_foundation_ai.png",
	"smooth_flow": "res://assets/ui/lacquer/icons/lacquer_ic_tech_smooth_ai.png",
	"torrential_flow": "res://assets/ui/lacquer/icons/lacquer_ic_tech_torrent_ai.png",
}

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The shipped technique catalog. Fails the test and returns null when it won't load.
func _load_catalog() -> CyclingTechniqueList:
	var catalog: CyclingTechniqueList = load(TECHNIQUE_LIST_PATH) as CyclingTechniqueList
	assert_not_null(catalog, "the technique catalog loads")
	return catalog

## The resource path of the icon the catalog's technique `technique_id` points at, or
## "" when the catalog has no such technique or the technique has no icon.
func _icon_path_of(technique_id: String) -> String:
	var catalog: CyclingTechniqueList = _load_catalog()
	if catalog == null:
		return ""
	for technique: CyclingTechniqueData in catalog.cycling_techniques:
		if technique.id == technique_id and technique.icon != null:
			return technique.icon.resource_path
	return ""

#-----------------------------------------------------------------------------
# TECHNIQUE ICONS
#-----------------------------------------------------------------------------

func test_every_catalog_technique_has_an_icon() -> void:
	var catalog: CyclingTechniqueList = _load_catalog()
	if catalog == null:
		return
	assert_gt(catalog.cycling_techniques.size(), 0, "the catalog lists techniques")
	for technique: CyclingTechniqueData in catalog.cycling_techniques:
		assert_not_null(technique.icon, "%s has an icon" % technique.id)
		if technique.icon != null:
			assert_eq(technique.icon.get_size(), TECH_ICON_SIZE, "%s icon size" % technique.id)

func test_icons_match_the_techniques() -> void:
	for technique_id: String in ICON_PATHS_BY_ID:
		assert_eq(_icon_path_of(technique_id), ICON_PATHS_BY_ID[technique_id], "%s icon" % technique_id)

#-----------------------------------------------------------------------------
# MADRA PER SECOND
#-----------------------------------------------------------------------------

func test_madra_per_second_spreads_the_cycles_madra_over_its_seconds() -> void:
	var technique := CyclingTechniqueData.new()
	technique.base_madra_per_cycle = 200.0
	technique.cycle_duration = 15.0
	assert_almost_eq(technique.get_madra_per_second(), 200.0 / 15.0, 0.0001)

func test_a_cycle_of_no_length_pays_no_madra_per_second() -> void:
	var technique := CyclingTechniqueData.new()
	technique.base_madra_per_cycle = 200.0
	technique.cycle_duration = 0.0
	assert_eq(technique.get_madra_per_second(), 0.0)

#-----------------------------------------------------------------------------
# SEEN TECHNIQUES IN THE SAVE
#-----------------------------------------------------------------------------

func test_reset_clears_seen_techniques() -> void:
	var data := SaveGameData.new()
	data.seen_cycling_technique_ids.append("smooth_flow")
	data.seen_cycling_techniques_initialized = true
	data.reset()
	assert_eq(data.seen_cycling_technique_ids, [] as Array[String], "reset forgets the seen techniques")
	assert_false(data.seen_cycling_techniques_initialized, "reset needs the first pass again")

func test_seen_techniques_survive_a_save() -> void:
	var data := SaveGameData.new()
	data.seen_cycling_technique_ids.append("smooth_flow")
	data.seen_cycling_technique_ids.append("torrential_flow")
	data.seen_cycling_techniques_initialized = true

	var save_error: Error = ResourceSaver.save(data, TMP_SAVE_PATH)
	var loaded: SaveGameData = null
	if save_error == OK:
		loaded = ResourceLoader.load(TMP_SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGameData
	# The file has done its job; remove it before the asserts so no failure leaves it behind.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE_PATH))

	assert_eq(save_error, OK, "the save is written")
	assert_not_null(loaded, "the save loads back as a SaveGameData")
	if loaded == null:
		return
	assert_eq(loaded.seen_cycling_technique_ids, data.seen_cycling_technique_ids, "the seen techniques are saved")
	assert_true(loaded.seen_cycling_techniques_initialized, "the first-pass flag is saved")
