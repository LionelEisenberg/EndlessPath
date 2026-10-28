shader_type canvas_item;

// The cooldown sweep on a technique's icon in the technique dock (spec:
// Shaders, and the Decisions row "Technique cooldown"). While a technique
// recharges, the part of its icon still to recharge shows in the kit's dark
// locked veil, a palette state and never an alpha overlay, and the veil is
// uncovered clockwise from 12 o'clock in 24 whole steps.
//
// Pixel art rules (kit §1): the sweep is worked out per 2 px cell of the
// icon (32x32 cells for a 64x64 icon), so its edge stays on the art grid. A
// cell is veiled when the angle of its centre around the icon's centre,
// measured from 12 o'clock clockwise, is at or past the recharged steps'
// angle. A veiled cell takes the step of the veil its luminance falls in
// (four bands onto the ramp's four darker colours) and keeps its alpha. No
// blending, no smoothstep and no TIME: the script sets progress in whole
// steps. The mock's adv_ability_*_cd_strip_ai.png frames are its reference
// output (cooldown_sweep() in the mock's gen/kit_adventure.py).
// The rect shows the icon square, icon_size px a side: 64 on a technique slot,
// 32 on a consumable socket of the technique dock (spec
// 2026-10-25-combat-consumables-lacquer-design.md).

// Recharged steps / 24, 0 to 1: 0 veils the whole icon, 1 shows it plain. The
// script only sets whole steps (k / 24), and the shader rounds progress x 24 to
// the nearest step rather than flooring it: for steps 7 and 14 that product
// lands exactly halfway between k and the float32 below it, so a floor would
// depend on how the GPU rounds the multiply.
uniform float progress : hint_range(0.0, 1.0) = 1.0;
// The icon rect's side in px, which puts the sweep's centre in the middle of
// it. Set on a material in the scene, never by a script.
uniform float icon_size = 64.0;

const float STEPS = 24.0;
// One art cell is 2 screen px.
const float CELL = 2.0;
// A cell centre exactly on a step's edge (on the diagonals, at 45, 135, 225
// and 315 degrees) counts as at the edge, as in the mock. The bias absorbs
// float rounding in atan(); every other cell centre is at least 0.0012 rad
// from an edge.
const float EDGE_BIAS = 0.0001;

// The locked veil's four darker steps, dark to light, and the luminance (0
// to 1) below which each of the first three takes over.
const vec3 VEIL_DARKEST = vec3(21.0, 26.0, 24.0) / 255.0; // #151A18
const vec3 VEIL_DARK = vec3(57.0, 66.0, 62.0) / 255.0; // #39423E
const vec3 VEIL_MID = vec3(75.0, 85.0, 80.0) / 255.0; // #4B5550
const vec3 VEIL_LIGHT = vec3(95.0, 106.0, 101.0) / 255.0; // #5F6A65
const float BAND_DARKEST = 60.0 / 255.0;
const float BAND_DARK = 140.0 / 255.0;
const float BAND_MID = 200.0 / 255.0;

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

// The veil's colour for an icon colour, by its luminance.
vec3 veil(vec3 colour) {
	float luminance = 0.2126 * colour.r + 0.7152 * colour.g + 0.0722 * colour.b;
	if (luminance < BAND_DARKEST) {
		return VEIL_DARKEST;
	}
	if (luminance < BAND_DARK) {
		return VEIL_DARK;
	}
	if (luminance < BAND_MID) {
		return VEIL_MID;
	}
	return VEIL_LIGHT;
}

void fragment() {
	vec4 icon = texture(TEXTURE, UV);
	vec2 centre = vec2(icon_size * 0.5);
	vec2 cell_centre = floor(local_px / CELL) * CELL + CELL * 0.5;
	float angle = mod(atan(cell_centre.x - centre.x, -(cell_centre.y - centre.y)), TAU);
	float recharged = floor(progress * STEPS + 0.5) / STEPS * TAU;
	COLOR = angle >= recharged - EDGE_BIAS ? vec4(veil(icon.rgb), icon.a) : icon;
}
