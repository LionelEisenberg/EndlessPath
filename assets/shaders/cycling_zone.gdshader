shader_type canvas_item;

// Zone state: 0.0 = idle, 1.0 = active (ball nearby), -1.0 = used/completed
uniform float state : hint_range(-1.0, 1.0) = 0.0;

// Colors
uniform vec4 idle_color : source_color = vec4(0.6, 0.8, 1.0, 0.5);
uniform vec4 active_color : source_color = vec4(0.8, 0.92, 1.0, 0.9);
uniform vec4 used_color : source_color = vec4(0.4, 0.4, 0.4, 0.3);

// Animation
uniform float pulse_speed : hint_range(0.5, 5.0) = 2.0;
uniform float ring_thickness : hint_range(0.01, 0.2) = 0.08;
uniform float glow_size : hint_range(0.0, 0.3) = 0.15;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);

	// Determine color based on state
	vec4 base_color;
	if (state < -0.5) {
		base_color = used_color;
	} else if (state > 0.5) {
		base_color = active_color;
	} else {
		base_color = idle_color;
	}

	// Pulse animation (only when not used)
	float pulse = 1.0;
	if (state > -0.5) {
		pulse = 0.85 + 0.15 * sin(TIME * pulse_speed);
	}

	// Active state pulses faster and stronger
	if (state > 0.5) {
		pulse = 0.7 + 0.3 * sin(TIME * pulse_speed * 2.0);
	}

	// Inner filled circle
	float inner_radius = 0.4 * pulse;
	float inner_circle = smoothstep(inner_radius, inner_radius - 0.05, dist);

	// Outer ring
	float outer_radius = 0.7 * pulse;
	float ring = smoothstep(outer_radius, outer_radius - ring_thickness, dist)
				- smoothstep(outer_radius - ring_thickness, outer_radius - ring_thickness * 2.0, dist);

	// Outer glow
	float glow = smoothstep(0.8, 0.0, dist) * glow_size;

	// Combine
	float alpha = max(inner_circle * 0.6, max(ring * 0.8, glow));
	COLOR = base_color;
	COLOR.a *= alpha * pulse;

	// Discard fully transparent pixels
	if (COLOR.a < 0.01) {
		discard;
	}
}
