extends Node
## لمرة واحدة: يضيف StaticBody+trimesh لكل mesh في مشاهد city_parts
## عدا road_* (مشي) — يشمل الأشجار/النباتات/العربات/المركبات/البيوت

const DIR := "res://assets/city_parts/"


func _ready() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		print("[PARTCOL] FAIL open dir")
		get_tree().quit(1)
		return
	var fixed := 0
	var skipped := 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tscn"):
			var r := _fix_one(DIR + fname)
			if r < 0:
				skipped += 1
			else:
				fixed += r
		fname = dir.get_next()
	print("[PARTCOL] shapes_added=", fixed, " files_skipped=", skipped)
	get_tree().quit(0)


func _fix_one(path: String) -> int:
	var packed := load(path) as PackedScene
	if packed == null:
		return -1
	var root := packed.instantiate() as Node3D
	var added := 0
	var stack: Array = [root]
	while stack.size() > 0:
		var c: Node = stack.pop_back()
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.mesh == null or mi.mesh.get_surface_count() == 0:
				continue
			if mi.get_node_or_null("StaticBody") != null:
				continue
			var shape := mi.mesh.create_trimesh_shape()
			if shape == null:
				continue
			shape.backface_collision = true
			var body := StaticBody3D.new()
			body.name = "StaticBody"
			var cs := CollisionShape3D.new()
			cs.name = "Shape"
			cs.shape = shape
			mi.add_child(body)
			body.owner = root
			body.add_child(cs)
			cs.owner = root
			added += 1
		for cc in c.get_children():
			stack.append(cc)
	if added > 0:
		var ps := PackedScene.new()
		var err := ps.pack(root)
		if err == OK:
			err = ResourceSaver.save(ps, path)
		if err != OK:
			print("[PARTCOL] FAIL save ", path, " err=", err)
	root.free()
	return added
