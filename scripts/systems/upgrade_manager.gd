extends RefCounted
class_name UpgradeManager
## ترقيات الموجة: 48 ترقية (16 عادية/16 نادرة/16 ممتازة) + تطبيق فوري + حالة الجارية

## الندرة ونسب الظهور عند توليد كل بطاقة
const RARITY_NORMAL := 0  # أزرق 50%
const RARITY_RARE := 1    # ذهبي 30%
const RARITY_EPIC := 2    # بنفسجي 20%
const RARITY_WEIGHTS: Array[float] = [0.5, 0.3, 0.2]

const UPGRADE_PATHS: Array[String] = [
	"res://resources/upgrades/damage_boost.tres",
	"res://resources/upgrades/fire_rate_boost.tres",
	"res://resources/upgrades/ammo_boost.tres",
	"res://resources/upgrades/piercing.tres",
	"res://resources/upgrades/freeze.tres",
	"res://resources/upgrades/explosive_rounds.tres",
	"res://resources/upgrades/auto_heal.tres",
	"res://resources/upgrades/energy_shield.tres",
	"res://resources/upgrades/death_explosion.tres",
	"res://resources/upgrades/second_weapon.tres",
	"res://resources/upgrades/drone_ally.tres",
	"res://resources/upgrades/time_slow.tres",
	"res://resources/upgrades/move_speed.tres",
	"res://resources/upgrades/ammo_regen.tres",
	"res://resources/upgrades/crit_chance.tres",
	"res://resources/upgrades/lifesteal.tres",
	"res://resources/upgrades/multishot.tres",
	"res://resources/upgrades/shield_regen.tres",
	"res://resources/upgrades/max_health.tres",
	"res://resources/upgrades/reload_speed.tres",
	"res://resources/upgrades/bullet_speed.tres",
	"res://resources/upgrades/range_boost.tres",
	"res://resources/upgrades/dash_cd.tres",
	"res://resources/upgrades/gold_gain.tres",
	"res://resources/upgrades/armor_flat.tres",
	"res://resources/upgrades/regen_minor.tres",
	"res://resources/upgrades/spread_reduction.tres",
	"res://resources/upgrades/essence_gain.tres",
	"res://resources/upgrades/big_bullets.tres",
	"res://resources/upgrades/execution.tres",
	"res://resources/upgrades/thorns.tres",
	"res://resources/upgrades/heal_wave.tres",
	"res://resources/upgrades/freeze_mastery.tres",
	"res://resources/upgrades/explosive_mastery.tres",
	"res://resources/upgrades/chain_plus.tres",
	"res://resources/upgrades/dash_shield.tres",
	"res://resources/upgrades/crit_power.tres",
	"res://resources/upgrades/regen_mastery.tres",
	"res://resources/upgrades/triple_shot.tres",
	"res://resources/upgrades/berserker.tres",
	"res://resources/upgrades/quantum_shield.tres",
	"res://resources/upgrades/iron_skin.tres",
	"res://resources/upgrades/revive.tres",
	"res://resources/upgrades/drone_master.tres",
	"res://resources/upgrades/frenzy.tres",
	"res://resources/upgrades/swift_magazine.tres",
	"res://resources/upgrades/ultimate_ammo.tres",
	"res://resources/upgrades/titan_pierce.tres",
]

static var _cache: Array[UpgradeResource] = []
static var acquired: Dictionary = {}  # id → عدد مرات الاكتساب
static var _revive_used := false  # ترقية Revive: مرة واحدة في الموجة
static var _by_rarity_cache: Dictionary = {}  # rarity → Array[UpgradeResource]


static func reset_run() -> void:
	acquired.clear()
	_revive_used = false


static func all_upgrades() -> Array[UpgradeResource]:
	if _cache.is_empty():
		for p in UPGRADE_PATHS:
			var r: Resource = load(p)
			if r is UpgradeResource:
				_cache.append(r)
		# بناء مسبقة حسب الندرة
		_by_rarity_cache.clear()
		for rr in [RARITY_NORMAL, RARITY_RARE, RARITY_EPIC]:
			_by_rarity_cache[rr] = []
		for u in _cache:
			var rr2 := int(u.rarity)
			if _by_rarity_cache.has(rr2):
				(_by_rarity_cache[rr2] as Array).append(u)
	return _cache


static func _get_by_rarity(rarity: int) -> Array:
	if _by_rarity_cache.is_empty():
		all_upgrades()
	var arr = _by_rarity_cache.get(rarity, [])
	if arr.is_empty():
		return []
	return arr


static func has(id: String) -> bool:
	return count_of(id) > 0


static func count_of(id: String) -> int:
	return int(acquired.get(id, 0))


