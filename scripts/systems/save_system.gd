class_name SaveSystem
## حفظ/تحميل التقدم الدائم — user://save.dat مع تشفير XOR بسيط

const SAVE_PATH: String = "user://save.dat"
const XOR_KEY: String = "zombie-arena-xor-2026"

const UPGRADE_PATHS: Array[String] = ["health", "speed", "damage", "ammo"]
const MAX_LEVEL: int = 5
const BASE_COSTS: Dictionary = {
	"health": 100,
	"speed": 150,
	"damage": 200,
	"ammo": 150,
}
const WEAPON_MAX_LEVEL: int = 10
const WEAPON_STAT_DEFS: Dictionary = {
	"damage": {"base_cost": 50, "mult": 0.12, "name": "Damage"},
	"fire_rate": {"base_cost": 40, "mult": 0.08, "name": "Fire Rate"},
	"range": {"base_cost": 60, "mult": 0.06, "name": "Range"},
	"ammo": {"base_cost": 45, "mult": 0.15, "name": "Ammo"},
}

static var data: Dictionary = {}
static var _loaded: bool = false

## حفظ مؤجّل: كتابة القرص مكلفة (XOR+JSON+فتح ملف) — تراكمها عند كل قتل يُبطئ الإطارات.
## نعلّم التغيير وندّخر الكتابة لتعمل مرة كل SAVE_THROTTLE_MS بدل كل قتل.
static var _dirty: bool = false
static var _last_save_ms: int = 0
const SAVE_THROTTLE_MS: int = 1500


static func _defaults() -> Dictionary:
	return {
		"gold": 0,
		"gems": 0,
		"unlocked_weapons": ["ak47"],
		"selected_weapon": "",
		"permanent_upgrades": {"health": 0, "speed": 0, "damage": 0, "ammo": 0},
		"weapon_upgrades": {},
		"stats": {
			"total_kills": 0,
			"total_waves": 0,
			"total_gold_earned": 0,
			"shots_fired": 0,
			"shots_hit": 0,
			"playtime": 0.0,
		},
		"last_login_date": "",
		"login_streak": 0,
		"missions": {"date": "", "items": []},
		"daily": {"last_claim": "", "day_idx": 0},
	}


## تحميل أولي (يدمج الحقول الجديدة مع الافتراضي)
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	data = _defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_buffer(f.get_length())
	f.close()
	var parsed: Variant = JSON.parse_string(_xor_decode(raw))
	if parsed is Dictionary:
		for k in data.keys():
			if parsed.has(k):
				data[k] = parsed[k]


## حفظ فوري — يُستخدم عند الشراء/التغييرات المهمة فقط
static func save() -> void:
	ensure_loaded()
	_dirty = false
	_last_save_ms = Time.get_ticks_msec()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(_xor_encode(JSON.stringify(data)))
	f.close()


## حفظ مؤجّل — يستخدمه المسارات المتكررة (كل قتل/ذهب): يعلّم التغيير
## ويدّخر الكتابة الفعلية لتعمل مرة كل SAVE_THROTTLE_MS بدل كل حدث.
static func save_deferred() -> void:
	_dirty = true
	if Time.get_ticks_msec() - _last_save_ms >= SAVE_THROTTLE_MS:
		save()


## يكتب فورًا إن كان هناك تغيير معلّق — يُستدعى عند نهاية الموجة/القائمة/الإغلاق
## لضمان عدم فقد أي تقدّم.
static func flush() -> void:
	if _dirty:
		save()


static func _xor_bytes(src: PackedByteArray) -> PackedByteArray:
	var key := XOR_KEY.to_utf8_buffer()
	var out := PackedByteArray()
	out.resize(src.size())
	for i in src.size():
		out[i] = src[i] ^ key[i % key.size()]
	return out


static func _xor_encode(text: String) -> PackedByteArray:
	return _xor_bytes(text.to_utf8_buffer())


static func _xor_decode(raw: PackedByteArray) -> String:
	return _xor_bytes(raw).get_string_from_utf8()


# ======================== الذهب ========================

static func get_gold() -> int:
	ensure_loaded()
	return int(data["gold"])


## كسب ذهب: يزيد الرصيد + الإجمالي المكتسب ثم يحفظ مؤجّلًا (يُستدعى كل قتل — لا نكتب القرص كل مرة)
static func earn_gold(amount: int) -> void:
	ensure_loaded()
	data["gold"] = int(data["gold"]) + amount
	var s: Dictionary = data["stats"]
	s["total_gold_earned"] = int(s.get("total_gold_earned", 0)) + amount
	save_deferred()


static func spend_gold(amount: int) -> bool:
	ensure_loaded()
	if int(data["gold"]) < amount:
		return false
	data["gold"] = int(data["gold"]) - amount
	save()
	return true


