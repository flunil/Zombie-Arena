extends Camera3D
## كاميرا علوية مائلة تتبع اللاعب بسلاسة (دوران ثابت)
## الموضع/الميل يُضبطان مباشرة من Transform في الـInspector (يُقرأان عند التشغيل)

@export var follow_lag := 8.0       ## سرعة التنعيم (قيمة أعلى = استجابة أسرع)
@export var rig_height := 14.0      ## يُشتق من transform.origin.y (للعرض/الاختبارات)
@export var rig_pitch_deg := -70.0  ## يُشتق من ميل transform.rotation.x

var _target: Node3D = null
var _offset := Vector3.ZERO            # إزاحة المتابعة كما في الـInspector
var _base_pos: Vector3 = Vector3.ZERO   # موضع المتابعة بدون اهتزاز
var _shake_strength: float = 0.0        # قوة الاهتزاز الحالية (وحدات عالم)
var _shake_left: float = 0.0            # المتبقي من زمن الاهتزاز
var view_area: Area3D = null            # نافذة الظهور أسفل الكاميرا (عدّ ظاهر/مخفي)

## إخفاء المباني المعترضة: شعاع من اللاعب نحو الكاميرا — كل مبنى يحجب نُخفي رسمه
## (يبقى تصادمًا) حتى لا تحجب الكاميرا، ويُعاد ظهوره فورًا عند زوال الحجب
const OCCLUDE_INTERVAL := 0.06     # كل كم ثانية يُعاد فحص الحجب
const OCCLUDE_HIDE_STREAK := 2     # تغطية متتالية قبل الإخفاء (يمنع الوميض)
const OCCLUDE_MAX_RAYS := 4        # تعدّد المباني على خط النظر
var _occ_timer := 0.0
var _occ_streaks := {}             # جذر المبنى ← عدّاد إطارات التغطية
var _occ_hidden: Array = []        # ما أخفيناه نحن فقط (لا نُظهر ما كان مخفيًا أصلًا)


func _ready() -> void:
	top_level = true  # decouple from parent transform so following can be smoothed
	# مصدر الحقيقة = Transform في الـInspector (position + rotation)
	_offset = transform.origin
	rig_height = _offset.y
	rig_pitch_deg = rotation_degrees.x
	_fit_viewport()   # قبل التموضع حتى يُحتسب الارتفاع الجديد
	rotation_degrees = Vector3(rig_pitch_deg, rotation_degrees.y, rotation_degrees.z)
	_target = get_parent() as Node3D
	if _target:
		global_position = _target.global_position + Vector3(_offset.x, rig_height, _offset.z)
	_base_pos = global_position
	current = true
	# العقدة موجودة في المشهد (Camera3D/ViewProbeArea) — نكتفي بقراءتها
	view_area = get_node_or_null("ViewProbeArea") as Area3D


## تكيّف مقاس الإطار مع نسبة الشاشة — اللعبة عمودية للهاتف
## في الوضع العمودي ينكمش العرض الأفقي كثيرًا مع FOV الثابت، فنرفع الكاميرا ونوسّع FOV
func _fit_viewport() -> void:
	var s := get_viewport().get_visible_rect().size
	var aspect := s.x / maxf(s.y, 1.0)
	if aspect <= 1.05:  # عمودي أو مربّع (بيئة headless) — إطالة أفقية فقط فوق 1.05
		rig_height *= 18.0 / 14.0  # رفع بنسّاع نفس الـTransform (14 → 18 في الوضع الافتراضي)
		fov = 82.0                 # بدل 65: تعويض ضيق النسبة العمودية


## اهتزاز خفيف (انفجارات / تلقّي ضرر) — يتلاشى خطيًا دون تأثير على المتابعة
func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_left = maxf(_shake_left, duration)


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	# Ease toward the rig position above the player to avoid snapping
	var want := _target.global_position + Vector3(_offset.x, rig_height, _offset.z)
	_base_pos = _base_pos.lerp(want, clampf(follow_lag * delta, 0.0, 1.0))
	var offset := Vector3.ZERO
	if _shake_left > 0.0:
		_shake_left -= delta
		var fade := clampf(_shake_left * 4.0, 0.0, 1.0)  # تلاشي فوق ~0.25ث
		if _shake_left <= 0.0:
			_shake_strength = 0.0
			fade = 0.0
		var s := _shake_strength * fade
		offset = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0) * 0.5, randf_range(-1.0, 1.0)) * s
	global_position = _base_pos + offset
	_occ_timer -= delta
	if _occ_timer <= 0.0:
		_occ_timer = OCCLUDE_INTERVAL
		_update_occluders()


## يجد جذر ما يُخفي: أعلى MeshInstance3D فوق الجسم (مبانٍ مفردة العقدة أو عبر M)،
## وإلا أب الجذر المباشر (مشهد مُدرجة كاملًا)
func _occluder_root(body: Node) -> Node3D:
	var mesh: MeshInstance3D = null
	var n: Node = body
	while n != null:
		if n is MeshInstance3D:
			mesh = n
		n = n.get_parent()
	if mesh != null:
		return mesh
	return body.get_parent() as Node3D


## فحص دوري: مَن يحجب خط النظر للاعب ← الكاميرا، وأخفِ/أظهر بحسب التغطية
func _update_occluders() -> void:
	if not is_instance_valid(_target):
		return
	var space := get_world_3d().direct_space_state
	var from := _target.global_position + Vector3(0.0, 1.2, 0.0)
	var to := global_position
	var dir := to - from
	if dir.length_squared() < 0.25:
		return
	var hit_roots: Dictionary = {}  # (لا اسم current: يظلّل خاصية Camera3D)
	var excluded: Array[RID] = []
	if _target is CollisionObject3D:
		excluded.append((_target as CollisionObject3D).get_rid())
	for i in OCCLUDE_MAX_RAYS:
		var rq := PhysicsRayQueryParameters3D.create(from, to, 1)  # طبقة العالم فقط
		rq.exclude = excluded
		rq.collide_with_areas = false
		var hit := space.intersect_ray(rq)
		if hit.is_empty():
			break
		var collider := hit["collider"] as Node3D
		if collider == null:
			break
		var root := _occluder_root(collider)
		if root == null or hit_roots.has(root):
			break
		hit_roots[root] = true
		excluded.append((collider as CollisionObject3D).get_rid())
		from = hit["position"] + dir.normalized() * 0.1  # تجاوز للشعاع التالي
	# صفر العدّاد لمن زال تغطيته
	for root in _occ_streaks.keys():
		if not hit_roots.has(root):
			_occ_streaks.erase(root)
	for root in hit_roots.keys():
		var n := int(_occ_streaks.get(root, 0)) + 1
		_occ_streaks[root] = n
		if n >= OCCLUDE_HIDE_STREAK:
			var r := root as Node3D
			if r.visible:
				r.visible = false
				if not _occ_hidden.has(r):
					_occ_hidden.append(r)
	# إعادة الإظهار لمن خرج من خط النظر (نتحقق من القائمة التي أخفيناه نحن فقط)
	for root in _occ_hidden.duplicate():
		var r := root as Node3D
		if not is_instance_valid(r):
			_occ_hidden.erase(root)
		elif not hit_roots.has(r):
			r.visible = true
			_occ_hidden.erase(r)
