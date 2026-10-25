extends GutTest

## The whole save, written and read back. A SaveGameData with every field of it,
## and of the resources inside it, set to a value other than its default is
## written through SaveFiles.write_atomically(), loaded through
## SaveFiles.load_save(), and compared field by field with what was written.
## Nothing checked the whole save before: the typed dictionaries keyed by item
## files, the equipped gear and accessories, the enum fields and the play stats
## each ride on the engine's text writer and loader.
##
## The comparison is a digest, a plain picture of every stored property that
## == can compare (see _digest()). A second test keeps the first honest: it fails
## for any field the test save leaves at its default, since a field nobody set
## comes back as the default whether or not it survives the file.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const ROOT: String = "user://__test_save_round_trip"
const SAVE_PATH: String = ROOT + "/save.tres"

# Real items: the inventory's dictionaries are keyed by these shared files.
const SPIRIT_FERN: MaterialDefinitionData = preload("res://resources/items/materials/spirit_fern.tres")
const DEWDROP_TEAR: MaterialDefinitionData = preload("res://resources/items/materials/dewdrop_tear.tres")
const REFUGEE_CAMP_MAP: ItemDefinitionData = preload("res://resources/items/quest_items/refugee_camp_map.tres")
const CRUDE_SCALE: ConsumableDefinitionData = preload("res://resources/items/consumables/crude_scale.tres")
const BARELY_COALESCED_SCALE: ConsumableDefinitionData = preload("res://resources/items/consumables/barely_coalesced_scale.tres")
const IRON_SHORTSWORD: EquipmentDefinitionData = preload("res://resources/items/equipment/spirit_valley/iron_shortsword.tres")
const REINFORCED_ROBES: EquipmentDefinitionData = preload("res://resources/items/equipment/spirit_valley/reinforced_robes.tres")
const LEECHING_RING: EquipmentDefinitionData = preload("res://resources/items/equipment/spirit_valley/leeching_ring.tres")

func after_each() -> void:
	for path: String in [SAVE_PATH, SaveFiles.temp_path_for(SAVE_PATH)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ROOT)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ROOT))

#-----------------------------------------------------------------------------
# THE SAVE
#-----------------------------------------------------------------------------

## A save with every stored field set to something other than its default, the
## items real files and the ids real ones.
func _full_save() -> SaveGameData:
	var save := SaveGameData.new()
	save.save_version = SaveGameData.CURRENT_VERSION
	save.madra = 61.5
	save.gold = 130.0
	_fill_inventory(save.inventory)
	save.character_attributes = CharacterAttributesData.new(12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0)

	# Cultivation: stage Copper, and a milestone paid in each stage.
	save.core_density_xp = 340.0
	save.core_density_level = 17.0
	save.current_advancement_stage = CultivationManager.AdvancementStage.COPPER
	save.core_density_milestones[CultivationManager.AdvancementStage.FOUNDATION] = 100
	save.core_density_milestones[CultivationManager.AdvancementStage.COPPER] = 10

	# Unlocks, events and quests: two latched conditions and fired events, one quest
	# at step 1 and one completed.
	for id: String in ["q_first_steps_enemy_defeated", "merchant_discovered"]:
		save.unlock_progression.unlocked_condition_ids.append(id)
		save.event_progression.triggered_events.append(id)
	save.quest_progression.active_quests["q_reach_core_density_10"] = 1
	save.quest_progression.completed_quest_ids.append("q_first_steps")

	# The zone: its progression with a forage under way, training ticks and the last
	# idle action, and the action ids the player has seen.
	save.current_selected_zone_id = "SpiritValley"
	var zone: ZoneProgressionData = save.get_zone_progression_data("SpiritValley")
	zone.action_completion_count["wilderness_cycling_action"] = 4
	zone.forage_active = true
	zone.forage_start_time = 12.5
	zone.training_tick_progress["aura_well_training"] = 30
	zone.last_idle_action_id = "aura_well_training"
	save.seen_action_ids.append("wilderness_cycling_action")
	save.seen_action_ids.append("aura_well_training")
	save.seen_actions_initialized = true

	# Techniques, abilities and the path.
	save.unlocked_cycling_technique_ids.append("smooth_flow")
	save.equipped_cycling_technique_id = "smooth_flow"
	save.seen_cycling_technique_ids.append("foundation_technique")
	save.seen_cycling_techniques_initialized = true
	save.unlocked_ability_ids.append("empty_palm")
	save.equipped_ability_ids[2] = "empty_palm"
	save.current_path_id = "pure_madra"
	save.path_node_purchases["expanded_core"] = 2
	save.path_node_purchases["cycling_focus"] = 1
	save.path_points = 3

	# One merchant's ledger.
	var ledger: MerchantLedgerData = save.get_merchant_ledger("spirit_valley_merchant")
	ledger.add_purchase("crude_scale")
	ledger.add_purchase("crude_scale")
	ledger.add_purchase("leeching_ring")

	# The play stats, with the pause a dev command sets: it is not saved.
	var stats: PlayStatsData = save.stats
	stats.play_time = 3725.5
	stats.event_first_times["q_first_steps_enemy_defeated"] = 412.25
	stats.event_first_times["merchant_discovered"] = 3100.5
	stats.condition_first_times["merchant_discovered"] = 3100.5
	stats.cycles_finished = 14
	stats.adventures_started = 5
	stats.adventures_won = 3
	stats.adventures_lost = 1
	stats.adventures_timed_out = 1
	stats.fights_won = 9
	stats.gold_earned = 340.0
	stats.built_from_preset = "round_trip_preset"
	stats.recording_paused = true
	return save

