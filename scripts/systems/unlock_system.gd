class_name UnlockSystem
## فتح الأسلحة حسب الموجة — ساكن بالكامل، يُستدعى من WeaponManager

const DEFAULT_UNLOCKED: Array[String] = ["ak47"]

static var unlocked: Array[String] = ["ak47"]


## فتح سلاح — يعيد true إذا كان فتحاً جديداً (ويُحفظ بشكل دائم)
static func unlock_weapon(weapon_id: String) -> bool:
	if weapon_id in unlocked:
		return false
	unlocked.append(weapon_id)
	SaveSystem.record_unlock(weapon_id)
	return true


static func is_unlocked(weapon_id: String) -> bool:
	return weapon_id in unlocked


## تُستدعى عند بداية كل موجة — تفتح ما بلغ شرطه وتُرجع المُفتح حديثاً
static func on_wave_started(wave: int, all_weapons: Array) -> Array[String]:
	var newly: Array[String] = []
	for data in all_weapons:
		if data is WeaponResource and not is_unlocked(data.weapon_id):
			if int(data.unlock_wave) <= wave:
				unlocked.append(data.weapon_id)
				SaveSystem.record_unlock(data.weapon_id)
				newly.append(data.weapon_id)
	return newly


## إعادة تعيين عند بدء جولة جديدة — تستعيد المحفوظ من SaveSystem
static func reset() -> void:
	unlocked = SaveSystem.get_unlocked_weapons()
