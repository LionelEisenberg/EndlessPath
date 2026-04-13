shader_type canvas_item;

// Keystone swirl shader for path progression nodes.
// Adapted from core_density_fill.gdshader — keeps the Balatro swirl effect
// but removes progress/fill logic (always fills the full shape).

//---------------------------------------------------------
// UNIFORMS
//---------------------------------------------------------

uniform highp float spin_speed = 50.0;
uniform highp float spin_amount = 0.36;
uniform highp float contrast = 2.0;
uniform highp vec4 swirl_col_primary : source_color = vec4(0.6, 0.8, 1.0, 0.7);
uniform highp vec4 swirl_col_secondary : source_color = vec4(0.5, 0.7, 0.95, 1.0);
uniform highp vec4 swirl_col_tertiary : source_color = vec4(0.4, 0.6, 0.85, 1.0);
uniform float state : hint_range(0.0, 2.0) = 1.0; // 0=locked, 1=available, 2=purchased
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.3;
uniform vec4 glow_color : source_color = vec4(0.7, 0.85, 1.0, 1.0);

const highp float PIXEL_FILTER = 700.0;
const vec2 OFFSET = vec2(0.0);
const highp float SPIN_EASE = 1.0;

//---------------------------------------------------------
// FUNCTIONS
//---------------------------------------------------------

vec4 effect(vec2 screenSize, vec2 screen_coords) {
	highp float pixel_size = length(screenSize.xy) / PIXEL_FILTER;
	highp vec2 uv = (floor(screen_coords.xy * (1.0 / pixel_size)) * pixel_size - 0.5 * screenSize.xy) / length(screenSize.xy) - OFFSET;
	highp float uv_len = length(uv);

	// Center swirl with time-based spin
	highp float speed_val = (0.0 * SPIN_EASE * 0.2) + 302.2;
	highp float new_pixel_angle = (atan(uv.y, uv.x)) + speed_val - SPIN_EASE * 20.0 * (1.0 * spin_amount * uv_len + (1.0 - 1.0 * spin_amount));
	highp vec2 mid = (screenSize.xy / length(screenSize.xy)) / 2.0;
	uv = (vec2((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid);

	// Paint effect on swirled UV
	uv *= 30.0;
	highp float anim_speed = TIME * spin_speed;
	highp vec2 uv2 = vec2(uv.x + uv.y);

	for (int i = 0; i < 5; i++) {
		uv2 += sin(max(uv.x, uv.y)) + uv;
		uv += 0.5 * vec2(cos(5.1123314 + 0.353 * uv2.y + anim_speed * 0.131121), sin(uv2.x - 0.113 * anim_speed));
		uv -= 1.0 * cos(uv.x + uv.y) - 1.0 * sin(uv.x * 0.711 - uv.y);
	}

	// Map paint to 0-2 range and blend three colors
	highp float contrast_mod = (0.25 * contrast + 0.5 * spin_amount + 1.2);
	highp float paint_res = min(2.0, max(0.0, length(uv) * 0.035 * contrast_mod));
	highp float c1p = max(0.0, 1.0 - contrast_mod * abs(1.0 - paint_res));
	highp float c2p = max(0.0, 1.0 - contrast_mod * abs(paint_res));
	highp float c3p = 1.0 - min(1.0, c1p + c2p);

	highp vec4 ret_col = (0.3 / contrast) * swirl_col_primary + (1.0 - 0.3 / contrast) * (swirl_col_primary * c1p + swirl_col_secondary * c2p + vec4(c3p * swirl_col_tertiary.rgb, c3p * swirl_col_primary.a));
	return ret_col;
}

//---------------------------------------------------------
// MAIN
//---------------------------------------------------------

// Hexagon signed distance function (pointy-top orientation)
float hex_sdf(vec2 p, float r) {
	vec2 q = abs(p);
	// Pointy-top hexagon: rotated 30 degrees from flat-top
	return max(q.x * 0.866025 + q.y * 0.5, q.y) - r;
}

void fragment() {
	// Hexagonal clip: discard pixels outside the hexagon shape
	vec2 center = vec2(0.5);
	vec2 p = UV - center;
	float hex_dist = hex_sdf(p, 0.48); // 0.48 = slightly inset from edge
	if (hex_dist > 0.0) {
		discard;
	}

	// Soft edge for anti-aliasing
	float edge_alpha = smoothstep(0.0, -0.02, hex_dist);

	vec2 used_coords = UV;
	vec4 swirl_color = effect(vec2(1.0), used_coords);

	// State-based brightness: locked=dim, available=moderate, purchased=full
	float brightness = mix(0.3, 1.0, clamp(state, 0.0, 2.0) / 2.0);
	swirl_color.rgb *= brightness;

	// Glow halo for purchased state
	float glow = 0.0;
	if (state > 1.5) {
		float dist = length(p);
		glow = exp(-dist * 4.0) * glow_intensity;
	}

	COLOR = swirl_color + glow_color * glow;
	COLOR.a = edge_alpha;
}
