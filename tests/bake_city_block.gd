extends Node
## bake لمرة واحدة: يحقن مجسمات city_parts كعقد مملوكة محفوظة داخل Arena.tscn
## (لا يبقى أي سكربت بناء — كل جزء عقدة قابلة للتعديل في المحرر)
## يحذف CityBlock القديم (سكربت) ويبني CityBlock ثابتًا + صدامات + إطار جدران/أرصفة

const PARTS := "res://assets/city_parts/"
const ARENA := "res://scenes/main/Arena.tscn"
const ARENA_HALF := 25.0

const BUILDINGS := [
	{"p": "bank", "n": "Bank", "x": -16.5, "z": -15.5, "ry": 0.0},
	{"p": "restaurant", "n": "Restaurant", "x": 16.5, "z": -15.5, "ry": 0.0},
	{"p": "boutique", "n": "Boutique", "x": -16.5, "z": 15.5, "ry": 0.0},
	{"p": "policestation", "n": "PoliceStation", "x": 16.5, "z": 15.5, "ry": 0.0},
]
const ROADS := [
	{"p": "road_a_02", "n": "RoadX1", "x": -24.0, "z": 0.0, "ry": 0.0},
	{"p": "road_a_02", "n": "RoadX2", "x": -12.0, "z": 0.0, "ry": 0.0},
	{"p": "road_a_02", "n": "RoadX3", "x": 0.0, "z": 0.0, "ry": 0.0},
	{"p": "road_a_02", "n": "RoadX4", "x": 12.0, "z": 0.0, "ry": 0.0},
	{"p": "road_a_02", "n": "RoadX5", "x": 24.0, "z": 0.0, "ry": 0.0},
	{"p": "road_a_02", "n": "RoadZ1", "x": 0.0, "z": -24.0, "ry": 1.5707963},
	{"p": "road_a_02", "n": "RoadZ2", "x": 0.0, "z": -12.0, "ry": 1.5707963},
	{"p": "road_a_02", "n": "RoadZ3", "x": 0.0, "z": 0.0, "ry": 1.5707963},
	{"p": "road_a_02", "n": "RoadZ4", "x": 0.0, "z": 12.0, "ry": 1.5707963},
	{"p": "road_a_02", "n": "RoadZ5", "x": 0.0, "z": 24.0, "ry": 1.5707963},
]
const VEHICLES := [
	{"p": "jeep_f", "n": "JeepF", "x": 12.0, "z": 1.5, "ry": 1.5707963, "c": true},
	{"p": "jeep_g", "n": "JeepG", "x": -16.0, "z": -1.5, "ry": 1.5707963, "c": true},
	{"p": "jeep_f_001", "n": "JeepF1", "x": 1.8, "z": -14.0, "ry": 0.0, "c": true},
	{"p": "truck_001", "n": "Truck", "x": -1.8, "z": 14.0, "ry": 0.0, "c": true},
]
const PROPS := [
	{"p": "tree", "n": "Tree1", "x": -6.9, "z": -7.0, "ry": 0.3, "c": false},
	{"p": "tree", "n": "Tree2", "x": 6.9, "z": -7.0, "ry": 1.9, "c": false},
	{"p": "tree", "n": "Tree3", "x": -6.9, "z": 7.0, "ry": 4.1, "c": false},
	{"p": "tree", "n": "Tree4", "x": 6.9, "z": 7.0, "ry": 2.7, "c": false},
	{"p": "tree", "n": "Tree5", "x": -6.9, "z": -16.5, "ry": 0.9, "c": false},
	{"p": "tree", "n": "Tree6", "x": 6.9, "z": 16.5, "ry": 3.6, "c": false},
	{"p": "tree", "n": "Tree7", "x": -16.5, "z": -6.9, "ry": 5.2, "c": false},
	{"p": "tree", "n": "Tree8", "x": 16.5, "z": 6.9, "ry": 0.5, "c": false},
	{"p": "plant", "n": "Plant1", "x": -8.8, "z": -8.8, "ry": 0.2, "c": false},
	{"p": "plant", "n": "Plant2", "x": 8.8, "z": -8.8, "ry": 1.4, "c": false},
	{"p": "plant", "n": "Plant3", "x": -8.8, "z": 8.8, "ry": 2.9, "c": false},
	{"p": "plant", "n": "Plant4", "x": 8.8, "z": 8.8, "ry": 4.4, "c": false},
	{"p": "cratebox_a001_Mesh_001", "n": "Crate1", "x": -9.2, "z": -7.2, "ry": 0.3, "c": false},
	{"p": "cratebox_a001_Mesh_001", "n": "Crate2", "x": -10.6, "z": -7.6, "ry": 0.8, "c": false},
	{"p": "barrel_b001_Mesh_001", "n": "Barrel1", "x": -8.4, "z": -7.9, "ry": 0.0, "c": false},
	{"p": "barrel_b001_Mesh_001", "n": "Barrel2", "x": 9.3, "z": -7.4, "ry": 0.6, "c": false},
	{"p": "cratebox_a001_Mesh_001", "n": "Crate3", "x": 10.4, "z": -7.8, "ry": 1.9, "c": false},
	{"p": "barrel_b001_Mesh_001", "n": "Barrel3", "x": -9.0, "z": 8.0, "ry": 1.1, "c": false},
	{"p": "logs_a001_Mesh_001", "n": "Logs", "x": -10.8, "z": 8.4, "ry": 0.2, "c": false},
	{"p": "timber_a002_Mesh_001", "n": "Timber", "x": 9.6, "z": 8.6, "ry": 1.6, "c": false},
	{"p": "barrel_b001_Mesh_001", "n": "Barrel4", "x": 10.6, "z": 8.0, "ry": 0.0, "c": false},
	{"p": "bench_b002_Mesh_001", "n": "Bench1", "x": 6.9, "z": -16.8, "ry": 0.0, "c": false},
	{"p": "bench_b002_Mesh_001", "n": "Bench2", "x": -6.9, "z": 16.8, "ry": 3.1415927, "c": false},
	{"p": "mailbox_a003_Mesh_001", "n": "Mailbox", "x": -6.9, "z": -18.5, "ry": 0.4, "c": false},
	{"p": "streetsign_a004_Mesh_001", "n": "StreetSign", "x": 6.9, "z": 18.5, "ry": 2.2, "c": false},
	{"p": "cart_b001_Mesh_001", "n": "Cart1", "x": -21.5, "z": -8.5, "ry": 0.7, "c": false},
	{"p": "cart_c002_Mesh_001", "n": "Cart2", "x": -22.3, "z": -9.4, "ry": 1.9, "c": false},
	{"p": "tyre", "n": "Tyre1", "x": 21.8, "z": -9.2, "ry": 0.5, "c": false},
	{"p": "tyre", "n": "Tyre2", "x": 22.4, "z": -8.4, "ry": 1.7, "c": false},
]

