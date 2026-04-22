extends GutTest

## Integration test: load the real pure_madra tree from disk and verify its
## structure. This catches regressions in the .tres wiring for prerequisite
## references, which are now typed Array[PathNodeData] instead of Array[String].

const PURE_MADRA_TREE_PATH: String = "res://resources/path_progression/pure_madra/pure_madra_tree.tres"

func test_pure_madra_tree_loads_and_validates() -> void:
	var tree: PathTreeData = load(PURE_MADRA_TREE_PATH)
	assert_not_null(tree, "pure_madra_tree.tres should load")
	assert_true(tree.validate(), "pure_madra_tree should pass validate() — prereq refs resolve to nodes in the tree")

func test_pure_madra_tree_prerequisites_are_resource_refs() -> void:
	var tree: PathTreeData = load(PURE_MADRA_TREE_PATH)
	var focused_strike: PathNodeData = tree.get_node_by_id("focused_strike")
	assert_not_null(focused_strike, "focused_strike node should exist")
	assert_eq(focused_strike.prerequisites.size(), 1,
		"focused_strike should have exactly one prerequisite")
	var prereq: PathNodeData = focused_strike.prerequisites[0]
	assert_not_null(prereq, "prerequisite should be a resolved PathNodeData reference")
	assert_eq(prereq.id, "power_font",
		"focused_strike's prerequisite should be the power_font node")

func test_pure_madra_tree_multi_prerequisite_wiring() -> void:
	var tree: PathTreeData = load(PURE_MADRA_TREE_PATH)
	var madra_surge: PathNodeData = tree.get_node_by_id("madra_surge")
	assert_not_null(madra_surge, "madra_surge node should exist")
	assert_eq(madra_surge.prerequisites.size(), 2,
		"madra_surge should have two prerequisites")
	var prereq_ids: Array[String] = []
	for prereq: PathNodeData in madra_surge.prerequisites:
		prereq_ids.append(prereq.id)
	assert_has(prereq_ids, "efficient_palm")
	assert_has(prereq_ids, "lingering_silence")
