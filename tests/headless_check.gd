extends Node
## فحص وظيفي سحابي (headless): اللاعب + الإطلاق التلقائي + الصحة/الذهب + GAME_OVER
## التشغيل: Godot --headless --path <project> res://tests/headless_check.tscn

var fails: Array[String] = []


func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		fails.append(label)
		print("FAIL: ", label)


func _ready() -> void:
	_run()


func _run() -> void:
	GM.set_state(GM.State.PLAYING)
	var arena: Node = (load("res://scenes/main/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await _wait_frames(2)

	var player: Node = arena.get_node("Player")
	var health := player.get_node("Health") as HealthComponent
	var wm: Node = player.get_node("WeaponManager")

	# بناء المشهد + تكامل المرحلة 9
	check(is_equal_approx(health.max_health, 100.0 + float(SaveSystem.get_health_bonus())),
		"health bonus applied (max=%s)" % health.max_health)
	check(int(player.get("gold")) == 0, "gold starts at 0")
	var weapons: Array = wm.get("_weapons")
	check(weapons != null and weapons.size() == 9,
		"9 weapons built (got %s)" % str(weapons.size()) if weapons != null else "9 weapons built (null)")
	check(arena.get_node_or_null("WaveManager") != null, "WaveManager present")
	check(arena.get_node_or_null("HUD") != null, "HUD present")
	check(arena.get_node_or_null("NavRegion") != null, "NavRegion present")
	# تجميد مؤقّت الموجة: الفحص الوظيفي يجب أن يبقى قبل أي موجة حقيقية
	# (في headless قد تتراكم ثوانٍ حقيقية أثناء awaits فتنطلق الموجة وتُفسد فحص الإطلاق/الصحة)
	var wave_mgr: Node = arena.get_node("WaveManager")
	if "_timer" in wave_mgr:
		wave_mgr.set("_timer", 99999.0)
	var pt0 := _playtime()

	# (1) بلا أعداء ظاهرين → بلا إطلاق (قبل موجة الـ 5ث)
	var ammo0: int = wm.get_current().get_ammo()
	await _wait_frames(60)
	check(wm.get_current().get_ammo() == ammo0, "no enemies -> no auto-fire")

	# (2) عدو وهمي: خارج حدود السلاح → لا إطلاق ولا التفات، ثم داخلها → إطلاق
	var rng: float = float(wm.get_current().weapon_data.max_range)
	var fake := Node3D.new()
	fake.name = "FakeEnemy"
	arena.add_child(fake)
	fake.global_position = Vector3(rng + 5.0, 0.9, 0)
	fake.add_to_group("enemies")
	await _wait_frames(30)
	var ammo_out: int = wm.get_current().get_ammo()
	check(ammo_out == ammo0, "no auto-fire beyond weapon range (r=%.1f d=%.1f ammo %s -> %s)" % [rng, rng + 5.0, ammo0, ammo_out])
	check(player.get("_aim_dir") == Vector3.ZERO, "no aim turn beyond weapon range")
	fake.global_position = Vector3(rng * 0.6, 0.9, 0)
	await _wait_frames(60)
	var ammo1: int = wm.get_current().get_ammo()
	check(ammo1 < ammo_out, "auto-fire at enemy in range (ammo %s -> %s)" % [ammo_out, ammo1])

	# (3) إزالة العدو → يتوقف الإطلاق (ما زال قبل موجة الـ 5ث)
	fake.queue_free()
	await _wait_frames(60)
	var ammo2: int = wm.get_current().get_ammo()
	await _wait_frames(30)
	check(wm.get_current().get_ammo() == ammo2, "firing stopped after enemy gone")

	# (3.5) تجميع MultiMesh للبعيد + منع التداخل (collision_mask = عالم + زومبي + لاعب)
	var zmgr := ZombieBatchManager.instance
	check(zmgr != null, "ZombieBatchManager created by WaveManager")
	var runner := (load("res://scenes/enemies/ZombieRunner.tscn") as PackedScene).instantiate()
	arena.add_child(runner)
	runner.set_physics_process(false)  # تثبيت مكاني: لا يطارد ولا يلكم أثناء الفحص
	check(runner.collision_mask == 7, "zombie mask = 7 (world+enemies+player)")
	runner.global_position = Vector3(40.0, 0.9, 0)  # 40م > 15 عن اللاعب ← دفعة
	await _wait_frames(70)  # نبض التجميع 0.5ث ≈ 30 إطار + هامش واسع ضد تذبذب headless
	check(runner.get("_batched") == true, "far zombie batched into MultiMesh")
	var rbody := runner.get_node_or_null("BodyMesh") as MeshInstance3D
	var rvis: Variant = runner.get("_visual")  # نموذج FBX عند وجوده، وإلا الـ BodyMesh
	check((rbody == null or not rbody.visible) and (rvis == null or not (rvis as Node3D).visible),
		"batched visual hidden")
	runner.global_position = Vector3(3.0, 0.9, 0)  # قريب ← يعود مفردًا
	await _wait_frames(70)
	check(runner.get("_batched") == false, "near zombie back to individual")
	check((rvis != null and (rvis as Node3D).visible) or (rvis == null and rbody != null and rbody.visible),
		"individual model visible")
	# Basic (نموذج FBX مفصّل) — مسار الدمج مختلف عن الكبسولة
	var basic := (load("res://scenes/enemies/ZombieBasic.tscn") as PackedScene).instantiate()
	arena.add_child(basic)
	basic.set_physics_process(false)
	basic.global_position = Vector3(-40.0, 0.9, 0)
	await _wait_frames(70)
	check(basic.get("_batched") == true, "far Basic (FBX) batched into MultiMesh")
	var fbx: Variant = basic.get("_visual")
	check(fbx != null and not (fbx as Node3D).visible, "batched FBX visual hidden")
	basic.queue_free()
	await _wait_frames(2)
	runner.queue_free()
	await _wait_frames(2)

	# (4) ذهب + عدّاد وقت اللعب — gold0 يقيس الفرق لأن مكافآت قتل runner/in-range قد تُضاف أثناء فحص الدمج
	var gold0: int = int(player.get("gold"))
	player.call("add_gold", 10)
	check(int(player.get("gold")) == gold0 + 10 and GM.run_gold >= 10,
		"add_gold -> gold/run_gold (%s -> %s, run=%s)" % [gold0, player.get("gold"), GM.run_gold])
	var pt1 := _playtime()
	check(pt1 > pt0, "StatsTracker.tick accumulates playtime (%s -> %s)" % [pt0, pt1])

	# (5) ضرر ثم موت → GAME_OVER
	player.call("take_damage", 10.0)
	check(is_equal_approx(health.health, health.max_health - 10.0), "take_damage -> health=%s" % health.health)
	player.call("take_damage", 99999.0)
	check(GM.is_game_over(), "death -> GAME_OVER")

	# (6) زمن اللعبة: تداخل التجميد (hit_stop) مع البطء (slow_motion) يجب أن يعيد السرعة 1.0
	# (كان يترك time_scale = 0.02 → لعب ببطء شديد/Stop Motion بعد ثلث الترقية)
	TimeFX.reset()
	check(is_equal_approx(Engine.time_scale, 1.0), "time_scale reset to 1.0")
	TimeFX.hit_stop(0.06)
	TimeFX.slow_motion(0.3, 0.5)
	await _wait_seconds(1.2)
	check(is_equal_approx(Engine.time_scale, 1.0),
		"overlap hit_stop+slow_motion restores time_scale=1.0 (got %.3f)" % Engine.time_scale)

	# (7) بطء منفرد ثم تجميد → يعود 1.0
	TimeFX.reset()
	TimeFX.slow_motion(0.3, 0.3)
	await _wait_seconds(0.9)
	check(is_equal_approx(Engine.time_scale, 1.0),
		"slow_motion alone restores time_scale=1.0 (got %.3f)" % Engine.time_scale)

	# (8) تجميد منفرد → يعود 1.0
	TimeFX.reset()
	TimeFX.hit_stop(0.05)
	await _wait_seconds(0.4)
	check(is_equal_approx(Engine.time_scale, 1.0),
		"hit_stop alone restores time_scale=1.0 (got %.3f)" % Engine.time_scale)

	if fails.is_empty():
		print("CHECK_RESULT: ALL_PASS")
	else:
		print("CHECK_RESULT: FAIL_COUNT=", fails.size())
	get_tree().quit(0 if fails.is_empty() else 1)


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_seconds(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()


func _playtime() -> float:
	return float(SaveSystem.stats().get("playtime", 0.0))
