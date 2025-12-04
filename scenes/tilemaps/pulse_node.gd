class_name PulseNode
extends Line2D
	
# Called when the node enters the scene tree for the first time.
func setup(speed: float, color: Color, modulate_min: float) -> void:
	var shader_mat := material as ShaderMaterial
	if shader_mat:
		shader_mat.set_shader_parameter("speed", speed)
		shader_mat.set_shader_parameter("tint_color", color)
		shader_mat.set_shader_parameter("min_alpha", modulate_min)
