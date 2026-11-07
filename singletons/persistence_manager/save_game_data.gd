class_name SaveGameData
extends Resource

#-----------------------------------------------------------------------------
# SAVE VERSION
#-----------------------------------------------------------------------------

## The save format this build writes. migrate() brings an older save up to it,
## and a save with a higher number was written by a newer build.
const CURRENT_VERSION: int = 8

## 0 means written before saves had versions. Never default this to CURRENT_VERSION: a loaded file sets only the keys it holds, so every old file would look current.
@export var save_version: int = 0

#-----------------------------------------------------------------------------
# RESOURCE MANAGER
#-----------------------------------------------------------------------------

@export var madra : float = 25.0
@export var gold : float = 0.0

## What health holds before it is ever set. ResourceManager fills it to the max
## when the save binds, since "full" depends on Body and gear.
const HEALTH_UNSET: float = -1.0

## The saved Health pool, or HEALTH_UNSET in a new save and in one from before
## the pool, which bind full. Written explicitly by _migrate_to_v3(), never left
## to this default: the text saver skips a value equal to its default.
@export var health: float = HEALTH_UNSET

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

## The player's trained stats: a level and XP for each of the six. A stat missing from it reads as Lv 1.
@export var stat_training: StatTrainingData = StatTrainingData.new()
## Legacy (version 1): the stats as values, before levels. Read only by
## _migrate_to_v2(), which clears it.
@export var character_attributes: CharacterAttributesData = null

## True when there is a training record and it holds a level and XP for every stat.
func _verify_stat_training() -> bool:
	if stat_training == null:
		return false
	for stat: CharacterAttributesData.AttributeType in CharacterAttributesData.AttributeType.values():
		var key: StringName = CharacterAttributesData.stat_key(stat)
		if not stat_training.levels.has(key) or not stat_training.xp.has(key):
			return false
	return true

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

## The version 8 step: a save that latched the first condition had Riverbank
## Training open under the old rule, and gets the second.
const V8_OLD_RIVERBANK_UNLOCK: String = "q_fill_core_completed"
const V8_RIVERBANK_UNLOCK: String = "riverbank_training_opened"

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
## technique_ids whose Auto the player has unlocked with a perfect cycle. Empty
## for a new save, and for a save from before Auto had to be earned.
@export var auto_cycling_technique_ids: Array[String] = []

#-----------------------------------------------------------------------------
# BODY REFINING MANAGER
#-----------------------------------------------------------------------------

## drill ids the player can play. A new save starts with the starting drill.
@export var unlocked_drill_ids: Array[String] = ["stone_lifting"]
@export var equipped_drill_id: String = "stone_lifting"
## drill ids the player has already seen. An unlocked drill missing from this
## list shows a NEW mark until it is seen or equipped.
@export var seen_drill_ids: Array[String] = []
## Set once BodyRefiningManager has marked every drill unlocked at the time as
## seen, so a save from before drills doesn't light the mark on its starting drill.
@export var seen_drills_initialized: bool = false
## drill ids whose Auto the player has unlocked with a perfect set. Empty for a
## new save, and for a save from before drill Auto.
@export var auto_drill_ids: Array[String] = []

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

#-----------------------------------------------------------------------------
# PLAY STATS
#-----------------------------------------------------------------------------

## How this save has been played: its playtime, when each event fired and each
## unlock condition latched, and a few counts. The systems that own those moments
## record them here.
@export var stats: PlayStatsData = PlayStatsData.new()

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

	return "SaveGameData(\n  SaveVersion: %d\n  Madra: %.2f\n  Health: %.2f\n  Gold: %.2f\n  CoreDensityXP: %.2f\n  CoreDensityLevel: %.2f\n  AdvancementStage: %s\n  UnlockProgression: %s\n  EventProgression: %s\n  QuestProgression: %s\n  SelectedZone: %s\n  ZoneProgressionData: %s\n  InventoryCount: %d\n  StatLevels: %s\n  UnlockedCyclingTechniques: %s\n  EquippedCyclingTechniqueId: %s\n  UnlockedDrills: %s\n  EquippedDrillId: %s\n  UnlockedAbilityIds: %s\n  EquippedAbilityIds: %s\n  CurrentPathId: %s\n  PathPoints: %d\n  PathNodePurchases: %s\n  MerchantLedgers: %s\n)" % [
			save_version,
			madra,
			health,
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
			_stat_levels_string(),
			str(unlocked_cycling_technique_ids),
			equipped_cycling_technique_id,
			str(unlocked_drill_ids),
			equipped_drill_id,
			str(unlocked_ability_ids),
			str(equipped_ability_ids),
			current_path_id,
			path_points,
			str(path_node_purchases),
			str(merchant_ledgers)
		]