## 3 خيارات عشوائية — كل بطاقة تُولَّد بندرتها (أزرق 50% / ذهبي 30% / بنفسجي 20%)،
## فريدة داخل الشاشة، والغير متكررة المملوكة مستبعدة، مع احتياطي إن نفد نادر فئة.
static func pick_three() -> Array[UpgradeResource]:
	var out: Array[UpgradeResource] = []
	var used: Dictionary = {}
	for i in 3:
		var rarity := _roll_rarity()
		var pool_arr := _get_by_rarity(rarity)
		var pick := _pick_from_array(pool_arr, used)
		if pick == null:
			# نفد الفئة → ممتاز ثم نادر ثم عادي
			for rr in [RARITY_EPIC, RARITY_RARE, RARITY_NORMAL]:
				pick = _pick_from_array(_get_by_rarity(rr), used)
				if pick != null:
					break
		if pick == null:
			break  # لم يتبقَّ شيء متاح
		used[pick.upgrade_id] = true
		out.append(pick)
	return out


static func _pick_from_array(arr: Array, used: Dictionary) -> UpgradeResource:
	# فحص سريع بدون نسخ مصفوفة كاملة
	var attempts := 0
	var size := arr.size()
	while attempts < size:
		var idx := randi() % size
		var u := arr[idx] as UpgradeResource
		if u != null and not used.has(u.upgrade_id) and (not has(u.upgrade_id) or u.stackable):
			return u
		attempts += 1
	# fallback: مسح كامل
	for u in arr:
		if u is UpgradeResource and not used.has((u as UpgradeResource).upgrade_id):
			var ur := u as UpgradeResource
			if has(ur.upgrade_id) and not ur.stackable:
				continue
			return ur
	return null


## ندرة واحدة بالتوزيع: عادي 50% / نادر 30% / ممتاز 20%
static func _roll_rarity() -> int:
	var roll := randf()
	if roll < RARITY_WEIGHTS[RARITY_NORMAL]:
		return RARITY_NORMAL
	if roll < RARITY_WEIGHTS[RARITY_NORMAL] + RARITY_WEIGHTS[RARITY_RARE]:
		return RARITY_RARE
	return RARITY_EPIC


static func rarity_color(rarity: int) -> Color:
	match rarity:
		RARITY_RARE:
			return Color(1.0, 0.78, 0.22, 1.0)  # ذهبي
		RARITY_EPIC:
			return Color(0.72, 0.35, 1.0, 1.0)  # بنفسجي
	return Color(0.3, 0.65, 1.0, 1.0)  # أزرق


static func rarity_name(rarity: int) -> String:
	match rarity:
		RARITY_RARE:
			return "Rare"
		RARITY_EPIC:
			return "Epic"
	return "Common"


## ندرة ترقية بمعرفها (للإضاءة اللونية عند الاختيار)
static func rarity_of(id: String) -> int:
	for u in all_upgrades():
		if u.upgrade_id == id:
			return int(u.rarity)
	return RARITY_NORMAL


## تطبيق فوري عند اختيار اللاعب
static func apply_upgrade(id: String) -> void:
	acquired[id] = count_of(id) + 1
	match id:
		"energy_shield":
			var h := _player_health()
			if h != null:
				h.shield += 30.0
		"second_weapon":
			_unlock_random_weapon()
		"drone_ally":
			_spawn_drone()
		"time_slow":
			apply_time_slow()  # فوري (إن كان زومبياً حياً) + يعاد عند بدء الموجة
		"max_health":
			var mh := _player_health()
			if mh != null:
				mh.max_health += 20.0
				mh.health = minf(mh.max_health, mh.health + 20.0)


## مضاعفات الأسلحة (تقرأ من weapon_base)
static func get_damage_mult() -> float:
	var m := 1.0 + 0.15 * count_of("damage_boost")
	if has("berserker"):  # ممتاز: ضرر أعلى كلما قلّت الصحة (حتى ×1.5 عند الصفر)
		var h := _player_health()
		if h != null and h.max_health > 0.0:
			var hp_pct := clampf(h.health / h.max_health, 0.0, 1.0)
			m *= 1.0 + 0.5 * (1.0 - hp_pct)
	return m


static func get_fire_rate_mult() -> float:
	return 1.0 + 0.12 * count_of("fire_rate_boost") + 0.3 * count_of("frenzy")


static func get_ammo_mult() -> float:
	return 1.0 + 0.25 * count_of("ammo_boost") + 1.0 * count_of("ultimate_ammo")


static func get_pierce_bonus() -> int:
	return count_of("piercing") + 3 * count_of("titan_pierce")


static func roll_freeze() -> bool:
	if not has("freeze"):
		return false
	var chance := 0.1 * count_of("freeze")
	if has("freeze_mastery"):  # نادر: يتضاعف فرصة التجميد
		chance *= 2.0
	return randf() < chance


static func has_explosive_rounds() -> bool:
	return has("explosive_rounds")


static func get_auto_heal_rate() -> float:
	return 2.0 * count_of("auto_heal") + 0.5 * count_of("regen_minor") + 1.0 * count_of("regen_mastery")


static func has_death_explosion() -> bool:
	return has("death_explosion")


