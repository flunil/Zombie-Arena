extends Node
class_name WaveManager
## إدارة الموجات: عد تنازلي 5ث → توليد عشوائي خارج إطار الكاميرا → قتل الكل → اختيار ترقية → راحة 5ث → التالية

signal wave_started(wave_num: int)
signal wave_cleared(wave_num: int)
signal kill_event(streak: int)  # سلسلة القتل: تصعد مع كل قتيل وتصفّر عند انتهاء المهلة
signal essence_changed(current: int, threshold: int, death_pos: Vector3)  # تحديث عدّاد الشظايا + موضع الوفاة للطيران البصري
signal essence_full()  # العدّاد امتلأ → فتح شاشة التطويرات

const FIRST_DELAY: float = 5.0
const REST_TIME: float = 5.0
const ARENA_EDGE: float = 23.0
const ESSENCE_THRESHOLD: int = 15  # عدد القتلات لامتلاء العدّاد وفتح التطويرات

@export var zombie_scene: PackedScene
@export var runner_scene: PackedScene
@export var exploder_scene: PackedScene
@export var shield_scene: PackedScene
@export var brute_scene: PackedScene
@export var boss_scene: PackedScene
@export var prewarm: int = 20

var wave: int = 0
var alive: int = 0
var pools: Dictionary = {}  # نوع الزومبي ← الـ Pool الخاص به
var streak: int = 0  # قتيل متتالي (يصفّر إن مضت 3ث بلا قتل)
var essence: int = 0  # شظايا مجمّعة (تزيد مع كل قتيل، تصفّر عند فتح التطويرات)
var _streak_timer: Timer = null
var _state: String = "countdown"  # countdown | fighting | upgrade | rest
var _timer: float = FIRST_DELAY
## إنزال تدريجي للموجة: بذرة واحدة في الإطار تسبّب ذبذبة physics 27-48ms (32 زومبي × revive+agent)
const SPAWN_BATCH: int = 4
const SPAWN_INTERVAL: float = 0.08
var _spawn_queue: Array[String] = []
var _spawn_timer: float = 0.0
var _was_wave_end_upgrade: bool = false  # هل كانت شاشة الترقية من نهاية الموجة (لا من امتلاء العدّاد)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # يستمر أثناء إيقاف شاشة التطويرات
	add_to_group("wave_manager")
	add_child(ZombieBatchManager.new())  # دفعات MultiMesh: رسم واحد لكل نوع زومبي بعيد
	AudioManager.play_music("arena")  # موسيقى الساحة (تتكثف مع الموجات)
	_streak_timer = Timer.new()
	_streak_timer.wait_time = 3.0
	_streak_timer.one_shot = true
	_streak_timer.timeout.connect(_on_streak_timeout)
	add_child(_streak_timer)
	call_deferred("_setup_pool")  # بعد انتهاء تجهيز شجرة المشهد


func _on_streak_timeout() -> void:
	streak = 0
	kill_event.emit(0)


func _setup_pool() -> void:
	_add_pool("basic", zombie_scene, prewarm)
	_add_pool("runner", runner_scene, 8)
	_add_pool("exploder", exploder_scene, 6)
	_add_pool("shield", shield_scene, 6)
	_add_pool("brute", brute_scene, 4)
	_add_pool("boss", boss_scene, 1)


func _add_pool(id: String, scene: PackedScene, count: int) -> void:
	if scene == null:
		return
	var p := ObjectPool.new()
	p.name = id.capitalize() + "Pool"
	add_child(p)
	p.setup(scene, get_parent(), count)
	pools[id] = p


func _process(delta: float) -> void:
	if GM.is_game_over():
		return
	if _state == "fighting":
		_drain_spawn_queue(delta)
		return
	if _state == "upgrade":
		return  # شاشة الترقية تجمّد العدّاد
	_timer -= delta
	if _timer <= 0.0:
		_start_next_wave()