## Fills every field of the inventory: materials, quest items and consumables keyed
## by item files, an equipment instance in the grid, one worn in a gear slot and
## one in an accessory slot, and a consumable on the hotbar.
func _fill_inventory(inventory: InventoryData) -> void:
	inventory.materials[SPIRIT_FERN] = 12
	inventory.materials[DEWDROP_TEAR] = 3
	inventory.quest_items[REFUGEE_CAMP_MAP] = 1
	inventory.consumables[CRUDE_SCALE] = 5
	inventory.consumables[BARELY_COALESCED_SCALE] = 2
	inventory.equipped_consumables[0] = CRUDE_SCALE
	inventory.equipment[3] = _instance_of(IRON_SHORTSWORD, "grid_sword")
	inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.ARMOR] = _instance_of(REINFORCED_ROBES, "worn_robes")
	inventory.equipped_accessories[0] = _instance_of(LEECHING_RING, "worn_ring")
	inventory.unlocked_equipment_pages = 3

## An item instance with all four of its fields set.
func _instance_of(definition: ItemDefinitionData, instance_id: String) -> ItemInstanceData:
	var instance := ItemInstanceData.new()
	instance.item_definition = definition
	instance.quantity = 2
	instance.instance_id = instance_id
	instance.metadata = {"tempered": true, "marks": [1, 2]}
	return instance

## Writes the save the way the game does and reads it back, or returns null when
## it did not come back.
func _round_trip(save: SaveGameData) -> SaveGameData:
	assert_eq(SaveFiles.write_atomically(save, SAVE_PATH), OK, "the save is written")
	var loaded: SaveGameData = SaveFiles.load_save(SAVE_PATH)
	assert_not_null(loaded, "the save loads again")
	return loaded

#-----------------------------------------------------------------------------
# THE DIGEST
#-----------------------------------------------------------------------------

## A plain picture of `value` that == compares. A Resource is the stored properties
## of its script, digested in turn; one that has a file of its own, as an item
## does, is only its path, so item keys compare by file. A Dictionary is its
## entries sorted by key, so the order they were written in does not matter, and
## an Array is its digested items. Anything else is itself.
func _digest(value: Variant) -> Variant:
	if value is Resource:
		return _digest_resource(value)
	if value is Dictionary:
		var entries: Array = []
		for key: Variant in value:
			entries.append([_digest(key), _digest(value[key])])
		entries.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
		return entries
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_digest(item))
		return items
	return value

func _digest_resource(resource: Resource) -> Variant:
	if _has_a_file_of_its_own(resource):
		return resource.resource_path
	var script: Script = resource.get_script()
	var picture: Dictionary = {"class": script.get_global_name()}
	for property: Dictionary in script.get_script_property_list():
		if (int(property["usage"]) & PROPERTY_USAGE_STORAGE) != 0:
			picture[property["name"]] = _digest(resource.get(property["name"]))
	return picture

