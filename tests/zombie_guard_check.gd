extends Node
## اختبار حراسة خريطة الزومبي: طيّر وهمي للفراغ + تعثّر وهمي بعيدًا
## يتحقق أن الحارس يُخرج الزومبي من الفراغ ويعيد نشر المتعثّر قرب اللاعب

var _died1 := false
var _died2 := false


func _on_died1() -> void:
	_died1 = true


func _on_died2() -> void:
	_died2 = true


func _ready() -> void:
	print("guard_check START")

	# أرضية اختبار (اللاعب لا يسقط في الفراغ)
	var floor_body := StaticBody3D.new()
	floor_body.name = "TestFloor"
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(400, 1, 400)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)

	var packed: PackedScene = load("res://scenes/enemies/ZombieBasic.tscn")
	var player_ps: PackedScene = load("res://scenes/player/Player.tscn")
	var player: Node3D = player_ps.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 1, 0)
	await get_tree().physics_frame

	var fails := 0

	# حالة1: زومبي طُيّر للفراغ → died + إخفاء خلال فحص دورية واحد
	var z1: Node3D = packed.instantiate()
	(z1 as Node).died.connect(_on_died1)
	add_child(z1)
	z1.global_position = Vector3(6498, 13901, 0)
	await get_tree().create_timer(1.6).timeout
	if _died1 and not z1.visible:
		print("PASS out_of_bounds evacuated")
	else:
		print("FAIL out_of_bounds died=", _died1, " visible=", z1.visible, " pos=", z1.global_position)
		fails += 1

	# حالة2: زومبي مجمّد (محاكاة تعثّر) على بعد48م → بعد3 فحوصات يُعاد نشره قرب اللاعب
	var z2: Node3D = packed.instantiate()
	(z2 as Node).died.connect(_on_died2)
	add_child(z2)
	z2.set_physics_process(false)  # تجمّد تام: لا يمشي ولا يسقط — يحاكي الجدار الذي يدسّه
	z2.global_position = Vector3(40, 1, -48)
	z2.velocity = Vector3.ZERO
	await get_tree().physics_frame
	for i in range(4):  # فحص1 يصفّر العدّاد (تحرك وهمي أول)، ثم3 فحوصات تعثّر
		z2.call("_guard_map")
		await get_tree().physics_frame
	var final_d := z2.global_position.distance_to(player.global_position)
	if final_d < 15.0 and z2.visible and not _died2:
		print("PASS stuck_respawned final_d=", final_d)
	else:
		print("FAIL stuck final_d=", final_d, " pos=", z2.global_position, " died=", _died2)
		fails += 1

	if fails == 0:
		print("guard_check ALL_PASS")
	else:
		print("guard_check FAILED count=", fails)
	get_tree().quit(1 if fails > 0 else 0)
