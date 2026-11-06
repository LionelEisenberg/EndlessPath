extends GutTest

## Content checks on the shipped cycling technique catalog: every technique has
## a unique id, trains Spirit and at most one Spiritual stat beside it with both
## written out in its file, and every path node that unlocks a technique names
## one the catalog has.

const CATALOG_PATH: String = "res://resources/cycling/cycling_techniques/cycling_technique_list.tres"
const PATH_TREES_PATH: String = "res://resources/path_progression/path_tree_list.tres"
const AttributeType = CharacterAttributesData.AttributeType
## The fields each technique's file writes out, never leaving them to the
## script's default (Godot's text saver drops a value equal to it).
const WRITTEN_OUT_FIELDS: Array[String] = ["spirit_xp_per_cycle", "minor_stat", "seal_seconds", "seal_xp"]
## The tier XP each zone's file writes out.
const ZONE_FIELDS: Array[String] = ["perfect_xp", "good_xp", "ok_xp"]

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _techniques() -> Array[CyclingTechniqueData]:
	var catalog: CyclingTechniqueList = load(CATALOG_PATH) as CyclingTechniqueList
	return catalog.cycling_techniques

func _catalog_ids() -> Array[String]:
	var ids: Array[String] = []
	for technique: CyclingTechniqueData in _techniques():
		ids.append(technique.id)
	return ids

#-----------------------------------------------------------------------------
# IDS
#-----------------------------------------------------------------------------

func test_the_catalog_has_techniques() -> void:
	assert_gt(_techniques().size(), 0, "the catalog ships techniques")

func test_technique_ids_are_unique_and_not_empty() -> void:
	var seen: Array[String] = []
	for technique: CyclingTechniqueData in _techniques():
		assert_ne(technique.id, "", "%s has an id" % technique.resource_path)
		assert_false(technique.id in seen, "the id '%s' is used once" % technique.id)
		seen.append(technique.id)

func test_every_path_node_unlocks_a_technique_in_the_catalog() -> void:
	var ids: Array[String] = _catalog_ids()
	var unlocks: int = 0
	var trees: PathTreeList = load(PATH_TREES_PATH) as PathTreeList
	for tree: PathTreeData in trees.path_trees:
		for node: PathNodeData in tree.nodes:
			for effect: PathNodeEffectData in node.effects:
				if effect.effect_type != PathNodeEffectData.EffectType.UNLOCK_CYCLING_TECHNIQUE:
					continue
				unlocks += 1
				assert_true(effect.string_value in ids,
					"the path node '%s' unlocks '%s', which the catalog has" % [node.id, effect.string_value])
	assert_gt(unlocks, 0, "precondition: some path node unlocks a technique")

func test_the_save_default_technique_is_in_the_catalog() -> void:
	var save := SaveGameData.new()
	var ids: Array[String] = _catalog_ids()
	assert_true(save.equipped_cycling_technique_id in ids, "a new save equips a technique the catalog has")
	for id: String in save.unlocked_cycling_technique_ids:
		assert_true(id in ids, "a new save unlocks '%s', which the catalog has" % id)

#-----------------------------------------------------------------------------
# TRAINING
#-----------------------------------------------------------------------------

func test_every_technique_trains_spirit_and_at_most_one_spiritual_stat() -> void:
	for technique: CyclingTechniqueData in _techniques():
		assert_gt(technique.spirit_xp_per_cycle, 0.0, "%s pays Spirit XP" % technique.id)
		assert_true(technique.minor_stat in [-1, AttributeType.MIND, AttributeType.CONTROL],
			"%s trains Mind, Control or nothing beside Spirit (%d)" % [technique.id, technique.minor_stat])

func test_every_technique_writes_out_its_training() -> void:
	for technique: CyclingTechniqueData in _techniques():
		var text: String = FileAccess.get_file_as_string(technique.resource_path)
		for field: String in WRITTEN_OUT_FIELDS:
			assert_true(text.contains("\n%s = " % field), "%s writes out %s" % [technique.resource_path, field])

