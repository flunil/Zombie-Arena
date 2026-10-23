extends Node
## مسبار مؤقت: يشغّل Arena داخل نافذة حقيقية + صحة لاعب عالية + لقطات شاشة
## المرحلة B ترفع شفافية الزجاج (glass alpha) لنرى حدّ المنطقة المرئية من اللوحة
## ونحدّد من يقصّ أعلى الحلقة.

const OUT_DIR := "user://probe2"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var arena := (load("res://scenes/main/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	await _run(arena)


func _run(arena: Node) -> void:
	var logf := FileAccess.open(OUT_DIR + "/probe.log", FileAccess.WRITE)
	var p: Node = arena.get_node_or_null("Player")
	var r: Node = p.get("_reticle") if p != null else null
	var mi: MeshInstance3D = r.get_node_or_null("ReticleMesh") if r != null else null
	var mat: Material = mi.mesh.material if (mi != null and mi.mesh is QuadMesh) else null
	var phase := "A"
	var shots := 0
	for i in 24:
		await get_tree().create_timer(1.0).timeout
		if p == null:
			p = arena.get_node_or_null("Player")
			continue
		var h: Node = p.get_node_or_null("Health")
		if h != null:
			h.max_health = 999999.0
			h.health = 999999.0
		if r == null:
			r = p.get("_reticle")
		if i == 10 and mat is ShaderMaterial:
			phase = "B"
			var g: Color = mat.get_shader_parameter("glass_color")
			g.a = 0.55
			mat.set_shader_parameter("glass_color", g)
			logf.store_line("glass alpha -> 0.55")
		if r == null:
			continue
		var tgt: Node = r.get("_target")
		var vis: bool = bool(r.get("visible"))
		logf.store_line("%s t=%s vis=%s tgt=%s pos=%s" % [
			phase, i, vis, (tgt.name if tgt != null else "null"), r.global_position])
		if vis and tgt != null and shots < 8:
			shots += 1
			var img := get_viewport().get_texture().get_image()
			img.save_png(OUT_DIR + "/%s_%02d.png" % [phase, shots])
			logf.store_line("  shot %s_%02d" % [phase, shots])
		logf.flush()
	logf.store_line("done shots=%s" % shots)
	logf.close()
	get_tree().quit(0)