# ==================== الترقيات الدائمة ====================

static func get_level(path: String) -> int:
	ensure_loaded()
	var ups: Dictionary = data["permanent_upgrades"]
	return int(ups.get(path, 0))


## تكلفة المستوى التالي: الأساس × (المستوى + 1)
static func get_cost(path: String) -> int:
	return int(BASE_COSTS.get(path, 100)) * (get_level(path) + 1)


## شراء مستوى — يرفض بلا ذهب كافٍ أو عند القمة
static func buy(path: String) -> bool:
	ensure_loaded()
	if path not in UPGRADE_PATHS:
		return false
	var lvl := get_level(path)
	if lvl >= MAX_LEVEL:
		return false
	var cost := int(BASE_COSTS[path]) * (lvl + 1)
	if int(data["gold"]) < cost:
		return false
	data["gold"] = int(data["gold"]) - cost
	var ups: Dictionary = data["permanent_upgrades"]
	ups[path] = lvl + 1
	save()
	return true


static func get_health_bonus() -> int:
	return get_level("health") * 20


static func get_speed_mult() -> float:
	return 1.0 + get_level("speed") * 0.05


static func get_damage_mult() -> float:
	return 1.0 + get_level("damage") * 0.10


static func get_ammo_mult() -> float:
	return 1.0 + get_level("ammo") * 0.15


# ==================== الأسلحة المفتوحة ====================

static func get_unlocked_weapons() -> Array[String]:
	ensure_loaded()
	var out: Array[String] = []
	for id in data["unlocked_weapons"]:
		out.append(str(id))
	if out.is_empty():
		out.append("ak47")
	return out


static func record_unlock(weapon_id: String) -> void:
	ensure_loaded()
	var arr: Array = data["unlocked_weapons"]
	if weapon_id not in arr:
		arr.append(weapon_id)
		save()


# ==================== السلاح المختار لبدء الجولة ====================

## السلاح المختار من صفحة قائمة الأسلحة (فارغ = أول سلاح مفتوح)
static func get_selected_weapon() -> String:
	ensure_loaded()
	return str(data.get("selected_weapon", ""))


static func set_selected_weapon(weapon_id: String) -> void:
	ensure_loaded()
	data["selected_weapon"] = weapon_id
	save()


# ==================== ترقيات الأسلحة ====================

static func get_weapon_upgrade(weapon_id: String, stat: String) -> int:
	ensure_loaded()
	var ups: Dictionary = data.get("weapon_upgrades", {})
	var w: Dictionary = ups.get(weapon_id, {})
	return int(w.get(stat, 0))


static func get_weapon_upgrade_cost(weapon_id: String, stat: String) -> int:
	var lvl := get_weapon_upgrade(weapon_id, stat)
	if lvl >= WEAPON_MAX_LEVEL:
		return -1
	var defs: Dictionary = WEAPON_STAT_DEFS.get(stat, {})
	var base := int(defs.get("base_cost", 50))
	return int(base * (1.0 + 0.45 * lvl))


static func buy_weapon_upgrade(weapon_id: String, stat: String) -> bool:
	ensure_loaded()
	var cost := get_weapon_upgrade_cost(weapon_id, stat)
	if cost < 0 or int(data["gold"]) < cost:
		return false
	data["gold"] = int(data["gold"]) - cost
	if "weapon_upgrades" not in data:
		data["weapon_upgrades"] = {}
	if weapon_id not in data["weapon_upgrades"]:
		data["weapon_upgrades"][weapon_id] = {}
	var w: Dictionary = data["weapon_upgrades"][weapon_id]
	w[stat] = get_weapon_upgrade(weapon_id, stat) + 1
	save()
	return true


static func get_weapon_stat_mult(weapon_id: String, stat: String) -> float:
	var lvl := get_weapon_upgrade(weapon_id, stat)
	var defs: Dictionary = WEAPON_STAT_DEFS.get(stat, {})
	return 1.0 + lvl * float(defs.get("mult", 0.1))


static func get_weapon_overall_level(weapon_id: String) -> int:
	var total := 0
	for stat in WEAPON_STAT_DEFS.keys():
		total += get_weapon_upgrade(weapon_id, stat)
	return total


# ==================== الإحصائيات ====================

static func stats() -> Dictionary:
	ensure_loaded()
	return data["stats"]


## زيادة إحصائية — persist=false للحقول المتكررة (playtime) تُحفظ لاحقاً مع الأحداث
static func add_stat(key: String, amount: float, persist: bool = true) -> void:
	ensure_loaded()
	var s: Dictionary = data["stats"]
	s[key] = float(s.get(key, 0.0)) + amount
	if persist:
		save()
