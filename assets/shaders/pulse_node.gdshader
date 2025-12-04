shader_type canvas_item;

// Controls the speed of the pulse
uniform float speed : hint_range(0.1, 10.0) = 2.0;

// The color to apply to the sprite. Default is white (no change).
// 'source_color' allows Godot to treat this as sRGB and gives you a color picker.
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float min_alpha : hint_range(0.0, 1.0) = 0.1;

void fragment() {
    // 1. Get the sprite's original texture color
    vec4 tex_color = texture(TEXTURE, UV);
    
    // 2. Apply the custom color (Tint)
    // We multiply the texture color by our uniform color.
    vec4 final_color = tex_color * tint_color;
	
    // 3. Calculate the pulse
    // First, get a value from 0.0 to 1.0
    float wave = (sin(TIME * speed) + 1.0) / 2.0;
    
    // Then, map that value to the 0.1 -> 1.0 range
    // Logic: Minimum + (NormalizedWave * (Maximum - Minimum))
    float pulse = min_alpha + (wave * (1.0 - min_alpha));
    
    // 4. Apply the pulse to the alpha channel
    // We modify the alpha of our tinted color
    COLOR = vec4(final_color.rgb, final_color.a * pulse);
}