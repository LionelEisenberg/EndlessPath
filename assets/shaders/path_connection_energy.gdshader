shader_type canvas_item;

// Energy pulse shader for path progression connection lines.
// Creates animated pulses that travel along the line direction.
// Applied to Line2D nodes for purchased connections.

uniform vec4 line_color : source_color = vec4(0.5, 0.7, 0.95, 1.0);
uniform vec4 energy_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float flow_speed : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_width : hint_range(0.01, 0.3) = 0.15;
uniform float pulse_count : hint_range(1.0, 5.0) = 2.0;

void fragment() {
	// UV.x goes along the line (0 to 1)
	float pos = fract(UV.x * pulse_count - TIME * flow_speed);
	float pulse = smoothstep(0.0, pulse_width, pos) * smoothstep(pulse_width * 2.0, pulse_width, pos);

	vec4 col = mix(line_color, energy_color, pulse);
	col.a *= texture(TEXTURE, UV).a;
	COLOR = col;
}
