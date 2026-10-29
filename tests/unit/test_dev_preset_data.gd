extends GutTest

## The dev step, story beat, story route and save preset resources: how a step
## reads and what it applies, what it flags as wrong, how a route finds its beats
## and how a preset checks itself against the route. Steps are checked and applied
## against the real autoloads on a fresh save, as DevCommands is tested. Each test
## puts the original save and the path tree back, and starts from the real ability
## index.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const Kind = DevStepData.Kind

const ZONE_ID: String = "SpiritValley"
const OTHER_ZONE_ID: String = "TestZone"

## NPC 1 is available on a fresh save, NPC 2 is not.
const NPC_1: String = "celestial_intervener_dialogue_1"
const NPC_2: String = "celestial_intervener_dialogue_2"

const CRUDE_SCALE: String = "res://resources/items/consumables/crude_scale.tres"
const PURE_MADRA_TREE: String = "res://resources/path_progression/pure_madra/pure_madra_tree.tres"
## A resource that loads fine and is not an item.
const QUEST_FILE: String = "res://resources/quests/q_fill_core.tres"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _original_tree: PathTreeData

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_tree = PathManager.get_current_tree()
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	# test_path_manager.gd leaves a one-entry ability index behind and no tree in
	# PathManager once its trees are cleared. Start from the real ones.
	AbilityManager._build_catalog_index()
	PathManager._current_tree = load(PURE_MADRA_TREE)

func after_each() -> void:
	_stop_actions()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	PathManager._current_tree = _original_tree
	# Binding the original save again resumes its idle action, if it has one.
	# Stop it, so its tick timer does not run on into the next test.
	_stop_actions()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _stop_actions() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func _step(kind: Kind, target_id: String = "", amount: float = 0.0) -> DevStepData:
	var step := DevStepData.new()
	step.kind = kind
	step.target_id = target_id
	step.amount = amount
	return step

func _beat(beat_id: String, steps: Array = []) -> StoryBeatData:
	var beat := StoryBeatData.new()
	beat.beat_id = beat_id
	beat.title = beat_id
	beat.steps.assign(steps)
	return beat

func _route(beats: Array) -> StoryRouteData:
	var route := StoryRouteData.new()
	route.beats.assign(beats)
	return route

func _preset(preset_id: String = "a_preset", title: String = "A preset") -> SavePresetData:
	var preset := SavePresetData.new()
	preset.preset_id = preset_id
	preset.title = title
	return preset

## The target ids of the steps, in order: what a test reads to see which steps it got.
func _targets(steps: Array[DevStepData]) -> Array[String]:
	var targets: Array[String] = []
	for step: DevStepData in steps:
		targets.append(step.target_id)
	return targets

## Asserts the step gives exactly one error, which names the step and says why.
func _assert_flagged(step: DevStepData, reason: String) -> void:
	var errors: PackedStringArray = step.validate()
	assert_eq(errors.size(), 1, "%s gives one error: %s" % [step.describe(), errors])
	if errors.size() == 1:
		assert_true(errors[0].begins_with(step.describe() + ": "), "the error names the step: %s" % errors[0])
		assert_string_contains(errors[0], reason)

## Asserts the step gives no errors.
func _assert_valid(step: DevStepData) -> void:
	assert_eq(step.validate(), PackedStringArray(), "%s is a good step" % step.describe())

#-----------------------------------------------------------------------------
# THE KINDS
#-----------------------------------------------------------------------------

