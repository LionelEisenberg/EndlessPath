extends GutTest

## Unit tests for CultivationManager's public max-Madra getter, which the
## cultivator plate, the cycling panel and ResourceManager.add_madra() read
## instead of the private stage-resource lookup. Foundation's curve is
## 100 base + 5 per Core Density level. Also pins Foundation's Core Density cap,
## which the Goals board's milestone and the cabinet's core orb read.

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# MAX MADRA
#-----------------------------------------------------------------------------

func test_max_madra_at_level_zero_is_the_stage_base() -> void:
	assert_eq(CultivationManager.get_max_madra(), 100.0)

func test_max_madra_follows_level() -> void:
	PersistenceManager.save_game_data.core_density_level = 32.0
	assert_eq(CultivationManager.get_max_madra(), 260.0, "100 + 5 x 32")

func test_add_madra_caps_at_the_getter_value() -> void:
	PersistenceManager.save_game_data.core_density_level = 32.0
	ResourceManager.add_madra(1000.0)
	assert_eq(ResourceManager.get_madra(), 260.0)

#-----------------------------------------------------------------------------
# CORE DENSITY CAP
#-----------------------------------------------------------------------------

func test_foundation_core_density_cap_is_one_hundred() -> void:
	assert_eq(CultivationManager.get_core_density_cap(), 100, "the design's 0-100 per stage; Goals reads \"Raise Core Density to 100\"")

#-----------------------------------------------------------------------------
# XP PER LEVEL
#-----------------------------------------------------------------------------

## Foundation's level 1 costs 10 XP, and each level 2% more than the last.
func test_xp_for_level_follows_the_stages_curve() -> void:
	assert_almost_eq(CultivationManager.get_xp_for_level(1), 10.0, 0.0001)
	assert_almost_eq(CultivationManager.get_xp_for_level(2), 10.2, 0.0001)
	assert_almost_eq(CultivationManager.get_xp_for_level(11), 10.0 * pow(1.02, 10), 0.0001)

func test_xp_for_next_level_is_the_next_levels_cost() -> void:
	PersistenceManager.save_game_data.core_density_level = 7.0
	assert_eq(CultivationManager.get_xp_for_next_level(), CultivationManager.get_xp_for_level(8))

func test_max_madra_at_a_level_follows_the_stages_curve() -> void:
	assert_eq(CultivationManager.get_max_madra_at(0), 100.0)
	assert_eq(CultivationManager.get_max_madra_at(12), 160.0, "100 + 5 x 12")

func test_max_madra_is_the_max_at_the_current_level() -> void:
	PersistenceManager.save_game_data.core_density_level = 32.0
	assert_eq(CultivationManager.get_max_madra(), CultivationManager.get_max_madra_at(32))
