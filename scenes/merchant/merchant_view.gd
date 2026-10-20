class_name MerchantView
extends Control

## MerchantView
## The merchant's shop overlay. Binds a MerchantActionData's stock to the
## pre-built rows, applies the merchant's zone theme, asks MerchantManager
## what each row may do and buys on Buy. Leave and Escape close it through
## MerchantViewState, which stops the merchant action.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted when the player presses Leave.
signal close_requested

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const MSG_BOUGHT := "Bought %s."

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _animation_player: AnimationPlayer = %AnimationPlayer
@onready var _title_label: Label = %TitleLabel
@onready var _greeting_label: Label = %GreetingLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _stock_list: VBoxContainer = %StockList
@onready var _status_label: Label = %StatusLabel
@onready var _leave_button: Button = %LeaveButton

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _stock: MerchantStock = null
var _rows: Array[MerchantStockRow] = []
## The theme the scene was saved with (Spirit Valley); used when a merchant has no shop_theme.
var _default_theme: Theme = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_default_theme = theme
	for child: Node in _stock_list.get_children():
		if child is MerchantStockRow:
			var row := child as MerchantStockRow
			_rows.append(row)
			row.buy_pressed.connect(_on_row_buy_pressed)
	_leave_button.pressed.connect(_on_leave_button_pressed)
	ResourceManager.gold_changed.connect(_on_gold_changed)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Shows the merchant: its zone theme, title, greeting and stock. Rows beyond
## the stock are hidden; stock beyond the rows is left out with a warning, and
## so is an entry with no item (its row stays hidden).
func setup(action_data: MerchantActionData) -> void:
	theme = action_data.shop_theme if action_data.shop_theme else _default_theme
	_title_label.text = action_data.action_name
	_greeting_label.text = action_data.greeting
	_greeting_label.visible = not action_data.greeting.is_empty()
	_status_label.text = ""

	_stock = action_data.stock
	var entries: Array[MerchantStockEntry] = []
	if _stock:
		entries = _stock.entries
	if entries.size() > _rows.size():
		Log.warn("MerchantView: %s sells %d entries but the shop has %d rows; the rest are hidden" % [
			action_data.action_id, entries.size(), _rows.size()])
	for i: int in _rows.size():
		var row := _rows[i]
		row.visible = false
		if i >= entries.size():
			continue
		var entry := entries[i]
		if entry == null or entry.item == null:
			Log.warn("MerchantView: %s stock entry %d has no item; its row is hidden" % [action_data.action_id, i])
			continue
		row.set_entry(entry)
		row.visible = true
	_refresh()

## Plays the open animation.
func animate_open() -> void:
	_animation_player.play("open")

## Plays the close animation.
func animate_close() -> void:
	_animation_player.play("close")

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _refresh() -> void:
	_gold_label.text = str(int(ResourceManager.get_gold()))
	if _stock == null:
		return
	for row: MerchantStockRow in _rows:
		var entry := row.get_entry()
		if row.visible and entry:
			row.set_status(MerchantManager.get_purchase_status(_stock, entry), MerchantManager.get_gold_shortfall(entry))

## setup() refreshes when the shop opens, so a closed shop skips the work.
func _refresh_if_visible() -> void:
	if is_visible_in_tree():
		_refresh()

func _on_row_buy_pressed(entry: MerchantStockEntry) -> void:
	if MerchantManager.purchase(_stock, entry) == MerchantManager.PurchaseResult.OK:
		_status_label.text = MSG_BOUGHT % entry.item.item_name
	_refresh()

func _on_leave_button_pressed() -> void:
	close_requested.emit()

func _on_gold_changed(_new_amount: float) -> void:
	_refresh_if_visible()

func _on_inventory_changed(_inventory: InventoryData) -> void:
	_refresh_if_visible()
