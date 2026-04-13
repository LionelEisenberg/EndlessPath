shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 0.5) = 0.15;
uniform float pulse_speed : hint_range(0.5, 4.0) = 1.5;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    COLOR = tex * (1.0 + pulse * glow_intensity);
}
