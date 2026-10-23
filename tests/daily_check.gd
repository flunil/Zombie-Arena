extends Node
## اختبار مرحلة 10: الصندوق اليومي + السلسلة + المهام — سحابي بلا محرر
## التشغيل: Godot --headless --path <project> res://tests/daily_check.tscn

var fails: Array[String] = []
var today := ""


func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		fails.append(label)
		print("FAIL: ", label)


func _ready() -> void:
	_run()


func _run() -> void:
	today = Time.get_date_string_from_system()
	# حالة نظيفة (تُستعاد نسخة احتياطية بعد الاختبار)
	SaveSystem.data = SaveSystem._defaults()
	SaveSystem._loaded = true

	# --- 1) أول تشغيل ---
	DailySystem._run_check("")
	check(int(SaveSystem.data["login_streak"]) == 1, "first boot -> streak=1")
	check(str(SaveSystem.data["last_login_date"]) == today, "last_login_date=today")
	var items: Array = SaveSystem.data["missions"]["items"]
	check(str(SaveSystem.data["missions"]["date"]) == today and items.size() == 3, "3 missions generated for today")
	check(DailySystem.can_claim(), "box claimable before claim")

	# --- 2) الصندوق مرة واحدة يومياً فقط ---
	var g1 := DailySystem.claim_reward()
	check(g1 > 0, "claim gives gems (%s)" % g1)
	var gems_after := int(SaveSystem.data["gems"])
	var g2 := DailySystem.claim_reward()
	check(g2 == 0 and int(SaveSystem.data["gems"]) == gems_after, "second claim same day blocked")
	check(not DailySystem.can_claim(), "can_claim false after claim")

	# --- 3) إعادة تشغيل نفس اليوم: السلسلة ثابتة + تقدم المهام محفوظ ---
	# مهام حتمية للاختبار (التوليد عشوائي من 5 قوالب)
	SaveSystem.data["missions"]["items"] = [
		_mk("kill50", 50, 10),
		_mk("boss5", 5, 15),
		_mk("waves3", 3, 8),
	]
	MissionSystem.record_kill("basic")
	MissionSystem.record_kill("basic")
	MissionSystem.record_kill("boss")
	check(int(_mission("kill50")["progress"]) == 3, "record_kill progresses kill50 (3 =.basic+.basic+.boss)")
	check(int(_mission("boss5")["progress"]) == 1, "boss kill progresses boss5 (1)")
	DailySystem._run_check("")
	check(int(SaveSystem.data["login_streak"]) == 1, "same-day reboot keeps streak=1")
	check(SaveSystem.data["missions"]["items"].size() == 3 and int(_mission("kill50")["progress"]) == 3,
		"same-day reboot keeps mission progress")

	# --- 4) يوم متتالي: streak+1 + توليد مهام جديدة ---
	SaveSystem.data["last_login_date"] = _n_days_ago(1)
	SaveSystem.data["login_streak"] = 1
	SaveSystem.data["missions"]["date"] = _n_days_ago(1)  # مهام البارحة
	DailySystem._run_check("")
	check(int(SaveSystem.data["login_streak"]) == 2, "consecutive day -> streak+1 (2)")
	check(SaveSystem.data["missions"]["items"].size() == 3, "missions regenerated on day change")
	var all_zero := true
	for it in SaveSystem.data["missions"]["items"]:
		if int(it.get("progress", 0)) != 0:
			all_zero = false
	check(all_zero, "missions reset on day change")

	# --- 5) انقطاع يوم واحد: لا يُصفَّر ---
	SaveSystem.data["last_login_date"] = _n_days_ago(2)
	SaveSystem.data["login_streak"] = 7
	DailySystem._run_check("")
	check(int(SaveSystem.data["login_streak"]) == 7, "1 missed day -> streak kept (7)")

	# --- 6) انقطاع يومين: يُصفَّر ---
	SaveSystem.data["last_login_date"] = _n_days_ago(3)
	SaveSystem.data["login_streak"] = 7
	DailySystem._run_check("")
	check(int(SaveSystem.data["login_streak"]) == 1, "2 missed days -> streak reset (1)")

	# --- 7) إكمال المهام → جواهر ---
	SaveSystem.data["missions"] = {"date": today, "items": [
		_mk("kill50", 50, 10),
		_mk("gold1000", 1000, 12),
		_mk("no_damage", 1, 10),
	]}
	var gems0 := int(SaveSystem.data["gems"])
	for i in 50:
		MissionSystem.record_kill("")
	check(bool(_mission("kill50")["done"]) and int(SaveSystem.data["gems"]) == gems0 + 10,
		"kill50 done -> +10 gems")
	check(int(_mission("kill50")["progress"]) == 50, "kill50 progress clamped at 50")
	for i in 10:
		MissionSystem.record_gold(100)
	check(bool(_mission("gold1000")["done"]) and int(SaveSystem.data["gems"]) == gems0 + 22,
		"gold1000 done -> +12 gems")

	MissionSystem.on_wave_started()
	MissionSystem.on_wave_cleared()
	check(bool(_mission("no_damage")["done"]) and int(SaveSystem.data["gems"]) == gems0 + 32,
		"no-damage wave -> +10 gems")

	SaveSystem.data["missions"] = {"date": today, "items": [_mk("no_damage", 1, 10)]}
	MissionSystem.on_wave_started()
	MissionSystem.on_player_damaged()
	MissionSystem.on_wave_cleared()
	check(not bool(_mission("no_damage")["done"]), "damaged wave NOT counted")

	# --- 8) Persistence بعد إعادة تحميل كامل ---
	SaveSystem.save()
	SaveSystem.data = {}
	SaveSystem._loaded = false
	SaveSystem.ensure_loaded()
	check(int(SaveSystem.data["login_streak"]) == 1, "reload: streak persists")
	check(int(SaveSystem.data["daily"]["day_idx"]) == 1, "reload: claim day_idx persists")
	check(SaveSystem.data["missions"].get("items", []).size() == 1, "reload: missions persist")

	# --- 9) الواجهتان تُبنى بلا أخطاء ---
	var dr := (load("res://scenes/ui/DailyReward.tscn") as PackedScene).instantiate()
	add_child(dr)
	await get_tree().process_frame
	var cards: int = dr.get_node("Center/Dialog/VBox/Days").get_child_count()
	check(cards == 7, "DailyReward builds 7 cards (got %s)" % cards)
	var mp := (load("res://scenes/ui/MissionPanel.tscn") as PackedScene).instantiate()
	add_child(mp)
	await get_tree().process_frame
	check(mp.get_node("Center/VBox/Rows").get_child_count() == 1, "MissionPanel rows match missions (1)")

	if fails.is_empty():
		print("CHECK_RESULT: ALL_PASS")
	else:
		print("CHECK_RESULT: FAIL_COUNT=", fails.size())
	get_tree().quit(0 if fails.is_empty() else 1)


func _mission(id: String) -> Dictionary:
	for it in SaveSystem.data["missions"].get("items", []):
		if str(it.get("id", "")) == id:
			return it
	return {"progress": 0, "done": false}


func _mk(id: String, target: int, gems: int) -> Dictionary:
	for t in MissionSystem.TEMPLATES:
		if str(t["id"]) == id:
			return {"id": id, "text": str(t["text"]), "target": target, "gems": gems, "progress": 0, "done": false}
	return {}


func _n_days_ago(n: int) -> String:
	# مرساة الظهيرة تتجنّب مشاكل منتصف الليل/التوقيت الصيفي
	var day_num := DailySystem._day_number(today) - n
	var dict := Time.get_datetime_dict_from_unix_time(float(day_num) * 86400.0 + 43200.0)
	return "%04d-%02d-%02d" % [dict["year"], dict["month"], dict["day"]]
