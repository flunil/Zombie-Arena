extends Node
## فحص: لوحة التصويب تتبع الزومبي نفسه الذي يُطلق عليه اللاعب (الأقرب الحيّ)

var fails: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: " + msg)
	else:
		fails.append(msg)
		print("FAIL: " + msg)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var menu := (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	var start: Button = menu.find_child("StartButton", true, false) as Button
	check(start != null, "StartButton exists in MainMenu")
	if start == null:
		_finish()
		return
	start.pressed.emit()

	var waited := 0.0
	while waited < 6.0:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
		var cs := get_tree().current_scene
		if cs != null and cs.scene_file_path.ends_with("Arena.tscn"):
			break
	var arena := get_tree().current_scene
	check(arena != null and arena.scene_file_path.ends_with("Arena.tscn"), "reached Arena")
	if arena == null:
		_finish()
		return

	var player: Node = arena.get_node_or_null("Player")
	check(player != null, "Player exists")
	if player == null:
		_finish()
		return
	check(player.get("_reticle") != null, "player has a TargetReticle instance (created in code)")

	var wm: Node = player.get_node_or_null("WeaponManager")
	while waited < 6.0 and wm != null and wm.call("get_current") == null:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	var w: Node = wm.call("get_current") if wm != null else null
	check(w != null, "weapon selected")
	if w == null:
		_finish()
		return

	var wmn: Node = arena.get_node_or_null("WaveManager")
	waited = 0.0
	while waited < 14.0 and wmn != null and int(wmn.get("wave")) < 1:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	check(wmn != null and int(wmn.get("wave")) >= 1, "wave 1 started")

	# انتظر حتى يبدأ الإطلاق التلقائي فعلياً (تتبّع هدف)
	waited = 0.0
	var ret: Node3D = player.get("_reticle") as Node3D
	while waited < 25.0:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
		if ret != null and ret.get("_target") != null:
			break
	var near: Node3D = player.call("_nearest_enemy") as Node3D
	check(near != null, "auto-fire has a live target (_nearest_enemy)")
	check(ret != null and ret.get("_target") != null, "reticle is tracking a target")

	if near == null or ret == null or ret.get("_target") == null:
		_finish()
		return

	var tracked: Node3D = ret.get("_target") as Node3D
	check(tracked == near, "reticle target == nearest enemy (same zombie being fired at)")
	check(not (tracked.has_method("is_dead") and tracked.is_dead()), "tracked target is alive")
	check(bool(ret.get("visible")), "reticle is visible while firing")

	# موقع اللوحة: على شعاع النظر نفسه من الكاميرا إلى قدمي الهدف ⇒ نفس البكسل على الشاشة
	# (الإزاحة OCCLUDE لا تغيّر موضع الشاشة إطلاقاً — لذلك لا نقارن XZ بل الإسقاط)
	var feet := Vector3(float(tracked.global_position.x), float(ret.call("_feet_y", tracked)),
		float(tracked.global_position.z))
	var dy := float(ret.global_position.y) - feet.y
	check(dy >= -0.1 and dy <= 1.7, "reticle lifted toward camera from feet (dy=%s)" % dy)

	# اللوحة أقرب للكاميرا من الزومبي وتواجهها (الوجه الأمامي +Z نحو الكاميرا)
	var cam: Camera3D = arena.get_viewport().get_camera_3d()
	check(cam != null, "camera found")
	if cam != null:
		var d_ret := cam.global_position.distance_to(ret.global_position)
		var d_tgt := cam.global_position.distance_to(feet)
		check(d_ret < d_tgt, "reticle closer to camera than its zombie (ret=%s tgt=%s)" % [d_ret, d_tgt])
		var z_axis: Vector3 = (ret.global_transform as Transform3D).basis.z
		var to_cam: Vector3 = (cam.global_position - ret.global_position).normalized()
		check(z_axis.dot(to_cam) > 0.7, "reticle front face points at camera (dot=%s)" % z_axis.dot(to_cam))
		var ndc_a := cam.unproject_position(ret.global_position)
		var ndc_b := cam.unproject_position(feet)
		var screen_err := ndc_a.distance_to(ndc_b)
		check(screen_err < 0.5, "reticle overlaps the feet on screen (err=%s px)" % screen_err)

	# إخفاء عند موت كل الأعداء
	var any_alive := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and (e as Node3D).visible and not (e.has_method("is_dead") and e.is_dead()):
			any_alive = true
			break
	if not any_alive:
		await get_tree().process_frame
		await get_tree().process_frame
		check(ret.get("_target") == null or not bool(ret.get("visible")),
			"reticle hides when no live enemies remain")

	_finish()


func _finish() -> void:
	var n := fails.size()
	if n == 0:
		print("RETICLE_TRACK: ALL_PASS")
	else:
		print("RETICLE_TRACK: FAIL_COUNT=%s" % n)
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if n == 0 else 1)
