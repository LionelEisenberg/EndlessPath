shader_type canvas_item;

// Animated border shader for non-keystone path nodes.
// Draws a pulsing, shimmering border ring around circle or diamond shapes.

// Shape: 0 = circle, 1 = diamond
uniform float shape_type : hint_range(0.0, 1.0) = 0.0;

// Colors
uniform vec4 border_color : source_color = vec4(0.55, 0.72, 0.95, 1.0);
uniform vec4 glow_color : source_color = vec4(0.75, 0.88, 1.0, 1.0);
uniform vec4 fill_color : source_color = vec4(0.3, 0.4, 0.55, 1.0);

// State: 0=locked, 1=available, 2=purchased
uniform float state : hint_range(0.0, 2.0) = 1.0;

// Border params
uniform float border_width : hint_range(0.01, 0.1) = 0.045;
uniform float shimmer_speed : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;
uniform float glow_size : hint_range(0.0, 0.15) = 0.06;
uniform float radius : hint_range(0.1, 0.5) = 0.42;

void fragment() {
	vec2 p = UV - vec2(0.5);

	// SDF based on shape type
	float d;
	if (shape_type > 0.5) {
		// Diamond
		vec2 q = abs(p);
		d = (q.x + q.y) / 1.414 - radius;
	} else {
		// Circle
		d = length(p) - radius;
	}

	// Outside everything — fully transparent
	if (d > glow_size) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		// Shimmer sweep around perimeter
		float angle = atan(p.y, p.x);
		float shimmer = sin(angle * 3.0 + TIME * shimmer_speed) * 0.5 + 0.5;

		// Pulse brightness
		float pulse = sin(TIME * pulse_speed) * 0.15 + 0.85;

		// State intensity
		float intensity = clamp(state, 0.0, 2.0) / 2.0;
		float dim = mix(0.4, 1.0, intensity);

		if (d < -border_width) {
			// Fill region
			COLOR = vec4(fill_color.rgb * dim, 1.0);
		} else if (d < 0.0) {
			// Border region with shimmer
			float shimmer_mix = shimmer * intensity;
			vec3 b = mix(border_color.rgb, glow_color.rgb, shimmer_mix * 0.6);
			COLOR = vec4(b * pulse * dim, 1.0);
		} else {
			// Outer glow
			float glow_alpha = smoothstep(glow_size, 0.0, d) * 0.4 * intensity * pulse;
			COLOR = vec4(glow_color.rgb, glow_alpha);
		}
	}
}
