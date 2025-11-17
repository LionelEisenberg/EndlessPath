extends PanelContainer

@onready var technique_name_label: Label = %TechniqueNameLabel
@onready var madra_rate_label: Label = %MadraRateLabel
@onready var duration_label: Label = %DurationLabel
@onready var cycling_zones_header: Label = %CyclingZonesHeader
@onready var cycling_zones_info: Label = %CyclingZonesInfo
@onready var change_technique_button: Button = %ChangeTechniqueButton


func setup(data: CyclingTechniqueData) -> void:
	technique_name_label.text = data.technique_name
	madra_rate_label.text = "Madra/cycle: %.1f" % data.base_madra_per_cycle
	duration_label.text = "Duration: %.0f s" % data.cycle_duration
	cycling_zones_info.text = "Cycling Zones: %s" % data.cycling_zones.size()
