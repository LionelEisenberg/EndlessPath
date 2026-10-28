extends GutTest

## Unit tests for ItemDefinitionData's mini icon: the 16 px icon the zone view
## draws inline (activity card detail lines, the Now strip), set per item in
## its .tres, with the item's own icon as the fallback. Also pins the Spirit
## Valley materials' 64 px icons, which the pressed pages show.

const DEWDROP_TEAR_PATH: String = "res://resources/items/materials/dewdrop_tear.tres"
const SPIRIT_FERN_PATH: String = "res://resources/items/materials/spirit_fern.tres"
const MINI_DEWDROP_PATH: String = "res://assets/ui/lacquer/lacquer_mini_dewdrop_ai.png"
const MINI_FERN_PATH: String = "res://assets/ui/lacquer/lacquer_mini_fern_ai.png"
const PRESSED_DEWDROP_PATH: String = "res://assets/sprites/items/materials/dewdrop_tear_ai.png"
const PRESSED_FERN_PATH: String = "res://assets/sprites/items/materials/spirit_fern_ai.png"

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

func test_spirit_valley_materials_carry_the_kit_mini_icons() -> void:
	assert_eq((load(DEWDROP_TEAR_PATH) as ItemDefinitionData).mini_icon, load(MINI_DEWDROP_PATH))
	assert_eq((load(SPIRIT_FERN_PATH) as ItemDefinitionData).mini_icon, load(MINI_FERN_PATH))

func test_spirit_valley_materials_have_their_pressed_icons() -> void:
	assert_eq((load(DEWDROP_TEAR_PATH) as ItemDefinitionData).icon, load(PRESSED_DEWDROP_PATH))
	assert_eq((load(SPIRIT_FERN_PATH) as ItemDefinitionData).icon, load(PRESSED_FERN_PATH))
