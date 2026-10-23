extends Node
## تشخيص تسرّب أثناء القتال: يقتل زومبيًا كثيرًا عبر «موجات» ويقيس نمو العقد/اليتيمة/الذاكرة
## التشغيل: Godot --headless --path <project> res://tests/combat_lag_probe.tscn

func _ready() -> void:
	_run()


func _run() -> void:
	GM.set_state(GM.State.PLAYING)
	var arena: Node = (load("res://scenes/main/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await _wait_frames(3)
	# نجمّد الموجة كي لا تُطلق زومبيًا حقيقيًا (نقيس أثر قتلنا نحن فقط)
	var wm: Node = arena.get_node("WaveManager")
	if "_timer" in wm:
		wm.set("_timer", 99999.0)

	print("=== COMBAT LAG PROBE ===")
	var base_nodes := _count_all(arena)
	var base_orphan := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var base_mem := Performance.get_monitor(Performance.MEMORY_STATIC)
	print("base nodes=%d orphan=%d mem=%d" % [base_nodes, base_orphan, base_mem])

	var scene: PackedScene = load("res://scenes/enemies/ZombieBasic.tscn")
	for wave in range(5):
		var killed := 0
		for i in 30:
			var z: Node = scene.instantiate()
			arena.add_child(z)
			z.global_position = Vector3(randf_range(-8, 8), 0.9, randf_range(-8, 8))
			z.set_physics_process(false)
			z.set_process(false)
			# نقتله مباشرة عبر HealthComponent لتفعيل مسار الموت الكامل
			var h: HealthComponent = z.get_node("Health")
			h.take_damage(99999.0)
			killed += 1
			# محاكاة إرجاع الـPool: نحرّر الزومبي بعد موتّه كي لا يلوّث العدّ (في اللعبจรبي يعود للـPool)
			z.queue_free()
		await _wait_frames(90)  # ننتظر تحرّر المؤثرات (انفجار1.2ث + رذاذ)
		var n := _count_all(arena)
		var o := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		var m := Performance.get_monitor(Performance.MEMORY_STATIC)
		print("wave %d killed=%d nodes=%d(Δ%+d) orphan=%d(Δ%+d) mem=%d(Δ%+d)" % [
			wave + 1, killed, n, n - base_nodes, o, o - base_orphan, m, m - base_mem])

	print("=== FINAL ===")
	print("nodes=%d orphan=%d mem=%d" % [_count_all(arena),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC)])
	get_tree().quit(0)


func _count_all(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count_all(ch)
	return c


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
