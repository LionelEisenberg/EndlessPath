class_name CyclingResourcePanel
extends MarginContainer

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

# UI visual constants
const INITIAL_CORE_SCALE = Vector2(0.5, 0.5)
const MAX_CORE_DENSITY_LEVEL = 100.0
const COLOR_CYCLING = Color(0.0, 1.0, 0.0)  # Green when actively cycling
const COLOR_IDLE = Color(0.7, 0.7, 0.7)  # Gray when idle

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------
signal open_technique_selector

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------
@onready var madra_circle_progress: TextureProgressBar = %MadraCircleProgressBar
@onready var madra_amount_label: Label = %MadraAmountLabel
@onready var madra_generation_rate_label: Label = %MadraGenerationRateLabel

@onready var core_density_sprite: Sprite2D = %CoreDensitySprite
@onready var core_density_level_label: Label = %CoreDensityLevelLabel
@onready var core_density_xp_progress_bar: ProgressBar = %CoreDensityXPProgressBar
@onready var core_density_xp_label: Label = %CoreDensityXPLabel

@onready var cultivation_stage_label: Label = %CultivationStageLabel
@onready var next_cultivation_stage_label: Label = %NextCultivationStageLabel

@onready var technique_name_label: Label = %TechniqueNameLabel
@onready var technique_stats_label: Label = %TechniqueStatsLabel
@onready var open_technique_selector_button: Button = %OpenTechniqueSelectorButton

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------
var current_technique_data: CyclingTechniqueData = null
var is_cycling: bool = false
var last_madra_per_second: float = 0.0  # Madra per second from last completed cycle
var last_madra_per_cycle: float = 0.0  # Madra per cycle from last completed cycle

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if not ResourceManager:
		Log.critical("CyclingResourcePanel: ResourceManager is missing!")
		return
	if not CultivationManager:
		Log.critical("CyclingResourcePanel: CultivationManager is missing!")
		return

	setup_ui()
	connect_signals()
	update_all_displays()

## Initialize UI elements with proper styling.
func setup_ui():
	# Setup circular progress bar
	madra_circle_progress.radial_fill_degrees = 360
	madra_circle_progress.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	
	# Setup core ball initial scale
	core_density_sprite.scale = INITIAL_CORE_SCALE
	
	# Setup button
	open_technique_selector_button.pressed.connect(_on_open_technique_selector)

## Connect to singleton signals for live updates.
func connect_signals():
	if ResourceManager:
		ResourceManager.madra_changed.connect(_on_madra_changed)
	
	if CultivationManager:
		CultivationManager.core_density_xp_updated.connect(_on_core_density_updated)
		CultivationManager.advancement_stage_changed.connect(_on_stage_changed)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Set the current technique data and update display.
func set_technique_data(technique: CyclingTechniqueData):
	current_technique_data = technique
	update_technique_info()

## Handle cycling started signal.
func on_cycling_started():
	is_cycling = true
	update_madra_rate()

## Handle cycle completed signal and calculate madra per second.
func on_cycle_completed(madra_earned: float, _mouse_accuracy: float):
	is_cycling = false
	
	# Store madra per cycle from last cycle
	last_madra_per_cycle = madra_earned
	
	# Calculate madra per second from last cycle
	if current_technique_data and current_technique_data.cycle_duration > 0:
		last_madra_per_second = madra_earned / current_technique_data.cycle_duration
	else:
		last_madra_per_second = 0.0
	
	update_madra_rate()

#-----------------------------------------------------------------------------
# UPDATE FUNCTIONS
#-----------------------------------------------------------------------------

## Update all display elements.
func update_all_displays():
	update_madra_display()
	update_core_density()
	update_stage()
	update_technique_info()

