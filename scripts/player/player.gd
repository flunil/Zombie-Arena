extends CharacterBody3D
## اللاعب: حركة بثمانية اتجاهات نسبةً إلى اتجاه الكاميرا + إطلاق تلقائي على أقرب عدو

signal gold_changed(new_gold: int)

const SPEED := 8.0          # سرعة الحركة بوحدات/ثانية
const GRAVITY := 24.0       # جاذبية مسرّعة للهاتف
const AUTO_FIRE_RANGE := 60.0  # مدى الإطلاق التلقائي بالمتر (بلا أعداء: بلا إطلاق)
const DASH_SPEED := 24.0    # سرعة القفزة/الانزلاق من النقرة المزدوجة (3× الحركة)
const DASH_TIME := 0.18     # زمن الانزلاق بالثانية
const DASH_CD := 0.5        # زمن منع التكرار بين القفزات (ثانية)

## ذكاء التصويب: اعتراض + ترجيح تهديد + ثبات هدف
const AIM_LEAD := 0.85      # نسبة اعتراض سرعة الزومبي (1=كامل سرعة الهدف)
const TARGET_STICKY := 0.4  # ثانية تفضيل الهدف الحالي (يقلّل تذبذب التحويل)
const STICKY_MULT := 1.55   # وزن الهدف المقفل عليه
const THREAT_MULT := 2.2    # وزن من هو ضمن مدى هجومه/لحاقه (قتال فوري)
const FINISH_MULT := 1.7    # وزن من صحته منخفضة (إنهاء القتل)

const MODEL_PATH := "Characters_Lis"            # عقدة النموذج في المشهد (FBX مضمّن)
const ANIM_IDLE := "CharacterArmature|Idle_Gun"  # وضعية الوقوف (مسلّح)
const ANIM_RUN := "CharacterArmature|Run_Gun"    # وضعية الجري (مسلّح)
const ANIM_DEATH := "Knife|Death"                # وضعية الموت
const TURN_SPEED := 14.0                         # سرعة تدوير الوجه نحو اتجاه الحركة (بالراديان/ث)

@export var camera_path: NodePath = NodePath("Camera3D")

var gold: int = 0
var last_direction: Vector3 = Vector3.FORWARD  # آخر اتجاه حركة (احتياط للتصويب)
var _aim_dir: Vector3 = Vector3.ZERO          # اتجاه الرمي الحالي (يتخذ النموذج اتجاهه إن وُجد)
var _heal_acc: float = 0.0                     # مراكم الشفاء التلقائي (ترقية auto_heal)
var _joy_ui: Node = null                       # عصا اللمس (VirtualJoystick) — يُعاد البحث عند فقدانها
var _model: Node3D = null                      # عقدة النموذج (ندوّرها وحدها — الكاميرا مستقلة عنها)
var _anim: AnimationPlayer = null              # مشغّل الأنيميشن داخل عقدة النموذج
var _current_anim: String = ""                 # الوضعية الحالية (حارس ضد إعادة التشغيل كل إطار)
var _dash_dir: Vector3 = Vector3.ZERO          # اتجاه القفزة الجارية
var _dash_time: float = 0.0                    # المتبقي من زمن القفزة
var _dash_cd: float = 0.0                      # المتبقي من منع التكرار
var _pending_dash: Vector2 = Vector2.ZERO      # قفزة مقترحة من النقرة المزدوجة (تُنفَّذ في الفيزياء)
var _model_base_y: float = 0.0                 # ارتفاع النموذج الأصلي (للقفزة البصرية)
var _reticle: TargetReticle = null             # لوحة التصويب المتتبّعة للزومبي المستهدف
var _locked_target: Node3D = null              # هدف مقفل عليه (ثبات التصويب)
var _lock_timer: float = 0.0                   # متبقٍّ من مدة الثبات


