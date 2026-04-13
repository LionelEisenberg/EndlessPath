shader_type canvas_item;

// Animated border shader for non-keystone path nodes.
// Draws a pulsing, shimmering border ring around circle or diamond shapes.
// Applied to a ColorRect overlay sized to the node.

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

// Shape radius (fraction of UV space, centered at 0.5)
uniform float radius : hint_range(0.1, 0.5) = 0.42;

// SDF functions
float circle_sdf(vec2 p, float r) {
	return length(p) - r;
}

float diamond_sdf(vec2 p, float r) {
	vec2 q = abs(p);
	return (q.x + q.y) / 1.414 - r;
}

void fragment() {
	vec2 center = vec2(0.5);
	vec2 p = UV - center;

	// Choose shape SDF
	float d;
	if (shape_type > 0.5) {
		d = diamond_sdf(p, radius);
	} else {
		d = circle_sdf(p, radius);
	}

	// Discard outside the shape + glow region
	if (d > glow_size) {
		discard;
	}

	// Compute angle for shimmer sweep
	float angle = atan(p.y, p.x);
	float shimmer = sin(angle * 3.0 + TIME * shimmer_speed) * 0.5 + 0.5;

	// Pulse: overall brightness oscillation
	float pulse = sin(TIME * pulse_speed) * 0.15 + 0.85;

	// State-based intensity
	float intensity = clamp(state, 0.0, 2.0) / 2.0;
	float locked_dim = mix(0.4, 1.0, intensity);

	// Fill region (inside the border)
	if (d < -border_width) {
		COLOR = fill_color * locked_dim;
		COLOR.a = 1.0;
		return;
	}

	// Border region
	if (d < 0.0) {
		// Blend between border and glow based on shimmer
		float shimmer_mix = shimmer * intensity;
		vec4 border_final = mix(border_color, glow_color, shimmer_mix * 0.6);
		border_final.rgb *= pulse * locked_dim;
		COLOR = border_final;
		COLOR.a = 1.0;
		return;
	}

	// Outer glow (d >= 0.0 and d < glow_size)
	float glow_alpha = smoothstep(glow_size, 0.0, d) * 0.4 * intensity * pulse;
	COLOR = glow_color;
	COLOR.a = glow_alpha;
}
