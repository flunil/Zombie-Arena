extends Node3D
class_name WeaponBase
## سلاح عام: تعبئة + إطلاق + انتشار + طلقات متعددة — كل السلوك محدد بالـ WeaponResource

signal ammo_changed(current: int, max_ammo: int)

## موضع احتياطي لمضة الفوهة — المجسم الفعلي على عظمة اليد في Player.tscn (وسم hand_node)
const MODEL_POS := Vector3(0.30, 1.05, -0.34)

@export var weapon_data: WeaponResource
@export var bullet_scene: PackedScene

var _ammo: int = 0
var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _ammo_regen_acc := 0.0  # ترقية AmmoRegen: مراكم الذخيرة/الثانية
const FLASH_MAT_PATH := "res://shaders/vfx/muzzle_flash.tres"  # شادر جدول حركة المضة
const SMOKE_MAT_PATH := "res://shaders/vfx/smoke.tres"          # شادر جدول حركة الدخان
const FLASH_SIZE := 0.55   # حجم مربّع المضة بالوحدات
const SMOKE_SIZE := 0.75   # حجم مربّع الدخان بالوحدات (الإطار يملأ الخليّة)

var _flash: GPUParticles3D = null
var _smoke: GPUParticles3D = null  # سحابة البارودة — تُشعل مع المضة نفسها
var hand_node: Node3D = null  # سلاح اليد المطابق (يضبطه weapon_manager — مصدر المجسم البصري)


func _ready() -> void:
	if weapon_data == null:
		weapon_data = WeaponResource.new()
	_apply_hand_model_stats()
	_ammo = get_ammo_max()
	ammo_changed.emit(_ammo, get_ammo_max())
	_build_muzzle_flash()


## ترقية AmmoRegen (عادي): +N ذخيرة كل ثانية أثناء التجديد — يوقف أثناء إعادة التلقيم
func _process(delta: float) -> void:
	var rate := UpgradeManager.get_ammo_regen_rate()
	if rate <= 0.0 or _reload_left > 0.0 or _ammo >= get_ammo_max():
		_ammo_regen_acc = 0.0
		return
	_ammo_regen_acc += rate * delta
	if _ammo_regen_acc >= 1.0:
		var add := int(_ammo_regen_acc)
		_ammo_regen_acc -= float(add)
		var before := _ammo
		_ammo = mini(get_ammo_max(), _ammo + add)
		if _ammo != before:
			ammo_changed.emit(_ammo, get_ammo_max())


## مدى/ضرر محرَّران من مشهد النموذج (hand_node) إن كانا > 0 — يعلقان فوق قيم weapon_data
func _apply_hand_model_stats() -> void:
	if hand_node == null or weapon_data == null:
		return
	if "damage" in hand_node:
		var d := float(hand_node.get("damage"))
		if d > 0.0:
			weapon_data.damage = d
	if "max_range" in hand_node:
		var r := float(hand_node.get("max_range"))
		if r > 0.0:
			weapon_data.max_range = r


## ومضة فوهة + سحابة بارودة لكل سلاح (one_shot — تُشعلان مع كل إطارة)
func _build_muzzle_flash() -> void:
	_flash = GPUParticles3D.new()
	_flash.name = "MuzzleFlash"
	_flash.one_shot = true
	_flash.amount = 6
	_flash.lifetime = 0.07
	_flash.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.direction = Vector3.FORWARD
	pm.spread = 35.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 6.5
	pm.gravity = Vector3.ZERO
	var tint := Color(1.0, 0.9, 0.45)
	if weapon_data != null:
		tint = weapon_data.bullet_color.lerp(Color(1.0, 0.9, 0.4), 0.55)
	pm.color = tint
	_flash.process_material = pm
	# شادر المضة الأصلي لا يواجه الكاميرا داخلياً ⇒ نواجه العقدة نفسها للكاميرا
	# local_coords=true ضروري: معه يُطبَّق تحويل العقدة على المِش (فيتمّ التوجيه)
	# وتُفسَر الحركة في إطار العقدة المحلّي
	_flash.local_coords = true
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.draw_pass_1 = _sprite_quad(FLASH_MAT_PATH, Vector2(FLASH_SIZE, FLASH_SIZE))
	_flash.position = MODEL_POS
	add_child(_flash)
	_build_muzzle_smoke()


