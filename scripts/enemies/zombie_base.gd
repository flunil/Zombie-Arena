extends CharacterBody3D
## زومبي أساسي: يتتبّع اللاعب دائمًا (بعيدًا كان أو قريبًا) وعند 1.5 وحدة يضرب كل ثانية

signal gold_dropped(amount: int)
signal died  # تُبث عند موت الزومبي — يستعملها WaveManager لإرجاعه للـ Pool

const ATTACK_RANGE: float = 1.5
const ATTACK_INTERVAL: float = 1.0
const ATTACK_WINDUP: float = 0.12  # تنفّس الكمة: الضرر بعد هذا — يعطي إحساس الضرب
const ATTACK_MISS_MULT: float = 1.35  # إن ابتعد اللاعب أثناء التنفّس ← كمة خاسرة
const LEAD_TIME: float = 0.38  # ثانية اعتراض: يستهدف موقع اللاعب المستقبلي
const ORBIT_SPREAD: float = 0.85  # انحراف الفتحة المدارية (يحيط بدل التكدّس)
const CATCH_RANGE: float = 4.2  # أقرب من هذا ← مطاردة متسارعة (لحاق)
const CATCH_MULT: float = 1.28
const GOLD_DROP: int = 10
const DEATH_EXPLOSION_RADIUS: float = 2.0
const DEATH_EXPLOSION_DAMAGE: float = 30.0
const BAR_WIDTH: float = 1.1
const BAR_HEIGHT: float = 0.14
const BAR_Y: float = 1.05  # فوق الرأس مباشرة (رأس النموذج ≈0.62 فوق الأصل)
const LOD_DIST: float = 30.0  # LOD يدوي: أبعد من هذا تُطفأ الظلال ويختفي الشريط
const LOD_INTERVAL: float = 0.5  # معدل فحص المسافة (أرخص من كل إطار)
const BATCH_ENTER: float = 30.0  # أبعد من اللاعب بهذا ← يُجمَّع في MultiMesh (يغطي مدى رؤية الكاميرا ~30م كاملًا)
const BATCH_EXIT: float = 28.0   # أقرب من هذا ← يعود مفردًا متحركًا (hysteresis 2م يمنع التردد)

## حراسة الخريطة: حدود مدينة موسّعة + مهلة التعثّر (زومبي طُيّر للفراغ أو تعثّر مجمّدًا بعيدًا)
const BOUND_X_MIN: float = -80.0
const BOUND_X_MAX: float = 120.0
const BOUND_Z_MIN: float = -160.0
const BOUND_Z_MAX: float = 120.0
const BOUND_Y_MIN: float = -20.0
const STUCK_SECONDS: int = 3      # ثوانٍ بلا حركة تقريبًا ← إعادة نشر قرب اللاعب
const STUCK_MIN_MOVE: float = 0.3  # أقل من هذا خلال فحص الدورية (ثانية) ← متعثّر

## أنيميشن النموذج (FBX Zombie Apocalypse Kit) — الأنواع بلا نموذج تبقى بلا أنيميشن
const ANIM_PREFIX := "CharacterArmature|"
const ANIM_IDLE: String = ANIM_PREFIX + "Idle"
const ANIM_WALK: String = ANIM_PREFIX + "Walk"
const ANIM_PUNCH: String = ANIM_PREFIX + "Punch"
const ANIM_HIT: String = ANIM_PREFIX + "HitReact"

@export var speed: float = 4.16  # 4.62 × 0.90 (إنقاص Basic 10%) = 4.158 ≈ 4.16
@export var max_health: float = 130.0  # 100 × 1.30
@export var attack_damage: float = 10.0

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var health: HealthComponent = $Health

