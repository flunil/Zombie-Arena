extends Node
## اختبار E2E لمسار اللعب الحقيقي: MainMenu → زر Start → SceneTransition → Arena
## → موجة 1 → إطلاق تلقائي فعلي → قتل أعداء + وجود مجسم السلاح

var fails: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: " + msg)
	else:
		fails.append(msg)
		print("FAIL: " + msg)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# --- 1) القائمة الرئيسية + ضغط زر Start الحقيقي ---
	var menu := (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu  # ليصبح هو current عند change_scene (جذري يبقى حياً)
	await get_tree().process_frame
	var start: Button = menu.find_child("StartButton", true, false) as Button
	check(start != null, "StartButton exists in MainMenu")
	if start == null:
		_finish()
		return
	start.pressed.emit()  # المسار الحقيقي: GM.reset_run + SceneTransition.goto

	# انتظار الانتقال إلى Arena (fade 0.3 + 0.1 + 0.3 + change_scene)
	var waited := 0.0
	while waited < 6.0:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
		var cs := get_tree().current_scene
		if cs != null and cs.scene_file_path.ends_with("Arena.tscn"):
			break
	var arena := get_tree().current_scene
	var reached: bool = arena != null and arena.scene_file_path.ends_with("Arena.tscn")
	check(reached, "SceneTransition reached Arena (current=%s)" % (
		arena.scene_file_path if arena != null else "null"))
	if not reached:
		_finish()
		return

	# --- 2) اللاعب + WeaponManager + سلاح مختار + مجسم ---
	var player: Node = arena.get_node_or_null("Player")
	check(player != null, "Player exists in Arena")
	if player == null:
		_finish()
		return
	var wm: Node = player.get_node_or_null("WeaponManager")
	check(wm != null, "WeaponManager exists on Player")
	if wm == null:
		_finish()
		return
	# _build_weapons مؤجل (deferred) — انتظر بناءه
	waited = 0.0
	while waited < 3.0 and wm.call("get_current") == null:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	var w: Node = wm.call("get_current")
	check(w != null, "a weapon is selected (get_current != null — بدونها لا إطلاق أصلاً)")
	if w != null:
		# لا مُجدٍّ طائر في WeaponBase — المجسم من عقد اليد في Player.tscn (طلب المستخدم)
		check(w.get_node_or_null("Model") == null, "no floating Model on WeaponBase (hand attachment)")
		check(w.get_node_or_null("MuzzleFlash") != null, "MuzzleFlash exists")
		check(bool(w.visible), "current weapon visible (selected)")
		var hand_root: Node = player.get_node_or_null("Characters_Lis/CharacterArmature/Skeleton3D/Rifle")
		check(hand_root != null, "hand attachment (Rifle bone) exists")
		if hand_root != null:
			var id := String(w.get("weapon_data").weapon_id)
			var vis_count := 0
			var matched: Node3D = null
			for hc in hand_root.get_children():
				if hc is Node3D and (hc as Node3D).visible:
					vis_count += 1
					if String(hc.name).to_lower() == id:
						matched = hc as Node3D
			check(matched != null, "current weapon hand node visible (%s)" % id)
			check(vis_count == 1, "exactly one hand weapon visible (count=%s)" % vis_count)
			if matched != null:
				check(_has_mesh(matched), "hand weapon contains mesh parts (%s)" % matched.get_child_count())

	# --- 2ب) دائرة مدى السلاح تحت اللاعب (constructive telegraphs + next_pass) ---
	var rc: Node = player.get_node_or_null("RangeCircle")
	check(rc != null, "RangeCircle telegraph exists under Player")
	if rc != null:
		check(rc.get("family") != null, "range circle has weapon-range family (green)")
		var area: Node = rc.get_node_or_null("Area")
		check(area != null, "range circle Area child exists")
		if area != null:
			check(int(area.get("shape_primitive")) == 2, "area shape is SPHERE")
			var r0: float = float(area.get("radius"))
			check(r0 >= 5.0 and r0 <= 15.0, "ring radius in weapon-range band 5..15 (%s)" % r0)
			var mn: float = float(area.get("min_radius"))
			check(mn > 0.0 and mn < r0, "ring is donut (min_radius=%s inside radius)" % mn)
			if w != null:
				var wd2: WeaponResource = w.get("weapon_data")
				var old_r: float = wd2.max_range
				wd2.max_range = 42.0
				rc.call("_update_range")
				check(is_equal_approx(float(area.get("radius")), 42.0),
					"ring radius follows weapon max_range (42)")
				check(is_equal_approx(float(rc.get("_alert_radius")), 42.0),
					"alert radius follows weapon max_range (42)")
				check(is_equal_approx(float(area.get("radius")) - float(area.get("min_radius")), 0.35),
					"ring is thin outline (width=0.35)")
				wd2.max_range = old_r
				rc.call("_update_range")
	var tgm: Node = arena.get_node_or_null("TelegraphManager")
	check(tgm != null, "ConTelegraphManager present in Arena")
	var gmesh: Node = arena.get_node_or_null("Ground/Mesh")
	var gmat: Material = null
	if gmesh is MeshInstance3D:
		gmat = (gmesh as MeshInstance3D).mesh.material
	check(gmat != null and gmat.next_pass != null, "ground material has telegraph next_pass")

	# --- 3) انتظار بدء الموجة الأولى (FIRST_DELAY=5s) ---
	var wmn: Node = arena.get_node_or_null("WaveManager")
	check(wmn != null, "WaveManager exists in Arena")
	if wmn == null:
		_finish()
		return
	waited = 0.0
	while waited < 14.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
		if int(wmn.get("wave")) >= 1:
			break
	var wave_n: int = int(wmn.get("wave"))
	check(wave_n >= 1, "wave 1 started (wave=%s)" % wave_n)

	var visible_enemies := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and (e as Node3D).visible:
			visible_enemies += 1
	check(visible_enemies > 0, "enemies spawned+visible in group (count=%s)" % visible_enemies)

	# --- 4) القتال: إطلاق + إصابة + قتلة ---
	var stats0: Dictionary = SaveSystem.stats()
	var sf0 := int(stats0.get("shots_fired", 0))
	var hits0 := int(stats0.get("shots_hit", 0))
	var kills0: int = GM.total_kills
	var ammo0: int = int(w.call("get_ammo")) if w.has_method("get_ammo") else -1

	waited = 0.0
	while waited < 25.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
		_close_distance(player)  # محاكاة اقتراب اللاعب: الأعداء يظهرون على الأطراف (23م) ولا يطاردون خارج 20م
		if GM.total_kills > kills0:
			break
		if GM.is_game_over():
			break

	var stats1: Dictionary = SaveSystem.stats()
	var sf1 := int(stats1.get("shots_fired", 0))
	var hits1 := int(stats1.get("shots_hit", 0))
	var ammo1: int = int(w.call("get_ammo")) if w.has_method("get_ammo") else -1
	check(sf1 > sf0, "auto-fire shot bullets (shots %s -> %s)" % [sf0, sf1])
	check(hits1 > hits0, "bullets damaged enemies (hits %s -> %s)" % [hits0, hits1])
	check(GM.total_kills > kills0, "enemy KILLED by auto-fire (kills %s -> %s)" % [kills0, GM.total_kills])
	check(ammo1 != ammo0, "ammo changed during combat (%s -> %s)" % [ammo0, ammo1])
	check(not GM.is_game_over(), "player survived (no false game-over)")
	_finish()


func _finish() -> void:
	if fails.is_empty():
		print("CHECK_RESULT: ALL_PASS")
	else:
		print("CHECK_RESULT: FAIL_COUNT=%d" % fails.size())
	get_tree().quit(0 if fails.is_empty() else 1)


## تقريب اللاعب نحو أقرب عدو (4م/ث) حتى يستدرجهم ضمن مدى الرصاص — يتوقف عند 16م
## فالعدو ضمن DETECT_RANGE(20م) يطارد تلقائياً ويكمل المسافة الباقية بنفسه
func _close_distance(player: Node) -> void:
	if not (player is Node3D):
		return
	var p := player as Node3D
	var tree := get_tree()
	if tree == null:
		return
	var best: Node3D = null
	var best_d := 9999.0
	for e in tree.get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n == null or not n.visible:
			continue
		if n.has_method("is_dead") and n.is_dead():
			continue
		var d: float = p.global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best == null or best_d <= 16.0:
		return
	var dir: Vector3 = best.global_position - p.global_position
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		p.global_position += dir.normalized() * 2.0  # 0.5s × 4م/ث


## بحث تنازلي عن MeshInstance3D بـ mesh (يشمل عقد المشاهد المُدرجة)
func _has_mesh(n: Node) -> bool:
	for c in n.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			return true
		if _has_mesh(c):
			return true
	return false
