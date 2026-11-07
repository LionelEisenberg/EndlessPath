shader_type canvas_item;

// Horse Stance's arc on the stance gauge (the "Drill roster on the board" canvas).
// The gauge is a half ring over its hub, standing at the left end and deepest at
// the right. The arc is a stretch of its track, BAND_HALF of the gauge to each
// side of where `progress` (0 standing, 1 deepest) puts its centre, drawn over the
// gauge frame (lacquer_drill_gauge_ai.png, 360x200, at its file size).
//
// Pixel art rules (kit §1): each 2 px cell takes one colour, by the angle and the
// radius of its centre around the hub. The arc's outer edge is its rim, its ends
// and its inner edge its shade, the rest its body; outside the arc the frame's
// own art shows. No blending and no TIME: the script sets progress and nothing
// else. The three colours are set on the material in the scene, never by a
// script: the stage holds a lit gauge in brass (shown while the needle is in the
// arc) and a dim one in tan, and the script shows one of them.

// Where the arc's centre stands along the gauge: 0 at the left end, 1 at the right.
uniform float progress : hint_range(0.0, 1.0) = 0.2;
uniform vec4 body_colour : source_color = vec4(0.831373, 0.658824, 0.290196, 1.0); // #D4A84A
uniform vec4 rim_colour : source_color = vec4(0.941176, 0.909804, 0.847059, 1.0); // #F0E8D8
uniform vec4 shade_colour : source_color = vec4(0.65098, 0.407843, 0.203922, 1.0); // #A66834

// One art cell is 2 screen px.
const float CELL = 2.0;
// The hub, and the track's inner and outer radius, in the frame's px.
const vec2 HUB = vec2(180.0, 186.0);
const float R_IN = 138.0;
const float R_OUT = 170.0;
// Half the arc, a share of the gauge (HorseStanceRun.BAND_HEIGHT / 2), and the
// share at each end that takes the shade.
const float BAND_HALF = 0.12;
const float END_SHADE = 0.012;

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 cell = floor(local_px / CELL) * CELL + CELL * 0.5;
	vec2 d = cell - HUB;
	float r = length(d);
	// 0 at the left end of the gauge, 1 at the right.
	float along = 1.0 - atan(-d.y, d.x) / PI;
	float off = along - progress;
	COLOR = art;
	if (d.y < 0.0 && r >= R_IN && r <= R_OUT && abs(off) <= BAND_HALF) {
		if (r > R_OUT - CELL * 2.0) {
			COLOR = rim_colour;
		} else if (abs(off) > BAND_HALF - END_SHADE || r < R_IN + CELL) {
			COLOR = shade_colour;
		} else {
			COLOR = body_colour;
		}
	}
}
