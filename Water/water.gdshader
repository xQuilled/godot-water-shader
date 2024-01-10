shader_type spatial;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D water_gradient;
uniform sampler2D normal_map;
uniform sampler2D normal_map_2;
uniform sampler2D water_distortion;
uniform sampler2D wave_texture;
uniform float beer_factor = 0.5;
uniform vec2 normal_map_direction = vec2(0.0, 0.05);
uniform vec2 normal_map_direction_2 = vec2(0.0, 0.05);
uniform vec2 distortion_direction = vec2(0.0, -0.02);
uniform bool waves_enabled = true;
uniform vec2 wave_direction = vec2(0.0, 0.1);
uniform float distortion_strength = 0.05;
uniform float wave_strength = 1.0;
uniform float alpha_power = 0.1;
uniform float refraction_start = 0.2;
uniform float normal_map_start = 0.2;
uniform float refraction = 0.133;
uniform bool refraction_enabled = true;
uniform bool alpha_enabled = true;
uniform float roughness : hint_range(0.0, 1.0) = 0.0;
uniform float normal_map_strength = 1.0;
uniform vec2 uv_scale = vec2(1.0, 1.0); // KEEP (1,1) IF NEED SEAMLESS

void vertex() {
	if (waves_enabled) {
		vec2 uv = UV * uv_scale;
		vec3 wave = texture(wave_texture, uv + TIME * wave_direction).rgb * wave_strength - wave_strength/2.0;
		VERTEX = wave * NORMAL + VERTEX;
	}
}

void fragment() {
	vec2 uv = UV * uv_scale;
	NORMAL_MAP_DEPTH = normal_map_strength;
	float depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	float depth = PROJECTION_MATRIX[3][2] / (depth_raw + PROJECTION_MATRIX[2][2]);
	depth = depth + VERTEX.z;
	depth = 1.0 - exp(-depth * beer_factor);
	depth = clamp(depth, 0.0, 0.99);
	vec3 color = texture(water_gradient, vec2(depth)).rgb;
	ALBEDO = color;
	
	vec3 distortion_texture = texture(water_distortion, uv + TIME * distortion_direction).rgb * distortion_strength;
	vec2 normal_uv = uv + TIME * normal_map_direction + distortion_texture.r; 
	vec3 normal_map_texture = texture(normal_map, normal_uv).rgb;
	normal_uv = uv + TIME * normal_map_direction_2 + distortion_texture.r; 
	vec3 normal_map_texture_2 = texture(normal_map_2, normal_uv).rgb;
	normal_map_texture = mix(normal_map_texture, normal_map_texture_2, 0.5);
	NORMAL_MAP = mix(vec3(1), normal_map_texture, pow(depth, normal_map_start));
	
	ROUGHNESS = roughness;
	if (alpha_enabled) {
		float alpha = pow(depth, alpha_power);
		ALPHA = alpha;
	}
	if (refraction_enabled) {
		vec3 unpacked_normal = NORMAL_MAP;
		unpacked_normal.xy = unpacked_normal.xy * 2.0 - 1.0;
		unpacked_normal.z = sqrt(max(0.0, 1.0 - dot(unpacked_normal.xy, unpacked_normal.xy)));
		vec3 ref_normal = normalize( mix(NORMAL,TANGENT * unpacked_normal.x + BINORMAL * unpacked_normal.y + NORMAL * unpacked_normal.z,NORMAL_MAP_DEPTH));
		vec2 ref_ofs = SCREEN_UV - ref_normal.xy * refraction;
		float ref_amount = 1.0 - depth;
		EMISSION += texture(SCREEN_TEXTURE,ref_ofs).rgb * ref_amount;
		ALBEDO *= pow(depth, refraction_start);
	}
}

