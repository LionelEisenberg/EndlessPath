class_name AdventureData
extends Resource

## The data for an adventure
@export_category("Adventure Information")
@export var adventure_id: String = ""
@export var adventure_name: String = ""
@export var adventure_description: String = ""

## The parameters used to generate the map for this adventure
@export_category("Map Parameters")
## Placement Generation Parameters
@export_group("Placement Parameters")
@export var num_special_tiles: int = 5
@export var max_distance_from_start: int = 6
@export var sparse_factor: int = 2

## Tile selection parameters
@export_group("Encounter Parameters")
@export var num_path_encounters: int = 5

## Number of non-MST edges added for path branching. 0 = pure MST.
@export var num_extra_edges: int = 2

## Per-encounter instance counts used by the new generator.
## Replaces special_encounter_pool / path_encounter_pool / num_special_tiles / num_path_encounters.
@export var encounter_quotas: Array[EncounterQuota] = []

## Event "Pools"
@export var boss_encounter: AdventureEncounter

# An array of events to pick from for the other special tiles
@export var special_encounter_pool: Array[AdventureEncounter]

# An array of events to pick from for the path tiles (e.g., combat)
@export var path_encounter_pool: Array[AdventureEncounter]

#-----------------------------------------------------------------------------
# VALIDATION
#-----------------------------------------------------------------------------

## Returns a list of human-readable config errors. Empty array = valid.
## Called by AdventureMapGenerator before generation; also run by the
## test suite against every shipped .tres.
func validate() -> Array[String]:
	var errors: Array[String] = []

	if boss_encounter == null:
		errors.append("boss_encounter is not set")
	elif boss_encounter.placement != AdventureEncounter.Placement.ANCHOR:
		errors.append("boss_encounter must have placement = ANCHOR")
	elif boss_encounter.min_distance_from_origin > max_distance_from_start:
		errors.append("boss_encounter.min_distance_from_origin exceeds max_distance_from_start")

	var has_filler_quota: bool = false
	var total_filler_count: int = 0

	for i in range(encounter_quotas.size()):
		var quota: EncounterQuota = encounter_quotas[i]
		if quota == null or quota.encounter == null:
			errors.append("encounter_quotas[%d] has null encounter" % i)
			continue
		if quota.count <= 0:
			errors.append("encounter_quotas[%d] (%s) has non-positive count" % [i, quota.encounter.encounter_id])
			continue
		if quota.encounter.min_distance_from_origin > max_distance_from_start:
			errors.append("%s.min_distance_from_origin exceeds max_distance_from_start" % quota.encounter.encounter_id)
		if quota.encounter.placement == AdventureEncounter.Placement.FILLER:
			has_filler_quota = true
			total_filler_count += quota.count

	for quota in encounter_quotas:
		if quota == null or quota.encounter == null:
			continue
		if quota.encounter.min_fillers_on_path > 0:
			if not has_filler_quota:
				errors.append("encounter %s requires fillers on path but quotas contain no FILLER entries" % quota.encounter.encounter_id)
			elif total_filler_count < quota.encounter.min_fillers_on_path:
				errors.append("encounter %s requires %d fillers on path but only %d are quota'd" % [
					quota.encounter.encounter_id,
					quota.encounter.min_fillers_on_path,
					total_filler_count,
				])

	return errors
