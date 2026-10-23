shader_type spatial;
render_mode unshaded, depth_draw_opaque;

// Inspired by https://godotshaders.com/shader/3d-pixel-art-outline-highlight-post-processing-shader/
// تحسين 60fps: حُذفت SCREEN_TEXTURE بالكامل — shadow_color=0 كان يضرب عيّناتها في صفر (حساب ميت)
// مع فرض نسخة شاشة كاملة كل إطار على المحرك Mobile

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

uniform vec3 shadow_color : source_color = vec3(0.0);
uniform float shadow_thickness = 2.0;

vec2 getDepth(vec2 screen_uv, sampler2D depth_texture, mat4 inv_projection_matrix){
	float raw_depth = texture(depth_texture, screen_uv)[0];
	vec3 normalized_device_coordinates = vec3(screen_uv * 2.0 - 1.0, raw_depth);
    vec4 view_space = inv_projection_matrix * vec4(normalized_device_coordinates, 1.0);	
	view_space.xyz /= view_space.w;	
	return vec2(-view_space.z, raw_depth);
}


void fragment() {
	vec2 e = vec2(1./VIEWPORT_SIZE.xy)*1.0;

	float depth_diff = 0.0;

	vec2 depth_data = getDepth(SCREEN_UV, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	float depth = depth_data.x;

	vec2 min_depth_data = depth_data;
	float min_depth = 99.9;

	for (float x = -shadow_thickness; x <= shadow_thickness;x += 1.0){
		for (float y = -shadow_thickness; y <= shadow_thickness; y += 1.0){
			if ((x == 0.0 && y == 0.0) || (shadow_thickness*shadow_thickness < (x*x + y*y))){
				continue;
			}

			vec2 du_data = getDepth(SCREEN_UV+1.0*vec2(x, y)*e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
			vec2 dd_data = getDepth(SCREEN_UV+0.5*vec2(x, y)*e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);

			float du = du_data.x;
			float dd = dd_data.x;

			float dd_diff = clamp(abs((depth - dd) - (dd - du)), 0.0, 1.0);

			// عتبة أقل للخطوة: درزات البلاطات الملّيمترية (0-8سم) لا تُرسم —
			// تراكم النقاط الصغيرة على خط مستقيم كان يصنع خطوطًا رفيعة على الأرض.
			// خطوات 12سم+ (حواف الأرصفة/قواعد المباني/الأعداء) تبقى محفوظة.
			float raw_step = max(abs(depth - du) - 0.12, 0.0);

			float val = clamp(raw_step, 0., 1.)/(x*x + y*y)*dd_diff*dd_diff*5000.0;

			val = clamp(val, 0.0, 1.0);

			depth_diff += val;

			if (du < min_depth){
				min_depth = du;
				min_depth_data = du_data;
			}

			// Mobile renderer: لا يتوفر hint_normal_roughness_texture (Forward+ فقط) — الكشف بالعمق وحده
		}
	}


	depth_diff = smoothstep(0.2, 0.3, depth_diff);

	// تلاشي تدريجي للحدود البعيدة: عند35-55م يصبح حجم البكسل أكبر من التفاصيل
	// فتظهر وهجات/خطوط شاشية — الحد المقلوب للـcel يبقى للsilhouettes البعيدة.
	float dist_fade = 1.0 - smoothstep(35.0, 55.0, depth);
	float alpha_mask = depth_diff * dist_fade;

	ALBEDO = shadow_color;

	DEPTH = min_depth_data.y*alpha_mask + depth_data.y*(1.0-alpha_mask);
	ALPHA = clamp((alpha_mask) * 0.4, 0., 1.);  // خفيف: سقف شفافية 40% بدل الاعتمة الكاملة (كان 5.0 ≈ 100%)

}