var _player: Node3D = null
var _attack_timer: float = 0.0
var _dead: bool = false
var _nav_ok: bool = false
var _nav_check: float = 0.0
var _repath_timer: float = 0.0  # تحديث هدف المسار كل ربع ثانية مشتّتًا (بدل كل إطار)
var _slow_mult: float = 1.0  # مبطّئ مؤقت (Freeze / TimeSlow)
var _slow_timer: float = 0.0
var _bar_fill: MeshInstance3D = null  # تعبئة شريط الصحة فوق الرأس
var _flash_mats: Array[Material] = []  # مواد الجسم (مُنسوخة لكل نسخة — خلوية أو أساسية)
var _flash_orig: Array[Color] = []            # ألوانها الأصلية
var _flash_tw: Tween = null
var _lod_timer: float = 0.0
var _lod_far: bool = false
var _batched: bool = false  # مُجمَّع في دفعة MultiMesh (بعيد عن اللاعب)
var _outline_stash: Dictionary = {}  # مادة ← outline محفوظ (يُلغى لمن بعيد جدًا)
var _visual: Node3D = null          # جذر النموذج (FBX) إن وُجد
var _anim: AnimationPlayer = null   # مشغّل الأنيميشن داخل النموذج
var _current_anim: String = ""      # المقطع الشغّال الآن
var _action_until: int = 0          # ticks msec يُمنع فيه تبديل المقطع (لكمة/استجابة)
var _stuck_time: int = 0            # فحوصات دورية متتالية بلا حركة (حراسة التعثّر)
var _last_guard_pos: Vector2 = Vector2.ZERO  # آخر موضع مسطّح سُجّل في الدورية
var _orbit_angle: float = 0.0  # زاوية الفتحة حول اللاعب (يحيط بدل التكدّس)
var _atk_pending: bool = false  # كمة طلبت ضررها بعد التنفّس (يُلغى لو ابتعد اللاعب)
var _dust_timer: float = 0.0  # مؤقت غبار الحركة (رذاذ ترابي عند الأقدام)


func _ready() -> void:
	_gather_flash_mats()  # قبل بناء شريط الصحة (يُستثنى منه)
	add_to_group("enemies")
	collision_mask = 7  # 1+2+4: عالم + زومبي (يمنع التداخل فيما بينهم) + لاعب
	health.max_health = max_health
	health.reset_health()
	health.died.connect(_on_died)
	_player = get_tree().get_first_node_in_group("player") as Node3D
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = ATTACK_RANGE * 0.8
	_repath_timer = randf() * 0.25  # تشتيت حتى لا تتحدّث كل الزومبي في نفس الإطار
	_orbit_angle = randf() * TAU  # فتحة مدارية عشوائية: يحيطون باللاعب بدل التكدّس أمامه
	_build_health_bar()
	_setup_model_anim()


func _physics_process(delta: float) -> void:
	if _dead:
		return

	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_timer = 0.0
			_slow_mult = 1.0

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			velocity = Vector3.ZERO
			return

	_nav_check -= delta
	if _nav_check <= 0.0:
		_nav_check = 1.0
		var regions: Array = NavigationServer3D.map_get_regions(get_world_3d().navigation_map)
		_nav_ok = regions.size() > 0
		_guard_map()  # دورية كل ثانية: خارج الحدود / تعثّر ← إرجاع فوري أو إعادة نشر

	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()

	if distance <= ATTACK_RANGE:
		# كمّة بتنفّس قصير: الضرر بعد ATTACK_WINDUP — لو ابتعد اللاعب أثناء التنفّس تفشل
		velocity = Vector3.ZERO
		_attack_timer -= delta
		if _attack_timer <= 0.0 and not _atk_pending:
			_attack_timer = ATTACK_INTERVAL
			_atk_pending = true
			_play_action(ANIM_PUNCH)
			get_tree().create_timer(ATTACK_WINDUP).timeout.connect(_land_attack, CONNECT_ONE_SHOT)
	else:
		_atk_pending = false  # خخرج من المدى أثناء التنفّس ← كمة خاسرة
		_attack_timer = maxf(_attack_timer, 0.0)
		var chase_speed := speed * (CATCH_MULT if distance <= CATCH_RANGE else 1.0)
		_chase(to_player, chase_speed)
		# غبار حركة: رذاذ ترابي خفيف عند الأقدام أثناء المشي
		_dust_timer -= delta
		if _dust_timer <= 0.0 and velocity.length() > 1.0:
			_dust_timer = 0.35
			if visible and not _batched and not _lod_far:
				FxLibrary.spawn_move_dust(global_position)  # غبار فقط لمن يراه اللاعب فعلًا

	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= 9.8 * delta

	move_and_slide()
	_update_anim(delta)  # أنيميشن + اتجاه النموذج (لا-op بلا نموذج)


