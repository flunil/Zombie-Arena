extends Node
## اختبار حدود الرصاص بعد توسعة المدينة: داخل المدينة الجديدة يطير، وخارج الحدود يُقتل


func _ready() -> void:
	print("bullet_bounds_check START")
	var packed: PackedScene = load("res://scenes/weapons/Bullet.tscn")
	var fails := 0

	# حالة1: نقطة داخل المدينة الجديدة (50,0) — خارج الصندوق القديم±24.4 — يجب أن تطير
	var b1: Area3D = packed.instantiate()
	add_child(b1)
	b1.global_position = Vector3(50, 1, 0)
	b1.direction = Vector3(0, 0, -1)
	b1.speed = 30.0
	b1.life = 3.0
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(b1) and not b1.is_queued_for_deletion():
		var moved := b1.global_position.distance_to(Vector3(50, 1, 0))
		if moved > 10.0:
			print("PASS city_bullet_flew moved=", moved)
		else:
			print("FAIL city_bullet_stuck moved=", moved, " pos=", b1.global_position)
			fails += 1
	else:
		print("FAIL city_bullet_freed_early")
		fails += 1

	# حالة2: نقطة خارج حدود المدينة (150,0) — يجب أن تُقتل فورًا
	var b2: Area3D = packed.instantiate()
	add_child(b2)
	b2.global_position = Vector3(150, 1, 0)
	b2.direction = Vector3(0, 0, -1)
	b2.speed = 30.0
	b2.life = 3.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(b2) or b2.is_queued_for_deletion():
		print("PASS out_of_bounds_freed")
	else:
		print("FAIL out_of_bounds_alive pos=", b2.global_position)
		fails += 1

	if fails == 0:
		print("bullet_bounds_check ALL_PASS")
	else:
		print("bullet_bounds_check FAILED count=", fails)
	get_tree().quit(1 if fails > 0 else 0)
