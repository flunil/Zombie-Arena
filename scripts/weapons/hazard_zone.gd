extends Area3D
class_name HazardZone
## منطقة سامة مؤقتة (SmokeLauncher): تضر الأعداء الداخلين حتى انتهاء مهلتها

var radius: float = 5.0
var lifetime: float = 5.0
var dps: float = 5.0

var _tick: float = 0.5


func _ready() -> void:
	collision_layer = 0  # لا يعوق المشي
	collision_mask = 2    # طبقة الأعداء فقط
	monitoring = true
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	cs.shape = sphere
	add_child(cs)
	_add_visual()


func _physics_process(delta: float) -> void:
	lifetime -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		for body in get_overlapping_bodies():
			if body.has_method("take_damage"):
				body.take_damage(dps * 0.5)  # نصف ثانية × 5/ث = 5 ضرر
	if lifetime <= 0.0:
		queue_free()


## قبة خضراء شفافة بصرية بسيطة
func _add_visual() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.9, 0.4, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)
