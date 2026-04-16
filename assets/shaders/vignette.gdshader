shader_type canvas_item;

// How far from screen center the vignette starts (0.0 = center, 1.0 = corner)
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.55;

// How soft the falloff is (higher = softer edge)
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.4;

// Color the edges fade to (default near-black with slight blue tint)
uniform vec4 vignette_color : source_color = vec4(0.0, 0.01, 0.04, 1.0);

void fragment() {
	// Distance from center (0,0) to corner (~0.707) in UV space
	float dist = distance(SCREEN_UV, vec2(0.5));

	// Map dist into 0 (clear) → 1 (full vignette) using radius and softness
	float mask = smoothstep(vignette_radius, vignette_radius + vignette_softness, dist);

	// Blend toward vignette color by mask
	COLOR = vec4(vignette_color.rgb, vignette_color.a * mask);
}
