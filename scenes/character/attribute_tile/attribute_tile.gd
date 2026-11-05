class_name AttributeTile
extends PanelContainer

## One stat on the Character book's left page, pressed into the paper: its
## icon in a pressed slot with the total on a paper tag at the slot's corner,
## its name, its level ("Lv 4"), and a bar of its XP toward the next level. At
## the stage's cap the bar is full and a CAPPED seal stamps across it. Emits
## hovered so the CharacterView can describe it on the right page, and wears
## printer's marks while it is the one described.

signal hovered(tile: AttributeTile)

@export var attribute_type: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.STRENGTH

@onready var _icon: TextureRect = %Icon
@onready var _value_label: Label = %ValueLabel
@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _xp_bar: LacquerRod = %XpBar
@onready var _cap_seal: Label = %CapSeal
@onready var _marks: Panel = %Marks

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	_name_label.text = StatDisplay.name_of(attribute_type)
	_icon.texture = StatDisplay.icon_of(attribute_type)

## Shows the stat's level, its XP toward the next level (a share of
## `xp_to_next`, none when that is 0) and its total. A capped stat shows a
## full bar with the CAPPED seal across it.
func set_stat(level: int, xp: float, xp_to_next: float, capped: bool, total: float) -> void:
	_level_label.text = "Lv %d" % level
	_value_label.text = "%.0f" % total
	# The paper tag hugs its text; an even width keeps its art on the 2 px grid.
	_value_label.custom_minimum_size.x = ceilf(_value_label.get_minimum_size().x / 2.0) * 2.0
	if capped:
		_xp_bar.set_fraction(1.0)
	else:
		_xp_bar.set_fraction(xp / xp_to_next if xp_to_next > 0.0 else 0.0)
	_cap_seal.visible = capped

## Shows or hides the printer's marks round the tile.
func set_selected(selected: bool) -> void:
	_marks.visible = selected

## True while the printer's marks sit round the tile.
func is_selected() -> bool:
	return _marks.visible

func _on_mouse_entered() -> void:
	hovered.emit(self)
