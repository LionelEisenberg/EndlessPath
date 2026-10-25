class_name SaveGameData
extends Resource

#-----------------------------------------------------------------------------
# SAVE VERSION
#-----------------------------------------------------------------------------

## The save format this build writes. migrate() brings an older save up to it,
## and a save with a higher number was written by a newer build.
const CURRENT_VERSION: int = 1

## 0 means written before saves had versions. Never default this to CURRENT_VERSION: a loaded file sets only the keys it holds, so every old file would look current.
@export var save_version: int = 0

#-----------------------------------------------------------------------------
# RESOURCE MANAGER
#-----------------------------------------------------------------------------

@export var madra : float = 25.0
@export var gold : float = 0.0

#-----------------------------------------------------------------------------
# INVENTORY MANAGER
#-----------------------------------------------------------------------------

# Key is the item instance id, value is the item instance data
@export var inventory : InventoryData = InventoryData.new()

## Where saves from before commit 0652b49 kept their two accessories in
## inventory.equipped_gear (the old EquipmentSlot ACCESSORY_1 and ACCESSORY_2),
## each mapped to the slot it has in inventory.equipped_accessories now.
const LEGACY_ACCESSORY_GEAR_KEYS: Dictionary[int, int] = {4: 0, 5: 1}

#-----------------------------------------------------------------------------
# CHARACTER MANAGER
#-----------------------------------------------------------------------------

@export var character_attributes: CharacterAttributesData = CharacterAttributesData.new()

#-----------------------------------------------------------------------------
# CULTIVATION MANAGER
#-----------------------------------------------------------------------------

@export var core_density_xp : float = 0.0 
@export var core_density_level : float = 0.0
@export var current_advancement_stage : CultivationManager.AdvancementStage = CultivationManager.AdvancementStage.FOUNDATION
## Stage (AdvancementStage) to the highest Core Density milestone already paid. Missing on old saves, so it is seeded on load.
@export var core_density_milestones: Dictionary[int, int] = {}

#-----------------------------------------------------------------------------
# UNLOCK MANAGER
#-----------------------------------------------------------------------------

@export var unlock_progression: UnlockProgressionData = UnlockProgressionData.new()

#-----------------------------------------------------------------------------
# EVENT MANAGER
#-----------------------------------------------------------------------------

@export var event_progression: EventProgressionData = EventProgressionData.new()

#-----------------------------------------------------------------------------
# QUEST MANAGER
#-----------------------------------------------------------------------------

@export var quest_progression: QuestProgressionData = QuestProgressionData.new()

#-----------------------------------------------------------------------------
# ZONE MANAGER
#-----------------------------------------------------------------------------

@export var current_selected_zone_id: String = ""
@export var zone_progression_data: Dictionary[String, ZoneProgressionData] = {}

## action_ids the player has already seen. An available action missing from
## this list shows a NEW tag on its card until it is first hovered or used.
@export var seen_action_ids: Array[String] = []
## Set once ZoneManager has marked every action available at the time as seen,
## so a save from before the NEW tag doesn't light it on every card.
@export var seen_actions_initialized: bool = false

## Zone ids a save may no longer stand in, mapped to where it moves on load.
## Test Zone is hidden from the map but kept in the zone list, so verify()
## still accepts it; the move only stops a player being stranded on a hidden hex.
const ZONE_ID_MIGRATIONS: Dictionary = {"TestZone": "SpiritValley"}


func get_zone_progression_data(zone_id: String) -> ZoneProgressionData:
	if zone_id in zone_progression_data:
		return zone_progression_data[zone_id]
	else:
		var new_zone_progression = ZoneProgressionData.new()
		new_zone_progression.zone_id = zone_id
		zone_progression_data[zone_id] = new_zone_progression
		return zone_progression_data[zone_id]

func increment_zone_progression_for_action(action_id: String, zone_id: String, quantity: int) -> int:
	if not zone_id in zone_progression_data:
		var new_zone_progression = ZoneProgressionData.new()
		new_zone_progression.zone_id = zone_id
		zone_progression_data[zone_id] = new_zone_progression
	
	zone_progression_data[zone_id].action_completion_count.set(action_id, zone_progression_data[zone_id].action_completion_count.get(action_id, 0) + quantity)
	return zone_progression_data[zone_id].action_completion_count[action_id]