## LOD يدوي للهاتف: كل نصف ثانية — فحص التجميع (مسافة اللاعب) ثم فحص الكاميرا للظلال/الشريط
func _process(delta: float) -> void:
	if _dead or not visible:
		return
	_lod_timer -= delta
	if _lod_timer > 0.0:
		return
	_lod_timer = LOD_INTERVAL
	_update_batch_state()  # أولاً: تجميع/إفراد حسب اللاعب (يعمل بلا كاميرا للاختبارات)
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var far: bool = global_position.distance_to(cam.global_position) > LOD_DIST
	if far == _lod_far:
		return
	_lod_far = far
	_set_lod_far(far)


## قرار التجميع: أبعد من 30م عن اللاعب ← دفعة MultiMesh، وأقرب من 28م ← مفرد متحرك
func _update_batch_state() -> void:
	var mgr := ZombieBatchManager.instance
	if mgr == null or _player == null or not is_instance_valid(_player):
		if _batched:
			_set_batched(false)
		return
	var d: float = global_position.distance_to(_player.global_position)
	if _batched:
		if d < BATCH_EXIT:
			_set_batched(false)
	elif d > BATCH_ENTER:
		_set_batched(true)


## إظهار/إخفاء النموذج عند التجميع: البعيد = تحويل في الدفعة، القريب = مفرد كامل الميزات
func _set_batched(b: bool) -> void:
	if b == _batched:
		return
	var mgr := ZombieBatchManager.instance
	if b:
		if mgr == null or not mgr.acquire(self):
			return  # لا شبكة للنوع ← يبقى مفردًا (لا إعادة محاولة مؤلمة)
		_batched = true
		_set_visual_hidden(true)
		if _anim != null:
			_anim.pause()  # بلا رسم بلا تكلفة أنيميشن
	else:
		_batched = false
		if mgr != null:
			mgr.release(self)
		_set_visual_hidden(false)
		_current_anim = ""  # إعادة بناء المقطع الصحيح عند الإظهار
		if _anim != null:
			_anim.pause()  # يبقى موقوفًا حتى يعيد _update_anim المقطع المناسب


func _set_visual_hidden(h: bool) -> void:
	if _visual != null:
		_visual.visible = not h
		return
	var body := get_node_or_null("BodyMesh") as MeshInstance3D
	if body != null:
		body.visible = not h


func _set_lod_far(far: bool) -> void:
	var body := get_node_or_null("BodyMesh") as MeshInstance3D
	if body != null:
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if far \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if _visual != null:  # ظلال مجسم النموذج (FBX) أيضًا
		for n in _visual.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi != null:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if far \
					else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var bar := get_node_or_null("HealthBar")
	if bar != null:
		bar.visible = not far
	# تمرير outline يكلف draw pass لكل جزء — يُلغى لمن بعيد جدًا (صغير على الشاشة)
	_set_outline(not far)


func _set_outline(on: bool) -> void:
	var meshes: Array = []
	var body := get_node_or_null("BodyMesh") as MeshInstance3D
	if body != null:
		meshes.append(body)
	if _visual != null:
		for n in _visual.find_children("*", "MeshInstance3D", true, false):
			meshes.append(n)
	for n in meshes:
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var m := mi.material_override
		if m == null:
			m = mi.get_active_material(0)
		if not (m is ShaderMaterial):
			continue
		var sm := m as ShaderMaterial
		if on:
			if _outline_stash.has(sm):
				sm.next_pass = _outline_stash[sm]
		elif sm.next_pass != null:
			_outline_stash[sm] = sm.next_pass
			sm.next_pass = null


