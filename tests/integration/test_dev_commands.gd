extends GutTest

## DevCommands against the real managers: what each command does, what it
## refuses, and what a refusal leaves alone. Each test binds a fresh save, calls the
## real autoloads, stops what it started and puts the original save back. A
## refusal is a returned reason, never a manager's push_error: GUT fails a test on
## an unexpected one, so a command that skips its own id check fails here.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const ZONE_ID: String = "SpiritValley"
const OTHER_ZONE_ID: String = "TestZone"

## NPC 1, "Talk to the [INTERVENER]": available on a fresh save and used up after
## one completion. Its success effects fire the event of the same name and start
## q_fill_core.
const NPC_1: String = "celestial_intervener_dialogue_1"
const NPC_1_EVENT: String = "celestial_intervener_dialogue_1"
const NPC_1_QUEST: String = "q_fill_core"
## NPC 2 unlocks once q_fill_core's Madra goal is met: locked on a fresh save.
const NPC_2: String = "celestial_intervener_dialogue_2"
const CYCLING_ACTION: String = "wilderness_cycling_action"
const ADVENTURE_ACTION: String = "shallow_woods_adventure_action"

## Fired when q_fill_core completes. It unlocks foraging, which then starts on its
## own (the first idle action to unlock does).
const FORAGING_EVENT: String = "q_fill_core_completed"
## Its condition unlocks the Aura Well's training, which starts on its own.
const AURA_WELL_EVENT: String = "aura_well_discovered"

const CRUDE_SCALE: String = "res://resources/items/consumables/crude_scale.tres"
const IRON_SHORTSWORD: String = "res://resources/items/equipment/spirit_valley/iron_shortsword.tres"
const PURE_MADRA_TREE: String = "res://resources/path_progression/pure_madra/pure_madra_tree.tres"
## A resource that loads fine and is not an item.
const QUEST_FILE: String = "res://resources/quests/q_fill_core.tres"

const DEV_LINE: String = "[color=magenta][DEV][/color] "

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _original_tree: PathTreeData
var _original_stage_override: int
var _original_stages: Array[AdvancementStageResource]
## The player's Health, Stamina and Madra: one object shared by every test.
var _original_vitals: Array[float] = []
## The hooks a test put on a manager signal to see recording_paused while a
## command ran, taken off again after the test.
var _probes: Array[Dictionary] = []

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_tree = PathManager.get_current_tree()
	_original_stage_override = PathManager._test_stage_override
	_original_stages = CultivationManager.advancement_stage_resources
	var vitals: VitalsManager = PlayerManager.vitals_manager
	_original_vitals = [vitals.current_health, vitals.current_stamina, vitals.current_madra]
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	# test_path_manager.gd leaves a one-entry ability index behind, no tree in
	# PathManager once its trees are cleared, and PathManager's stage override at
	# Jade. Start from the real ones: -1 makes PathManager read the player's stage.
	AbilityManager._build_catalog_index()
	PathManager._current_tree = load(PURE_MADRA_TREE)
	PathManager._test_stage_override = -1

func after_each() -> void:
	for probe: Dictionary in _probes:
		var emitted: Signal = probe["signal"]
		if emitted.is_connected(probe["hook"]):
			emitted.disconnect(probe["hook"])
	_probes.clear()
	CultivationManager.advancement_stage_resources = _original_stages
	_stop_actions()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	PathManager._current_tree = _original_tree
	PathManager._test_stage_override = _original_stage_override
	var vitals: VitalsManager = PlayerManager.vitals_manager
	vitals.current_health = _original_vitals[0]
	vitals.current_stamina = _original_vitals[1]
	vitals.current_madra = _original_vitals[2]
	# Binding the original save again resumes its idle action, if it has one.
	# Stop it, so its tick timer does not run on into the next test.
	_stop_actions()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _stop_actions() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func _stats() -> PlayStatsData:
	return PersistenceManager.save_game_data.stats

func _current_id() -> String:
	var current: ZoneActionData = ActionManager.get_current_action()
	return current.action_id if current else ""

func _completions(action_id: String) -> int:
	return ZoneManager.get_zone_progression(ZONE_ID).action_completion_count.get(action_id, 0)

func _start(action_id: String) -> void:
	ActionManager.select_action(ZoneManager.get_action_by_id(action_id))

## Every line the player's log got since watch_signals(LogManager).
func _logged_lines() -> Array[String]:
	var lines: Array[String] = []
	for index: int in maxi(get_signal_emit_count(LogManager, "message_logged"), 0):
		lines.append(get_signal_parameters(LogManager, "message_logged", index)[0])
	return lines

## The [DEV] lines among them.
func _dev_lines() -> Array[String]:
	var lines: Array[String] = []
	for line: String in _logged_lines():
		if line.begins_with(DEV_LINE):
			lines.append(line)
	return lines

func _logged_lines_with(text: String) -> Array[String]:
	var lines: Array[String] = []
	for line: String in _logged_lines():
		if line.contains(text):
			lines.append(line)
	return lines

