# CultivationManager.gd
# AUTOLOADED SINGLETON
extends Node

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------
signal core_density_xp_updated(xp: float, level: float)
signal core_density_level_updated(xp: float, level: float)
## Emitted once, on the level-up that reaches the stage's Core Density cap.
signal core_filled(stage: AdvancementStage)
signal advancement_stage_changed(new_stage: AdvancementStage)

#-----------------------------------------------------------------------------
# ENUMS & CONSTANTS
#-----------------------------------------------------------------------------
enum AdvancementStage { 
	FOUNDATION,
	COPPER,
	IRON,
	JADE,
	SILVER
}

@export var advancement_stage_resources: Array[AdvancementStageResource] = [
	preload("res://resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres"),
	preload("res://resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres"),
]

## Points awarded per Core Density level milestone, indexed by advancement stage.
const PATH_POINTS_PER_STAGE: Dictionary = {
	AdvancementStage.FOUNDATION: 1,
	AdvancementStage.COPPER: 2,
	AdvancementStage.IRON: 3,
	AdvancementStage.JADE: 4,
}
const PATH_POINT_LEVEL_INTERVAL: int = 10
## Written to the player's log when the core fills and a next stage waits.
const CORE_FULL_LOG: String = "Your core is full. The Tribulation waits in Spirit Valley."
## The short "Core full" text the cabinet, the cycle line and the zone floaters show while the core is full.
const CORE_FULL_TEXT: String = "Core full"

#-----------------------------------------------------------------------------
# PLAYER DATA (Held by this manager)
#-----------------------------------------------------------------------------

# --- Persistent State (via shared SaveGameData) ---
var live_save_data: SaveGameData = null # Reference set in _ready

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_update_resources)
		_update_resources()
	else:
		Log.critical("CultivationManager: Could not get save_game_data from PersistenceManager on ready!")

func _update_resources() -> void:
	live_save_data = PersistenceManager.save_game_data
	if live_save_data == null:
		Log.critical("CultivationManager: live_save_data is null in _update_resources!")
		return
	
	# A save from before the cap can stand past it: it loads at the cap, without XP
	var cap: int = get_core_density_cap()
	if cap > 0 and live_save_data.core_density_level > cap:
		Log.info("CultivationManager: Core Density %d is past the stage's cap of %d. Loaded at the cap, with no XP" % [int(live_save_data.core_density_level), cap])
		live_save_data.core_density_level = cap
		live_save_data.core_density_xp = 0.0

	# A save from before the milestones were recorded was paid each one up to its
	# level, so seed from the level. The clamp comes first: the cap is the most it can hold
	var stage: AdvancementStage = live_save_data.current_advancement_stage
	if not live_save_data.core_density_milestones.has(stage):
		live_save_data.core_density_milestones[stage] = floori(live_save_data.core_density_level / PATH_POINT_LEVEL_INTERVAL) * PATH_POINT_LEVEL_INTERVAL

	core_density_xp_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)
	core_density_level_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)
	advancement_stage_changed.emit(live_save_data.current_advancement_stage)

#-----------------------------------------------------------------------------
# PUBLIC LOGIC FUNCTIONS
#-----------------------------------------------------------------------------
## Add XP to core density and handle level progression. A full core takes none:
## the XP is lost. The level-up that reaches the stage's cap drops the XP left
## over, then announces the full core.
func add_core_density_xp(amount: float) -> void:
	if live_save_data == null:
		Log.error("CultivationManager: Cannot add XP - live_save_data is null")
		return
	
	# A full core holds no XP, so what arrives (and what an older save held) is lost
	if is_core_full():
		live_save_data.core_density_xp = 0.0
		core_density_xp_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)
		return

	# Add XP to current amount
	live_save_data.core_density_xp += amount
	
	# Check for level progression
	var cap: int = get_core_density_cap()
	var xp_needed_for_next_level: float = get_xp_for_next_level()
	
	# Level up if we have enough XP
	while live_save_data.core_density_xp >= xp_needed_for_next_level:
		# A free level, or a stage with no resource, costs 0 XP and passes every
		# check: stop here instead of levelling for nothing (or forever)
		if xp_needed_for_next_level <= 0.0:
			Log.error("CultivationManager: Cannot level - level %d of stage %s costs no XP (a free level or a missing stage resource)" % [
				int(live_save_data.core_density_level) + 1,
				AdvancementStage.find_key(live_save_data.current_advancement_stage),
			])
			break
		# Nothing levels past the cap. With a positive cap the entry check and the
		# break after core_filled stop every run before it gets here, so this is the
		# backstop for a misconfigured cap (0 or less)
		if live_save_data.core_density_level >= cap:
			break

		# Level up
		live_save_data.core_density_level += 1
		live_save_data.core_density_xp -= xp_needed_for_next_level
		var reached_cap: bool = live_save_data.core_density_level >= cap
		if reached_cap:
			# The core is full: the XP left over is lost
			live_save_data.core_density_xp = 0.0

		# Emit level up signal
		core_density_level_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)

		# Award path points every PATH_POINT_LEVEL_INTERVAL levels, once per stage
		_pay_milestone(int(live_save_data.core_density_level))

		if reached_cap:
			core_filled.emit(live_save_data.current_advancement_stage)
			if has_next_stage() and LogManager:
				LogManager.log_message(CORE_FULL_LOG)
			break

		# Get XP needed for next level
		xp_needed_for_next_level = get_xp_for_next_level()
	
	# Always emit XP updated signal for UI updates
	core_density_xp_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)

