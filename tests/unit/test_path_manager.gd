extends GutTest

# ----- Test helpers -----

var _save_data: SaveGameData

func _create_test_effect(type: PathNodeEffectData.EffectType, value: float) -> PathNodeEffectData:
	var effect := PathNodeEffectData.new()
	effect.effect_type = type
	effect.float_value = value
	return effect

func _create_test_node(id: String, cost: int = 1, prereqs: Array[PathNodeData] = [], max_purchases: int = 1, stage: CultivationManager.AdvancementStage = CultivationManager.AdvancementStage.FOUNDATION) -> PathNodeData:
	var node := PathNodeData.new()
	node.id = id
	node.display_name = "Test " + id
	node.description = "Test node"
	node.point_cost = cost
	node.prerequisites = prereqs
	node.max_purchases = max_purchases
	node.required_stage = stage
	return node

func _create_test_tree(nodes: Array[PathNodeData]) -> PathTreeData:
	var tree := PathTreeData.new()
	tree.path_id = "test_path"
	tree.path_name = "Test Path"
	tree.nodes = nodes
	return tree

func before_each() -> void:
	_save_data = SaveGameData.new()
	PathManager._live_save_data = _save_data
	PathManager._all_trees = {}
	PathManager._current_tree = null
	PathManager._cached_effects = PathEffectsSummary.new()
	PathManager._test_stage_override = CultivationManager.AdvancementStage.JADE
	# PathManager.purchase_node now calls CyclingManager, so set up its test state
	CyclingManager._live_save_data = _save_data
	var _smooth_flow := CyclingTechniqueData.new()
	_smooth_flow.id = "smooth_flow"
	CyclingManager._techniques_by_id = {"smooth_flow": _smooth_flow}
	# PathManager.purchase_node now calls AbilityManager, so set up its test state
	AbilityManager._live_save_data = _save_data
	var _empty_palm := AbilityData.new()
	_empty_palm.ability_id = "empty_palm"
	AbilityManager._abilities_by_id = {"empty_palm": _empty_palm}

# ----- Point management -----

func test_initial_point_balance_is_zero() -> void:
	assert_eq(PathManager.get_point_balance(), 0, "should start with 0 points")

func test_add_points_increases_balance() -> void:
	PathManager.add_points(5)
	assert_eq(PathManager.get_point_balance(), 5, "should have 5 points after adding 5")

func test_add_points_emits_signal() -> void:
	watch_signals(PathManager)
	PathManager.add_points(3)
	assert_signal_emitted_with_parameters(PathManager, "points_changed", [3])

# ----- Path setting -----

func test_set_path_with_valid_id() -> void:
	var tree := _create_test_tree([])
	PathManager._all_trees["test_path"] = tree
	var result: bool = PathManager.set_path("test_path")
	assert_true(result, "should succeed with valid path_id")
	assert_eq(PathManager.get_current_tree(), tree, "should set current tree")

func test_set_path_with_invalid_id() -> void:
	var result: bool = PathManager.set_path("nonexistent")
	assert_false(result, "should fail with invalid path_id")
	assert_null(PathManager.get_current_tree(), "should not set current tree")
	assert_push_error("unknown path_id")

func test_set_path_clears_previous_state() -> void:
	var tree := _create_test_tree([_create_test_node("a")])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(5)
	PathManager.purchase_node("a")
	PathManager.set_path("test_path")
	assert_eq(PathManager.get_point_balance(), 0, "should reset points")
	assert_eq(PathManager.get_node_purchase_count("a"), 0, "should reset purchases")

# ----- Purchase validation -----

func test_can_purchase_with_enough_points() -> void:
	var node_a := _create_test_node("a", 2)
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(2)
	assert_true(PathManager.can_purchase_node("a"), "should be purchasable with enough points")

func test_cannot_purchase_without_enough_points() -> void:
	var node_a := _create_test_node("a", 5)
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(3)
	assert_false(PathManager.can_purchase_node("a"), "should not be purchasable without enough points")

func test_cannot_purchase_at_max_level() -> void:
	var node_a := _create_test_node("a", 1, [], 1)
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(5)
	PathManager.purchase_node("a")
	assert_false(PathManager.can_purchase_node("a"), "should not be purchasable at max level")

func test_cannot_purchase_without_prerequisites() -> void:
	var node_a := _create_test_node("a")
	var node_b := _create_test_node("b", 1, [node_a])
	var tree := _create_test_tree([node_a, node_b])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(5)
	assert_false(PathManager.can_purchase_node("b"), "should not be purchasable without prereqs")

func test_can_purchase_with_prerequisites_met() -> void:
	var node_a := _create_test_node("a")
	var node_b := _create_test_node("b", 1, [node_a])
	var tree := _create_test_tree([node_a, node_b])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(5)
	PathManager.purchase_node("a")
	assert_true(PathManager.can_purchase_node("b"), "should be purchasable with prereqs met")

func test_cannot_purchase_without_no_path_set() -> void:
	assert_false(PathManager.can_purchase_node("anything"), "should not purchase without a path set")

# ----- Purchase execution -----

func test_purchase_deducts_points() -> void:
	var node_a := _create_test_node("a", 3)
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(5)
	PathManager.purchase_node("a")
	assert_eq(PathManager.get_point_balance(), 2, "should deduct 3 points from 5")

func test_purchase_increments_level() -> void:
	var node_a := _create_test_node("a", 1, [], 3)
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(5)
	PathManager.purchase_node("a")
	assert_eq(PathManager.get_node_purchase_count("a"), 1, "should be level 1")
	PathManager.purchase_node("a")
	assert_eq(PathManager.get_node_purchase_count("a"), 2, "should be level 2")