func _ready() -> void:
	add_to_group("player")
	# Make sure our camera is active so the movement basis stays stable
	var cam := get_node_or_null(camera_path) as Camera3D
	if cam and not cam.current:
		cam.current = true
	var health := get_node_or_null("Health") as HealthComponent
	if health != null:
		health.max_health = 100.0 + SaveSystem.get_health_bonus()  # ترقية الصحة الدائمة
		health.reset_health()
		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)
		if not health.damaged.is_connected(_on_health_damaged):
			health.damaged.connect(_on_health_damaged)
	_model = get_node_or_null(MODEL_PATH) as Node3D
	_anim = get_node_or_null(MODEL_PATH + "/AnimationPlayer") as AnimationPlayer
	if _model != null:
		_model_base_y = _model.position.y
	_setup_model_anim()
	_reticle = TargetReticle.new()  # لوحة التصويب — تُنشأ برمجياً بلا تعديل المشهد
	add_child(_reticle)
	CelMaterial.apply_tree(get_node_or_null(MODEL_PATH))  # تحويل خلوٍّ للنموذج والأسلحة (تحت Characters_Lis فقط)
	# مؤثرات الترقيات المرئية (فقاعة الدرع/هالة الغاضب/وميض الشفاء) — عقدة بجانب اللاعب
	if get_node_or_null("UpgradeVisuals") == null:
		var vis := Node3D.new()
		vis.name = "UpgradeVisuals"
		vis.set_script(load("res://scripts/player/upgrade_visuals.gd"))
		add_child(vis)
	gold_changed.emit(gold)


## تجهيز النموذج: تكرار الوضعيات المستمرة (المستورد LOOP_NONE افتراضياً) + مواءمة الوجه + بدء الوقوف
func _setup_model_anim() -> void:
	if _anim == null:
		return
	for n in [ANIM_IDLE, ANIM_RUN]:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	if _model != null:
		# محتوى العقدة يواجه +Z داخلياً (المستخدم دوّرها180° في المشهد لتصبح في الاتجاه الافتراضي)
		# الهدف = atan2(dir.x, dir.z) ليطابق اتجاه الحركة عند آخر اتجاه معروف
		_model.rotation.y = atan2(last_direction.x, last_direction.z)
	_play_anim(ANIM_IDLE)


func _on_died() -> void:
	if UpgradeManager.consume_revive():  # ممتاز: انبعاث مرة واحدة في الموجة
		var rh := get_node_or_null("Health") as HealthComponent
		if rh != null:
			rh.health = 30.0
			rh.shield = maxf(rh.shield, 10.0)
		var rv := get_node_or_null("UpgradeVisuals")
		if rv != null and rv.has_method("play_revive"):
			rv.play_revive()  # وميض أزرق قوي يُظهر لحظة الانبعاث
		_play_anim(ANIM_IDLE)
		return
	_set_reticle(null)  # إخفاء لوحة التصويب مع موت اللاعب
	_play_anim(ANIM_DEATH)  # وضعية الموت قبل إيقاف الحركة
	GM.set_state(GM.State.GAME_OVER)
	SaveSystem.add_stat("deaths", 1.0)
	SaveSystem.save()


func _on_health_damaged(_amount: float, _new_health: float) -> void:
	MissionSystem.on_player_damaged()  # مهمة "موجة بدون ضرر"
	# اهتزاز خفيف للكاميرا عند تلقّي الضرر
	var cam := get_node_or_null(camera_path) as Node
	if cam != null and cam.has_method("shake"):
		cam.call("shake", 0.15, 0.18)


