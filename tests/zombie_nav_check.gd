extends Node
## تشخيص حيّ: قلتشات الزومبي (تعلق في البيوت + سقوط تحت الأرض)
## يقرأ الشبكة، يفحص تصادم المباني، وزومبي تجريبي قرب بيت

var _fails: int = 0


func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _ready() -> void:
	await get_tree().process_frame
	var arena_ps := load("res://scenes/main/Arena.tscn") as PackedScene
	check(arena_ps != null, "تحميل Arena.tscn")
	if arena_ps == null:
		_finish()
		return
	var arena := arena_ps.instantiate()
	add_child(arena)
	# انتظارخبake الشبكة (call_deferred في _ready + bake)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout

	_test_navmesh(arena)
	_test_buildings_ground(arena)
	await _test_zombie_at_building(arena)
	await _test_zombie_falling(arena)
	_finish()


func _finish() -> void:
	print("CHECK_RESULT: ", "ALL_PASS" if _fails == 0 else "FAIL_COUNT=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


## الشبكة: عدد المضلعات + النطاق + هل تغطي الأرض
func _test_navmesh(arena: Node) -> void:
	var nav := arena.get_node_or_null("NavRegion") as NavigationRegion3D
	check(nav != null, "NavRegion موجود")
	if nav == null:
		return
	var nm: NavigationMesh = nav.navigation_mesh
	check(nm != null, "navigation_mesh معيّن")
	if nm == null:
		return
	print("DIAG nav polys=", nm.polygons.size(), " cell=", nm.cell_size,
		" agent_r=", nm.agent_radius, " agent_h=", nm.agent_height,
		" cell_h=", nm.cell_height)
	check(nm.polygons.size() > 50, "شبكة الملاحة فيها مضلعات (%d)" % nm.polygons.size())
	# نطاق الشبكة: هل يغطي منطقة اللعب x=[-23,23] z=[-23,23]؟
	var map_rid: RID = nav.get_world_3d().navigation_map
	var regions: Array = NavigationServer3D.map_get_regions(map_rid)
	check(regions.size() > 0, "خريطة الملاحة فيها مناطق (%d)" % regions.size())
	# أقرب نقطة لمركز الساحة
	var center := NavigationServer3D.map_get_closest_point(map_rid, Vector3(0, 1, 0))
	print("DIAG closest to (0,1,0) = ", center)
	check(center.distance_to(Vector3(0, 0.5, 0)) < 3.0, "الشبكة قريبة من مركز الأرض (%.2f)" % center.distance_to(Vector3(0, 0.5, 0)))


## المباني: هل تلامس الأرض؟ هل تصادمها يحجب الشبكة؟
func _test_buildings_ground(arena: Node) -> void:
	var n3d2 := arena.get_node_or_null("Node3D2")
	check(n3d2 != null, "Node3D2 (المباني) موجود")
	if n3d2 == null:
		return
	var floating := 0
	var grounded := 0
	var no_collision := 0
	for b in n3d2.get_children():
		var shapes := _find_collision_shapes(b)
		if shapes.is_empty():
			no_collision += 1
			print("DIAG no-collision building: ", b.name)
			continue
		var lowest := INF
		for cs in shapes:
			var s := cs.shape as BoxShape3D
			if s != null:
				# أدنى نقطة للصندوق في العالم
				var cy := cs.global_position.y
				lowest = minf(lowest, cy - s.size.y * 0.5)
			else:
				# trimesh: نستخدم أدنى نقطة AABB للـ StaticBody
				var sb := cs.get_parent() as StaticBody3D
				if sb != null:
					lowest = minf(lowest, sb.global_position.y)
		if lowest > 2.0:
			floating += 1
			print("DIAG FLOATING building: ", b.name, " lowest_y=", lowest)
		else:
			grounded += 1
	print("DIAG buildings: grounded=", grounded, " floating=", floating, " no_collision=", no_collision)
	check(floating == 0, "لا مبنى عائم فوق الأرض (%d عائم)" % floating)
	check(no_collision == 0, "كل المباني لها تصادم (%d بلا)" % no_collision)


## زومبي تجريبي قرب بيت: هل يعلق أم يصل؟
func _test_zombie_at_building(arena: Node) -> void:
	var n3d2 := arena.get_node_or_null("Node3D2")
	if n3d2 == null:
		return
	# ابحث عن house_05
	var house := n3d2.get_node_or_null("house_05")
	if house == null:
		house = n3d2.get_node_or_null("restaurant")
	if house == null:
		print("DIAG no house found for zombie test")
		return
	var house_pos: Vector3 = house.global_position
	print("DIAG house at ", house_pos)
	# أنشئ زومبي قرب البيت (6م بعيدًا)
	var zb_ps := load("res://scenes/enemies/ZombieBasic.tscn") as PackedScene
	if zb_ps == null:
		return
	var zb := zb_ps.instantiate()
	add_child(zb)
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var spawn := house_pos + Vector3(6, 0.9, 0)
	spawn.y = 0.9
	zb.global_position = spawn
	if player != null:
		zb.set("_player", player)
	# تتبّع لمدة 3 ثوانٍ
	var start_pos: Vector3 = zb.global_position
	for i in 18:
		await get_tree().physics_frame
		var p: Vector3 = zb.global_position
		if i % 6 == 0:
			print("DIAG zb t=%.1f pos=(%.1f,%.2f,%.1f) vel=(%.1f,%.1f,%.1f)" % [
				i * get_physics_process_delta_time(), p.x, p.y, p.z,
				zb.velocity.x, zb.velocity.y, zb.velocity.z])
	# هل سقط تحت الأرض؟
	var final: Vector3 = zb.global_position
	check(final.y > -1.0, "الزومبي لم يسقط تحت الأرض (y=%.2f)" % final.y)
	# هل تحرّك (ليس عالقًا تمامًا)?
	var moved := Vector2(final.x - start_pos.x, final.z - start_pos.z).length()
	print("DIAG zb moved=", moved, "m from ", start_pos, " to ", final)
	check(moved > 0.5, "الزومبي تحرّك (%.2fم) — ليس عالقًا تمامًا" % moved)
	zb.queue_free()
	await get_tree().process_frame


## زومبي فوق فجوة: هل تسقط ثم تُستعاد؟
func _test_zombie_falling(arena: Node) -> void:
	var zb_ps := load("res://scenes/enemies/ZombieBasic.tscn") as PackedScene
	if zb_ps == null:
		return
	var zb := zb_ps.instantiate()
	add_child(zb)
	await get_tree().process_frame
	# ضعه فوق الأرض مباشرة ثم تحت الأرض لاختبار الاستعادة
	zb.global_position = Vector3(0, 0.9, 0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		zb.set("_player", player)
	# انتظر حتى يستقر على الأرض
	for i in 30:
		await get_tree().physics_frame
	var on_ground: Vector3 = zb.global_position
	print("DIAG zb landed y=%.2f" % on_ground.y)
	check(on_ground.y > -0.5 and on_ground.y < 2.0, "الزومبي يستقر فوق الأرض (y=%.2f)" % on_ground.y)
	zb.queue_free()
	await get_tree().process_frame


func _find_collision_shapes(n: Node) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	if n is CollisionShape3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_collision_shapes(c))
	return out
