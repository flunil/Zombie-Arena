extends Node
## تشخيص real-full-cycle: فتح القائمة → بكرة → اختيار → لحظة بطلة → 5 دورات
## يقيس نمو العقد/اليتيمة/الذاكرة (التشخيص (nodes=26) كان يفتح/يغلق sans اختيار)

func _ready() -> void:
	_run()


func _run() -> void:
	GM.set_state(GM.State.PLAYING)
	var arena: Node = (load("res://scenes/main/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await _wait_frames(3)
	var wm: Node = arena.get_node("WaveManager")
	if "_timer" in wm:
		wm.set("_timer", 99999.0)

	var usel: Node = arena.get_node("HUD").find_child("UpgradeSelection", true, false)
	print("=== FULL-CYCLE LAG PROBE ===")
	var base_nodes := _count_all(arena)
	var base_orphan := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var base_mem := Performance.get_monitor(Performance.MEMORY_STATIC)
	print("base nodes=%d orphan=%d mem=%d" % [base_nodes, base_orphan, base_mem])

	for cycle in range(5):
		usel.call("_show_options")
		await _wait_frames(2)  # تأكد من ظهور 3 بطاقات
		# انتظر انتهاء البكرة (2.1ث + هامش)
		await _wait_seconds(2.6)
		# اختر بطاقة (الأولى)
		var cards: Node = usel.get("cards")
		var btn: Button = null
		if cards != null and cards.get_child_count() > 0:
			btn = cards.get_child(0) as Button
		if btn != null:
			btn.emit_signal("pressed")
		# انتظر لحظة البطلة + تلاشي (~1.5ث)
		await _wait_seconds(1.8)
		var n := _count_all(arena)
		var o := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		var m := Performance.get_monitor(Performance.MEMORY_STATIC)
		print("cycle %d: nodes=%d(Δ%+d) orphan=%d(Δ%+d) mem=%d(Δ%+d)" % [
			cycle + 1, n, n - base_nodes, o, o - base_orphan, m, m - base_mem])

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


func _wait_seconds(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()
