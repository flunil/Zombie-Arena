class_name DailySystem
## الأنظمة اليومية: فحص التاريخ عند بدء التشغيل + سلسلة الأيام + الصندوق اليومي

const REWARDS_GEMS: Array[int] = [5, 8, 10, 15, 20, 25, 50]  # مكافآت الأيام السبعة (شفافية)

static var _checked: bool = false  # فحص واحد لكل تشغيل


## يُستدعى مرة واحدة عند بدء التشغيل (GM._ready)
static func check_on_boot(today: String = "") -> void:
	if _checked:
		return
	_checked = true
	_run_check(today)


## النواة (قابلة للاختبار مباشرة بتجاوز حارس التشغيل)
static func _run_check(today: String) -> void:
	SaveSystem.ensure_loaded()
	if today == "":
		today = Time.get_date_string_from_system()
	var last := str(SaveSystem.data.get("last_login_date", ""))
	if last != today:
		var diff := _day_diff(last, today)
		var streak := int(SaveSystem.data.get("login_streak", 0))
		if last == "" or diff >= 3 or diff <= 0:
			streak = 1            # أول تشغيل / انقطاع يومين فأكثر / تاريخ غير صالح
		elif diff == 1:
			streak += 1           # يوم متتالي → +
		# diff == 2: انقطاع يوم واحد → تُبقي السلسلة كما هي (لا تُصفَّر)
		SaveSystem.data["login_streak"] = streak
		SaveSystem.data["last_login_date"] = today
		SaveSystem.save()
	# المهام: تُولَّد إن كان تاريخها مختلفاً عن اليوم
	MissionSystem.ensure_today()


## الصندوق: متاح مرة واحدة يومياً فقط
static func can_claim() -> bool:
	SaveSystem.ensure_loaded()
	return str(SaveSystem.data["daily"].get("last_claim", "")) != Time.get_date_string_from_system()


## استلام صندوق اليوم — يرجع الجواهر الممنوحة، أو 0 إن كان مُستلماً بالفعل
static func claim_reward() -> int:
	SaveSystem.ensure_loaded()
	var today := Time.get_date_string_from_system()
	var d: Dictionary = SaveSystem.data["daily"]
	if str(d.get("last_claim", "")) == today:
		return 0
	var idx := int(d.get("day_idx", 0)) % REWARDS_GEMS.size()
	var gems := int(REWARDS_GEMS[idx])
	d["day_idx"] = (idx + 1) % REWARDS_GEMS.size()
	d["last_claim"] = today
	SaveSystem.data["gems"] = int(SaveSystem.data["gems"]) + gems
	SaveSystem.save()
	return gems


## رقم يوم مستقل (لحساب الفارق بآمنية عبر منتصف الليل/التوقيت الصيفي)
## خوارزمية Rata Die (Hinnant): تاريخ مدني ← عدد أيام — حساب نقي بلا اعتماد على الساعة
static func _day_number(date_str: String) -> int:
	var p := date_str.split("-")
	if p.size() != 3:
		return -1
	var y := int(p[0])
	var m := int(p[1])
	var d := int(p[2])
	if m <= 2:
		y -= 1
		m += 12
	m -= 3
	@warning_ignore("integer_division")  # قسمة صحيحة مقصودة (خوارزمية Hinnant)
	var era: int = y / 400
	var yoe: int = y - era * 400
	@warning_ignore("integer_division")
	var doy: int = (153 * m + 2) / 5 + d - 1
	@warning_ignore("integer_division")
	var doe: int = yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


## الفارق بالأيام: to - from (يُرجع -1 عند خطأ)
static func _day_diff(from_date: String, to_date: String) -> int:
	if from_date == "" or to_date == "":
		return -1
	return _day_number(to_date) - _day_number(from_date)
