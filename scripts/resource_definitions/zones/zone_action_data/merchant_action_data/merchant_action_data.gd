class_name MerchantActionData
extends ZoneActionData

## MerchantActionData
## A zone action that opens a merchant's shop. The action stays current until
## the shop closes it through ActionManager.stop_action().

#-----------------------------------------------------------------------------
# EXPORTED PROPERTIES
#-----------------------------------------------------------------------------

## What this merchant sells.
@export var stock: MerchantStock

## One line shown under the shop title.
@export_multiline var greeting: String = ""

## The zone's merchant look (MerchantPanel, MerchantRow, MerchantButton,
## LabelMerchantTitle, HSeparatorMerchant and MerchantAtmosphere colours).
## Null keeps the shop scene's default theme.
@export var shop_theme: Theme

func _init() -> void:
	action_type = ZoneActionData.ActionType.MERCHANT