## The route and the presets store a step's kind as an int, so the numbers are
## fixed: a kind is appended, never inserted or renumbered. A new kind is added
## here, and gets its arms in apply(), describe() and validate().
func test_kind_numbers_never_change() -> void:
	var expected: Dictionary = {
		"COMPLETE_ACTION": 0,
		"TRIGGER_EVENT": 1,
		"REACH_CORE_DENSITY": 2,
		"SET_MADRA": 3,
		"SET_GOLD": 4,
		"BUY_PATH_NODE": 5,
		"UNLOCK_TECHNIQUE": 6,
		"EQUIP_TECHNIQUE": 7,
		"UNLOCK_ABILITY": 8,
		"EQUIP_ABILITY": 9,
		"AWARD_ITEM": 10,
		"ADVANCE_STAGE": 11,
		"TRAVEL": 12,
	}
	assert_eq(DevStepData.Kind, expected, "a step's kind is stored as an int: append only")

#-----------------------------------------------------------------------------
# DESCRIBE
#-----------------------------------------------------------------------------

func test_every_kind_describes_itself() -> void:
	for kind: int in Kind.values():
		var text: String = _step(kind as Kind, "an_id", 1.0).describe()
		assert_ne(text, "", "kind %d has a description" % kind)
		assert_false(text.begins_with("Unknown"), "kind %d is not the unknown kind: %s" % [kind, text])

#-----------------------------------------------------------------------------
# VALIDATE
#-----------------------------------------------------------------------------

## One good step of every kind, so a kind that validate() has no arm for fails here.
func test_a_good_step_validates() -> void:
	_assert_valid(_step(Kind.COMPLETE_ACTION, NPC_1))
	_assert_valid(_step(Kind.TRIGGER_EVENT, "aura_well_discovered"))
	_assert_valid(_step(Kind.REACH_CORE_DENSITY, "", 1.0))
	_assert_valid(_step(Kind.SET_MADRA, "", 100.0))
	_assert_valid(_step(Kind.SET_MADRA, "", 0.0))
	_assert_valid(_step(Kind.SET_GOLD, "", 700.0))
	_assert_valid(_step(Kind.SET_GOLD, "", 0.0))
	_assert_valid(_step(Kind.BUY_PATH_NODE, "pure_core_awakening"))
	_assert_valid(_step(Kind.UNLOCK_TECHNIQUE, "torrential_flow"))
	_assert_valid(_step(Kind.EQUIP_TECHNIQUE, "smooth_flow"))
	_assert_valid(_step(Kind.UNLOCK_ABILITY, "power_font"))
	_assert_valid(_step(Kind.EQUIP_ABILITY, "empty_palm", 1.0))
	_assert_valid(_step(Kind.EQUIP_ABILITY, "empty_palm", 3.0))
	_assert_valid(_step(Kind.EQUIP_ABILITY, "empty_palm", 4.0))
	_assert_valid(_step(Kind.AWARD_ITEM, CRUDE_SCALE, 1.0))
	_assert_valid(_step(Kind.ADVANCE_STAGE))
	_assert_valid(_step(Kind.TRAVEL, ZONE_ID))

## One assertion per rule.
func test_validate_catches_each_bad_step() -> void:
	_assert_flagged(_step(Kind.COMPLETE_ACTION, "no_such_action"), "unknown action")
	_assert_flagged(_step(Kind.TRIGGER_EVENT, "no_such_event"), "unknown event")
	_assert_flagged(_step(Kind.BUY_PATH_NODE, "no_such_node"), "not a node of")
	_assert_flagged(_step(Kind.UNLOCK_TECHNIQUE, "no_such_technique"), "unknown technique")
	_assert_flagged(_step(Kind.EQUIP_TECHNIQUE, "no_such_technique"), "unknown technique")
	_assert_flagged(_step(Kind.UNLOCK_ABILITY, "no_such_ability"), "unknown ability")
	_assert_flagged(_step(Kind.EQUIP_ABILITY, "no_such_ability", 3.0), "unknown ability")
	_assert_flagged(_step(Kind.AWARD_ITEM, "res://resources/items/no_such_item.tres", 1.0), "not an item")
	_assert_flagged(_step(Kind.AWARD_ITEM, QUEST_FILE, 1.0), "not an item")
	_assert_flagged(_step(Kind.TRAVEL, "Nowhere"), "unknown zone")
	_assert_flagged(_step(Kind.REACH_CORE_DENSITY, "", 0.0), "level")
	_assert_flagged(_step(Kind.REACH_CORE_DENSITY, "", -5.0), "level")
	_assert_flagged(_step(Kind.EQUIP_ABILITY, "empty_palm", 0.0), "slot")
	_assert_flagged(_step(Kind.EQUIP_ABILITY, "empty_palm", 5.0), "slot")
	_assert_flagged(_step(Kind.AWARD_ITEM, CRUDE_SCALE, 0.0), "quantity")
	_assert_flagged(_step(Kind.AWARD_ITEM, CRUDE_SCALE, -2.0), "quantity")
	_assert_flagged(_step(Kind.SET_MADRA, "", -1.0), "Madra")
	_assert_flagged(_step(Kind.SET_GOLD, "", -1.0), "gold")