func _physics_process(delta: float) -> void:
	if GM.is_game_over():
		return
	StatsTracker.tick(delta)
	_ensure_joy_signal()
	_update_dash_timers(delta)

	var input := _move_input()
	# Yaw-only basis from the camera so input maps to the screen axes
	var basis_yaw := Basis.IDENTITY
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		basis_yaw = Basis(Vector3.UP, cam.global_rotation.y)
	var dir := (basis_yaw * Vector3(input.x, 0.0, input.y))
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var moving := dir.length_squared() > 0.01
	if moving:
		last_direction = dir.normalized()

	# قفزة من النقرة المزدوجة على الجوي: نحو آخر اتجاه للعصا (تحويل بنفس أساس الكاميرا)
	if _pending_dash != Vector2.ZERO:
		if _dash_time <= 0.0 and _dash_cd <= 0.0:
			var dd := basis_yaw * Vector3(_pending_dash.x, 0.0, _pending_dash.y)
			dd.y = 0.0
			if dd.length_squared() > 0.001:
				_dash_dir = dd.normalized()
				_dash_time = DASH_TIME
				_dash_cd = DASH_CD * UpgradeManager.get_dash_cd_mult()  # DashCd: -20% لكل مستوى
				if UpgradeManager.has("dash_shield"):
					var dh := get_node_or_null("Health") as HealthComponent
					if dh != null:
						# درع القفزة (نادر): +10 درع لكل مستوى مع سقف 40 لمنع التكديس
						dh.shield = minf(40.0, dh.shield + 10.0 * UpgradeManager.count_of("dash_shield"))
				last_direction = _dash_dir  # الوجه يتجه مع القفزة
		_pending_dash = Vector2.ZERO

	var eff_speed := SPEED * _weapon_move_mult() * SaveSystem.get_speed_mult() * UpgradeManager.get_move_speed_mult()
	if _dash_time > 0.0:
		velocity.x = _dash_dir.x * DASH_SPEED
		velocity.z = _dash_dir.z * DASH_SPEED
	else:
		velocity.x = dir.x * eff_speed
		velocity.z = dir.z * eff_speed

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	move_and_slide()

	_update_model(delta, moving or _dash_time > 0.0)
	_try_auto_fire()
	_auto_heal(delta)

	# تبديل السلاح
	if Input.is_action_just_pressed("switch_weapon"):
		var wm2 := get_node_or_null("WeaponManager")
		if wm2 != null and wm2.has_method("switch_next"):
			wm2.call("switch_next")


## اكتشاف الجوي وربط النقرة المزدوجة (يُستدعى كل إطار — الجوي قد يظهر لاحقاً بعد اللاعب)
func _ensure_joy_signal() -> void:
	if _joy_ui != null and is_instance_valid(_joy_ui):
		return
	_joy_ui = get_tree().get_first_node_in_group("virtual_joystick")
	if _joy_ui != null and _joy_ui.has_signal("double_tap") \
			and not _joy_ui.is_connected("double_tap", _on_double_tap):
		_joy_ui.connect("double_tap", _on_double_tap)


## النقرة المزدوجة على الجوي → قفزة نحو آخر اتجاه للعصا
func _on_double_tap(last_v: Vector2) -> void:
	if _dash_time > 0.0 or _dash_cd > 0.0:
		return  # قفزة جارية أو ضمن المنع
	_pending_dash = last_v


func _update_dash_timers(delta: float) -> void:
	if _dash_time > 0.0:
		_dash_time = maxf(0.0, _dash_time - delta)
	if _dash_cd > 0.0:
		_dash_cd = maxf(0.0, _dash_cd - delta)


## دخل الحركة: كيبورد/جوي فيزيائي (InputMap) + عصا اللمس — الأطول طولاً يفوز
## (ضغط الكيبورد كاملاً يتفوّق على عصا اللمس half-deflection = أولوية كيبورد)
func _move_input() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _joy_ui == null or not is_instance_valid(_joy_ui):
		_joy_ui = get_tree().get_first_node_in_group("virtual_joystick")
	if _joy_ui != null and _joy_ui.has_method("get_move_vector"):
		var jv: Vector2 = _joy_ui.call("get_move_vector")
		if jv.length_squared() > v.length_squared():
			v = jv
	return v


