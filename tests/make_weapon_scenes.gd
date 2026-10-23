extends Node

# أداة توليد (تُشغَّل يدويًا): تبني مشهد مستقل لكل سلاح من الأشكال الإجرائية الحالية
# التشغيل: godot --headless --path . res://tests/make_weapon_scenes.tscn
# تحذير: تعيد كتابة مشاهد scenes/weapons/models/* — لا تُشغَّل بعد استبدال المستخدم مجسمًا بـ FBX

const OUT_DIR := "res://scenes/weapons/models"
const IDS: Array[String] = [
	"ak47", "shotgun", "heavymg", "laserifle", "flamethrower",
	"grenadelauncher", "rocketlauncher", "teslacoil", "smokelauncher",
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var fails := 0
	for id in IDS:
		var data := load("res://resources/weapons/%s.tres" % id) as WeaponResource
		if data == null:
			fails += 1
			print("GEN FAIL: missing tres ", id)
			continue
		var root := Node3D.new()
		root.name = id
		var wb := WeaponBase.new()
		wb.weapon_data = data
		wb._build_shape(root)
		wb.free()
		_owners(root, root)  # pack() لا يضمّ عقداً بلا owner — ضبط مالك لكل الأبناء
		var ps := PackedScene.new()
		var err := ps.pack(root)
		if err == OK:
			err = ResourceSaver.save(ps, "%s/%s.tscn" % [OUT_DIR, id])
		root.free()
		if err == OK:
			print("GEN OK: ", id)
		else:
			fails += 1
			print("GEN ERR ", err, ": ", id)
	print("GEN_RESULT: ", "ALL_OK" if fails == 0 else "FAILS %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)


## ضبط owner لكل العقد تنازلياً (شرط لـ PackedScene.pack)
func _owners(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_owners(c, root)
