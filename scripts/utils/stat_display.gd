class_name StatDisplay
extends RefCounted

## StatDisplay
## How the screens show the six stats: the two sides they sit on, Physical and
## Spiritual, each stat's name, icon and side, and the icon that stands for each
## side. The one map the Character book, the Abilities book and the zone cards
## read. Statics only.

## The two sides the stats sit on.
enum StatSide { PHYSICAL, SPIRITUAL }

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The Physical stats, in the order the screens list them.
const PHYSICAL: Array[CharacterAttributesData.AttributeType] = [
	CharacterAttributesData.AttributeType.STRENGTH,
	CharacterAttributesData.AttributeType.BODY,
	CharacterAttributesData.AttributeType.AGILITY,
]

## The Spiritual stats, in the order the screens list them.
const SPIRITUAL: Array[CharacterAttributesData.AttributeType] = [
	CharacterAttributesData.AttributeType.SPIRIT,
	CharacterAttributesData.AttributeType.MIND,
	CharacterAttributesData.AttributeType.CONTROL,
]

## Each Physical stat's 16 px mini icon, drawn from its icon, for a line that
## names the stat beside a figure (the body refining board, its card, its floaters
## and its drill drawers). Body's is its heart in steel, apart from the Health
## heart.
const _MINI_ICONS: Dictionary = {
	CharacterAttributesData.AttributeType.STRENGTH: preload("res://assets/ui/lacquer/lacquer_mini_strength_ai.png"),
	CharacterAttributesData.AttributeType.BODY: preload("res://assets/ui/lacquer/lacquer_mini_body_ai.png"),
	CharacterAttributesData.AttributeType.AGILITY: preload("res://assets/ui/lacquer/lacquer_mini_agility_ai.png"),
}

## Each stat's icon. Mind keeps the icon Foundation had.
const _ICONS: Dictionary = {
	CharacterAttributesData.AttributeType.STRENGTH: preload("res://assets/sprites/ui/attribute_icons/strength_icon.png"),
	CharacterAttributesData.AttributeType.BODY: preload("res://assets/sprites/ui/attribute_icons/body_icon.png"),
	CharacterAttributesData.AttributeType.AGILITY: preload("res://assets/sprites/ui/attribute_icons/agility_icon.png"),
	CharacterAttributesData.AttributeType.SPIRIT: preload("res://assets/sprites/ui/attribute_icons/spirit_icon.png"),
	CharacterAttributesData.AttributeType.MIND: preload("res://assets/sprites/ui/attribute_icons/foundation_icon.png"),
	CharacterAttributesData.AttributeType.CONTROL: preload("res://assets/sprites/ui/attribute_icons/control_icon_ai.png"),
}

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## The stat's name as the screens print it: "Strength", "Mind".
static func name_of(stat: CharacterAttributesData.AttributeType) -> String:
	return CharacterManager.get_attribute_display_name(stat)

## The stat's icon, or null for a stat that has none (logged as an error).
static func icon_of(stat: CharacterAttributesData.AttributeType) -> Texture2D:
	if not _ICONS.has(stat):
		Log.error("StatDisplay: No icon for attribute type %s" % stat)
		return null
	return _ICONS[stat]

## The stat's 16 px mini icon, or null for a stat whose mini is not drawn yet: a
## line then names the stat in words.
static func mini_icon_of(stat: CharacterAttributesData.AttributeType) -> Texture2D:
	return _MINI_ICONS.get(stat, null)

## The side the stat sits on: "Physical" for Strength, Body and Agility, and
## "Spiritual" for the rest.
static func side_name(stat: CharacterAttributesData.AttributeType) -> String:
	return "Physical" if PHYSICAL.has(stat) else "Spiritual"

## The icon that stands for a whole side, where a screen names the side by an
## icon (the Cycling and Riverbank Training cards): its first stat's, Strength's
## for the Physical side and Spirit's for the Spiritual side, until the sides have
## icons of their own (the user's call on #145).
static func side_icon(side: StatSide) -> Texture2D:
	return icon_of(PHYSICAL[0] if side == StatSide.PHYSICAL else SPIRITUAL[0])
