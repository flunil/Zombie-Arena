extends Node
## لمرة واحدة: تكبير الساحة لتغطية مدينة المستخدم + إكمال رصف المباني
## لا يمسّ عقد المستخدم الحالية (Node3D طرق / Node3D2 مباني) — يضيف فقط
## الحدود: x[-32,72] z[-102,60] المركز (20,-21)

const ARENA := "res://scenes/main/Arena.tscn"
const PARTS := "res://assets/city_parts/"
const BOUND_X_MIN := -32.0
const BOUND_X_MAX := 72.0
const BOUND_Z_MIN := -102.0
const BOUND_Z_MAX := 60.0

# مباني الغرب: صف على الشارع (x=16، ملتفة 90° تواجه الشارع) + عمود غربي ثانٍ
const WEST_FLANK := [
	{"p": "restaurant", "pos": Vector3(16, 0, -4), "ry": PI / 2.0},
	{"p": "bank", "pos": Vector3(16, 0, -20), "ry": PI / 2.0},
	{"p": "boutique", "pos": Vector3(16, 0, -36), "ry": PI / 2.0},
	{"p": "businesscenter", "pos": Vector3(16, 0, -52), "ry": PI / 2.0},
	{"p": "hotel_b", "pos": Vector3(16, 0, -68), "ry": PI / 2.0},
	{"p": "postoffice", "pos": Vector3(16, 0, -84), "ry": PI / 2.0},
]
const WEST_DISTRICT := [
	{"p": "house_01", "pos": Vector3(-17, 0, 40), "ry": 0.0},
	{"p": "house_05", "pos": Vector3(-17, 0, -12), "ry": 0.0},
	{"p": "musicshop", "pos": Vector3(-17, 0, -40), "ry": 0.0},
	{"p": "policestation", "pos": Vector3(-17, 0, -70), "ry": 0.0},
]


func _ready() -> void:
	print("[EXT] loading arena ...")
	var packed := load(ARENA) as PackedScene
	if packed == null:
		print("[EXT] FAIL load arena")
		get_tree().quit(1)
		return
	var root := packed.instantiate()
	print("[EXT] resizing ground + walls ...")
	_resize_ground(root)
	_resize_walls(root)
	var roads := root.get_node_or_null("Node3D") as Node3D
	var builds := root.get_node_or_null("Node3D2") as Node3D
	if roads == null or builds == null:
		print("[EXT] FAIL containers Node3D/Node3D2 missing")
		root.free()
		get_tree().quit(1)
		return
	print("[EXT] extending roads ...")
	_extend_roads(roads, root)
	print("[EXT] adding buildings ...")
	var added := 0
	for spec in WEST_FLANK:
		added += _add_building(builds, root, spec)
	for spec in WEST_DISTRICT:
		added += _add_building(builds, root, spec)
	print("[EXT] buildings added=", added)
	print("[EXT] packing ...")
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, ARENA)
	print("[EXT] saved err=", err)
	root.free()
	get_tree().quit(0)


func _resize_ground(root: Node) -> void:
	var w := BOUND_X_MAX - BOUND_X_MIN
	var d := BOUND_Z_MAX - BOUND_Z_MIN
	var cx := (BOUND_X_MAX + BOUND_X_MIN) / 2.0
	var cz := (BOUND_Z_MAX + BOUND_Z_MIN) / 2.0
	var ground := root.get_node_or_null("Ground") as Node3D
	if ground == null:
		return
	ground.position = Vector3(cx, 0, cz)
	var mi := ground.get_node_or_null("Mesh") as MeshInstance3D
	if mi != null and mi.mesh is PlaneMesh:
		(mi.mesh as PlaneMesh).size = Vector2(w, d)
	var cs := ground.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs != null and cs.shape is BoxShape3D:
		(cs.shape as BoxShape3D).size = Vector3(w, 1, d)


