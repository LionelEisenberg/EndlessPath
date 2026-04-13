# Path Progression System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a within-run skill tree system where players spend Path Points (earned via Core Density leveling) to unlock perks in a freeform node graph tied to their chosen Madra Path.

**Architecture:** Data-driven resource system adapted from the FusionForge upgrade tree pattern. PathNodeData resources define individual nodes; PathTreeData holds the full tree; PathManager singleton manages state, purchases, and effect aggregation. Scene-based layout for visual positioning. UI built fresh for EndlessPath's theme.

**Tech Stack:** Godot 4.6, GDScript, GUT 9.6.0 for testing

**Design Spec:** `docs/progression/PATH_PROGRESSION.md`

**Reference Implementation:** FusionForge upgrade system (`C:/Users/lione/Documents/Godot Games/RealProjects/FusionForge/`)

---

## File Structure

**Data Model (create):**
- `scripts/resource_definitions/path_progression/path_node_data.gd` -- single node definition
- `scripts/resource_definitions/path_progression/path_node_effect_data.gd` -- effect granted by a node
- `scripts/resource_definitions/path_progression/path_tree_data.gd` -- full tree containing all nodes
- `scripts/resource_definitions/path_progression/path_effects_summary.gd` -- aggregated effects snapshot

**Singleton (create):**
- `singletons/path_manager/path_manager.gd` -- core business logic

**Resources (create):**
- `resources/path_progression/pure_madra/pure_madra_tree.tres` -- Pure Madra tree definition
- `resources/path_progression/pure_madra/nodes/` -- individual .tres node files for Tier 1

**Layout (create):**
- `scenes/path_progression/layouts/pure_madra_tier1_layout.tscn` -- marker scene for node positions

**Assets (create, empty for now):**
- `assets/images/path_progression/` -- path tree UI images (backgrounds, tier gate dividers)
- `assets/images/path_progression/node_icons/` -- icons for individual path nodes
- `assets/images/path_progression/node_icons/pure_madra/` -- Pure Madra path-specific node icons
- `assets/images/path_progression/node_frames/` -- keystone/major/minor/repeatable frame textures

**UI (create):**
- `scenes/path_progression/path_tree_view.tscn` + `.gd` -- main view container with panning
- `scenes/path_progression/path_node_container.gd` -- pannable canvas that draws connection lines
- `scenes/path_progression/path_tree_view_state.gd` -- MainView state for the path tree
- `scenes/path_progression/path_node_ui.tscn` + `.gd` -- individual node button
- `scenes/path_progression/path_node_tooltip.tscn` + `.gd` -- hover tooltip

**Tests (create):**
- `tests/unit/test_path_manager.gd` -- PathManager logic tests

**Modified:**
- `singletons/persistence_manager/save_game_data.gd` -- add path progression state
- `singletons/cultivation_manager/cultivation_manager.gd` -- emit path point awards
- `project.godot` -- register PathManager autoload
- `scenes/ui/main_view/main_view.gd` -- add path tree view state
- `scenes/ui/main_view/main_view.tscn` -- add path tree view state node + path tree view scene

---

## Task 0: Scaffold Directory Structure

- [ ] **Step 1: Create all directories**

```bash
mkdir -p scripts/resource_definitions/path_progression
mkdir -p singletons/path_manager
mkdir -p resources/path_progression/pure_madra/nodes
mkdir -p scenes/path_progression/layouts
mkdir -p assets/images/path_progression/node_icons/pure_madra
mkdir -p assets/images/path_progression/node_frames
```

- [ ] **Step 2: Add .gdignore-free placeholder files so Git tracks empty asset dirs**

```bash
touch assets/images/path_progression/.gitkeep
touch assets/images/path_progression/node_icons/.gitkeep
touch assets/images/path_progression/node_icons/pure_madra/.gitkeep
touch assets/images/path_progression/node_frames/.gitkeep
```

- [ ] **Step 3: Commit**

```bash
git add scripts/resource_definitions/path_progression/.gitkeep singletons/path_manager/.gitkeep resources/path_progression/ scenes/path_progression/ assets/images/path_progression/
git commit -m "chore(progression): scaffold path progression directory structure"
```

Note: The `.gitkeep` files ensure empty directories are tracked. They'll be replaced by real files in subsequent tasks.

---

## Task 1: PathNodeEffectData Resource Class

**Files:**
- Create: `scripts/resource_definitions/path_progression/path_node_effect_data.gd`

- [ ] **Step 1: Create the effect data resource**

```gdscript
class_name PathNodeEffectData
extends Resource

## Defines a single effect granted by a path node.
## Each node can have multiple effects. Effects stack additively
## for repeatable nodes (applied per purchase level).

enum EffectType {
	ATTRIBUTE_BONUS,             ## Adds to a character attribute (uses attribute_type + float_value)
	MADRA_GENERATION_MULT,       ## Multiplier on Madra generated per cycle (float_value, e.g. 1.1 = +10%)
	MADRA_CAPACITY_BONUS,        ## Flat bonus to max Madra capacity (float_value)
	CORE_DENSITY_XP_MULT,        ## Multiplier on Core Density XP earned (float_value, e.g. 1.15 = +15%)
	STAMINA_RECOVERY_MULT,       ## Multiplier on stamina recovery rate in combat (float_value)
	CYCLING_ACCURACY_BONUS,      ## Flat bonus to cycling zone accuracy radius (float_value in pixels)
	ADVENTURE_MADRA_RETURN_PCT,  ## Percentage of unspent adventure Madra returned (float_value, e.g. 0.1 = 10%)
	MADRA_ON_LEVEL_UP,           ## Bonus Madra granted on Core Density level-up (float_value)
	UNLOCK_ABILITY,              ## Unlocks a combat ability (string_value = resource path to AbilityData .tres)
	UNLOCK_CYCLING_TECHNIQUE,    ## Unlocks a cycling technique (string_value = technique name/resource path)
}

@export var effect_type: EffectType = EffectType.ATTRIBUTE_BONUS
@export var float_value: float = 0.0

## Used for ATTRIBUTE_BONUS to specify which attribute to boost.
@export var attribute_type: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.STRENGTH

## Used for UNLOCK_ABILITY (resource path to AbilityData .tres) and
## UNLOCK_CYCLING_TECHNIQUE (technique name or resource path).
@export var string_value: String = ""
```

- [ ] **Step 2: Commit**

```bash
git add scripts/resource_definitions/path_progression/path_node_effect_data.gd
git commit -m "feat(progression): add PathNodeEffectData resource class"
```

---

