extends TextureRect

## Wrapper for the inventory's anchored item description box.
## Delegates to the shared ItemDescriptionPanel.

@onready var _panel: ItemDescriptionPanel = %ItemDescriptionPanel

## Populates the description box with item data.
func setup(item_instance_data: ItemInstanceData) -> void:
	_panel.setup(item_instance_data)

## Resets the description box to empty state.
func reset() -> void:
	_panel.reset()
