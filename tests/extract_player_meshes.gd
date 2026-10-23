extends SceneTree
## استخراج شبكات/جلد/مادة Player.tscn إلى ملفات .res/.tres خارجية
## يحفظ الموارد الكبرى فقط (Shaun body + Rifle + shadow + skin + material)
## التشغيل: Godot --headless --path <project> --script res://tests/extract_player_meshes.gd

const OUT := "res://meshes/player"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var ps: PackedScene = load("res://scenes/player/Player.tscn")
	if ps == null:
		print("ERR load"); quit(1); return
	var root: Node = ps.instantiate()
	if root == null:
		print("ERR instantiate"); quit(1); return

	# احفظ المادة أولًا agar الشبكة تشير إليها بمسار
	var mat_saved := false
	var body_mesh: ArrayMesh = null
	var rifle_mesh: ArrayMesh = null
	var body_skin: Skin = null

	for n in _all(root):
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.name == "Shaun":
				body_mesh = mi.mesh as ArrayMesh
				body_skin = mi.skin
			elif mi.name == "Rifle":
				rifle_mesh = mi.mesh as ArrayMesh

	# المادة من سطح الشبكة
	if body_mesh != null and body_mesh.get_surface_count() > 0:
		var m := body_mesh.surface_get_material(0)
		if m is StandardMaterial3D:
			var mp := OUT + "/player_mat.tres"
			print("SAVE mat err=", ResourceSaver.save(m, mp))
			mat_saved = true

	if body_mesh != null:
		print("SAVE body err=", ResourceSaver.save(body_mesh, OUT + "/player_body.res"))
	if rifle_mesh != null:
		print("SAVE rifle err=", ResourceSaver.save(rifle_mesh, OUT + "/player_rifle.res"))
	if body_skin != null:
		print("SAVE skin err=", ResourceSaver.save(body_skin, OUT + "/player_skin.res"))

	print("DONE mat_saved=", mat_saved)
	root.free()
	quit(0)


func _all(n: Node, acc: Array = []) -> Array:
	acc.append(n)
	for c in n.get_children():
		_all(c, acc)
	return acc
