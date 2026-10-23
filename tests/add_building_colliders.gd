extends Node
## لمرة واحدة: يضيف StaticBody3D بأشكال trimesh (من شبكات المباني نفسها)
## داخل مشاهد الأجزاء four buildings، ويحذف صناديق AABB القديمة من Arena.tscn

const PARTS_DIR := "res://assets/city_parts/"
const ARENA := "res://scenes/main/Arena.tscn"
const BUILDINGS := [
	{"part": "bank", "inst": "Bank"},
	{"part": "restaurant", "inst": "Restaurant"},
	{"part": "boutique", "inst": "Boutique"},
	{"part": "policestation", "inst": "PoliceStation"},
]


func _ready() -> void:
	var total := 0
	for b in BUILDINGS:
		total += _fix_part(PARTS_DIR + b["part"] + ".tscn")
	_trim_arena_boxes()
	print("[COLLIDERS] building shapes=", total)
	get_tree().quit(0)


func _fix_part(path: String) -> int:
	var packed := load(path) as PackedScene
	if packed == null:
		print("[COLLIDERS] FAIL load ", path)
		return 0
	var root := packed.instantiate() as Node3D
	# حذف StaticBody قديم إن وُجد
	var old := root.get_node_or_null("StaticBody")
	if old != null:
		root.remove_child(old)
		old.free()
	var body := StaticBody3D.new()
	body.name = "StaticBody"
	root.add_child(body)
	body.owner = root
	var count := 0
	var stack: Array = [root]
	while stack.size() > 0:
		var c: Node = stack.pop_back()
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				var shape := mi.mesh.create_trimesh_shape()
				if shape == null:
					continue
				shape.backface_collision = true
				var cs := CollisionShape3D.new()
				cs.shape = shape
				cs.name = "Shape_" + String(mi.name)
				cs.transform = _relative(mi, root)
				body.add_child(cs)
				cs.owner = root
				count += 1
		for cc in c.get_children():
			if cc != body:
				stack.append(cc)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, path)
	print("[COLLIDERS] ", path.get_file(), " shapes=", count, " save_err=", err)
	root.free()
	return count


func _relative(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != root:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


func _trim_arena_boxes() -> void:
	# حذف صناديق AABB القديمة للمباني من المشهد (التصادم الآن من part scenes)
	var packed := load(ARENA) as PackedScene
	if packed == null:
		print("[COLLIDERS] DEBUG arena load failed")
		return
	var arena := packed.instantiate() as Node3D
	var cb := arena.get_node_or_null("CityBlock")
	if cb == null:
		var names := PackedStringArray()
		for c in arena.get_children():
			names.append(String(c.name))
		print("[COLLIDERS] DEBUG CityBlock missing, children=", names)
		arena.free()
		return
	var removed := 0
	for b in BUILDINGS:
		var inst := cb.get_node_or_null(b["inst"])
		if inst == null:
			continue
		var box := inst.get_node_or_null("Collider_" + b["inst"])
		if box != null:
			inst.remove_child(box)
			box.free()
			removed += 1
	var ps := PackedScene.new()
	var err := ps.pack(arena)
	if err == OK:
		err = ResourceSaver.save(ps, ARENA)
	print("[COLLIDERS] arena boxes removed=", removed, " save_err=", err)
	arena.free()
