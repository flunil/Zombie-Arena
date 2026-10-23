extends "res://scripts/enemies/zombie_base.gd"
## زومبي متفجر: ينفجر عند الموت ويضر اللاعب والزومبي على قطر 2.5م (40 ضرر)

const EXPLODE_RADIUS: float = 2.5
const EXPLODE_DAMAGE: float = 40.0


func _has_own_explosion() -> bool:
	return true  # انفجاره الخاص — لا يُضاف انفجار موت فوقه


func _on_died() -> void:
	_explode()  # أولاً — قبل الإرجاع للـ Pool
	super._on_died()


func _explode() -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = EXPLODE_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 2 + 4  # أعداء + لاعب (bitmask طبقتهما)
	query.collide_with_bodies = true
	var results: Array[Dictionary] = space.intersect_shape(query, 32)
	for r in results:
		var b: Node = r.get("collider")
		if b == null or b == self:
			continue
		if b.has_method("take_damage"):
			b.take_damage(EXPLODE_DAMAGE)
		else:
			var h: Node = b.get_node_or_null("Health")
			if h != null and h.has_method("take_damage"):
				h.take_damage(EXPLODE_DAMAGE)
	# أثر LegionGames الثلاثي (Debris+Fire+Smoke) + صوت + اهتزاز — يُضاف للمشهد لا للزومبي
	# (الزومبي يعود للـ Pool ويُخفى — الأثر يجب أن يبقى مستقلاً حتى اكتماله ثم queue_free)
	FxLibrary.spawn_legion_explosion(global_position, EXPLODE_RADIUS)