## The six stats' trained levels for _to_string(), "{strength: 1, body: 1, ...}",
## read through the training record, so a stat it lacks shows its Lv 1. "None"
## with no record.
func _stat_levels_string() -> String:
	if stat_training == null:
		return "None"
	var levels := PackedStringArray()
	for stat: CharacterAttributesData.AttributeType in CharacterAttributesData.AttributeType.values():
		levels.append("%s: %d" % [CharacterAttributesData.stat_key(stat), stat_training.get_level(stat)])
	return "{%s}" % ", ".join(levels)

#-----------------------------------------------------------------------------
# STATE FUNCTIONS AND VERIFICATION
#-----------------------------------------------------------------------------

## A new save at the current version, for a game that starts fresh, with every
## stat written out at Lv 1. A plain SaveGameData.new() is version 0, the number
## an old file loads with, and its training record is empty.
static func new_current() -> SaveGameData:
	var save := SaveGameData.new()
	save.save_version = CURRENT_VERSION
	save.stat_training = StatTrainingData.new_default()
	return save

## True when a newer build wrote this save. This build must neither migrate it
## nor write it back.
func is_from_newer_build() -> bool:
	return save_version > CURRENT_VERSION

## True when the save can be played as it is: its current zone is one the game
## has, and its training record holds a level and XP for every stat. repair()
## fixes what it rejects.
func verify() -> bool:
	return _verify_current_selected_zone_id() and _verify_stat_training()

## Fixes what verify() would reject, in place, and returns the names of the
## fields it changed (empty when there was nothing to fix). A current zone the
## game no longer has goes back to "", which means the first zone in the list.
## A missing training record is made, and a record missing a stat gets it at
## Lv 1 with no XP; the levels and XP it holds are kept. Each check runs on its
## own, so a save can be repaired in both.
func repair() -> PackedStringArray:
	var repaired := PackedStringArray()
	if not _verify_current_selected_zone_id():
		current_selected_zone_id = ""
		repaired.append("current_selected_zone_id")
	if not _verify_stat_training():
		if stat_training == null:
			stat_training = StatTrainingData.new()
		for stat: CharacterAttributesData.AttributeType in CharacterAttributesData.AttributeType.values():
			var key: StringName = CharacterAttributesData.stat_key(stat)
			if not stat_training.levels.has(key):
				stat_training.set_level(stat, 1)
			if not stat_training.xp.has(key):
				stat_training.set_xp(stat, 0.0)
		repaired.append("stat_training")
	return repaired

## Brings a save written by an older build up to CURRENT_VERSION, then stamps it.
## Does nothing to a save from a newer build. Runs after a save loads and before
## it is checked. It does two kinds of work:
## The version steps (_migrate_to_vN) run once per save, for a save older than N.
## Each stamps its own number once it ran, so a step that cannot run (version 2's
## when CultivationManager did not load) stops there, and the save stays at the
## last step it finished, never stamped current unconverted.
## The zone id move runs on every load, whatever the save's version.
## A schema change bumps CURRENT_VERSION, adds a _migrate_to_vN(), and adds its
## step to _run_version_steps().
func migrate() -> void:
	if is_from_newer_build():
		return
	var converted: bool = _run_version_steps()
	_apply_zone_id_migrations()
	if converted:
		save_version = CURRENT_VERSION