func _verify_current_selected_zone_id() -> bool:
	return current_selected_zone_id == "" or ZoneManager.has_zone(current_selected_zone_id)

#-----------------------------------------------------------------------------
# CYCLING MANAGER
#-----------------------------------------------------------------------------

@export var unlocked_cycling_technique_ids: Array[String] = ["foundation_technique"]
@export var equipped_cycling_technique_id: String = "foundation_technique"
## technique_ids the player has already seen. An unlocked technique missing from
## this list shows a NEW seal on its drawer until the pointer leaves the drawer or
## the technique is equipped.
@export var seen_cycling_technique_ids: Array[String] = []
## Set once CyclingManager has marked every technique unlocked at the time as seen,
## so a save from before the NEW seal doesn't light it on every drawer.
@export var seen_cycling_techniques_initialized: bool = false

#-----------------------------------------------------------------------------
# ABILITY MANAGER
#-----------------------------------------------------------------------------

@export var unlocked_ability_ids: Array[String] = ["basic_strike", "enforce"]
@export var equipped_ability_ids: Array[String] = ["basic_strike", "enforce", "", ""]

#-----------------------------------------------------------------------------
# PATH PROGRESSION
#-----------------------------------------------------------------------------

## The path_id of the currently active path tree (empty if no path selected).
@export var current_path_id: String = ""
## Maps node_id -> purchase count for the current run's path tree.
@export var path_node_purchases: Dictionary[String, int] = {}
## Current unspent path point balance.
@export var path_points: int = 0

#-----------------------------------------------------------------------------
# MERCHANT MANAGER
#-----------------------------------------------------------------------------

## Maps MerchantStock.merchant_id -> what the player bought from that merchant.
@export var merchant_ledgers: Dictionary[String, MerchantLedgerData] = {}

## Returns the merchant's ledger, creating and storing an empty one on first use.
func get_merchant_ledger(merchant_id: String) -> MerchantLedgerData:
	if not merchant_ledgers.has(merchant_id):
		var ledger := MerchantLedgerData.new()
		ledger.merchant_id = merchant_id
		merchant_ledgers[merchant_id] = ledger
	return merchant_ledgers[merchant_id]

func _to_string() -> String:
	var zone_progression_data_str := ""
	if typeof(zone_progression_data) == TYPE_DICTIONARY:
		var progression_strings := []
		for zone_id in zone_progression_data.keys():
			var progression : ZoneProgressionData = zone_progression_data[zone_id]
			var progression_summary := ""
			if progression:
				progression_summary = "Completions: %s" % (str(progression.action_completion_count) if "action_completion_count" in progression else "N/A")
			else:
				progression_summary = "None"
			progression_strings.append("%s: [%s]" % [zone_id, progression_summary])
		zone_progression_data_str = "{%s}" % ", ".join(progression_strings)
	else:
		zone_progression_data_str = "N/A"

	return "SaveGameData(\n  SaveVersion: %d\n  Madra: %.2f\n  Gold: %.2f\n  CoreDensityXP: %.2f\n  CoreDensityLevel: %.2f\n  AdvancementStage: %s\n  UnlockProgression: %s\n  EventProgression: %s\n  QuestProgression: %s\n  SelectedZone: %s\n  ZoneProgressionData: %s\n  InventoryCount: %d\n  CharacterAttributes: %s\n  UnlockedCyclingTechniques: %s\n  EquippedCyclingTechniqueId: %s\n  UnlockedAbilityIds: %s\n  EquippedAbilityIds: %s\n  CurrentPathId: %s\n  PathPoints: %d\n  PathNodePurchases: %s\n  MerchantLedgers: %s\n)" % [
			save_version,
			madra,
			gold,
			core_density_xp,
			core_density_level,
			CultivationManager.get_advancement_stage_name(current_advancement_stage),
			str(unlock_progression),
			str(event_progression),
			str(quest_progression),
			current_selected_zone_id,
			zone_progression_data_str,
			inventory.equipment.size() if inventory else 0,
			str(character_attributes) if character_attributes else "None",
			str(unlocked_cycling_technique_ids),
			equipped_cycling_technique_id,
			str(unlocked_ability_ids),
			str(equipped_ability_ids),
			current_path_id,
			path_points,
			str(path_node_purchases),
			str(merchant_ledgers)
		]


