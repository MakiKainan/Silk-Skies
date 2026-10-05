shader_type spatial;
render_mode unshaded;

// Flat placeholder floor: a world-space grid so you can see how fast and which way you're moving.

uniform vec3 base_color : source_color = vec3(0.02, 0.03, 0.06);
uniform vec3 minor_color : source_color = vec3(0.06, 0.1, 0.18);
uniform vec3 major_color : source_color = vec3(0.12, 0.22, 0.4);
uniform float cell_size = 5.0;
uniform float major_every = 5.0;
uniform float line_width = 0.06;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 1.0 on a grid line, 0.0 elsewhere, antialiased.
float grid_line(vec2 p, float size, float width) {
	vec2 dist = abs(fract(p / size + 0.5) - 0.5) * size;
	float d = min(dist.x, dist.y);
	float aa = length(fwidth(p));
	return 1.0 - smoothstep(width - aa, width + aa, d);
}

void fragment() {
	vec2 p = world_pos.xz;
	float minor = grid_line(p, cell_size, line_width);
	float major = grid_line(p, cell_size * major_every, line_width * 1.6);
	vec3 col = mix(base_color, minor_color, minor);
	col = mix(col, major_color, major);
	ALBEDO = col;
}