## Makes the adventure the current action, which is what "an adventure runs" comes
## to for a command, and refills the vitals.
func _refill_vitals_during_an_adventure() -> String:
	_start(ADVENTURE_ACTION)
	return DevCommands.refill_vitals()

## Fills every slot of the equipment grid with an item instance.
func _fill_equipment_grid() -> void:
	var inventory: InventoryData = InventoryManager.get_inventory()
	for index: int in inventory.equipment_capacity():
		inventory.equipment[index] = ItemInstanceData.new()

func _node(node_id: String, point_cost: int, stage: CultivationManager.AdvancementStage = CultivationManager.AdvancementStage.FOUNDATION) -> PathNodeData:
	var node := PathNodeData.new()
	node.id = node_id
	node.display_name = node_id
	node.point_cost = point_cost
	node.required_stage = stage
	return node

## Makes PathManager's current tree a tree of just this node.
func _use_tree_of(node: PathNodeData) -> void:
	var tree := PathTreeData.new()
	tree.path_id = "dev_commands_test_path"
	tree.path_name = "Test Path"
	var nodes: Array[PathNodeData] = [node]
	tree.nodes = nodes
	PathManager._current_tree = tree

## Hooks `emitted` so that each emission notes whether recording was paused at
## that moment. Returns the notes, filled as the emissions come.
func _note_recording_on(emitted: Signal, argument_count: int) -> Array[bool]:
	var notes: Array[bool] = []
	var probe: Callable = func() -> void: notes.append(PersistenceManager.save_game_data.stats.recording_paused)
	var hook: Callable = probe.unbind(argument_count)
	emitted.connect(hook)
	_probes.append({"signal": emitted, "hook": hook})
	return notes

#-----------------------------------------------------------------------------
# COMPLETE ACTION
#-----------------------------------------------------------------------------

func test_complete_action_runs_its_effects() -> void:
	assert_eq(DevCommands.complete_action(NPC_1), "")
	assert_eq(_completions(NPC_1), 1, "one completion counts in Spirit Valley")
	assert_true(EventManager.has_event_triggered(NPC_1_EVENT), "its success effects ran")
	assert_true(QuestManager.has_active_quest(NPC_1_QUEST), "q_fill_core is active")
	assert_null(ActionManager.get_current_action(), "nothing was played")

func test_complete_action_skips_a_used_up_action() -> void:
	assert_eq(DevCommands.complete_action(NPC_1), "")
	watch_signals(LogManager)
	assert_eq(DevCommands.complete_action(NPC_1), "", "a used-up action is not a failure")
	assert_eq(_completions(NPC_1), 1, "and it counts nothing more")
	assert_eq(_dev_lines().size(), 0, "nor logs anything")

func test_complete_action_refuses_an_unavailable_action() -> void:
	var reason: String = DevCommands.complete_action(NPC_2)
	assert_eq(reason, "%s is not available now" % NPC_2)
	assert_string_contains(reason, "not available")
	assert_eq(_completions(NPC_2), 0, "nothing counted")
	assert_false(EventManager.has_event_triggered(NPC_2), "and none of its effects ran")

func test_complete_action_refuses_an_unknown_id() -> void:
	assert_ne(DevCommands.complete_action("not_an_action"), "")

func test_complete_action_refuses_when_there_is_no_current_zone() -> void:
	PersistenceManager.save_game_data.current_selected_zone_id = "Nowhere"
	assert_null(ZoneManager.get_current_zone(), "precondition: the save names no zone the game has")
	assert_ne(DevCommands.complete_action(NPC_1), "")

func test_complete_action_looks_only_in_the_current_zone() -> void:
	assert_eq(DevCommands.travel_to_zone(OTHER_ZONE_ID), "")
	assert_ne(DevCommands.complete_action(NPC_1), "", "NPC 1 belongs to Spirit Valley, not the Test Zone")
	assert_eq(_completions(NPC_1), 0)
	assert_false(EventManager.has_event_triggered(NPC_1_EVENT))

#-----------------------------------------------------------------------------
# EVENTS
#-----------------------------------------------------------------------------

func test_trigger_event_refuses_an_unknown_id() -> void:
	assert_ne(DevCommands.trigger_event("not_an_event"), "")
	assert_false(EventManager.has_event_triggered("not_an_event"))
	assert_true(EventManager.get_triggered_events().is_empty(), "nothing fired")

func test_trigger_event_twice_is_fine() -> void:
	assert_eq(DevCommands.trigger_event(AURA_WELL_EVENT), "")
	assert_eq(DevCommands.trigger_event(AURA_WELL_EVENT), "")
	assert_eq(EventManager.get_triggered_events().count(AURA_WELL_EVENT), 1, "it fired once")

#-----------------------------------------------------------------------------
# CORE DENSITY
#-----------------------------------------------------------------------------

