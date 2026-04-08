shader_type canvas_item;

// Rotation — driven by code based on ball movement speed
uniform float spin_speed : hint_range(0.0, 20.0) = 2.0;

// Pulse (scale breathing) — stronger when idle to attract clicks
uniform float pulse_speed : hint_range(0.0, 8.0) = 1.5;
uniform float pulse_amount : hint_range(0.0, 0.3) = 0.05;

// Glow
uniform float glow_intensity : hint_range(0.0, 3.0) = 0.3;
uniform vec4 glow_color : source_color = vec4(0.5, 0.75, 1.0, 1.0);

// State: 0.0 = idle/stopped, 1.0 = moving at full speed
uniform float movement_state : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 center = vec2(0.5);
	vec2 uv = UV - center;

	// Idle: big slow pulse to attract attention. Moving: subtle pulse.
	float idle_pulse = sin(TIME * 3.0) * 0.12;
	float move_pulse = sin(TIME * pulse_speed) * pulse_amount;
	float pulse = 1.0 + mix(idle_pulse, move_pulse, movement_state);
	uv /= pulse;

	// Rotation proportional to movement
	float angle = TIME * spin_speed * max(movement_state, 0.5);
	float cos_a = cos(angle);
	float sin_a = sin(angle);
	vec2 rotated_uv = vec2(
		uv.x * cos_a - uv.y * sin_a,
		uv.x * sin_a + uv.y * cos_a
	);

	vec2 final_uv = rotated_uv + center;
	vec4 tex = texture(TEXTURE, final_uv);

	// Glow — brighter when idle
	float dist = length(uv);
	float glow_mult = mix(1.6, 1.0, movement_state);
	float glow = exp(-dist * 6.0) * glow_intensity * glow_mult;
	vec4 glow_contribution = glow_color * glow * tex.a;

	COLOR = tex + glow_contribution;
	COLOR.a = tex.a;
}
