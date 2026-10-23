extends Node

# فحص مشاهد المجسمات:9 مشاهد موجودة وسليمة + العرض من عقد اليد في Player.tscn (بلا مُجدٍّ طائر)

const IDS: Array[String] = [
	"ak47", "shotgun", "heavymg", "laserifle", "flamethrower",
	"grenadelauncher", "rocketlauncher", "teslacoil", "smokelauncher",
]

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("CHECK PASS: ", label)
	else:
		_fails += 1
		print("CHECK FAIL: ", label)


func _ready() -> void:
	for id in IDS:
		var path := "res://scenes/weapons/models/%s.tscn" % id
		_check(FileAccess.file_exists(path), "%s: scene file exists" % id)
		if not FileAccess.file_exists(path):
			continue
		var ps := load(path) as PackedScene
		_check(ps != null, "%s: scene loads" % id)
		if ps == null:
			continue
		var r := ps.instantiate()
		_check(r is Node3D, "%s: root is Node3D" % id)
		_check(_has_mesh(r), "%s: has mesh parts (تنازلي)" % id)
		_check(_has_prop(r, "damage") and _has_prop(r, "range_slot") and _has_prop(r, "max_range"),
			"%s: root exposes damage/range_slot/max_range controls" % id)
		var slot := int(r.get("range_slot"))
		_check(slot >= 0 and slot <= 9, "%s: range_slot in 0..9 -> %dm" % [id, 5 + slot])
		r.free()

	# المدى محصور 5..15 في موارد الأسلحة التسعة
	var bad_range := ""
	for id in IDS:
		var res_r := load("res://resources/weapons/%s.tres" % id) as WeaponResource
		if res_r == null or res_r.max_range < 5.0 or res_r.max_range > 15.0:
			bad_range += id + "(" + (str(res_r.max_range) if res_r != null else "null") + ") "
	_check(bad_range == "", "all weapon resources max_range in 5..15 (" + (bad_range if bad_range != "" else "ok") + ")")

	# تحكّم المشهد يعلو فوق weapon_data وقت التشغيل (slot7 -> 12م من النموذج)
	var model := (load("res://scenes/weapons/models/ak47.tscn") as PackedScene).instantiate()
	model.set("damage", 77.0)
	model.set("range_slot", 7)
	var wd := (load("res://resources/weapons/ak47.tres") as WeaponResource).duplicate(true) as WeaponResource
	var w2 := WeaponBase.new()
	w2.weapon_data = wd
	w2.hand_node = model
	add_child(w2)
	_check(is_equal_approx(wd.damage, 77.0) and is_equal_approx(wd.max_range, 12.0),
		"model scene controls override weapon_data (77 dmg / slot7 = 12m)")
	w2.free()
	model.free()

	# تكامل weapon_base: بلا مُجدٍّ طائر — المجسم البصري من عقد اليد (طلب المستخدم)
	var data := load("res://resources/weapons/ak47.tres") as WeaponResource
	var w := WeaponBase.new()
	w.weapon_data = data
	add_child(w)
	_check(w.get_node_or_null("Model") == null, "weapon_base: no floating Model (hand attachment)")
	_check(w.get_node_or_null("MuzzleFlash") != null, "weapon_base: MuzzleFlash built")
	w.free()

	# Player.tscn: 9 أسلحة مثبتة على عظمة اليد + ظاهر واحد فقط (AK47 افتراضياً)
	var p := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	var hr := p.get_node_or_null("Characters_Lis/CharacterArmature/Skeleton3D/Rifle") as Node3D
	_check(hr != null, "Player: hand attachment exists")
	if hr != null:
		var inst := 0
		var vis := 0
		for c in hr.get_children():
			if c is Node3D and String((c as Node3D).scene_file_path) != "":
				inst += 1
				_check(_has_mesh(c), "%s: hand instance has meshes" % c.name)
				if (c as Node3D).visible:
					vis += 1
		_check(inst == 9, "Player: 9 weapon instances on hand (found %s)" % inst)
		_check(vis == 1, "Player: exactly one hand weapon visible (found %s)" % vis)
	p.free()

	print("CHECK_RESULT: ", "ALL_PASS" if _fails == 0 else "FAIL(%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


## بحث تنازلي عن MeshInstance3D بـ mesh (يشمل عقد المشاهد المُدرجة GLB)
func _has_mesh(n: Node) -> bool:
	for c in n.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			return true
		if _has_mesh(c):
			return true
	return false


## هل يملك العقد خاصية بهذا الاسم (عبر get_property_list بلا أخطاء)
func _has_prop(n: Object, p: String) -> bool:
	for pr in n.get_property_list():
		if String(pr.name) == p:
			return true
	return false