func test_reach_core_density_pays_milestones() -> void:
	assert_eq(DevCommands.reach_core_density(20), "")
	assert_eq(CultivationManager.get_core_density_level(), 20.0)
	assert_eq(PathManager.get_point_balance(), 2, "levels 10 and 20 each paid a path point")

func test_reach_core_density_stops_at_the_cap() -> void:
	assert_eq(DevCommands.reach_core_density(150), "")
	assert_eq(CultivationManager.get_core_density_level(), 100.0)
	assert_true(CultivationManager.is_core_full())

func test_reach_core_density_does_nothing_at_or_above_the_target() -> void:
	assert_eq(DevCommands.reach_core_density(20), "")
	var points: int = PathManager.get_point_balance()
	watch_signals(LogManager)
	assert_eq(DevCommands.reach_core_density(10), "", "below the level it has")
	assert_eq(DevCommands.reach_core_density(20), "", "at the level it has")
	assert_eq(CultivationManager.get_core_density_level(), 20.0, "the level never drops")
	assert_eq(PathManager.get_point_balance(), points, "and nothing is paid twice")
	assert_eq(_dev_lines().size(), 0, "nothing was done, so nothing is logged")

## A stage whose levels cost no XP never levels, so the command's loop would never
## end. It refuses the moment an add of XP changes nothing.
func test_reach_core_density_refuses_a_stage_with_no_cost() -> void:
	var free_stage := AdvancementStageResource.new()
	free_stage.stage_name = "Free"
	free_stage.core_density_base_xp_cost = 0.0
	var stages: Array[AdvancementStageResource] = [free_stage]
	CultivationManager.advancement_stage_resources = stages
	assert_ne(DevCommands.reach_core_density(5), "")
	assert_eq(CultivationManager.get_core_density_level(), 0.0)

#-----------------------------------------------------------------------------
# MADRA, GOLD AND PATH POINTS
#-----------------------------------------------------------------------------

func test_set_madra_and_set_gold_set_exactly() -> void:
	assert_eq(DevCommands.set_madra(40.0), "")
	assert_eq(ResourceManager.get_madra(), 40.0)
	assert_eq(DevCommands.set_gold(700.0), "")
	assert_eq(ResourceManager.get_gold(), 700.0)

func test_set_madra_and_set_gold_refuse_a_negative_value() -> void:
	ResourceManager.set_madra(30.0)
	ResourceManager.set_gold(5.0)
	assert_ne(DevCommands.set_madra(-1.0), "")
	assert_ne(DevCommands.set_gold(-1.0), "")
	assert_eq(ResourceManager.get_madra(), 30.0, "Madra is left as it was")
	assert_eq(ResourceManager.get_gold(), 5.0, "and so is gold")

func test_add_path_points_adds_to_the_balance() -> void:
	assert_eq(DevCommands.add_path_points(3), "")
	assert_eq(DevCommands.add_path_points(2), "")
	assert_eq(PathManager.get_point_balance(), 5)

#-----------------------------------------------------------------------------
# PATH NODES
#-----------------------------------------------------------------------------

func test_buy_path_node_adds_only_missing_points() -> void:
	assert_eq(PathManager.get_point_balance(), 0, "precondition: no points")
	assert_eq(DevCommands.buy_path_node("pure_core_awakening"), "")
	assert_eq(PathManager.get_node_purchase_count("pure_core_awakening"), 1, "the node is bought")
	assert_eq(PathManager.get_point_balance(), 0, "it granted the one point the node costs, and spent it")
	assert_true(AbilityManager.is_ability_unlocked("empty_palm"), "the node's ability is unlocked")
	assert_true(CyclingManager.is_technique_unlocked("smooth_flow"), "and its technique")

func test_buy_path_node_spends_the_points_it_has_before_adding_any() -> void:
	PathManager.add_points(3)
	assert_eq(DevCommands.buy_path_node("pure_core_awakening"), "")
	assert_eq(PathManager.get_point_balance(), 2, "the node cost one of the three points")

func test_buy_path_node_grants_only_the_shortfall() -> void:
	_use_tree_of(_node("dev_commands_test_node", 3))
	PathManager.add_points(1)
	assert_eq(DevCommands.buy_path_node("dev_commands_test_node"), "")
	assert_eq(PathManager.get_node_purchase_count("dev_commands_test_node"), 1)
	assert_eq(PathManager.get_point_balance(), 0, "two points were missing: one in hand and two granted make the cost")

func test_buy_path_node_skips_a_bought_node() -> void:
	assert_eq(DevCommands.buy_path_node("pure_core_awakening"), "")
	watch_signals(LogManager)
	assert_eq(DevCommands.buy_path_node("pure_core_awakening"), "", "a bought node is not a failure")
	assert_eq(PathManager.get_node_purchase_count("pure_core_awakening"), 1, "it is not bought twice")
	assert_eq(PathManager.get_point_balance(), 0, "and no point is granted for it")
	assert_eq(_dev_lines().size(), 0, "nothing was done, so nothing is logged")