## Task 2: PathNodeData Resource Class

**Files:**
- Create: `scripts/resource_definitions/path_progression/path_node_data.gd`

- [ ] **Step 1: Create the node data resource**

```gdscript
class_name PathNodeData
extends Resource

## Defines a single node in a path progression tree.
## Nodes can be keystones, major, minor, or repeatable.
## Prerequisites are tracked by ID strings referencing other nodes in the same tree.

enum NodeType {
	KEYSTONE,    ## Game-changers: new abilities, cycling techniques, mechanic shifts (~20%)
	MAJOR,       ## Significant upgrades, meaningful new options (~30%)
	MINOR,       ## Stat bonuses, small QoL, connective tissue (~25%)
	REPEATABLE,  ## Stackable bonuses with a cap, point sinks (~25%)
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var node_type: NodeType = NodeType.MINOR
@export var icon: Texture2D = null

@export_group("Requirements")
## IDs of nodes that must be purchased (level >= 1) before this node can be purchased.
@export var prerequisites: Array[String] = []
## The cultivation stage required to purchase this node (tier gate).
@export var required_stage: CultivationManager.AdvancementStage = CultivationManager.AdvancementStage.FOUNDATION

@export_group("Cost & Limits")
## Cost in path points per purchase.
@export var point_cost: int = 1
## Maximum number of times this node can be purchased. 1 for non-repeatable, >1 for repeatable.
@export var max_purchases: int = 1

@export_group("Effects")
## Effects granted per purchase of this node. For repeatable nodes, effects stack per level.
@export var effects: Array[PathNodeEffectData] = []

## Returns true if this node's data is valid (has required fields).
func validate() -> bool:
	if id.is_empty():
		push_error("PathNodeData: id is empty")
		return false
	if display_name.is_empty():
		push_error("PathNodeData: display_name is empty for node '%s'" % id)
		return false
	if point_cost < 1:
		push_error("PathNodeData: point_cost must be >= 1 for node '%s'" % id)
		return false
	if max_purchases < 1:
		push_error("PathNodeData: max_purchases must be >= 1 for node '%s'" % id)
		return false
	return true

## Returns true if this node supports multiple purchases.
func is_repeatable() -> bool:
	return max_purchases > 1
```

- [ ] **Step 2: Commit**

```bash
git add scripts/resource_definitions/path_progression/path_node_data.gd
git commit -m "feat(progression): add PathNodeData resource class"
```

---

## Task 3: PathTreeData and PathEffectsSummary Resource Classes

**Files:**
- Create: `scripts/resource_definitions/path_progression/path_tree_data.gd`
- Create: `scripts/resource_definitions/path_progression/path_effects_summary.gd`

- [ ] **Step 1: Create PathTreeData**

```gdscript
class_name PathTreeData
extends Resource

## Defines a complete path progression tree for a single Madra path.
## Contains all nodes across all tiers. The tree is displayed as a freeform
## node graph with tier gates at cultivation stage boundaries.

@export var path_id: String = ""
@export var path_name: String = ""
@export_multiline var path_description: String = ""

## All nodes in this tree, across all tiers.
@export var nodes: Array[PathNodeData] = []

## Returns the node with the given ID, or null if not found.
func get_node_by_id(node_id: String) -> PathNodeData:
	for node: PathNodeData in nodes:
		if node.id == node_id:
			return node
	return null

## Returns all nodes that require the given cultivation stage.
func get_nodes_for_stage(stage: CultivationManager.AdvancementStage) -> Array[PathNodeData]:
	var result: Array[PathNodeData] = []
	for node: PathNodeData in nodes:
		if node.required_stage == stage:
			result.append(node)
	return result

## Returns the total point cost to purchase every node once (repeatable nodes counted once).
func get_total_tree_cost() -> int:
	var total: int = 0
	for node: PathNodeData in nodes:
		total += node.point_cost * node.max_purchases
	return total

## Validates all nodes in the tree. Returns true if all are valid.
func validate() -> bool:
	if path_id.is_empty():
		push_error("PathTreeData: path_id is empty")
		return false
	var ids: Array[String] = []
	for node: PathNodeData in nodes:
		if not node.validate():
			return false
		if ids.has(node.id):
			push_error("PathTreeData: duplicate node id '%s'" % node.id)
			return false
		ids.append(node.id)
	# Validate prerequisite references
	for node: PathNodeData in nodes:
		for prereq_id: String in node.prerequisites:
			if not ids.has(prereq_id):
				push_error("PathTreeData: node '%s' references unknown prerequisite '%s'" % [node.id, prereq_id])
				return false
	return true
```

- [ ] **Step 2: Create PathEffectsSummary**

```gdscript
class_name PathEffectsSummary
extends RefCounted

## Aggregated snapshot of all active path progression effects.
## Rebuilt by PathManager whenever a node is purchased.
## Other systems query this to apply path bonuses.

## Dictionary[CharacterAttributesData.AttributeType, float] -- flat bonus per attribute
var attribute_bonuses: Dictionary = {}

## Multiplier on Madra generated per cycle (1.0 = no change)
var madra_generation_mult: float = 1.0

## Flat bonus to max Madra capacity
var madra_capacity_bonus: float = 0.0

## Multiplier on Core Density XP earned (1.0 = no change)
var core_density_xp_mult: float = 1.0

## Multiplier on stamina recovery rate (1.0 = no change)
var stamina_recovery_mult: float = 1.0

## Flat bonus to cycling zone accuracy radius (pixels)
var cycling_accuracy_bonus: float = 0.0

## Percentage of unspent adventure Madra returned (0.0 to 1.0)
var adventure_madra_return_pct: float = 0.0

## Bonus Madra granted on Core Density level-up
var madra_on_level_up: float = 0.0

## Resource paths of combat abilities unlocked by purchased nodes.
## Not yet consumed by the ability system (wired during ability rework).
var unlocked_abilities: Array[String] = []

## Technique names/paths of cycling techniques unlocked by purchased nodes.
## Not yet consumed by the cycling system (wired during ability rework).
var unlocked_cycling_techniques: Array[String] = []

## Resets all values to defaults (no bonuses).
func reset() -> void:
	attribute_bonuses.clear()
	madra_generation_mult = 1.0
	madra_capacity_bonus = 0.0
	core_density_xp_mult = 1.0
	stamina_recovery_mult = 1.0
	cycling_accuracy_bonus = 0.0
	adventure_madra_return_pct = 0.0
	madra_on_level_up = 0.0
	unlocked_abilities.clear()
	unlocked_cycling_techniques.clear()
```

