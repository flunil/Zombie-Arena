extends CanvasLayer
## HUD: الصحة + الذخيرة + رقم الموجة + الذهب + عدّاد الشظايا + شاشة انتهت اللعبة
## أرقام متدرّجة بـTween + وميض أحمر عند فقد الصحة + عدّاد سلسلة القتل + شظايا طائرة

@onready var ammo_label: Label = $Root/AmmoLabel
@onready var hp_bar: ProgressBar = $Root/HPBar
@onready var wave_label: Label = $Root/WaveLabel
@onready var gold_label: Label = $Root/GoldLabel
@onready var essence_bar: ProgressBar = $Root/EssenceBar
@onready var essence_label: Label = $Root/EssenceLabel
@onready var game_over: Control = $Root/GameOverScreen

var _player: Node = null
var _hp: Node = null

# أرقام متحرّكة (يُقتل tween السابق عند تحديث جديد لمنع التشابك)
var _gold_shown: float = 0.0
var _gold_tw: Tween = null
var _ammo_shown: float = 0.0
var _ammo_tw: Tween = null
var _ammo_max: int = 0
var _wave_shown: float = 0.0
var _wave_tw: Tween = null
var _hp_tw: Tween = null

# عدّاد الشظايا (essence)
var _essence_shown: float = 0.0
var _essence_tw: Tween = null
var _essence_bar_tw: Tween = null

# وميض الشاشة عند فقد الصحة (vignette أحمر خفيف على الحواف)
var _vignette: ColorRect = null
var _vig_tw: Tween = null

# عدّاد سلسلة القتل (×N أعلى منتصف الشاشة + صوت صاعد)
var _streak_label: Label = null
var _streak_tw: Tween = null

# عدّاد الظهور (Area3D أسفل الكاميرا): عناصر ظاهرة على الشاشة مقابل مخفية
var _view_label: Label = null
var _view_area: Area3D = null
var _view_timer: float = 0.0

# شظايا طائرة من موضع الزومبي إلى العدّاد (طبقة UI منفصلة)
var _shard_layer: CanvasLayer = null


func _ready() -> void:
	game_over.visible = false
	_build_vignette()
	_build_streak_label()
	_build_view_label()
	_build_shard_layer()
	_init_essence_ui()
	_player = get_tree().get_first_node_in_group("player")
	if _player != null:
		_hp = _player.get_node_or_null("Health")
		if _hp != null:
			if _hp.has_signal("damaged"):
				_hp.damaged.connect(_on_hp_damaged)
			if _hp.has_signal("healed"):
				_hp.healed.connect(_on_hp_healed)
			if _hp.has_signal("died"):
				_hp.died.connect(_on_player_died)
			_refresh_hp(true)
		if _player.has_signal("gold_changed"):
			_player.gold_changed.connect(_on_gold_changed)
			_gold_shown = float(_player.get("gold"))
			gold_label.text = str(int(_gold_shown))
		_connect_weapon_manager()
	_connect_wave_manager.call_deferred()


