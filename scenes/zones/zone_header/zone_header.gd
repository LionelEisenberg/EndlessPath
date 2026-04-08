extends PanelContainer
## Floating zone header displaying the current zone name and description.

@onready var zone_name_label: Label = %ZoneNameLabel
@onready var zone_description_label: RichTextLabel = %ZoneDescriptionLabel

func _ready() -> void:
	ZoneManager.zone_changed.connect(_on_zone_changed)
	_update_zone_info()

func _update_zone_info() -> void:
	var zone_data: ZoneData = ZoneManager.get_current_zone()
	if zone_data == null:
		return
	zone_name_label.text = zone_data.zone_name
	zone_description_label.text = zone_data.description

func _on_zone_changed(_zone_data: ZoneData) -> void:
	_update_zone_info()