## تحديث النموذج كل إطار: الوجه نحو اتجاه الرمي إن وُجد وإلا نحو الحركة (ناعم) + تبديل الوضعية
func _update_model(delta: float, moving: bool) -> void:
	if _model != null:
		var face: Vector3 = _aim_dir if _aim_dir != Vector3.ZERO else last_direction
		var target := atan2(face.x, face.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target, minf(1.0, TURN_SPEED * delta))
		# قفزة بصرية خفيفة أثناء الانزلاق (قوس جيبي 0.5م)
		var hop := 0.0
		if _dash_time > 0.0:
			var t := 1.0 - _dash_time / DASH_TIME
			hop = sin(t * PI) * 0.5
		_model.position.y = _model_base_y + hop
	_play_anim(ANIM_RUN if moving else ANIM_IDLE)


## تشغيل وضعية إن وُجدت ولم تكن هي الحالية
func _play_anim(anim_name: String) -> void:
	if _anim == null or anim_name == _current_anim:
		return
	if not _anim.has_animation(anim_name):
		return
	_anim.play(anim_name)
	_current_anim = anim_name


## الإطلاق التلقائي: يصوّب ويطلق فقط داخل حدود السلاح الحالي (دائرة المدى) — خارجها: لا التفات ولا إطلاق
## ذكاء: ترجيح من يقترب/صحته منخفضة + ثبات الهدف + اعتراض سرعة الزومبي (AIM_LEAD)
func _try_auto_fire() -> void:
	var wm := get_node_or_null("WeaponManager")
	if wm == null or not wm.has_method("try_fire"):
		return
	_lock_timer = maxf(0.0, _lock_timer - get_process_delta_time())
	var target := _pick_target(wm)
	if target == null:
		_aim_dir = Vector3.ZERO  # لا عدو = لا وجه نحو الرمي → الوجه يعود نحو الحركة
		_set_reticle(null)
		return
	var aim_pt := _predict_aim_point(target, wm)
	var to: Vector3 = aim_pt - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		to = last_direction
	# المدى يُقاس على موضع الهدف الحالي (الاعتراض لا يوسّع مدى السلاح)
	var dist_now: float = global_position.distance_to(target.global_position)
	if dist_now > _weapon_range(wm):
		_aim_dir = Vector3.ZERO
		_set_reticle(null)
		return
	_set_reticle(target)
	_locked_target = target
	_lock_timer = TARGET_STICKY
	_aim_dir = to.normalized()
	wm.call("try_fire", _aim_dir)


## نقطة التصويب: موضع الزومبي + جزء من سرعته × زمن وصول الرصاصة (اعتراض خفيف)
func _predict_aim_point(target: Node3D, wm: Node) -> Vector3:
	var p := target.global_position
	if target is CharacterBody3D:
		var zv: Vector3 = (target as CharacterBody3D).velocity
		zv.y = 0.0
		if zv.length_squared() > 0.04:
			var bspeed := _weapon_bullet_speed(wm)
			var t := global_position.distance_to(p) / maxf(8.0, bspeed)
			p += zv * AIM_LEAD * t
	return p


## سرعة الرصاصة الحالية (لحساب زمن الاعتراض) — افتراضي 30 إن تعذّرت القراءة
func _weapon_bullet_speed(wm: Node) -> float:
	var w: Node = wm.call("get_current")
	if w == null:
		return 30.0
	var wd: Variant = w.get("weapon_data")
	if wd == null:
		return 30.0
	var s: Variant = wd.get("bullet_speed")
	if s == null:
		return 30.0
	return float(s)