var _placed := 0
var _colliders := 0


func _ready() -> void:
	print("[BAKE] loading arena ...")
	var packed := load(ARENA) as PackedScene
	if packed == null:
		print("[BAKE] FAIL load arena")
		get_tree().quit(1)
		return
	var arena := packed.instantiate() as Node3D
	# حذف CityBlock القديم (سكربت أو بقايا)
	var old := arena.get_node_or_null("CityBlock")
	if old != null:
		arena.remove_child(old)
		old.free()
	# إنشاء حاوية ثابتة قبل NavRegion
	var cb := Node3D.new()
	cb.name = "CityBlock"
	var nav_idx := arena.get_node("NavRegion").get_index()
	arena.add_child(cb)
	arena.move_child(cb, nav_idx)
	cb.owner = arena
	var items: Array = []
	items.append_array(BUILDINGS)
	items.append_array(ROADS)
	items.append_array(VEHICLES)
	items.append_array(PROPS)
	for item in items:
		var n := _place(item, cb, arena)
		if n == null:
			continue
		_placed += 1
		if item.get("c", false):
			_add_collider(n, item["n"], arena)
	# الإطار المدمج: أسوار + أرصفة + قاعدة كأسطر عادية
	_build_frame(cb, arena)
	var ps := PackedScene.new()
	var err := ps.pack(arena)
	if err != OK:
		print("[BAKE] FAIL pack err=", err)
		get_tree().quit(1)
		return
	err = ResourceSaver.save(ps, ARENA)
	print("[BAKE] saved arena err=", err, " placed=", _placed, " colliders=", _colliders)
	get_tree().quit(0 if err == OK else 1)