- [ ] **Step 3: Commit**

```bash
git add scripts/resource_definitions/path_progression/path_tree_data.gd scripts/resource_definitions/path_progression/path_effects_summary.gd
git commit -m "feat(progression): add PathTreeData and PathEffectsSummary classes"
```

---

## Task 4: SaveGameData Persistence Integration

**Files:**
- Modify: `singletons/persistence_manager/save_game_data.gd`

- [ ] **Step 1: Add path progression fields to SaveGameData**

Add to the existing file, in a new section after the existing exports:

```gdscript
# ----- Path Progression -----
## The path_id of the currently active path tree (empty if no path selected).
@export var current_path_id: String = ""
## Maps node_id -> purchase count for the current run's path tree.
@export var path_node_purchases: Dictionary = {}
## Current unspent path point balance.
@export var path_points: int = 0
```

- [ ] **Step 2: Add resets to the reset() function**

In the existing `reset()` function, add:

```gdscript
	# Path Progression
	current_path_id = ""
	path_node_purchases = {}
	path_points = 0
```

- [ ] **Step 3: Add to _to_string()**

In the existing `_to_string()` function, add to the output:

```gdscript
	result += "\n--- Path Progression ---"
	result += "\nCurrent Path: %s" % current_path_id
	result += "\nPath Points: %d" % path_points
	result += "\nPurchased Nodes: %s" % str(path_node_purchases)
```

- [ ] **Step 4: Commit**

```bash
git add singletons/persistence_manager/save_game_data.gd
git commit -m "feat(progression): add path progression fields to SaveGameData"
```

---

## Task 5: PathManager Singleton -- Core Logic + Tests

**Files:**
- Create: `singletons/path_manager/path_manager.gd`
- Create: `tests/unit/test_path_manager.gd`

This is the core task. We build the manager with TDD: write failing tests, then implement to pass.

- [ ] **Step 1: Create PathManager skeleton**

```gdscript
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
```

- [ ] **Step 2: Write failing tests**

