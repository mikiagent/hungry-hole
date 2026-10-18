shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
// Flat-colored ground that is cut open under each hole (depth-mask replacement).
uniform vec4 base_color : source_color = vec4(0.545, 0.831, 0.314, 1.0);
uniform vec4 holes[8];          // x, z, radius, active
uniform vec4 inner_color : source_color = vec4(0.078, 0.078, 0.125, 1.0);
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	for (int i = 0; i < 8; i++) {
		if (holes[i].w > 0.5) {
			float d = distance(world_pos.xz, holes[i].xy);
			if (d < holes[i].z) { discard; }
		}
	}
	ALBEDO = base_color.rgb;
	ROUGHNESS = 1.0;
}