## The path node check reads the current tree, which can be missing: it says so.
func test_a_path_node_step_without_a_tree_says_so() -> void:
	PathManager._current_tree = null
	_assert_flagged(_step(Kind.BUY_PATH_NODE, "pure_core_awakening"), "no current path tree")

func test_a_step_reports_every_problem_it_has() -> void:
	var step: DevStepData = _step(Kind.AWARD_ITEM, "res://resources/items/no_such_item.tres", 0.0)
	assert_eq(step.validate().size(), 2, "a bad path and a bad quantity: %s" % step.validate())

func test_an_unknown_kind_is_flagged_and_refused() -> void:
	var step: DevStepData = _step(99 as Kind)
	_assert_flagged(step, "no such step kind")
	assert_ne(step.apply(), "", "applying it refuses")
	assert_ne(step.describe(), "")

#-----------------------------------------------------------------------------
# APPLY
#-----------------------------------------------------------------------------

func test_apply_dispatches_to_the_command() -> void:
	assert_eq(_step(Kind.SET_GOLD, "", 700.0).apply(), "")
	assert_eq(ResourceManager.get_gold(), 700.0)

## apply() hands back the command's reason for refusing, and the command did nothing.
func test_apply_returns_the_commands_refusal() -> void:
	var reason: String = _step(Kind.COMPLETE_ACTION, NPC_2).apply()
	assert_string_contains(reason, "not available")
	assert_eq(ZoneManager.get_zone_progression(ZONE_ID).action_completion_count.get(NPC_2, 0), 0, "nothing was counted")

## The route and the presets exercise the other kinds (the route's coverage test
## and the preset build test apply them), so these four are checked here.
func test_the_kinds_the_route_does_not_use_apply() -> void:
	assert_false(CyclingManager.is_technique_unlocked("torrential_flow"), "precondition: locked on a fresh save")
	assert_eq(_step(Kind.UNLOCK_TECHNIQUE, "torrential_flow").apply(), "")
	assert_true(CyclingManager.is_technique_unlocked("torrential_flow"))

	assert_false(AbilityManager.is_ability_unlocked("power_font"), "precondition: locked on a fresh save")
	assert_eq(_step(Kind.UNLOCK_ABILITY, "power_font").apply(), "")
	assert_true(AbilityManager.is_ability_unlocked("power_font"))

	assert_eq(_step(Kind.AWARD_ITEM, CRUDE_SCALE, 2.0).apply(), "")
	var crude_scale: ConsumableDefinitionData = load(CRUDE_SCALE)
	assert_eq(InventoryManager.get_inventory().consumables.get(crude_scale), 2, "the amount is the quantity")

	assert_eq(DevCommands.travel_to_zone(OTHER_ZONE_ID), "", "precondition: standing in another zone")
	assert_eq(_step(Kind.TRAVEL, ZONE_ID).apply(), "")
	assert_eq(ZoneManager.get_current_zone().zone_id, ZONE_ID)

