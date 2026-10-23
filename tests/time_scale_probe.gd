extends Node
## اختبار سيناريو "الترقية الثالثة": موجة تنتهي بقتيل (hit_stop + slow_motion) ثم فتح القائمة
## الهدف: إثبات أن Engine.time_scale يعود 1.0 ولا تعلق اللعبة بـ Slow Motion

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
	await _wait_frames(3)
	var wm: Node = arena.get_node("WaveManager")
	if "_timer" in wm:
		wm.set("_timer", 99999.0)
	var usel: Node = arena.get_node("HUD").find_child("UpgradeSelection", true, false)

	print("=== TIME_SCALE SCENARIO PROBE ===")

	# سيناريو 1: قتيل (hit_stop) + نهاية موجة (slow_motion) في نفس اللحظة
	TimeFX.reset()
	TimeFX.hit_stop(0.06)
	TimeFX.slow_motion(0.3, 0.5)
	await _wait_seconds(1.5)
	check(is_equal_approx(Engine.time_scale, 1.0),
		"kill+wave_end overlap -> time_scale=1.0 (got %.3f)" % Engine.time_scale)

	# سيناريو 2: نفس الشيء لكن مع فتح القائمة في المنتصف (كما في اللعبة)
	TimeFX.reset()
	TimeFX.hit_stop(0.06)
	TimeFX.slow_motion(0.3, 0.5)
	await _wait_seconds(0.1)
	usel.call("_show_options")
	await _wait_frames(3)
	check(is_equal_approx(Engine.time_scale, 1.0),
		"opening menu mid-slow resets time_scale=1.0 (got %.3f)" % Engine.time_scale)
	# إغلاق القائمة
	usel.call("_hero_end")
	await _wait_frames(3)
	check(is_equal_approx(Engine.time_scale, 1.0),
		"after closing menu time_scale=1.0 (got %.3f)" % Engine.time_scale)

	# سيناريو 3: ثلاث دورات متتالية (كما في الترقيات الثلاث) مع قياس السرعة
	for i in 3:
		TimeFX.reset()
		TimeFX.hit_stop(0.06)
		TimeFX.slow_motion(0.3, 0.5)
		usel.call("_show_options")
		await _wait_frames(2)
		usel.call("_hero_end")
		await _wait_seconds(1.0)
		check(is_equal_approx(Engine.time_scale, 1.0),
			"cycle %d: time_scale=1.0 (got %.3f)" % [i + 1, Engine.time_scale])

	# سيناريو 4: تجميد متكرر (كل قنبلة) لا يعلّق السرعة
	TimeFX.reset()
	for i in 5:
		TimeFX.hit_stop(0.04)
	await _wait_seconds(0.5)
	check(is_equal_approx(Engine.time_scale, 1.0),
		"repeated hit_stop -> time_scale=1.0 (got %.3f)" % Engine.time_scale)

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