```gdscript
extends GutTest

# ----- Test helpers -----

var _save_data: SaveGameData
var _manager: PathManager

func _create_test_effect(type: PathNodeEffectData.EffectType, value: float) -> PathNodeEffectData:
	var effect := PathNodeEffectData.new()
	effect.effect_type = type
	effect.float_value = value
	return effect

func _create_test_node(id: String, cost: int = 1, prereqs: Array[String] = [], max_purchases: int = 1, stage: CultivationManager.AdvancementStage = CultivationManager.AdvancementStage.FOUNDATION) -> PathNodeData:
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
	_manager = PathManager.new()
	_manager._live_save_data = _save_data
	_manager._all_trees = {}

# ----- Point management -----

func test_initial_point_balance_is_zero() -> void:
	assert_eq(_manager.get_point_balance(), 0, "should start with 0 points")

func test_add_points_increases_balance() -> void:
	_manager.add_points(5)
	assert_eq(_manager.get_point_balance(), 5, "should have 5 points after adding 5")

func test_add_points_emits_signal() -> void:
	watch_signals(_manager)
	_manager.add_points(3)
	assert_signal_emitted_with_parameters(_manager, "points_changed", [3])

# ----- Path setting -----

func test_set_path_with_valid_id() -> void:
	var tree := _create_test_tree([])
	_manager._all_trees["test_path"] = tree
	var result: bool = _manager.set_path("test_path")
	assert_true(result, "should succeed with valid path_id")
	assert_eq(_manager.get_current_tree(), tree, "should set current tree")

func test_set_path_with_invalid_id() -> void:
	var result: bool = _manager.set_path("nonexistent")
	assert_false(result, "should fail with invalid path_id")
	assert_null(_manager.get_current_tree(), "should not set current tree")

func test_set_path_clears_previous_state() -> void:
	var tree := _create_test_tree([_create_test_node("a")])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(5)
	_manager.purchase_node("a")
	# Set same path again to reset
	_manager.set_path("test_path")
	assert_eq(_manager.get_point_balance(), 0, "should reset points")
	assert_eq(_manager.get_node_purchase_count("a"), 0, "should reset purchases")

# ----- Purchase validation -----

func test_can_purchase_with_enough_points() -> void:
	var node_a := _create_test_node("a", 2)
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(2)
	assert_true(_manager.can_purchase_node("a"), "should be purchasable with enough points")

func test_cannot_purchase_without_enough_points() -> void:
	var node_a := _create_test_node("a", 5)
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(3)
	assert_false(_manager.can_purchase_node("a"), "should not be purchasable without enough points")

func test_cannot_purchase_at_max_level() -> void:
	var node_a := _create_test_node("a", 1, [], 1)
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(5)
	_manager.purchase_node("a")
	assert_false(_manager.can_purchase_node("a"), "should not be purchasable at max level")

func test_cannot_purchase_without_prerequisites() -> void:
	var node_a := _create_test_node("a")
	var node_b := _create_test_node("b", 1, ["a"])
	var tree := _create_test_tree([node_a, node_b])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(5)
	assert_false(_manager.can_purchase_node("b"), "should not be purchasable without prereqs")

func test_can_purchase_with_prerequisites_met() -> void:
	var node_a := _create_test_node("a")
	var node_b := _create_test_node("b", 1, ["a"])
	var tree := _create_test_tree([node_a, node_b])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(5)
	_manager.purchase_node("a")
	assert_true(_manager.can_purchase_node("b"), "should be purchasable with prereqs met")

func test_cannot_purchase_without_no_path_set() -> void:
	assert_false(_manager.can_purchase_node("anything"), "should not purchase without a path set")

# ----- Purchase execution -----

func test_purchase_deducts_points() -> void:
	var node_a := _create_test_node("a", 3)
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(5)
	_manager.purchase_node("a")
	assert_eq(_manager.get_point_balance(), 2, "should deduct 3 points from 5")

func test_purchase_increments_level() -> void:
	var node_a := _create_test_node("a", 1, [], 3)
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(5)
	_manager.purchase_node("a")
	assert_eq(_manager.get_node_purchase_count("a"), 1, "should be level 1")
	_manager.purchase_node("a")
	assert_eq(_manager.get_node_purchase_count("a"), 2, "should be level 2")

func test_purchase_emits_signal() -> void:
	var node_a := _create_test_node("a")
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(5)
	watch_signals(_manager)
	_manager.purchase_node("a")
	assert_signal_emitted_with_parameters(_manager, "node_purchased", ["a", 1])

func test_failed_purchase_returns_false() -> void:
	var node_a := _create_test_node("a", 10)
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(1)
	var result: bool = _manager.purchase_node("a")
	assert_false(result, "should return false when purchase fails")
	assert_eq(_manager.get_point_balance(), 1, "should not deduct points on failure")

# ----- Effect aggregation -----

func test_effects_empty_by_default() -> void:
	var effects: PathEffectsSummary = _manager.get_effects()
	assert_eq(effects.madra_generation_mult, 1.0, "default madra gen mult should be 1.0")
	assert_eq(effects.madra_capacity_bonus, 0.0, "default madra cap bonus should be 0.0")

func test_additive_effect_applied() -> void:
	var node_a := _create_test_node("a")
	node_a.effects = [_create_test_effect(PathNodeEffectData.EffectType.MADRA_CAPACITY_BONUS, 25.0)]
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(5)
	_manager.purchase_node("a")
	var effects: PathEffectsSummary = _manager.get_effects()
	assert_eq(effects.madra_capacity_bonus, 25.0, "should have +25 madra cap")

func test_multiplicative_effect_applied() -> void:
	var node_a := _create_test_node("a")
	node_a.effects = [_create_test_effect(PathNodeEffectData.EffectType.MADRA_GENERATION_MULT, 1.1)]
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(5)
	_manager.purchase_node("a")
	var effects: PathEffectsSummary = _manager.get_effects()
	assert_almost_eq(effects.madra_generation_mult, 1.1, 0.001, "should have 1.1x madra gen")

func test_repeatable_effects_stack() -> void:
	var node_a := _create_test_node("a", 1, [], 5)
	node_a.effects = [_create_test_effect(PathNodeEffectData.EffectType.ADVENTURE_MADRA_RETURN_PCT, 0.1)]
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(10)
	_manager.purchase_node("a")
	_manager.purchase_node("a")
	_manager.purchase_node("a")
	var effects: PathEffectsSummary = _manager.get_effects()
	assert_almost_eq(effects.adventure_madra_return_pct, 0.3, 0.001, "should have 30% madra return at level 3")

func test_adventure_madra_return_capped_at_100() -> void:
	var node_a := _create_test_node("a", 1, [], 20)
	node_a.effects = [_create_test_effect(PathNodeEffectData.EffectType.ADVENTURE_MADRA_RETURN_PCT, 0.1)]
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(20)
	for i in 15:
		_manager.purchase_node("a")
	var effects: PathEffectsSummary = _manager.get_effects()
	assert_almost_eq(effects.adventure_madra_return_pct, 1.0, 0.001, "should cap at 100%")

# ----- Unlock effects -----

func test_ability_unlock_tracked() -> void:
	var node_a := _create_test_node("a")
	var effect := PathNodeEffectData.new()
	effect.effect_type = PathNodeEffectData.EffectType.UNLOCK_ABILITY
	effect.string_value = "res://resources/abilities/empty_palm.tres"
	node_a.effects = [effect]
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(5)
	_manager.purchase_node("a")
	var unlocked: Array[String] = _manager.get_unlocked_abilities()
	assert_eq(unlocked.size(), 1, "should have 1 unlocked ability")
	assert_eq(unlocked[0], "res://resources/abilities/empty_palm.tres", "should be empty_palm")

func test_cycling_technique_unlock_tracked() -> void:
	var node_a := _create_test_node("a")
	var effect := PathNodeEffectData.new()
	effect.effect_type = PathNodeEffectData.EffectType.UNLOCK_CYCLING_TECHNIQUE
	effect.string_value = "smooth_flow"
	node_a.effects = [effect]
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(5)
	_manager.purchase_node("a")
	var unlocked: Array[String] = _manager.get_unlocked_cycling_techniques()
	assert_eq(unlocked.size(), 1, "should have 1 unlocked technique")
	assert_eq(unlocked[0], "smooth_flow", "should be smooth_flow")

func test_duplicate_unlocks_not_added() -> void:
	var node_a := _create_test_node("a", 1, [], 3)
	var effect := PathNodeEffectData.new()
	effect.effect_type = PathNodeEffectData.EffectType.UNLOCK_ABILITY
	effect.string_value = "res://resources/abilities/empty_palm.tres"
	node_a.effects = [effect]
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(5)
	_manager.purchase_node("a")
	_manager.purchase_node("a")
	var unlocked: Array[String] = _manager.get_unlocked_abilities()
	assert_eq(unlocked.size(), 1, "should not duplicate unlock on re-purchase")

# ----- Reset -----

func test_reset_clears_all_state() -> void:
	var node_a := _create_test_node("a")
	var tree := _create_test_tree([node_a])
	_manager._all_trees["test_path"] = tree
	_manager.set_path("test_path")
	_manager.add_points(5)
	_manager.purchase_node("a")
	_manager.reset_path()
	assert_null(_manager.get_current_tree(), "tree should be null after reset")
	assert_eq(_manager.get_point_balance(), 0, "points should be 0 after reset")
	assert_eq(_manager.get_node_purchase_count("a"), 0, "purchases should be cleared")
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gtest=test_path_manager.gd -gexit`

Expected: Tests fail (PathManager class not yet loadable without autoload, but test structure validates).

Note: Since PathManager references PersistenceManager and CultivationManager singletons, the tests inject `_live_save_data` directly and bypass `_ready()`. The `_is_stage_reached` method may need stubbing if CultivationManager is not available in the test runner. If tests fail due to CultivationManager reference, add a `_current_stage_override` test helper:

Add to PathManager for testability:

```gdscript
## Test-only: override stage check. Set to -1 to use real CultivationManager.
var _test_stage_override: int = -1

func _is_stage_reached(required: CultivationManager.AdvancementStage) -> bool:
	if _test_stage_override >= 0:
		return _test_stage_override >= required
	if not CultivationManager:
		return false
	return CultivationManager.get_current_advancement_stage() >= required
```

And in tests, add to `before_each()`:

```gdscript
	_manager._test_stage_override = CultivationManager.AdvancementStage.JADE  # Allow all stages in tests
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gtest=test_path_manager.gd -gexit`

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add singletons/path_manager/path_manager.gd tests/unit/test_path_manager.gd
git commit -m "feat(progression): add PathManager singleton with purchase logic and tests"
```

---

## Task 6: Register PathManager Autoload

**Files:**
- Modify: `project.godot`

- [ ] **Step 1: Add PathManager to autoloads**

Add the following line to the `[autoload]` section in `project.godot`, after `LogManager`:

```
PathManager="*res://singletons/path_manager/path_manager.gd"
```

- [ ] **Step 2: Run all existing tests to verify nothing is broken**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit`