## تفريغ طابور الإنزال: 4 زومبي كل0.08ث بدل32 في إطار واحد (يفصل ذبذبة بداية الموجة)
func _drain_spawn_queue(delta: float) -> void:
	if _spawn_queue.is_empty():
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = SPAWN_INTERVAL
	for i in range(mini(SPAWN_BATCH, _spawn_queue.size())):
		_spawn_zombie(_spawn_queue.pop_front())


func get_state() -> String:
	return _state


## بعد اختيار الترقية → راحة 5ث ثم الموجة التالية (أو استئناف القتال إن كانت من امتلاء العدّاد وأماكن أحياء)
func begin_rest() -> void:
	if _state != "upgrade":
		return
	essence = 0  # تصفير عدّاد الشظايا بعد كل ترقية
	essence_changed.emit(essence, ESSENCE_THRESHOLD, Vector3.ZERO)
	if not _was_wave_end_upgrade and alive > 0:
		# ترقية من امتلاء العدّاد وسط الموجة → استئناف القتال دون بدء موجة جديدة
		_was_wave_end_upgrade = false
		_state = "fighting"
		GM.set_state(GM.State.PLAYING)
		return
	_was_wave_end_upgrade = false
	_state = "rest"
	_timer = REST_TIME


## بدء الموجة التالية (يمكن استدعاؤها يدوياً للاختبار)
func _start_next_wave() -> void:
	wave += 1
	var count: int = (5 + (wave * 3)) * 4  # ×4 أضعاف الحشود حسب طلب المستخدم
	alive = count
	var boss_extra: bool = EnemyFactory.is_boss_wave(wave)
	if boss_extra:
		alive += 1
	_state = "fighting"
	_timer = 0.0
	print("[WM] start wave=", wave, " count=", count, " boss=", boss_extra)
	AudioManager.play_sfx("wave_start", -1.0, 0.03)  # بوق بداية الموجة
	AudioManager.set_arena_intensity(wave)  # تصاعد الموسيقى مع الموجات
	# إنزال تدريجي عبر _drain_spawn_queue (بدون ذبذبة في إطار واحدة)
	_spawn_queue.clear()
	for i in range(count):
		_spawn_queue.append(EnemyFactory.pick_type(wave))
	if boss_extra:
		_spawn_queue.append("boss")  # الزعيم آخرًا
	_spawn_timer = 0.0  # أول دفعة في الإطار التالي
	GM.set_state(GM.State.PLAYING)
	MissionSystem.on_wave_started()  # موجة بلا ضرر: تفعيل التتبع
	UpgradeManager.on_wave_started()  # TimeSlow + مسح استهلاك Revive لهذه الموجة
	wave_started.emit(wave)


func _spawn_zombie(forced_type: String = "") -> void:
	var type_id: String = forced_type
	if type_id == "":
		type_id = EnemyFactory.pick_type(wave)
	if not pools.has(type_id):
		type_id = "basic"
	var p: ObjectPool = pools[type_id]
	var z: Node = p.get_instance()
	if not z.has_meta("wave_connected"):
		z.died.connect(_on_zombie_died.bind(z, p))
		z.set_meta("wave_connected", true)
		if z.has_signal("summon_requested"):
			z.summon_requested.connect(_on_summon_requested)
	z.set_meta("pool_type", type_id)
	z.call("revive", _spawn_position())


## الزعيم يستدعي 3 زومبي — يزيد alive حتى لا تنتهي الموجة مبكراً
func _on_summon_requested(count: int) -> void:
	if _state != "fighting" or GM.is_game_over():
		return
	alive += count
	for i in range(count):
		_spawn_zombie("basic")


