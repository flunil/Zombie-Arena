extends Node
## اختبار وظيفي لورشة الأسلحة: شراء ترقية / تجهيز / ذهب غير كافٍ / أقصى / مقفل / تمرير
## + ملاءمة نافذة 536×954 (stretch viewport يبقي التصميم 720×1280)

var _fails: int = 0


func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _ready() -> void:
	await get_tree().process_frame
	SaveSystem.ensure_loaded()
	# سجل تجريبي حتمي (يُستعاد save.dat من النسخة الاحتياطية بعد الاختبار خارجيًا)
	SaveSystem.data["gold"] = 10000
	SaveSystem.data["unlocked_weapons"] = ["ak47", "shotgun"]
	SaveSystem.data["weapon_upgrades"] = {}
	SaveSystem.data["selected_weapon"] = ""

	var scene := load("res://scenes/ui/WeaponList.tscn") as PackedScene
	check(scene != null, "تحميل WeaponList.tscn")
	if scene == null:
		_finish()
		return
	var wl = scene.instantiate()
	add_child(wl)
	await get_tree().process_frame
	await get_tree().process_frame

	_test_arsenal_rows_and_scroll(wl)
	await _test_upgrade_purchase(wl)
	await _test_insufficient_gold(wl)
	await _test_max_level(wl)
	await _test_select_and_equip(wl)
	await _test_locked_weapon(wl)
	await _test_phone_fit(wl)
	_finish()


