extends Node
## محاكاة كاملة لعدة موجات: قتال حقيقي (hit_stop) + نهاية موجة (slow_motion)
## + فتح قائمة الترقية + اختيار ترقية + إغلاق → قياس time_scale والعقد والذاكرة
## الهدف: إثبات أن الإصلاح يصمد عبر اللعب الطويل (كل الموجات) بلا تعلّم السرعة

var fails: Array[String] = []
var waves: int = 10


func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		fails.append(label)
		print("FAIL: ", label)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--waves="):
			waves = int(a.split("=")[1])
	_run()


func _run() -> void:
	GM.set_state(GM.State.PLAYING)
	var arena: Node = (load("res://scenes/main/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await _wait_frames(3)
	var wm: Node = arena.get_node("WaveManager")
	var usel: Node = arena.get_node("HUD").find_child("UpgradeSelection", true, false)
	# اللاعب لا يتحرك في الاختبار → نُبقيه حياً (وإلا انتهت الجولة بـ Game Over
	# فولا تُفتح قائمة التطويرات أصلاً — سلوك صحيح في اللعبة لكنه يُفسد القياس)
	var player: Node = arena.get_node_or_null("Player")
	var phealth: Node = null
	if player != null:
		phealth = player.find_child("Health", true, false)
		if phealth != null:
			# صحة ضخمة → اللاعب لا يموت (الاختبار لا يتحرك به).
			# موت اللاعب يفعّل Game Over فتخاطى GameManager إشارة موجة_انتهت
			# ولا تُفتح القائمة — سلوك صحيح لكنه يُفسد قياس "فتح القائمة".
			phealth.set("max_health", 1000000.0)
			phealth.set("health", 1000000.0)

	print("=== MULTI-WAVE STABILITY PROBE (waves=%d) ===" % waves)
	wm.set("_timer", 999.0)  # نمنع بدء موجة تلقائي متزامن مع محاكاتنا
	var base_nodes := _count_all(arena)
	var base_orphan := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var base_types: Dictionary = {}
	_type_counts(arena, base_types)
	print("base nodes=%d orphan=%d" % [base_nodes, base_orphan])

	var max_orphan := base_orphan
	var last_nodes := base_nodes

	for w in range(1, waves + 1):
		# (1) بدء الموجة
		GM.set_state(GM.State.PLAYING)
		if phealth != null:
			phealth.set("health", phealth.get("max_health"))
		wm.set("essence", 0)
		wm.call("_start_next_wave")
		await _wait_frames(2)

		# (2) قتال: نقتل كل الزومبي (كما عند نهاية الموجة) — يولّد hit_stop حقيقي
		# ننتظر "alive == 0" لا فراغ المجموعة: الزومبي المُعاد إلى المسبح يبقى فيها
		var killed := 0
		var guard := 0
		while guard < 2500:
			guard += 1
			var alive_now: int = int(wm.get("alive"))
			if alive_now <= 0:
				break
			# نقتل عدة زومبي في الإطار الواحد (حتى 4 = دفعة الإنزال) حتى لا
			# يتعطّل الاختبار بسبب "فترة سماح التجميد" (وهي سلوك اللعبة الصحيح)
			var hits := 0
			for z in get_tree().get_nodes_in_group("enemies"):
				if hits >= 4:
					break
				# نقتل ZombieBatchManager يُخفي الزومبي البعيد (MultiMesh) → لا ن rely على visible
				if not (z is Node3D):
					continue
				if is_instance_valid(z) and z.has_method("take_damage") and not bool(z.get("_dead")):
					z.call("take_damage", 999999.0)
					killed += 1
					hits += 1
			# نمنع فتح القائمة من امتلاء العدّاد وسط الموجة (حالة不同于 نهاية الموجة)
			wm.set("essence", 0)
			# نُبقي اللاعب حياً (الاختبار لا يتحرك به)
			if phealth != null:
				phealth.set("health", phealth.get("max_health"))
				if GM.is_game_over():
					GM.set_state(GM.State.PLAYING)
			await _wait_frames(1)
			# (3) أخطر نافذة تداخل: بطيء زمني أثناء نافذة تجميد لحظي
			if killed == 3:
				TimeFX.slow_motion(0.3, 0.5)

		# (4) ننتظر أن تفتح wave_manager قائمة التطويرات طبيعيًا (wave_cleared)
		if int(wm.get("alive")) > 0:
			_dump_alive(w)
		var opened := await _wait_until(func() -> bool: return bool(usel.get("visible")), 6.0)
		check(opened, "wave %d: upgrade menu opened automatically at wave end" % w)
		if not opened:
			_dump_state(w, wm, usel, "menu did not open")
			continue
		var reel_stopped := await _wait_until(func() -> bool: return not bool(usel.get("_reel_spinning")), 8.0)
		if not reel_stopped:
			_dump_state(w, wm, usel, "reel still spinning")

		# (5) اختيار بطاقة (كما يفعل اللاعب)
		var cards: Node = usel.get("cards")
		var btn: Button = null
		if cards != null and cards.get_child_count() > 0:
			btn = cards.get_child(0) as Button
		if btn != null:
			btn.emit_signal("pressed")
		# انتظار انتهاء أنيميشن البطل وإغلاق القائمة فعليًا
		var closed := await _wait_until(func() -> bool:
			return not bool(usel.get("_picking")) and not get_tree().paused, 8.0)
		if not closed:
			_dump_state(w, wm, usel, "menu did not close")
		await _wait_seconds(0.3)

		# (6) بعد الإغلاق يجب أن تعود السرعة الطبيعية (ننتظر تجاوز أي تجميد لحظي عابر)
		var ok := await _expect_scale_one()
		check(ok, "wave %d: time_scale returns to 1.0 after upgrade (got %.3f)" % [w, Engine.time_scale])
		check(not get_tree().paused,
			"wave %d: game unpaused after upgrade" % w)

		var n := _count_all(arena)
		var o := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		max_orphan = maxi(max_orphan, o)
		last_nodes = n
		print("wave %d: killed=%d nodes=%d(Δ%+d) orphan=%d scale=%.3f" % [
			w, killed, n, n - base_nodes, o, Engine.time_scale])

		# (7) الموجة التالية تبدأ طبيعيًا (rest → _start_next_wave) — نمنع البدء المزدوج
		wm.set("_timer", 999.0)
		await _wait_frames(2)

	# (8) فحوص نهائية
	var ok_final := await _expect_scale_one()
	check(ok_final, "final time_scale returns to 1.0 (got %.3f)" % Engine.time_scale)
	check(max_orphan == base_orphan,
		"no orphan growth (base=%d max=%d)" % [base_orphan, max_orphan])

	# لا تسرب حقيقي: عدد العقد المُتيمة = 0، والمسبحة محدودة بكمية المسبح
	var pool_total := 0
	var pools: Dictionary = wm.get("pools")
	for k in pools.keys():
		var p: ObjectPool = pools[k]
		pool_total += p.total_created()
	var wave_zombies: int = (5 + waves * 3) * 4
	print("pool total instances=%d (wave %d needs %d zombies)" % [pool_total, waves, wave_zombies])
	# كل زومبي مسبح ≈ 13 عقد (جسم/تصادم/شريط حياة/هيكل/...) → النمو = المسبحة فقط
	var allowed: int = 80 + pool_total * 15
	check(last_nodes - base_nodes < allowed,
		"node growth == pool only (Δ=%d < allowed=%d for %d pooled zombies)" % [
			last_nodes - base_nodes, allowed, pool_total])
	check(pool_total <= wave_zombies * 2 + 60,
		"enemy pool bounded by wave size (created=%d, wave=%d)" % [pool_total, wave_zombies])

	# تفصيل: ما الذي نما بالضبط
	var diff := _type_diff(arena, base_types)
	var parts: Array[String] = []
	for k in diff.keys():
		parts.append("%s+%d" % [k, diff[k]])
	print("growth breakdown: ", ", ".join(parts))
	_print_leftovers(arena, base_types)

	# (10) تشخيص: هل تتجمد تويتات HUD أثناء pause القائمة؟ ننتظر بعد إغلاقها
	var shard_layer: Node = arena.get_node("HUD").get_node_or_null("ShardLayer")
	print("shard children right after last wave = %d" % (shard_layer.get_child_count() if shard_layer else -1))
	await _wait_seconds(3.0)
	print("shard children after 3s unpaused      = %d" % (shard_layer.get_child_count() if shard_layer else -1))
	print("hud process_mode = %d  tree.paused=%s" % [
		arena.get_node("HUD").process_mode, str(get_tree().paused)])

	# (9) موجة إضافية سريعة بلا قتال — تأكيد أن الراحة/البداية لا تعلّق السرعة
	TimeFX.slow_motion(0.3, 0.5)
	await _wait_seconds(1.2)
	var ok_solo := await _expect_scale_one()
	check(ok_solo, "slow_motion alone after all waves -> 1.0 (got %.3f)" % Engine.time_scale)

	if fails.is_empty():
		print("CHECK_RESULT: ALL_PASS")
	else:
		print("CHECK_RESULT: FAIL_COUNT=", fails.size())
	get_tree().quit(0 if fails.is_empty() else 1)


func _dump_alive(w: int) -> void:
	var n := 0
	for z in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(z) and z.has_method("take_damage") and not bool(z.get("_dead")):
			var hp := -1.0
			var hc: Node = z.get_node_or_null("Health")
			if hc != null:
				hp = float(hc.get("health"))
			print("  ?? wave %d alive zombie: %s type=%s hp=%.1f vis=%s" % [
				w, z.name, z.get_class(), hp, str((z as Node3D).visible if z is Node3D else "n/a")])
			n += 1
			if n >= 8:
				break
	print("  ?? wave %d: %d+ zombies still alive after kill loop" % [w, n])


func _dump_state(w: int, wm: Node, usel: Node, why: String) -> void:
	print("  !! wave %d (%s): wm.state=%s alive=%s essence=%s end_upgrade=%s | usel.visible=%s reel=%s picking=%s | game_over=%s paused=%s scale=%.3f" % [
		w, why, str(wm.get_state()), str(wm.get("alive")), str(wm.get("essence")),
		str(wm.get("_was_wave_end_upgrade")),
		str(usel.get("visible")), str(usel.get("_reel_spinning")), str(usel.get("_picking")),
		str(GM.is_game_over()), str(get_tree().paused), Engine.time_scale])


func _count_all(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count_all(ch)
	return c


func _type_counts(n: Node, out: Dictionary) -> void:
	out[n.get_class()] = int(out.get(n.get_class(), 0)) + 1
	for ch in n.get_children():
		_type_counts(ch, out)


func _type_diff(root: Node, base: Dictionary) -> Dictionary:
	var now: Dictionary = {}
	_type_counts(root, now)
	var diff: Dictionary = {}
	for k in now.keys():
		var d: int = int(now[k]) - int(base.get(k, 0))
		if d > 0:
			diff[k] = d
	return diff


func _print_leftovers(n: Node, base: Dictionary) -> void:
	var cls := n.get_class()
	if cls == "ColorRect" or cls == "TextureRect" or cls == "Label":
		print("  leftover %s: %s" % [cls, str(n.get_path())])
	for ch in n.get_children():
		_print_leftovers(ch, base)


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_seconds(s: float) -> void:
	# وقت حقيقي (لا يتأثر بـ Engine.time_scale ولا بـ pause)
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < int(s * 1000.0):
		await get_tree().process_frame


func _wait_until(cond: Callable, timeout: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < int(timeout * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


## ينتظر عودة السرعة للطبيعية خلال مهلة — نتجاهل التجميد اللحظي العابر (60ms)
func _expect_scale_one(timeout: float = 2.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < int(timeout * 1000.0):
		if is_equal_approx(Engine.time_scale, 1.0):
			return true
		await get_tree().process_frame
	return is_equal_approx(Engine.time_scale, 1.0)
