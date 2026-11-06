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
const WRITTEN_OUT_FIELDS: Array[String] = ["spirit_xp_per_cycle", "minor_stat"]

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
