extends Node
## فحص النقرة المزدوجة على الجوي: تُطلق آخر متجه + اللاعب ينفلت نحوه بسرعة القفزة
## ملاحظة: الأحداث تُسلَّم باستدعاء مباشر لـ _input لأن transform السطح في headless
## يضاعف الإحداثيات ×20 (نافذة64 وهمية) فلا تصل لنطاق الجوي.

var _fails: int = 0
var _tapped: bool = false
var _tap_vec: Vector2 = Vector2.ZERO


func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _ready() -> void:
	await get_tree().process_frame
	await _test_double_tap_signal()
	await _test_player_dash()
	print("CHECK_RESULT: ", "ALL_PASS" if _fails == 0 else "FAIL_COUNT=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


## الجوي وحده: سحب يسجل آخر متجه ثم نقرتان سريعتان تُطلق الإشارة بالمتجه نفسه
func _test_double_tap_signal() -> void:
	var joy: Node = load("res://scenes/ui/VirtualJoystick.tscn").instantiate()
	add_child(joy)
	await get_tree().process_frame
	joy.connect("double_tap", func(v: Vector2) -> void:
		_tapped = true
		_tap_vec = v)

	# سحب لليمين لتسجيل آخر متجه (70px عن المركز → اتجاه +x)
	_touch(joy, true, Vector2(200, 130))
	await get_tree().process_frame
	_drag(joy, Vector2(250, 130))
	await get_tree().process_frame
	_touch(joy, false, Vector2(250, 130))
	check(joy.call("get_move_vector") == Vector2.ZERO, "vector resets on release")
	check((joy.call("get_last_vector") as Vector2).x > 0.5, "last vector saved (+x)")

	# نقرتان سريعتان بعد فاصل زمني عن السحب (>DOUBLE_TAP_TIME)
	await get_tree().create_timer(0.45).timeout
	_tapped = false
	_tap_vec = Vector2.ZERO
	_touch(joy, true, Vector2(130, 130))
	await get_tree().process_frame
	_touch(joy, false, Vector2(130, 130))
	await get_tree().create_timer(0.1).timeout
	_touch(joy, true, Vector2(130, 130))
	await get_tree().process_frame
	check(_tapped, "double_tap signal emitted")
	check(_tap_vec.length() > 0.5, "signal carries last joystick vector (got %s)" % _tap_vec)
	_touch(joy, false, Vector2(130, 130))
	await get_tree().process_frame
	joy.queue_free()
	await get_tree().process_frame


## اللاعب: نقرتان مزدوجتان → سرعة انزلاق 24 (فوق سرعة الحركة 8) + منع تكرار فعّال
func _test_player_dash() -> void:
	var p: Node = load("res://scenes/player/Player.tscn").instantiate()
	var joy: Node = load("res://scenes/ui/VirtualJoystick.tscn").instantiate()
	add_child(p)
	add_child(joy)
	await get_tree().process_frame
	await get_tree().process_frame  # اللاعب يربط double_tap في أول إطار فيزياء

	# حدّث آخر متجه للجوي (سحب لليمين) ثم انتظر انتهاء نافذة النقر المزدوج
	_touch(joy, true, Vector2(200, 130))
	await get_tree().process_frame
	_drag(joy, Vector2(250, 130))
	await get_tree().process_frame
	_touch(joy, false, Vector2(250, 130))
	await get_tree().create_timer(0.45).timeout

	var start := (p as Node3D).global_position
	# نقرتان سريعتان
	_touch(joy, true, Vector2(130, 130))
	await get_tree().process_frame
	_touch(joy, false, Vector2(130, 130))
	await get_tree().create_timer(0.1).timeout
	_touch(joy, true, Vector2(130, 130))
	await get_tree().process_frame
	_touch(joy, false, Vector2(130, 130))

	# داخل نافذة الانزلاق: السرعة الأفقية ≈ DASH_SPEED (24) بدل 0/8
	await get_tree().create_timer(0.06).timeout
	var hspeed := Vector2(float(p.get("velocity").x), float(p.get("velocity").z)).length()
	check(hspeed > 12.0, "dash speed active (got %.1f)" % hspeed)
	check(float(p.get("_dash_cd")) > 0.0, "dash cooldown armed")
	check((p as Node3D).global_position.x > start.x + 0.3,
		"moved toward +x last joystick dir (%.2f -> %.2f)" % [start.x, (p as Node3D).global_position.x])

	# انتهاء الانزلاق: السرعة تعود للعادي (بلا مدخل → ≈0)
	await get_tree().create_timer(0.3).timeout
	var hspeed2 := Vector2(float(p.get("velocity").x), float(p.get("velocity").z)).length()
	check(hspeed2 < 8.0, "dash ended, speed back to normal (got %.1f)" % hspeed2)
	p.queue_free()
	joy.queue_free()
	await get_tree().process_frame


## تسليم حدث لمس مباشر للجوي (تجاوز transform رأس التشغيل)
func _touch(joy: Node, pressed: bool, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = pressed
	ev.position = pos
	joy.call("_input", ev)


func _drag(joy: Node, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = pos
	ev.relative = Vector2.ZERO
	joy.call("_input", ev)
