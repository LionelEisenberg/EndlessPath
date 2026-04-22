extends GutTest

func test_defaults() -> void:
	var quota := EncounterQuota.new()
	assert_null(quota.encounter, "encounter defaults to null")
	assert_eq(quota.count, 1, "count defaults to 1")

func test_holds_encounter_reference() -> void:
	var enc := AdventureEncounter.new()
	enc.encounter_id = "test_quota_enc"
	var quota := EncounterQuota.new()
	quota.encounter = enc
	quota.count = 3
	assert_eq(quota.encounter.encounter_id, "test_quota_enc")
	assert_eq(quota.count, 3)