Expected: All tests pass (both existing and new PathManager tests).

- [ ] **Step 3: Commit**

```bash
git add project.godot
git commit -m "chore(progression): register PathManager autoload"
```

---

## Task 7: CultivationManager Integration -- Point Awards

**Files:**
- Modify: `singletons/cultivation_manager/cultivation_manager.gd`

- [ ] **Step 1: Add path point award on Core Density level-up**

In `cultivation_manager.gd`, find the function that handles Core Density level-ups (the function that emits `core_density_level_updated`). Add path point award logic after the level-up:

```gdscript
## Points awarded per Core Density level milestone, indexed by advancement stage.
const PATH_POINTS_PER_STAGE: Dictionary = {
	AdvancementStage.FOUNDATION: 1,
	AdvancementStage.COPPER: 2,
	AdvancementStage.IRON: 3,
	AdvancementStage.JADE: 4,
}
const PATH_POINT_LEVEL_INTERVAL: int = 10
```

In the level-up logic, after incrementing the level and emitting the signal, add:

```gdscript
	# Award path points every PATH_POINT_LEVEL_INTERVAL levels
	if int(_live_save_data.core_density_level) % PATH_POINT_LEVEL_INTERVAL == 0 and int(_live_save_data.core_density_level) > 0:
		var points: int = PATH_POINTS_PER_STAGE.get(_live_save_data.current_advancement_stage, 1)
		if PathManager:
			PathManager.add_points(points)
```

- [ ] **Step 2: Commit**

```bash
git add singletons/cultivation_manager/cultivation_manager.gd
git commit -m "feat(progression): award path points on Core Density level milestones"
```

---

## Task 8: Pure Madra Tier 1 Content -- Resource Files

**Files:**
- Create: `resources/path_progression/pure_madra/pure_madra_tree.tres`
- Create: `resources/path_progression/pure_madra/nodes/` -- individual node .tres files

This task creates the actual content for the Pure Madra Tier 1 tree. Each node is a `.tres` file instantiating PathNodeData. The tree file references all nodes.

- [ ] **Step 1: Create node .tres files via script**

Create a temporary GDScript tool to generate the resources, or create them manually in the editor. The nodes for Tier 1 are:

| ID | Name | Type | Cost | Max | Prerequisites | Effects |
|----|------|------|------|-----|---------------|---------|
| `pure_core_awakening` | Pure Core Awakening | KEYSTONE | 1 | 1 | none | UNLOCK_ABILITY: empty_palm.tres, UNLOCK_CYCLING_TECHNIQUE: smooth_flow |
| `madra_strike` | Madra Strike | KEYSTONE | 2 | 1 | `pure_core_awakening` | UNLOCK_ABILITY: madra_strike.tres |
| `torrent_flow` | Torrent Flow | MAJOR | 2 | 1 | `pure_core_awakening` | UNLOCK_CYCLING_TECHNIQUE: torrent_flow |
| `cycling_accuracy` | Cycling Focus | MINOR | 1 | 1 | `pure_core_awakening` | CYCLING_ACCURACY_BONUS +15.0 |
| `madra_gen_up` | Madra Surge | REPEATABLE | 1 | 3 | `pure_core_awakening` | MADRA_GENERATION_MULT 1.1 |
| `madra_capacity` | Expanded Core | MINOR | 1 | 1 | `pure_core_awakening` | MADRA_CAPACITY_BONUS +25.0 |
| `empty_palm_duration` | Lingering Silence | MAJOR | 1 | 1 | `pure_core_awakening` | (Empty Palm duration marker) |
| `empty_palm_cost` | Efficient Palm | MINOR | 1 | 1 | `empty_palm_duration` | (Empty Palm cost reduction marker) |
| `madra_strike_damage` | Focused Strike | MAJOR | 1 | 1 | `madra_strike` | (Madra Strike damage marker) |
| `madra_strike_efficiency` | Strike Efficiency | MINOR | 1 | 1 | `madra_strike` | (Stamina cost reduction marker) |
| `stamina_recovery` | Iron Will | MAJOR | 1 | 1 | `pure_core_awakening` | STAMINA_RECOVERY_MULT 1.2 |
| `core_xp_boost` | Dedicated Cultivation | REPEATABLE | 1 | 3 | `pure_core_awakening` | CORE_DENSITY_XP_MULT 1.1 |
| `madra_on_levelup` | Breakthrough Surge | MINOR | 1 | 1 | `core_xp_boost` | MADRA_ON_LEVEL_UP 10.0 |
| `adventure_madra_return` | Madra Reclamation | REPEATABLE | 1 | 5 | `pure_core_awakening` | ADVENTURE_MADRA_RETURN_PCT 0.1 |

**Total tree cost:** ~22 points (with repeatables maxed). With ~10 points available in Foundation, player completes ~60-70%.

Note: Nodes marked with "(marker)" effects don't have numeric PathNodeEffectData yet because they unlock abilities or modify systems not yet integrated. These will be wired up during the ability rework. For now they exist in the tree and are purchasable but their effects are descriptive only (shown in tooltip via description text).

The preferred method is to create these in the Godot editor by:
1. Create a new PathNodeData resource for each
2. Set the exported properties in the Inspector
3. Save each as a `.tres` file in `resources/path_progression/pure_madra/nodes/`
4. Create a PathTreeData resource referencing all nodes

If creating programmatically, use a tool script:

```gdscript
# Snippet for creating pure_core_awakening.tres
var node := PathNodeData.new()
node.id = "pure_core_awakening"
node.display_name = "Pure Core Awakening"
node.description = "Establish your Pure Madra identity. Unlocks the Empty Palm combat technique and Smooth Flow cycling technique."
node.node_type = PathNodeData.NodeType.KEYSTONE
node.required_stage = CultivationManager.AdvancementStage.FOUNDATION
node.point_cost = 1
node.max_purchases = 1
node.prerequisites = []
node.effects = []
ResourceSaver.save(node, "res://resources/path_progression/pure_madra/nodes/pure_core_awakening.tres")
```

Repeat for each node listed above.

- [ ] **Step 2: Create the tree resource**

