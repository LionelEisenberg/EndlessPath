shader_type canvas_item;

// The cultivator cabinet's Core Density orb (lacquer kit §5.1): a pixel
// spiral that grows from the centre of the socket to level / 100 and turns
// slowly, drawn over a frame of the core orb strip (the carved socket). The
// cycling view's core fill, on the kit's grid.
//
// Pixel art rules (kit §1): every pixel is worked out on the 2 px art grid
// (40x40 cells on the 80 px orb), colours come only from the Madra ramp, and
// time advances in whole steps, so it reads as hand-animated frames:
// - three ramp bands in two arms, turning once every 12 s;
// - a bright core and a 1 cell bright edge where the fill ends.
// The rect must show the 80x80 frame at its file size.

// min(level, 100) / 100. 0 draws no fill, so the frame underneath shows.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Animation frames per second.
uniform float steps_per_second : hint_range(1.0, 30.0, 1.0) = 10.0;

// One art pixel is 2 screen px.
const float CELL = 2.0;
const vec2 CENTRE = vec2(20.0);
// The fill's radius in cells at the lowest level and at 100, where it meets
// the socket's rim (cells within sqrt(249) of the centre).
const float RADIUS_MIN = 2.5;
const float RADIUS_MAX = 15.78;
const float CORE_RADIUS = 1.5;
const float ARMS = 2.0;
// Cells outward per band cycle, and seconds per band cycle.
const float PITCH = 7.0;
const float CYCLE_SECONDS = 6.0;

// The kit's Madra ramp, light to dark.
const vec4 MADRA_LIGHT = vec4(0.909804, 0.964706, 0.992157, 1.0); // #E8F6FD
const vec4 MADRA_PALE = vec4(0.733333, 0.835294, 0.905882, 1.0); // #BBD5E7
const vec4 MADRA_BLUE = vec4(0.517647, 0.607843, 0.894118, 1.0); // #849BE4
const vec4 MADRA_DEEP = vec4(0.109804, 0.184314, 0.376471, 1.0); // #1C2F60

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

// The spiral's colour at art cell `cell` at time `t`, or alpha 0 where the
// frame's own art shows.
vec4 spiral(vec2 cell, float t) {
	if (progress <= 0.0) {
		return vec4(0.0);
	}
	float radius = mix(RADIUS_MIN, RADIUS_MAX, clamp(progress, 0.0, 1.0));
	vec2 d = cell + 0.5 - CENTRE;
	float r = length(d);
	if (r >= radius) {
		return vec4(0.0);
	}
	if (r >= radius - 1.0 || r < CORE_RADIUS) {
		return MADRA_LIGHT;
	}
	float phase = atan(d.y, d.x) / TAU * ARMS + r / PITCH - t / CYCLE_SECONDS;
	float band = floor(fract(phase) * 3.0);
	if (band < 0.5) {
		return MADRA_PALE;
	}
	if (band < 1.5) {
		return MADRA_BLUE;
	}
	return MADRA_DEEP;
}

void fragment() {
	vec4 socket = texture(TEXTURE, UV);
	float t = floor(TIME * steps_per_second) / steps_per_second;
	vec4 fill = spiral(floor(local_px / CELL), t);
	COLOR = fill.a > 0.0 ? fill : socket;
}