func test_buy_path_node_names_a_missing_prerequisite() -> void:
	var reason: String = DevCommands.buy_path_node("power_font")
	assert_string_contains(reason, "pure_core_awakening")
	assert_eq(PathManager.get_node_purchase_count("power_font"), 0, "the node is not bought")
	assert_eq(PathManager.get_point_balance(), 0, "a refusal grants no points")
	assert_false(AbilityManager.is_ability_unlocked("power_font"))

func test_buy_path_node_buys_a_node_after_its_prerequisite() -> void:
	assert_eq(DevCommands.buy_path_node("pure_core_awakening"), "")
	assert_eq(DevCommands.buy_path_node("power_font"), "")
	assert_true(AbilityManager.is_ability_unlocked("power_font"))

func test_buy_path_node_refuses_an_unknown_node() -> void:
	assert_ne(DevCommands.buy_path_node("not_a_node"), "")
	assert_eq(PathManager.get_point_balance(), 0, "a refusal grants no points")

func test_buy_path_node_refuses_when_no_path_is_chosen() -> void:
	PathManager._current_tree = null
	assert_ne(DevCommands.buy_path_node("pure_core_awakening"), "")
	assert_eq(PathManager.get_point_balance(), 0, "a refusal grants no points")

## A node PathManager will never sell (max_purchases 0, which a validated tree cannot
## hold) passes every check the command makes. PathManager still says no, and the
## command reports that instead of a purchase that did not happen.
func test_buy_path_node_reports_a_node_the_manager_will_not_sell() -> void:
	var node: PathNodeData = _node("dev_commands_test_node", 1)
	node.max_purchases = 0
	_use_tree_of(node)
	watch_signals(LogManager)
	var reason: String = DevCommands.buy_path_node("dev_commands_test_node")
	assert_string_contains(reason, "could not be bought")
	assert_eq(PathManager.get_node_purchase_count("dev_commands_test_node"), 0)
	assert_eq(_dev_lines().size(), 0, "so no success was logged")

## The command asks PathManager whether the stage is reached, so it agrees with the
## manager even under the manager's test-only stage override.
func test_buy_path_node_follows_the_managers_own_stage_rule() -> void:
	_use_tree_of(_node("dev_commands_test_node", 1, CultivationManager.AdvancementStage.COPPER))
	PathManager._test_stage_override = CultivationManager.AdvancementStage.JADE
	assert_eq(DevCommands.buy_path_node("dev_commands_test_node"), "", "the manager counts the stage as reached")
	assert_eq(PathManager.get_node_purchase_count("dev_commands_test_node"), 1)

func test_buy_path_node_refuses_a_stage_too_low() -> void:
	_use_tree_of(_node("dev_commands_test_node", 1, CultivationManager.AdvancementStage.COPPER))
	var reason: String = DevCommands.buy_path_node("dev_commands_test_node")
	assert_string_contains(reason, "Copper")
	assert_eq(PathManager.get_node_purchase_count("dev_commands_test_node"), 0)
	assert_eq(PathManager.get_point_balance(), 0, "a refusal grants no points")

#-----------------------------------------------------------------------------
# TECHNIQUES
#-----------------------------------------------------------------------------

func test_unlock_and_equip_technique() -> void:
	assert_false(CyclingManager.is_technique_unlocked("smooth_flow"), "precondition: locked on a fresh save")
	assert_eq(DevCommands.unlock_technique("smooth_flow"), "")
	assert_true(CyclingManager.is_technique_unlocked("smooth_flow"))
	assert_eq(DevCommands.equip_technique("smooth_flow"), "")
	assert_eq(CyclingManager.get_equipped_technique().id, "smooth_flow")
	watch_signals(LogManager)
	assert_eq(DevCommands.unlock_technique("smooth_flow"), "", "unlocking it again is fine")
	assert_eq(_dev_lines().size(), 0, "and does nothing, so logs nothing")

func test_technique_commands_refuse_an_unknown_id_and_equip_refuses_a_locked_one() -> void:
	assert_ne(DevCommands.unlock_technique("not_a_technique"), "")
	assert_ne(DevCommands.equip_technique("not_a_technique"), "")
	assert_ne(DevCommands.equip_technique("torrential_flow"), "", "it is locked")
	assert_false(CyclingManager.is_technique_unlocked("torrential_flow"), "equipping never unlocks")
	assert_eq(CyclingManager.get_equipped_technique().id, "foundation_technique", "the equipped one stays")

#-----------------------------------------------------------------------------
# ABILITIES
#-----------------------------------------------------------------------------

func test_equip_ability_uses_slots_one_to_four() -> void:
	assert_eq(DevCommands.unlock_ability("empty_palm"), "")
	assert_eq(DevCommands.equip_ability("empty_palm", 3), "")
	assert_eq(AbilityManager.get_ability_at_slot(2), "empty_palm", "slot 3 is index 2")
	for slot: int in [1, 2, 3, 4]:
		assert_eq(DevCommands.equip_ability("empty_palm", slot), "", "slot %d" % slot)
		assert_eq(AbilityManager.get_ability_at_slot(slot - 1), "empty_palm", "slot %d is index %d" % [slot, slot - 1])

