extends Node
## اختبار: نقاط وسط المباني صارت محظورة (فحص السقف) والشوارع بقيت حرة


func _ready() -> void:
	var arena: Node = load("res://scenes/main/Arena.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame  # تسجيل التصادم في الفيزياء
	await get_tree().physics_frame
	var wm: Node = arena.get_node_or_null("WaveManager")
	var nd: Node = arena.get_node_or_null("Node3D2")
	if wm == null or nd == null:
		print("[SPAWNCHK] FAIL missing wm/nd")
		get_tree().quit(1)
		return
	var checked := 0
	var blocked_ok := 0
	var leaks: Array[String] = []
	for b in nd.get_children():
		if not (b is MeshInstance3D):
			continue
		# كل مبنى يجب أن يحوي StaticBody ليعمل فحص الفيزياء
		var has_body := false
		for c in b.get_children():
			if c is StaticBody3D:
				has_body = true
		if not has_body:
			continue
		checked += 1
		var p := Vector3(b.position.x, 0.9, b.position.z)
		if wm.call("_point_blocked", p):
			blocked_ok += 1
		else:
			leaks.append(b.name)
	print("[SPAWNCHK] buildings=", checked, " blocked=", blocked_ok, " leaks=", leaks)
	# الشوارع المفتوحة: أخذ 4 نقاط ممر احتياطية من الكود
	var lanes := [Vector3(0, 0.9, -21), Vector3(0, 0.9, 21), Vector3(21, 0.9, 0), Vector3(-21, 0.9, 0)]
	var free_lanes := 0
	for lp in lanes:
		if not wm.call("_point_blocked", lp):
			free_lanes += 1
	print("[SPAWNCHK] free_lanes=", free_lanes)
	# عينة عشوائية داخل منطقة الظهور: نسبة المحظور يجب ألا تكون 100%
	var rnd_blocked := 0
	for i in range(40):
		var rp := Vector3(randf_range(-23, 23), 0.9, randf_range(-23, 23))
		if wm.call("_point_blocked", rp):
			rnd_blocked += 1
	print("[SPAWNCHK] random_blocked=", rnd_blocked, "/40")
	var pass_: bool = checked > 0 and leaks.is_empty() and free_lanes >= 1 and rnd_blocked < 40
	print("[SPAWNCHK] ", "ALL_PASS" if pass_ else "FAIL")
	get_tree().quit(0 if pass_ else 1)
