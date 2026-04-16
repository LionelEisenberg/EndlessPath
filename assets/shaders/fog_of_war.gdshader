shader_type canvas_item;

// Maximum number of clear (visible) tile positions. Fixed at compile time for array uniform.
const int MAX_CLEAR_POSITIONS = 64;

// Screen-pixel positions of cleared tiles (pre-converted from world space in GDScript)
uniform vec2 clear_positions[MAX_CLEAR_POSITIONS];

// How many positions are actually valid in the array
uniform int clear_count = 0;

// How far from a clear position a fragment is still "revealed" (in screen pixels, zoom-adjusted)
uniform float clear_radius : hint_range(0.0, 800.0) = 180.0;

// How soft the edge is between revealed and fog (0 = hard edge, 1 = very soft)
uniform float clear_softness : hint_range(0.0, 1.0) = 0.5;

// Fog tint + alpha (max darkness at its edge)
uniform vec4 fog_color : source_color = vec4(0.02, 0.03, 0.08, 0.85);

void fragment() {
	// Convert SCREEN_UV (0-1 across viewport) to screen pixel space
	vec2 viewport_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 frag_pos = SCREEN_UV * viewport_size;

	// Find the minimum distance to any clear position
	float min_dist = 99999.0;
	for (int i = 0; i < MAX_CLEAR_POSITIONS; i++) {
		if (i >= clear_count) {
			break;
		}
		min_dist = min(min_dist, distance(frag_pos, clear_positions[i]));
	}

	// Fade from 0 (clear) at min_dist < clear_radius to 1 (fog) at the softness falloff edge
	float mask = smoothstep(clear_radius, clear_radius * (1.0 + clear_softness), min_dist);
	COLOR = vec4(fog_color.rgb, fog_color.a * mask);
}