#-----------------------------------------------------------------------------
# STATE FUNCTIONS AND VERIFICATION
#-----------------------------------------------------------------------------

## A new save at the current version, for a game that starts fresh. A plain
## SaveGameData.new() is version 0, the number an old file loads with.
static func new_current() -> SaveGameData:
	var save := SaveGameData.new()
	save.save_version = CURRENT_VERSION
	return save

## True when a newer build wrote this save. This build must neither migrate it
## nor write it back.
func is_from_newer_build() -> bool:
	return save_version > CURRENT_VERSION

func verify() -> bool:
	return _verify_current_selected_zone_id()

## Fixes what verify() would reject, in place, and returns the names of the
## fields it changed (empty when there was nothing to fix). A current zone the
## game no longer has goes back to "", which means the first zone in the list.
func repair() -> PackedStringArray:
	var repaired := PackedStringArray()
	if not _verify_current_selected_zone_id():
		current_selected_zone_id = ""
		repaired.append("current_selected_zone_id")
	return repaired

## Brings a save written by an older build up to CURRENT_VERSION, then stamps it.
## Does nothing to a save from a newer build. Runs after a save loads and before
## it is checked. It does two kinds of work:
## The version steps (_migrate_to_vN) run once per save, for a save older than N.
## The zone id move runs on every load, whatever the save's version.
## A schema change bumps CURRENT_VERSION, adds a _migrate_to_vN(), and adds an
## "if save_version < N" line here.
func migrate() -> void:
	if is_from_newer_build():
		return
	if save_version < 1:
		_migrate_to_v1()
	_apply_zone_id_migrations()
	save_version = CURRENT_VERSION

## Version step 1, run only for a save older than version 1: moves each accessory
## an old save holds in equipped_gear to its slot in equipped_accessories. A slot
## that is already taken keeps its item, and the old accessory stays in
## equipped_gear, named in the log.
func _migrate_to_v1() -> void:
	if inventory == null:
		return
	for gear_key: int in LEGACY_ACCESSORY_GEAR_KEYS:
		if not inventory.equipped_gear.has(gear_key):
			continue
		var accessory_index: int = LEGACY_ACCESSORY_GEAR_KEYS[gear_key]
		var item: ItemInstanceData = inventory.equipped_gear[gear_key]
		if inventory.equipped_accessories.has(accessory_index):
			var item_id: String = item.item_definition.item_id if item and item.item_definition else "an item with no definition"
			Log.warn("SaveGameData: Accessory slot %d is taken, so %s stays in equipped_gear slot %d" % [accessory_index, item_id, gear_key])
			continue
		inventory.equipped_accessories[accessory_index] = item
		inventory.equipped_gear.erase(gear_key)

## Moves the current zone off an id in ZONE_ID_MIGRATIONS, such as the hidden Test
## Zone. Not a version step: it runs on every load. The dev panel can walk a save
## into Test Zone and its toggle resets on the next launch, so a save of any
## version may be standing on a hex the map does not show.
func _apply_zone_id_migrations() -> void:
	if ZONE_ID_MIGRATIONS.has(current_selected_zone_id):
		var new_zone_id: String = ZONE_ID_MIGRATIONS[current_selected_zone_id]
		Log.info("SaveGameData: Moved the current zone from %s to %s" % [current_selected_zone_id, new_zone_id])
		current_selected_zone_id = new_zone_id

## Resets every saved field to the default a new SaveGameData declares, in
## place, so the managers holding this object keep a valid reference. It copies
## from a fresh instance instead of listing the defaults a second time, so a new
## field resets without being added here, and every sub-resource is a new object.
func reset() -> void:
	var defaults := SaveGameData.new()
	var script: Script = get_script()
	for property: Dictionary in script.get_script_property_list():
		var usage: int = property["usage"]
		if (usage & PROPERTY_USAGE_STORAGE) != 0:
			var property_name: String = property["name"]
			set(property_name, defaults.get(property_name))
	save_version = CURRENT_VERSION
