class_name ProgressShaderRect
extends TextureRect

## ProgressShaderRect
## Simple script to change the progress value of the shader that is applied to the material of the texture rect
## Should set a target value, and interpolate to it over time

var target_value: float = 0.0
var current_value: float = 0.0

const SPEED_LERP: float = 10.0

func _ready() -> void:
	if not material:
		Log.error("ProgressShaderRect: Material is missing!")
		return
	
	if not material is ShaderMaterial:
		Log.error("ProgressShaderRect: Material is not a ShaderMaterial!")
		return
	
	for _uniform in (material as ShaderMaterial).shader.get_shader_uniform_list():
		if _uniform["name"] == "progress":
			current_value = target_value
			return

	Log.error("ProgressShaderRect: Material shader does not have a 'progress' uniform!")	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	current_value = lerp(current_value, target_value, delta * SPEED_LERP)
	(material as ShaderMaterial).set_shader_parameter("progress", current_value)

func set_value(new_value: float) -> void:
	target_value = new_value
