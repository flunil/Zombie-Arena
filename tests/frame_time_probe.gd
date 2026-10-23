extends Node
## يقيس زمن الإطار الفعلي عند فتح قائمة التطويرات — قبل القتال وبعده (السبب الحقيقي للإحساس بالبطء)
## التشغيل: Godot --headless --path <project> res://tests/frame_time_probe.tscn

var _deltas: Array[float] = []
var _measuring := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # نقيس حتى أثناء إيقاف اللعب بالقائمة
	_run()


func _process(delta: float) -> void:
	if _measuring:
		_deltas.append(delta)


func _run() -> void:
	GM.set_state(GM.State.PLAYING)
	var arena: Node = (load("res://scenes/main/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await _wait_frames(3)
	var wm: Node = arena.get_node("WaveManager")
	if "_timer" in wm:
		wm.set("_timer", 99999.0)

	var usel: Node = arena.get_node("HUD").find_child("UpgradeSelection", true, false)
	print("=== FRAME TIME PROBE ===")

	# (1) فتح القائمة في مشهد نظيف (بلا قتال)
	await _measure_menu(usel, "menu-clean")

	# (2) قتل زومبي كثير (محاكاة موجات) لبناء الذاكرة/المؤثرات
	var scene: PackedScene = load("res://scenes/enemies/ZombieBasic.tscn")
	for wave in range(5):
		for i in 30:
			var z: Node = scene.instantiate()
			arena.add_child(z)
			z.global_position = Vector3(randf_range(-8, 8), 0.9, randf_range(-8, 8))
			z.set_physics_process(false)
			z.set_process(false)
			var h: HealthComponent = z.get_node("Health")
			h.take_damage(99999.0)
			z.queue_free()
		await _wait_frames(60)

	# (3) فتح القائمة بعد5 موجات قتال
	await _measure_menu(usel, "menu-after-combat")

	print("=== FINAL mem=%d ===" % Performance.get_monitor(Performance.MEMORY_STATIC))
	get_tree().quit(0)


func _measure_menu(usel: Node, label: String) -> void:
	usel.call("_show_options")
	await _wait_frames(3)  # تستقر القائمة (البكرة تدور لكن قياس الإطار يشملها)
	_deltas.clear()
	_measuring = true
	await _wait_frames(120)  # ≈2 ثانية قياس
	_measuring = false
	usel.call("_reset_open_state")
	usel.visible = false
	get_tree().paused = false
	var avg := _avg(_deltas)
	var mx := _max(_deltas)
	print("%s: frames=%d avg=%.2fms max=%.2fms" % [label, _deltas.size(), avg * 1000.0, mx * 1000.0])
	await _wait_frames(5)


func _avg(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()


func _max(a: Array[float]) -> float:
	var m := 0.0
	for v in a:
		if v > m:
			m = v
	return m


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
