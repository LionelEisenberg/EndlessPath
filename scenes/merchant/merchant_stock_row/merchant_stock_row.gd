class_name MerchantStockRow
extends PanelContainer

## MerchantStockRow
## One line of the merchant shop: icon (hover shows the item description),
## name, effects, price and a Buy button. It only displays data: MerchantView
## decides the status and does the buying.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted when the player presses Buy on this row.
signal buy_pressed(entry: MerchantStockEntry)

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const THEME_TYPE := &"MerchantAtmosphere"
const MSG_NEED_GOLD := "Need %d more gold"
const MSG_EQUIPMENT_FULL := "Equipment full"

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _slot_glow: TextureRect = %SlotGlow
@onready var _item_slot: ItemDisplaySlot = %ItemSlot
@onready var _name_label: Label = %NameLabel
@onready var _detail_label: RichTextLabel = %DetailLabel
@onready var _block_reason_label: Label = %BlockReasonLabel
@onready var _sold_out_label: Label = %SoldOutLabel
@onready var _price_box: HBoxContainer = %PriceBox
@onready var _price_label: Label = %PriceLabel
@onready var _buy_button: Button = %BuyButton

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _entry: MerchantStockEntry = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_button_pressed)
	_apply_theme_colours()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_apply_theme_colours()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Shows the entry's item: icon, name, effects line and price.
func set_entry(entry: MerchantStockEntry) -> void:
	_entry = entry
	_item_slot.setup_from_definition(entry.item)
	_name_label.text = entry.item.item_name
	_detail_label.text = _format_detail(entry.item)
	_price_label.text = str(entry.get_price())

## Shows what the player can do with this entry right now: Buy enabled only
## for OK, a red reason for missing gold or equipment space, "Sold out" in
## place of the price and button.
func set_status(status: MerchantManager.PurchaseResult, gold_shortfall: int) -> void:
	var sold_out := status == MerchantManager.PurchaseResult.SOLD_OUT
	_sold_out_label.visible = sold_out
	_price_box.visible = not sold_out
	_buy_button.visible = not sold_out
	_buy_button.disabled = status != MerchantManager.PurchaseResult.OK

	match status:
		MerchantManager.PurchaseResult.INSUFFICIENT_GOLD:
			_block_reason_label.text = MSG_NEED_GOLD % gold_shortfall
			_block_reason_label.visible = true
		MerchantManager.PurchaseResult.EQUIPMENT_FULL:
			_block_reason_label.text = MSG_EQUIPMENT_FULL
			_block_reason_label.visible = true
		_:
			_block_reason_label.visible = false

## The entry this row shows, or null if the row was never bound.
func get_entry() -> MerchantStockEntry:
	return _entry

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## "<Slot or type>: <effects>", e.g. "Main Hand: +5 Strength, +2 Agility".
func _format_detail(item: ItemDefinitionData) -> String:
	var kind := item._get_item_type()
	if item is EquipmentDefinitionData:
		var slot: int = (item as EquipmentDefinitionData).slot_type
		kind = EquipmentDefinitionData.EquipmentSlot.keys()[slot].replace("_", " ").capitalize()
	var effects := item._get_item_effects()
	if effects.is_empty():
		return kind
	return "%s: %s" % [kind, ", ".join(effects)]

func _apply_theme_colours() -> void:
	_slot_glow.self_modulate = get_theme_color(&"slot_glow", THEME_TYPE)

func _on_buy_button_pressed() -> void:
	if _entry:
		buy_pressed.emit(_entry)