```gdscript
var tree := PathTreeData.new()
tree.path_id = "pure_madra"
tree.path_name = "Pure Madra"
tree.path_description = "The path of Pure Madra. Versatile and balanced, specializing in disruption and neutralization of enemy techniques."
tree.nodes = [
	load("res://resources/path_progression/pure_madra/nodes/pure_core_awakening.tres"),
	load("res://resources/path_progression/pure_madra/nodes/madra_strike.tres"),
	load("res://resources/path_progression/pure_madra/nodes/torrent_flow.tres"),
	load("res://resources/path_progression/pure_madra/nodes/cycling_accuracy.tres"),
	load("res://resources/path_progression/pure_madra/nodes/madra_gen_up.tres"),
	load("res://resources/path_progression/pure_madra/nodes/madra_capacity.tres"),
	load("res://resources/path_progression/pure_madra/nodes/empty_palm_duration.tres"),
	load("res://resources/path_progression/pure_madra/nodes/empty_palm_cost.tres"),
	load("res://resources/path_progression/pure_madra/nodes/madra_strike_damage.tres"),
	load("res://resources/path_progression/pure_madra/nodes/madra_strike_efficiency.tres"),
	load("res://resources/path_progression/pure_madra/nodes/stamina_recovery.tres"),
	load("res://resources/path_progression/pure_madra/nodes/core_xp_boost.tres"),
	load("res://resources/path_progression/pure_madra/nodes/madra_on_levelup.tres"),
	load("res://resources/path_progression/pure_madra/nodes/adventure_madra_return.tres"),
]
ResourceSaver.save(tree, "res://resources/path_progression/pure_madra/pure_madra_tree.tres")
```

- [ ] **Step 3: Validate tree**

Write a quick test to load and validate:

```gdscript
func test_pure_madra_tree_validates() -> void:
	var tree: PathTreeData = load("res://resources/path_progression/pure_madra/pure_madra_tree.tres")
	assert_not_null(tree, "tree should load")
	assert_true(tree.validate(), "tree should be valid")
	assert_eq(tree.path_id, "pure_madra", "should have correct path_id")
	assert_gt(tree.nodes.size(), 0, "should have nodes")
```

- [ ] **Step 4: Commit**

```bash
git add resources/path_progression/
git commit -m "feat(progression): add Pure Madra Tier 1 content resources"
```

---

## Task 9: Scene-Based Layout System

**Files:**
- Create: `scenes/path_progression/layouts/pure_madra_tier1_layout.tscn`

- [ ] **Step 1: Create the layout scene**

Create a scene with `Node2D` as root. Add child `Marker2D` nodes for each path node, named matching the node IDs:

Scene structure:
```
Node2D (root, named "PureMadraTier1Layout")
  |- Marker2D (named "pure_core_awakening") @ position (400, 300)
  |- Marker2D (named "madra_strike") @ position (600, 200)
  |- Marker2D (named "torrent_flow") @ position (600, 400)
  |- Marker2D (named "cycling_accuracy") @ position (200, 200)
  |- Marker2D (named "madra_gen_up") @ position (200, 400)
  |- Marker2D (named "madra_capacity") @ position (200, 300)
  |- Marker2D (named "empty_palm_duration") @ position (500, 100)
  |- Marker2D (named "empty_palm_cost") @ position (700, 100)
  |- Marker2D (named "madra_strike_damage") @ position (800, 200)
  |- Marker2D (named "madra_strike_efficiency") @ position (800, 300)
  |- Marker2D (named "stamina_recovery") @ position (400, 500)
  |- Marker2D (named "core_xp_boost") @ position (300, 500)
  |- Marker2D (named "madra_on_levelup") @ position (300, 600)
  |- Marker2D (named "adventure_madra_return") @ position (500, 500)
```

These positions are starting values. Adjust in the Godot 2D editor by dragging markers to desired positions. The key requirement is that marker names match node IDs exactly.

- [ ] **Step 2: Create layout reader utility**

Add a static helper to read positions from a layout scene. Put this in the path tree view script (Task 10), or as a utility:

```gdscript
## Reads node positions from a layout scene. Returns Dictionary[String, Vector2].
static func read_layout_positions(layout_scene: PackedScene) -> Dictionary:
	var positions: Dictionary = {}
	var root: Node2D = layout_scene.instantiate()
	for child: Node in root.get_children():
		if child is Marker2D:
			positions[child.name] = child.position
	root.queue_free()
	return positions
```

- [ ] **Step 3: Commit**

```bash
git add scenes/path_progression/layouts/
git commit -m "feat(progression): add scene-based layout system with Pure Madra positions"
```

---

## Task 10: Path Tree UI -- View Container

**Files:**
- Create: `scenes/path_progression/path_tree_view.tscn`
- Create: `scenes/path_progression/path_tree_view.gd`

- [ ] **Step 1: Create the path tree view script**

This is the main container that renders the full tree. Handles panning, instantiates nodes, draws connections.

```gdscript
class_name PathTreeView
extends Control

## The layout scene containing Marker2D nodes for positioning.
@export var layout_scene: PackedScene
## The PackedScene for individual node UI elements.
@export var path_node_ui_scene: PackedScene

@onready var node_container: Control = %NodeContainer
@onready var points_label: Label = %PointsLabel

var _node_positions: Dictionary = {}  # node_id -> Vector2
var _node_uis: Dictionary = {}  # node_id -> PathNodeUI
var _is_panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO

const NODE_SIZE := Vector2(64, 64)

func _ready() -> void:
	if layout_scene:
		_node_positions = PathTreeView.read_layout_positions(layout_scene)
	PathManager.node_purchased.connect(_on_node_purchased)
	PathManager.points_changed.connect(_on_points_changed)
	PathManager.path_set.connect(_on_path_set)
	_build_tree()
	_update_points_display()

func _build_tree() -> void:
	# Clear existing
	for child: Node in node_container.get_children():
		child.queue_free()
	_node_uis.clear()

	var tree: PathTreeData = PathManager.get_current_tree()
	if tree == null:
		return

	for node_data: PathNodeData in tree.nodes:
		var node_ui: Control = path_node_ui_scene.instantiate()
		node_ui.setup(node_data, PathManager.get_node_purchase_count(node_data.id))
		node_ui.node_clicked.connect(_on_node_clicked)

		var pos: Vector2 = _node_positions.get(node_data.id, Vector2.ZERO)
		node_ui.position = pos - NODE_SIZE / 2.0

		_node_uis[node_data.id] = node_ui
		node_container.add_child(node_ui)

	node_container.queue_redraw()

func _on_node_clicked(node_id: String) -> void:
	PathManager.purchase_node(node_id)

func _on_node_purchased(_node_id: String, _new_level: int) -> void:
	_refresh_all_nodes()
	node_container.queue_redraw()

func _on_points_changed(_new_balance: int) -> void:
	_update_points_display()

func _on_path_set(_tree: PathTreeData) -> void:
	_build_tree()

func _refresh_all_nodes() -> void:
	var tree: PathTreeData = PathManager.get_current_tree()
	if tree == null:
		return
	for node_data: PathNodeData in tree.nodes:
		if _node_uis.has(node_data.id):
			var node_ui: Control = _node_uis[node_data.id]
			node_ui.refresh(
				PathManager.get_node_purchase_count(node_data.id),
				PathManager.can_purchase_node(node_data.id)
			)

func _update_points_display() -> void:
	if points_label:
		points_label.text = "Path Points: %d" % PathManager.get_point_balance()

# ----- Panning -----

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_panning = true
				_pan_start = event.position
			else:
				_is_panning = false
	elif event is InputEventMouseMotion and _is_panning:
		var delta: Vector2 = event.position - _pan_start
		node_container.position += delta
		_pan_start = event.position

# ----- Layout reader -----

## Reads node positions from a layout scene. Returns Dictionary[String, Vector2].
static func read_layout_positions(layout_scene_resource: PackedScene) -> Dictionary:
	var positions: Dictionary = {}
	var root: Node = layout_scene_resource.instantiate()
	for child: Node in root.get_children():
		if child is Marker2D:
			positions[child.name] = child.position
	root.queue_free()
	return positions
```

