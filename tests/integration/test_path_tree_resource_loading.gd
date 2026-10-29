extends GutTest

## Integration test: load the real pure_madra tree from disk and verify its
## structure. This catches regressions in the .tres wiring for prerequisite
## references, which are now typed Array[PathNodeData] instead of Array[String].

const PURE_MADRA_TREE_PATH: String = "res://resources/path_progression/pure_madra/pure_madra_tree.tres"

func test_pure_madra_tree_loads_and_validates() -> void:
	var tree: PathTreeData = load(PURE_MADRA_TREE_PATH)
	assert_not_null(tree, "pure_madra_tree.tres should load")
	assert_true(tree.validate(), "pure_madra_tree should pass validate() — prereq refs resolve to nodes in the tree")

## A node's typed prerequisites load as the PathNodeData its .tres names, none
## dropped: focused_strike's one and madra_surge's two.
func test_pure_madra_tree_prerequisites_are_resource_refs() -> void:
	var tree: PathTreeData = load(PURE_MADRA_TREE_PATH)
	var cases: Array[Dictionary] = [
		{"node": "focused_strike", "prerequisites": ["power_font"]},
		{"node": "madra_surge", "prerequisites": ["efficient_palm", "lingering_silence"]},
	]
	for case: Dictionary in cases:
		var node: PathNodeData = tree.get_node_by_id(case.node)
		assert_not_null(node, "%s node should exist" % case.node)
		if node == null:
			continue
		assert_eq(node.prerequisites.size(), case.prerequisites.size(),
			"%s should have %d prerequisite(s)" % [case.node, case.prerequisites.size()])
		var prereq_ids: Array[String] = []
		for prereq: PathNodeData in node.prerequisites:
			assert_not_null(prereq, "%s: a prerequisite should be a resolved PathNodeData reference" % case.node)
			prereq_ids.append(prereq.id if prereq != null else "")
		for expected_id: String in case.prerequisites:
			assert_has(prereq_ids, expected_id, "%s should require %s" % [case.node, expected_id])
