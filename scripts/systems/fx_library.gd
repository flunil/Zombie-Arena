class_name FxLibrary
## مكتبة المؤثرات البصرية: عقد مؤقتة تُضاف للمشهد وتتحرر تلقائياً (بلا تسرّب).
## جزيئات GPU للموت/الإصابة/الغبار + Hit-stop + اهتزاز كاميرا + انفجارات.

const FX_GROUP: String = "fx"


static func _spawn(node: Node) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		node.free()
		return
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root
	host.add_child(node)
	node.add_to_group(FX_GROUP)
	if node is GPUParticles3D:
		var p := node as GPUParticles3D
		p.emitting = true  # يبدأ بعد الإضافة للشجرة
		if not p.finished.is_connected(node.queue_free):
			p.finished.connect(node.queue_free)
	elif node is CPUParticles3D:
		var p := node as CPUParticles3D
		if not p.finished.is_connected(node.queue_free):
			p.finished.connect(node.queue_free)


## شكل الجسيم حسب الدور: قطرات كروية للرذاذ، شظايا زوايا للانفجار، شرر ممتد للطلب والنار
static func _mesh_for(shape: String, size: float) -> Mesh:
	match shape:
		"shard":  # شظايا: مكعبات صغيرة بزوايا حادة (انفجارات)
			var bsh := BoxMesh.new()
			bsh.size = Vector3(size, size * 0.7, size * 0.9)
			return bsh
		"streak":  # شرر: أعمدة أفقية ممتدة تُقرأ كخطوط ضوء (طلاء/ومضات جدار/شرارات صعود)
			var bst := BoxMesh.new()
			bst.size = Vector3(size * 2.4, size * 0.3, size * 0.3)
			return bst
		_:  # افتراضي: قطرة كروية (رشات الإصابة وقطرات الموت الخضراء)
			var sph := SphereMesh.new()
			sph.radius = size * 0.5
			sph.height = size
			return sph


## رذاذ جزيئات GPU عام (one_shot + حرر عند اكتماله) — أخف على CPU من CPUParticles3D
## مسبحة موارد: المواد/الشبكات تُنشأ مرة لكل (شكل، لون، حجم) وتُعاد استخدامها —
## تمنع تسرّب StandardMaterial3D/شبكات عند كل موت (كان يتراكم مئات الكيلوبايت لكل موجة)
static var _burst_res: Dictionary = {}  # مفتاح → {"mesh": Mesh, "mat": ParticleProcessMaterial}

static func _burst_resources(shape: String, size: float, color: Color, dir: Vector3,
		spread_deg: float, speed: float, grav: Vector3) -> Dictionary:
	var key := "%s|%.3f|%.3f|%.3f|%.3f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f" % [
		shape, size, color.r, color.g, color.b,
		dir.x, dir.y, dir.z, spread_deg, speed, grav.y]
	if _burst_res.has(key):
		return _burst_res[key] as Dictionary
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir.normalized()
	pm.spread = spread_deg
	pm.initial_velocity_min = speed * 0.55
	pm.initial_velocity_max = speed
	pm.gravity = grav
	var mesh := _mesh_for(shape, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.6
	mesh.material = m
	var res := {"mesh": mesh, "mat": pm}
	# حدّ صارم: أكثر من24 تركيبة فريدة نتجاهل التخزين (يمنع نمو لا متناهي للمسبحة)
	if _burst_res.size() < 24:
		_burst_res[key] = res
	return res


static func _burst(pos: Vector3, color: Color, count: int, speed: float, life: float,
		size: float, dir: Vector3, spread_deg: float, grav: Vector3,
		shape: String = "droplet") -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	p.local_coords = false  # الجسيمات تبقى في مكان الانطلاق بعد تحريك العقدة
	p.fixed_fps = 30
	var res := _burst_resources(shape, size, color, dir, spread_deg, speed, grav)
	p.process_material = res["mat"] as ParticleProcessMaterial
	p.draw_pass_1 = res["mesh"] as Mesh
	p.position = pos
	return p


## لمعة كروية تتلاشى (انفجارات / ترقية)
static func _flash_sphere(pos: Vector3, radius: float, color: Color, dur: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = pos
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, dur)
	tw.tween_callback(mi.queue_free)
	return mi


## إصابة عدو (رذاذ أخضر شاحب) أو جدار (شرر دافئ)
static func spawn_impact(pos: Vector3, normal: Vector3, enemy_hit: bool) -> void:
	var dir := normal
	if dir.length_squared() < 0.001:
		dir = Vector3.UP
	var color := Color(0.55, 1.0, 0.5) if enemy_hit else Color(1.0, 0.8, 0.45)
	var shape := "droplet" if enemy_hit else "streak"  # رشاش جسم كروي vs شرر جدار ممتد
	_spawn(_burst(pos + dir * 0.05, color, 8, 3.5, 0.3, 0.09, dir, 55.0, Vector3(0, -7, 0), shape))


## أرقام الضرر الطائرة: Label3D (billboard) يصعد للأعلى بتلاشي ثم يتحرر
static func spawn_damage_number(pos: Vector3, amount: float) -> void:
	var lbl := Label3D.new()
	lbl.text = str(maxi(1, int(round(amount))))
	lbl.font_size = 110
	lbl.pixel_size = 0.004
	lbl.outline_size = 28
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true  # تظهر فوق الزومبي حتى خلف جسم آخر
	lbl.modulate = Color(1.0, 0.88, 0.3)  # ذهبي مقروء فوق الأخضر
	lbl.position = pos + Vector3(randf_range(-0.18, 0.18), 0.0, randf_range(-0.1, 0.1))
	_spawn(lbl)
	var tw := lbl.create_tween()
	var rise := tw.tween_property(lbl, "position", lbl.position + Vector3.UP * 0.75, 0.55)
	rise.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var fade := tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.3)
	fade.set_delay(0.25)  # تظهر ثابتة قليلًا ثم تتلاشى في آخر 0.3 ثانية
	tw.tween_callback(lbl.queue_free)


