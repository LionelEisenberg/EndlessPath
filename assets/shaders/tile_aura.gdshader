shader_type canvas_item;

uniform vec4 aura_color : source_color = vec4(0.6, 0.84, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.6;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	float vertex_alpha = COLOR.a;
	float wave = (sin(TIME * pulse_speed) + 1.0) * 0.5;
	float pulse = pulse_min + wave * (1.0 - pulse_min);
	COLOR = vec4(aura_color.rgb * pulse, vertex_alpha * aura_color.a);
}
