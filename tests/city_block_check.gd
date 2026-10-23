extends Node
## فحص Arena.tscn بعد bake: عقد city_parts محفوظة كأسطر المشهد (لا سكربت بناء)

var _fails: Array[String] = []


func _ready() -> void:
	var arena: Node = load("res://scenes/main/Arena.tscn").instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(arena)
	if _fails.is_empty():
		print("CITYBLOCK_CHECK ALL_PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("CITYBLOCK_CHECK FAIL: ", f)
		get_tree().quit(1)


func _check(arena: Node) -> void:
	var d: Node = arena.get_node_or_null("CityBlock")
	if d == null:
		_fail("CityBlock missing")
		return
	if d.get_script() != null:
		_fail("CityBlock still has a script — must be plain saved nodes")
	var buildings := ["Bank", "Restaurant", "Boutique", "PoliceStation"]
	for n in buildings:
		var b: Node = d.get_node_or_null(n)
		if b == null:
			_fail("building missing: " + n)
			continue
		var body: Node = b.get_node_or_null("StaticBody")
		if body == null:
			_fail("building StaticBody missing: " + n)
			continue
		var shapes := 0
		for cs in body.get_children():
			if cs is CollisionShape3D and (cs as CollisionShape3D).shape != null:
				shapes += 1
		if shapes < 1:
			_fail("building trimesh shapes missing: " + n)
	var roads := 0
	var vehicles := 0
	var props := 0
	var colliders := 4  # المباني الأربعة مع StaticBody من part scenes
	for c in d.get_children():
		var nm := String(c.name)
		if nm.begins_with("Road"):
			roads += 1
		elif nm in ["JeepF", "JeepG", "JeepF1", "Truck"]:
			vehicles += 1
		elif c is Node3D and c.get_child_count() > 0 and c.get_child(0) is MeshInstance3D:
			props += 1
		if c.get_node_or_null("Collider_" + nm) != null:
			colliders += 1
	if roads != 10:
		_fail("roads != 10: " + str(roads))
	if vehicles != 4:
		_fail("vehicles != 4: " + str(vehicles))
	if props < 25:
		_fail("props too few: " + str(props))
	if colliders < 8:
		_fail("colliders too few: " + str(colliders))
	var frame: Node = d.get_node_or_null("Frame")
	if frame == null:
		_fail("Frame missing")
	else:
		var meshes := 0
		for c in frame.get_children():
			if c is MeshInstance3D:
				meshes += 1
		if meshes < 12:
			_fail("Frame meshes too few: " + str(meshes))
	for wn in ["North", "South", "East", "West"]:
		var wm: MeshInstance3D = arena.get_node_or_null("Walls/" + wn + "/Mesh") as MeshInstance3D
		if wm == null:
			_fail("wall mesh missing: " + wn)
		elif wm.visible:
			_fail("wall mesh visible: " + wn)
	if arena.get_node_or_null("Ground/Mesh") == null:
		_fail("ground mesh missing")
	var nav: NavigationRegion3D = arena.get_node_or_null("NavRegion") as NavigationRegion3D
	if nav == null:
		_fail("NavRegion missing")
	else:
		var nm2 := nav.get_navigation_mesh()
		if nm2 == null or nm2.get_polygon_count() < 1:
			_fail("nav not baked")


func _fail(msg: String) -> void:
	_fails.append(msg)