func test_purchase_emits_signal() -> void:
	var node_a := _create_test_node("a")
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(5)
	watch_signals(PathManager)
	PathManager.purchase_node("a")
	assert_signal_emitted_with_parameters(PathManager, "node_purchased", ["a", 1])

func test_failed_purchase_returns_false() -> void:
	var node_a := _create_test_node("a", 10)
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(1)
	var result: bool = PathManager.purchase_node("a")
	assert_false(result, "should return false when purchase fails")
	assert_eq(PathManager.get_point_balance(), 1, "should not deduct points on failure")

# ----- Effect aggregation -----

func test_effects_empty_by_default() -> void:
	var effects: PathEffectsSummary = PathManager.get_effects()
	assert_eq(effects.madra_generation_mult, 1.0, "default madra gen mult should be 1.0")
	assert_eq(effects.madra_capacity_bonus, 0.0, "default madra cap bonus should be 0.0")

func test_additive_effect_applied() -> void:
	var node_a := _create_test_node("a")
	node_a.effects = [_create_test_effect(PathNodeEffectData.EffectType.MADRA_CAPACITY_BONUS, 25.0)]
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(5)
	PathManager.purchase_node("a")
	var effects: PathEffectsSummary = PathManager.get_effects()
	assert_eq(effects.madra_capacity_bonus, 25.0, "should have +25 madra cap")

func test_multiplicative_effect_applied() -> void:
	var node_a := _create_test_node("a")
	node_a.effects = [_create_test_effect(PathNodeEffectData.EffectType.MADRA_GENERATION_MULT, 1.1)]
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(5)
	PathManager.purchase_node("a")
	var effects: PathEffectsSummary = PathManager.get_effects()
	assert_almost_eq(effects.madra_generation_mult, 1.1, 0.001, "should have 1.1x madra gen")

func test_repeatable_effects_stack() -> void:
	var node_a := _create_test_node("a", 1, [], 5)
	node_a.effects = [_create_test_effect(PathNodeEffectData.EffectType.ADVENTURE_MADRA_RETURN_PCT, 0.1)]
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(10)
	PathManager.purchase_node("a")
	PathManager.purchase_node("a")
	PathManager.purchase_node("a")
	var effects: PathEffectsSummary = PathManager.get_effects()
	assert_almost_eq(effects.adventure_madra_return_pct, 0.3, 0.001, "should have 30% madra return at level 3")

func test_adventure_madra_return_capped_at_100() -> void:
	var node_a := _create_test_node("a", 1, [], 20)
	node_a.effects = [_create_test_effect(PathNodeEffectData.EffectType.ADVENTURE_MADRA_RETURN_PCT, 0.1)]
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(20)
	for i in 15:
		PathManager.purchase_node("a")
	var effects: PathEffectsSummary = PathManager.get_effects()
	assert_almost_eq(effects.adventure_madra_return_pct, 1.0, 0.001, "should cap at 100%")

# ----- Unlock effects -----

func test_ability_unlock_tracked() -> void:
	var node_a := _create_test_node("a")
	var effect := PathNodeEffectData.new()
	effect.effect_type = PathNodeEffectData.EffectType.UNLOCK_ABILITY
	effect.string_value = "empty_palm"
	node_a.effects = [effect]
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(5)
	PathManager.purchase_node("a")
	var unlocked: Array[String] = PathManager.get_unlocked_abilities()
	assert_eq(unlocked.size(), 1, "should have 1 unlocked ability")
	assert_eq(unlocked[0], "empty_palm", "should be empty_palm")

func test_cycling_technique_unlock_tracked() -> void:
	var node_a := _create_test_node("a")
	var effect := PathNodeEffectData.new()
	effect.effect_type = PathNodeEffectData.EffectType.UNLOCK_CYCLING_TECHNIQUE
	effect.string_value = "smooth_flow"
	node_a.effects = [effect]
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(5)
	PathManager.purchase_node("a")
	var unlocked: Array[String] = PathManager.get_unlocked_cycling_techniques()
	assert_eq(unlocked.size(), 1, "should have 1 unlocked technique")
	assert_eq(unlocked[0], "smooth_flow", "should be smooth_flow")

func test_duplicate_unlocks_not_added() -> void:
	var node_a := _create_test_node("a", 1, [], 3)
	var effect := PathNodeEffectData.new()
	effect.effect_type = PathNodeEffectData.EffectType.UNLOCK_ABILITY
	effect.string_value = "empty_palm"
	node_a.effects = [effect]
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(5)
	PathManager.purchase_node("a")
	PathManager.purchase_node("a")
	var unlocked: Array[String] = PathManager.get_unlocked_abilities()
	assert_eq(unlocked.size(), 1, "should not duplicate unlock on re-purchase")

# ----- Reset -----

func test_reset_clears_all_state() -> void:
	var node_a := _create_test_node("a")
	var tree := _create_test_tree([node_a])
	PathManager._all_trees["test_path"] = tree
	PathManager.set_path("test_path")
	PathManager.add_points(5)
	PathManager.purchase_node("a")
	PathManager.reset_path()
	assert_null(PathManager.get_current_tree(), "tree should be null after reset")
	assert_eq(PathManager.get_point_balance(), 0, "points should be 0 after reset")
	assert_eq(PathManager.get_node_purchase_count("a"), 0, "purchases should be cleared")
