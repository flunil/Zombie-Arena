extends Node
## اختبار الكاميرا: مبنى وهمي بين اللاعب والكاميرا يُخفى، وبعده يُعاد ظهوره


func _ready() -> void:
	var arena: Node = load("res://scenes/main/Arena.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	var player: Node3D = arena.get_node_or_null("Player") as Node3D
	var cam: Camera3D = arena.get_node_or_null("Player/Camera3D") as Camera3D
	if player == null or cam == null:
		print("[CAMOCC] FAIL no player/camera")
		get_tree().quit(1)
		return
	# انقل اللاعب لمكان مفتوح ودع الكاميرا تلتقط (تعقب بتنعيم)
	player.global_position = Vector3(0, 0.9, 0)
	await get_tree().create_timer(1.0).timeout
	# صندوق وهمي يقطع خط النظر: قاعدته فوق مستوى رأس اللاعب (يبقى خارج بداية الشعاع)
	var mid := (player.global_position + cam.global_position) * 0.5
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10, 26, 10)
	mi.mesh = box
	mi.position = Vector3(mid.x, mid.y + 9.0, mid.z)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	cs.shape = shape
	body.add_child(cs)
	mi.add_child(body)
	arena.add_child(mi)
	await get_tree().physics_frame  # تسجيل تصادم الصندوق في الفيزياء
	await get_tree().physics_frame
	# تشخيص: هل يرى الشعاع الصندوق أصلًا؟
	var dbg_from := player.global_position + Vector3(0, 1.2, 0)
	var dbg_rq := PhysicsRayQueryParameters3D.create(dbg_from, cam.global_position, 1)
	var dbg_hit: Dictionary = arena.get_world_3d().direct_space_state.intersect_ray(dbg_rq)
	var dbg_name := "-"
	if not dbg_hit.is_empty():
		dbg_name = String((dbg_hit["collider"] as Node).name)
	print("[CAMOCC] cam=", cam.global_position, " player=", player.global_position,
			" manual_hit=", not dbg_hit.is_empty(), " hit_name=", dbg_name)
	# تشخيص2: ضربة رأسية على الصندوق — هل تصادمه مسجل أصلًا؟
	var down_rq := PhysicsRayQueryParameters3D.create(
			Vector3(mi.position.x, 40.0, mi.position.z),
			Vector3(mi.position.x, -5.0, mi.position.z), 1)
	var down_hit: Dictionary = arena.get_world_3d().direct_space_state.intersect_ray(down_rq)
	var down_y := -999.0
	if not down_hit.is_empty():
		down_y = (down_hit["position"] as Vector3).y
	print("[CAMOCC] box_pos=", mi.position, " layer=", body.collision_layer,
			" down_hit=", not down_hit.is_empty(), " down_y=", down_y)
	cam.call("_update_occluders")
	cam.call("_update_occluders")  # عدّاد التغطية = 2 → إخفاء
	var hidden1: bool = not mi.visible
	print("[CAMOCC] hidden_while_between=", hidden1)
	# أبعد الصندوق — يجب إعادة الإظهار فورًا
	mi.position = Vector3(500, 15, 500)
	await get_tree().physics_frame
	await get_tree().physics_frame
	cam.call("_update_occluders")
	var restored: bool = mi.visible
	print("[CAMOCC] restored_when_clear=", restored)
	# أعِد الحجب — يُخفى ثانية (لا يتجمد الـ state)
	mi.position = Vector3(mid.x, mid.y + 9.0, mid.z)
	await get_tree().physics_frame
	await get_tree().physics_frame
	cam.call("_update_occluders")
	cam.call("_update_occluders")
	var rehidden: bool = not mi.visible
	print("[CAMOCC] rehidden=", rehidden)
	var ok: bool = hidden1 and restored and rehidden
	print("[CAMOCC] ", "ALL_PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
