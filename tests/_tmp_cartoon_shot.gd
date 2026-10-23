extends Node
## مسبار تحقق المظهر الكرتوني: يحمّل Arena ويحفظ لقطتين (لعب + أفق المباني).
## TOON_OFF=1 يفصل سكربت toon_look قبل الإضافة للشجرة (خط أساس للمقارنة).

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var prefix := "toon_off" if OS.get_environment("TOON_OFF") == "1" else "toon_on"
	var arena := (load("res://scenes/main/Arena.tscn") as PackedScene).instantiate()
	if prefix == "toon_off":
		var we: Node = arena.get_node("WorldEnvironment")
		we.set_script(null)
	add_child(arena)
	var player: Node3D = arena.get_node("Player")
	var health: Node = player.get_node_or_null("Health")
	if health:
		(health as HealthComponent).max_health = 999999.0
		(health as HealthComponent).health = 999999.0
	for i in 2:
		var z := (load("res://scenes/enemies/ZombieBasic.tscn") as PackedScene).instantiate()
		arena.add_child(z)
		z.global_position = player.global_position + Vector3(-2.0 + 4.0 * i, 0.0, 12.0)
	for i in 8:
		await get_tree().process_frame
	await _snap("user://%s_01_play.png" % prefix)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 70.0
	cam.global_position = Vector3(0.0, 25.0, -35.0)
	cam.look_at(Vector3(31.0, 10.0, 14.0), Vector3.UP)
	cam.current = true
	for i in 3:
		await get_tree().process_frame
	await _snap("user://%s_02_skyline.png" % prefix)
	# لقطة علوية (الخريطة) فوق منطقة اللاعب
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 60.0
	cam.global_position = Vector3(player.global_position.x, 80.0, player.global_position.z + 8.0)
	cam.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	for i in 3:
		await get_tree().process_frame
	await _snap("user://%s_03_map.png" % prefix)
	var env: Environment = (arena.get_node("WorldEnvironment") as WorldEnvironment).environment
	print("TOON[%s] sat=%s con=%s tone=%s glow=%s amb=%s" % [
		prefix, env.adjustment_saturation, env.adjustment_contrast,
		env.tonemap_mode, env.glow_enabled, env.ambient_light_energy])
	get_tree().quit(0)


func _snap(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("TOON saved ", path, " ", img.get_size())
