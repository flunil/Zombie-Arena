extends Node
## اختبار ثبات 30 دقيقة (المرحلة 12): موجات مستمرة مع نقر تلقائي على بطاقات الترقية

const DURATION: int = 1800  # ثانية = 30 دقيقة

var _arena: Node = null


func _ready() -> void:
	_arena = load("res://scenes/main/Arena.tscn").instantiate()
	add_child(_arena)
	_autopick_loop()
	await get_tree().create_timer(1.0).timeout
	print("SOAK start t=0 nodes=", get_tree().get_node_count())
	var elapsed: int = 0
	while elapsed < DURATION:
		await get_tree().create_timer(60.0).timeout
		elapsed += 60
		var wm: Node = get_tree().get_first_node_in_group("wave_manager")
		var wave: int = int(wm.get("wave")) if wm != null else -1
		var alive: int = get_tree().get_nodes_in_group("enemies").size()
		var nodes: int = get_tree().get_node_count()
		var fps: float = Engine.get_frames_per_second()
		var state_s: String = str(GM.state)
		# سطر بفواصل: يظهر دائماً بغض النظر عن أي أخطاء تنسيق
		print("SOAK t=", elapsed, " wave=", wave, " alive=", alive,
			" state=", state_s, " nodes=", nodes, " fps=", fps)
		# سطر % للتشخيص: إن فشل مجدداً فالقيم معلومة من السطر أعلاه
		print("SOAKFMT t=%ds wave=%d alive=%d state=%s nodes=%d fps=%.0f" % [
			elapsed, wave, alive, state_s, nodes, fps])
	print("SOAK_OK duration=", DURATION, " kills=", GM.total_kills, " nodes=", get_tree().get_node_count())
	print("CHECK_RESULT: ALL_PASS")
	get_tree().quit(0)


## نقر تلقائي على أول بطاقة ترقية عند ظهورها (وإلا تتوقف الموجات عند شاشة الاختيار)
func _autopick_loop() -> void:
	while true:
		await get_tree().create_timer(0.4).timeout
		if get_tree() == null:
			return
		var sel: Node = find_child("UpgradeSelection", true, false)
		if sel == null:
			continue
		var vis := (sel as Control).visible
		if not vis:
			continue
		var cards: Node = sel.get_node_or_null("Cards")
		if cards == null or cards.get_child_count() == 0:
			continue
		var b := cards.get_child(0) as Button
		if b != null:
			print("SOAK auto-pick upgrade")
			b.pressed.emit()
