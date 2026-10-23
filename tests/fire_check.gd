extends Node
## تشخيص: هل تولّد الموجات أعداء؟ هل يرى اللاعب عدوًا؟ هل يطلق فعليًا؟


func _ready() -> void:
	var arena: Node = load("res://scenes/main/Arena.tscn").instantiate()
	add_child(arena)
	await get_tree().create_timer(7.0).timeout  # عدّ 5ث + بداية الموجة 1
	var wm_arena: Node = arena.get_node_or_null("WaveManager")
	var player: Node3D = arena.get_node_or_null("Player") as Node3D
	var wm: Node = player.get_node_or_null("WeaponManager")
	print("[FIRECHK] wave=", wm_arena.get("wave"), " state=", wm_arena.get("_state"))
	var enemies := get_tree().get_nodes_in_group("enemies")
	print("[FIRECHK] enemies=", enemies.size())
	var w: Node = wm.call("get_current")
	var wd: Variant = null
	if w != null:
		wd = w.get("weapon_data")
	var rng: float = float(player.call("_weapon_range", wm))
	var tgt: Node3D = player.call("_nearest_enemy")
	print("[FIRECHK] weapon=", "null" if w == null else w.name,
			" weapon_data=", "null" if wd == null else "ok",
			" range=", rng,
			" nearest=", "null" if tgt == null else tgt.name)
	# عد الرصاص الناتج خلال ثانية من الإطلاق اليدوي المباشر
	var w0 := get_tree().get_nodes_in_group("bullet").size()
	for i in range(10):
		wm.call("try_fire", Vector3(1, 0, 0))
		await get_tree().physics_frame
	var w1 := get_tree().get_nodes_in_group("bullet").size()
	# إن لم يكن الرصاص في مجموعة — عد بأسماء الأبناء
	if w1 == 0 and w0 == 0:
		var cnt := 0
		for c in get_children():
			if String(c.name).begins_with("Bullet"):
				cnt += 1
		w1 = cnt
	print("[FIRECHK] manual_bullets=", w1 - w0)
	# مراقبة الإطلاق التلقائي3ث: مدى أقرب عدو + ذخيرة + عدد مرئي
	var weapon0: Node = wm.call("get_current")
	for s in range(6):
		await get_tree().create_timer(0.5).timeout
		var t2: Node3D = player.call("_nearest_enemy")
		var dist := -1.0
		if t2 != null:
			dist = player.global_position.distance_to(t2.global_position)
		var vis := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if (e as Node3D).visible:
				vis += 1
		var ammo := -1
		if weapon0 != null and weapon0.has_method("get_ammo"):
			ammo = int(weapon0.call("get_ammo"))
		print("[FIRECHK] t=", 0.5 * (s + 1), " nearest_d=", dist,
				" vis_enemies=", vis, " ammo=", ammo)
	var ok: bool = (rng > 0.0) and (w1 - w0 > 0)
	print("[FIRECHK] ", "ALL_PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _bullet_count() -> int:
	var n := get_tree().get_nodes_in_group("bullet").size()
	if n > 0:
		return n
	for c in get_children():
		if String(c.name).begins_with("Bullet"):
			n += 1
	return n
