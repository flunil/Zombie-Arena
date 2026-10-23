extends Node
## اختبار: لاعب بعيد في المدينة — هل يصل الزومبي ويعمل الإطلاق؟ + تأكيد خبز navmesh


func _ready() -> void:
	var arena: Node = load("res://scenes/main/Arena.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: Node3D = arena.get_node_or_null("Player") as Node3D
	player.global_position = Vector3(60, 3.0, -40)  # داخل حدود المدينة الجديدة بعيدًا
	await get_tree().create_timer(8.0).timeout  # عدّ5ث +3ث موجة
	var wm_arena: Node = arena.get_node_or_null("WaveManager")
	var wm: Node = player.get_node_or_null("WeaponManager")
	var weapon: Node = wm.call("get_current")
	for s in range(6):
		await get_tree().create_timer(1.0).timeout
		var t2: Node3D = player.call("_nearest_enemy")
		var dist := -1.0
		if t2 != null:
			dist = player.global_position.distance_to(t2.global_position)
		var ammo := -1
		if weapon != null and weapon.has_method("get_ammo"):
			ammo = int(weapon.call("get_ammo"))
		print("[FARCHK] t=", 8 + s + 1, "s wave=", wm_arena.get("wave"),
				" nearest_d=", dist, " ammo=", ammo)
	get_tree().quit(0)
