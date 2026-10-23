extends Node
## تشخيص تسرّب قائمة التطويرات: يفتحها3 مرات ويقيس العُقد والعُقد اليتيمة والذاكرة
## التشغيل: Godot --headless --path <project> res://tests/upgrade_lag_probe.tscn

func _ready() -> void:
	_run()


func _run() -> void:
	GM.set_state(GM.State.PLAYING)
	var arena: Node = (load("res://scenes/main/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await _wait_frames(3)

	var hud: Node = arena.get_node("HUD")
	var usel: Node = hud.get_node("Root/UpgradeSelection") if hud.get_node_or_null("Root") else null
	if usel == null:
		# بحث تعاوني
		usel = hud.find_child("UpgradeSelection", true, false)
	if usel == null:
		print("PROBE: UpgradeSelection NOT FOUND")
		get_tree().quit(1)
		return

	print("=== UPGRADE LAG PROBE ===")
	for open in range(3):
		# نفتح القائمة (توقف اللعب داخليًا)
		usel.call("_show_options")
		await _wait_frames(5)
		var n1 := _count_desc(usel)
		var o1 := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		var m1 := Performance.get_monitor(Performance.MEMORY_STATIC)
		print("open %d AFTER_SHOW nodes=%d orphan=%d mem=%d" % [open + 1, n1, o1, m1])
		# نختار أول بطاقة (يُطلق لحظة البطلة ثم التنظيف)
		var cards_box: Node = usel.get_node("Cards")
		if cards_box.get_child_count() > 0:
			var b: Button = cards_box.get_child(0) as Button
			if b != null:
				usel.call("_on_pick", str(b.get_meta("_pick_id", "")))
		await _wait_frames(90)  # ننتظر اكتمال لحظة البطلة + التنظيف
		var n2 := _count_desc(usel)
		var o2 := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		var m2 := Performance.get_monitor(Performance.MEMORY_STATIC)
		print("open %d AFTER_PICK+CLEAN nodes=%d orphan=%d mem=%d" % [open + 1, n2, o2, m2])
		_dump_caches(usel)
		usel.call("_reset_open_state")  # يحاكي بداية الفتح القادم
		await _wait_frames(2)

	print("=== FINAL ===")
	print("nodes=%d orphan=%d mem=%d" % [_count_desc(usel),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC)])
	get_tree().quit(0)


func _count_desc(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count_desc(ch)
	return c


func _dump_caches(usel: Node) -> void:
	# نطبع أحجام كل قواميس التخزين المؤقت داخل UpgradeSelection
	for key in ["_icon_cache", "_icon_fallback", "_rarity_sb", "_fire_mats",
			"_fire_border", "_fire_gold", "_reel_tweens", "_reel_rot", "_reel_bases"]:
		var d = usel.get(key)
		if d is Dictionary:
			print("  cache %s size=%d" % [key, d.size()])
		elif d is Array:
			print("  cache %s len=%d" % [key, d.size()])


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
