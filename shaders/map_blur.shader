shader_type canvas_item;
// Light screen-space blur for the world behind the map (GLES2-safe: plain texture() taps, no mipmaps).
uniform float radius : hint_range(0.0, 8.0) = 2.5;   // blur reach in screen pixels
uniform float dim : hint_range(0.0, 1.0) = 0.10;      // slight darkening so the map reads clearly

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec3 c = texture(SCREEN_TEXTURE, SCREEN_UV).rgb * 4.0;
	c += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(px.x, 0.0)).rgb * 2.0;
	c += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(px.x, 0.0)).rgb * 2.0;
	c += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, px.y)).rgb * 2.0;
	c += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(0.0, px.y)).rgb * 2.0;
	c += texture(SCREEN_TEXTURE, SCREEN_UV + px).rgb;
	c += texture(SCREEN_TEXTURE, SCREEN_UV - px).rgb;
	c += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(px.x, -px.y)).rgb;
	c += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-px.x, px.y)).rgb;
	c /= 16.0;
	COLOR = vec4(c * (1.0 - dim), 1.0);
}