func _resize_walls(root: Node) -> void:
	var walls := root.get_node_or_null("Walls") as Node3D
	if walls == null:
		return
	var w := BOUND_X_MAX - BOUND_X_MIN
	var d := BOUND_Z_MAX - BOUND_Z_MIN
	var cx := (BOUND_X_MAX + BOUND_X_MIN) / 2.0
	var cz := (BOUND_Z_MAX + BOUND_Z_MIN) / 2.0
	var n := walls.get_node_or_null("North") as Node3D
	if n != null:
		n.position = Vector3(cx, 1.5, BOUND_Z_MIN)
		var nm := n.get_node_or_null("Mesh") as MeshInstance3D
		if nm != null:
			nm.scale = Vector3(w, 1, 1)
	var s := walls.get_node_or_null("South") as Node3D
	if s != null:
		s.position = Vector3(cx, 1.5, BOUND_Z_MAX)
		var sm := s.get_node_or_null("Mesh") as MeshInstance3D
		if sm != null:
			sm.scale = Vector3(w, 1, 1)
	var e := walls.get_node_or_null("East") as Node3D
	if e != null:
		e.position = Vector3(BOUND_X_MAX, 1.5, cz)
		var em := e.get_node_or_null("Mesh") as MeshInstance3D
		if em != null:
			em.scale = Vector3(1, 1, d)
	var we := walls.get_node_or_null("West") as Node3D
	if we != null:
		we.position = Vector3(BOUND_X_MIN, 1.5, cz)
		var wm := we.get_node_or_null("Mesh") as MeshInstance3D
		if wm != null:
			wm.scale = Vector3(1, 1, d)
	# أشكال الصدام مشتركة: عدّل مرة واحدة لكل نوع
	var sh_ns := _find_shape(root, "Shape_wall_ns")
	if sh_ns != null:
		sh_ns.size = Vector3(w, 3, 1)
	var sh_ew := _find_shape(root, "Shape_wall_ew")
	if sh_ew != null:
		sh_ew.size = Vector3(1, 3, d)


func _find_shape(root: Node, sname: String) -> BoxShape3D:
	var stack: Array = [root]
	while stack.size() > 0:
		var c: Node = stack.pop_back()
		if c is CollisionShape3D:
			var cs := c as CollisionShape3D
			if cs.name == sname and cs.shape is BoxShape3D:
				return cs.shape as BoxShape3D
		for cc in c.get_children():
			stack.append(cc)
	return null


func _extend_roads(roads: Node3D, root: Node) -> void:
	var template: MeshInstance3D = null
	for c in roads.get_children():
		if c is MeshInstance3D:
			template = c as MeshInstance3D
			break
	if template == null:
		print("[EXT] FAIL no template road")
		return
	# امتداد جنوب الشارع الرئيسي (x=37)
	var south := _dup_owned(template, root, "road_s_01") as Node3D
	south.position = Vector3(template.position.x, 0, -91.2)
	# شارع عرضي عند z=12 (بزاوية 90° عن قالب الشارع)
	var rot := Basis(Vector3.UP, PI / 2.0)
	var xs := [3.0, 15.0, 27.0]
	for i in xs.size():
		var cross := _dup_owned(template, root, "road_x_%02d" % (i + 1)) as Node3D
		cross.transform = Transform3D(rot * template.basis, Vector3(xs[i], 0, 12))


func _dup_owned(src: Node, root: Node, new_name: String) -> Node:
	var d := src.duplicate() as Node3D
	d.name = new_name
	(src.get_parent() as Node3D).add_child(d)
	d.owner = root
	_set_owner_recursive(d, root)
	return d


func _set_owner_recursive(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_set_owner_recursive(c, root)


func _add_building(parent: Node3D, root: Node, spec: Dictionary) -> int:
	var path := PARTS + String(spec["p"]) + ".tscn"
	var packed := load(path) as PackedScene
	if packed == null:
		print("[EXT] FAIL load ", path)
		return 0
	var inst := packed.instantiate() as Node3D
	# ارفع المجسم ليستقر قاعه على y=0 (حساب حدود يدوي بلا شجرة)
	var min_y := _bounds_min_y(inst)
	var pos: Vector3 = spec["pos"]
	inst.position = Vector3(pos.x, -min_y, pos.z)
	inst.rotation.y = spec["ry"]
	parent.add_child(inst)
	inst.owner = root
	return 1


## يحسب أقل y عبر ركوب transforms يدويًا (معطوب رانتايم — لا شجرة)
func _bounds_min_y(root_n: Node3D) -> float:
	var min_y := INF
	var stack: Array = [{"n": root_n, "t": root_n.transform}]
	while stack.size() > 0:
		var item: Dictionary = stack.pop_back()
		var n: Node = item["n"]
		var t: Transform3D = item["t"]
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				var aabb := mi.get_aabb()
				for i in 8:
					var corner := Vector3(
							aabb.position.x + (aabb.size.x if (i & 1) == 1 else 0.0),
							aabb.position.y + (aabb.size.y if (i & 2) == 2 else 0.0),
							aabb.position.z + (aabb.size.z if (i & 4) == 4 else 0.0))
					min_y = minf(min_y, (t * corner).y)
		for c in n.get_children():
			if c is Node3D:
				stack.append({"n": c, "t": t * (c as Node3D).transform})
	if min_y == INF:
		min_y = 0.0
	return min_y