## انفجار: يُستخدم مشهد ExplosionVFX (حطام+نار+دخان GPU) — يُستشهد عند موت Exploder وقذائف المتفجرات
const EXPLOSION_VFX_SCENE: PackedScene = preload("res://scenes/vfx/ExplosionVFX.tscn")


static func spawn_explosion(pos: Vector3, radius: float = 2.5) -> void:
	var vfx: Node3D = EXPLOSION_VFX_SCENE.instantiate()
	_spawn(vfx)
	vfx.global_position = pos
	vfx.call("explode")  # الأنظمة الثلاث + حذف ذاتي بعد 2 ثانية
	AudioManager.play_sfx("explosion", -2.0, 0.08)
	shake_camera(clampf(0.14 + radius * 0.045, 0.14, 0.35), 0.25)


## انفجار LegionGames — يُستشهد عند موت Exploder (نفس المشهد)
static func spawn_legion_explosion(pos: Vector3, radius: float = 2.5) -> void:
	var vfx: Node3D = EXPLOSION_VFX_SCENE.instantiate()
	_spawn(vfx)
	vfx.global_position = pos
	vfx.call("explode")
	AudioManager.play_sfx("explosion", -2.0, 0.08)
	shake_camera(clampf(0.14 + radius * 0.045, 0.14, 0.35), 0.25)


## مشهد انفجار الدخان (منقوص من Top-Down Action Adventure Starter Kit): نار + دخان + حطام متطاير
const SMOKE_EXPLOSION_SCENE: PackedScene = preload("res://assets/vfx/smoke_explosion/SmokeExplosion.tscn")


## موت الزومبي: انفجار SmokeExplosion — نار/دخان بحجم 50% (بلا حطام طائر)
static func spawn_death_burst(pos: Vector3) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree != null else null
	if host == null:
		return
	var vfx: GPUParticles3D = SMOKE_EXPLOSION_SCENE.instantiate()
	vfx.position = pos
	vfx.scale = Vector3.ONE * 0.19  # ≈1.8م ≈ حجم الزومبي (1.6م) + 10%
	host.add_child(vfx)
	vfx.add_to_group(FX_GROUP)
	# نُطلق يدويًا بلا _spawn: إشارة finished قد تُطلق مبكرًا قبل اكتمال الدخان
	vfx.emitting = true
	tree.create_timer(1.2).timeout.connect(
		func() -> void: if is_instance_valid(vfx): vfx.queue_free(),
		CONNECT_ONE_SHOT)
	_spawn(_burst(pos + Vector3.UP * 0.9, Color(0.95, 0.2, 0.15), 8, 2.8, 0.5, 0.14, Vector3.UP, 80.0, Vector3(0, -4.5, 0), "droplet"))  # أحمر
	_spawn(_burst(pos + Vector3.UP * 1.0, Color(1.0, 0.85, 0.2), 8, 2.5, 0.5, 0.13, Vector3.UP, 70.0, Vector3(0, -4.5, 0), "droplet"))  # أصفر


