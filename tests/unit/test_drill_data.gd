extends GutTest

## Content tests for the drill catalog (resources/body_refining/drills/): each
## drill trains Strength and at most one other Physical stat, ids are unique,
## every value is written out in its file (its words and icon too), and the roster
## holds the numbers the "Body refining drills" canvas approved.

const AttributeType = CharacterAttributesData.AttributeType

const DRILL_LIST_PATH: String = "res://resources/body_refining/drills/drill_list.tres"

## Every field a drill file writes out.
const WRITTEN_FIELDS: Array[String] = [
	"id", "drill_name", "icon", "minor_stat", "strength_xp_per_rep", "minor_xp_per_rep",
	"health_per_rep", "input_kind", "rep_seconds", "reps_per_set", "play_hint",
	"ready_line", "play_line",
]

func _drills() -> Array[DrillData]:
	var list: DrillList = load(DRILL_LIST_PATH)
	return list.drills

func test_each_drill_trains_strength_and_at_most_one_physical_minor() -> void:
	for drill: DrillData in _drills():
		assert_gt(drill.strength_xp_per_rep, 0.0, "%s pays Strength XP" % drill.id)
		assert_gt(drill.health_per_rep, 0.0, "%s refills Health" % drill.id)
		assert_has([-1, AttributeType.BODY, AttributeType.AGILITY], drill.minor_stat, "%s's other stat is Body, Agility or none" % drill.id)
		if drill.has_minor_stat():
			assert_gt(drill.minor_xp_per_rep, 0.0, "%s pays its other stat's XP" % drill.id)
		assert_gt(drill.rep_seconds, 0.0, "%s's rep takes time" % drill.id)
		assert_gt(drill.reps_per_set, 0, "%s's set has reps" % drill.id)

func test_drill_ids_are_unique() -> void:
	var seen: Array[String] = []
	for drill: DrillData in _drills():
		assert_false(drill.id.is_empty(), "every drill has an id")
		assert_does_not_have(seen, drill.id, "%s is listed once" % drill.id)
		seen.append(drill.id)

## The text saver drops a value equal to its default, so a changed default would
## silently change a drill. Each file names every field.
func test_every_value_is_written_out() -> void:
	for drill: DrillData in _drills():
		var text: String = FileAccess.get_file_as_string(drill.resource_path)
		for field: String in WRITTEN_FIELDS:
			assert_true(text.contains("\n%s = " % field), "%s writes out %s" % [drill.id, field])

func test_the_approved_roster() -> void:
	var expected: Array[Dictionary] = [
		{"id": "stone_lifting", "minor": -1, "strength_xp": 6.0, "minor_xp": 0.0, "health": 4.0, "input": DrillData.InputKind.HOLD_RELEASE, "seconds": 4.0},
		{"id": "horse_stance", "minor": AttributeType.BODY, "strength_xp": 8.0, "minor_xp": 4.0, "health": 4.0, "input": DrillData.InputKind.HOLD_STEADY, "seconds": 4.0},
		{"id": "falling_leaf", "minor": AttributeType.AGILITY, "strength_xp": 4.0, "minor_xp": 2.0, "health": 2.0, "input": DrillData.InputKind.CATCH, "seconds": 2.0},
		{"id": "waterfall_tempering", "minor": AttributeType.BODY, "strength_xp": 6.0, "minor_xp": 3.0, "health": 3.0, "input": DrillData.InputKind.BEAT, "seconds": 3.0},
	]
	var drills: Array[DrillData] = _drills()
	assert_eq(drills.size(), expected.size(), "the roster has the approved drills")
	for i: int in mini(drills.size(), expected.size()):
		var drill: DrillData = drills[i]
		var want: Dictionary = expected[i]
		assert_eq(drill.id, want["id"], "drill %d" % i)
		assert_eq(drill.minor_stat, want["minor"], "%s's other stat" % drill.id)
		assert_eq(drill.strength_xp_per_rep, want["strength_xp"], "%s's Strength XP" % drill.id)
		assert_eq(drill.minor_xp_per_rep, want["minor_xp"], "%s's other stat's XP" % drill.id)
		assert_eq(drill.health_per_rep, want["health"], "%s's Health" % drill.id)
		assert_eq(drill.input_kind, want["input"], "%s's input" % drill.id)
		assert_eq(drill.rep_seconds, want["seconds"], "%s's Auto pace" % drill.id)
		assert_eq(drill.reps_per_set, 10, "%s's set" % drill.id)

## The drill drawer and the board read each drill's words and icon: how it plays,
## and the footer's line before a set and during one.
func test_every_drill_has_its_words_and_icon() -> void:
	for drill: DrillData in _drills():
		assert_not_null(drill.icon, "%s has an icon" % drill.id)
		assert_false(drill.play_hint.is_empty(), "%s says how it plays" % drill.id)
		assert_false(drill.ready_line.is_empty(), "%s has a line before a set" % drill.id)
		assert_false(drill.play_line.is_empty(), "%s has a line during one" % drill.id)

func test_a_new_save_starts_with_the_first_drill() -> void:
	var save := SaveGameData.new()
	assert_eq(save.unlocked_drill_ids, [_drills()[0].id] as Array[String], "the starting drill is unlocked")
	assert_eq(save.equipped_drill_id, _drills()[0].id, "and equipped")
