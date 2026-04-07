shader_type canvas_item;

// Rotation
uniform float spin_speed : hint_range(0.0, 10.0) = 2.0;

// Pulse (scale breathing)
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_amount : hint_range(0.0, 0.2) = 0.05;

// Glow
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.3;
uniform vec4 glow_color : source_color = vec4(0.5, 0.75, 1.0, 1.0);

void fragment() {
	// Center UV at (0,0)
	vec2 center = vec2(0.5);
	vec2 uv = UV - center;

	// Pulse: scale UV in and out
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	uv /= pulse;

	// Rotate UV
	float angle = TIME * spin_speed;
	float cos_a = cos(angle);
	float sin_a = sin(angle);
	vec2 rotated_uv = vec2(
		uv.x * cos_a - uv.y * sin_a,
		uv.x * sin_a + uv.y * cos_a
	);

	// Sample texture at rotated UV
	vec2 final_uv = rotated_uv + center;
	vec4 tex = texture(TEXTURE, final_uv);

	// Add inner glow based on distance from center
	float dist = length(uv);
	float glow = exp(-dist * 6.0) * glow_intensity;
	vec4 glow_contribution = glow_color * glow * tex.a;

	COLOR = tex + glow_contribution;
	COLOR.a = tex.a;
}