## Take `count` levels of Core Density away, never below level 0. The XP towards
## the next level goes with them. The path points stay: they were already earned.
func lose_core_density_levels(count: int) -> void:
	if live_save_data == null:
		Log.error("CultivationManager: Cannot lose levels - live_save_data is null")
		return

	live_save_data.core_density_level = maxf(0.0, live_save_data.core_density_level - count)
	live_save_data.core_density_xp = 0.0
	core_density_level_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)
	core_density_xp_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)

## Breaks through to the current stage's next stage: the stage changes and Core
## Density starts over at level 0 with no XP. Returns false, changing nothing,
## when the stage has no next stage. The caller decides when the player has
## earned it: nothing here checks that the core is full.
func advance_to_next_stage() -> bool:
	if not has_next_stage():
		return false

	var next_stage: AdvancementStageResource = _get_current_stage_resource().next_stage
	live_save_data.current_advancement_stage = next_stage.stage_id
	live_save_data.core_density_level = 0.0
	live_save_data.core_density_xp = 0.0

	# Logged before the signals: what the new stage unlocks logs its own lines when
	# they fire, and those should read after the breakthrough, not before it
	if LogManager:
		LogManager.log_message("You break through to %s." % next_stage.stage_name)
	core_density_level_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)
	core_density_xp_updated.emit(live_save_data.core_density_xp, live_save_data.core_density_level)
	advancement_stage_changed.emit(live_save_data.current_advancement_stage)
	return true

func get_xp_for_next_level() -> float:
	if live_save_data == null:
		return 0.0
	var cur_level = live_save_data.core_density_level + 1
	var res = _get_current_stage_resource()
	return res.get_xp_for_level(cur_level) if res else 0.0

func get_core_density_xp() -> float:
	if live_save_data == null:
		return 0.0
	return live_save_data.core_density_xp

func get_core_density_level() -> float:
	if live_save_data == null:
		return 0.0
	return live_save_data.core_density_level

## The highest Core Density level of the current stage, where XP stops. 0 when
## there is no save or no stage resource.
func get_core_density_cap() -> int:
	var res: AdvancementStageResource = _get_current_stage_resource()
	return res.max_core_density_level if res else 0

## True when Core Density has reached the current stage's cap.
func is_core_full() -> bool:
	var cap: int = get_core_density_cap()
	return cap > 0 and get_core_density_level() >= cap

## True when the current stage has a next stage to break through to.
func has_next_stage() -> bool:
	var res: AdvancementStageResource = _get_current_stage_resource()
	return res != null and res.next_stage != null

## Maximum Madra the player can hold: the current stage's curve at the current
## Core Density level. 0.0 when there is no save or stage resource.
func get_max_madra() -> float:
	var res: AdvancementStageResource = _get_current_stage_resource()
	if res == null:
		return 0.0
	return res.get_max_madra(int(get_core_density_level()))

func get_current_advancement_stage() -> AdvancementStage:
	if live_save_data == null:
		return AdvancementStage.FOUNDATION
	return live_save_data.current_advancement_stage

func get_current_advancement_stage_name() -> String:
	var res = _get_current_stage_resource()
	return res.stage_name if res else "Unknown"

func get_advancement_stage_name(stage: AdvancementStage) -> String:
	for res in advancement_stage_resources:
		if res.stage_id == stage:
			return res.stage_name
	return "Unknown"

#-----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS
#-----------------------------------------------------------------------------

## Pays the stage's path points for reaching `level` when it is a milestone the
## stage has not paid yet, and records it. Regaining a level that was lost (a
## failed breakthrough) pays nothing: the first crossing already did.
func _pay_milestone(level: int) -> void:
	var stage: AdvancementStage = live_save_data.current_advancement_stage
	var paid: int = live_save_data.core_density_milestones.get(stage, 0)
	if level % PATH_POINT_LEVEL_INTERVAL != 0 or level <= 0 or level <= paid:
		return

	var points: int = PATH_POINTS_PER_STAGE.get(stage, 1)
	if PathManager:
		PathManager.add_points(points)
		live_save_data.core_density_milestones[stage] = level

func _get_stage_resource(stage: AdvancementStage) -> AdvancementStageResource:
	for i in range(advancement_stage_resources.size()):
		if advancement_stage_resources[i].stage_id == stage:
			return advancement_stage_resources[i]
	return null

func _get_current_stage_resource() -> AdvancementStageResource:
	if live_save_data == null:
		return null
	var stage : AdvancementStage = live_save_data.current_advancement_stage
	return _get_stage_resource(stage)
