class_name MerchantPresenter
extends ZoneActionPresenter
## Presenter for MERCHANT cards: "<n> wares · you have <gold> gold", where the
## wares are the stock lines not yet sold out. It follows gold and purchases.

@onready var _detail_label: Label = %DetailLabel

## Moves the detail into the card and fills it.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_detail_label.reparent(button.get_detail_slot(), false)
	ResourceManager.gold_changed.connect(_on_gold_changed)
	MerchantManager.item_purchased.connect(_on_item_purchased)
	_refresh()

## Disconnects from the managers before the card goes.
func teardown() -> void:
	if ResourceManager.gold_changed.is_connected(_on_gold_changed):
		ResourceManager.gold_changed.disconnect(_on_gold_changed)
	if MerchantManager.item_purchased.is_connected(_on_item_purchased):
		MerchantManager.item_purchased.disconnect(_on_item_purchased)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _refresh() -> void:
	_detail_label.text = "%d wares · you have %d gold" % [_count_wares(), floori(ResourceManager.get_gold())]
	button.fit_detail_label(_detail_label)

## Stock lines the merchant can still sell this save.
func _count_wares() -> int:
	var merchant := action_data as MerchantActionData
	if merchant == null or merchant.stock == null:
		return 0
	var wares: int = 0
	for entry: MerchantStockEntry in merchant.stock.entries:
		if MerchantManager.get_remaining_stock(merchant.stock, entry) != 0:
			wares += 1
	return wares

func _on_gold_changed(_new_amount: float) -> void:
	_refresh()

func _on_item_purchased(_stock: MerchantStock, _entry: MerchantStockEntry) -> void:
	_refresh()