func test_equip_ability_refuses_slot_zero_and_five() -> void:
	DevCommands.unlock_ability("empty_palm")
	var loadout: Array[String] = PersistenceManager.save_game_data.equipped_ability_ids.duplicate()
	for slot: int in [0, 5, -1]:
		assert_ne(DevCommands.equip_ability("empty_palm", slot), "", "slot %d" % slot)
	assert_eq(PersistenceManager.save_game_data.equipped_ability_ids, loadout, "the loadout is unchanged")

func test_ability_commands_refuse_an_unknown_id_and_equip_refuses_a_locked_one() -> void:
	var loadout: Array[String] = PersistenceManager.save_game_data.equipped_ability_ids.duplicate()
	assert_ne(DevCommands.unlock_ability("not_an_ability"), "")
	assert_ne(DevCommands.equip_ability("not_an_ability", 3), "")
	assert_ne(DevCommands.equip_ability("power_font", 3), "", "it is locked")
	assert_false(AbilityManager.is_ability_unlocked("power_font"), "equipping never unlocks")
	assert_eq(PersistenceManager.save_game_data.equipped_ability_ids, loadout, "the loadout is unchanged")

func test_unlock_ability_twice_is_fine() -> void:
	assert_eq(DevCommands.unlock_ability("empty_palm"), "")
	assert_true(AbilityManager.is_ability_unlocked("empty_palm"))
	watch_signals(LogManager)
	assert_eq(DevCommands.unlock_ability("empty_palm"), "")
	assert_eq(_dev_lines().size(), 0, "nothing was done, so nothing is logged")

#-----------------------------------------------------------------------------
# ITEMS
#-----------------------------------------------------------------------------

func test_award_item_by_path() -> void:
	assert_eq(DevCommands.award_item(CRUDE_SCALE, 3), "")
	var scale: ConsumableDefinitionData = load(CRUDE_SCALE)
	assert_eq(InventoryManager.get_inventory().consumables.get(scale), 3)

## The Items tab offers every path list_item_paths() returns, so each must award.
func test_every_listed_item_can_be_awarded() -> void:
	for path: String in DevCommands.list_item_paths():
		var item: ItemDefinitionData = load(path)
		assert_false(InventoryManager.has_item(item.item_id), "precondition: a fresh save holds no %s" % item.item_id)
		assert_eq(DevCommands.award_item(path, 1), "", path)
		assert_true(InventoryManager.has_item(item.item_id), "%s is in the inventory" % item.item_id)

func test_award_item_refuses_a_path_that_is_not_an_item_and_a_quantity_below_one() -> void:
	assert_ne(DevCommands.award_item(QUEST_FILE, 1), "", "a quest is not an item")
	assert_ne(DevCommands.award_item("res://resources/items/not_an_item.tres", 1), "", "a file that is not there")
	assert_ne(DevCommands.award_item("", 1), "")
	assert_ne(DevCommands.award_item(CRUDE_SCALE, 0), "")
	assert_ne(DevCommands.award_item(CRUDE_SCALE, -2), "")
	assert_true(InventoryManager.get_inventory().consumables.is_empty(), "nothing was awarded")

func test_award_equipment_fills_free_grid_slots() -> void:
	assert_eq(DevCommands.award_item(IRON_SHORTSWORD, 2), "")
	assert_eq(InventoryManager.get_inventory().equipment.size(), 2, "one instance for each copy")

## Review Focus 5: InventoryManager drops equipment that has no slot, and still
## logs "Looted". The command refuses before it gets that far.
func test_award_equipment_with_a_full_grid_fails() -> void:
	_fill_equipment_grid()
	var inventory: InventoryData = InventoryManager.get_inventory()
	var grid: Dictionary = inventory.equipment.duplicate()
	watch_signals(LogManager)
	watch_signals(InventoryManager)
	assert_eq(DevCommands.award_item(IRON_SHORTSWORD, 1), "Equipment is full")
	assert_eq(inventory.equipment, grid, "the grid is unchanged")
	assert_eq(_logged_lines_with("Looted").size(), 0, "no Looted line was logged")
	assert_eq(_dev_lines().size(), 0, "and no success was reported")
	assert_signal_not_emitted(InventoryManager, "item_awarded")

func test_award_equipment_needs_a_free_slot_for_every_copy() -> void:
	_fill_equipment_grid()
	var inventory: InventoryData = InventoryManager.get_inventory()
	inventory.equipment.erase(5)
	assert_eq(DevCommands.award_item(IRON_SHORTSWORD, 2), "Equipment is full", "two copies, one free slot")
	assert_false(inventory.equipment.has(5), "not even one of them was placed")
	assert_eq(DevCommands.award_item(IRON_SHORTSWORD, 1), "")
	assert_true(inventory.equipment.has(5), "one copy fits the one free slot")