## ترقية: اندفاع ذهبي صاعد + ومضة
static func spawn_levelup_burst(pos: Vector3) -> void:
	_spawn(_flash_sphere(pos + Vector3.UP * 1.1, 0.7, Color(1.0, 0.85, 0.3), 0.3))
	_spawn(_burst(pos + Vector3.UP * 1.1, Color(1.0, 0.85, 0.35), 18, 4.0, 0.6, 0.13, Vector3.UP, 35.0, Vector3(0, 2.5, 0), "streak"))


## اهتزاز الكاميرا (خفيف — strength بوحدات العالم، duration بالثواني)
static func shake_camera(strength: float, duration: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var p := tree.get_first_node_in_group("player") as Node
	if p == null or not is_instance_valid(p):
		return
	var cam: Node = null
	if p.get("camera_path") != null:
		cam = p.get_node_or_null(p["camera_path"])
	if cam != null and cam.has_method("shake"):
		cam.call("shake", strength, duration)


## Hit-stop: تجميد لحظي متناهي الصغر عند الضربة القاتلة — يرفع متعة القتال بشكل مذهل
## يمر عبر TimeFX لمشاركة حالة السرعة (يمنع تعليق اللعب بـ Slow Motion دائم)
static func hit_stop(duration: float = 0.06) -> void:
	TimeFX.hit_stop(duration)


## غبار حركة: رذاذ ترابي خفيف عند أقدام الزومبي/اللاعب أثناء المشي
## مسبحة عقد مُعاد استخدامها: بلا إنشاء عقد/مواد/شبكات GPU عند كل نفخة (مصدر تقطيع رئيسي)
const DUST_POOL_SIZE := 24
static var _dust_pool: Array[GPUParticles3D] = []
static var _dust_next := 0
static var dust_demand := 0  # تلميتر: مرات طلب الغبار (لقياس ضغط المسبحة في perf_probe)
static var dust_enabled := true  # مفتاح تشخيص: تعطيل رش الغبار مؤقتًا (perf_probe)


## عقدة غبار جاهزة من المسبحة (تُبنى أول استخدام وتعاد تلقائيًا بعد تغيّر المشهد)
static func _dust_node() -> GPUParticles3D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root
	if host == null:
		return null
	if not _dust_pool.is_empty():
		_dust_pool = _dust_pool.filter(func(n): return is_instance_valid(n))
	while _dust_pool.size() < DUST_POOL_SIZE:
		var p := GPUParticles3D.new()
		p.one_shot = true
		p.amount = 4
		p.lifetime = 0.35
		p.explosiveness = 1.0
		p.local_coords = false  # الجسيمات تبقى في مكان الانطلاق بعد تحريك العقدة
		p.fixed_fps = 30
		p.emitting = false
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3.UP
		pm.spread = 40.0
		pm.initial_velocity_min = 0.33
		pm.initial_velocity_max = 0.6
		pm.gravity = Vector3(0, 1.2, 0)
		p.process_material = pm
		var mesh := _mesh_for("droplet", 0.1)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_color = Color(0.55, 0.5, 0.4, 0.5)
		m.emission_enabled = true
		m.emission = Color(0.55, 0.5, 0.4, 0.5)
		m.emission_energy_multiplier = 1.6
		mesh.material = m
		p.draw_pass_1 = mesh
		host.add_child(p)
		p.add_to_group(FX_GROUP)
		_dust_pool.append(p)
	var node := _dust_pool[_dust_next % _dust_pool.size()]
	_dust_next = (_dust_next + 1) % _dust_pool.size()
	return node


static func spawn_move_dust(pos: Vector3) -> void:
	if not dust_enabled:
		return
	dust_demand += 1
	var p := _dust_node()
	if p == null:
		return
	p.emitting = false  # أوقف أي انبعاث سابق (يمسح جسيماته القديمة عند إعادة التشغيل)
	p.global_position = pos + Vector3.UP * 0.05
	p.restart()
	p.emitting = true


## شرارات رصاص: رذاذ ذهبي ممتد عند ارتطام الطلقة بجدار/سطح صلب
static func spawn_sparks(pos: Vector3, normal: Vector3) -> void:
	var dir := normal
	if dir.length_squared() < 0.001:
		dir = Vector3.UP
	_spawn(_burst(pos + dir * 0.03, Color(1.0, 0.85, 0.3), 6, 4.0, 0.2,
		0.06, dir, 70.0, Vector3(0, -8, 0), "streak"))
