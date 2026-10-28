class_name MaterialSlot
extends TextureRect

## MaterialSlot
## One 72 px slot of the Materials page, pressed into the paper. Holding a
## material, it is a deep slot showing the material's 64 px icon, with how
## many the player has on a paper tag at its bottom right (2 px in from the
## right, 4 up from the bottom, as the mockup draws it). Empty, it is a
## shallow slot filling out the page. Printer's marks sit round it while the
## details show its material. Emits clicked for every gui_input event and
## hovered when the pointer enters.

signal clicked(slot: MaterialSlot, event: InputEvent)
## Emitted when the pointer enters the slot.
signal hovered(slot: MaterialSlot)

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _icon: TextureRect = %Icon
@onready var _count: PaperTag = %Count
@onready var _marks: Panel = %Marks

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _def: MaterialDefinitionData = null
var _qty: int = 0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	_refresh()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Shows a material and how many the player has, or empties the slot when
## `def` is null.
func setup(def: MaterialDefinitionData, qty: int) -> void:
	_def = def
	_qty = qty
	if is_node_ready():
		_refresh()

## Returns the material the slot holds, or null when it is empty.
func get_definition() -> MaterialDefinitionData:
	return _def

## Shows or hides the printer's marks round the slot.
func set_marked(marked: bool) -> void:
	_marks.visible = marked

## True while the printer's marks sit round the slot.
func is_marked() -> bool:
	return _marks.visible

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	clicked.emit(self, event)

func _on_mouse_entered() -> void:
	hovered.emit(self)

## Prints the slot: deep, with the icon and the count's tag, while it holds a
## material; shallow and bare while it is empty.
func _refresh() -> void:
	var filled: bool = _def != null
	texture = InventorySlot.DEEP_TEXTURE if filled else InventorySlot.SHALLOW_TEXTURE
	_icon.texture = _def.icon if filled else null
	_count.visible = filled
	if filled:
		_count.set_count(_qty)
