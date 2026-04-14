shader_type canvas_item;

// Procedural pulsing hexagon outline for tile hover feedback.
// Applied to a Sprite2D (or any quad) — the underlying texture is ignored;
// the shader renders the hex border directly from UV coordinates using a
// signed-distance-field math trick.
//
// Usage: set the sprite bounds to roughly match the target hex tile size,
// tweak hex_radius until the outline sits on the tile edge, and tune
// border_color / pulse_speed / thickness to taste.

uniform vec4 border_color : source_color = vec4(0.55, 0.78, 1.0, 1.0);

// Thickness of the border band as a fraction of the sprite UV [0..1]
uniform float border_thickness : hint_range(0.0, 0.2) = 0.06;

// Pulse cycle speed (radians per second — higher = faster pulse)
uniform float pulse_speed : hint_range(0.1, 10.0) = 3.0;

// How dim the border gets at the pulse trough (1.0 = no alpha pulse)
uniform float pulse_min_alpha : hint_range(0.0, 1.0) = 0.45;

// Hexagon "inscribed" radius in UV space. Tune to match the underlying
// tile size. 0.42 is a good default for a sprite scale-matched to the hex.
uniform float hex_radius : hint_range(0.1, 0.6) = 0.42;

// How much the hex breathes outward/inward over the pulse cycle. 0 = static.
// Small values (0.005 - 0.02) give a subtle breathing; larger feels more active.
uniform float radius_pulse_amount : hint_range(0.0, 0.1) = 0.008;

// Rotation in degrees for flat-top vs pointy-top alignment. 0 = flat-top
// (edges on top/bottom). 30 = pointy-top (vertices on top/bottom).
uniform float hex_rotation_deg : hint_range(0.0, 60.0) = 0.0;

// Inigo Quilez's hexagon SDF (https://iquilezles.org/articles/distfunctions2d/)
// Returns signed distance from point p to a regular hexagon of inscribed
// radius r, centered at origin. Negative inside, positive outside.
float sd_hexagon(vec2 p, float r) {
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	p = abs(p);
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
	return length(p) * sign(p.y);
}

void fragment() {
	// Center the UV so (0,0) is the sprite middle and edges reach ±0.5
	vec2 uv = UV - vec2(0.5);

	// Optional rotation for hex orientation alignment
	float rad = hex_rotation_deg * 0.0174533;
	float cr = cos(rad);
	float sr = sin(rad);
	uv = vec2(cr * uv.x - sr * uv.y, sr * uv.x + cr * uv.y);

	// Pulse wave: oscillates 0 → 1 → 0 over the pulse cycle
	float wave = (sin(TIME * pulse_speed) + 1.0) * 0.5;

	// Radius breathes slightly over the pulse cycle for a "living" border
	float breathing_radius = hex_radius + wave * radius_pulse_amount;

	// Signed distance from this fragment to the hex edge
	float d = sd_hexagon(uv, breathing_radius);

	// Render as border where |d| is small. Straddles the hex edge with
	// smooth falloff so the border has soft edges instead of a sharp cut.
	float border_mask = 1.0 - smoothstep(0.0, border_thickness, abs(d));

	// Alpha pulse: oscillate border brightness between pulse_min_alpha and 1.0
	float alpha_pulse = pulse_min_alpha + wave * (1.0 - pulse_min_alpha);

	COLOR = vec4(border_color.rgb, border_mask * alpha_pulse * border_color.a);
}
