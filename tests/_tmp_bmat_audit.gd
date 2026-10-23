extends Node
## تدقيق material_override على المباني الطويلة


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := (load("res://scenes/main/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	for i in 8:
		await get_tree().process_frame
	var props: Array = []
	_collect(arena, props)
	var n := 0
	for mi in props:
		var m := mi as MeshInstance3D
		var gab: AABB = m.global_transform * m.get_aabb()
		if gab.size.y <= 0.6:
			continue
		var mo := m.material_override
		var surf0 := m.get_active_material(0) if m.get_surface_override_material_count() > 0 else null
		var mo_col := "-"
		if mo is ShaderMaterial:
			mo_col = "SH c=%s" % str((mo as ShaderMaterial).get_shader_parameter("color"))
		elif mo is BaseMaterial3D:
			mo_col = "BM c=%s emis=%s" % [str((mo as BaseMaterial3D).albedo_color), (mo as BaseMaterial3D).emission_enabled]
		elif mo != null:
			mo_col = mo.get_class()
		var s0_col := "-"
		if surf0 is ShaderMaterial:
			s0_col = "SH c=%s" % str((surf0 as ShaderMaterial).get_shader_parameter("color"))
		elif surf0 is BaseMaterial3D:
			s0_col = "BM c=%s" % str((surf0 as BaseMaterial3D).albedo_color)
		print("OV ", m.name, " override=", mo_col, " surf0=", s0_col)
		n += 1
		if n >= 15:
			break
	get_tree().quit(0)


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c.name == &"Player" or c.is_in_group(&"fx") or c.is_in_group(&"enemies"):
			continue
		if c is MeshInstance3D:
			out.append(c)
		_collect(c, out)
