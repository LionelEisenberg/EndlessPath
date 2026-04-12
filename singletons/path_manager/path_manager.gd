class_name PathManager
extends Node

## Manages the player's path progression tree for the current run.
## Owns path selection, tree state, point balance, and effect aggregation.
## Other managers query PathManager to know what perks are active.

signal node_purchased(node_id: String, new_level: int)
signal points_changed(new_balance: int)
signal path_set(path_tree: PathTreeData)
signal effects_changed(effects: PathEffectsSummary)

var _live_save_data: SaveGameData = null
var _current_tree: PathTreeData = null
var _all_trees: Dictionary = {}  # path_id -> PathTreeData
var _cached_effects: PathEffectsSummary = PathEffectsSummary.new()

## Test-only: override stage check. Set to -1 to use real CultivationManager.
var _test_stage_override: int = -1

func _ready() -> void:
	if PersistenceManager:
		_live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_on_save_data_reset)
	_load_all_path_trees()
	_restore_current_path()

# ----- Public API -----

## Sets the active path for this run. Clears any existing tree state.
func set_path(path_id: String) -> bool:
	if not _all_trees.has(path_id):
		push_error("PathManager: unknown path_id '%s'" % path_id)
		return false
	_current_tree = _all_trees[path_id]
	_live_save_data.current_path_id = path_id
	_live_save_data.path_node_purchases.clear()
	_live_save_data.path_points = 0
	_recalculate_effects()
	path_set.emit(_current_tree)
	return true

## Returns the currently active path tree, or null if none set.
func get_current_tree() -> PathTreeData:
	return _current_tree

## Returns the current unspent path point balance.
func get_point_balance() -> int:
	if not _live_save_data:
		return 0
	return _live_save_data.path_points

## Adds path points to the balance.
func add_points(amount: int) -> void:
	_live_save_data.path_points += amount
	points_changed.emit(_live_save_data.path_points)

## Returns how many times a node has been purchased (0 if not purchased).
func get_node_purchase_count(node_id: String) -> int:
	if not _live_save_data.path_node_purchases.has(node_id):
		return 0
	return _live_save_data.path_node_purchases[node_id]

## Returns true if the node can be purchased right now.
func can_purchase_node(node_id: String) -> bool:
	if _current_tree == null:
		return false
	var node: PathNodeData = _current_tree.get_node_by_id(node_id)
	if node == null:
		return false
	# Check max purchases
	var current_level: int = get_node_purchase_count(node_id)
	if current_level >= node.max_purchases:
		return false
	# Check point cost
	if _live_save_data.path_points < node.point_cost:
		return false
	# Check tier gate
	if not _is_stage_reached(node.required_stage):
		return false
	# Check prerequisites
	if not _are_all_prerequisites_met(node):
		return false
	return true

## Attempts to purchase a node. Returns true on success.
func purchase_node(node_id: String) -> bool:
	if not can_purchase_node(node_id):
		return false
	var node: PathNodeData = _current_tree.get_node_by_id(node_id)
	_live_save_data.path_points -= node.point_cost
	var new_level: int = get_node_purchase_count(node_id) + 1
	_live_save_data.path_node_purchases[node_id] = new_level
	_recalculate_effects()
	points_changed.emit(_live_save_data.path_points)
	node_purchased.emit(node_id, new_level)
	return true

## Returns the current aggregated effects from all purchased nodes.
func get_effects() -> PathEffectsSummary:
	return _cached_effects

## Returns resource paths of all combat abilities unlocked by purchased nodes.
## Not yet consumed by the ability system — ready for ability rework integration.
func get_unlocked_abilities() -> Array[String]:
	return _cached_effects.unlocked_abilities

## Returns names/paths of all cycling techniques unlocked by purchased nodes.
## Not yet consumed by the cycling system — ready for ability rework integration.
func get_unlocked_cycling_techniques() -> Array[String]:
	return _cached_effects.unlocked_cycling_techniques

## Resets all path progression state (for ascension).
func reset_path() -> void:
	_current_tree = null
	_live_save_data.current_path_id = ""
	_live_save_data.path_node_purchases.clear()
	_live_save_data.path_points = 0
	_cached_effects = PathEffectsSummary.new()
	points_changed.emit(0)
	effects_changed.emit(_cached_effects)

