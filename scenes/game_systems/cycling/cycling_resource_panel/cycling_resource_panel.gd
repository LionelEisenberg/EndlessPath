class_name CyclingResourcePanel
extends MarginContainer

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
var madra_rate: float = 0.0  # Current madra generation rate
var is_cycling: bool = false

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready():
	if not ResourceManager:
		push_error("Critical - update_madra_display: ResourceManager is missing!")
		return
	if not CultivationManager:
		push_error("Critical - update_madra_display: CultivationManager is missing!")
		return

	setup_ui()
	connect_signals()
	update_all_displays()

func setup_ui():
	"""Initialize UI elements with proper styling"""
	# Setup circular progress bar
	madra_circle_progress.radial_fill_degrees = 360
	madra_circle_progress.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	
	# Setup core ball initial scale
	core_density_sprite.scale = Vector2(0.5, 0.5)
	
	# Setup button
	open_technique_selector_button.pressed.connect(_on_open_technique_selector)

func connect_signals():
	"""Connect to singleton signals for live updates"""
	if ResourceManager:
		ResourceManager.madra_changed.connect(_on_madra_changed)
	
	if CultivationManager:
		CultivationManager.core_density_xp_updated.connect(_on_core_density_updated)
		CultivationManager.advancement_stage_changed.connect(_on_stage_changed)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

func set_technique_data(technique: CyclingTechniqueData):
	"""Set the current technique data and update display"""
	current_technique_data = technique
	update_technique_info()

func set_cycling_state(cycling: bool):
	"""Update cycling state for rate calculations"""
	is_cycling = cycling
	update_madra_rate()

func set_madra_rate(rate: float):
	"""Set the current madra generation rate"""
	madra_rate = rate
	update_madra_rate()

#-----------------------------------------------------------------------------
# UPDATE FUNCTIONS
#-----------------------------------------------------------------------------

func update_all_displays():
	"""Update all display elements"""
	update_madra_display()
	update_core_density()
	update_stage()
	update_technique_info()

func update_madra_display():
	"""Update madra section with current values"""

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

func update_madra_rate():
	"""Update madra rate display"""
	if is_cycling and madra_rate > 0:
		madra_generation_rate_label.text = "+%.1f/s" % madra_rate
		madra_generation_rate_label.modulate = Color(0.0, 1.0, 0.0)  # Green
	else:
		madra_generation_rate_label.text = "+0.0/s"
		madra_generation_rate_label.modulate = Color(0.7, 0.7, 0.7)  # Gray

func update_core_density():
	"""Update core density section with current values"""
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
	var normalized = clamp(level / 100.0, 0.0, 1.0)
	core_density_sprite.scale = Vector2(normalized, normalized)

func update_stage():
	"""Update cultivation stage display"""
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

func update_technique_info():
	"""Update technique information section"""
	if not current_technique_data:
		technique_name_label.text = "Technique: None"
		technique_stats_label.text = "⚡ Madra: +0.0/s | ⭐ XP: 0/click"
		return
	technique_name_label.text = "Technique: %s" % current_technique_data.technique_name
	# Show all stats available in the resource data
	var msg = "⚡ Madra: +%.1f/s" % current_technique_data.base_madra_per_second
	technique_stats_label.text = msg

#-----------------------------------------------------------------------------
# HELPER FUNCTIONS
#-----------------------------------------------------------------------------

func get_next_stage_name() -> String:
	"""Get the name of the next cultivation stage"""
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

func _on_madra_changed(new_amount: float):
	"""Handle madra changes from ResourceManager"""
	update_madra_display()

func _on_core_density_updated(xp: float, level: float):
	"""Handle core density updates from CultivationManager"""
	update_core_density()

func _on_stage_changed(new_stage):
	"""Handle cultivation stage changes"""
	update_stage()

func _on_open_technique_selector():
	"""Handle change technique button press"""
	open_technique_selector.emit()
