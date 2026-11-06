class_name StatDisplay
extends RefCounted

## StatDisplay
## How the screens show the six stats: the two sides they sit on, Physical and
## Spiritual, and each stat's name, icon and side. The one map the Character
## book and the Abilities book read. Statics only.

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

## Each stat's 16 px mini icon, drawn from its icon, for a line that names the
## stat beside a figure (the body refining board, its card and floaters). Only
## Strength has one so far: the drills that train Body and Agility bring theirs
## (#106).
const _MINI_ICONS: Dictionary = {
	CharacterAttributesData.AttributeType.STRENGTH: preload("res://assets/ui/lacquer/lacquer_mini_strength_ai.png"),
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

## The stat's 16 px mini icon, or null for a stat that has none yet (logged as
## an error).
static func mini_icon_of(stat: CharacterAttributesData.AttributeType) -> Texture2D:
	if not _MINI_ICONS.has(stat):
		Log.error("StatDisplay: No mini icon for attribute type %s" % stat)
		return null
	return _MINI_ICONS[stat]

## The side the stat sits on: "Physical" for Strength, Body and Agility, and
## "Spiritual" for the rest.
static func side_name(stat: CharacterAttributesData.AttributeType) -> String:
	return "Physical" if PHYSICAL.has(stat) else "Spiritual"
