class_name TargetReticle
extends Node3D
## نقطة التصويب (Red Dot) تحت الزومبي المستهدف — شادر Reflex الأصلي بامتياز
## الشادر يبني الـUV من اتجاه النظر داخل الإطار المحلي، فهو يتطلّب لوحة تواجه الكاميرا:
## نضبط المواجهة من هنا عبر transform العقدة (وليس داخل الشادر) فيبقى الشادر حرفيّاً كما هو.

const SIZE := 4.0            # حجم المربّع — يجب أن يتّسع للقرص الظاهر عند أقصى مدى
const OCCLUDE := 1.6         # إزاحة على شعاع النظر نحو الكاميرا
const LIFT := 0.06           # رفع احتياطي حين لا توجد كاميرا
const MATERIAL_PATH := "res://shaders/vfx/target_reticle.tres"

var _mesh: MeshInstance3D = null
var _target: Node3D = null


func _ready() -> void:
	visible = false
	_mesh = MeshInstance3D.new()
	_mesh.name = "ReticleMesh"
	var quad := QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE)
	quad.material = load(MATERIAL_PATH)
	_mesh.mesh = quad
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	# اللوحة تتبع الهدف بوضعها العالمي وحدها — لا ترث تحويل اللاعب
	set_as_top_level(true)


## تتبّع هدف جديد (null أو غير صالح = إخفاء)
func track(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		clear()
		return
	_target = target
	visible = true
	_snap()


## إخفاء اللوحة (لا هدف / موت اللاعب)
func clear() -> void:
	_target = null
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	# التعافي الذاتي إن مات الهدف أو خرج من المشهد
	if _target == null or not is_instance_valid(_target):
		clear()
		return
	_snap()


## وضع اللوحة على قدمي الهدف + مواجهتها للكاميرا
func _snap() -> void:
	var p := _target.global_position
	var feet := Vector3(p.x, _feet_y(_target), p.z)
	var cam := _camera()
	if cam == null:
		global_position = feet + Vector3(0.0, LIFT, 0.0)
		return
	var to_cam := cam.global_position - feet
	if to_cam.length_squared() < 0.000001:
		global_position = feet + Vector3(0.0, LIFT, 0.0)
		return
	# الإزاحة على الشعاع نفسه لا تغيّر موضع الشاشة إطلاقاً، لكنها تُخرج اللوحة
	# من داخل جسم الزومبي (الشعاع يبقى داخل الكبسولة نحو 1.0م قبل القدم)
	# فتظهر كاملة، وتبقى فوق سطح الأرض في كل المدىات.
	var dir := to_cam.normalized()
	var pos := feet + dir * OCCLUDE
	# المحاذاة: متعامدة مع شعاع النظر **إلى القدم** — لا مع محور الكاميرا.
	# الشادر يبني الـUV من اتجاه النظر داخل الإطار المحلي، فإن استخدمنا محور الكاميرا
	# صار مركز النقش هو مركز الشاشة لا قدم الزومبي، وقصّته حواف اللوحة حين ينحرف
	# الهدف عن مركز الشاشة. المحاذاة على الشعاع تجعل uv=0.5 عند قدم الزومبي تماماً.
	var z := dir  # محلي +Z نحو الكاميرا
	var x := cam.global_basis.x - z * cam.global_basis.x.dot(z)
	if x.length_squared() < 0.000001:
		x = cam.global_basis.y.cross(z)
	x = x.normalized()
	var y := z.cross(x).normalized()
	global_transform = Transform3D(Basis(x, y, z), pos)


func _camera() -> Camera3D:
	if not is_inside_tree():
		return null
	return get_viewport().get_camera_3d()


## قدم الزومبي = أسفل الكبسولة، مشتقّة من شكل التصادم لا من قيمة ثابتة
## (تعمل سواء كان أصل العقدة عند القلب أم عند القدم)
func _feet_y(t: Node3D) -> float:
	for c in t.get_children():
		var cs := c as CollisionShape3D
		if cs == null:
			continue
		var cap := cs.shape as CapsuleShape3D
		if cap != null:
			return t.global_position.y + cs.position.y - cap.height * 0.5
		return t.global_position.y + cs.position.y
	return t.global_position.y
