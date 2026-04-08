shader_type canvas_item;

// Zone state: 0.0 = idle, 1.0 = active (ball nearby), -1.0 = used/completed
uniform float state : hint_range(-1.0, 1.0) = 0.0;

// Colors
uniform vec4 idle_color : source_color = vec4(0.6, 0.8, 1.0, 0.6);
uniform vec4 active_color : source_color = vec4(0.85, 0.95, 1.0, 0.95);
uniform vec4 used_color : source_color = vec4(0.4, 0.4, 0.4, 0.25);

// Animation — toned down
uniform float pulse_speed : hint_range(0.5, 5.0) = 1.5;
uniform float ring_thickness : hint_range(0.01, 0.2) = 0.08;
uniform float glow_size : hint_range(0.0, 0.3) = 0.12;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);

	// Smooth state blending instead of hard cutoffs
	float active_blend = smoothstep(0.3, 0.7, state);
	float used_blend = smoothstep(-0.3, -0.7, state);
	vec4 base_color = mix(mix(idle_color, active_color, active_blend), used_color, used_blend);

	// Gentle pulse — subtle size variation
	float pulse = 1.0;
	if (state > -0.5) {
		// Idle: very gentle. Active: slightly more.
		float pulse_strength = mix(0.03, 0.06, active_blend);
		pulse = 1.0 - pulse_strength + pulse_strength * 2.0 * sin(TIME * pulse_speed);
	}

	// Inner filled circle
	float inner_radius = 0.35 * pulse;
	float inner_circle = smoothstep(inner_radius, inner_radius - 0.06, dist);

	// Outer ring
	float outer_radius = 0.6 * pulse;
	float ring = smoothstep(outer_radius, outer_radius - ring_thickness, dist)
				- smoothstep(outer_radius - ring_thickness, outer_radius - ring_thickness * 2.0, dist);

	// Outer glow
	float glow = smoothstep(0.7, 0.0, dist) * glow_size;

	// Combine — active state is brighter overall
	float brightness = mix(1.0, 1.3, active_blend);
	float alpha = max(inner_circle * 0.5, max(ring * 0.7, glow));
	COLOR = base_color * brightness;
	COLOR.a = alpha * base_color.a;

	if (COLOR.a < 0.01) {
		discard;
	}
}