func test_grant_equipment_page_adds_a_page() -> void:
	var pages: int = InventoryManager.get_inventory().unlocked_equipment_pages
	assert_eq(DevCommands.grant_equipment_page(), "")
	assert_eq(InventoryManager.get_inventory().unlocked_equipment_pages, pages + 1)

#-----------------------------------------------------------------------------
# ATTRIBUTES AND STAGE
#-----------------------------------------------------------------------------

func test_add_attribute_adds_to_the_base_value() -> void:
	var attributes: CharacterAttributesData = PersistenceManager.save_game_data.character_attributes
	var before: float = attributes.strength
	assert_eq(DevCommands.add_attribute(CharacterAttributesData.AttributeType.STRENGTH, 5.0), "")
	assert_eq(attributes.strength, before + 5.0)

func test_add_attribute_refuses_an_unknown_attribute() -> void:
	var unknown: CharacterAttributesData.AttributeType = 99 as CharacterAttributesData.AttributeType
	assert_ne(DevCommands.add_attribute(unknown, 5.0), "")

func test_advance_stage_refuses_at_copper() -> void:
	assert_eq(DevCommands.advance_stage(), "", "Foundation has Copper after it")
	assert_eq(CultivationManager.get_current_advancement_stage(), CultivationManager.AdvancementStage.COPPER)
	assert_ne(DevCommands.advance_stage(), "", "nothing follows Copper yet")
	assert_eq(CultivationManager.get_current_advancement_stage(), CultivationManager.AdvancementStage.COPPER, "the stage stays")

#-----------------------------------------------------------------------------
# TRAVEL
#-----------------------------------------------------------------------------

func test_travel_moves_to_the_zone() -> void:
	assert_eq(DevCommands.travel_to_zone(OTHER_ZONE_ID), "", "nothing runs, so nothing is in the way")
	assert_eq(ZoneManager.get_current_zone().zone_id, OTHER_ZONE_ID)

func test_travel_is_allowed_while_foraging_runs() -> void:
	EventManager.trigger_event(FORAGING_EVENT)
	assert_eq(_current_id(), "sprint_forest_foraging_action", "precondition: unlocking foraging starts it")
	assert_eq(DevCommands.travel_to_zone(OTHER_ZONE_ID), "")
	assert_eq(ZoneManager.get_current_zone().zone_id, OTHER_ZONE_ID)

func test_travel_is_allowed_while_training_runs() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	assert_eq(_current_id(), "aura_well_training", "precondition: finding the Aura Well starts its training")
	assert_eq(DevCommands.travel_to_zone(OTHER_ZONE_ID), "")
	assert_eq(ZoneManager.get_current_zone().zone_id, OTHER_ZONE_ID)

func test_travel_refuses_during_cycling() -> void:
	_start(CYCLING_ACTION)
	assert_eq(_current_id(), CYCLING_ACTION, "precondition: cycling runs")
	assert_string_contains(DevCommands.travel_to_zone(OTHER_ZONE_ID), "travel")
	assert_eq(ZoneManager.get_current_zone().zone_id, ZONE_ID, "the zone stays")
	assert_eq(_current_id(), CYCLING_ACTION, "and cycling runs on")

func test_travel_refuses_an_unknown_zone() -> void:
	assert_ne(DevCommands.travel_to_zone("Nowhere"), "")
	assert_eq(ZoneManager.get_current_zone().zone_id, ZONE_ID)

#-----------------------------------------------------------------------------
# VITALS
#-----------------------------------------------------------------------------

func test_refill_vitals_refuses_outside_a_run() -> void:
	var vitals: VitalsManager = PlayerManager.vitals_manager
	vitals.current_health = 10.0
	vitals.current_stamina = 5.0
	assert_ne(DevCommands.refill_vitals(), "", "no adventure runs")
	assert_eq(vitals.current_health, 10.0, "Health is left as it was")
	assert_eq(vitals.current_stamina, 5.0, "and so is Stamina")

func test_refill_vitals_fills_health_and_stamina_and_keeps_the_run_madra() -> void:
	ResourceManager.set_madra(100.0)
	_start(ADVENTURE_ACTION)
	assert_eq(_current_id(), ADVENTURE_ACTION, "precondition: the adventure is the current action")
	var vitals: VitalsManager = PlayerManager.vitals_manager
	vitals.current_health = 10.0
	vitals.current_stamina = 5.0
	vitals.current_madra = 33.0
	assert_eq(DevCommands.refill_vitals(), "")
	assert_eq(vitals.current_health, vitals.max_health)
	assert_eq(vitals.current_stamina, vitals.max_stamina)
	assert_eq(vitals.current_madra, 33.0, "the Madra the run has left stays")

#-----------------------------------------------------------------------------
# UNLOCK ALL
#-----------------------------------------------------------------------------

