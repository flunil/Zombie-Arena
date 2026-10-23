extends Node
## اختبار دمج انفجار LegionGames في موت Exploder:
## spawn_legion_explosion يضيف ExplosionVFX للمشهد ويشغّله، والانفجار لا يتبع الزومبي للـ Pool.

const EPS := 0.01


func _ready() -> void:
	print("exploder_vfx_check START")
	var fails := 0

	# 1) FxLibrary.spawn_legion_explosion: عقدة في مجموعة fx عند الموضع + الأنظمة الثلاثة شغّالة
	FxLibrary.spawn_legion_explosion(Vector3(5, 1, 7), 2.5)
	await get_tree().process_frame
	var vfx := _find_vfx()
	if vfx != null and vfx.global_position.distance_to(Vector3(5, 1, 7)) < EPS:
		print("PASS lib_spawn_pos")
	else:
		print("FAIL lib_spawn_pos")
		fails += 1
	if vfx != null and _all_emitting(vfx):
		print("PASS lib_emitting")
	else:
		print("FAIL lib_emitting")
		fails += 1
	if vfx != null and vfx.get_node_or_null("Audio") is AudioStreamPlayer3D:
		print("PASS lib_scene")
	else:
		print("FAIL lib_scene")
		fails += 1
	if vfx != null:
		vfx.queue_free()

	# 2) Exploder ينفجر عبر المسار الحقيقي (health.died → _on_died → _explode)
	var z: Node3D = load("res://scenes/enemies/ZombieExploder.tscn").instantiate()
	add_child(z)
	z.global_position = Vector3(3, 0, 4)
	await get_tree().process_frame
	z.get_node("Health").take_damage(99999.0)  # قتل مباشر — يستدعي _on_died كاملًا
	await get_tree().process_frame
	var vfx2 := _find_vfx()
	if vfx2 != null and vfx2.global_position.distance_to(Vector3(3, 0, 4)) < EPS:
		print("PASS death_spawn_pos")
	else:
		print("FAIL death_spawn_pos")
		fails += 1
	if vfx2 != null and _all_emitting(vfx2):
		print("PASS death_emitting")
	else:
		print("FAIL death_emitting")
		fails += 1

	# 3) الأثر مستقل عن الزومبي: بعد موت الزومبي يستمر الأثر (لا child للزومبي)
	if vfx2 != null and not (vfx2.get_parent() is CharacterBody3D):
		print("PASS independent_parent")
	else:
		print("FAIL independent_parent")
		fails += 1

	# 4) ضرر الانفجار 40 على زومبي بديل قريب (CharacterBody3D + Health — intersect_shape يضرب الأجساد فقط)
	var dummy := CharacterBody3D.new()
	dummy.collision_layer = 6  # طبقة زومبي/لاعب (2+4) — نفس mask انفجار Exploder
	var cshape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.4
	cshape.shape = sph
	dummy.add_child(cshape)
	var hp: HealthComponent = load("res://scripts/systems/health_component.gd").new()
	hp.name = "Health"
	hp.max_health = 100.0
	dummy.add_child(hp)
	add_child(dummy)
	dummy.global_position = Vector3(3.6, 0, 4)
	await get_tree().process_frame
	hp.reset_health()  # بعد _ready (الذي يضبط health=max_health مرة أخرى)
	# exploder مات بالفعل أعلاه — نستخدم نسخة ثانية مستقلة على نفس الموضع تقريبًا
	var z2: Node3D = load("res://scenes/enemies/ZombieExploder.tscn").instantiate()
	add_child(z2)
	z2.global_position = Vector3(4.5, 0, 4)
	await get_tree().process_frame
	z2.get_node("Health").take_damage(99999.0)
	await get_tree().process_frame
	if hp.health < 100.0:
		print("PASS damage_nearby health=", hp.health)
	else:
		print("FAIL damage_nearby")
		fails += 1

	if fails == 0:
		print("exploder_vfx_check ALL_PASS")
	else:
		print("exploder_vfx_check FAILED count=", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _find_vfx() -> Node3D:
	for n in get_tree().get_nodes_in_group("fx"):
		if n is Node3D and n.has_method("explode") \
				and n.get_node_or_null("Debris") != null:
			return n as Node3D
	return null


func _all_emitting(vfx: Node3D) -> bool:
	for kind in ["Debris", "Fire", "Smoke"]:
		var p := vfx.get_node_or_null(kind) as GPUParticles3D
		if p == null or not p.emitting:
			return false
	return true
