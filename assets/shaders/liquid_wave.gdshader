shader_type canvas_item;

//---------------------------------------------------------
// UNIFORMS
//---------------------------------------------------------

// Progression of the fill (0.0 to 1.0)
uniform float progress : hint_range(0.0, 1.0) = 0.5;

// Wave parameters
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;
uniform float wave_frequency : hint_range(0.0, 20.0) = 5.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 4.0;
uniform float wave_randomness_freq : hint_range(0.1, 5.0) = 3.0;
uniform float wave_randomness_amp : hint_range(0.1, 1.0) = 0.6;

// Foam parameters
uniform float foam_thickness : hint_range(0.0, 0.1) = 0.005;
uniform vec4 foam_color : source_color = vec4(0.5, 0.65, 0.8, 1.0);

// Colors (Base fill is handled by swirl colors now)
uniform vec4 bg_color : source_color = vec4(0.43, 0.43, 0.43, 0.2); // Transparent by default

// Border masking
const float BORDER_THRESHOLD = 0.25;
const float BORDER_ALPHA_THRESHOLD = 0.04;

// Swirl / Balatro Shader Uniforms
const bool POLAR_COORDINATES = true;
uniform vec2 polar_center = vec2(0.5);
uniform float polar_zoom = 1.;
uniform float polar_repeat = 1.;

uniform highp float spin_rotation = 0.0;
uniform highp float spin_speed = 20.0;
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

float calculate_wave_offset(vec2 uv, float time) {
	float wave1 = sin(uv.x * wave_frequency + time) * wave_amplitude;
	// Second wave with different frequency/speed/amplitude to create interference
	float wave2 = sin(uv.x * wave_frequency * wave_randomness_freq + time * 0.73) * (wave_amplitude * wave_randomness_amp);
	return wave1 + wave2;
}

bool is_border_pixel(vec4 color) {
	return length(color.rgb) < BORDER_THRESHOLD && color.a > BORDER_ALPHA_THRESHOLD;
}

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
	// Base UV.y is 0 at top, 1 at bottom.
	// We want to fill from bottom (1.0) to top (0.0).
	float y_threshold = 1.0 - progress;

	float time_wave = TIME * wave_speed;
	float wave_offset = calculate_wave_offset(UV, time_wave);
	float current_level = y_threshold + wave_offset;

	vec4 tex_color = texture(TEXTURE, UV);

	if (is_border_pixel(tex_color)) {
		// Preserve original border color
		COLOR = tex_color;
	} else {
		if (UV.y < current_level) {
			// Empty part (above the wave)
			COLOR = tex_color * bg_color;
		} else if (UV.y < current_level + foam_thickness) {
			// Wave foam (border)
			COLOR = foam_color;
			COLOR.a *= tex_color.a;
		} else {
			// Filled part (below the wave)

			// Apply Balatro Swirl Effect
			vec2 used_coords = UV;
			if (POLAR_COORDINATES){
				used_coords = polar_coords(UV.xy, polar_center, polar_zoom, polar_repeat);
			}

			// Using 1.0/TEXTURE_PIXEL_SIZE to attempt to simulate screen size if that was the intent,
			// OR just passing TEXTURE_PIXEL_SIZE as requested.
			// The user provided: effect(TEXTURE_PIXEL_SIZE, polarCoords).
			// FIX: TEXTURE_PIXEL_SIZE is very small, causing the swirl to be zoomed in 1000x.
			// Passing vec2(1.0) normalizes the calculation to UV space.
			vec4 swirl_color = effect(vec2(1.0), used_coords);

			COLOR = swirl_color;
			COLOR.a *= tex_color.a;
		}
	}
}