func test_unlock_all_techniques_logs_how_many_were_new() -> void:
	var catalog: int = CyclingManager.get_all_techniques().size()
	var new_ones: int = catalog - CyclingManager.get_unlocked_techniques().size()
	assert_gt(new_ones, 0, "precondition: a fresh save leaves some locked")
	watch_signals(LogManager)
	assert_eq(DevCommands.unlock_all_techniques(), "")
	assert_eq(CyclingManager.get_unlocked_techniques().size(), catalog, "every technique is unlocked")
	assert_eq(DevCommands.unlock_all_techniques(), "")
	assert_eq(_dev_lines(), [
		DEV_LINE + "Unlocked all techniques (%d new)" % new_ones,
		DEV_LINE + "Unlocked all techniques (0 new)",
	] as Array[String])

func test_unlock_all_abilities_logs_how_many_were_new() -> void:
	var catalog: int = AbilityManager.get_all_abilities().size()
	var new_ones: int = catalog - AbilityManager.get_unlocked_abilities().size()
	assert_gt(new_ones, 0, "precondition: a fresh save leaves some locked")
	watch_signals(LogManager)
	assert_eq(DevCommands.unlock_all_abilities(), "")
	assert_eq(AbilityManager.get_unlocked_abilities().size(), catalog, "every ability is unlocked")
	assert_eq(DevCommands.unlock_all_abilities(), "")
	assert_eq(_dev_lines(), [
		DEV_LINE + "Unlocked all abilities (%d new)" % new_ones,
		DEV_LINE + "Unlocked all abilities (0 new)",
	] as Array[String])

#-----------------------------------------------------------------------------
# PLAY STATS
#-----------------------------------------------------------------------------

func test_dev_commands_never_count_as_play() -> void:
	assert_eq(DevCommands.trigger_event(AURA_WELL_EVENT), "")
	assert_true(EventManager.has_event_triggered(AURA_WELL_EVENT), "precondition: the event fired")
	assert_true(_stats().event_first_times.is_empty(), "so no event time was recorded")
	assert_true(_stats().condition_first_times.is_empty(), "nor a condition time for the conditions it latched")
	assert_false(_stats().recording_paused, "recording is on again")
	assert_ne(DevCommands.trigger_event("not_an_event"), "")
	assert_false(_stats().recording_paused, "and stays on after a refusal")
	EventManager.trigger_event("played_for_real")
	assert_true(_stats().event_first_times.has("played_for_real"), "play still records")

## Every command holds the pause while it runs game code, not just the one the
## test above goes through. The probes see the flag from inside a manager signal.
func test_a_command_pauses_recording_for_its_own_duration() -> void:
	var during_event: Array[bool] = _note_recording_on(EventManager.event_triggered, 1)
	var during_madra: Array[bool] = _note_recording_on(ResourceManager.madra_changed, 1)
	var during_award: Array[bool] = _note_recording_on(InventoryManager.item_awarded, 2)
	var during_completion: Array[bool] = _note_recording_on(QuestManager.quest_started, 1)
	DevCommands.trigger_event(AURA_WELL_EVENT)
	DevCommands.set_madra(10.0)
	DevCommands.award_item(CRUDE_SCALE, 1)
	DevCommands.complete_action(NPC_1)
	assert_eq(during_event, [true, true] as Array[bool], "the aura event, then NPC 1's event")
	assert_eq(during_madra, [true] as Array[bool], "set_madra")
	assert_eq(during_award, [true] as Array[bool], "award_item")
	assert_eq(during_completion, [true] as Array[bool], "complete_action: the quest NPC 1 starts")
	assert_false(_stats().recording_paused, "and recording is on again after them")

## A holder further out (a preset build, say) keeps its pause across a command.
func test_a_command_leaves_an_outer_pause_on() -> void:
	_stats().recording_paused = true
	assert_eq(DevCommands.set_madra(10.0), "")
	assert_true(_stats().recording_paused, "the command put the pause back as it found it")
	_stats().recording_paused = false

#-----------------------------------------------------------------------------
# CATALOGS
#-----------------------------------------------------------------------------

## A content lock: an event the content starts to listen to, or stops listening
## to, changes this list on purpose. Update the test with it, and give the new
## event a story route step (see the story route's coverage test).
func test_known_event_ids() -> void:
	var expected := PackedStringArray([
		"celestial_intervener_dialogue_1",
		"celestial_intervener_dialogue_2",
		"celestial_intervener_dialogue_3",
		"celestial_intervener_dialogue_4",
		"q_fill_core_completed",
		"q_first_steps_enemy_defeated",
		"aura_well_discovered",
		"merchant_discovered",
	])
	expected.sort()
	assert_eq(DevCommands.known_event_ids(), expected, "these eight, sorted, each once")

func test_list_item_paths_finds_nested_items() -> void:
	var paths: PackedStringArray = DevCommands.list_item_paths()
	assert_has(paths, CRUDE_SCALE)
	assert_has(paths, IRON_SHORTSWORD)
	for path: String in paths:
		assert_true(load(path) is ItemDefinitionData, "%s loads as an item" % path)
	var sorted: PackedStringArray = paths.duplicate()
	sorted.sort()
	assert_eq(paths, sorted, "the paths come sorted")

