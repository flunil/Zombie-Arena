extends Node
## فحص: الشادرات الثلاثة حرفيّاً كما في godotshaders + العُقد تضبطها صحيحة

var fails := []


func check(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)


func _ready() -> void:
	# --- الكاميرا (ميل -70 كما في player_camera) ---
	var cam := Camera3D.new()
	cam.position = Vector3(0, 14, 6)
	cam.rotation_degrees = Vector3(-70, 0, 0)
	add_child(cam)
	cam.current = true

	# --- 1) الشادرات تُحمَّل ونصوصها كما في الموقع ---
	var mf := load("res://shaders/vfx/muzzle_flash.gdshader") as Shader
	var sm := load("res://shaders/vfx/smoke.gdshader") as Shader
	var rt := load("res://shaders/vfx/target_reticle.gdshader") as Shader
	check(mf != null and sm != null and rt != null, "shader load failed")
	var mfs := mf.code if mf else ""
	var sms := sm.code if sm else ""
	var rts := rt.code if rt else ""
	# المضة: الشادر الأصلي بلا مواجهة داخلية (كانت مضافتاها في نسختنا السابقة)
	check(not mfs.contains("mat4 mat_world"), "muzzle must not billboard (site code)")
	check(mfs.contains("inverse_fresnel"), "muzzle inverse_fresnel missing")
	check(mfs.contains("ALPHA_SCISSOR_THRESHOLD = 0.001"), "muzzle scissor missing")
	# الدخان: يحتوي المواجهة كما في الموقع
	check(sms.contains("mat4 mat_world"), "smoke billboard missing")
	check(sms.contains("MODELVIEW_NORMAL_MATRIX"), "smoke normal matrix missing")
	check(sms.contains("ALPHA = (albedo_tex.a * COLOR.a)"), "smoke fragment mismatch")
	# النقش: كود Reflex كامل بلا تعديلاتنا السابقة
	check(rts.contains("MOA_TO_RADIANS"), "reticle MOA missing")
	check(rts.contains("rotate_poa"), "reticle rotate_poa missing")
	check(rts.contains("ref_target_moa"), "reticle ref_target_moa missing")
	check(rts.contains("transpose(mat3(VIEW_MATRIX * MODEL_MATRIX))"), "reticle view_local missing")
	check(not rts.contains("unshaded"), "reticle must stay shaded (site code)")
	check(not rts.contains("ALPHA_SCISSOR"), "reticle scissor not in site code")

	# --- 2) المواد تدلّ على الشادرات وحقولها مضبوطة ---
	var mfm := load("res://shaders/vfx/muzzle_flash.tres") as ShaderMaterial
	var smm := load("res://shaders/vfx/smoke.tres") as ShaderMaterial
	var rtm := load("res://shaders/vfx/target_reticle.tres") as ShaderMaterial
	check(mfm != null and mfm.shader == mf, "muzzle material shader mismatch")
	check(smm != null and smm.shader == sm, "smoke material shader mismatch")
	check(rtm != null and rtm.shader == rt, "reticle material shader mismatch")
	check(int(mfm.get_shader_parameter("particles_anim_h_frames")) == 4, "muzzle h_frames")
	check(int(mfm.get_shader_parameter("particles_anim_v_frames")) == 1, "muzzle v_frames")
	check(int(smm.get_shader_parameter("particles_anim_h_frames")) == 4, "smoke h_frames")
	check(int(smm.get_shader_parameter("particles_anim_v_frames")) == 2, "smoke v_frames")
	check(mfm.get_shader_parameter("texture_albedo") != null, "muzzle texture")
	check(smm.get_shader_parameter("texture_albedo") != null, "smoke texture")
	check(rtm.get_shader_parameter("reticle_texture") != null, "reticle texture")
	check(is_equal_approx(float(rtm.get_shader_parameter("ref_target_moa")), 380.0), "reticle moa=380")
	var glass: Variant = rtm.get_shader_parameter("glass_color")
	check(glass is Color and is_equal_approx(glass.a, 0.0), "reticle glass alpha 0")

	# --- 3) السلاح: المضة تواجه الكاميرا والدخان في الفضاء العالمي ---
	var w := WeaponBase.new()
	add_child(w)
	check(w._flash != null and w._smoke != null, "muzzle emitters missing")
	check(w._flash.local_coords, "flash must be local_coords (node basis drives mesh)")
	check(not w._smoke.local_coords, "smoke must be world coords")
	check(w._flash.draw_pass_1.material == mfm, "flash draw pass material")
	check(w._smoke.draw_pass_1.material == smm, "smoke draw pass material")
	var aim := Vector3(0, 0, -1)
	w._trigger_muzzle(aim)
	var cb := cam.global_basis
	var fb := w._flash.global_basis
	check((fb.x - cb.x).length() < 0.001 and (fb.y - cb.y).length() < 0.001
		and (fb.z - cb.z).length() < 0.001, "flash basis must equal camera basis")
	var fpm := w._flash.process_material as ParticleProcessMaterial
	check(fpm != null, "flash process material")
	if fpm != null:
		var want := cb.inverse() * aim
		check((fpm.direction - want).length() < 0.001,
			"flash direction local-space, got %s want %s" % [fpm.direction, want])
	var spm := w._smoke.process_material as ParticleProcessMaterial
	# الدخان يُطلق باتجاه مائل للأعلى، ومع local_coords=false يكون الاتجاه عالمياً
	var want_smoke := aim.lerp(Vector3.UP, 0.5).normalized()
	check(spm != null and (spm.direction - want_smoke).length() < 0.001,
		"smoke direction world-space")
	check(spm != null and spm.direction.y > 0.0, "smoke direction tilted up")

	# --- 4) النقش: يتبع قدمي الهدف ويواجه الكاميرا ويبقى أمامه ---
	var target := Node3D.new()
	target.position = Vector3(3, 0, -2)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	target.add_child(cs)
	add_child(target)

	var ret := TargetReticle.new()
	add_child(ret)
	ret.track(target)
	check(ret.visible, "reticle not visible")
	var feet := Vector3(3, 0, -2)  # 0 + 0.8 - 1.6*0.5
	var rb := ret.global_basis
	var ray_to_cam := (cam.global_position - ret.global_position).normalized()
	check(rb.z.dot(ray_to_cam) > 0.999, "reticle perpendicular to view ray (faces camera)")
	check(absf(rb.x.dot(rb.z)) < 0.001 and absf(rb.y.dot(rb.z)) < 0.001
		and absf(rb.x.length() - 1.0) < 0.001, "reticle basis orthonormal")
	# على الشعاع نفسه من القدم نحو الكاميرا (لا تغيّر في موضع الشاشة)
	var wdir := cam.global_position - feet
	var v := ret.global_position - feet
	check(v.cross(wdir).length() < 0.001, "reticle not on view ray")
	check(ret.global_position.distance_to(cam.global_position)
		< feet.distance_to(cam.global_position), "reticle must be nearer than feet")
	# فوق سطح الأرض
	check(ret.global_position.y > 0.5, "reticle too low (ground clip risk)")
	ret.clear()
	check(not ret.visible, "reticle clear failed")
	target.queue_free()

	if fails.is_empty():
		print("SHADER_EXACT ALL_PASS")
	else:
		for f in fails:
			print("FAIL: ", f)
		print("SHADER_EXACT FAIL_COUNT=", fails.size())
	get_tree().quit()