#-----------------------------------------------------------------------------
# THE ROUTE: FINDING BEATS AND STEPS
#-----------------------------------------------------------------------------

func test_find_beat_finds_a_beat_by_id() -> void:
	var second: StoryBeatData = _beat("second")
	var route: StoryRouteData = _route([_beat("first"), second])
	assert_eq(route.find_beat("second"), second)
	assert_null(route.find_beat("third"), "a beat the route lacks")

## "" means no beat, even in a route that (wrongly) holds a beat with no id.
func test_find_beat_never_finds_a_beat_by_an_empty_id() -> void:
	var route: StoryRouteData = _route([_beat("", [_step(Kind.COMPLETE_ACTION, "a1")]), _beat("second")])
	assert_null(route.find_beat(""))
	assert_true(route.steps_through("").is_empty(), "so no beat's steps are taken for it")

func test_steps_through_includes_earlier_beats_in_order() -> void:
	var route: StoryRouteData = _route([
		_beat("first", [_step(Kind.COMPLETE_ACTION, "a1"), _step(Kind.COMPLETE_ACTION, "a2")]),
		_beat("second", [_step(Kind.COMPLETE_ACTION, "b1")]),
		_beat("third", [_step(Kind.COMPLETE_ACTION, "c1"), _step(Kind.COMPLETE_ACTION, "c2")]),
	])
	assert_eq(_targets(route.steps_through("first")), ["a1", "a2"] as Array[String])
	assert_eq(_targets(route.steps_through("second")), ["a1", "a2", "b1"] as Array[String])
	assert_eq(_targets(route.steps_through("third")), ["a1", "a2", "b1", "c1", "c2"] as Array[String])

func test_steps_through_nothing() -> void:
	var route: StoryRouteData = _route([_beat("first", [_step(Kind.COMPLETE_ACTION, "a1")])])
	assert_true(route.steps_through("").is_empty(), "no beat named: no steps")
	assert_true(route.steps_through("no_such_beat").is_empty(), "a beat the route lacks: no steps, not the whole route")

#-----------------------------------------------------------------------------
# THE ROUTE: VALIDATE
#-----------------------------------------------------------------------------

func test_a_good_route_validates() -> void:
	var route: StoryRouteData = _route([
		_beat("first", [_step(Kind.COMPLETE_ACTION, NPC_1), _step(Kind.SET_MADRA, "", 100.0)]),
		_beat("second", [_step(Kind.TRIGGER_EVENT, "aura_well_discovered")]),
	])
	route.optional_quest_ids.assign(["q_first_steps"])
	route.excluded_action_ids.assign([NPC_2])
	assert_eq(route.validate(), PackedStringArray())

func test_route_validate_catches_duplicate_beats() -> void:
	var route: StoryRouteData = _route([_beat("beat_a"), _beat("beat_b"), _beat("beat_a")])
	var errors: PackedStringArray = route.validate()
	assert_eq(errors.size(), 1, "one beat repeats an id: %s" % errors)
	if errors.size() == 1:
		assert_string_contains(errors[0], "beat_a")

func test_route_validate_catches_a_beat_with_no_id() -> void:
	var route: StoryRouteData = _route([_beat("beat_a"), _beat("")])
	var errors: PackedStringArray = route.validate()
	assert_eq(errors.size(), 1, "the second beat has no id: %s" % errors)
	if errors.size() == 1:
		assert_string_contains(errors[0], "no beat_id")

func test_route_validate_catches_an_unknown_quest_or_action() -> void:
	var route: StoryRouteData = _route([_beat("beat_a")])
	route.optional_quest_ids.assign(["q_first_steps", "no_such_quest"])
	route.excluded_action_ids.assign([NPC_2, "no_such_action"])
	var errors: PackedStringArray = route.validate()
	assert_eq(errors.size(), 2, "one unknown quest and one unknown action: %s" % errors)
	if errors.size() == 2:
		assert_string_contains(errors[0], "no_such_quest")
		assert_string_contains(errors[1], "no_such_action")