## Update madra section with current values.
func update_madra_display():

	var current_madra = ResourceManager.get_madra()
	var level = CultivationManager.get_core_density_level()
	var stage_res = CultivationManager._get_current_stage_resource()
	var max_madra = stage_res.get_max_madra(level) if stage_res else 0.0

	# Update progress bar (0-100%)
	var progress = (current_madra / max_madra) * 100.0 if max_madra > 0 else 0.0
	madra_circle_progress.value = progress

	# Update labels
	madra_amount_label.text = "Madra: %d / %d" % [int(current_madra), int(max_madra)]
	update_madra_rate()

## Update madra rate display using last cycle's madra per second and per cycle.
func update_madra_rate():
	var display_text = "+%.1f/s\n%.1f/cycle" % [last_madra_per_second, last_madra_per_cycle]
	
	if is_cycling:
		# Show last cycle's rate while cycling
		madra_generation_rate_label.text = display_text
		madra_generation_rate_label.modulate = COLOR_CYCLING
	else:
		# Show last cycle's rate
		madra_generation_rate_label.text = display_text
		madra_generation_rate_label.modulate = COLOR_IDLE

## Update core density section with current values.
func update_core_density():
	if not CultivationManager:
		return
	
	var xp = CultivationManager.get_core_density_xp()
	var level = CultivationManager.get_core_density_level()
	var max_xp = CultivationManager.get_xp_for_next_level()

	# Update level label
	core_density_level_label.text = "Level: %d" % int(level)

	# Update XP progress bar
	var xp_progress = (xp / max_xp) * 100.0
	core_density_xp_progress_bar.value = xp_progress
	core_density_xp_label.text = "XP: %d / %d" % [int(xp), int(max_xp)]

	# Update core sprite scale based on LEVEL (0-100 maps to 0-1.0 scale)
	var normalized = clamp(level / MAX_CORE_DENSITY_LEVEL, 0.0, 1.0)
	core_density_sprite.scale = Vector2(normalized, normalized)

## Update cultivation stage display.
func update_stage():
	if not CultivationManager:
		return
	var stage_res = CultivationManager._get_current_stage_resource()
	if stage_res:
		cultivation_stage_label.text = "Stage: %s" % stage_res.stage_name
	else:
		cultivation_stage_label.text = "Stage: Unknown"

	# Show next stage name if you have next_stage data available
	var next_stage_label_text = "(MAX)"
	if stage_res and stage_res.next_stage:
		next_stage_label_text = "(Next: %s)" % stage_res.next_stage.stage_name
	if next_cultivation_stage_label:
		next_cultivation_stage_label.text = next_stage_label_text

## Update technique information section.
func update_technique_info():
	if not current_technique_data:
		technique_name_label.text = "Technique: None"
		technique_stats_label.text = "⚡ Madra: +0.0/s | ⭐ XP: 0/click"
		return
	technique_name_label.text = "Technique: %s" % current_technique_data.technique_name
	# Show all stats available in the resource data
	var msg = "⚡ Madra: %.1f/cycle" % current_technique_data.base_madra_per_cycle
	technique_stats_label.text = msg

#-----------------------------------------------------------------------------
# HELPER FUNCTIONS
#-----------------------------------------------------------------------------

## Get the name of the next cultivation stage.
func get_next_stage_name() -> String:
	if not CultivationManager:
		return "Unknown"
	
	var current_stage = CultivationManager.get_current_advancement_stage()
	var next_stage = current_stage + 1
	
	if next_stage >= CultivationManager.AdvancementStage.size():
		return "MAX"
	
	return CultivationManager.get_advancement_stage_name(next_stage)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## Handle madra changes from ResourceManager.
func _on_madra_changed(_new_amount: float):
	update_madra_display()

## Handle core density updates from CultivationManager.
func _on_core_density_updated(_xp: float, _level: float):
	update_core_density()

## Handle cultivation stage changes.
func _on_stage_changed(_new_stage):
	update_stage()

## Handle change technique button press.
func _on_open_technique_selector():
	open_technique_selector.emit()