## اختيار الهدف: درجة = قرب × تهديد × إنهاء قتل × ثبات — أفضل درجة تفوز
func _pick_target(wm: Node) -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var wrange := _weapon_range(wm)
	if wrange <= 0.0:
		return null
	var best: Node3D = null
	var best_score: float = 0.0
	var keep_locked: bool = _lock_timer > 0.0 and _locked_target != null \
		and is_instance_valid(_locked_target) and _locked_target.visible \
		and not (_locked_target.has_method("is_dead") and _locked_target.is_dead())
	for e in tree.get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n == null or not is_instance_valid(n):
			continue
		if n.visible == false:
			continue  # ميت/مدررج (hide عند الموت)
		if n.has_method("is_dead") and n.is_dead():
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d > wrange:
			continue
		var score := 1.0 / maxf(d, 0.5)
		# من يقترب بسرعة = تهديد فوري (لوحاق/هجوم)
		if n is CharacterBody3D:
			var zv: Vector3 = (n as CharacterBody3D).velocity
			zv.y = 0.0
			var toward := global_position - n.global_position
			toward.y = 0.0
			if toward.length_squared() > 0.01 and zv.dot(toward.normalized()) > 1.5:
				score *= THREAT_MULT
		# صحة منخفضة = أنهِ القتل
		var hp_node: Node = n.get_node_or_null("Health")
		if hp_node != null:
			var hpv: Variant = hp_node.get("health")
			var mhv: Variant = hp_node.get("max_health")
			if hpv != null and mhv != null and float(mhv) > 0.0:
				if float(hpv) / float(mhv) < 0.35:
					score *= FINISH_MULT
		if keep_locked and n == _locked_target:
			score *= STICKY_MULT
		if score > best_score:
			best_score = score
			best = n
	if best == null:
		_locked_target = null
	return best


## تحديث لوحة التصويب: هدف → تتبّع قدميه، null → إخفاء (حارس إن لم تُنشأ اللوحة)
func _set_reticle(target: Node3D) -> void:
	if _reticle == null or not is_instance_valid(_reticle):
		return
	if target == null:
		_reticle.clear()
	else:
		_reticle.track(target)


## مدى السلاح الحالي = نصف قطر دائرة المدى الفعلية — إن تعذّرت القراءة يعود 0 (بلا إطلاق)
func _weapon_range(wm: Node) -> float:
	var w: Node = wm.call("get_current")
	if w == null:
		return 0.0
	var wd: Variant = w.get("weapon_data")
	if wd == null:
		return 0.0
	var r: Variant = wd.get("max_range")
	if r == null:
		return 0.0
	return float(r)


## شفاء تلقائي (ترقية auto_heal): 2ر.د م لكل مستوى — يتراكم حتى 1 صحة كل ثانية تقريباً
func _auto_heal(delta: float) -> void:
	var rate: float = UpgradeManager.get_auto_heal_rate()
	if rate <= 0.0:
		_heal_acc = 0.0
		return
	_heal_acc += rate * delta
	if _heal_acc >= 1.0:
		_heal_acc -= 1.0
		var h := get_node_or_null("Health") as HealthComponent
		if h != null and h.health < h.max_health:
			h.heal(1.0)


## استدعاء من انفجارات الزومبي على اللاعب مباشرة (death_explosion / exploder)
func take_damage(amount: float) -> void:
	var h := get_node_or_null("Health") as HealthComponent
	if h != null:
		h.take_damage(amount)


## مضاعف سرعة السلاح الحالي (HeavyMG يُبطئ الحركة)
func _weapon_move_mult() -> float:
	var wm := get_node_or_null("WeaponManager")
	if wm != null and wm.has_method("get_move_mult"):
		return float(wm.call("get_move_mult"))
	return 1.0


## إضافة ذهب للاعب (تستدعيها الزومبي عند الموت)
func add_gold(amount: int) -> void:
	var boosted := int(round(float(amount) * UpgradeManager.get_gold_mult()))  # GoldGain: +25%
	gold += boosted
	GM.run_gold += boosted
	SaveSystem.earn_gold(boosted)
	MissionSystem.record_gold(boosted)  # مهمة "اجمع 1000 ذهب"
	gold_changed.emit(gold)
