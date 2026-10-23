extends Node
## قياس الأداء بحمولات متزايدة: فارغة → موجة1 (32) → حشد (~112) → حشد كبير (~250)
## يطبع سطر [PERFPROBE] لكل مرحلة — يُشغَّل نافذةً لقياس GPU الحقيقي وheadless للـCPU
## ملاحظة: يلغي الموجة التلقائية ويطوّي صحة اللاعب وقت القياس فقط

var _lines: Array[String] = []


func _ready() -> void:
	var arena_ps := load("res://scenes/main/Arena.tscn") as PackedScene
	if arena_ps == null:
		print("CHECK_RESULT: FAIL arena load")
		get_tree().quit(1)
		return
	var arena := arena_ps.instantiate()
	add_child(arena)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var wm := arena.get_node_or_null("WaveManager")
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if wm == null or player == null:
		print("CHECK_RESULT: FAIL missing wm/player")
		get_tree().quit(1)
		return
	var hp := player.get_node_or_null("Health") as HealthComponent
	if hp != null:
		hp.max_health = 1000000.0  # لا يموت أثناء الهجوم الجماعي المقيس
		hp.health = 1000000.0
	wm.set("_timer", 9999.0)  # منع الموجة التلقائية — نقيس "فارغًا" أولًا
	GM.set_state(GM.State.PLAYING)  # تظهر حلقة المدى والواجهة كما في اللعب الفعلي
	await get_tree().create_timer(1.5).timeout  # استقرار التحميل + خبake الشبكة
	var rr_dbg := player.get_node_or_null("RangeCircle/RingReceiver") as MeshInstance3D
	if rr_dbg != null and rr_dbg.mesh is PlaneMesh:
		print("[PERFPROBE] receiver_size=", (rr_dbg.mesh as PlaneMesh).size)
	await _measure("empty", 2.0)
	await _start_wave(wm, 0)
	await _measure("wave1_32", 5.0)
	await _start_wave(wm, 4)   # +80 فوق ما تبقّى ≈112 حيًا
	await _measure("mid_112", 6.0)
	await _start_wave(wm, 9)   # +140 ≈250 حيًا
	await _measure("big_250", 8.0)
	await _diag_big(arena)  # عزل تكلفة الظلال وتمرير outline عند الحشد
	print("[PERFPROBE] RESULT_BEGIN")
	for l in _lines:
		print("[PERFPROBE] ", l)
	print("[PERFPROBE] RESULT_END")
	print("CHECK_RESULT: ALL_PASS")
	get_tree().quit(0)


## تشخيص عند الحشد (بلا تغييرات مواد/بيئة تُسبّب إعادة ترجمة): outline ثم أشرطة الصحة
func _diag_big(arena: Node) -> void:
	var stashed: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node
		if n == null:
			continue
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var mii := mi as MeshInstance3D
			var m := mii.material_override
			if m == null:
				m = mii.get_active_material(0)
			if m is ShaderMaterial and (m as ShaderMaterial).next_pass != null:
				stashed.append([m, (m as ShaderMaterial).next_pass])
				(m as ShaderMaterial).next_pass = null
	await _measure("diagbig_nooutline", 5.0)
	for pair in stashed:
		(pair[0] as ShaderMaterial).next_pass = pair[1]
	await get_tree().process_frame
	await _measure("diagbig_outline_on", 5.0)  # B: عودة التكلفة؟
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node
		if n == null:
			continue
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var mii := mi as MeshInstance3D
			var m := mii.material_override
			if m == null:
				m = mii.get_active_material(0)
			if m is ShaderMaterial and (m as ShaderMaterial).next_pass != null:
				if not stashed.any(func(pair): return pair[0] == m):
					stashed.append([m, (m as ShaderMaterial).next_pass])
				(m as ShaderMaterial).next_pass = null
	await _measure("diagbig_nooutline2", 5.0)  # A2: تراجع ثانٍ = حسم السببية
	# اختبار الدقة الديناميكية: هل تخفض تكلفة الحشد بوضوح؟ (قرار: تكيّف تلقائي مع البطء)
	get_viewport().scaling_3d_scale = 0.55
	await get_tree().process_frame
	await _measure("diagbig_scale055", 5.0)
	get_viewport().scaling_3d_scale = 0.7
	await get_tree().process_frame
	await _measure("diagbig_scale070", 5.0)


