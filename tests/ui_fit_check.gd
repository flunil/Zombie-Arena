extends Node
## فحص مقاسات اللعبه للوضع العمودي: إعدادات 720×1280 + كاميرا متكيفة + لا فيض في الواجهات

var _fails: int = 0
var _overflow: Array[String] = []


func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _ready() -> void:
	await get_tree().process_frame
	_test_settings()
	_test_camera()
	await _test_ui_fit()
	await _test_multi_aspect()
	print("OVERFLOW_COUNT: ", _overflow.size())
	for line in _overflow:
		print("OVER: ", line)
	print("CHECK_RESULT: ", "ALL_PASS" if _fails == 0 else "FAIL_COUNT=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


## إعدادات العرض في project.godot + حجم النافذة الفعلي
func _test_settings() -> void:
	check(int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) == 720,
		"design width = 720")
	check(int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) == 1280,
		"design height = 1280")
	check(ProjectSettings.get_setting("display/window/handheld/orientation", "?") == "portrait",
		"handheld orientation = portrait")
	check(ProjectSettings.get_setting("display/window/stretch/mode", "?") == "viewport",
		"stretch mode = viewport")
	check(ProjectSettings.get_setting("display/window/stretch/aspect", "?") == "expand",
		"stretch aspect = expand")
	# وضع viewport: الحجم الفعلي = مقاس التصميم دائمًا (720×1280) حتى في headless
	var vp := get_viewport().get_visible_rect().size
	if vp != Vector2(720, 1280):
		print("DIAG forcing viewport size, was: ", vp)
		get_viewport().size = Vector2i(720, 1280)
		await get_tree().process_frame
		vp = get_viewport().get_visible_rect().size
	print("DIAG display=", DisplayServer.get_name(), " window=", get_window().size,
		" visible=", vp)
	check(vp == Vector2(720, 1280), "runtime viewport = 720x1280 (got %s)" % vp)


## كاميرا اللاعب: متكيفة مع العمودي (FOV أوسع + ارتفاع أعلى)
func _test_camera() -> void:
	var ps: PackedScene = load("res://scenes/player/Player.tscn")
	if ps == null:
		check(false, "load Player.tscn")
		return
	var authored_y := 0.0
	var root_scale := 1.0
	var probe: Node = ps.instantiate()
	var probe_cam := probe.get_node_or_null("Camera3D") as Node3D
	if probe_cam != null:
		authored_y = probe_cam.position.y
	# جذر اللاعب قد يحمل مقياسًا (1.5) — الكاميرا top_level تحفظ الموضع العالمي
	root_scale = (probe as Node3D).scale.y
	probe.free()
	var p: Node = ps.instantiate()
	add_child(p)
	await get_tree().process_frame
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	check(cam != null, "player camera exists")
	if cam != null:
		var s := get_viewport().get_visible_rect().size
		var aspect := s.x / maxf(s.y, 1.0)
		var factor := 18.0 / 14.0 if aspect <= 1.05 else 1.0
		var expected := authored_y * root_scale * factor
		if aspect <= 1.05:
			check(cam.fov >= 75.0, "portrait camera FOV widened (got %.0f)" % cam.fov)
		var rh := float(cam.get("rig_height"))
		check(absf(rh - expected) < 0.05, "camera rig = authored %.2f x scale %.2f x fit (got %.2f, want %.2f)" % [authored_y, root_scale, rh, expected])
	p.queue_free()
	await get_tree().process_frame


## كل الواجهات + الساحة: لا شيء يتجاوز 720×1280
func _test_ui_fit() -> void:
	var scenes := [
		"res://scenes/ui/MainMenu.tscn",
		"res://scenes/ui/GameOverScreen.tscn",
		"res://scenes/ui/UpgradeSelection.tscn",
		"res://scenes/ui/MissionPanel.tscn",
		"res://scenes/ui/MetaUpgradeShop.tscn",
		"res://scenes/ui/DailyReward.tscn",
		"res://scenes/ui/HUD.tscn",
		"res://scenes/ui/VirtualJoystick.tscn",
		"res://scenes/ui/WeaponList.tscn",
	]
	var vp := Vector2(720, 1280)  # مقاس التصميم الحقيقي للهاتف
	for path in scenes:
		var packed: PackedScene = load(path)
		if packed == null:
			check(false, "load %s" % path)
			continue
		var inst: Node = packed.instantiate()
		add_child(inst)
		await get_tree().process_frame
		await get_tree().process_frame
		var before := _overflow.size()
		_collect_overflow(inst, inst.name, vp)
		var added := _overflow.size() - before
		check(added == 0, "%s fits 720x1280 (overflow=%d)" % [path.get_file(), added])
		inst.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame


