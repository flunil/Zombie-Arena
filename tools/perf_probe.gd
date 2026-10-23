extends Node
## قرص قياس الأداء: يفتح الساحة ويجمع FPS/أوقات معالجة/วาด/عقد/أعداء
## يتجاوز شاشة الترقية تلقائيًا (begin_rest) ويقف عند GameOver — للتطوير فقط
## أعلام A/B عبر user args بعد -- : no-outline / no-shadow / no-city / no-sun

const SAMPLE_SEC := 32


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var no_outline := "no-outline" in args
	var no_shadow := "no-shadow" in args
	var no_city := "no-city" in args
	var no_sun := "no-sun" in args
	print("PERF_ARGS outline_off=", no_outline, " shadow_off=", no_shadow, " city_off=", no_city, " sun_off=", no_sun)
	var packed := load("res://scenes/main/Arena.tscn") as PackedScene
	if packed == null:
		print("PERF_FAIL: cannot load Arena.tscn")
		get_tree().quit(1)
		return
	var arena := packed.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	if no_outline:
		var oq := arena.get_node_or_null("Player/Camera3D/OutlineQuad")
		if oq == null:
			oq = arena.find_child("OutlineQuad", true, false)
		if oq != null:
			oq.visible = false
			print("PERF applied: outline hidden")
		else:
			print("PERF warn: OutlineQuad not found")
	if no_shadow:
		var sun := arena.get_node_or_null("Sun") as DirectionalLight3D
		if sun != null:
			sun.shadow_enabled = false
			print("PERF applied: sun shadow off")
	if no_sun:
		var sun2 := arena.get_node_or_null("Sun") as DirectionalLight3D
		var fill := arena.get_node_or_null("Fill") as DirectionalLight3D
		if sun2 != null:
			sun2.visible = false
		if fill != null:
			fill.visible = false
		print("PERF applied: lights hidden")
	if no_city:
		for city_name in ["Node3D", "Node3D2", "Node3D3", "Node3D4"]:
			var city := arena.get_node_or_null(city_name) as Node3D
			if city != null:
				city.visible = false
		print("PERF applied: city containers hidden")
	# لاعب لا يموت أثناء القياس (معدلات عادلة عبر كل السيناريوهات)
	var player := arena.get_node_or_null("Player")
	if player != null:
		var hp := player.get_node_or_null("Health")
		if hp != null:
			hp.set("max_health", 1000000.0)
			if hp.has_method("reset_health"):
				hp.call("reset_health")
			print("PERF applied: player invincible")

	var fps_all: Array[float] = []
	var draws_all: Array[float] = []
	var proc_all: Array[float] = []
	var worst_fps := 9999.0
	var worst_t := -1
	for t in SAMPLE_SEC:
		await get_tree().create_timer(1.0).timeout
		if GM != null and GM.is_game_over():
			print("PERF note: game_over at t=", t)
			break
		# تجاوز شاشة الترقية: راحة فورية حتى تستمر الموجات
		var wm := get_tree().get_first_node_in_group("wave_manager")
		if wm != null and wm.get("get_state") != null and wm.call("get_state") == "upgrade":
			wm.call("begin_rest")
		var fps := Performance.get_monitor(Performance.TIME_FPS)
		var proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var phys_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		var vmem_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)
		var enemies := get_tree().get_nodes_in_group("enemies").size()
		var wave := 0
		if wm != null:
			wave = int(wm.get("wave"))
		fps_all.append(fps)
		draws_all.append(draws)
		proc_all.append(proc_ms)
		if fps < worst_fps:
			worst_fps = fps
			worst_t = t
		print("PERF t=%d wave=%d enemies=%d fps=%.1f proc=%.1fms phys=%.1fms draws=%.0f prims=%.0f nodes=%.0f vmem=%.0fMB" % [
			t, wave, enemies, fps, proc_ms, phys_ms, draws, prims, nodes, vmem_mb,
		])
	if fps_all.is_empty():
		print("PERF_FAIL: no samples")
		get_tree().quit(1)
		return
	var avg_fps := 0.0
	var avg_draws := 0.0
	var avg_proc := 0.0
	for i in fps_all.size():
		avg_fps += fps_all[i]
		avg_draws += draws_all[i]
		avg_proc += proc_all[i]
	var n := float(fps_all.size())
	print("PERF_SUMMARY avg_fps=%.1f worst_fps=%.1f(worst_t=%d) avg_draws=%.0f avg_proc=%.1fms samples=%d" % [
		avg_fps / n, worst_fps, worst_t, avg_draws / n, avg_proc / n, fps_all.size(),
	])
	get_tree().quit(0)