## سحابة بارودة خلف الفوهة — نفس توقيت المضة لكن أبطأ وأكبر تدريجياً
func _build_muzzle_smoke() -> void:
	_smoke = GPUParticles3D.new()
	_smoke.name = "MuzzleSmoke"
	_smoke.one_shot = true
	_smoke.amount = 9
	_smoke.lifetime = 0.85
	_smoke.explosiveness = 0.85
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.direction = Vector3.FORWARD
	pm.spread = 55.0
	pm.initial_velocity_min = 0.7
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0.0, 1.2, 0.0)  # الكتلة تصعد قليلاً بعد الخروج
	pm.scale_min = 0.85
	pm.scale_max = 1.25
	# توسّع الدخان أثناء عمره (الشادر يقرأ مقياس MODEL_MATRIX)
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.55))
	grow.add_point(Vector2(1.0, 1.45))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	# CUSTOM.x = الزاوية بالراديان (من درجات angle) — دوارة عشوائية لكل جسيم
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	# CUSTOM.z = الإزاحة مُنقّطة 0..1 => floor(z*frames) يعطي إطاراً عشوائياً من الجدول
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0
	pm.color = Color(1.0, 1.0, 1.0, 0.55)
	_smoke.process_material = pm
	# شادر الدخان يواجه الكاميرا داخل vertex، ونُبقي الجسيمات في الفضاء العالمي
	# فتبقى معلّقة في الهواء بعد خروجها من الفوهة (وتُفسَر الحركة عالميّاً)
	_smoke.local_coords = false
	_smoke.draw_pass_1 = _sprite_quad(SMOKE_MAT_PATH, Vector2(SMOKE_SIZE, SMOKE_SIZE))
	_smoke.position = MODEL_POS
	add_child(_smoke)