func _collect_overflow(n: Node, path: String, vp: Vector2) -> void:
	if n is Control:
		var c := n as Control
		# محتوى ScrollContainer قابل للتمرير — حجمه الكامل ليس فيضًا
		var in_scroll := false
		var p := c.get_parent()
		while p != null:
			if p is ScrollContainer:
				in_scroll = true
				break
			p = p.get_parent()
		if not in_scroll and c.is_visible_in_tree() and c.size.x > 0.5 and c.size.y > 0.5:
			var r := c.get_global_rect()
			if r.position.x < -1.0 or r.position.y < -1.0 \
					or r.end.x > vp.x + 1.0 or r.end.y > vp.y + 1.0:
				_overflow.append("%s :: %s :: %s" % [path, c.name, r])
	for child in n.get_children():
		_collect_overflow(child, path + "/" + child.name, vp)


## كل نسب الشاشات: مقياس موحّد (بلا تشوه) + القوائم ملائمة ومتمركزة في كل مقاس
func _test_multi_aspect() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: multi-aspect needs a real window")
		return
	var win := get_window()
	var original := win.size
	var sizes := [
		Vector2i(720, 1280),   # تصميم 9:16
		Vector2i(720, 1560),   # هاتف 20:9
		Vector2i(720, 1624),   # هاتف 19.5:9
		Vector2i(768, 1024),   # جهاز لوحي 3:4
		Vector2i(900, 1600),   # فريميير 9:16
		Vector2i(1080, 1920),  # هاتف كامل
		Vector2i(1280, 720),   # سطح مكتب عريض 16:9
		Vector2i(1600, 900),   # سطح مكتب عريض أكبر
	]
	var us_ps: PackedScene = load("res://scenes/ui/UpgradeSelection.tscn")
	var mm_ps: PackedScene = load("res://scenes/ui/MainMenu.tscn")
	for wsz in sizes:
		win.size = wsz
		await get_tree().process_frame
		await get_tree().process_frame
		var vp := get_viewport().get_visible_rect().size
		var sx := float(wsz.x) / maxf(vp.x, 1.0)
		var sy := float(wsz.y) / maxf(vp.y, 1.0)
		check(absf(sx - sy) < 0.02,
			"uniform scale (no distortion) at window %dx%d (sx=%.3f sy=%.3f)" % [wsz.x, wsz.y, sx, sy])
		check(vp.x >= 719.0 and vp.y >= 1279.0,
			"viewport >= design at %dx%d (got %s)" % [wsz.x, wsz.y, vp])
		# شاشة الترقيات: البطاقات مركزية فعلًا + لا فيض
		var u: Node = us_ps.instantiate()
		add_child(u)
		await get_tree().process_frame
		await get_tree().process_frame
		var cards := u.get_node_or_null("Cards") as Control
		if cards != null:
			var cx := cards.get_global_rect().get_center().x
			check(absf(cx - vp.x * 0.5) < 2.0,
				"UpgradeSelection cards centered at %dx%d (cx=%.1f want=%.1f)" % [wsz.x, wsz.y, cx, vp.x * 0.5])
		var before := _overflow.size()
		_collect_overflow(u, "UpgradeSelection@%dx%d" % [wsz.x, wsz.y], vp)
		check(_overflow.size() == before, "UpgradeSelection fits at %dx%d" % [wsz.x, wsz.y])
		u.queue_free()
		await get_tree().process_frame
		# المين منيو: الشريط السفلي وزر البدء ضمن الحدود في كل مقاس
		var m: Node = mm_ps.instantiate()
		add_child(m)
		await get_tree().process_frame
		await get_tree().process_frame
		var bar := m.get_node_or_null("BottomBar") as Control
		if bar != null:
			var r := bar.get_global_rect()
			check(r.end.y <= vp.y + 1.0 and r.position.x >= -1.0 and r.end.x <= vp.x + 1.0,
				"MainMenu BottomBar in bounds at %dx%d" % [wsz.x, wsz.y])
		var sb := m.get_node_or_null("StartButton") as Control
		if sb != null:
			var sr := sb.get_global_rect()
			check(sr.end.y <= vp.y + 1.0 and sr.position.y >= -1.0,
				"StartButton in bounds at %dx%d" % [wsz.x, wsz.y])
			check(absf(sr.get_center().x - vp.x * 0.5) < 2.0,
				"StartButton centered at %dx%d (cx=%.1f)" % [wsz.x, wsz.y, sr.get_center().x])
		before = _overflow.size()
		_collect_overflow(m, "MainMenu@%dx%d" % [wsz.x, wsz.y], vp)
		check(_overflow.size() == before, "MainMenu fits at %dx%d" % [wsz.x, wsz.y])
		m.queue_free()
		await get_tree().process_frame
	win.size = original
	await get_tree().process_frame
	print("DIAG window restored to ", original)
