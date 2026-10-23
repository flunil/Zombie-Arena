extends Node
## اختبار المرحلة 12 — إعدادات الهاتف + أزرار اللمس 44px+ + ضوء ظل واحد + LOD يدوي

var _fails: int = 0
var _passes: int = 0


func check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _ready() -> void:
	await get_tree().process_frame
	_test_project_settings()
	await _test_all_ui_button_sizes()
	await _test_lod()
	await _test_arena_shadow_and_touch()
	print("CHECK_RESULT: ", "ALL_PASS" if _fails == 0 else "FAIL_COUNT=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


## إعدادات project.godot المطلوبة للهاتف
func _test_project_settings() -> void:
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?") == "mobile",
		"renderer = mobile")
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "?") == "mobile",
		"renderer.mobile = mobile")
	check(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", -1) == 0,
		"MSAA 3D = 0 (ميزانية الأداء — إصلاح اللاقط أوقف MSAA)")
	check(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", -1) == 0,
		"MSAA 2D disabled")
	check(ProjectSettings.get_setting("rendering/shadows/quality/directional_shadow_atlas_size", -1) == 1024,
		"directional shadow atlas = 1024 (رفع جودة مطلوب)")
	check(ProjectSettings.get_setting("rendering/shadows/quality/soft_shadow_filter_quality", -1) == 0,
		"soft shadow filter = hard (0) — ظلال حادّة كرتونية")
	check(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", false) == true,
		"ETC2/ASTC texture compression enabled (أندرويد)")


## كل أزرار واجهات اللمس: 44px+ (معيار الحد الأدنى للمس)
func _test_all_ui_button_sizes() -> void:
	var scenes := [
		"res://scenes/ui/MainMenu.tscn",
		"res://scenes/ui/GameOverScreen.tscn",
		"res://scenes/ui/UpgradeSelection.tscn",
		"res://scenes/ui/MissionPanel.tscn",
		"res://scenes/ui/MetaUpgradeShop.tscn",
		"res://scenes/ui/DailyReward.tscn",
	]
	for path in scenes:
		var packed: PackedScene = load(path)
		if packed == null:
			check(false, "load %s" % path)
			continue
		var inst: Node = packed.instantiate()
		add_child(inst)
		await get_tree().process_frame
		await get_tree().process_frame
		var bad: Array[String] = []
		var total: int = 0
		for n in inst.find_children("*", "Button", true, false):
			var b := n as Button
			if b == null:
				continue
			total += 1
			var h: float = maxf(b.custom_minimum_size.y, b.size.y)
			if h < 44.0:
				bad.append("%s(%.0f)" % [b.name, h])
		if total == 0:
			check(true, "%s: no buttons (skip)" % path.get_file())
		else:
			check(bad.is_empty(), "%s: all buttons >= 44px (got %d, bad: %s)" % [
				path.get_file(), total, ", ".join(bad) if not bad.is_empty() else "-"])
		inst.queue_free()
	await get_tree().process_frame


## LOD يدوي: زومبي قريب (ظل+شريط) ↔ بعيد (>30م: ظل مطفأ + شريط مخفي)
func _test_lod() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 10, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	var zc: PackedScene = load("res://scenes/enemies/ZombieBasic.tscn")
	var z: Node3D = zc.instantiate()
	add_child(z)
	z.position = Vector3.ZERO  # المسافة إلى الكاميرا = 10م < 30
	await get_tree().create_timer(0.7).timeout
	var body := z.get_node_or_null("BodyMesh") as MeshInstance3D
	if body == null:
		# بلا صندوق قديم (حُذف BodyMesh من ZombieBasic): أول شبكة داخل المجسم المرئي (FBX عبر _visual)
		var meshes: Array = z.find_children("*", "MeshInstance3D", true, false)
		if meshes.size() > 0:
			body = meshes[0] as MeshInstance3D
	var bar := z.get_node_or_null("HealthBar")
	check(body != null and body.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"LOD قريب: الظل مُفعّل")
	z.position = Vector3(60, 0, 0)  # المسافة ≈ 61م > 30
	await get_tree().create_timer(0.7).timeout
	check(body != null and body.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"LOD بعيد: الظل مُطفأ")
	check(bar != null and not bar.visible, "LOD بعيد: شريط الصحة مخفي")
	z.position = Vector3.ZERO
	await get_tree().create_timer(0.7).timeout
	check(body != null and body.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"LOD رجع قريب: الظل عاد")
	check(bar != null and bar.visible, "LOD رجع قريب: الشريط عاد")
	z.queue_free()
	cam.queue_free()
	await get_tree().process_frame


## في الساحة: لا ظلال حية (تعطيل ظل الشمس — تقنية تحسين الأداء من الفيديو) + joystick بمقاس لمس + شريط الأسلحة مُزال (طلب المستخدم)
func _test_arena_shadow_and_touch() -> void:
	var arena: Node = load("res://scenes/main/Arena.tscn").instantiate()
	add_child(arena)
	await get_tree().create_timer(1.0).timeout

	var casting: int = 0
	for n in arena.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l != null and l.shadow_enabled:
			casting += 1
	check(casting == 0, "Arena: no realtime shadow casters (got %d)" % casting)

	var wbar: Control = arena.find_child("WeaponBar", true, false) as Control
	check(wbar == null, "Arena: WeaponBar removed (no weapon-switch buttons)")

	var joy: Control = arena.find_child("VirtualJoystick", true, false) as Control
	check(joy != null and joy.custom_minimum_size.x >= 200.0,
		"virtual joystick size >= 200px (got %s)" % (str(joy.custom_minimum_size.x) if joy != null else "missing"))

	arena.queue_free()