## Presses train Control and seals train Mind (#91, #99): a technique with zones
## trains Control and has no seals, one with seals trains Mind and has no zones,
## and one with neither trains Spirit alone.
func test_zones_pay_control_and_seals_pay_mind() -> void:
	for technique: CyclingTechniqueData in _techniques():
		var has_zones: bool = not technique.cycling_zones.is_empty()
		var has_seals: bool = not technique.seal_seconds.is_empty()
		assert_false(has_zones and has_seals, "%s has zones or seals, not both" % technique.id)
		if has_zones:
			assert_eq(technique.minor_stat, AttributeType.CONTROL, "%s's zones pay Control" % technique.id)
		elif has_seals:
			assert_eq(technique.minor_stat, AttributeType.MIND, "%s's seals pay Mind" % technique.id)
		else:
			assert_eq(technique.minor_stat, -1, "%s, with neither, trains Spirit alone" % technique.id)

## Each seal shows SEAL_LEAD before its node, so a node sits at least that far
## into the cycle and that far after the one before it (two seals never show at
## once), and within the cycle; a technique with seals pays for them.
func test_seals_fit_their_cycle() -> void:
	var seals: int = 0
	for technique: CyclingTechniqueData in _techniques():
		var last: float = 0.0
		for seconds: float in technique.seal_seconds:
			seals += 1
			assert_gte(seconds - last, CyclingRules.SEAL_LEAD, "%s's seal at %s s shows after the one before is done" % [technique.id, seconds])
			assert_lte(seconds, technique.cycle_duration, "%s's seal at %s s is within its cycle" % [technique.id, seconds])
			last = seconds
		if not technique.seal_seconds.is_empty():
			assert_gt(technique.seal_xp, 0.0, "%s's seals pay" % technique.id)
	assert_gt(seals, 0, "precondition: the catalog has seals")

## Every zone is a file of its own that writes out what each tier pays, never
## leaning on the class's defaults.
func test_every_zone_writes_out_its_tier_xp() -> void:
	var zones: int = 0
	for technique: CyclingTechniqueData in _techniques():
		for zone: CyclingZoneData in technique.cycling_zones:
			zones += 1
			assert_true(zone.resource_path.ends_with(".tres"), "%s's zone is a file of its own" % technique.id)
			var text: String = FileAccess.get_file_as_string(zone.resource_path)
			for field: String in ZONE_FIELDS:
				assert_true(text.contains("\n%s = " % field), "%s writes out %s" % [zone.resource_path, field])
	assert_gt(zones, 0, "precondition: the catalog has zones")

## What a cycle at its best pays each technique's stats, as #91 and #99 set them.
func test_the_roster_s_xp_per_cycle() -> void:
	var expected: Dictionary = {
		"foundation_technique": {AttributeType.SPIRIT: 12.0, AttributeType.MIND: 0.0, AttributeType.CONTROL: 0.0},
		"smooth_flow": {AttributeType.SPIRIT: 30.0, AttributeType.MIND: 0.0, AttributeType.CONTROL: 30.0},
		"torrential_flow": {AttributeType.SPIRIT: 16.0, AttributeType.MIND: 15.0, AttributeType.CONTROL: 0.0},
	}
	var seen: int = 0
	for technique: CyclingTechniqueData in _techniques():
		if not expected.has(technique.id):
			continue
		seen += 1
		var per_stat: Dictionary = expected[technique.id]
		for stat: int in per_stat:
			assert_almost_eq(technique.get_xp_per_cycle(stat), per_stat[stat], 0.0001,
				"%s pays %s %s a cycle at its best" % [technique.id, StatDisplay.name_of(stat), per_stat[stat]])
	assert_eq(seen, expected.size(), "precondition: the catalog has the three techniques")
