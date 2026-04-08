class_name CyclingResourcePanel
extends MarginContainer

## CyclingResourcePanel
## Compact resource display for the cycling view's Resources tab.
## Shows Madra, Core Density, and active technique summary.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const MAX_CORE_DENSITY_LEVEL: float = 100.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _madra_circle: ProgressShaderRect = %MadraCircle
@onready var _madra_amount_label: Label = %MadraAmountLabel
@onready var _madra_rate_label: Label = %MadraGenerationRateLabel

@onready var _core_density_circle: ProgressShaderRect = %CoreDensityRect
@onready var _core_density_level_label: Label = %CoreDensityLevelLabel
@onready var _core_density_xp_label: Label = %CoreDensityXPLabel
@onready var _core_density_xp_bar: ProgressBar = %CoreDensityXPProgressBar
@onready var _stage_label: Label = %StageLabel

@onready var _technique_name_label: RichTextLabel = %TechniqueNameLabel
@onready var _technique_stats_label: RichTextLabel = %TechniqueStatsLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _current_technique: CyclingTechniqueData = null
var _is_cycling: bool = false
var _last_madra_per_second: float = 0.0
var _last_madra_per_cycle: float = 0.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	if ResourceManager:
		ResourceManager.madra_changed.connect(_on_madra_changed)
	if CultivationManager:
		CultivationManager.core_density_xp_updated.connect(_on_core_density_xp_updated)
		CultivationManager.advancement_stage_changed.connect(_on_advancement_stage_changed)
	_update_all_displays()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Set the active technique and update the summary display.
func set_technique_data(data: CyclingTechniqueData) -> void:
	_current_technique = data
	if is_node_ready():
		_update_technique_display()

## Get the global position of the Madra orb center (for particle targets).
func get_madra_orb_global_position() -> Vector2:
	return _madra_circle.global_position + _madra_circle.size * 0.5

## Get the global position of the Core Density orb center (for particle targets).
func get_core_density_orb_global_position() -> Vector2:
	return _core_density_circle.global_position + _core_density_circle.size * 0.5

## Called when a cycle starts.
func on_cycling_started() -> void:
	_is_cycling = true
	_update_madra_rate_display()

## Called when a cycle completes.
func on_cycle_completed(madra_earned: float, _mouse_accuracy: float) -> void:
	_last_madra_per_cycle = madra_earned
	if _current_technique:
		_last_madra_per_second = madra_earned / _current_technique.cycle_duration
	_update_madra_rate_display()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _on_madra_changed(_amount: float) -> void:
	_update_madra_display()

func _on_core_density_xp_updated(_xp: float, _level: float) -> void:
	_update_core_density_display()

func _on_advancement_stage_changed(_new_stage: CultivationManager.AdvancementStage) -> void:
	_update_stage_display()

func _update_all_displays() -> void:
	_update_madra_display()
	_update_core_density_display()
	_update_stage_display()
	_update_technique_display()
	_update_madra_rate_display()

func _update_madra_display() -> void:
	if not ResourceManager or not CultivationManager:
		return
	var current: float = ResourceManager.get_madra()
	var level: float = CultivationManager.get_core_density_level()
	var stage_res: AdvancementStageResource = CultivationManager._get_current_stage_resource()
	var max_madra: float = stage_res.get_max_madra(level) if stage_res else 0.0
	_madra_amount_label.text = "Madra: %d / %d" % [current, max_madra]

	if _madra_circle:
		var progress: float = current / max_madra if max_madra > 0 else 0.0
		_madra_circle.set_value(progress)

func _update_madra_rate_display() -> void:
	if _is_cycling:
		_madra_rate_label.text = "+%.1f/s  %.1f/cycle" % [_last_madra_per_second, _last_madra_per_cycle]
	else:
		if _current_technique:
			_madra_rate_label.text = "%.1f/cycle" % _current_technique.base_madra_per_cycle
		else:
			_madra_rate_label.text = ""

func _update_core_density_display() -> void:
	if not CultivationManager:
		return
	var level: float = CultivationManager.get_core_density_level()
	var xp: float = CultivationManager.get_core_density_xp()
	var max_xp: float = CultivationManager.get_xp_for_next_level()

	_core_density_level_label.text = "Level: %d" % int(level)
	_core_density_xp_label.text = "XP: %d / %d" % [xp, max_xp]

	var xp_ratio: float = xp / max_xp if max_xp > 0 else 0.0
	_core_density_xp_bar.value = xp_ratio * 100.0

	if _core_density_circle:
		var density_progress: float = level / MAX_CORE_DENSITY_LEVEL
		_core_density_circle.set_value(density_progress)

func _update_stage_display() -> void:
	if not CultivationManager:
		return
	var stage_name: String = CultivationManager.get_current_advancement_stage_name()
	_stage_label.text = "Stage: %s" % stage_name

func _update_technique_display() -> void:
	if not is_node_ready():
		return
	if _current_technique == null:
		_technique_name_label.text = "[center][font_size=36][color=#D4A84A]No Technique[/color][/font_size][/center]"
		_technique_stats_label.text = ""
		return
	_technique_name_label.text = "[center][font_size=36][color=#D4A84A]%s[/color][/font_size][/center]" % _current_technique.technique_name
	var zones_count: int = _current_technique.cycling_zones.size()
	_technique_stats_label.text = "[font_size=28][table=2][cell][color=#7a6a52]Madra/cycle[/color][/cell][cell][color=#F0E8D8]%.0f[/color][/cell][cell][color=#7a6a52]Duration[/color][/cell][cell][color=#F0E8D8]%.0fs[/color][/cell][cell][color=#7a6a52]Zones[/color][/cell][cell][color=#F0E8D8]%d[/color][/cell][/table][/font_size]" % [
		_current_technique.base_madra_per_cycle,
		_current_technique.cycle_duration,
		zones_count
	]
