shader_type canvas_item;

uniform float pulse_speed : hint_range(0.5, 5.0) = 1.5;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.6;
uniform float pulse_max : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float pulse = mix(pulse_min, pulse_max, (sin(TIME * pulse_speed) + 1.0) * 0.5);
	COLOR.a *= pulse;
}
