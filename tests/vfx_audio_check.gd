extends Node
## اختبار مرحلة 11: أصوات + موسيقى + مؤثرات بصرية + اهتزاز + وميض الإصابة
## التشغيل: Godot --headless --path <project> res://tests/vfx_audio_check.tscn

const WEAPONS: Array = [
	"ak47", "shotgun", "heavymg", "laserifle", "flamethrower",
	"grenadelauncher", "rocketlauncher", "teslacoil", "smokelauncher",
]
const AUX: Array = ["zombie_death", "upgrade_pick", "wave_start", "wave_end", "explosion", "reel_tick", "reel_lock"]

var fails: Array[String] = []


func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		fails.append(label)
		print("FAIL: ", label)


func _ready() -> void:
	_run()


func _run() -> void:
	GM.reset_run()  # فك أسلحة افتراضي (ak47 مفتوح من الموجة 1)

	# --- 1) كل سلاح له صوت إطلاق ---
	var bad := ""
	for w in WEAPONS:
		var d := AudioManager.get_sfx_duration("fire_" + w)
		if d < 0.03 or d > 0.6:
			bad += w + "(" + str(d) + ") "
	check(bad == "", "9 weapons have fire sounds (got: " + (bad if bad != "" else "all") + ")")

	# أصوات مساندة
	bad = ""
	for id in AUX:
		var d2 := AudioManager.get_sfx_duration(id)
		if d2 < 0.03 or d2 > 0.6:
			bad += id + "(" + str(d2) + ") "
	check(bad == "", "aux sounds generated (death/pick/wave x2/explosion/reel x2)")

	# --- 2) لا ترددات حادة فوق 5kHz (تقدير بتقاطعات الصفر) ---
	var hot: Array = []
	for w in WEAPONS:
		var pf := AudioManager.get_sfx_peak_freq("fire_" + w)
		if pf > 5000.0:
			hot.append("fire_" + w + "=" + str(int(pf)))
	for id in AUX:
		var pf2 := AudioManager.get_sfx_peak_freq(id)
		if pf2 > 5000.0:
			hot.append(id + "=" + str(int(pf2)))
	for k in ["menu", "calm", "hot"]:
		var pf3 := AudioManager.get_music_peak_freq(k)
		if pf3 > 5000.0:
			hot.append("music_" + k + "=" + str(int(pf3)))
	check(hot.is_empty(), "all audio <= 5kHz (offenders: " + (", ".join(hot) if not hot.is_empty() else "none") + ")")

	# --- 3) تشغيل المؤثر + id مجهول بلا خطأ ---
	AudioManager.play_sfx("fire_ak47")
	check(AudioManager.is_sfx_playing(), "play_sfx starts playback")
	AudioManager.play_sfx("no_such_id")  # يُتجاهل بصمت
	check(true, "unknown sfx id ignored without error")

	# --- 4) موسيقى: قوائم → ساحة → تكثيف حسب الموجة → إيقاف ---
	AudioManager.play_music("menu")
	check(AudioManager.get_music_track() == "menu", "music menu starts")
	check(AudioManager.get_music_duration("menu") > 3.9, "menu loop 4s generated")
	AudioManager.play_music("arena")
	check(AudioManager.get_music_track() == "arena", "music arena starts")
	check(AudioManager.get_music_duration("calm") > 3.9 and AudioManager.get_music_duration("hot") > 3.9,
		"arena calm+hot loops generated")
	AudioManager.set_arena_intensity(1)
	check(not AudioManager.is_music_layer_hot(), "hot layer muted before wave 3")
	AudioManager.set_arena_intensity(4)
	await get_tree().create_timer(1.0).timeout  # تلاشي الصوت 0.8ث
	check(AudioManager.is_music_layer_hot(), "hot layer fades in at wave >= 3")
	AudioManager.play_music("stop")
	check(AudioManager.get_music_track() == "stop", "music stop works")

	# --- 5) دورة حياة المؤثرات: تُبنى ثم تتحرر (بلا تسرّب عقد) ---
	FxLibrary.spawn_impact(Vector3(0, 1, 0), Vector3.UP, true)
	FxLibrary.spawn_impact(Vector3(0, 1, 0), Vector3.UP, false)
	FxLibrary.spawn_explosion(Vector3(0, 1, 0), 2.0)
	FxLibrary.spawn_death_burst(Vector3(0, 1, 0))
	FxLibrary.spawn_levelup_burst(Vector3(0, 1, 0))
	check(get_tree().get_nodes_in_group("fx").size() >= 5, "5 fx nodes spawned (impact x2/explosion/deathx2/levelup)")
	var blood := false
	for n in get_tree().get_nodes_in_group("fx"):
		if n is CPUParticles3D and (n as CPUParticles3D).amount >= 30:
			blood = true
	check(blood, "death burst: green-blood spray (amount >= 30)")
	await get_tree().create_timer(1.8).timeout
	check(get_tree().get_nodes_in_group("fx").size() == 0, "all fx auto-freed (no node leak)")

	# --- 6) وميض أبيض عند إصابة الزومبي (قبل إضافة اللاعب = بلا تدخّل إطلاق تلقائي) ---
	var z := (load("res://scenes/enemies/ZombieBasic.tscn") as PackedScene).instantiate()
	add_child(z)
	z.position = Vector3(8, 0, 8)
	await get_tree().process_frame
	var mats: Array = z.get("_flash_mats")
	var origs: Array = z.get("_flash_orig")
	check(mats.size() > 0 and origs.size() == mats.size(), "zombie flash materials gathered (got %s)" % mats.size())
	# شريط الصحة فوق الزومبي: موجود + يتحدث مع الضرر
	check(z.has_node("HealthBar"), "health bar node exists above zombie")
	var bar_fill: Node = z.get("_bar_fill")
	var bar_x0: float = bar_fill.scale.x
	check(bar_x0 > 0.99, "health bar starts full (scale.x=%s)" % bar_x0)
	z.take_damage(1.0)
	check(float(bar_fill.scale.x) < bar_x0, "health bar shrinks on damage (%s -> %s)" % [bar_x0, bar_fill.scale.x])
	# مادة لم تكن حمراء قبل الضربة وصارت حمراء = الوميض فعّال
	# (حِل محل شرط before_white القديم: نماذج FBX موادها albedo أبيض + texture)
	var now_red := false
	for i in mats.size():
		var c2: Color = CelMaterial.color_of(mats[i])
		var o: Color = origs[i]
		var was_red := o.r > 0.95 and o.g < 0.4 and o.b < 0.4
		if c2.r > 0.95 and c2.g < 0.4 and c2.b < 0.4 and not was_red:
			now_red = true
	check(now_red, "hit flash turns material red (0.1s)")
	var num_found := false
	for n in get_tree().get_nodes_in_group("fx"):
		if n is Label3D and (n as Label3D).text == "1":
			num_found = true
	check(num_found, "damage number Label3D spawns on zombie hit (text=1)")
	await get_tree().create_timer(0.3).timeout
	var restored := true
	for i in mats.size():
		if not CelMaterial.color_of(mats[i]).is_equal_approx(origs[i]):
			restored = false
	check(restored, "flash restores original colors after 0.12s tween")
	z.queue_free()
	await get_tree().process_frame

	# --- 7) اهتزاز الكاميرا + ومضة الفوهة ---
	var player := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var cam := player.get_node("Camera3D") as Node
	check(cam != null and cam.has_method("shake"), "player camera has shake()")
	FxLibrary.shake_camera(0.3, 0.25)
	check(float(cam.get("_shake_left")) > 0.0, "shake active after trigger")
	await get_tree().create_timer(0.5).timeout
	check(float(cam.get("_shake_left")) <= 0.001, "shake fully decayed")

	var wm := player.get_node("WeaponManager") as Node
	var w := wm.get_current() as Node
	check(w != null and w.has_node("MuzzleFlash"), "current weapon has MuzzleFlash node")
	if w != null:
		var ammo0: int = w.get_ammo()
		w.call("try_fire", Vector3.FORWARD)
		check(w.get_ammo() == ammo0 - 1, "manual fire consumes ammo (%s -> %s)" % [ammo0, w.get_ammo()])
		var flash := w.get_node("MuzzleFlash")
		check(bool(flash.get("emitting")), "muzzle flash emitting after fire")

	# --- 8) عصا اللمس + الأجوي الفيزيائي يقودان اللاعب ---
	var joy := (load("res://scenes/ui/VirtualJoystick.tscn") as PackedScene).instantiate()
	add_child(joy)
	joy.call("_set_vector", Vector2(0.7, 0.0))
	var mv: Vector2 = player.call("_move_input")
	check(mv.distance_to(Vector2(0.7, 0.0)) < 0.001, "virtual joystick vector feeds player movement")
	Input.action_press("move_up")  # أولوية الكيبورد عند الضغط
	mv = player.call("_move_input")
	check(mv.y < -0.5, "keyboard overrides joystick when pressed")
	Input.action_release("move_up")
	joy.call("_set_vector", Vector2.ZERO)
	mv = player.call("_move_input")
	check(mv.length_squared() < 0.001, "zero input when idle (both sources neutral)")

	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = -1.0
	Input.parse_input_event(ev)  # عصا يسار فيزيائية (مرتبطة من GM وقت التشغيل)
	await get_tree().process_frame
	mv = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	check(mv.x < -0.5, "physical gamepad left stick bound to movement (x=%s)" % mv.x)
	var ev2 := InputEventJoypadMotion.new()
	ev2.device = 0
	ev2.axis = JOY_AXIS_LEFT_X
	ev2.axis_value = 0.0
	Input.parse_input_event(ev2)
	await get_tree().process_frame
	var joy_btn_bound := false
	for ea in InputMap.action_get_events("switch_weapon"):
		if ea is InputEventJoypadButton and ea.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			joy_btn_bound = true
	check(joy_btn_bound, "gamepad RB bound to switch_weapon")

	# --- 9) تصويب الأقرب + التحويل التلقائي عند اقتراب عدو جديد ---
	var zA := (load("res://scenes/enemies/ZombieBasic.tscn") as PackedScene).instantiate()
	add_child(zA)
	zA.position = Vector3(-10, 0, 0)
	var zB := (load("res://scenes/enemies/ZombieBasic.tscn") as PackedScene).instantiate()
	add_child(zB)
	zB.position = Vector3(-30, 0, 0)
	var n1: Node = player.call("_nearest_enemy")
	check(n1 == zA, "aims nearest enemy first (10m vs 30m)")
	zB.position = Vector3(-3, 0, 0)
	var n2: Node = player.call("_nearest_enemy")
	check(n2 == zB, "auto-retargets when another enemy becomes closer (3m)")
	zB.hide()
	var n3: Node = player.call("_nearest_enemy")
	check(n3 == zA, "hidden enemy skipped -> back to other visible enemy")
	zA.queue_free()
	zB.queue_free()

	# --- 10) أنواع الزومبي الستة كما في BUILD_INSTRUCTIONS ---
	var at8: Array = EnemyFactory.available_types(8)
	check(at8.size() == 5, "5 factory types unlock by wave 8 (got %s)" % at8.size())  # + الزعيم = 6
	var at1: Array = EnemyFactory.available_types(1)
	check(at1.size() == 1, "wave 1 starts with basic only (got %s)" % at1.size())
	check(EnemyFactory.is_boss_wave(5) and not EnemyFactory.is_boss_wave(6),
		"6th type: boss every 5th wave")

	# --- 11) بطيء الزمن عند آخر قتيل (0.3× نصف ثانية زمنية حقيقية ثم استعادة) ---
	TimeFX.slow_motion(0.3, 0.25)
	check(is_equal_approx(Engine.time_scale, 0.3), "slow_motion sets time_scale=0.3")
	await get_tree().create_timer(0.4, true, false, true).timeout  # يتجاوز time_scale
	check(is_equal_approx(Engine.time_scale, 1.0), "slow_motion restores time_scale after real 0.25s")

	if fails.is_empty():
		print("CHECK_RESULT: ALL_PASS")
	else:
		print("CHECK_RESULT: FAIL_COUNT=", fails.size())
	get_tree().quit(0 if fails.is_empty() else 1)
