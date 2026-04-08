class_name ZoneResourcePanel
extends PanelContainer
## Floating resource orbs displaying Madra and Core Density.

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _madra_circle: ProgressShaderRect = %MadraCircle
@onready var _madra_label: Label = %MadraLabel
@onready var _core_density_rect: ProgressShaderRect = %CoreDensityRect
@onready var _core_density_label: Label = %CoreDensityLabel

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_connect_signals()
	_update_all_displays()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _connect_signals() -> void:
	ResourceManager.madra_changed.connect(_on_madra_changed)
	CultivationManager.core_density_level_updated.connect(_on_core_density_updated)
	CultivationManager.advancement_stage_changed.connect(_on_stage_changed)

func _update_all_displays() -> void:
	_update_madra()
	_update_core_density()

func _update_madra() -> void:
	var current_madra: float = ResourceManager.get_madra()
	var level: int = int(CultivationManager.get_core_density_level())
	var stage_res: AdvancementStageResource = CultivationManager._get_current_stage_resource()
	var max_madra: float = stage_res.get_max_madra(level) if stage_res else 0.0
	var progress: float = current_madra / max_madra if max_madra > 0 else 0.0
	_madra_circle.set_value(progress)
	_madra_label.text = "%d / %d" % [int(current_madra), int(max_madra)]

func _update_core_density() -> void:
	var level: float = CultivationManager.get_core_density_level()
	var stage_name: String = CultivationManager.get_current_advancement_stage_name()
	var progress: float = level / 100.0
	_core_density_rect.set_value(progress)
	_core_density_label.text = "%s - Lvl %d" % [stage_name, int(level)]

func _on_madra_changed(_amount: float) -> void:
	_update_madra()

func _on_core_density_updated(_xp: float, _level: float) -> void:
	_update_core_density()

func _on_stage_changed(_stage: CultivationManager.AdvancementStage) -> void:
	_update_core_density()
	_update_madra()