## True for an item or other shared file, false for a resource that lives inside
## the save (a sub-resource's path names its file and its id).
func _has_a_file_of_its_own(resource: Resource) -> bool:
	return resource.resource_path != "" and not resource.resource_path.contains("::")

## The paths of the stored properties under `resource`, and under every resource
## inside it, that still hold what a new instance of their class holds.
func _fields_left_at_default(resource: Resource, path: String) -> PackedStringArray:
	var left := PackedStringArray()
	var script: GDScript = resource.get_script()
	var defaults: Resource = script.new()
	for property: Dictionary in script.get_script_property_list():
		if (int(property["usage"]) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var property_name: String = property["name"]
		var value: Variant = resource.get(property_name)
		if _digest(value) == _digest(defaults.get(property_name)):
			left.append("%s.%s" % [path, property_name])
		else:
			left.append_array(_fields_left_at_default_in(value, "%s.%s" % [path, property_name]))
	return left

## _fields_left_at_default() for what a property holds: the resources inside it,
## or inside the dictionary or array it is. Item files are not the save's to set.
func _fields_left_at_default_in(value: Variant, path: String) -> PackedStringArray:
	var left := PackedStringArray()
	if value is Resource:
		if not _has_a_file_of_its_own(value):
			left.append_array(_fields_left_at_default(value, path))
	elif value is Dictionary:
		for key: Variant in value:
			left.append_array(_fields_left_at_default_in(value[key], "%s[%s]" % [path, key]))
	elif value is Array:
		for index: int in value.size():
			left.append_array(_fields_left_at_default_in(value[index], "%s[%d]" % [path, index]))
	return left

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_a_full_save_round_trips() -> void:
	var original: SaveGameData = _full_save()
	var loaded: SaveGameData = _round_trip(original)
	if loaded == null:
		return
	assert_not_same(loaded, original, "the save is read from the file")
	var script: GDScript = original.get_script()
	var compared: PackedStringArray = PackedStringArray()
	for property: Dictionary in script.get_script_property_list():
		if (int(property["usage"]) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var property_name: String = property["name"]
		compared.append(property_name)
		assert_eq(_digest(loaded.get(property_name)), _digest(original.get(property_name)), "SaveGameData.%s comes back as it was written" % property_name)
	assert_true(compared.has("inventory") and compared.has("stats"), "the digest reads the save's stored properties")

func test_the_full_save_leaves_no_field_at_its_default() -> void:
	var left: PackedStringArray = _fields_left_at_default(_full_save(), "SaveGameData")
	assert_true(left.is_empty(), "Set these in _full_save(), or the round trip proves nothing for them: %s" % ", ".join(left))

func test_item_keys_still_find_their_items() -> void:
	var loaded: SaveGameData = _round_trip(_full_save())
	if loaded == null:
		return
	var inventory: InventoryData = loaded.inventory
	# The dictionaries are keyed by the one shared object of each item file, so a
	# lookup with the item finds the entry; a copy of the item would not.
	assert_eq(inventory.materials.get(SPIRIT_FERN), 12, "materials are found by their item")
	assert_eq(inventory.materials.get(DEWDROP_TEAR), 3)
	assert_eq(inventory.quest_items.get(REFUGEE_CAMP_MAP), 1, "quest items are found by their item")
	assert_eq(inventory.consumables.get(CRUDE_SCALE), 5, "consumables are found by their item")
	assert_eq(inventory.consumables.get(BARELY_COALESCED_SCALE), 2)
	assert_same(inventory.equipped_consumables.get(0), CRUDE_SCALE, "the hotbar holds the shared consumable")
	assert_same(inventory.equipment[3].item_definition, IRON_SHORTSWORD, "an equipment instance holds the shared definition")
	assert_same(inventory.equipped_gear[EquipmentDefinitionData.EquipmentSlot.ARMOR].item_definition, REINFORCED_ROBES)
	assert_same(inventory.equipped_accessories[0].item_definition, LEECHING_RING)

func test_pausing_recording_is_not_saved() -> void:
	var save := SaveGameData.new()
	save.stats.recording_paused = true
	var loaded: SaveGameData = _round_trip(save)
	if loaded == null:
		return
	assert_false(loaded.stats.recording_paused, "a dev command's pause ends with the run that made it")
