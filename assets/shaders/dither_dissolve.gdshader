shader_type canvas_item;

// The style guide's 2-step dither dissolve (§8, Show and hide), the one
// crossfade the look allows. The shaded node draws whole at step 0, on half of
// its 2 px art cells at step 1 (a checkerboard) and on three quarters at step 2.
// Each step keeps every cell the step before kept, so no cell comes back. With
// invert on, the node keeps the cells the other way, the complement of each
// step: half at step 1, a quarter at step 2. A node dissolving in draws over the
// old picture without invert; a still of the old picture dissolving out over the
// new one draws with it (ViewDissolve). The script sets dissolve_step and
// nothing else; invert is set on the material in the scene.

uniform int dissolve_step : hint_range(0, 2) = 0;
uniform bool invert = false;

// One art px is 2 screen px.
const float CELL = 2.0;

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

void fragment() {
	ivec2 cell = ivec2(floor(local_px / CELL));
	bool odd_x = cell.x % 2 == 1;
	bool odd_y = cell.y % 2 == 1;
	bool gone = false;
	if (dissolve_step == 1) {
		gone = odd_x != odd_y;
	} else if (dissolve_step == 2) {
		gone = odd_x && !odd_y;
	}
	if (invert && dissolve_step != 0) {
		gone = !gone;
	}
	if (gone) {
		discard;
	}
}