func _finish() -> void:
	print("CHECK_RESULT: ", "ALL_PASS" if _fails == 0 else "FAIL_COUNT=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


## الترسانة: 9 صفوف + العدّاد + التمرير متاح
func _test_arsenal_rows_and_scroll(wl) -> void:
	var rows: VBoxContainer = wl.get_node("MainVBox/ArsenalPanel/Scroll/Rows")
	check(rows.get_child_count() == 9, "9 صفوف أسلحة (got %d)" % rows.get_child_count())
	var count_lbl: Label = wl.get_node("MainVBox/ArsenalCount")
	check("2 of 9" in count_lbl.text, "العدّاد = 2 من 9 (got \"%s\")" % count_lbl.text)
	await get_tree().process_frame
	var scroll: ScrollContainer = wl.get_node("MainVBox/ArsenalPanel/Scroll")
	var vsb: ScrollBar = scroll.get_v_scroll_bar()
	check(vsb.page > 0.0 and vsb.max_value > vsb.page + 1.0,
		"التمرير متاح (max=%.0f page=%.0f)" % [vsb.max_value, vsb.page])


## شراء ترقية: خصم الذهب + رفع المستوى + تحديث الشاشة
func _test_upgrade_purchase(wl) -> void:
	var w_id: String = wl._selected_id
	check(w_id == "ak47", "السلاح المختار افتراضيًا ak47 (got %s)" % w_id)
	var gold_before := SaveSystem.get_gold()
	var lvl_before := SaveSystem.get_weapon_upgrade(w_id, "damage")
	var cost := SaveSystem.get_weapon_upgrade_cost(w_id, "damage")
	check(cost > 0, "تكلفة الترقية موجبة (%d)" % cost)
	var btn := _find_upgrade_button(wl)
	if btn == null:
		check(false, "زر ترقية موجود في البطاقات")
		return
	check("Upgrade" in btn.text, "نص زر الترقية يحتوي \"Upgrade\" (got \"%s\")" % btn.text)
	btn.pressed.emit()
	await get_tree().process_frame
	check(SaveSystem.get_gold() == gold_before - cost,
		"الذهب خُصم بالتكلفة (%d = %d - %d)" % [SaveSystem.get_gold(), gold_before, cost])
	check(SaveSystem.get_weapon_upgrade(w_id, "damage") == lvl_before + 1,
		"مستوى damage ارتفع (%d → %d)" % [lvl_before, SaveSystem.get_weapon_upgrade(w_id, "damage")])
	var gold_lbl: Label = wl.get_node("MainVBox/TopBar/TopHBox/Resources/GoldChip/GoldHBox/GoldValue")
	check(gold_lbl.text == str(SaveSystem.get_gold()), "شريط الذهب حدّث نصه (%s)" % gold_lbl.text)
	var toast: Label = wl.get_node("ToastLabel")
	check(toast.visible and "Upgraded" in toast.text, "التوست يعرض نجاح الترقية")


## ذهب غير كافٍ: أزرار الترقية معطّلة ولا يُخصم شيء
func _test_insufficient_gold(wl) -> void:
	SaveSystem.data["gold"] = 1
	var lvl_before := SaveSystem.get_weapon_upgrade(wl._selected_id, "damage")
	wl._rebuild()
	await get_tree().process_frame
	await get_tree().process_frame
	var stats: GridContainer = wl.get_node("MainVBox/Body/StatsGrid")
	var buttons := _find_all_buttons(stats)
	check(buttons.size() == 4, "4 بطاقات ترقية (got %d)" % buttons.size())
	var all_disabled := true
	for b in buttons:
		if not (b as Button).disabled:
			all_disabled = false
	check(all_disabled, "كل أزرار الترقية معطّلة عند ذهب 1")
	check(SaveSystem.get_gold() == 1, "الذهب لم يتغير (%d)" % SaveSystem.get_gold())
	check(SaveSystem.get_weapon_upgrade(wl._selected_id, "damage") == lvl_before,
		"المستوى لم يتغير بدون ذهب")


## المستوى الأقصى: شارة MAX وبلا أزرار ترقية
func _test_max_level(wl) -> void:
	SaveSystem.data["gold"] = 100000
	var w_id: String = wl._selected_id
	SaveSystem.data["weapon_upgrades"][w_id] = {
		"damage": 10, "fire_rate": 10, "range": 10, "ammo": 10,
	}
	check(SaveSystem.get_weapon_upgrade_cost(w_id, "damage") == -1, "تكلفة المستوى الأقصى = -1")
	wl._rebuild()
	await get_tree().process_frame
	await get_tree().process_frame
	var stats: GridContainer = wl.get_node("MainVBox/Body/StatsGrid")
	check(_find_all_buttons(stats).is_empty(), "لا أزرار ترقية عند المستوى الأقصى")
	var found_max := false
	for c in stats.get_children():
		for lbl in _find_all_labels(c):
			if "Max" in lbl.text:
				found_max = true
	check(found_max, "شارة \"Max Level\" ظاهرة في البطاقات")
	var level_lbl: Label = wl.get_node("MainVBox/Body/PreviewArea/PreviewVBox/PreviewRow/InfoPanel/InfoVBox/LevelBadge")
	check("40/40" in level_lbl.text, "المستوى العام 40/40 (got \"%s\")" % level_lbl.text)


## اختيار صف من الترسانة + تجهيز فعلي
func _test_select_and_equip(wl) -> void:
	# اختيار shotgun عرضيًا (منطق _on_select)
	wl._on_select("shotgun")
	await get_tree().process_frame
	var shotgun = load("res://resources/weapons/shotgun.tres")
	var name_lbl: Label = wl.get_node("MainVBox/Body/PreviewArea/PreviewVBox/PreviewRow/InfoPanel/InfoVBox/WeaponNameRow/NameLabel")
	check(name_lbl.text == shotgun.display_name, "اسم السلاح في البطاقة = %s" % name_lbl.text)
	# تجهيز عبر زر الواجهة
	var equip: Button = wl.get_node("MainVBox/Body/PreviewArea/PreviewVBox/EquipButton")
	check(not equip.disabled, "زر التجهيز مفعّل لسلاح مفتوح غير مجهّز")
	equip.pressed.emit()
	await get_tree().process_frame
	check(SaveSystem.get_selected_weapon() == "shotgun", "selected_weapon = shotgun (got %s)" % SaveSystem.get_selected_weapon())
	check(equip.disabled and "Equipped" in equip.text, "الزر معطّل ويعرض \"Equipped\" (got \"%s\")" % equip.text)
	# اختيار من الصف نفسه (زر \"عرض\")
	var rows: VBoxContainer = wl.get_node("MainVBox/ArsenalPanel/Scroll/Rows")
	var select_btns := _find_buttons_with_text(rows, "View")
	check(select_btns.size() == 1, "زر عرض واحد فقط (السلاح الآخر غير مختار) (got %d)" % select_btns.size())
	if select_btns.size() == 1:
		(select_btns[0] as Button).pressed.emit()
		await get_tree().process_frame
		check(wl._selected_id != "shotgun", "التحديد تغيّر من صف آخر (%s)" % wl._selected_id)


## سلاح مقفل: زر تجهيز معطّل + شارة قفل + صفوف مقفلة بلا أزرار عرض
func _test_locked_weapon(wl) -> void:
	var locked_id := ""
	for id in ["heavymg", "laserifle", "flamethrower", "grenadelauncher", "rocketlauncher", "teslacoil", "smokelauncher"]:
		if id not in SaveSystem.get_unlocked_weapons():
			locked_id = id
			break
	check(locked_id != "", "يوجد سلاح مقفل للاختبار")
	if locked_id == "":
		return
	wl._selected_id = locked_id
	wl._rebuild()
	await get_tree().process_frame
	await get_tree().process_frame
	var equip: Button = wl.get_node("MainVBox/Body/PreviewArea/PreviewVBox/EquipButton")
	check(equip.disabled, "زر التجهيز معطّل لسلاح مقفل")
	check("Locked" in equip.text, "نص الزر يوضح القفل (got \"%s\")" % equip.text)
	var stats: GridContainer = wl.get_node("MainVBox/Body/StatsGrid")
	var lock_lbl := false
	for c in stats.get_children():
		for lbl in _find_all_labels(c):
			if "Unlock this weapon" in lbl.text:
				lock_lbl = true
	check(lock_lbl, "منطقة الإحصائيات تعرض رسالة فتح السلاح المقفل")
	var rows: VBoxContainer = wl.get_node("MainVBox/ArsenalPanel/Scroll/Rows")
	check(_find_buttons_with_text(rows, "View").size() == 2, "أزرار عرض = المفتوح فقط (got %d)" % _find_buttons_with_text(rows, "View").size())
	var wave_lbls := 0
	for lbl in _find_all_labels(rows):
		if "Wave" in lbl.text:
			wave_lbls += 1
	check(wave_lbls == 7, "7 صفوف مقفلة تُظهر رقم الموجة (got %d)" % wave_lbls)


## ملاءمة نافذة 536×954 (نسبة الموبايل المطلوبة)
func _test_phone_fit(wl) -> void:
	get_window().size = Vector2i(536, 954)
	await get_tree().process_frame
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	if vp != Vector2(720, 1280):
		print("DIAG forcing viewport size, was: ", vp)
		get_viewport().size = Vector2i(720, 1280)
		await get_tree().process_frame
		vp = get_viewport().get_visible_rect().size
	print("DIAG window=", get_window().size, " viewport=", vp)
	check(vp == Vector2(720, 1280), "stretch viewport يبقي التصميم 720×1280 مع نافذة 536×954")
	var overflow: Array[String] = []
	_collect_overflow(wl, "WeaponList", Vector2(720, 1280), overflow)
	check(overflow.is_empty(), "لا فيض خارج حدود التصميم (overflow=%d)" % overflow.size())
	for line in overflow:
		print("OVER: ", line)


func _collect_overflow(n: Node, path: String, vp: Vector2, out: Array[String]) -> void:
	if n is Control:
		var c := n as Control
		var in_scroll := false
		var p := c.get_parent()
		while p != null:
			if p is ScrollContainer:
				in_scroll = true
				break
			p = p.get_parent()
		if not in_scroll and c.is_visible_in_tree() and c.size.x > 0.5 and c.size.y > 0.5:
			var r := c.get_global_rect()
			if r.position.x < -1.0 or r.position.y < -1.0 \
					or r.end.x > vp.x + 1.0 or r.end.y > vp.y + 1.0:
				out.append("%s :: %s :: %s" % [path, c.name, r])
	for child in n.get_children():
		_collect_overflow(child, path + "/" + (child as Node).name, vp, out)


func _find_upgrade_button(wl) -> Button:
	var stats: GridContainer = wl.get_node("MainVBox/Body/StatsGrid")
	for b in _find_all_buttons(stats):
		if not (b as Button).disabled and "Upgrade" in (b as Button).text:
			return b
	return null


func _find_all_buttons(n: Node) -> Array[Button]:
	var out: Array[Button] = []
	if n is Button:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_all_buttons(c))
	return out


func _find_all_labels(n: Node) -> Array[Label]:
	var out: Array[Label] = []
	if n is Label:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_all_labels(c))
	return out


func _find_buttons_with_text(n: Node, text: String) -> Array[Button]:
	var out: Array[Button] = []
	for b in _find_all_buttons(n):
		if (b as Button).text == text:
			out.append(b)
	return out