- [ ] **Step 2: Create the scene file**

Build `path_tree_view.tscn` in the editor with this structure:

```
Control (root, script: path_tree_view.gd)
  |- PanelContainer (anchors: full rect, for background)
  |    |- (theme override: use existing panel style from assets/themes/)
  |- Control (unique name: %NodeContainer, anchors: full rect)
  |    |- (this is the pannable canvas, nodes are added as children)
  |- MarginContainer (anchors: top-left, margin 16px)
  |    |- Label (unique name: %PointsLabel, text: "Path Points: 0")
```

Set the `layout_scene` and `path_node_ui_scene` exports in the Inspector after creating the other scenes.

- [ ] **Step 3: Add connection drawing to NodeContainer**

The NodeContainer needs to draw connection lines. Create a custom Control script for it:

```gdscript
class_name PathNodeContainer
extends Control

## Reference to the parent view to access node positions and tree data.
var path_tree_view: PathTreeView

func _draw() -> void:
	if not PathManager or PathManager.get_current_tree() == null:
		return

	var tree: PathTreeData = PathManager.get_current_tree()
	var node_size := PathTreeView.NODE_SIZE

	for node_data: PathNodeData in tree.nodes:
		if node_data.prerequisites.is_empty():
			continue
		var node_ui: Control = path_tree_view._node_uis.get(node_data.id)
		if node_ui == null or not node_ui.visible:
			continue

		var end_pos: Vector2 = node_ui.position + node_size / 2.0

		for prereq_id: String in node_data.prerequisites:
			var prereq_ui: Control = path_tree_view._node_uis.get(prereq_id)
			if prereq_ui == null or not prereq_ui.visible:
				continue

			var start_pos: Vector2 = prereq_ui.position + node_size / 2.0
			var prereq_level: int = PathManager.get_node_purchase_count(prereq_id)
			var node_level: int = PathManager.get_node_purchase_count(node_data.id)

			var line_color: Color
			if node_level > 0:
				line_color = Color("a89070")  # Purchased: warm gold (EndlessPath theme)
			elif prereq_level > 0:
				line_color = Color.WHITE      # Available: white
			else:
				line_color = Color(1, 1, 1, 0.2)  # Locked: dim

			draw_line(start_pos, end_pos, line_color, 2.0, true)
```

- [ ] **Step 4: Commit**

```bash
git add scenes/path_progression/path_tree_view.tscn scenes/path_progression/path_tree_view.gd scenes/path_progression/path_node_container.gd
git commit -m "feat(progression): add path tree view with panning and connection drawing"
```

---

## Task 11: Path Node UI Component

**Files:**
- Create: `scenes/path_progression/path_node_ui.tscn`
- Create: `scenes/path_progression/path_node_ui.gd`

- [ ] **Step 1: Create the node UI script**

```gdscript
class_name PathNodeUI
extends TextureButton

## Emitted when the player clicks this node.
signal node_clicked(node_id: String)

const HOVER_SCALE: float = 1.15
const HOVER_DURATION: float = 0.12

var _node_data: PathNodeData = null
var _current_level: int = 0
var _original_scale: Vector2

@onready var level_label: Label = %LevelLabel
@onready var border: Panel = %Border
@onready var tooltip_control: Control = %Tooltip

func _ready() -> void:
	_original_scale = scale
	pivot_offset = size / 2.0
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## Initialize with node data and current purchase level.
func setup(data: PathNodeData, current_level: int) -> void:
	_node_data = data
	_current_level = current_level
	if data.icon:
		texture_normal = data.icon
	_update_display()

## Refresh display after a purchase or state change.
func refresh(current_level: int, can_afford: bool) -> void:
	_current_level = current_level
	_update_display()

func _update_display() -> void:
	if _node_data == null:
		return

	# Level label (only show for repeatable nodes)
	if _node_data.is_repeatable():
		level_label.visible = true
		level_label.text = "%d/%d" % [_current_level, _node_data.max_purchases]
	else:
		level_label.visible = false

	# Border color based on state
	var is_maxed: bool = _current_level >= _node_data.max_purchases
	var is_purchased: bool = _current_level > 0
	var can_purchase: bool = PathManager.can_purchase_node(_node_data.id) if PathManager else false

	var border_style: StyleBoxFlat = border.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if is_maxed:
		border_style.border_color = Color("a89070")  # Gold for maxed
	elif is_purchased:
		border_style.border_color = Color.WHITE
	elif can_purchase:
		border_style.border_color = Color(1, 1, 1, 0.6)  # Bright: available
	else:
		border_style.border_color = Color(1, 1, 1, 0.2)  # Dim: locked
	border.add_theme_stylebox_override("panel", border_style)

	# Dim overlay for unpurchasable
	modulate.a = 1.0 if (can_purchase or is_purchased) else 0.5

func _on_pressed() -> void:
	if _node_data:
		node_clicked.emit(_node_data.id)

func _on_mouse_entered() -> void:
	_animate_hover(true)
	if tooltip_control and tooltip_control.has_method("show_tooltip"):
		tooltip_control.show_tooltip(_node_data, _current_level)

func _on_mouse_exited() -> void:
	_animate_hover(false)
	if tooltip_control and tooltip_control.has_method("hide_tooltip"):
		tooltip_control.hide_tooltip()

func _animate_hover(hovering: bool) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT if hovering else Tween.EASE_IN)
	var target: Vector2 = _original_scale * HOVER_SCALE if hovering else _original_scale
	tween.tween_property(self, "scale", target, HOVER_DURATION)
```