# ----- Private -----

func _is_stage_reached(required: CultivationManager.AdvancementStage) -> bool:
	if _test_stage_override >= 0:
		return _test_stage_override >= required
	if not CultivationManager:
		return false
	return CultivationManager.get_current_advancement_stage() >= required

func _are_all_prerequisites_met(node: PathNodeData) -> bool:
	for prereq_id: String in node.prerequisites:
		if get_node_purchase_count(prereq_id) < 1:
			return false
	return true

func _recalculate_effects() -> void:
	_cached_effects = PathEffectsSummary.new()
	if _current_tree == null:
		effects_changed.emit(_cached_effects)
		return
	for node: PathNodeData in _current_tree.nodes:
		var level: int = get_node_purchase_count(node.id)
		if level < 1:
			continue
		for effect: PathNodeEffectData in node.effects:
			_apply_effect(effect, level)
	effects_changed.emit(_cached_effects)

func _apply_effect(effect: PathNodeEffectData, level: int) -> void:
	match effect.effect_type:
		PathNodeEffectData.EffectType.ATTRIBUTE_BONUS:
			var current: float = _cached_effects.attribute_bonuses.get(effect.attribute_type, 0.0)
			_cached_effects.attribute_bonuses[effect.attribute_type] = current + (effect.float_value * level)
		PathNodeEffectData.EffectType.MADRA_GENERATION_MULT:
			_cached_effects.madra_generation_mult *= pow(effect.float_value, level)
		PathNodeEffectData.EffectType.MADRA_CAPACITY_BONUS:
			_cached_effects.madra_capacity_bonus += effect.float_value * level
		PathNodeEffectData.EffectType.CORE_DENSITY_XP_MULT:
			_cached_effects.core_density_xp_mult *= pow(effect.float_value, level)
		PathNodeEffectData.EffectType.STAMINA_RECOVERY_MULT:
			_cached_effects.stamina_recovery_mult *= pow(effect.float_value, level)
		PathNodeEffectData.EffectType.CYCLING_ACCURACY_BONUS:
			_cached_effects.cycling_accuracy_bonus += effect.float_value * level
		PathNodeEffectData.EffectType.ADVENTURE_MADRA_RETURN_PCT:
			_cached_effects.adventure_madra_return_pct += effect.float_value * level
			_cached_effects.adventure_madra_return_pct = minf(_cached_effects.adventure_madra_return_pct, 1.0)
		PathNodeEffectData.EffectType.MADRA_ON_LEVEL_UP:
			_cached_effects.madra_on_level_up += effect.float_value * level
		PathNodeEffectData.EffectType.UNLOCK_ABILITY:
			if not effect.string_value.is_empty() and not _cached_effects.unlocked_abilities.has(effect.string_value):
				_cached_effects.unlocked_abilities.append(effect.string_value)
		PathNodeEffectData.EffectType.UNLOCK_CYCLING_TECHNIQUE:
			if not effect.string_value.is_empty() and not _cached_effects.unlocked_cycling_techniques.has(effect.string_value):
				_cached_effects.unlocked_cycling_techniques.append(effect.string_value)

func _load_all_path_trees() -> void:
	var tree_dir: String = "res://resources/path_progression/"
	var dir := DirAccess.open(tree_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var folder_name: String = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var tree_path: String = tree_dir + folder_name + "/" + folder_name + "_tree.tres"
			if ResourceLoader.exists(tree_path):
				var tree: PathTreeData = load(tree_path) as PathTreeData
				if tree and tree.validate():
					_all_trees[tree.path_id] = tree
		folder_name = dir.get_next()

func _restore_current_path() -> void:
	if _live_save_data and not _live_save_data.current_path_id.is_empty():
		if _all_trees.has(_live_save_data.current_path_id):
			_current_tree = _all_trees[_live_save_data.current_path_id]
			_recalculate_effects()

func _on_save_data_reset() -> void:
	_live_save_data = PersistenceManager.save_game_data
	_current_tree = null
	_cached_effects = PathEffectsSummary.new()
	_restore_current_path()
