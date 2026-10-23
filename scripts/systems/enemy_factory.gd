class_name EnemyFactory
## توزيع أنواع الزومبي الستة حسب تقدّم الموجات — الستة كلها تظهر من الموجة 8
## (runner2 · exploder4 · shield6 · brute8 · boss كل 5 موجات من الموجة 5)


static func available_types(wave: int) -> Array[String]:
	var out: Array[String] = ["basic"]
	if wave >= 2:
		out.append("runner")
	if wave >= 4:
		out.append("exploder")
	if wave >= 6:
		out.append("shield")
	if wave >= 8:
		out.append("brute")
	return out


static func pick_type(wave: int) -> String:
	var types: Array[String] = available_types(wave)
	return types[randi() % types.size()]


static func is_boss_wave(wave: int) -> bool:
	return wave >= 5 and wave % 5 == 0
