shader_type canvas_item;

//---------------------------------------------------------
// UNIFORMS
//---------------------------------------------------------

// Progression of the fill (0.0 to 1.0)
uniform float progress : hint_range(0.0, 1.0) = 0.5;

// Pulse/Bob parameter
uniform float pulse_amplitude : hint_range(0.0, 0.05) = 0.005;
uniform float pulse_frequency : hint_range(0.0, 20.0) = 1.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;

// Edge parameters
uniform float edge_thickness : hint_range(0.0, 0.1) = 0.01;
uniform vec4 edge_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Colors (Base fill is handled by swirl colors now)
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.0); // Transparent by default

// Swirl / Balatro Shader Uniforms
const bool POLAR_COORDINATES = false;
uniform vec2 polar_center = vec2(0.5);
uniform float polar_zoom = 1.;
uniform float polar_repeat = 1.;

uniform highp float spin_rotation = 0.0;
uniform highp float spin_speed = 50.0;
const vec2 OFFSET = vec2(0.0);
uniform highp vec4 swirl_col_primary : source_color = vec4(0.702, 0.854, 1.0, 0.678); // Original Fill
uniform highp vec4 swirl_col_secondary : source_color = vec4(0.6, 0.75, 0.9, 1.0); // Variation
uniform highp vec4 swirl_col_tertiary : source_color = vec4(0.5, 0.65, 0.8, 1.0); // Darker variation
uniform highp float contrast = 2.;
uniform highp float spin_amount = 0.36;
const float PIXEL_FILTER = 700.0;
#define SPIN_EASE 1.0

//---------------------------------------------------------
// FUNCTIONS
//---------------------------------------------------------

vec4 effect(vec2 screenSize, vec2 screen_coords){
	//Convert to UV coords (0-1) and floor for pixel effect
	highp float pixel_size = length(screenSize.xy) / PIXEL_FILTER;
    highp vec2 uv = (floor(screen_coords.xy*(1./pixel_size))*pixel_size - 0.5*screenSize.xy)/length(screenSize.xy) - OFFSET;
    highp float uv_len = length(uv);

	//Adding in a center swirl, changes with time. Only applies meaningfully if the 'spin amount' is a non-zero number
    highp float speed = (spin_rotation*SPIN_EASE*0.2) + 302.2;
    highp float new_pixel_angle = (atan(uv.y, uv.x)) + speed - SPIN_EASE*20.*(1.*spin_amount*uv_len + (1. - 1.*spin_amount));
    highp vec2 mid = (screenSize.xy/length(screenSize.xy))/2.;
    uv = (vec2((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid);

	//Now add the paint effect to the swirled UV
    uv *= 30.;
    speed = TIME*(spin_speed);
	highp vec2 uv2 = vec2(uv.x+uv.y);

	for(int i=0; i < 5; i++) {
		uv2 += sin(max(uv.x, uv.y)) + uv;
		uv  += 0.5*vec2(cos(5.1123314 + 0.353*uv2.y + speed*0.131121),sin(uv2.x - 0.113*speed));
		uv  -= 1.0*cos(uv.x + uv.y) - 1.0*sin(uv.x*0.711 - uv.y);
	}

	//Make the paint amount range from 0 - 2
    highp float contrast_mod = (0.25*contrast + 0.5*spin_amount + 1.2);
	highp float paint_res = min(2., max(0.,length(uv)*(0.035)*contrast_mod));
    highp float c1p = max(0.,1. - contrast_mod*abs(1.-paint_res));
    highp float c2p = max(0.,1. - contrast_mod*abs(paint_res));
    highp float c3p = 1. - min(1., c1p + c2p);

	highp vec4 ret_col = (0.3/contrast)*swirl_col_primary + (1. - 0.3/contrast)*(swirl_col_primary*c1p + swirl_col_secondary*c2p + vec4(c3p*swirl_col_tertiary.rgb, c3p*swirl_col_primary.a));
	return ret_col;
}

vec2 polar_coords(vec2 uv, vec2 center, float zoom, float repeat){
	vec2 dir = uv - center;
	float radius = length(dir) * 2.0;
	float angle = atan(dir.y , dir.x) * 1.0 / (PI * 2.0);
	return mod(vec2(radius * zoom, angle * repeat), 1.0);
}

//---------------------------------------------------------
// MAIN
//---------------------------------------------------------

void fragment() {
	// Center is 0.5, 0.5
	vec2 center = vec2(0.5);
	float dist = distance(UV, center);
	
	// SCALE LOGIC:
	// We want the fill + edge + pulse to fit within the 0.5 circle (texture bounds) at max progress.
	// max_dist = 0.5
	// filled_radius + edge_thickness + pulse_amplitude <= 0.5
	// filled_radius <= 0.5 - edge_thickness - pulse_amplitude
	// So base radius (from progress) should map to this available space.
	// Added extra -0.05 safety margin as requested to prevent clipping at high progress.
	
	float max_fill_radius = 0.5 - edge_thickness - pulse_amplitude - 0.015;
	float base_radius = progress * max_fill_radius;
	
	// PULSE LOGIC:
	// "Expand and contract on a circle very slightly" - uniform pulse
	float pulse = sin(TIME * pulse_speed) * pulse_amplitude;
	
	float current_radius_threshold = base_radius + pulse;
	
	vec4 tex_color = texture(TEXTURE, UV);
	
	// If progress is very low, clamp radius so we don't draw negative
	if (progress <= 0.01) {
		current_radius_threshold = 0.0;
	}

	// Draw
	if (dist < current_radius_threshold) {
		// Inside fill -> Swirl
		
		// Apply Balatro Swirl Effect
		vec2 used_coords = UV;
		if (POLAR_COORDINATES){
			used_coords = polar_coords(UV.xy, polar_center, polar_zoom, polar_repeat);
		}
		
		vec4 swirl_color = effect(vec2(1.0), used_coords);
		
		COLOR = swirl_color;
		// Mask by texture alpha (circle shape)
		COLOR.a *= tex_color.a;
		
	} else if (dist < current_radius_threshold + edge_thickness) {
		// Edge
		COLOR = edge_color;
		COLOR.a *= tex_color.a;
	} else {
		// Background
		COLOR = tex_color * bg_color;
	}
}
