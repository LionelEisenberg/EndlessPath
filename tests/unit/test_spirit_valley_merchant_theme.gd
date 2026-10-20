extends GutTest

## Content tests for the Spirit Valley merchant theme: it defines every variant
## and colour the shop reads. A variant without a base type is ignored, so its
## node falls back to plain styling. A missing MerchantAtmosphere colour renders
## opaque black.

const THEME_PATH: String = "res://assets/themes/merchant/spirit_valley_merchant_theme.tres"

const VARIANTS: Array[StringName] = [
	&"MerchantPanel",
	&"MerchantRow",
	&"MerchantButton",
	&"LabelMerchantTitle",
	&"HSeparatorMerchant",
]

## [variant, data type, item name] for what the shop's nodes read from each
## variant. MerchantButton covers every state, disabled included. The title
## inherits LabelTitle's colours, but not its size: pixel_theme.tres's default
## font size answers first, so the title repeats it.
const VARIANT_ITEMS: Array[Array] = [
	[&"MerchantPanel", Theme.DATA_TYPE_STYLEBOX, &"panel"],
	[&"MerchantRow", Theme.DATA_TYPE_STYLEBOX, &"panel"],
	[&"MerchantButton", Theme.DATA_TYPE_STYLEBOX, &"normal"],
	[&"MerchantButton", Theme.DATA_TYPE_STYLEBOX, &"hover"],
	[&"MerchantButton", Theme.DATA_TYPE_STYLEBOX, &"pressed"],
	[&"MerchantButton", Theme.DATA_TYPE_STYLEBOX, &"disabled"],
	[&"LabelMerchantTitle", Theme.DATA_TYPE_COLOR, &"font_outline_color"],
	[&"LabelMerchantTitle", Theme.DATA_TYPE_CONSTANT, &"outline_size"],
	[&"LabelMerchantTitle", Theme.DATA_TYPE_FONT_SIZE, &"font_size"],
	[&"HSeparatorMerchant", Theme.DATA_TYPE_STYLEBOX, &"separator"],
]

const ATMOSPHERE_COLOURS: Array[StringName] = [
	&"mist",
	&"mote_primary",
	&"mote_secondary",
	&"light",
	&"slot_glow",
]

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _theme() -> Theme:
	return load(THEME_PATH) as Theme

#-----------------------------------------------------------------------------
# VARIANTS
#-----------------------------------------------------------------------------

func test_every_variant_has_a_base_type() -> void:
	var theme := _theme()
	for variant: StringName in VARIANTS:
		assert_ne(theme.get_type_variation_base(variant), &"", "%s needs a base type or Godot ignores it" % variant)

func test_variants_define_what_the_shop_reads() -> void:
	var theme := _theme()
	for variant_item: Array in VARIANT_ITEMS:
		var variant: StringName = variant_item[0]
		var item_name: StringName = variant_item[2]
		assert_true(theme.has_theme_item(variant_item[1], item_name, variant), "%s needs %s" % [variant, item_name])

#-----------------------------------------------------------------------------
# ATMOSPHERE
#-----------------------------------------------------------------------------

func test_defines_every_atmosphere_colour() -> void:
	var theme := _theme()
	for colour: StringName in ATMOSPHERE_COLOURS:
		assert_true(theme.has_color(colour, &"MerchantAtmosphere"), "MerchantAtmosphere %s would render opaque black" % colour)
