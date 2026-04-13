shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.83, 0.66, 0.29, 0.6);
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float pulse_speed : hint_range(0.5, 4.0) = 1.5;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    float glow = pulse * glow_intensity;
    COLOR = tex + glow_color * glow * tex.a;
}
