class_name StatCell
extends Control

## One stat on the cultivator cabinet: its icon in a ring of XP beads, with its
## name and "Lv N" under the ring. The beads light toward the next level, each
## only once its share of the XP is earned, and every bead is lit at the stage's
## cap. The cell never takes the pointer.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The ring's beads: the ring strip's frame n lights n of them, 0 to 24.
const RING_BEADS: int = 24
## The frame shown at the cap, the full ring: the strip has no capped frame of
## its own.
const RING_CAPPED_FRAME: int = 24

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The stat the cell shows.
@export var attribute_type: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.STRENGTH

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _xp_ring: LacquerStripRect = %XpRing
@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_name_label.text = StatDisplay.name_of(attribute_type)
	_icon.texture = StatDisplay.icon_of(attribute_type)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the stat's level and its XP toward the next level: of the ring's
## RING_BEADS beads, floor(xp × RING_BEADS / xp_to_next) are lit (none when
## xp_to_next is 0), so a bead lights only once its share is earned. A capped
## stat shows the full ring.
func set_stat(level: int, xp: float, xp_to_next: float, capped: bool) -> void:
	_level_label.text = "Lv %d" % level
	if capped:
		_xp_ring.set_frame(RING_CAPPED_FRAME)
	else:
		var lit_beads: int = floori(xp * RING_BEADS / xp_to_next) if xp_to_next > 0.0 else 0
		_xp_ring.set_frame(clampi(lit_beads, 0, RING_BEADS))
