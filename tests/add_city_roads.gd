extends Node
## لمرة واحدة: شبكة طرق مستقيمة تغطي المدينة كلها بنمط المستخدم
## نفس قطعة road_a ونفس الدوران والتباعد 12 — تكرار العقد لا يمسّ الموجود
## الحدود الجديدة: x[-44,84] z[-110,71]

const ARENA := "res://scenes/main/Arena.tscn"
const BOUND_X_MIN := -44.0
const BOUND_X_MAX := 84.0
const BOUND_Z_MIN := -110.0
const BOUND_Z_MAX := 71.0
# شوارع طولية (تمتد على z) عند هذه x
const NS_X := [-38.0, 1.5, 78.0]
# شارعان عرضيان (يمتدان على x) عند هذه z — عدا z=12 الموجود
const EW_Z := [64.0, -104.0]
const Z_START := 64.0
const Z_END := -104.0
const Z_STEP := -12.0
const X_START := -36.8
const X_STEP := 12.0
const X_LAST := 76.9


func _ready() -> void:
	print("[GRID] loading arena ...")
	var packed := load(ARENA) as PackedScene
	if packed == null:
		get_tree().quit(1)
		return
	var root := packed.instantiate()
	print("[GRID] resizing ground + walls ...")
	_resize_bounds(root)
	var roads := root.get_node_or_null("Node3D") as Node3D
	if roads == null:
		print("[GRID] FAIL Node3D missing")
		root.free()
		get_tree().quit(1)
		return
	var template: MeshInstance3D = null
	for c in roads.get_children():
		if c is MeshInstance3D:
			template = c as MeshInstance3D
			break
	if template == null:
		print("[GRID] FAIL no template road")
		root.free()
		get_tree().quit(1)
		return
	print("[GRID] laying roads ...")
	var n := 0
	# طولية: نفس قالب المستخدم تمامًا
	for x in NS_X:
		var z := Z_START
		while z >= Z_END:
			n += 1
			var piece := _dup_owned(template, roads, root, "road_grid_%03d" % n) as Node3D
			piece.position = Vector3(x, 0, z)
			z += Z_STEP
	# عرضية: قالب ملتف 90°
	var rot := Basis(Vector3.UP, PI / 2.0)
	var cross_basis := rot * template.basis
	for ez in EW_Z:
		var xs: Array = []
		var x := X_START
		while x < BOUND_X_MAX - 7.2:
			xs.append(x)
			x += X_STEP
		xs.append(X_LAST)
		for x2 in xs:
			n += 1
			var piece := _dup_owned(template, roads, root, "road_grid_%03d" % n) as Node3D
			piece.transform = Transform3D(cross_basis, Vector3(x2, 0, ez))
	print("[GRID] pieces added=", n)
	print("[GRID] packing ...")
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, ARENA)
	print("[GRID] saved err=", err)
	root.free()
	get_tree().quit(0)


func _dup_owned(src: Node, parent: Node3D, root: Node, new_name: String) -> Node:
	var d := src.duplicate() as Node3D
	d.name = new_name
	parent.add_child(d)
	d.owner = root
	_set_owner_recursive(d, root)
	return d


func _set_owner_recursive(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_set_owner_recursive(c, root)


func _resize_bounds(root: Node) -> void:
	var w := BOUND_X_MAX - BOUND_X_MIN
	var d := BOUND_Z_MAX - BOUND_Z_MIN
	var cx := (BOUND_X_MAX + BOUND_X_MIN) / 2.0
	var cz := (BOUND_Z_MAX + BOUND_Z_MIN) / 2.0
	var ground := root.get_node_or_null("Ground") as Node3D
	if ground != null:
		ground.position = Vector3(cx, 0, cz)
		var mi := ground.get_node_or_null("Mesh") as MeshInstance3D
		if mi != null and mi.mesh is PlaneMesh:
			(mi.mesh as PlaneMesh).size = Vector2(w, d)
		var cs := ground.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if cs != null and cs.shape is BoxShape3D:
			(cs.shape as BoxShape3D).size = Vector3(w, 1, d)
	var walls := root.get_node_or_null("Walls") as Node3D
	if walls == null:
		return
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
