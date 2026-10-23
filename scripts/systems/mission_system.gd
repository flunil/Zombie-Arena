class_name MissionSystem
## المهام اليومية: 3 من 5 قوالب — تتبع تلقائي + جواهر فورية عند الإكمال

const TEMPLATES: Array[Dictionary] = [
	{"id": "kill50", "text": "Kill 50 zombies", "target": 50, "gems": 10},
	{"id": "waves3", "text": "Clear 3 waves", "target": 3, "gems": 8},
	{"id": "gold1000", "text": "Collect 1000 gold", "target": 1000, "gems": 12},
	{"id": "boss5", "text": "Kill 5 bosses", "target": 5, "gems": 15},
	{"id": "no_damage", "text": "Clear a wave without taking damage", "target": 1, "gems": 10},
]

static var _wave_active: bool = false
static var _wave_damaged: bool = false


## توليد مهام اليوم إن كان تاريخها مختلفاً (يُستدعى من DailySystem)
static func ensure_today() -> void:
	SaveSystem.ensure_loaded()
	var today := Time.get_date_string_from_system()
	var m: Dictionary = SaveSystem.data["missions"]
	var items: Array = m.get("items", [])
	if str(m.get("date", "")) == today and items.size() > 0:
		return
	var pool: Array = TEMPLATES.duplicate()
	pool.shuffle()
	items = []
	for i in range(mini(3, pool.size())):
		var t: Dictionary = pool[i]
		items.append({
			"id": str(t["id"]),
			"text": str(t["text"]),
			"target": int(t["target"]),
			"gems": int(t["gems"]),
			"progress": 0,
			"done": false,
		})
	m["date"] = today
	m["items"] = items
	SaveSystem.save()


static func get_missions() -> Array:
	SaveSystem.ensure_loaded()
	var items: Array = SaveSystem.data["missions"].get("items", [])
	return items


## قتل زومبي — type_id من meta "pool_type" (الزعيم = "boss")
static func record_kill(type_id: String = "") -> void:
	_bump("kill50", 1)
	if type_id == "boss":
		_bump("boss5", 1)


static func record_wave() -> void:
	_bump("waves3", 1)


static func record_gold(amount: int) -> void:
	_bump("gold1000", amount)


# ==================== موجة بدون ضرر ====================

static func on_wave_started() -> void:
	_wave_active = true
	_wave_damaged = false


static func on_player_damaged() -> void:
	if _wave_active:
		_wave_damaged = true


static func on_wave_cleared() -> void:
	if _wave_active and not _wave_damaged:
		_bump("no_damage", 1)
	_wave_active = false
	_wave_damaged = false


## زيادة تقدم مهمة — عند بلوغ الهدف: done + منح الجواهر فوراً
static func _bump(id: String, amount: int) -> void:
	if amount <= 0:
		return
	SaveSystem.ensure_loaded()
	var items: Array = SaveSystem.data["missions"].get("items", [])
	for it in items:
		if str(it.get("id", "")) != id or bool(it.get("done", false)):
			continue
		it["progress"] = int(it["progress"]) + amount
		if int(it["progress"]) >= int(it["target"]):
			it["progress"] = int(it["target"])
			it["done"] = true
			SaveSystem.data["gems"] = int(SaveSystem.data["gems"]) + int(it["gems"])
		SaveSystem.save_deferred()  # يُستدعى كل قتل ذهب — حفظ مؤجّل يمنع بطء القرص
		return
