extends Node

# اختبار ربط أنيميشن اللاعب: وضعية الوقوف/الجري + تدوير النموذج نحو اتجاه الحركة

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("CHECK PASS: ", label)
	else:
		_fails += 1
		print("CHECK FAIL: ", label)


func _ready() -> void:
	var ps := load("res://scenes/player/Player.tscn") as PackedScene
	_check(ps != null, "Player.tscn loaded")
	if ps == null:
		_finish()
		return
	var p := ps.instantiate()
	add_child(p)
	for i in 8:
		await get_tree().physics_frame

	var model := p.get_node_or_null("Characters_Lis") as Node3D
	var ap := p.get_node_or_null("Characters_Lis/AnimationPlayer") as AnimationPlayer
	_check(model != null, "model node exists")
	_check(ap != null, "AnimationPlayer exists")
	if model == null or ap == null:
		_finish()
		return

	# 1) الوضعية الأولية والتكرار
	_check(String(ap.get_current_animation()) == "CharacterArmature|Idle_Gun",
		"starts in Idle_Gun (got: %s)" % ap.get_current_animation())
	_check(ap.has_animation("CharacterArmature|Run_Gun"), "Run_Gun exists")
	_check(ap.has_animation("Knife|Death"), "Death anim exists")
	_check(ap.get_animation("CharacterArmature|Idle_Gun").loop_mode == Animation.LOOP_LINEAR,
		"Idle_Gun loops")
	_check(ap.get_animation("CharacterArmature|Run_Gun").loop_mode == Animation.LOOP_LINEAR,
		"Run_Gun loops")

	# 2) الوجه الأولي: آخر اتجاه FORWARD=(0,0,-1) → atan2(0,-1)=PI
	_check(absf(absf(model.rotation.y) - PI) < 0.02, "initial facing = PI (got %f)" % model.rotation.y)

	# 3) حركة يسار (-X): وضعية جري + تدوير إلى -PI/2
	Input.action_press("move_left")
	for i in 50:
		await get_tree().physics_frame
	_check(String(ap.get_current_animation()) == "CharacterArmature|Run_Gun",
		"moving -> Run_Gun (got: %s)" % ap.get_current_animation())
	var err_l := wrapf(model.rotation.y - (-PI / 2.0), -PI, PI)
	_check(absf(err_l) < 0.03, "faces -PI/2 moving left (got %f)" % model.rotation.y)
	var ld: Vector3 = p.get("last_direction")
	_check(ld.x < -0.9, "last_direction points left")

	# 4) إيقاف الحركة → عودة الوقوف (بقاء الوجه كما هو)
	Input.action_release("move_left")
	for i in 12:
		await get_tree().physics_frame
	_check(String(ap.get_current_animation()) == "CharacterArmature|Idle_Gun",
		"stopped -> back to Idle_Gun (got: %s)" % ap.get_current_animation())

	# 5) حركة لأسفل (+z): الوجه = 0
	Input.action_press("move_down")
	for i in 50:
		await get_tree().physics_frame
	var err_d := wrapf(model.rotation.y, -PI, PI)
	_check(absf(err_d) < 0.03, "faces 0 moving +Z (got %f)" % model.rotation.y)
	Input.action_release("move_down")

	_finish()


func _finish() -> void:
	print("CHECK_RESULT: ", "ALL_PASS" if _fails == 0 else "FAIL(%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