func test_route_validate_prefixes_step_errors_with_the_beat() -> void:
	var route: StoryRouteData = _route([
		_beat("beat_a", [_step(Kind.COMPLETE_ACTION, NPC_1)]),
		_beat("beat_b", [_step(Kind.SET_MADRA, "", 5.0), _step(Kind.COMPLETE_ACTION, "no_such_action")]),
	])
	var errors: PackedStringArray = route.validate()
	assert_eq(errors.size(), 1, "one bad step, in the second beat: %s" % errors)
	if errors.size() == 1:
		assert_true(errors[0].begins_with("beat_b: "), "the error starts with its beat: %s" % errors[0])
		assert_string_contains(errors[0], "no_such_action")

#-----------------------------------------------------------------------------
# THE PRESET: VALIDATE
#-----------------------------------------------------------------------------

func test_a_good_preset_validates() -> void:
	var route: StoryRouteData = _route([_beat("beat_a", [_step(Kind.COMPLETE_ACTION, NPC_1)])])
	var recipe: SavePresetData = _preset()
	recipe.story_through = "beat_a"
	recipe.steps.assign([_step(Kind.SET_GOLD, "", 700.0)])
	assert_eq(recipe.validate(route), PackedStringArray(), "a recipe preset")
	var from_a_fresh_start: SavePresetData = _preset()
	assert_eq(from_a_fresh_start.validate(route), PackedStringArray(), "no story_through is a fresh start")
	var from_a_snapshot: SavePresetData = _preset()
	from_a_snapshot.snapshot = SaveGameData.new_current()
	assert_eq(from_a_snapshot.validate(route), PackedStringArray(), "a snapshot of this build")
	from_a_snapshot.snapshot = SaveGameData.new()
	assert_eq(from_a_snapshot.validate(route), PackedStringArray(), "an older, unversioned snapshot migrates, so it is fine")

func test_preset_validate_catches_a_missing_id_and_title() -> void:
	var route: StoryRouteData = _route([_beat("beat_a")])
	var errors: PackedStringArray = _preset("", "").validate(route)
	assert_eq(errors.size(), 2, "no id and no title: %s" % errors)
	if errors.size() == 2:
		assert_string_contains(errors[0], "preset_id")
		assert_string_contains(errors[1], "title")

func test_preset_validate_catches_an_unknown_beat() -> void:
	var route: StoryRouteData = _route([_beat("beat_a")])
	var preset: SavePresetData = _preset()
	preset.story_through = "no_such_beat"
	var errors: PackedStringArray = preset.validate(route)
	assert_eq(errors.size(), 1, "the route has no such beat: %s" % errors)
	if errors.size() == 1:
		assert_string_contains(errors[0], "no_such_beat")
	assert_eq(preset.validate(null).size(), 1, "with no route at all, the beat is just as unknown")

func test_preset_validate_reports_its_step_errors() -> void:
	var preset: SavePresetData = _preset()
	preset.steps.assign([_step(Kind.SET_GOLD, "", 700.0), _step(Kind.SET_GOLD, "", -1.0)])
	var errors: PackedStringArray = preset.validate(_route([]))
	assert_eq(errors.size(), 1, "the second step is bad: %s" % errors)
	if errors.size() == 1:
		assert_string_contains(errors[0], "gold")

func test_preset_validate_catches_a_snapshot_from_a_newer_build() -> void:
	var preset: SavePresetData = _preset()
	preset.snapshot = SaveGameData.new_current()
	preset.snapshot.save_version = SaveGameData.CURRENT_VERSION + 1
	var errors: PackedStringArray = preset.validate(_route([]))
	assert_eq(errors.size(), 1, "this build cannot read a newer save: %s" % errors)
	if errors.size() == 1:
		assert_string_contains(errors[0], "newer build")
