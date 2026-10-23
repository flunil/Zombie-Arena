extends Area3D
## رصاصة: تتحرك، تطبّق الضرر — وتدعم انفجارة/سلسلة/اختراق/منطقة سامة حسب إعدادات السلاح

const CHAIN_RANGE: float = 8.0
const ARENA_X: float = 90.0   # حدود المدينة الموسّعة x∈[-44,84] + هامش أمان (كان ±24.4 للساحة القديمة وحدها)
const ARENA_Z: float = 120.0  # z∈[-110,71] + هامش أمان

var direction: Vector3 = Vector3.FORWARD
var speed: float = 30.0
var damage: float = 25.0
var life: float = 2.0
var pierce: int = 0
var explosion_radius: float = 0.0
var chain_targets: int = 0
var poison_radius: float = 0.0
var poison_time: float = 0.0
var poison_dps: float = 0.0
var bullet_color: Color = Color(1, 0.9, 0.85, 1)
var visual_scale: float = 1.0

var _hits: Array[Node3D] = []
var _hit_normal: Vector3 = Vector3.UP  # آخر سطح اصطدم به (لاستدعاء أثر الاصطدام)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visual()


func _physics_process(delta: float) -> void:
	# كشف بالخط بين الإطارين — يمنع النفاذ للطلقات السريعة (الليزر 120م/ث)
	var step: Vector3 = direction * speed * delta
	var to: Vector3 = global_position + step
	# حاجز حدود الساحة: الطلقة لا تخرج أبداً (ولو وُلدت خارج الجدار)
	if _outside_arena(global_position):
		queue_free()
		return
	if _outside_arena(to):
		FxLibrary.spawn_sparks(global_position, -direction)  # شرارات جدار GPU
		queue_free()
		return
	var query := PhysicsRayQueryParameters3D.create(global_position, to, 3)  # طبقات: عالم + أعداء
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]
		_hit_normal = hit.get("normal", Vector3.UP)
		var collider := hit.get("collider") as Node3D
		if collider != null:
			_on_body_entered(collider)
		if not is_queued_for_deletion():
			global_position = to  # اختراق: تابع الطريق دون تدمير
	else:
		global_position = to
	life -= delta
	if life <= 0.0:
		if explosion_radius > 0.0:
			_explode()
		queue_free()


func _outside_arena(p: Vector3) -> bool:
	return absf(p.x) > ARENA_X or absf(p.z) > ARENA_Z


func _on_body_entered(body: Node3D) -> void:
	if body is Node3D and body in _hits:
		return
	var enemy_hit: bool = body.is_in_group("enemies")
	if enemy_hit:
		FxLibrary.spawn_impact(global_position, _hit_normal, true)  # رذاذ أخضر GPU
	else:
		FxLibrary.spawn_sparks(global_position, _hit_normal)  # شرارات ذهبية GPU
	if body.has_method("take_damage"):
		body.take_damage(damage, direction)
		StatsTracker.record_hit()
		if UpgradeManager.roll_freeze() and body.has_method("apply_slow"):
			body.apply_slow(0.4, 2.0)  # ترقية Freeze
			FxLibrary._spawn(FxLibrary._flash_sphere(  # وميض أزرق يُظهر التجميد
				body.global_position + Vector3.UP * 0.9, 0.65, Color(0.4, 0.8, 1.0), 0.35))
		_hits.append(body)
		if chain_targets > 0:
			_chain_from(body)
		if poison_radius > 0.0:
			_spawn_hazard()
		if explosion_radius > 0.0:
			_explode()
			return
		if pierce > 0:
			pierce -= 1
			return  # يخترق ويستمر
	queue_free()


## انفجار: ضرر دائري لجميع الأعداء + مشهد ExplosionVFX + Hit-stop خفيف
func _explode() -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = explosion_radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 2  # طبقة الأعداء
	query.collide_with_bodies = true
	var results: Array[Dictionary] = space.intersect_shape(query, 32)
	for r in results:
		var b: Node = r.get("collider")
		if b != null and b.has_method("take_damage"):
			b.take_damage(damage)
	FxLibrary.spawn_explosion(global_position, explosion_radius)
	FxLibrary.hit_stop(0.04)  # Hit-stop خفيف مع الانفجار
	queue_free()


## سلسلة كهربائية: أقرب الأعداء حتى بلوغ العدد المطلوب
func _chain_from(origin_body: Node3D) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = CHAIN_RANGE
	var from_pos: Vector3 = origin_body.global_position
	var chained: int = 1
	while chained < chain_targets:
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(), from_pos)
		query.collision_mask = 2
		query.collide_with_bodies = true
		var results: Array[Dictionary] = space.intersect_shape(query, 16)
		var next_body: Node3D = null
		for r in results:
			var b: Node3D = r.get("collider") as Node3D
			if b == null or b == origin_body or b in _hits:
				continue
			if b.has_method("take_damage"):
				next_body = b
				break
		if next_body == null:
			return
		next_body.take_damage(damage * 0.7)
		_hits.append(next_body)
		from_pos = next_body.global_position
		chained += 1


## منطقة سامة عند الاصطدام (SmokeLauncher)
func _spawn_hazard() -> void:
	var zone: Area3D = Area3D.new()
	zone.set_script(load("res://scripts/weapons/hazard_zone.gd"))
	zone.radius = poison_radius
	zone.lifetime = poison_time
	zone.dps = poison_dps
	get_tree().current_scene.add_child(zone)
	zone.global_position = global_position


## لون/حجم مميز لكل سلاح (المادة تُنسخ لكل طلقة)
func _apply_visual() -> void:
	if not is_equal_approx(visual_scale, 1.0):
		scale = Vector3.ONE * visual_scale
	var mesh_node: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		return
	var src: StandardMaterial3D = mesh_node.material_override as StandardMaterial3D
	if src == null:
		return
	var mat: StandardMaterial3D = src.duplicate()
	mat.albedo_color = bullet_color
	mat.emission = bullet_color
	mesh_node.material_override = mat