- [ ] **Step 2: Create the scene file**

Build `path_node_ui.tscn` in the editor:

```
TextureButton (root, 64x64, script: path_node_ui.gd)
  |- Panel (unique name: %Border, anchors: full rect, 3px border StyleBoxFlat, transparent bg)
  |- Label (unique name: %LevelLabel, anchors: bottom-right, small font)
  |- PathNodeTooltip (unique name: %Tooltip, instance of path_node_tooltip.tscn)
```

- [ ] **Step 3: Commit**

```bash
git add scenes/path_progression/path_node_ui.tscn scenes/path_progression/path_node_ui.gd
git commit -m "feat(progression): add path node UI component with hover and purchase"
```

---

## Task 12: Path Node Tooltip

**Files:**
- Create: `scenes/path_progression/path_node_tooltip.tscn`
- Create: `scenes/path_progression/path_node_tooltip.gd`

- [ ] **Step 1: Create tooltip script**

```gdscript
class_name PathNodeTooltip
extends Control

@onready var name_label: Label = %NameLabel
@onready var type_label: Label = %TypeLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var cost_label: Label = %CostLabel
@onready var level_label: Label = %LevelLabel

const SHOW_DURATION: float = 0.15

func _ready() -> void:
	visible = false

## Show the tooltip with data for the given node.
func show_tooltip(data: PathNodeData, current_level: int) -> void:
	if data == null:
		return

	name_label.text = data.display_name
	type_label.text = PathNodeData.NodeType.keys()[data.node_type].capitalize()
	description_label.text = data.description
	cost_label.text = "Cost: %d point%s" % [data.point_cost, "s" if data.point_cost != 1 else ""]

	if data.is_repeatable():
		level_label.visible = true
		level_label.text = "Level: %d / %d" % [current_level, data.max_purchases]
	else:
		level_label.visible = current_level > 0
		level_label.text = "Purchased" if current_level > 0 else ""

	visible = true
	scale = Vector2(1, 0.2)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, SHOW_DURATION)

## Hide the tooltip with animation.
func hide_tooltip() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(1, 0.2), SHOW_DURATION * 0.5)
	tween.tween_callback(func() -> void: visible = false)
```

- [ ] **Step 2: Create the scene file**

Build `path_node_tooltip.tscn` in the editor:

```
Control (root, script: path_node_tooltip.gd, min size: 200x150)
  |- PanelContainer (anchors: full rect, theme: dark semi-transparent panel)
  |    |- VBoxContainer (margin 8px)
  |    |    |- Label (unique name: %NameLabel, bold, larger font)
  |    |    |- Label (unique name: %TypeLabel, smaller font, dim color)
  |    |    |- HSeparator
  |    |    |- RichTextLabel (unique name: %DescriptionLabel, fit_content=true, bbcode_enabled=true)
  |    |    |- HSeparator
  |    |    |- Label (unique name: %CostLabel)
  |    |    |- Label (unique name: %LevelLabel)
```

Position the tooltip above the node (negative Y offset) so it doesn't overlap.

- [ ] **Step 3: Commit**

```bash
git add scenes/path_progression/path_node_tooltip.tscn scenes/path_progression/path_node_tooltip.gd
git commit -m "feat(progression): add path node tooltip with animated show/hide"
```

---

## Task 13: MainView State Integration

**Files:**
- Create: `scenes/path_progression/path_tree_view_state.gd`
- Modify: `scenes/ui/main_view/main_view.gd`
- Modify: `scenes/ui/main_view/main_view.tscn`

- [ ] **Step 1: Create PathTreeViewState**

```gdscript
class_name PathTreeViewState
extends MainViewState

## View state for the path progression tree. Entered via input action
## or system menu button. Shows the full path tree for the current run.

func enter() -> void:
	if scene_root.has_node("PathTreeView"):
		scene_root.get_node("PathTreeView").visible = true

func exit() -> void:
	if scene_root.has_node("PathTreeView"):
		scene_root.get_node("PathTreeView").visible = false

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_path_tree"):
		scene_root.pop_state()
	elif event.is_action_pressed("ui_cancel"):
		scene_root.pop_state()
```

- [ ] **Step 2: Add input action to project.godot**

Add `open_path_tree` input action mapped to the `P` key (or another available key). Add to `project.godot` under `[input]`:

```
open_path_tree={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":80,"physical_keycode":0,"key_label":0,"unicode":112,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 3: Wire into MainView**

In `main_view.gd`, add:

```gdscript
@onready var path_tree_view_state: MainViewState = %MainViewStateMachine/PathTreeViewState
```

And in `_ready()`:

```gdscript
	path_tree_view_state.scene_root = self
```

In `main_view.tscn`:
1. Add a `PathTreeViewState` node as a child of `MainViewStateMachine`
2. Add a `PathTreeView` instance as a child of `MainView`, initially hidden
3. Set the `layout_scene` export on the PathTreeView to the Pure Madra layout scene
4. Set the `path_node_ui_scene` export to the PathNodeUI scene

- [ ] **Step 4: Add state transition from ZoneViewState**

In the ZoneViewState (or wherever input is handled for the zone view), add handling for the path tree input:

```gdscript
	if event.is_action_pressed("open_path_tree"):
		scene_root.push_state(scene_root.path_tree_view_state)
```

- [ ] **Step 5: Commit**

```bash
git add scenes/path_progression/path_tree_view_state.gd scenes/ui/main_view/ project.godot
git commit -m "feat(progression): integrate path tree view into MainView state machine"
```

---

## Task 14: Run Full Test Suite and Smoke Test

- [ ] **Step 1: Run all unit tests**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit`

Expected: All tests pass, including existing tests and new PathManager tests.

- [ ] **Step 2: Launch the game and smoke test**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn`

Manual checks:
1. Game launches without errors
2. Press P to open path tree view
3. Tree displays with nodes and connections
4. Hovering nodes shows tooltip
5. Purchasing a node deducts points and updates display
6. Prerequisite nodes prevent purchase of locked nodes
7. Press Escape to close path tree view
8. Cycle to earn Core Density XP and verify path points are awarded every 10 levels

- [ ] **Step 3: Fix any issues found during smoke test**

Address console errors, visual bugs, or interaction problems.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "fix(progression): address smoke test issues"
```

Note: Only create this commit if there were fixes. Skip if smoke test passed clean.
