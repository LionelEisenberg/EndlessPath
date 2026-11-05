extends GutTest

## Unit tests for StatTrainingData, the player's saved training record: a level
## and the XP toward the next one for each stat, keyed by stat key.

const AttributeType = CharacterAttributesData.AttributeType

#-----------------------------------------------------------------------------
# A NEW RECORD
#-----------------------------------------------------------------------------

func test_new_default_writes_every_stat_at_level_one() -> void:
	var record := StatTrainingData.new_default()
	assert_eq([record.levels.size(), record.xp.size()], [6, 6], "one level and one XP per stat")
	for stat: int in AttributeType.values():
		var key: StringName = CharacterAttributesData.stat_key(stat)
		assert_eq(record.levels.get(key), 1, "%s starts at Lv 1" % key)
		assert_eq(record.xp.get(key), 0.0, "%s starts with no XP" % key)

func test_a_missing_stat_reads_as_level_one_with_no_xp() -> void:
	var record := StatTrainingData.new()
	assert_eq(record.get_level(AttributeType.SPIRIT), 1, "a stat with no level reads as Lv 1")
	assert_eq(record.get_xp(AttributeType.SPIRIT), 0.0, "a stat with no XP reads as 0")

#-----------------------------------------------------------------------------
# WRITING
#-----------------------------------------------------------------------------

func test_set_level_and_xp_store_under_the_stat_key() -> void:
	var record := StatTrainingData.new()
	record.set_level(AttributeType.MIND, 4)
	record.set_xp(AttributeType.MIND, 12.5)
	assert_eq(record.levels.get(&"mind"), 4, "the level is stored under &\"mind\"")
	assert_eq(record.xp.get(&"mind"), 12.5, "the XP is stored under &\"mind\"")
	assert_eq(record.get_level(AttributeType.MIND), 4, "get_level() reads the level back")
	assert_eq(record.get_xp(AttributeType.MIND), 12.5, "get_xp() reads the XP back")