#-----------------------------------------------------------------------------
# THE DEV LINE
#-----------------------------------------------------------------------------

## One working call of every command that logs, in an order that gives each what it
## needs. Each logs exactly one line, and it is a [DEV] line with something after
## the tag.
func test_successful_commands_log_a_dev_line() -> void:
	var steps: Array[Array] = [
		["set_madra", func() -> String: return DevCommands.set_madra(100.0)],
		["set_gold", func() -> String: return DevCommands.set_gold(700.0)],
		["add_path_points", func() -> String: return DevCommands.add_path_points(2)],
		["add_attribute", func() -> String: return DevCommands.add_attribute(CharacterAttributesData.AttributeType.STRENGTH, 5.0)],
		["grant_equipment_page", func() -> String: return DevCommands.grant_equipment_page()],
		["trigger_event", func() -> String: return DevCommands.trigger_event(AURA_WELL_EVENT)],
		["complete_action", func() -> String: return DevCommands.complete_action(NPC_1)],
		["reach_core_density", func() -> String: return DevCommands.reach_core_density(10)],
		["buy_path_node", func() -> String: return DevCommands.buy_path_node("pure_core_awakening")],
		["unlock_technique", func() -> String: return DevCommands.unlock_technique("torrential_flow")],
		["equip_technique", func() -> String: return DevCommands.equip_technique("smooth_flow")],
		["unlock_ability", func() -> String: return DevCommands.unlock_ability("power_font")],
		["equip_ability", func() -> String: return DevCommands.equip_ability("empty_palm", 3)],
		["award_item", func() -> String: return DevCommands.award_item(CRUDE_SCALE, 3)],
		["unlock_all_techniques", func() -> String: return DevCommands.unlock_all_techniques()],
		["unlock_all_abilities", func() -> String: return DevCommands.unlock_all_abilities()],
		["travel_to_zone", func() -> String: return DevCommands.travel_to_zone(OTHER_ZONE_ID)],
		["refill_vitals", _refill_vitals_during_an_adventure],
		["advance_stage", func() -> String: return DevCommands.advance_stage()],
	]
	watch_signals(LogManager)
	var logged: int = 0
	for step: Array in steps:
		var step_name: String = step[0]
		var run: Callable = step[1]
		assert_eq(run.call(), "", "%s worked" % step_name)
		var lines: Array[String] = _dev_lines()
		assert_eq(lines.size(), logged + 1, "%s logged one [DEV] line" % step_name)
		if lines.size() > logged:
			assert_gt(lines.back().length(), DEV_LINE.length(), "%s's line says what it did" % step_name)
		logged = lines.size()

## The wording of a few lines: what the command did, by the ids and values it was given.
func test_dev_lines_say_what_was_done() -> void:
	watch_signals(LogManager)
	assert_eq(DevCommands.set_madra(40.0), "")
	assert_eq(DevCommands.set_gold(700.0), "")
	assert_eq(DevCommands.add_path_points(2), "")
	assert_eq(DevCommands.trigger_event(AURA_WELL_EVENT), "")
	assert_eq(DevCommands.complete_action(NPC_1), "")
	assert_eq(DevCommands.unlock_ability("empty_palm"), "")
	assert_eq(DevCommands.equip_ability("empty_palm", 3), "")
	assert_eq(DevCommands.award_item(CRUDE_SCALE, 3), "")
	assert_eq(_dev_lines(), [
		DEV_LINE + "Set Madra to 40",
		DEV_LINE + "Set Gold to 700",
		DEV_LINE + "Granted 2 Path Points",
		DEV_LINE + "Triggered event aura_well_discovered",
		DEV_LINE + "Completed action celestial_intervener_dialogue_1",
		DEV_LINE + "Unlocked ability empty_palm",
		DEV_LINE + "Equipped ability empty_palm in slot 3",
		DEV_LINE + "Gave 3x crude_scale",
	] as Array[String])

func test_a_refusal_logs_no_dev_line() -> void:
	AbilityManager.unlock_ability("empty_palm")
	watch_signals(LogManager)
	assert_ne(DevCommands.set_madra(-1.0), "")
	assert_ne(DevCommands.trigger_event("not_an_event"), "")
	assert_ne(DevCommands.complete_action(NPC_2), "")
	assert_ne(DevCommands.equip_ability("empty_palm", 0), "")
	assert_eq(_dev_lines().size(), 0)

## The one public way to write a [DEV] line, which the dev panel's tabs and DevManager
## use for the lines that are not a command's: the tag, a space, what happened. The
## player's log keys its tone off the tag, so the exact string is pinned.
func test_log_dev_line_writes_the_tagged_line() -> void:
	watch_signals(LogManager)
	DevCommands.log_dev_line("Show Whole Map: ON")
	assert_eq(_logged_lines(), [DEV_LINE + "Show Whole Map: ON"] as Array[String])
