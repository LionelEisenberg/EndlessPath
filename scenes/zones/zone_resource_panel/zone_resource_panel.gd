class_name ZoneResourcePanel
extends PanelContainer

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------
@onready var madra_circle: ProgressShaderRect = %MadraCircle
@onready var madra_label: Label = %MadraLabel

@onready var core_density_rect: ProgressShaderRect = %CoreDensityRect
@onready var core_density_label: Label = %CoreDensityLabel

@onready var gold_label: Label = %GoldLabel

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------
func _ready() -> void:
	if not ResourceManager:
		Log.critical("ZoneResourcePanel: ResourceManager is missing!")
		return
	if not CultivationManager:
		Log.critical("ZoneResourcePanel: CultivationManager is missing!")
		return

	_connect_signals()
	_update_all_displays()

func _connect_signals() -> void:
	if ResourceManager:
		ResourceManager.madra_changed.connect(_on_madra_changed)
		ResourceManager.gold_changed.connect(_on_gold_changed)
	
	if CultivationManager:
		CultivationManager.core_density_level_updated.connect(_on_core_density_updated)
		CultivationManager.advancement_stage_changed.connect(_on_stage_changed)

#-----------------------------------------------------------------------------
# UPDATE FUNCTIONS
#-----------------------------------------------------------------------------
func _update_all_displays() -> void:
	_update_madra()
	_update_core_density()
	_update_gold()

func _update_madra() -> void:
	var current_madra = ResourceManager.get_madra()
	var level = CultivationManager.get_core_density_level()
	var stage_res = CultivationManager._get_current_stage_resource()
	var max_madra = stage_res.get_max_madra(level) if stage_res else 0.0
	
	# Update Shader
	var progress = current_madra / max_madra if max_madra > 0 else 0.0
	if madra_circle:
		madra_circle.set_value(progress)
	
	# Update Label
	if madra_label:
		madra_label.text = "%d / %d" % [int(current_madra), int(max_madra)]

func _update_core_density() -> void:
	var level = CultivationManager.get_core_density_level()
	var stage_name = CultivationManager.get_current_advancement_stage_name()
	
	var max_level_cap = 100.0
	var progress = level / max_level_cap
	if core_density_rect:
		core_density_rect.set_value(progress)
	
	if core_density_label:
		core_density_label.text = "%s - Lvl %d" % [stage_name, int(level)]

func _update_gold() -> void:
	var gold = ResourceManager.get_gold()
	if gold_label:
		gold_label.text = "Gold: %d" % int(gold)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------
func _on_madra_changed(_amount: float) -> void:
	_update_madra()

func _on_gold_changed(_amount: float) -> void:
	_update_gold()

func _on_core_density_updated(_xp: float, _level: float) -> void:
	_update_core_density()

func _on_stage_changed(_stage) -> void:
	_update_core_density()