## موضع ظهور عشوائي داخل حدود الساحة وخارج إطار كاميرا اللاعب
## (Camera3D/ViewProbeArea/ProbeShape في Player.tscn) حتى لا ينفلت العدو داخل الشاشة
## ومع ذلك بعيداً عن أجسام المدينة الصلبة حتى لا يظهر زومبي داخل مبنى
func _spawn_position() -> Vector3:
	var shape := _probe_shape()
	if shape == null:
		return _escape_spot()
	var box := shape.shape as BoxShape3D
	if box == null:
		return _escape_spot()
	var xf := shape.global_transform  # الصندوق يتبع الكاميرا لحظيًا — يُقرأ وقت الظهور لا يُثبَّت
	var he := box.size * 0.5
	for i in range(24):
		var c := _random_arena_point()
		if not _is_inside_frame(xf, c, he) and not _point_blocked(c):
			return c
	# احتياطي حتمي: زاوية من زوايا الساحة الأربع — لا يمكن لصندوق واحد أن يغطي زاويتين متقابلتين
	var corners := [Vector2(22.5, -22.5), Vector2(-22.5, 22.5), Vector2(22.5, 22.5), Vector2(-22.5, -22.5)]
	for cv in corners:
		var cp := Vector3(cv.x, 0.9, cv.y)
		if not _is_inside_frame(xf, cp, he) and not _point_blocked(cp):
			return cp
	# آخر احتياطي: نقاط ثابتة على محاور الطرق — ممرات خالية من المباني دائماً
	var lanes := [Vector3(0, 0.9, -21), Vector3(0, 0.9, 21), Vector3(21, 0.9, 0), Vector3(-21, 0.9, 0)]
	for lp in lanes:
		if not _point_blocked(lp) and not _is_inside_frame(xf, lp, he):
			return lp
	return _random_arena_point()  # لا يحدث نظريًا — بقاء موضع صالح داخل الساحة


## هل يحجز الموضع جسم صلب؟ (مباني المدينة/الديكور/الجدران) — استعلام فيزياء ثابت
## + فحص سقف رأسي: المباني قشرة trimesh فارغة، الكرة في وسطها لا تلمس جدرانها،
## فنرفض أي نقطة تسقط تحت سقف/جسر (ضربة من الأعلى تكشف المبنى كاملًا)
func _point_blocked(pos: Vector3) -> bool:
	var space := get_tree().root.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.55
	q.shape = sph
	q.transform = Transform3D(Basis(), pos)
	q.collision_mask = 0xFFFFFFFF
	if not space.intersect_shape(q, 1).is_empty():
		return true
	var from := Vector3(pos.x, 60.0, pos.z)
	var rq := PhysicsRayQueryParameters3D.create(from, Vector3(pos.x, pos.y - 0.1, pos.z), 0xFFFFFFFF)
	rq.collide_with_areas = false
	var hit := space.intersect_ray(rq)
	if hit.is_empty():
		return false
	# أرض/طريق ≈ y≤0.15 لا يُحسب؛ أي شيء أعلى من متر فوق النقطة = سقف مبنى/جسر
	return (hit["position"] as Vector3).y > pos.y + 1.5


## بدون كاميرا (اختبارات headless): موضع خالٍ مباشرة
func _escape_spot() -> Vector3:
	for i in range(24):
		var c := _random_arena_point()
		if not _point_blocked(c):
			return c
	return _random_arena_point()


## عقدة شكل الكاميرا عبر مجموعة اللاعب (تعتمد player.gd إضافة "player" للمجموعة)
func _probe_shape() -> CollisionShape3D:
	var p := get_tree().get_first_node_in_group("player") as Node
	if p == null:
		return null
	var cam: Node = p.get_node_or_null("Camera3D")
	if cam == null:
		return null
	return cam.get_node_or_null("ViewProbeArea/ProbeShape") as CollisionShape3D


func _random_arena_point() -> Vector3:
	return Vector3(randf_range(-ARENA_EDGE, ARENA_EDGE), 0.9, randf_range(-ARENA_EDGE, ARENA_EDGE))


## هل النقطة داخل صندوق الإطار؟ (تحويل إلى فضاء الصندوق ثم مقارنة بأنصاف الأبعاد)
func _is_inside_frame(xf: Transform3D, world_pos: Vector3, he: Vector3) -> bool:
	var lp := xf.affine_inverse() * world_pos
	return absf(lp.x) <= he.x and absf(lp.y) <= he.y and absf(lp.z) <= he.z


