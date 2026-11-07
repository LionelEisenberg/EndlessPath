shader_type canvas_item;

// Horse Stance's needle on the stance gauge (the "Drill roster on the board"
// canvas): a line out from the gauge's hub, pointing at the left end at `progress`
// 0 (standing) and at the right end at 1 (the deepest stance). It runs on a rect
// the size of the gauge frame (360x200) laid over it, and is transparent off the
// line, so the gauge shows through.
//
// Pixel art rules (kit §1): a 2 px cell is the needle's when its centre lies
// within the needle's reach from the hub and within a cell's width of its line.
// One kit colour, no blending and no TIME: the script sets progress and nothing
// else.

// The needle's depth: 0 standing, 1 the deepest stance.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// One art cell is 2 screen px.
const float CELL = 2.0;
// The hub, in the gauge frame's px, and where the needle starts and ends along
// its line.
const vec2 HUB = vec2(180.0, 186.0);
const float FROM = 22.0;
const float TO = 168.0;
// How far from the line a cell's centre may stand and still be the needle's.
const float HALF_WIDTH = CELL * 0.72;
const vec4 NEEDLE = vec4(0.941176, 0.909804, 0.847059, 1.0); // #F0E8D8, the kit's cream

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

void fragment() {
	vec2 cell = floor(local_px / CELL) * CELL + CELL * 0.5;
	float angle = PI * (1.0 - progress);
	vec2 dir = vec2(cos(angle), -sin(angle));
	vec2 d = cell - HUB;
	float along = dot(d, dir);
	float across = length(d - dir * along);
	COLOR = (along >= FROM && along <= TO && across <= HALF_WIDTH) ? NEEDLE : vec4(0.0);
}
