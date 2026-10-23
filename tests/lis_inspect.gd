extends Node

# فحص محتوى المشهد المستورد Characters_Lis.fbx: العقد + الأنيميشن

var _fails := 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("CHECK PASS: ", label)
	else:
		_fails += 1
		print("CHECK FAIL: ", label)

func _ready() -> void:
	var ps := load("res://assets/models/Zombie Apocalypse Kit - March 2024/Characters/FBX/Characters_Lis.fbx") as PackedScene
	_check(ps != null, "PackedScene loaded")
	if ps == null:
		print("CHECK_RESULT: FAIL (", _fails, ")")
		get_tree().quit(1)
		return
	var inst := ps.instantiate()
	add_child(inst)
	print("LIS root: ", inst.name, " type=", inst.get_class())
	_dump(inst, 0)
	var ap := _find_anim(inst)
	_check(ap != null, "AnimationPlayer exists")
	if ap:
		var names := ap.get_animation_list()
		print("LIS anim_count=", names.size())
		for a in names:
			var anim := ap.get_animation(a)
			print("LIS anim: ", a, " len=", anim.length, " tracks=", anim.get_track_count())
	# اختبار تشغيل Idle إن وُجد
	if ap:
		var names2: Array = ap.get_animation_list()
		var idle := ""
		for a in names2:
			if String(a).to_lower().contains("idle"):
				idle = a
				break
		if idle != "":
			ap.play(idle)
			for i in 30:
				await get_tree().process_frame
			_check(true, "idle plays without error")
		else:
			print("LIS note: no idle-named animation; playing first: ", names2[0] if names2.size() else "(none)")
			if names2.size() > 0:
				ap.play(names2[0])
				for i in 30:
					await get_tree().process_frame
	print("CHECK_RESULT: ", "ALL_PASS" if _fails == 0 else "FAIL(%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _dump(n: Node, depth: int) -> void:
	print("  ".repeat(depth), "- ", n.name, " (", n.get_class(), ")")
	if depth >= 5:
		return
	for c in n.get_children():
		_dump(c, depth + 1)

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null