## شريط صحة فوق الرأس: خلفية داكنة + تعبئة مصوّبة للكاميرا (billboard)
func _build_health_bar() -> void:
	var bar := Node3D.new()
	bar.name = "HealthBar"
	bar.position = Vector3(0, BAR_Y, 0)
	# كلا الطبقتين يكتبان في مخزن العمق: تمنع الدائرة (next-pass للأرض) من رسمها فوق الشريط
	bar.add_child(_make_bar_quad(Color(0.07, 0.07, 0.07, 0.85), true))
	_bar_fill = _make_bar_quad(Color(0.25, 0.9, 0.35, 1.0), true)
	_bar_fill.position.z = 0.005  # إزاحة ملّيمتر نحو الكاميرا: تفصل التعبئة عن الخلفية في العمق
	bar.add_child(_bar_fill)
	add_child(bar)
	_update_health_bar()


func _make_bar_quad(color: Color, depth_write: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := QuadMesh.new()  # في مخطط XY (يناسب billboard) — لا PlaneMesh (أفقي XZ)
	mesh.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if depth_write:
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS  # يحجب دائرة next-pass عن الشريط
	mat.albedo_color = color
	mi.material_override = mat
	return mi


## تحديث التعبئة: العرض = نسبة الصحة، واللون أخضر→أحمر مع النقصان
func _update_health_bar() -> void:
	if _bar_fill == null:
		return
	var pct := clampf(health.get_percent(), 0.0, 1.0)
	_bar_fill.scale = Vector3(maxf(pct, 0.001), 1.0, 1.0)  # تقلّص من المركز (موثوق مع billboard)
	var mat := _bar_fill.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = Color(0.9, 0.25, 0.2).lerp(Color(0.25, 0.9, 0.35), pct)


## التتبّع الذكي: اعتراض مسار اللاعب (LEAD_TIME) + فتحة مدارية (يحيطون بدل التكدّس)
func _chase(to_player: Vector3, move_speed: float) -> void:
	var target := _player.global_position
	# اعتراض: يستهدف موضع اللاعب المستقبلي لو كان يتحرك بسرعة تجاه/بعيد عن الزومبي
	var lead := Vector3.ZERO
	if _player is CharacterBody3D:
		lead = (_player as CharacterBody3D).velocity
		lead.y = 0.0
		lead *= LEAD_TIME
	var dist := to_player.length()
	# فتحة مدارية: كل زومبي يقترب من زاويته — تخفيف التكدّس وتغطية اللاعب من كل الجهات
	# قرب المدى القتالي تُلغى الفتحة (يريد اللاعب مباشرة)
	var orbit := Vector3.ZERO
	if dist > ATTACK_RANGE * 1.15:
		orbit = Vector3(cos(_orbit_angle), 0.0, sin(_orbit_angle)) * ORBIT_SPREAD
		# أبعد = فتحة أوسع (يقتربون تدريجيًا من المدى)
		orbit *= clampf(dist * 0.25, 0.6, 2.4)
	var aim: Vector3 = target + lead + orbit
	aim.y = global_position.y
	var dir: Vector3
	if _nav_ok:
		_repath_timer -= get_process_delta_time()
		if _repath_timer <= 0.0:
			# قريب = مسار أسرع تكرارًا (≈1Hz بعيد / 4.5Hz لحاق) — تقليل حِمل NavigationServer
			_repath_timer = 0.22 if dist < CATCH_RANGE else 0.9
			agent.target_position = aim
		var next: Vector3 = agent.get_next_path_position()
		dir = next - global_position
		dir.y = 0.0
		if dir.length_squared() < 0.01:
			dir = aim - global_position
			dir.y = 0.0
	else:
		dir = aim - global_position
		dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * move_speed * _slow_mult
	velocity.z = dir.z * move_speed * _slow_mult


## إنزال الكمة: الضرر فقط إن كان اللاعب لا يزال ضمن مدى ضرب أوسع قليلًا
func _land_attack() -> void:
	if _dead or not _atk_pending:
		return
	_atk_pending = false
	if _player == null or not is_instance_valid(_player):
		return
	var d := global_position.distance_to(_player.global_position)
	if d > ATTACK_RANGE * ATTACK_MISS_MULT:
		return  # ابتعد اللاعب أثناء التنفّس — كمة خاسرة
	_attack_player()


## إنزال الضرر — أنيميشن الكمة يُشغَّل مسبقًا عند بداية التنفّس
func _attack_player() -> void:
	var target: Node = _player.get_node_or_null("Health")
	if target != null and target.has_method("take_damage"):
		target.take_damage(attack_damage)
		var thorns := UpgradeManager.get_thorns_damage(attack_damage)
		if thorns > 0.0 and not _dead:
			take_damage(thorns)  # ترقية Thorns (نادر): ردّ 30% من ضرر الكمة


## تبطئ مؤقت (Freeze / TimeSlow)
func apply_slow(mult: float, duration: float) -> void:
	_slow_mult = mult
	_slow_timer = maxf(_slow_timer, duration)


## استدعاء من الأسلحة (الرصاصة يبحث عن take_damage) — الاتجاه لتمييز الدرع الأمامي
func take_damage(amount: float, _from_direction: Vector3 = Vector3.ZERO) -> void:
	if _dead:
		return
	var hp0: float = health.health
	if UpgradeManager.roll_execution() and health.max_health > 0.0 and health.health / health.max_health < 0.25:
		amount = health.health  # ترقية Execution (نادر): قتل فوري لهدف تحت 25%
	health.take_damage(amount)
	var dealt: float = hp0 - health.health  # الضرر الفعلي على الصحة (يبقى 0 لو صدّ الدرع)
	_update_health_bar()
	if dealt > 0.0:
		FxLibrary.spawn_damage_number(global_position + Vector3.UP * 1.35, dealt)
		if not health.is_dead():  # الضربة القاتلة لا تُلغِ مقطع Death (تُستدعى الإشارة هنا)
			_play_action(ANIM_HIT)  # استجابة للاصابة (إن وُجد النموذج)
	if not health.is_dead():
		_flash_hit()


## نسخ مواد الجسم (عزل عن المواد المشتركة بين نسخ الـ Pool) + حفظ ألوانها
func _gather_flash_mats() -> void:
	_flash_mats.clear()
	_flash_orig.clear()
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var src: BaseMaterial3D = null
		if mi.material_override is BaseMaterial3D:
			src = mi.material_override as BaseMaterial3D
		elif mi.get_active_material(0) is BaseMaterial3D:
			src = mi.get_active_material(0) as BaseMaterial3D
		if src == null:
			continue
		var dup := src.duplicate() as BaseMaterial3D
		var out: Material = dup
		if CelMaterial.convertible(dup):
			out = CelMaterial.from_base(dup)  # تحويل خلوٍّ مع حواف outline
		mi.material_override = out
		_flash_mats.append(out)
		_flash_orig.append(CelMaterial.color_of(out))


## وميض أحمر سريع عند الإصابة — 0.1 ثانية (ألوان مواد الجسم لأن Node3D بلا modulate)
func _flash_hit() -> void:
	if _flash_mats.is_empty():
		return
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	for i in _flash_mats.size():
		CelMaterial.set_color(_flash_mats[i], Color(1.0, 0.15, 0.15, _flash_orig[i].a))
	_flash_tw = create_tween()
	_flash_tw.set_parallel(true)
	for i in _flash_mats.size():
		var m := _flash_mats[i]
		var orig := _flash_orig[i]
		_flash_tw.tween_method(
			func(v: Color) -> void: CelMaterial.set_color(m, v),
			Color(1.0, 0.15, 0.15, orig.a), orig, 0.1)


func _on_died() -> void:
	_dead = true
	if _batched:
		_set_batched(false)  # يعود مفردًا ليعود للـPool في حالته الصحيحة (يختفي فورًا)
	StatsTracker.record_kill()
	MissionSystem.record_kill(str(get_meta("pool_type", "")))  # مهام اليوم (boss للزعيم)
	FxLibrary.spawn_death_burst(global_position)  # انفجار SmokeExplosion + رذاذ أحمر/أصفر
	FxLibrary.hit_stop(0.06)  # تجميد لحظي عند الضربة القاتلة
	FxLibrary.shake_camera(0.1, 0.18)  # اهتزاز خفيف مع كل قتيل
	AudioManager.play_sfx("zombie_death", -3.0, 0.09)  # موت كوميدي
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1
	gold_dropped.emit(GOLD_DROP)
	if _player != null and is_instance_valid(_player):
		_player.call("add_gold", GOLD_DROP)  # 10 ذهب للموت
		var steal := UpgradeManager.get_lifesteal_heal()
		if steal > 0.0:  # ترقية Lifesteal (نادر): علاج اللاعب عند كل قتل
			var ph := _player.get("health") as HealthComponent
			if ph != null:
				ph.heal(steal)
	if UpgradeManager.has_death_explosion() and not _has_own_explosion():
		_death_area_explode()
	# بلا أنيميشن موت ولا جثة: الزومبي يختفي فورًا والانفجار يكفي
	died.emit()  # أولاً يستقبلها WaveManager
	hide()


## انفجار المتفجر الخاص به (يمنع تراكب انفجار الموت فوقه)
func _has_own_explosion() -> bool:
	return false


## انفجار موت (ترقية DeathExplosion): 30 ضرر على 2م + أثر بصري ExplosionVFX
func _death_area_explode() -> void:
	var radius := DEATH_EXPLOSION_RADIUS + UpgradeManager.get_blast_bonus()  # ExplosiveMastery: +1م
	FxLibrary.spawn_explosion(global_position, radius)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 2 + 4  # أعداء + لاعب
	query.collide_with_bodies = true
	var results: Array[Dictionary] = space.intersect_shape(query, 32)
	for r in results:
		var b: Node = r.get("collider")
		if b == null or b == self:
			continue
		if b.has_method("take_damage"):
			b.take_damage(DEATH_EXPLOSION_DAMAGE)
		else:
			var h: Node = b.get_node_or_null("Health")
			if h != null and h.has_method("take_damage"):
				h.take_damage(DEATH_EXPLOSION_DAMAGE)


## دورية كل ثانية: خارج خريطة المدينة ← إرجاع للمخزن؛ متعثّر مجمّدًا بعيدًا عن اللاعب ← إعادة نشر قربه
## (.move_and_slide مع trimesh المباني قد يطرد الزومبي للفراغ أو يدسّه في زاوية — الحارس يشفي الحالة)
func _guard_map() -> void:
	if _dead:
		return
	var p := global_position
	if p.x < BOUND_X_MIN or p.x > BOUND_X_MAX or p.z < BOUND_Z_MIN or p.z > BOUND_Z_MAX or p.y < BOUND_Y_MIN:
		_evacuate_to_pool()
		return
	if _player == null or not is_instance_valid(_player):
		return
	var dist := p.distance_to(_player.global_position)
	var flat_move := Vector2(p.x - _last_guard_pos.x, p.z - _last_guard_pos.y).length()
	_last_guard_pos = Vector2(p.x, p.z)
	if dist <= ATTACK_RANGE * 2.0 or flat_move > STUCK_MIN_MOVE:
		_stuck_time = 0
		return
	_stuck_time += 1
	if _stuck_time < STUCK_SECONDS:
		return
	_stuck_time = 0
	var map: RID = get_world_3d().navigation_map
	var off := Vector3(randf_range(-10.0, 10.0), 0.0, randf_range(-10.0, 10.0))
	var dest := NavigationServer3D.map_get_closest_point(map, _player.global_position + off)
	if dest == Vector3.ZERO:
		dest = _player.global_position + off
	dest.y += 0.9
	global_position = dest
	velocity = Vector3.ZERO


## إرجاع فوري للمخزن بلا ذهب/مؤثرات (طوارئ الخريطة فقط)
func _evacuate_to_pool() -> void:
	_dead = true
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	died.emit()
	hide()


## إعادة التفعيل (تُستدعى من الـ Pool في المرحلة 4)
func revive(spawn_pos: Vector3) -> void:
	global_position = spawn_pos
	collision_layer = 2
	collision_mask = 7  # عالم + زومبي (منع التداخل) + لاعب
	if _batched:  # دفاعي: العودة للـPool يجب أن تكون مفردًا
		_set_batched(false)
	health.reset_health()
	_dead = false
	_attack_timer = 0.0
	_atk_pending = false
	_orbit_angle = randf() * TAU  # فتحة جديدة عند كل إحياء
	_slow_mult = 1.0
	_slow_timer = 0.0
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_stuck_time = 0
	_last_guard_pos = Vector2(spawn_pos.x, spawn_pos.z)
	show()
	set_process(true)  # التخزين يوقف process أيضًا — إعادته عند الإحياء
	set_physics_process(true)
	_current_anim = ""  # حالة الأنيميشن للصفر (revive جديد)
	_action_until = 0
	if _anim != null:
		_play_anim(ANIM_IDLE)
	_lod_far = false  # إعادة تفعيل LOD كاملة (يُصحَّح تلقائيًا في أول فحص)
	_set_lod_far(false)
	_update_health_bar()


## اكتشاف النموذج المرئي ومشغّل الأنيميشن (FBX) — إن لم يوجد يبقى بلا أنيميشن
func _setup_model_anim() -> void:
	for c in get_children():
		if not (c is Node3D):
			continue
		var aps: Array = (c as Node3D).find_children("*", "AnimationPlayer", true, false)
		if aps.is_empty():
			continue
		_visual = c as Node3D
		_anim = aps[0] as AnimationPlayer
		break
	if _anim == null:
		return
	# المقطعان اللذان يجب أن يتكررا (FBX يصلّرها LOOP_NONE عند الاستيراد)
	for n in [ANIM_IDLE, ANIM_WALK]:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_play_anim(ANIM_IDLE)


## كل إطار: اتجاه النموذج (نحو الحركة وإلا نحو اللاعب) + مقطع المشي/الوقوف
func _update_anim(delta: float) -> void:
	# الاتجاه دائمًا — حتى وهو مُجمَّع: نسخة الدفعة تُكتب من global_transform
	var d := Vector3(velocity.x, 0.0, velocity.z)
	if d.length_squared() < 0.09 and _player != null and is_instance_valid(_player):
		d = _player.global_position - global_position
		d.y = 0.0
	if d.length_squared() > 0.0001:
		var target_yaw: float = atan2(d.x, d.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 8.0, 1.0))
	if _anim == null or _batched:
		return
	_anim.speed_scale = maxf(_slow_mult, 0.05)  # تزامن مع التبريد/التباطؤ
	# قفل المقطع الإجرائي (لكمة/استجابة) — لا يُقاطع
	if _action_until > Time.get_ticks_msec():
		return
	var want: String = ANIM_WALK \
		if Vector2(velocity.x, velocity.z).length() > 0.3 else ANIM_IDLE
	_play_anim(want)


## تشغيل مقطع إن تغيّر — no-op بلا مشغّل أو بلا المقطع
func _play_anim(anim_name: String) -> void:
	if _anim == null or _current_anim == anim_name:
		return
	if not _anim.has_animation(anim_name):
		return
	_anim.play(anim_name)
	_current_anim = anim_name


## مقطع إجرائي قصير (لكمة/استجابة): يشغّل ويقفل التبديل طوال طوله
func _play_action(anim_name: String) -> void:
	if _batched:  # مُجمَّع بلا رسم: بلا أنيميشن ولا قفل إجراء
		return
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _action_until > Time.get_ticks_msec():
		return
	_anim.play(anim_name)
	_current_anim = anim_name
	_action_until = Time.get_ticks_msec() + int(_anim.get_animation(anim_name).length * 1000.0)