func _on_zombie_died(zombie: Node, pool: ObjectPool) -> void:
	print("[WM] died wave=", wave, " alive_before=", alive, " z=", zombie.name)
	streak += 1
	_streak_timer.start()  # إعادة بدء مهلة 3ث
	kill_event.emit(streak)
	alive -= 1
	GM.total_kills += 1
	pool.return_instance(zombie)
	# عدّاد الشظايا: +1 مع كل قتيل → عند الامتلاء تُفتح التطويرات فورًا (وسط الموجة)
	essence += 1
	if UpgradeManager.roll_essence_bonus():  # EssenceGain (عادي): +20% جوهرة إضافية
		essence += 1
	essence_changed.emit(essence, ESSENCE_THRESHOLD, zombie.global_position)
	if essence >= ESSENCE_THRESHOLD and _state == "fighting" and alive > 0:
		# امتلأ العدّاد قبل نهاية الموجة → تجميد مؤقت + فتح التطويرات
		essence_full.emit()
		_state = "upgrade"
		_was_wave_end_upgrade = false  # ترقية من العدّاد (ليست نهاية موجة)
		GM.set_state(GM.State.WAVE_CLEARED)  # يجمّد الموجة أثناء الاختيار
		return
	# إصلاح حرج: كان يُشترط alive<=0 فقط → أي زومبي يموت بعد نهاية الموجة
	# (مثلاً تابع للزعيم أو ميت متأخر) يُعيد تشغيل كتلة "نهاية الموجة" → تُبثّ
	# إشارة wave_cleared مرتين → تُفتح قائمة التطويرات مرتين وتتوقف اللعبة مرتين
	# (وهذا سبب "البطء" من الموجة الثالثة). الشرط على _state يضمن التنفيذ مرة واحدة.
	if alive <= 0 and _state == "fighting":
		alive = 0
		_state = "upgrade"  # تجمّد → شاشة الترقية ثم begin_rest
		_was_wave_end_upgrade = true  # ترقية من نهاية الموجة
		GM.waves_completed = wave
		GM.set_state(GM.State.WAVE_CLEARED)
		StatsTracker.record_wave()  # إحصائية دائمة + حفظ
		MissionSystem.record_wave()
		MissionSystem.on_wave_cleared()  # يمنح جواهر "بدون ضرر" إن لم يُصَب اللاعب
		AudioManager.play_sfx("wave_end", -1.0, 0.03)  # جرس نهاية الموجة
		TimeFX.slow_motion(0.3, 0.5)  # بطيء زمن 0.3× نصف ثانية حقيقية عند آخر قتيل
		# شبكة أمان: بعد انتهاء البطء نضمن عودة السرعة الطبيعية
		_watch_time_scale()


## ينهي الموجة: يضمن عودة السرعة الطبيعية ثم يبثّ "الموجة انتهت" (فتح قائمة التطويرات)
## إصلاح حرج: كان منطق نهاية الموجة كلّه محصورًا داخل شرط "السرعة منخفضة"،
## فلا تُبثّ إشارة wave_cleared إلا مصادفةً → القائمة لا تُفتح أصلًا أو تُفتح
## والسرعة عندها 2% فيبدو الأنيميشن واقفًا. الآن المنطق يعمل دائمًا.
func _watch_time_scale() -> void:
	await get_tree().create_timer(0.9, true, false, true).timeout
	if Engine.time_scale < 0.9 and not get_tree().paused:
		TimeFX.reset()
	var wh := UpgradeManager.get_wave_heal()  # HealWave (نادر): +5 صحة عند تنظيف الموجة
	if wh > 0.0:
		UpgradeManager.heal_player(wh)
	SaveSystem.flush()  # نهاية الموجة = نقطة حفظ آمنة (يكتب أي ذهب مؤجّل متبقٍّ)
	wave_cleared.emit(wave)