## مربّع مرسوم بشادر الجسيمات — الشادر يتولّى المواجهة للكاميرا والمقياس
static func _sprite_quad(mat_path: String, size: Vector2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	q.material = load(mat_path)
	return q


## الشكل المميز لكل سلاح (الفوهة نحو -Z أعلى الشاشة)
## يُستخدم لتوليد scenes/weapons/models عبر tests/make_weapon_scenes (لا يُشغَّل بعد استبدال المستخدم المجسمات)
## ملاحظة: المجسم البصري أثناء اللعب يأتي من عقد اليد في Player.tscn وليس من هنا
func _build_shape(m: Node3D) -> void:
	var accent: Color = weapon_data.bullet_color
	match weapon_data.weapon_id:
		"ak47":
			_box(m, Vector3(0.09, 0.12, 0.42), Vector3.ZERO, Color(0.35, 0.2, 0.1))
			_cyl(m, 0.025, 0.4, Vector3(0, 0.02, -0.4), Color(0.12, 0.12, 0.13), Vector3(PI / 2, 0, 0))
			_box(m, Vector3(0.07, 0.17, 0.1), Vector3(0, -0.13, -0.04), Color(0.1, 0.1, 0.11))
			_box(m, Vector3(0.07, 0.1, 0.24), Vector3(0, 0, 0.32), Color(0.4, 0.24, 0.12))
			_box(m, Vector3(0.06, 0.15, 0.07), Vector3(0, -0.12, 0.15), Color(0.4, 0.24, 0.12), Vector3(-0.25, 0, 0))
		"shotgun":
			_cyl(m, 0.025, 0.5, Vector3(-0.03, 0.02, -0.44), Color(0.12, 0.12, 0.14), Vector3(PI / 2, 0, 0))
			_cyl(m, 0.025, 0.5, Vector3(0.03, 0.02, -0.44), Color(0.12, 0.12, 0.14), Vector3(PI / 2, 0, 0))
			_box(m, Vector3(0.11, 0.11, 0.24), Vector3(0, 0, -0.08), Color(0.15, 0.15, 0.16))
			_box(m, Vector3(0.08, 0.1, 0.3), Vector3(0, -0.02, 0.24), Color(0.42, 0.26, 0.13))
			_box(m, Vector3(0.09, 0.07, 0.14), Vector3(0, -0.06, -0.36), Color(0.42, 0.26, 0.13))
		"heavymg":
			_box(m, Vector3(0.14, 0.16, 0.5), Vector3.ZERO, Color(0.14, 0.15, 0.16))
			_cyl(m, 0.035, 0.5, Vector3(0, 0.03, -0.5), Color(0.2, 0.2, 0.22), Vector3(PI / 2, 0, 0))
			_cyl(m, 0.05, 0.08, Vector3(0, 0.03, -0.74), Color(0.1, 0.1, 0.1), Vector3(PI / 2, 0, 0))
			_box(m, Vector3(0.1, 0.15, 0.16), Vector3(0.11, -0.04, 0.06), Color(0.3, 0.32, 0.2))  # صندوق الذخيرة
			_box(m, Vector3(0.3, 0.03, 0.03), Vector3(0, -0.12, -0.55), Color(0.1, 0.1, 0.1))  # قاعدة أمامية
		"laserifle":
			_box(m, Vector3(0.09, 0.12, 0.5), Vector3.ZERO, Color(0.82, 0.86, 0.9))
			_cyl(m, 0.03, 0.3, Vector3(0, 0.03, -0.44), Color(0.15, 0.16, 0.18), Vector3(PI / 2, 0, 0))
			_box(m, Vector3(0.02, 0.035, 0.4), Vector3(0.05, 0.05, -0.04), accent, Vector3.ZERO, true)
			_cyl(m, 0.05, 0.12, Vector3(0, -0.09, 0.06), accent, Vector3.ZERO)  # خلية الطاقة
			_box(m, Vector3(0.06, 0.13, 0.07), Vector3(0, -0.12, 0.16), Color(0.2, 0.22, 0.25), Vector3(-0.25, 0, 0))
		"flamethrower":
			_box(m, Vector3(0.1, 0.12, 0.4), Vector3.ZERO, Color(0.45, 0.15, 0.12))
			_cyl(m, 0.04, 0.26, Vector3(0, 0, -0.4), Color(0.12, 0.12, 0.13), Vector3(PI / 2, 0, 0))
			_cyl(m, 0.055, 0.26, Vector3(-0.06, 0.1, 0.04), Color(0.75, 0.4, 0.12), Vector3(PI / 2, 0, 0))  # خزان
			_cyl(m, 0.055, 0.26, Vector3(0.06, 0.1, 0.04), Color(0.75, 0.4, 0.12), Vector3(PI / 2, 0, 0))  # خزان
			_box(m, Vector3(0.06, 0.14, 0.07), Vector3(0, -0.12, 0.13), Color(0.2, 0.2, 0.22), Vector3(-0.25, 0, 0))
		"grenadelauncher":
			_cyl(m, 0.055, 0.42, Vector3(0, 0.02, -0.36), Color(0.2, 0.3, 0.2), Vector3(PI / 2, 0, 0))  # أنبوب سميك قصير
			_box(m, Vector3(0.1, 0.13, 0.3), Vector3(0, 0, 0.02), Color(0.22, 0.32, 0.22))
			_cyl(m, 0.09, 0.07, Vector3(0, -0.1, 0.04), Color(0.1, 0.1, 0.1))  # طبلة الذخيرة
			_box(m, Vector3(0.06, 0.14, 0.07), Vector3(0, -0.12, 0.17), Color(0.15, 0.2, 0.15), Vector3(-0.25, 0, 0))
		"rocketlauncher":
			_cyl(m, 0.075, 0.95, Vector3(0, 0.05, -0.12), Color(0.3, 0.34, 0.22), Vector3(PI / 2, 0, 0))  # أنبوب الصاروخ
			_cone(m, 0.07, 0.02, 0.16, Vector3(0, 0.05, -0.66), accent, Vector3(PI / 2, 0, 0))  # رأس مخروطي
			_cyl(m, 0.085, 0.06, Vector3(0, 0.05, 0.4), Color(0.12, 0.12, 0.12), Vector3(PI / 2, 0, 0))  # فتحة خلفية
			_box(m, Vector3(0.03, 0.07, 0.14), Vector3(0, 0.15, -0.1), Color(0.1, 0.1, 0.1))  # مِسبار
			_box(m, Vector3(0.06, 0.14, 0.07), Vector3(0, -0.1, 0.2), Color(0.15, 0.16, 0.14), Vector3(-0.25, 0, 0))
		"teslacoil":
			_box(m, Vector3(0.13, 0.09, 0.32), Vector3.ZERO, Color(0.14, 0.14, 0.16))
			_cyl(m, 0.05, 0.3, Vector3(0, 0.18, 0), Color(0.72, 0.45, 0.2))  # ملف نحاسي
			_cyl(m, 0.075, 0.03, Vector3(0, 0.1, 0), Color(0.5, 0.3, 0.15))  # حلقة
			_cyl(m, 0.075, 0.03, Vector3(0, 0.18, 0), Color(0.5, 0.3, 0.15))  # حلقة
			_cyl(m, 0.075, 0.03, Vector3(0, 0.26, 0), Color(0.5, 0.3, 0.15))  # حلقة
			_sph(m, 0.06, Vector3(0, 0.37, 0), accent, true)  # كرة التفريغ الكهربائية
		"smokelauncher":
			_cyl(m, 0.06, 0.36, Vector3(0, 0.02, -0.34), Color(0.3, 0.32, 0.35), Vector3(PI / 2, 0, 0))
			_box(m, Vector3(0.1, 0.12, 0.3), Vector3(0, 0, 0.04), Color(0.32, 0.34, 0.37))
			_cyl(m, 0.05, 0.2, Vector3(0.07, 0.08, 0.06), Color(0.25, 0.45, 0.25))  # علبة الدخان
			_cyl(m, 0.075, 0.08, Vector3(0, 0.02, -0.55), Color(0.14, 0.14, 0.15), Vector3(PI / 2, 0, 0))  # فوهة
			_box(m, Vector3(0.06, 0.14, 0.07), Vector3(0, -0.12, 0.15), Color(0.16, 0.17, 0.18), Vector3(-0.25, 0, 0))
		_:
			_box(m, Vector3(0.09, 0.12, 0.45), Vector3.ZERO, Color(0.2, 0.2, 0.22))  # شكل افتراضي
			_cyl(m, 0.025, 0.35, Vector3(0, 0.02, -0.4), Color(0.1, 0.1, 0.1), Vector3(PI / 2, 0, 0))


## مساعدات المجسمات (مركّبة إجرائية) — خلوية بالحواف إن لم تكن مضيئة
static func _mat(color: Color, emissive: bool = false) -> Material:
	if not emissive:
		return CelMaterial.from_color(color)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = color
	mm.roughness = 0.55
	mm.emission_enabled = true
	mm.emission = color
	mm.emission_energy_multiplier = 1.8
	return mm


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color, emissive)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = _mat(color)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cone(parent: Node3D, r_bottom: float, r_top: float, height: float, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = height
	mi.mesh = cm
	mi.material_override = _mat(color)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _sph(parent: Node3D, radius: float, pos: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.material_override = _mat(color, emissive)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			_ammo = get_ammo_max()
			ammo_changed.emit(_ammo, get_ammo_max())


## سقف الذخيرة بعد ترقية AmmoBoost + الترقية الدائمة + ترقيات ورشة السلاح
func get_ammo_max() -> int:
	var mult: float = SaveSystem.get_weapon_stat_mult(weapon_data.weapon_id, "ammo")
	return maxi(1, int(round(float(weapon_data.ammo_max) * UpgradeManager.get_ammo_mult() * SaveSystem.get_ammo_mult() * mult)))


func get_ammo() -> int:
	return _ammo


func is_reloading() -> bool:
	return _reload_left > 0.0


## محاولة إطلاق (طلقة أو عدة عند pellets > 1)
func try_fire(direction: Vector3) -> void:
	if _reload_left > 0.0 or _cooldown > 0.001:
		return
	if _ammo <= 0:
		_start_reload()
		return
	_ammo -= 1
	var rate_mult: float = SaveSystem.get_weapon_stat_mult(weapon_data.weapon_id, "fire_rate")
	_cooldown = 1.0 / maxf(0.01, weapon_data.fire_rate * UpgradeManager.get_fire_rate_mult() * rate_mult)
	_fire_projectiles(direction)
	_trigger_muzzle(direction)
	# اهتزاز بارتداد: أقوى للأسلحة المتفجرة (rocket/grenade) وخفيف للبقية
	if weapon_data.explosion_radius > 0.0:
		FxLibrary.shake_camera(0.12, 0.22)  # سلاح متفجر — اهتزاز أوضح
	else:
		FxLibrary.shake_camera(0.05, 0.15)  # اهتزاز بارتداد خفيف جدًا (maxf يمنع التكديس)
	AudioManager.play_sfx("fire_" + weapon_data.weapon_id, -2.0, 0.06)
	ammo_changed.emit(_ammo, get_ammo_max())
	if _ammo <= 0:
		_start_reload()


func _start_reload() -> void:
	if _reload_left > 0.0:
		return
	_reload_left = maxf(0.05, weapon_data.reload_time * UpgradeManager.get_reload_mult())


## عقدة Muzzle أسفل سلاح اليد — تحكم بمكان خروج الرصاص والمضة إن وُجدت
func _muzzle_marker() -> Marker3D:
	if hand_node != null and is_instance_valid(hand_node):
		return hand_node.get_node_or_null("Muzzle") as Marker3D
	return null


## إشعال المضة والسحابة عند طرف أنبوب السلاح — كلاهما يتبع اتجاه التصويب
func _trigger_muzzle(direction: Vector3) -> void:
	if _flash != null:
		_fire_emitter(_flash, direction, true)
	if _smoke != null:
		# الدخان ينثثر نحو الفوهة مع ميل للأعلى (كحزمة بارودة صاعدة)
		_fire_emitter(_smoke, direction.lerp(Vector3.UP, 0.5).normalized(), false)


## وضع مُشغّل عند فوهة السلاح ثم إعادة إشعاله باتجاه الرمية
## face_camera: توجيه عقدة المضة نحو الكاميرا (شادر المضة بلا مواجهة داخلية)
func _fire_emitter(p: GPUParticles3D, dir: Vector3, face_camera := false) -> void:
	# عند عقدة Muzzle إن وُجدت وإلا عند فوهة سلاح اليد ثم الموضع الاحتياطي
	var muzzle := _muzzle_marker()
	if muzzle != null:
		_pose_emitter(p, muzzle.global_position, face_camera)
	elif hand_node != null and is_instance_valid(hand_node):
		_pose_emitter(p, hand_node.global_position + dir * 0.45, face_camera)
	else:
		p.position = MODEL_POS + dir * 0.55
		if face_camera:
			_face_camera(p)
	var pm := p.process_material as ParticleProcessMaterial
	if pm != null:
		# الاتجاه يُفسَر في إطار العقدة إن كانت محلّية وإلا عالميّاً
		pm.direction = (p.global_basis.inverse() * dir) if p.local_coords else dir
	p.restart()
	p.emitting = true


func _pose_emitter(p: GPUParticles3D, pos: Vector3, face_camera: bool) -> void:
	var b := p.global_basis
	if face_camera:
		var cam := _view_camera()
		if cam != null:
			b = cam.global_basis
	p.global_transform = Transform3D(b, pos)


func _face_camera(p: GPUParticles3D) -> void:
	var cam := _view_camera()
	if cam != null:
		p.global_basis = cam.global_basis


func _view_camera() -> Camera3D:
	if not is_inside_tree():
		return null
	return get_viewport().get_camera_3d()


func _fire_projectiles(direction: Vector3) -> void:
	if bullet_scene == null:
		return
	if direction.length() < 0.001:
		direction = Vector3(0, 0, -1)
	direction = direction.normalized()
	var count: int = maxi(1, weapon_data.pellets)
	for i in count:
		_spawn_bullet(_apply_spread(direction))
	# ترقية Multishot (ممتاز): طلقات إضافية متباعدة حول الاتجاه
	var bonus := UpgradeManager.get_multishot_bonus()
	for i in bonus:
		var ang := 0.14 * float(i + 1)  # ≈8° لكل طلقة
		if i % 2 == 1:
			ang = -ang
		_spawn_bullet(_apply_spread(direction.rotated(Vector3.UP, ang)))


## انتشار مخروطي حول الاتجاه (بالراديان)
func _apply_spread(dir: Vector3) -> Vector3:
	var s: float = weapon_data.spread * UpgradeManager.get_spread_mult()
	if s <= 0.0:
		return dir
	var side: Vector3 = dir.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	var out: Vector3 = dir.rotated(Vector3.UP, randf_range(-s, s))
	out = out.rotated(side.normalized(), randf_range(-s, s))
	return out.normalized()


func _spawn_bullet(dir: Vector3) -> void:
	var bullet: Node3D = bullet_scene.instantiate()
	var dmg_mult: float = SaveSystem.get_weapon_stat_mult(weapon_data.weapon_id, "damage")
	bullet.damage = weapon_data.damage * UpgradeManager.get_damage_mult() * SaveSystem.get_damage_mult() * dmg_mult
	if UpgradeManager.has("big_bullets"):  # نادر: طلقات سميكة +10% ضرر
		bullet.damage *= UpgradeManager.get_big_bullets_dmg_mult()
	var crit := UpgradeManager.roll_crit()  # CritChance/CritPower: حرج ×2 حتى ×2.5
	if crit:
		bullet.damage *= UpgradeManager.get_crit_mult()
	StatsTracker.record_shot()
	bullet.speed = weapon_data.bullet_speed * UpgradeManager.get_bullet_speed_mult()
	bullet.direction = dir
	var range_mult: float = SaveSystem.get_weapon_stat_mult(weapon_data.weapon_id, "range")
	bullet.life = (weapon_data.max_range * range_mult * UpgradeManager.get_range_mult()) / maxf(1.0, bullet.speed)
	bullet.pierce = weapon_data.pierce + UpgradeManager.get_pierce_bonus()
	bullet.explosion_radius = weapon_data.explosion_radius
	if UpgradeManager.has_explosive_rounds() and bullet.explosion_radius <= 0.0:
		bullet.explosion_radius = 1.8  # ترقية ExplosiveRounds
	if bullet.explosion_radius > 0.0:
		bullet.explosion_radius += UpgradeManager.get_blast_bonus()  # ExplosiveMastery: +1م
	bullet.chain_targets = weapon_data.chain_targets
	if weapon_data.chain_targets > 0:
		bullet.chain_targets += UpgradeManager.get_chain_bonus()  # ChainPlus: +1 قفزة
	bullet.poison_radius = weapon_data.poison_radius
	bullet.poison_time = weapon_data.poison_time
	bullet.poison_dps = weapon_data.poison_dps
	bullet.bullet_color = weapon_data.bullet_color
	if crit:
		bullet.bullet_color = Color(1.0, 0.82, 0.15)  # إصابة حاسمة: أثر ذهبي مميز
	bullet.visual_scale = weapon_data.bullet_scale * UpgradeManager.get_bullet_scale_mult()
	get_tree().current_scene.add_child(bullet)
	# الطلقة تنطلق من عقدة Muzzle أسفل السلاح إن وُجدت (تحكّم يدوي بموضع الخروج)
	# وإلا من ارتفاع السلاح (1.05م) لا من أرضية اللاعب — الرصاص عند y=0
	# كان يمرّ تحت الزومبي (قاع كبسولته ≈ 0.075م) فلا يصيبه أبدًا
	var muzzle := _muzzle_marker()
	if muzzle != null:
		bullet.global_position = muzzle.global_position
	else:
		bullet.global_position = get_parent().global_position + Vector3(0.0, 1.05, 0.0)