## بدء موجة مضبوط + إلغاء أي بطء زمني من ترقيات حفظ المستخدم (TimeSlow)
func _start_wave(wm: Node, wave_num: int) -> void:
	wm.set("wave", wave_num)
	wm.call("_start_next_wave")
	Engine.time_scale = 1.0
	get_tree().paused = false  # شاشة الترقيات توقف المشهد — نقيس لعبة حيّة دائمًا
	await get_tree().physics_frame


func _measure(phase: String, dur: float) -> void:
	var frames := 0
	var sum := 0.0
	var mx := 0.0
	var proc_sum := 0.0
	var phys_sum := 0.0
	var _dt_all: Array[float] = []
	# تلميتر كل ثانية: يربط فترات البطء بأحداث مشهدية محددة
	var b_start := Time.get_ticks_usec()
	var b_dt: Array[float] = []
	var b_dust0 := FxLibrary.dust_demand
	var b_n := 0
	var t0 := Time.get_ticks_usec()
	var last := t0
	while (Time.get_ticks_usec() - t0) < int(dur * 1000000.0):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000.0
		last = now
		frames += 1
		sum += dt
		_dt_all.append(dt)
		mx = maxf(mx, dt)
		proc_sum += Performance.get_monitor(Performance.TIME_PROCESS)
		phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		b_dt.append(dt)
		b_n += 1
		get_tree().paused = false  # حماية من أي إيقاف أثناء القياس (ترقيات/موجة مق cleared)
		if GM.state == GM.State.WAVE_CLEARED:
			GM.set_state(GM.State.PLAYING)
		if (now - b_start) >= 1000000:
			b_dt.sort()
			var fx_e := 0
			var fx_t := 0
			var batched := 0
			var far := 0
			var total := 0
			var mv := 0
			for e in get_tree().get_nodes_in_group("enemies"):
				total += 1
				if e.get("_batched") == true:
					batched += 1
				if e.get("_lod_far") == true:
					far += 1
				var vel: Variant = e.get("velocity")
				if vel is Vector3 and (vel as Vector3).length() > 1.0:
					mv += 1
			for f in get_tree().get_nodes_in_group("fx"):
				fx_t += 1
				var fp := f as GPUParticles3D
				if fp != null and fp.emitting:
					fx_e += 1
			var labels := get_tree().root.find_children("*", "Label3D", true, false).size()
			var dust_rate := FxLibrary.dust_demand - b_dust0
			print("[PERFPROBE] bucket %s med=%.1fms max=%.1f fx=%d/%d labels=%d batched=%d far=%d/%d mv=%d dust=%d/s" % [
				phase, b_dt[b_n / 2], b_dt[b_n - 1], fx_e, fx_t, labels, batched, far, total, mv, dust_rate])
			b_start = now
			b_dt = []
			b_n = 0
			b_dust0 = FxLibrary.dust_demand
	if frames == 0:
		frames = 1
	var n := float(frames)
	_dt_all.sort()
	var median := _dt_all[int(frames / 2)]
	var enemies := get_tree().get_nodes_in_group("enemies").size()
	var vis := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node3D
		if en != null and en.visible:
			vis += 1
	var s := "%s: enemies=%d/%d avg=%.1fms med=%.1fms max=%.1f proc=%.2fms phys=%.2fms fps=%.0f draws=%d nodes=%d" % [
		phase, vis, enemies, sum / n, median, mx, proc_sum / n, phys_sum / n,
		Performance.get_monitor(Performance.TIME_FPS),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]
	_lines.append(s)
	print("[PERFPROBE] ", s)