static func has_time_slow() -> bool:
	return has("time_slow")


## ترقيات جديدة — تُقرأ من player/weapon_base/health_component
static func get_move_speed_mult() -> float:
	return 1.0 + 0.12 * count_of("move_speed")


static func get_ammo_regen_rate() -> float:
	return 1.0 * count_of("ammo_regen")  # ذخيرة/ثانية لكل تكرار


static func roll_crit() -> bool:
	# crit_chance (نادر) 15%/مستوى + crit_power (نادر) 10% مستقلة حتى بلا chance
	var chance := 0.15 * count_of("crit_chance") + 0.1 * count_of("crit_power")
	return chance > 0.0 and randf() < chance


static func get_crit_mult() -> float:
	return 2.0 + 0.5 * count_of("crit_power")  # ×2 أساسي → ×2.5 لكل CritPower


static func get_lifesteal_heal() -> float:
	return 2.0 * count_of("lifesteal")  # حياة عند كل قتل


static func get_multishot_bonus() -> int:
	return count_of("multishot") + 2 * count_of("triple_shot")  # طلقات متباعدة


static func has_shield_regen() -> bool:
	return has("shield_regen")


## ترقيات الدفعة الثانية (10 لكل فئة) — تُقرأ من player/weapon_base/health/zombie/wave
static func get_reload_mult() -> float:
	return maxf(0.1, 1.0 - 0.2 * count_of("reload_speed") - 0.5 * count_of("swift_magazine"))


static func get_bullet_speed_mult() -> float:
	return 1.0 + 0.2 * count_of("bullet_speed")


static func get_range_mult() -> float:
	return 1.0 + 0.25 * count_of("range_boost")


static func get_dash_cd_mult() -> float:
	return maxf(0.2, 1.0 - 0.2 * count_of("dash_cd"))


static func get_gold_mult() -> float:
	return 1.0 + 0.25 * count_of("gold_gain")


static func roll_essence_bonus() -> bool:
	return randf() < 0.2 * count_of("essence_gain")


static func get_spread_mult() -> float:
	return maxf(0.25, 1.0 - 0.25 * count_of("spread_reduction"))


static func roll_execution() -> bool:
	return has("execution") and randf() < 0.1 * count_of("execution")


static func get_thorns_damage(attack: float) -> float:
	return 0.3 * attack * count_of("thorns")  # يُستدعى من هجوم الزومبي بالضرر الأصلي


static func get_wave_heal() -> float:
	return 5.0 * count_of("heal_wave")


static func get_blast_bonus() -> float:
	return 1.0 * count_of("explosive_mastery")


static func get_chain_bonus() -> int:
	return count_of("chain_plus")


static func get_bullet_scale_mult() -> float:
	return 1.0 + 0.5 * count_of("big_bullets")


static func get_big_bullets_dmg_mult() -> float:
	return 1.0 + 0.1 * count_of("big_bullets")


static func get_drone_dmg_mult() -> float:
	return 1.0 + 0.5 * count_of("drone_master")


static func heal_player(amount: float) -> void:
	var h := _player_health()
	if h != null:
		h.heal(amount)


## انبعاث (ممتاز): مرة واحدة في كل موجة
static func consume_revive() -> bool:
	if not has("revive") or _revive_used:
		return false
	_revive_used = true
	return true


## يُستدعى من WaveManager عند بدء كل موجة
static func on_wave_started() -> void:
	_revive_used = false
	apply_time_slow()  # TimeSlow: إبطاء 5ث إن كان مملوكاً


## TimeSlow: إبطاء كل الزومبي الحاليين 30% لمدة 5ث — يُستدعى عند بدء الموجة
static func apply_time_slow() -> void:
	if not has_time_slow():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	for c in tree.current_scene.get_children():
		if c.has_method("apply_slow"):
			c.apply_slow(0.7, 5.0)


static func _unlock_random_weapon() -> void:
	var locked: Array[String] = []
	for id in ["shotgun", "heavymg", "grenadelauncher", "flamethrower", "teslacoil", "rocketlauncher", "smokelauncher", "laserifle"]:
		if not UnlockSystem.is_unlocked(id):
			locked.append(id)
	if locked.is_empty():
		return
	locked.shuffle()
	var picked: String = locked[0]
	if UnlockSystem.unlock_weapon(picked):
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.current_scene != null:
			var wm_node := tree.current_scene.get_node_or_null("Player/WeaponManager")
			if wm_node != null and wm_node.has_signal("weapons_unlocked"):
				wm_node.weapons_unlocked.emit([picked])


static func _spawn_drone() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	if tree.current_scene.get_node_or_null("DroneAlly") != null:
		return  # روبوت واحد فقط
	var drone := Node3D.new()
	drone.name = "DroneAlly"
	drone.set_script(load("res://scripts/player/drone.gd"))
	tree.current_scene.add_child(drone)


static func _player_health() -> HealthComponent:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("Player/Health") as HealthComponent
