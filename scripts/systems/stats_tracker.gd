class_name StatsTracker
## تتبّع الإحصائيات الدائمة — يكتب في SaveSystem ثم تُحفظ مع الأحداث


static func record_kill() -> void:
	SaveSystem.add_stat("total_kills", 1.0, false)


static func record_wave() -> void:
	SaveSystem.add_stat("total_waves", 1.0, false)
	SaveSystem.save()


static func record_shot() -> void:
	SaveSystem.add_stat("shots_fired", 1.0, false)


static func record_hit() -> void:
	SaveSystem.add_stat("shots_hit", 1.0, false)


## زمن اللعب بالثواني — بلا حفظ لكل إطار (يُحفظ مع الأحداث)
static func tick(delta: float) -> void:
	SaveSystem.add_stat("playtime", delta, false)


static func get_accuracy() -> float:
	var s := SaveSystem.stats()
	var fired := float(s.get("shots_fired", 0.0))
	if fired <= 0.0:
		return 0.0
	return clampf(float(s.get("shots_hit", 0.0)) / fired, 0.0, 1.0)


static func get_playtime() -> float:
	return float(SaveSystem.stats().get("playtime", 0.0))


## حفظ دفعة (يُستدعى عند أحداث مهمة)
static func flush() -> void:
	SaveSystem.save()
