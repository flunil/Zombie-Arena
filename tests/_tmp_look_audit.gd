extends Node
## تدقيق بصري مؤقت: يطبّق التحويل الخلوي على أشجار Arena ويطبع إحصاء المواد
## (عدد MeshInstance، أصناف المواد، كم منها convertible، ألوان مميّزة)

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := (load("res://scenes/main/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await get_tree().process_frame
	var stats := _audit(arena, "before")
	var conv := CelMaterial.apply_tree(arena)
	print("AUDIT converted=", conv)
	_audit(arena, "after")
	get_tree().quit(0)


func _audit(root: Node, tag: String) -> Dictionary:
	var meshes := 0
	var convertible := 0
	var by_class := {}
	var colors := {}
	for n in _all(root):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		meshes += 1
		for s in mi.get_surface_override_material_count():
			var m := mi.get_active_material(s)
			if m == null:
				continue
			var cn := m.get_class()
			by_class[cn] = int(by_class.get(cn, 0)) + 1
			if CelMaterial.convertible(m):
				convertible += 1
			if m is BaseMaterial3D:
				colors[str((m as BaseMaterial3D).albedo_color)] = true
			elif m is ShaderMaterial:
				var v: Variant = (m as ShaderMaterial).get_shader_parameter("color")
				if v is Color:
					colors[str(v)] = true
	print("AUDIT[%s] meshes=%s mats=%s convertible=%s classes=%s colors=%s" % [
		tag, meshes, str(by_class), convertible, str(by_class), str(colors.size())])
	var i := 0
	for k in colors:
		if i >= 14:
			break
		print("AUDIT[%s] color %s" % [tag, k])
		i += 1
	return by_class


func _all(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out
