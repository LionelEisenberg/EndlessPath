extends GutTest

## Unit tests for ItemDefinitionData's mini icon: the 16 px icon the zone view
## draws inline (activity card detail lines, the Now strip), set per item in
## its .tres, with the item's own icon as the fallback.

func test_mini_icon_defaults_to_none() -> void:
	assert_null(ItemDefinitionData.new().mini_icon)

func test_get_mini_icon_prefers_the_mini_icon() -> void:
	var item := ItemDefinitionData.new()
	item.icon = PlaceholderTexture2D.new()
	item.mini_icon = PlaceholderTexture2D.new()
	assert_eq(item.get_mini_icon(), item.mini_icon)

func test_get_mini_icon_falls_back_to_the_icon() -> void:
	var item := ItemDefinitionData.new()
	item.icon = PlaceholderTexture2D.new()
	assert_eq(item.get_mini_icon(), item.icon)

func test_get_mini_icon_is_null_without_either() -> void:
	assert_null(ItemDefinitionData.new().get_mini_icon())