## فينيتيج: مستطيل بملء الشاشة يرسم تدرّجًا أحمر على الحواف فقط
func _build_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.name = "DamageVignette"
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(1, 1, 1, 1)
	_vignette.modulate.a = 0.0
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p * vec2(1.1, 0.9));
	float edge = smoothstep(0.30, 0.62, d);
	COLOR = vec4(0.85, 0.05, 0.05, edge * COLOR.a);
}
"""
	mat.shader = sh
	_vignette.material = mat
	var root: Control = get_node("Root")
	root.add_child(_vignette)
	root.move_child(_vignette, 0)  # خلف كل عناصر HUD


## عدّاد السلسلة: ×N أعلى منتصف الشاشة تحت الموجة
func _build_streak_label() -> void:
	_streak_label = Label.new()
	_streak_label.name = "StreakLabel"
	_streak_label.anchor_left = 0.25
	_streak_label.anchor_right = 0.75
	_streak_label.anchor_top = 0.0
	_streak_label.anchor_bottom = 0.0
	_streak_label.offset_top = 76.0
	_streak_label.offset_bottom = 124.0
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_streak_label.add_theme_font_size_override("font_size", 40)
	_streak_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2))
	_streak_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 1.0))
	_streak_label.add_theme_constant_override("outline_size", 8)
	_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak_label.visible = false
	get_node("Root").add_child(_streak_label)


## عدّاد الظهور: "ظاهر / مخفي" أعلى يسار الشاشة تحت شريط الصحة
func _build_view_label() -> void:
	_view_label = Label.new()
	_view_label.name = "ViewCountLabel"
	_view_label.anchor_left = 0.0
	_view_label.anchor_right = 0.55
	_view_label.anchor_top = 0.0
	_view_label.anchor_bottom = 0.0
	_view_label.offset_left = 24.0
	_view_label.offset_top = 70.0
	_view_label.offset_bottom = 106.0
	_view_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_view_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_view_label.add_theme_font_size_override("font_size", 24)
	_view_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_view_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_view_label.add_theme_constant_override("outline_size", 6)
	_view_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_node("Root").add_child(_view_label)


## طبقة شظايا الطيران: CanvasLayer منفصلة فوق كل عناصر HUD
func _build_shard_layer() -> void:
	_shard_layer = CanvasLayer.new()
	_shard_layer.name = "ShardLayer"
	_shard_layer.layer = 10  # فوق HUD (layer 1) وتحت شاشة التطويرات إن لزم
	add_child(_shard_layer)


## تهيئة شريط الشظايا: أصول حزمة Vector_UI — شريط أخضر جاهز + أيقونة جوهرة
const ESSENCE_BAR_BG := preload("res://assets/ui/Vector_UI_Pack_dobo_ui/ProgressBars/progressBarBase_black.png")
const ESSENCE_BAR_FILL := preload("res://assets/ui/Vector_UI_Pack_dobo_ui/ProgressBars/progressBar_green.png")
const ESSENCE_GEM := preload("res://assets/ui/Vector_UI_Pack_dobo_ui/Icons/64px/gem_icon_64px.png")
const ESSENCE_ENERGY := preload("res://assets/ui/Vector_UI_Pack_dobo_ui/Icons/64px/energy_icon_64px.png")


func _init_essence_ui() -> void:
	essence_bar.value = 0.0
	# خلفية: صورة الشريط الأسود الجاهزة (9-slice)
	var bg_tex := ESSENCE_BAR_BG
	var bg_style := StyleBoxTexture.new()
	bg_style.texture = bg_tex
	bg_style.texture_margin_left = 8
	bg_style.texture_margin_right = 8
	bg_style.texture_margin_top = 6
	bg_style.texture_margin_bottom = 6
	essence_bar.add_theme_stylebox_override("background", bg_style)
	# تعبئة: صورة الشريط الأخضر الجاهزة
	var fill_tex := ESSENCE_BAR_FILL
	var fill_style := StyleBoxTexture.new()
	fill_style.texture = fill_tex
	fill_style.texture_margin_left = 8
	fill_style.texture_margin_right = 8
	fill_style.texture_margin_top = 6
	fill_style.texture_margin_bottom = 6
	essence_bar.add_theme_stylebox_override("fill", fill_style)
	# أيقونة جوهرة يسار الشريط
	var gem_icon := TextureRect.new()
	gem_icon.name = "EssenceGemIcon"
	gem_icon.texture = ESSENCE_GEM
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.custom_minimum_size = Vector2(22, 22)
	gem_icon.position = Vector2(essence_bar.position.x - 26, essence_bar.position.y - 2)
	gem_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_icon.z_index = 1
	get_node("Root").add_child(gem_icon)
	# تحديث موضع الأيقونة عند تغيّر حجم الشريط
	essence_bar.resized.connect(func() -> void:
		if is_instance_valid(gem_icon):
			gem_icon.position = Vector2(essence_bar.global_position.x - 26, essence_bar.global_position.y - 2)
	)
	essence_label.text = "0 / %d" % _essence_threshold()
	# نص العدّاد: أخضر فاتح مع حد داكن
	essence_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.55, 1.0))
	essence_label.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.02, 0.95))
	essence_label.add_theme_constant_override("outline_size", 4)


func _essence_threshold() -> int:
	var wm: Node = get_tree().get_first_node_in_group("wave_manager")
	if wm != null:
		return int(wm.get("ESSENCE_THRESHOLD"))
	return 15


func _process(delta: float) -> void:
	_view_timer -= delta
	if _view_timer > 0.0:
		return
	_view_timer = 0.25
	_update_view_count()


## عدّ الأعداء الحيّة: داخل Area3D أسفل الكاميرا = ظاهر، وخارجها = مخفي (المعلّقة/البركة خارج الحساب)
func _update_view_count() -> void:
	if _view_label == null:
		return
	if _view_area == null and _player != null:
		var cam: Node = _player.get_node_or_null("Camera3D")
		if cam != null:
			_view_area = cam.get_node_or_null("ViewProbeArea") as Area3D
	var vis := 0
	var hid := 0
	var bodies: Array[Node3D] = []
	if _view_area != null:
		bodies = _view_area.get_overlapping_bodies()
	for en in get_tree().get_nodes_in_group("enemies"):
		var e := en as Node3D
		if e == null or not e.visible:
			continue
		if e.get("_dead") == true:  # عقد بلا سكربت (أعداء وهمية بالاختبارات) تعيد null — مقارنة مباشرة بلا bool()
			continue
		if bodies.has(e):
			vis += 1
		else:
			hid += 1
	_view_label.text = "Visible: %d   Hidden: %d" % [vis, hid]


func _connect_wave_manager() -> void:
	var wm: Node = get_tree().get_first_node_in_group("wave_manager")
	if wm == null:
		return
	if wm.has_signal("wave_started"):
		wm.wave_started.connect(_on_wave_started)
	if wm.has_signal("wave_cleared"):
		wm.wave_cleared.connect(_on_wave_cleared)
	if wm.has_signal("kill_event"):
		wm.kill_event.connect(_on_kill_event)
	if wm.has_signal("essence_changed"):
		wm.essence_changed.connect(_on_essence_changed)
	if wm.has_signal("essence_full"):
		wm.essence_full.connect(_on_essence_full)
	_wave_shown = float(wm.get("wave"))
	wave_label.text = "Wave %d" % int(_wave_shown)


## ربط مدير الأسلحة: الذخيرة فقط (شريط تبديل الأزال بطلب المستخدم — التبديل Q/E/RB)
func _connect_weapon_manager() -> void:
	var mgr: Node = _player.get_node_or_null("WeaponManager")
	if mgr == null:
		return
	if mgr.has_signal("ammo_changed"):
		mgr.ammo_changed.connect(_on_ammo_changed)


func _refresh_hp(instant: bool = false) -> void:
	if _hp == null:
		return
	var target := 100.0 * float(_hp.call("get_percent"))
	if _hp_tw != null and _hp_tw.is_valid():
		_hp_tw.kill()
	if instant:
		hp_bar.value = target
		return
	_hp_tw = create_tween()
	_hp_tw.tween_property(hp_bar, "value", target, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## فقد صحة → تدرّج الشريط + وميض أحمر خفيف على الحواف
func _on_hp_damaged(_amount: float, _new_health: float) -> void:
	_refresh_hp()
	flash_damage()


## استعادة صحة → تدرّج الشريط بلا وميض
func _on_hp_healed(_amount: float, _new_health: float) -> void:
	_refresh_hp()


func flash_damage() -> void:
	if _vignette == null:
		return
	if _vig_tw != null and _vig_tw.is_valid():
		_vig_tw.kill()
	_vignette.modulate.a = 0.5
	_vig_tw = create_tween()
	_vig_tw.tween_property(_vignette, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_OUT)


## الذهب: عدّ متدرّج من القيمة المعروضة إلى الجديدة
func _on_gold_changed(new_gold: int) -> void:
	if _gold_tw != null and _gold_tw.is_valid():
		_gold_tw.kill()
	_gold_tw = create_tween()
	_gold_tw.tween_method(_set_gold_shown, _gold_shown, float(new_gold), 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _set_gold_shown(v: float) -> void:
	_gold_shown = v
	gold_label.text = str(int(round(v)))


## الذخيرة: عدّ متدرّج مع الحفاظ على صيغة "الحالي / الأقصى"
func _on_ammo_changed(current: int, max_ammo: int) -> void:
	_ammo_max = max_ammo
	if _ammo_tw != null and _ammo_tw.is_valid():
		_ammo_tw.kill()
	_ammo_tw = create_tween()
	_ammo_tw.tween_method(_set_ammo_shown, _ammo_shown, float(current), 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _set_ammo_shown(v: float) -> void:
	_ammo_shown = v
	ammo_label.text = "%d / %d" % [int(round(v)), _ammo_max]


## الموجة: عدّ متدرّج إلى رقمها الجديد
func _on_wave_started(wave_num: int) -> void:
	if _wave_tw != null and _wave_tw.is_valid():
		_wave_tw.kill()
	_wave_tw = create_tween()
	_wave_tw.tween_method(_set_wave_shown, _wave_shown, float(wave_num), 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_wave_cleared(wave_num: int) -> void:
	wave_label.text = "Wave %d — Cleared" % wave_num


func _set_wave_shown(v: float) -> void:
	_wave_shown = v
	wave_label.text = "Wave %d" % int(round(v))


## سلسلة القتل: عرض ×N بنبضة + صوت صاعد مع كل قتيل (0 = تصفّر وإخفاء)
func _on_kill_event(streak: int) -> void:
	if _streak_tw != null and _streak_tw.is_valid():
		_streak_tw.kill()
	if streak <= 0:
		_streak_tw = create_tween()
		_streak_tw.tween_property(_streak_label, "modulate:a", 0.0, 0.3)
		_streak_tw.tween_callback(func() -> void: _streak_label.visible = false)
		return
	_streak_label.text = "×%d" % streak
	_streak_label.visible = true
	_streak_label.modulate.a = 1.0
	_streak_label.pivot_offset = _streak_label.size * 0.5
	_streak_label.scale = Vector2(1.35, 1.35)
	_streak_tw = create_tween()
	_streak_tw.tween_property(_streak_label, "scale", Vector2.ONE, 0.22) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# صوت صاعد: مقياس الصوت يتصاعد مع كل قتيل (×1.07 حتى ×1.9)
	var pitch := clampf(1.0 + float(streak) * 0.07, 1.0, 1.9)
	AudioManager.play_sfx("kill_streak", -2.0, 0.0, pitch)


## تحديث عدّاد الشظايا: نبضة + تحديث الشريط والنص + شظايا طائرة من موضع الوفاة
func _on_essence_changed(current: int, threshold: int, death_pos: Vector3) -> void:
	# شظايا طائرة من موضع الزومبي الذي مات
	if death_pos != Vector3.ZERO:
		_spawn_flying_shard(death_pos)
	# تحديث الشريط بنبضة سلسة
	if _essence_bar_tw != null and _essence_bar_tw.is_valid():
		_essence_bar_tw.kill()
	var target_pct := 100.0 * float(current) / float(maxi(threshold, 1))
	_essence_bar_tw = create_tween()
	_essence_bar_tw.tween_property(essence_bar, "value", target_pct, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# تحديث النص
	if _essence_tw != null and _essence_tw.is_valid():
		_essence_tw.kill()
	_essence_tw = create_tween()
	_essence_tw.tween_method(_set_essence_shown, _essence_shown, float(current), 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# نبضة حجم عند الإضافة + وميض أخضر خفيف على الحدود
	essence_bar.pivot_offset = essence_bar.size * 0.5
	essence_bar.scale = Vector2(1.06, 1.35)
	var tw := create_tween()
	tw.tween_property(essence_bar, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# وميض حدود أخضر خفيف (تأثير توهج لحظي)
	essence_bar.modulate = Color(0.8, 1.4, 0.9, 1.0)
	var tw2 := create_tween()
	tw2.tween_property(essence_bar, "modulate", Color(1.0, 1.0, 1.0, 0.95), 0.3).set_ease(Tween.EASE_OUT)


func _set_essence_shown(v: float) -> void:
	_essence_shown = v
	var threshold := _essence_threshold()
	essence_label.text = "%d / %d" % [int(round(v)), threshold]


## العدّاد امتلأ → احتفال: نبضة كبيرة + وميض نيون أخضر + توهج حافات
func _on_essence_full() -> void:
	# نبضة امتلاء دراماتيكية: تكبير كبير مع ارتداد مرن
	essence_bar.pivot_offset = essence_bar.size * 0.5
	essence_bar.scale = Vector2(1.25, 1.8)
	var tw := create_tween()
	tw.tween_property(essence_bar, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	# وميض نيون أخضر قوي ثم عودة للوضع الطبيعي
	essence_bar.modulate = Color(0.8, 1.8, 0.9, 1.0)
	var tw2 := create_tween()
	tw2.tween_property(essence_bar, "modulate", Color(1.0, 1.0, 1.0, 0.95), 0.6).set_ease(Tween.EASE_OUT)
	# نبضة حجم النص أيضًا
	essence_label.pivot_offset = essence_label.size * 0.5
	essence_label.scale = Vector2(1.3, 1.3)
	var tw3 := create_tween()
	tw3.tween_property(essence_label, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	# صوت امتلاء
	AudioManager.play_sfx("upgrade_pick", -2.0, 0.08)


## شظية طائرة واحدة: أيقونة جوهرة حقيقية من حزمة UI بدل مربع ملوّن
## تحويل موضع العالم إلى شاشة ثم طيران إلى العدّاد مع أثر توهج
func _spawn_flying_shard(world_pos: Vector3) -> void:
	if _shard_layer == null or _player == null:
		return
	var cam: Camera3D = _player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	# تحويل موضع الزومبي في العالم إلى إحداثيات شاشة
	var screen_pos := cam.unproject_position(world_pos)
	# موضع العدّاد على الشاشة (منتصف أعلى)
	var target := Vector2(essence_bar.global_position.x + essence_bar.size.x * 0.5,
		essence_bar.global_position.y + essence_bar.size.y * 0.5)
	# شظية: أيقونة جوهرة (TextureRect) — أصغر قليلًا مع طيران
	var shard := TextureRect.new()
	shard.texture = ESSENCE_GEM
	shard.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shard.custom_minimum_size = Vector2(20, 20)
	shard.size = Vector2(20, 20)
	shard.position = screen_pos - shard.size * 0.5
	shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# توهج أخضر: modulate يُلوِّن الجوهرة الوردية إلى أخضر نيون
	shard.modulate = Color(0.4, 1.6, 0.5, 1.0)
	_shard_layer.add_child(shard)
	# أثر باهت: نسخة أصغر وأخف خلف الجوهرة
	var trail := TextureRect.new()
	trail.texture = ESSENCE_GEM
	trail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trail.custom_minimum_size = Vector2(12, 12)
	trail.size = Vector2(12, 12)
	trail.position = screen_pos - trail.size * 0.5
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail.modulate = Color(0.3, 1.0, 0.4, 0.35)
	_shard_layer.add_child(trail)
	# طيران متعرج مع تسارع ثم ارتداد نحو الهدف
	var mid := screen_pos.lerp(target, 0.45) + Vector2(randf_range(-50, 50), randf_range(-40, 15))
	# الجوهرة الرئيسية
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(shard, "position", mid, 0.16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(shard, "size", Vector2(12, 12), 0.16)
	tw.tween_property(shard, "rotation", randf_range(-0.5, 0.5), 0.16)
	tw.chain()
	tw.tween_property(shard, "position", target - shard.size * 0.5, 0.24).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(shard, "modulate", Color(0.6, 2.2, 0.7, 0.0), 0.18)
	tw.tween_callback(shard.queue_free)
	# الأثر الباهت يتبع بتأخير خفيف
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(trail, "position", mid + Vector2(randf_range(-10, 10), randf_range(-8, 5)), 0.20).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw2.tween_property(trail, "size", Vector2(6, 6), 0.20)
	tw2.chain()
	tw2.tween_property(trail, "position", target - trail.size * 0.5, 0.26).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw2.tween_property(trail, "modulate:a", 0.0, 0.2)
	tw2.tween_callback(trail.queue_free)


func _on_player_died() -> void:
	var gold: int = 0
	if _player != null:
		gold = int(_player.get("gold"))
	game_over.call("show_stats", int(GM.waves_completed), int(GM.total_kills), gold)
