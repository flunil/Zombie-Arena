extends Node
## قياس أحجام كل جزء في city_parts (ثوانٍ — لا يحمل city.tscn)


func _ready() -> void:
	print("[SIZE] start")
	var dir := DirAccess.open("res://assets/city_parts/")
	if dir == null:
		print("[SIZE] dir open FAILED")
		get_tree().quit(1)
		return
	print("[SIZE] dir ok")
	dir.list_dir_begin()
	var fname := dir.get_next()
	var n_files := 0
	while fname != "":
		n_files += 1
		if fname.ends_with(".tscn"):
			var packed := load("res://assets/city_parts/" + fname) as PackedScene
			print("[SIZE] try ", fname, " ok=", packed != null)
			if packed == null:
				fname = dir.get_next()
				continue
			var inst := packed.instantiate()
			var stack: Array = [inst]
			var w := 0.0
			var d := 0.0
			var h := 0.0
			while stack.size() > 0:
				var c: Node = stack.pop_back()
				if c is MeshInstance3D:
					var mi := c as MeshInstance3D
					var aabb := mi.get_aabb()
					var s: Vector3 = mi.scale
					var size := Vector3(aabb.size.x * absf(s.x),
							aabb.size.y * absf(s.y), aabb.size.z * absf(s.z))
					# المحور الأفقي بعد دوران المحلي ±90°: x↔z عند ry=±90
					var ry: float = mi.rotation.y
					if absf(absf(ry) - PI / 2.0) < 0.1:
						size = Vector3(size.z, size.y, size.x)
					w = maxf(w, size.x)
					h = maxf(h, size.y)
					d = maxf(d, size.z)
				for cc in c.get_children():
					stack.append(cc)
			inst.free()
			print("[SIZE] ", fname.replace(".tscn", ""), " w=", snappedf(w, 0.1),
					" d=", snappedf(d, 0.1), " h=", snappedf(h, 0.1))
		fname = dir.get_next()
	print("[SIZE] total_entries=", n_files)
	get_tree().quit(0)