func _place(item: Dictionary, cb: Node3D, arena: Node3D) -> Node3D:
	var scene := load(PARTS + item["p"] + ".tscn") as PackedScene
	if scene == null:
		print("[BAKE] MISSING part ", item["p"])
		return null
	var n := scene.instantiate() as Node3D
	n.name = item["n"]
	cb.add_child(n)
	n.owner = arena
	n.rotation.y = item["ry"]
	# رفع حتى يستقر قاع المجسم على y=0 (الأصل في منتصف الشبكة)
	var b := _local_bounds(n)
	n.position = Vector3(item["x"], -b.position.y, item["z"])
	return n


func _add_collider(root: Node3D, label: String, arena: Node3D) -> void:
	var b := _local_bounds(root)
	if b.size.x < 0.1 or b.size.z < 0.1:
		return
	var body := StaticBody3D.new()
	body.name = "Collider_" + label
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = b.size
	cs.shape = box
	cs.position = b.get_center()
	body.add_child(cs)
	root.add_child(body)
	body.owner = arena
	cs.owner = arena
	_colliders += 1


func _local_bounds(root: Node3D) -> AABB:
	# حساب يدوي بدون global_transform (العقدة قد لا تكون داخل الشجرة بعد)
	var out := AABB()
	var has := false
	var stack: Array = [{"n": root, "xf": Transform3D.IDENTITY}]
	while stack.size() > 0:
		var item: Dictionary = stack.pop_back()
		var c: Node = item["n"]
		var xf: Transform3D = item["xf"]
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				var local: AABB = xf * mi.mesh.get_aabb()
				if has:
					out = out.merge(local)
				else:
					out = local
					has = true
		for cc in c.get_children():
			if cc is Node3D:
				stack.append({"n": cc, "xf": xf * (cc as Node3D).transform})
	if not has:
		out = AABB(Vector3.ZERO, Vector3.ONE)
	return out


func _build_frame(cb: Node3D, arena: Node3D) -> void:
	var frame := Node3D.new()
	frame.name = "Frame"
	cb.add_child(frame)
	frame.owner = arena
	var mat_sw := _mat(Color(0.78, 0.76, 0.72))
	var mat_wall := _mat(Color(0.86, 0.84, 0.79))
	var mat_skirt := _mat(Color(0.24, 0.32, 0.22))
	_box(frame, arena, "Skirt", Vector3(0, -0.3, 0), Vector3(54.0, 0.55, 54.0), mat_skirt)
	var core := 40.0
	var ring := (ARENA_HALF * 2.0 - core) * 0.5
	var edge := core * 0.5 + ring * 0.5
	var t := 0.14
	_box(frame, arena, "SidewalkN", Vector3(0, t * 0.5, -edge), Vector3(ARENA_HALF * 2.0, t, ring), mat_sw)
	_box(frame, arena, "SidewalkS", Vector3(0, t * 0.5, edge), Vector3(ARENA_HALF * 2.0, t, ring), mat_sw)
	_box(frame, arena, "SidewalkW", Vector3(-edge, t * 0.5, 0), Vector3(ring, t, core), mat_sw)
	_box(frame, arena, "SidewalkE", Vector3(edge, t * 0.5, 0), Vector3(ring, t, core), mat_sw)
	var ci := 0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			ci += 1
			_box(frame, arena, "SidewalkC" + str(ci), Vector3(sx * edge, t * 0.5, sz * edge), Vector3(ring, t, ring), mat_sw)
	var h := 1.4
	var w := ARENA_HALF * 2.0 - 0.4
	_box(frame, arena, "WallN", Vector3(0, h * 0.5, -24.8), Vector3(w, h, 0.5), mat_wall)
	_box(frame, arena, "WallS", Vector3(0, h * 0.5, 24.8), Vector3(w, h, 0.5), mat_wall)
	_box(frame, arena, "WallW", Vector3(-24.8, h * 0.5, 0), Vector3(0.5, h, w), mat_wall)
	_box(frame, arena, "WallE", Vector3(24.8, h * 0.5, 0), Vector3(0.5, h, w), mat_wall)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _box(parent: Node3D, arena: Node3D, n: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	mi.owner = arena
