shader_type canvas_item;

// The cultivator cabinet's Madra orb (lacquer kit §5.1): Madra as a liquid in
// the orb's socket, drawn over the strip's empty frame (the brass rim, the
// dark socket and its gloss), which shows wherever no liquid is.
//
// Pixel art rules (kit §1): every pixel is worked out on the 2 px art grid
// (40x40 cells on the 80 px orb), colours come only from the three ramp
// colours below (Madra's unless a material sets others), and time advances in
// whole steps, so it reads as hand-animated frames:
// - a wavy surface (two summed waves) with a 1 cell bright crest and a darker
//   line under it;
// - three bubbles rising, a sheen that slides across every 4 s and three
//   undulating current streaks drifting under the surface;
// - glass shading on the lower right and a deeper band at the bottom.
// The rect must show the 80x80 frame at its file size.

// Madra / max, 0 to 1. 0 draws no liquid; 1 fills the socket with no crest.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Animation frames per second.
uniform float steps_per_second : hint_range(1.0, 30.0, 1.0) = 10.0;

// One art pixel is 2 screen px.
const float CELL = 2.0;
// The socket: cells whose centre lies within sqrt(249) of the orb's centre,
// rows 4 to 35.
const vec2 CENTRE = vec2(20.0);
const float SOCKET_R2 = 249.0;
const float TOP = 4.0;
const float BOTTOM = 36.0;

// The liquid's ramp, light to dark. The defaults are the kit's Madra ramp, so
// the cultivator cabinet's orb sets none of them; another orb (the adventure
// view's Health orb) sets its own on its material.
uniform vec4 light : source_color = vec4(0.909804, 0.964706, 0.992157, 1.0); // #E8F6FD
uniform vec4 pale : source_color = vec4(0.733333, 0.835294, 0.905882, 1.0); // #BBD5E7
uniform vec4 blue : source_color = vec4(0.517647, 0.607843, 0.894118, 1.0); // #849BE4

// Bubbles: column, rise speed in cells per second, phase.
const vec3 BUBBLES[3] = vec3[3](vec3(11.0, 5.0, 0.0), vec3(22.0, 4.0, 0.45), vec3(29.0, 6.0, 0.8));
// Current streaks: depth under the level, drift in cells per second,
// repeat period and dash length in cells.
const vec4 CURRENTS[3] = vec4[3](vec4(7.0, 2.5, 19.0, 4.0), vec4(15.0, -2.0, 23.0, 5.0), vec4(23.0, 3.0, 17.0, 3.0));

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

// The liquid's colour at art cell `cell` at time `t`, or alpha 0 where the
// socket's own art shows (outside the socket, or above the surface).
vec4 liquid(vec2 cell, float t) {
	vec2 d = cell + 0.5 - CENTRE;
	if (dot(d, d) > SOCKET_R2 || progress <= 0.0) {
		return vec4(0.0);
	}
	float level = BOTTOM - progress * (BOTTOM - TOP);
	if (progress >= 1.0) {
		level -= 4.0;
	}
	float wave = sin(cell.x * 0.42 + t * 2.6) + 0.5 * sin(cell.x * 0.77 - t * 3.9 + 1.3);
	float surface = floor(level + wave + 0.5);
	float depth = cell.y - surface;
	if (depth < 0.0) {
		return vec4(0.0);
	}
	if (depth < 0.5) {
		return light;
	}
	if (depth < 1.5) {
		return blue;
	}
	float span = BOTTOM - TOP;
	for (int i = 0; i < 3; i++) {
		vec3 bubble = BUBBLES[i];
		float row = BOTTOM - 1.0 - floor(fract(t * bubble.y / span + bubble.z) * span);
		float side_step = floor(fract(t * 0.9 + bubble.z) * 2.0);
		if (cell.x == bubble.x + side_step && cell.y == row && depth > 2.5) {
			return light;
		}
	}
	float sheen_x = -12.0 + fract(t / 4.0 + 0.1) * 64.0;
	float slant = cell.x - (BOTTOM - cell.y) * 0.5;
	if (slant >= sheen_x && slant < sheen_x + 1.0 && depth > 2.5 && depth < 7.5) {
		return light;
	}
	for (int k = 0; k < 3; k++) {
		vec4 current = CURRENTS[k];
		float row = floor(level + current.x + 0.8 * sin(cell.x * 0.4 + t * 1.7 + float(k) * 2.1) + 0.5);
		if (cell.y == row && depth > 2.5 && cell.y < BOTTOM - 9.0) {
			if (fract((cell.x + t * current.y) / current.z + float(k) * 0.37) * current.z < current.w) {
				return blue;
			}
		}
	}
	if (dot(d, d) > 13.6 * 13.6 && d.x + d.y > 6.0) {
		return blue;
	}
	float deep = floor(BOTTOM - 7.0 + 0.9 * sin(cell.x * 0.5 - t * 1.3) + 0.5);
	if (cell.y >= deep) {
		return blue;
	}
	return pale;
}

void fragment() {
	vec4 socket = texture(TEXTURE, UV);
	float t = floor(TIME * steps_per_second) / steps_per_second;
	vec4 fill = liquid(floor(local_px / CELL), t);
	COLOR = fill.a > 0.0 ? fill : socket;
}