## Runs each version step the save has not had, in order, stamping each one's
## number after it. Returns false when a step could not run.
func _run_version_steps() -> bool:
	if save_version < 1:
		_migrate_to_v1()
		save_version = 1
	if save_version < 2:
		if not _can_read_stage_caps():
			Log.error("SaveGameData: CultivationManager did not load, so a version %d save cannot get its stat levels. It stays at version %d" % [save_version, save_version])
			return false
		_migrate_to_v2()
		save_version = 2
	if save_version < 3:
		_migrate_to_v3()
		save_version = 3
	# Version 4 added the drill fields. Their defaults suit an old save (the
	# starting drill, unlocked and equipped), so the step moves nothing.
	if save_version < 4:
		save_version = 4
	# Version 5 added the play stats' set count. Its default of 0 suits an old
	# save, so the step moves nothing.
	if save_version < 5:
		save_version = 5
	# Version 6 added the techniques whose Auto is unlocked. Its empty default
	# suits an old save (every Auto locked), so the step moves nothing.
	if save_version < 6:
		save_version = 6
	# Version 7 added the drills whose Auto is unlocked. Its empty default suits
	# an old save (every drill's Auto locked), so the step moves nothing.
	if save_version < 7:
		save_version = 7
	if save_version < 8:
		_migrate_to_v8()
		save_version = 8
	return true

## True when CultivationManager, which the version 2 step reads the stat caps
## from, has loaded.
func _can_read_stage_caps() -> bool:
	return is_instance_valid(CultivationManager)

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

## Version step 2, run only for a save older than version 2: turns the stats a
## version 1 save kept as values (character_attributes) into trained levels. A
## stat gets one level per point above its Lv 1 value, rounded down, from Lv 1,
## up to the stat level cap of the save's own stage (no cap when no stage
## resource has it), and no XP. Every stat is written out, at Lv 1 when the save
## holds no old values, and the old values are cleared. The step keeps the Aura
## Well's Spirit; foundation, resilience and willpower, stats this build no
## longer has, were already dropped by the loader.
func _migrate_to_v2() -> void:
	if stat_training == null:
		stat_training = StatTrainingData.new()
	var cap: int = _stat_level_cap_of_save_stage()
	for stat: CharacterAttributesData.AttributeType in CharacterAttributesData.AttributeType.values():
		var old_value: float = character_attributes.get_attribute(stat) if character_attributes else CharacterAttributesData.STAT_BASELINE
		var level: int = maxi(1, 1 + floori(old_value - CharacterAttributesData.STAT_BASELINE))
		if cap > 0:
			level = mini(level, cap)
		stat_training.set_level(stat, level)
		stat_training.set_xp(stat, 0.0)
	character_attributes = null

## The stat_level_cap of the save's own stage, or 0 when no stage resource has
## it. CultivationManager.get_stat_level_cap_of() reads the stage list, not the
## bound save: the managers have not bound when migrate() runs, but their
## preloaded defaults are set.
func _stat_level_cap_of_save_stage() -> int:
	return CultivationManager.get_stat_level_cap_of(current_advancement_stage)

## Version step 3, run only for a save older than version 3: writes health out as
## HEALTH_UNSET, so the bind fills it to the max whatever the field's default.
## A save from before the Health pool starts full.
func _migrate_to_v3() -> void:
	health = HEALTH_UNSET

## Version step 8, run only for a save older than version 8: Riverbank Training
## used to open with Awaken Your Spirit's end, and now opens with First Steps
## Out's end or a lost fight. A save that had finished Awaken Your Spirit had the
## card, so its condition latches here, and no one loses the river mid-game.
func _migrate_to_v8() -> void:
	if unlock_progression == null:
		return
	var unlocked: Array[String] = unlock_progression.unlocked_condition_ids
	if V8_OLD_RIVERBANK_UNLOCK in unlocked and not V8_RIVERBANK_UNLOCK in unlocked:
		unlocked.append(V8_RIVERBANK_UNLOCK)

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
## The training record is then written out with every stat at Lv 1, as
## new_current() writes it: a reset save is current, so no migration would ever
## fill an empty one.
func reset() -> void:
	var defaults := SaveGameData.new()
	var script: Script = get_script()
	for property: Dictionary in script.get_script_property_list():
		var usage: int = property["usage"]
		if (usage & PROPERTY_USAGE_STORAGE) != 0:
			var property_name: String = property["name"]
			set(property_name, defaults.get(property_name))
	stat_training = StatTrainingData.new_default()
	save_version = CURRENT_VERSION
