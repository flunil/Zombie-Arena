extends Control
class_name UpgradeSelection
## شاشة اختيار الترقية: 3 بطاقات بعد كل موجة → تطبيق فوري + راحة 5ث ثم الموجة التالية

const CARD_SCENE: String = "res://scenes/ui/UpgradeCard.tscn"

## خريطة أيقونات حزمة الواجهة لكل ترقية — عدّلها يدويًا لتغيير أي أيقونة
## (بلاها أو بغياب الملف: مربع لون مسطّح بلون الترقية)
const ICON_MAP: Dictionary = {
	"ammo_boost": "res://assets/ui/Vector_UI_Pack_dobo_ui/Icons/128px/energy_icon_128px.png",
	"auto_heal": "res://assets/ui/Vector_UI_Pack_dobo_ui/Icons/128px/plusV2_icon_128px.png",
	"damage_boost": "res://assets/ui/Vector_UI_Pack_dobo_ui/Icons/128px/sword_icon_128px.png",
	"death_explosion": "res://assets/ui/Vector_UI_Pack_dobo_ui/Icons/128px/chestSkull_icon_128px.png",
	"drone_ally": "res://assets/ui/Vector_UI_Pack_dobo_ui/Icons/128px/skills_icon_128px.png",
	"energy_shield": "res://assets/ui/Vector_UI_Pack_dobo_ui/Icons/128px/armor_icon_128px.png",
	"explosive_rounds": "res://assets/ui/Vector_UI_Pack_dobo_ui/Icons/128px/warningCircle_icon_128px.png",
	"fire_rate_boost": "res://assets/ui/Vector_UI_Pack_dobo_ui/Icons/128px/timer_icon_128px.png",
	"freeze": "res://assets/ui/Vector_UI_Pack_dobo_ui/Icons/128px/gem_icon_128px.png",
	"piercing": "res://assets/ui/Vector_UI_Pack_dobo_ui/Arrows/arrow_yellow.png",
	"second_weapon": "res://assets/ui/Vector_UI_Pack_dobo_ui/Icons/128px/adventure_icon_128px.png",
	"time_slow": "res://assets/ui/Vector_UI_Pack_dobo_ui/Icons/128px/options_icon_128px.png",
}

## آلة الحظ: بكرات تدور داخل البطاقات قبل كشف الترقيات ثم تتوقف واحدة تلو الأخرى
const REEL_TICK: float = 0.09  # خطوة البكرة: تبديل رمز + انزلاق رأسي متزامن (~11 رمز/ث)
const REEL_DROP: float = 40.0  # مسافة انزلاق كل خطوة بالبكسل (المحتوى ينزل من فوق إلى مكانه)
const REEL_STOPS: Array[float] = [0.9, 1.5, 2.1]  # زمن توقّف كل بكرة بالثواني
const HINT_SPIN: String = "Spinning the wheel of fortune..."
const HINT_FINAL: String = "The next wave starts after you pick"
const REEL_PARTS: Array[String] = ["IconFrame", "NameLabel", "DescLabel"]  # أجزاء المحتوى التي تنزلق معًا

## إطار ناري يظهر حول البطاقة المحددة (تحويم/تركيز) — شادر ملء الشاشة خلف المحتوى
const FIRE_SHADER: String = "res://shaders/upgrade_card_fire.gdshader"
const FIRE_MARGIN: float = 14.0  # امتداد الإطار خارج حدود البطاقة (بكسل)
const FIRE_CARD: Vector2 = Vector2(168, 262)  # حجم البطاقة المرجعي لرسم حلبة الحدود
const FIRE_CORNER: float = 12.0  # نصف قطر الحواف (يطابق StyleBox البطاقة)

## معاملات الشادر الناري — عدّلها هنا لتغيير ألوان النار وقوّتها
const FIRE_PARAMS: Dictionary = {
	"margem_seguranca": 0.0,  # 0 حتى لا يقصّ الشادر حافة الإطار
	"pixelado": false,  # واجهة ناعمة بدل مربّعات البكسل
	"usar_rastro_procedural": false,  # نستخدم حدود البطاقة (نصورة) لا حلبة دائرية
	"usar_textura_formato": true,
	"formato_tex_escala": Vector2(1, 1),
	"distorcer_textura": true,
	"distorcao_forca": 0.008,  # تموّج خفيف جدًا — الشريط صار رفيعًا فلا نقصّر لسانًا
	"distorcao_velocidade": 1.5,
	"distorcao_escala": 2.5,
	"intensidade_glow": 1.15,  # تبقى الأزرق فاتحًا بدل أن يشطف إلى أبيض
	"forca_fogo": 1.5,
	"variacao_caos": 1.2,
	"criar_faiscas": true,
	"qtd_faiscas": 0.55,
	"velocidade_puxao_faiscas": 1.6,
	"faiscas_com_borda": true,
	"alpha_geral": 1.0,
	"cor_externa": Color(0.04, 0.18, 0.55, 1.0),  # أزرق غامق على الحافة الخارجية
	"cor_media": Color(0.12, 0.45, 0.9, 1.0),  # أزرق متوسط
	"cor_nucleo": Color(0.5, 0.82, 1.0, 1.0),  # أزرق فاتح في القلب
	"cor_contorno": Color(0.0, 0.03, 0.15, 1.0),  # كحلي شديد للحدّ الداكن والشرر
}

## لحظة الاختيار: البطاقة المختارة تكبر حتى تملأ الشاشة ونار ذهبية تشتعل حولها
const HERO_SCALE: float = 2.55  # كم تكبر البطاقة البطلة
const HERO_POS: Vector2 = Vector2(0.5, 0.44)  # مركز الشاشة قليلًا فوق المنتصف (التمهيد تحت)
const HERO_T_UP: float = 0.5  # زمن القفز الصاعد
const HERO_T_SETTLE: float = 0.28  # زمن تهدئة الميلان
const HERO_T_HOLD: float = 0.35  # زمن التوقف قبل التلاشي
const HERO_T_FADE: float = 0.3  # زمن تلاشي الشاشة

## معاملات اللهب الذهبي (تُدمج فوق FIRE_PARAMS) — ذهبي دافئ مشتعل
const FIRE_GOLD: Dictionary = {
	"distorcao_forca": 0.012,  # تموّج أكبر للحظة البطولة
	"intensidade_glow": 1.5,
	"forca_fogo": 2.6,
	"variacao_caos": 1.35,
	"qtd_faiscas": 1.0,
	"velocidade_puxao_faiscas": 2.4,
	"cor_externa": Color(0.7, 0.24, 0.0, 1.0),  # كهرماني عميق على الحافة
	"cor_media": Color(1.0, 0.7, 0.15, 1.0),  # ذهبي
	"cor_nucleo": Color(1.0, 0.96, 0.66, 1.0),  # ذهبي شاحب في القلب
	"cor_contorno": Color(0.14, 0.06, 0.0, 1.0),  # بني داكن للحدّ
}

@onready var cards: HBoxContainer = $Cards
@onready var hint: Label = $Hint

var _reel_spinning := false
var _reel_gen := 0  # جيل التوليد الحالي: أي شاشة جديدة تُلغي بكرات سابقة معلّقة
var _reel_tweens: Dictionary = {}  # بطاقة → Tween خطوة الانزلاق الأخير
var _reel_rot: Dictionary = {}  # بطاقة → Tween دوران الأيقونة المستمر
var _reel_bases: Dictionary = {}  # بطاقة → مواضع y الأصلية لأجزاء المحتوى
var _cards_base_x := 0.0  # موضع اللوحة قبل اهتزاز الماكينة

var _wm: Node = null
var _card_scene: PackedScene = null
var _icon_cache: Dictionary = {}
var _icon_fallback: Dictionary = {}  # upgrade_id → مربع لون احتياطي (مخبّأة بدل إعادة إنشائه كل نبضة بكرة)
var _rarity_sb: Dictionary = {}  # أنماط حدود ملوّنة حسب الندرة (مخبّأة)
var _fire_mats: Dictionary = {}  # حجم البطاقة → ShaderMaterial ناري مشترك
var _fire_noises: Array = []  # [noise_tex, noise_tex2] مولّدة مرة واحدة
var _fire_border: Dictionary = {}  # حجم البطاقة → صورة حلبة الحدود
var _fire_failed := false  # الشادر غير متاح — بلا محاولة إضافية
var _fire_gold: Dictionary = {}  # حجم البطاقة → مادة اللهب الذهبي
var _picking := false  # لحظة البطاقة البطلة جارية — بلا اختيار ثانٍ
var _hero_gold: ShaderMaterial = null  # مادة البطلة أثناء اشتعالها (للتحريك)
var _self_tweens: Array = []  # توينات مُنشأة على هذا العقد (لحظة البطلة) — تُقتل عند فتح جديد
var _card_pool: Array[Button] = []  # إعادة استخدام البطاقات بدل الإنشاء/التدمير
var _pool_ready := false


func _ready() -> void:
	visible = false
	_cards_base_x = cards.position.x
	call_deferred("_connect_wm")  # بعد اكتمال جاهزية كل العقد
	call_deferred("_warm_fire")  # توليد الضجيج والحدود مبكرًا حتى لا تتخلف أول بطاقة
	call_deferred("_warm_upgrades")  # تحميل كل الترقيات مسبقًا لتفادي تأخر أول فتح
	call_deferred("_init_card_pool")  # تجهيز مسبق ل3 بطاقات


func _init_card_pool() -> void:
	if _pool_ready:
		return
	for i in 3:
		var btn := _create_card_fresh()
		if btn != null:
			btn.visible = false
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(btn)
			_card_pool.append(btn)
	_pool_ready = true


func _get_card() -> Button:
	if not _card_pool.is_empty():
		var b := _card_pool.pop_back() as Button
		b.visible = true
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.scale = Vector2.ONE
		b.modulate = Color(1,1,1)
		b.rotation = 0.0
		b.position = Vector2.ZERO
		return b
	return _create_card_fresh()


func _create_card_fresh() -> Button:
	if _card_scene == null and FileAccess.file_exists(CARD_SCENE):
		_card_scene = load(CARD_SCENE) as PackedScene
	var btn: Button = null
	if _card_scene != null:
		btn = _card_scene.instantiate() as Button
	if btn == null:
		btn = Button.new()
		btn.custom_minimum_size = Vector2(168, 262)
	return btn


func _return_card(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	# إزالة اتصالات _on_pick
	if btn.pressed.is_connected(_on_pick):
		pass  # لا يمكن إلغاء ربط bind بسهولة، سنخفيها فقط
	btn.visible = false
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if btn.get_parent() == self:
		remove_child(btn)
	elif btn.get_parent() == cards:
		cards.remove_child(btn)
	if _card_pool.size() < 6:
		_card_pool.append(btn)
	else:
		btn.queue_free()


## تحميل مسبق للترقيات ومشهد البطاقة
func _warm_upgrades() -> void:
	if _card_scene == null and FileAccess.file_exists(CARD_SCENE):
		_card_scene = load(CARD_SCENE) as PackedScene
	UpgradeManager.all_upgrades()
	# تحميل مسبق لكل أيقونات fallback
	for u in UpgradeManager.all_upgrades():
		var uid := str(u.upgrade_id)
		if not _icon_fallback.has(uid):
			var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
			img.fill(u.icon_color)
			_icon_fallback[uid] = ImageTexture.create_from_image(img)
	# تحضير مسبق لألوان الندرة
	for r in [0,1,2]:
		var _c := UpgradeManager.rarity_color(r)


## تجهيز مادة الشادر الناري مرة واحدة عند تحميل المشهد (بلا كلفة عند أول تحويم)
func _warm_fire() -> void:
	if _fire_failed or _fire_mats.has(FIRE_CARD):
		return
	if _fire_material(FIRE_CARD) == null:
		_fire_failed = true


func _connect_wm() -> void:
	_wm = get_tree().get_first_node_in_group("wave_manager")
	if _wm != null and _wm.has_signal("wave_cleared"):
		_wm.wave_cleared.connect(_on_wave_cleared)
	if _wm != null and _wm.has_signal("essence_full"):
		_wm.essence_full.connect(_on_essence_full)


func _on_wave_cleared(_wave_num: int) -> void:
	if GM.is_game_over():
		return
	# لحظة القتل الأخير بطيء زمن 0.3× نصف ثانية → نؤخر الشاشة زمنًا حقيقيًا لتُرى اللحظة
	await get_tree().create_timer(0.6, true, false, true).timeout
	if GM.is_game_over():
		return
	_show_options()


## العدّاد امتلأ (وسط الموجة) → فتح التطويرات فورًا
func _on_essence_full() -> void:
	if GM.is_game_over():
		return
	_show_options()


## تنظيف دفاعي عند كل فتح: يضمن أن لا تتراكم بقايا شاشة سابقة (بطاقات بطلة ضالة أو توينات)
## مهما تعثّر مسار _hero_end — وإلا تتكاثف الشاشات القديمة فيصبح الفتح التالي أبطأ
func _reset_open_state() -> void:
	# موت أي توينات لاصقة بهذا العقد (لحظة البطلة/التلاشي) حتى لا تتراكم
	for t in _self_tweens:
		if t != null and is_instance_valid(t):
			(t as Tween).kill()
	_self_tweens.clear()
	# البطاقة البطلة تُنقل من cards لتصبح ابناً مباشراً لنا — إن فات _hero_end تبقى ضالة هنا
	for c in get_children():
		if c is Button:
			c.queue_free()
	# إعادة الضبط في حال توقّف الفتح السابق قبل نهايته الطبيعية
	_hero_gold = null
	_picking = false
	modulate.a = 1.0


func _show_options() -> void:
	# إيقاف اللعب أولاً: أي تجميد لحظي قادم من القتال لن يصل الواجهة
	get_tree().paused = true  # إيقاف اللعب أثناء قائمة التطويرات
	process_mode = Node.PROCESS_MODE_ALWAYS  # نبقى نشطة رغم الإيقاف
	# إصلاح حرج: استعادة سرعة الوقت (منع Slow Motion دائم بعد تداخل التأثيرات)
	# بعد الإيقاف تحديدًا: لو استعدناها قبله لأمكن أن يصيبها تجميد لحظي أثناء البناء
	TimeFX.reset()
	_reset_open_state()  # تنظيف دفاعي: أي بقايا شاشة سابقة لا تتراكم بين الفتحات
	var options := UpgradeManager.pick_three()
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	var idx := 0
	for u in options:
		var btn := _make_card(u)
		cards.add_child(btn)
		_pulse_card(btn, idx)
		idx += 1
	# عناصر HUD تُضاف وقت التشغيل (السلسلة/الظهور) تأتي بعدنا في الترتيب → نعلو فوقها كي يشملها التعتيم
	var p := get_parent()
	if p != null:
		p.move_child(self, p.get_child_count() - 1)
	visible = true
	_reel_gen += 1
	hint.text = HINT_SPIN
	_reel_reveal(options)  # بكرات ماكينة الحظ تدور ثم تكشف الترقيات


func _fill_card(btn: Button, u) -> void:
	if btn == null or u == null:
		return
	var name_l := btn.get_node_or_null("NameLabel") as Label
	if name_l != null:
		name_l.text = u.display_name
	var desc_l := btn.get_node_or_null("DescLabel") as Label
	if desc_l != null:
		desc_l.text = u.description
	_fill_icon(btn.get_node_or_null("IconFrame/Icon") as TextureRect, u)
	# ربط الضغط
	if btn.pressed.is_connected(_on_pick):
		btn.pressed.disconnect(_on_pick)
	btn.pressed.connect(_on_pick.bind(u.upgrade_id))
	btn.set_meta("_pick_id", u.upgrade_id)
	_apply_rarity(btn, u)
	_setup_fire_frame(btn)


## بطاقة واحدة: مشهد مصمَّم (UpgradeCard) مع تعبئة البيانات + بديل بسيط عند فشل التحميل
func _make_card(u) -> Button:
	if _card_scene == null and FileAccess.file_exists(CARD_SCENE):
		_card_scene = load(CARD_SCENE) as PackedScene
	var btn: Button = null
	if _card_scene != null:
		btn = _card_scene.instantiate() as Button
	if btn == null:
		btn = _fallback_card(u)
	else:
		var name_l := btn.get_node_or_null("NameLabel") as Label
		if name_l != null:
			name_l.text = u.display_name
		var desc_l := btn.get_node_or_null("DescLabel") as Label
		if desc_l != null:
			desc_l.text = u.description
		_fill_icon(btn.get_node_or_null("IconFrame/Icon") as TextureRect, u)
	btn.pressed.connect(_on_pick.bind(u.upgrade_id))
	btn.set_meta("_pick_id", u.upgrade_id)
	_apply_rarity(btn, u)
	_setup_fire_frame(btn)
	return btn


## ندرة البطاقة: حدود ملوّنة (أزرق/ذهبي/بنفسجي) + شارة "عادي/نادر/ممتاز"
func _apply_rarity(btn: Button, u) -> void:
	if btn == null or not (u is UpgradeResource):
		return
	var r := int((u as UpgradeResource).rarity)
	var col := UpgradeManager.rarity_color(r)
	var base_key := str(r)
	if not _rarity_sb.has(base_key):
		var sb_n := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if sb_n != null:
			sb_n.border_color = col
			_rarity_sb[base_key] = sb_n
		var sb_h := btn.get_theme_stylebox("hover").duplicate() as StyleBoxFlat
		if sb_h != null:
			sb_h.border_color = col.lightened(0.3)
			_rarity_sb["hover_" + base_key] = sb_h
	if _rarity_sb.has(base_key):
		btn.add_theme_stylebox_override("normal", _rarity_sb[base_key])
		btn.add_theme_stylebox_override("pressed", _rarity_sb[base_key])
	if _rarity_sb.has("hover_" + base_key):
		btn.add_theme_stylebox_override("hover", _rarity_sb["hover_" + base_key])
	if btn.get_node_or_null("RarityTag") == null:
		var tag := Label.new()
		tag.name = "RarityTag"
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.text = UpgradeManager.rarity_name(r)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.anchor_right = 1.0
		tag.offset_top = 0.0
		tag.offset_bottom = 14.0
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", col)
		tag.add_theme_color_override("font_outline_color", Color.BLACK)
		tag.add_theme_constant_override("outline_size", 4)
		btn.add_child(tag)


## إضافة الإطار الناري خلف محتوى البطاقة — ظاهر دائمًا مع ت усиление عند التحويم
func _setup_fire_frame(btn: Button) -> void:
	var sz := btn.custom_minimum_size
	if sz.x < 1.0 or sz.y < 1.0:
		sz = FIRE_CARD
	var mat := _fire_material(sz)
	if mat == null:
		return
	var fx := ColorRect.new()
	fx.name = "FireFrame"
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.material = mat
	fx.visible = false  # مخفي عند السكون — لا يشغّل الشادر الثقيل إلا عند التحويم (يرفع الأداء)
	btn.add_child(fx)
	btn.move_child(fx, 0)  # خلف الأيقونة والنصوص (الأبناء يرسمون فوق الأب)
	fx.anchor_left = 0.0
	fx.anchor_top = 0.0
	fx.anchor_right = 1.0
	fx.anchor_bottom = 1.0
	fx.offset_left = -FIRE_MARGIN
	fx.offset_top = -FIRE_MARGIN
	fx.offset_right = FIRE_MARGIN
	fx.offset_bottom = FIRE_MARGIN
	fx.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fx.grow_vertical = Control.GROW_DIRECTION_BOTH
	btn.set_meta("_fire", 0)  # مطفأ عند السكون
	# الشادر يشتعل عند تحويم الماوس أو تركيز الكيبورد فقط (بدل تشغيله دائمًا على3 بطاقات)
	btn.mouse_entered.connect(_set_fire.bind(btn, 1, true))
	btn.mouse_exited.connect(_set_fire.bind(btn, 1, false))
	btn.focus_entered.connect(_set_fire.bind(btn, 2, true))
	btn.focus_exited.connect(_set_fire.bind(btn, 2, false))


## إظهار/إخفاء الإطار: bit1 = تحويم الماوس، bit2 = تركيز كيبورد/يد تحكم
func _set_fire(btn: Button, mask: int, on: bool) -> void:
	if bool(btn.get_meta("_fire_lock", false)):
		return  # بطلة الاختيار: النار مثبّتة لا يطفئها خروج الماوس
	var v := int(btn.get_meta("_fire", 0))
	if on:
		v |= mask
	else:
		v &= ~mask
	btn.set_meta("_fire", v)
	var fx := btn.get_node_or_null("FireFrame") as Control
	if fx != null:
		fx.visible = v != 0


## أيقونة الترقية من ICON_MAP (مخزَّنة) أو مربع لون مسطّح احتياطيًا
func _fill_icon(icon_r: TextureRect, u) -> void:
	if icon_r == null:
		return
	var path := str(ICON_MAP.get(u.upgrade_id, ""))
	if path != "" and FileAccess.file_exists(path):
		if not _icon_cache.has(path):
			_icon_cache[path] = load(path) as Texture2D
		icon_r.texture = _icon_cache[path] as Texture2D
		return
	# مربع لون احتياطي: مخزَّن لكل ترقية (يمنع إعادة إنشاء ImageTexture كل نبضة بكرة)
	var uid := str(u.upgrade_id)
	if not _icon_fallback.has(uid):
		var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		img.fill(u.icon_color)
		_icon_fallback[uid] = ImageTexture.create_from_image(img)
	icon_r.texture = _icon_fallback[uid] as Texture2D


## بديل: زر نصي صلب إن فشل تحميل مشهد البطاقة (وظيفة كاملة بلا تنسيق الحزمة)
func _fallback_card(u) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(168, 262)
	btn.text = u.display_name + "\n\n" + u.description
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 15)
	return btn


## نبضة فتح البطاقة: تكبير بـTween مع تجاوز خفيف وتأخير متدرّج لكل بطاقة
func _pulse_card(btn: Button, idx: int) -> void:
	btn.pivot_offset = btn.custom_minimum_size * 0.5
	btn.scale = Vector2(0.6, 0.6)
	var tw := _ui_tween(btn)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.38) \
		.set_delay(float(idx) * 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## تويت خاص بواجهة القوائم: يتجاهل Engine.time_scale حتى لا يجمّده أي تجميد لحظي
## (كان أي hit_stop أثناء فتح القائمة يخفض السرعة إلى 0.02 فيبدو الأنيميشن واقفًا)
func _ui_tween(n: Node) -> Tween:
	var tw := n.create_tween()
	tw.set_ignore_time_scale(true)
	return tw


## بكرات ماكينة الحظ: خلط + انزلاق رأسي متزامن ثم توقّف متدرّج (0.9/1.5/2.1ث) مع اهتزاز اللوحة
func _reel_reveal(options: Array) -> void:
	var gen := _reel_gen
	_reel_spinning = true
	_reel_tweens.clear()
	_reel_rot.clear()
	_reel_bases.clear()
	cards.position.x = _cards_base_x
	var btns: Array = []
	for i in cards.get_child_count():
		var b := cards.get_child(i) as Button
		if b == null:
			continue
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE  # بلا نقر قبل الكشف
		btns.append(b)
		_start_reel_spin(b)
	if btns.is_empty():
		_reel_spinning = false
		return
	var pool := UpgradeManager.all_upgrades()
	for i in btns.size():
		_scramble_card(btns[i] as Button, pool)
	var elapsed := 0.0
	var locked: Array = []
	locked.resize(btns.size())
	locked.fill(false)
	while true:
		var all_done := true
		var locked_now := false
		for i in btns.size():
			if locked[i]:
				continue
			all_done = false
			if elapsed >= float(REEL_STOPS[mini(i, REEL_STOPS.size() - 1)]):
				_lock_card(btns[i] as Button, options[i], i)
				locked[i] = true
				locked_now = true
		if all_done:
			break
		await get_tree().create_timer(REEL_TICK, true, false, true).timeout
		if gen != _reel_gen or not is_inside_tree():
			return  # شاشة جديدة تولّدت — هذه البكرة ألغيت (الجديد يدير اللوحة)
		elapsed += REEL_TICK
		if not locked_now:
			AudioManager.play_sfx("reel_tick", -12.0, 0.25)
		cards.position.x = _cards_base_x + randf_range(-2.5, 2.5)  # اهتزاز خفيف يشبه الماكينة
		for i in btns.size():
			if not locked[i]:
				var b := btns[i] as Button
				_scramble_card(b, pool)
				_step_reel(b)
	cards.position.x = _cards_base_x
	_reel_tweens.clear()
	_reel_rot.clear()
	_reel_bases.clear()
	_reel_spinning = false
	hint.text = HINT_FINAL


## تجهيز بطاقة للدوران: حفظ المواضع الأصلية + بدء دوران الأيقونة المستمر حول مركزها
func _start_reel_spin(b: Button) -> void:
	var bas: Array = []
	for part_name in REEL_PARTS:
		var n := b.get_node_or_null(part_name) as Control
		bas.append(n.position.y if n != null else 0.0)
	_reel_bases[b] = bas
	var icon_r := b.get_node_or_null("IconFrame/Icon") as TextureRect
	if icon_r != null:
		icon_r.rotation = 0.0
		icon_r.pivot_offset = Vector2(26, 26)  # مركز الأيقونة52×52 داخل الإطار64
		var rt := _ui_tween(icon_r).set_loops()
		rt.tween_property(icon_r, "rotation", TAU, 0.5).set_trans(Tween.TRANS_LINEAR)
		_reel_rot[b] = rt


## خطوة بكرة واحدة: انزلاق رأسي للمحتوى من فوق إلى وضعه الطبيعي — يتزامن مع تبديل الرمز
## (القفزة للأعلى تختفي خلف تبديل الرمز الجديد = وهم شريط يمرّ)
func _step_reel(b: Button) -> void:
	var bas = _reel_bases.get(b) as Array
	if bas == null:
		return
	var old = _reel_tweens.get(b)
	if old != null:
		(old as Tween).kill()
	var tw := _ui_tween(b)
	var started := false
	for j in REEL_PARTS.size():
		var n := b.get_node_or_null(REEL_PARTS[j]) as Control
		if n == null:
			continue
		var base := float(bas[j])
		n.position.y = base - REEL_DROP  # نقطة الانطلاق: المحتوى قادمًا من الأعلى
		if started:
			tw.parallel().tween_property(n, "position:y", base, REEL_TICK).set_trans(Tween.TRANS_LINEAR)
		else:
			tw.tween_property(n, "position:y", base, REEL_TICK).set_trans(Tween.TRANS_LINEAR)
			started = true
	if started:
		_reel_tweens[b] = tw


## خلط محتوى بطاقة واحدة بترقية عشوائية (سلك البكرة)
func _scramble_card(b: Button, pool: Array) -> void:
	if b == null or pool.is_empty():
		return
	var ru: UpgradeResource = pool[randi() % pool.size()]
	var name_l := b.get_node_or_null("NameLabel") as Label
	if name_l != null:
		name_l.text = ru.display_name
	var desc_l := b.get_node_or_null("DescLabel") as Label
	if desc_l != null:
		desc_l.text = ru.description
	_fill_icon(b.get_node_or_null("IconFrame/Icon") as TextureRect, ru)


## قفل بطاقة: إيقاف الدوران + بيانات الترقية الحقيقية + استقرار المحتوى + ومضة + صوت صاعد التوتر
func _lock_card(b: Button, u: UpgradeResource, i: int) -> void:
	if b == null:
		return
	var oldtw = _reel_tweens.get(b)
	if oldtw != null:
		(oldtw as Tween).kill()
		_reel_tweens.erase(b)
	var rottw = _reel_rot.get(b)
	if rottw != null:
		(rottw as Tween).kill()
		_reel_rot.erase(b)
	var bas = _reel_bases.get(b) as Array
	var icon_r := b.get_node_or_null("IconFrame/Icon") as TextureRect
	if icon_r != null:
		icon_r.rotation = 0.0  # الأيقونة تستقر قائمة
	if bas != null:
		for j in REEL_PARTS.size():
			var np := b.get_node_or_null(REEL_PARTS[j]) as Control
			if np != null:
				np.position.y = float(bas[j])
	var name_l := b.get_node_or_null("NameLabel") as Label
	if name_l != null:
		name_l.text = u.display_name
	var desc_l := b.get_node_or_null("DescLabel") as Label
	if desc_l != null:
		desc_l.text = u.description
	_fill_icon(icon_r, u)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	AudioManager.play_sfx("reel_lock", -2.0, 0.0, 0.92 + 0.09 * float(i))  # توتر صاعد 0.92→1.10
	# استقرار: الاسم والأيقونة ينزلان14px بارتداد BACK — إحساس «الطابعة انطبقت في مكانها»
	if bas != null:
		var nn := b.get_node_or_null("NameLabel") as Control
		var nif := b.get_node_or_null("IconFrame") as Control
		if nif != null:
			nif.position.y = float(bas[0]) - 14.0
		if nn != null:
			nn.position.y = float(bas[1]) - 14.0
		var tws := _ui_tween(b)
		if nif != null:
			tws.tween_property(nif, "position:y", float(bas[0]), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if nn != null:
			tws.parallel().tween_property(nn, "position:y", float(bas[1]), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.modulate = Color(1.8, 1.8, 1.8)  # ومضة ساطعة تعود خلال 0.3ث
	var tw := _ui_tween(b)
	tw.tween_property(b, "modulate", Color(1, 1, 1), 0.3)
	var tw2 := _ui_tween(b)
	tw2.tween_property(b, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(b, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)


func _on_pick(id: String) -> void:
	if _reel_spinning or _picking:
		return  # بكرات الحظ لم تتوقف بعد، أو لحظة البطلة جارية
	_picking = true
	# استعادة سرعة الوقت
	TimeFX.reset()
	UpgradeManager.apply_upgrade(id)
	AudioManager.play_sfx("upgrade_pick", -1.0, 0.02)  # صوت اختيار الترقية
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p != null:
		FxLibrary.spawn_levelup_burst(p.global_position)  # LevelUpEffect
		var vis := p.get_node_or_null("UpgradeVisuals")  # نبضة بلون ندرة الترقية حول اللاعب
		if vis != null and vis.has_method("play_pick"):
			vis.play_pick(UpgradeManager.rarity_of(id))
	var picked := _find_card(id)
	if picked == null:  # لا توجد بطاقة مطابقة — نكتفي بالسلوك القديم
		visible = false
		_picking = false
		TimeFX.reset()  # ضمان سرعة طبيعية
		get_tree().paused = false  # استئناف اللعب
		if _wm != null:
			_wm.call("begin_rest")
		return
	_hero_anim(picked)


func _find_card(id: String) -> Button:
	for c in cards.get_children():
		if c is Button and str(c.get_meta("_pick_id", "")) == id:
			return c as Button
	return null


## لحظة البطاقة البطلة: تتحرر من الحاوية، تكبر إلى وسط الشاشة، ونار ذهبية تشتعل حولها
func _hero_anim(picked: Button) -> void:
	for t in _self_tweens:  # حارس: لا تكدّس لحظتي بطولتين إن تداخلتا
		if t != null and is_instance_valid(t):
			(t as Tween).kill()
	_self_tweens.clear()
	var nl := picked.get_node_or_null("NameLabel") as Label
	hint.text = "Upgrade applied: " + (nl.text if nl != null else "")

	# بقية البطاقات: تخفت وتنزلق للأسفل معًا
	for c in cards.get_children():
		if c == picked:
			continue
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t_out := _ui_tween(self).set_parallel(true)
		_self_tweens.append(t_out)
		t_out.tween_property(c, "modulate:a", 0.0, 0.22)
		t_out.tween_property(c, "position:y", c.position.y + 30.0, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# نحرر البطاقة من الحاوية حتى لا يعيدها التخطيط إلى مكانها
	var gpos := picked.global_position
	var gsz := picked.size
	if gsz.x < 1.0 or gsz.y < 1.0:
		gsz = picked.custom_minimum_size
	cards.remove_child(picked)
	add_child(picked)
	picked.anchor_left = 0.0
	picked.anchor_top = 0.0
	picked.anchor_right = 0.0
	picked.anchor_bottom = 0.0
	picked.size = gsz
	picked.global_position = gpos
	picked.scale = Vector2.ONE
	picked.pivot_offset = gsz * 0.5  # التكبير يدور حول مركز البطاقة
	picked.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picked.set_meta("_fire_lock", true)
	picked.set_meta("_fire", 3)  # نُبقي الإطار ظاهرًا دائمًا

	# اللهب الذهبي: مادة خاصة على الإطار نفسه بدل الأزرق
	var gold := _fire_material_gold(gsz)
	var fx := picked.get_node_or_null("FireFrame") as ColorRect
	if fx != null and gold != null:
		fx.material = gold
		fx.visible = true
		_hero_gold = gold
		gold.set_shader_parameter("alpha_geral", 0.3)
		var twf := _ui_tween(self)
		_self_tweens.append(twf)
		twf.tween_method(_hero_gold_ramp, 0.0, 1.0, HERO_T_UP + 0.25)

	# الوجهة: مركز الشاشة قليلًا فوق المنتصف
	var target := Vector2(size.x * HERO_POS.x, size.y * HERO_POS.y)
	var delta := target - (picked.position + picked.pivot_offset)

	# الصعود: قفزة مرنية مع ميلان خفيف
	var tw := _ui_tween(self)
	_self_tweens.append(tw)
	tw.set_parallel(true)
	tw.tween_property(picked, "scale", Vector2(HERO_SCALE, HERO_SCALE), HERO_T_UP) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(picked, "position", picked.position + delta, HERO_T_UP) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(picked, "rotation_degrees", -2.0, HERO_T_UP * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# الهدوء ثم التوقف ثم التلاشي
	tw.set_parallel(false)
	tw.tween_property(picked, "rotation_degrees", 0.0, HERO_T_SETTLE) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(HERO_T_HOLD)
	tw.tween_property(self, "modulate:a", 0.0, HERO_T_FADE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_hero_end)


## اشتعال تدريجي للنار الذهبية أثناء صعود البطاقة
func _hero_gold_ramp(t: float) -> void:
	if _hero_gold != null:
		_hero_gold.set_shader_parameter("alpha_geral", lerpf(0.3, 1.35, t))
		_hero_gold.set_shader_parameter("forca_fogo", lerpf(1.2, 2.6, t))


## نهاية اللحظة: تنظيف ثم الراحة ثم الموجة التالية
func _hero_end() -> void:
	if _hero_gold != null:  # نعيد المادة الذهبية جاهزةً لاختيار قادم
		_hero_gold.set_shader_parameter("alpha_geral", 1.35)
		_hero_gold.set_shader_parameter("forca_fogo", 2.6)
		_hero_gold = null
	for c in get_children():  # البطاقة البطلة صارت ابناً مباشرًا لنا
		if c is Button:
			c.queue_free()
	visible = false
	modulate.a = 1.0  # شاشة جديدة تظهر تامة الصفاء
	_picking = false
	TimeFX.reset()  # ضمان عودة سرعة اللعبة الطبيعية بعد الاختيار
	get_tree().paused = false  # استئناف اللعب بعد الاختيار
	if _wm != null:
		_wm.call("begin_rest")


## مادة الشادر الناري لحجم بطاقة معيّن (مشتركة بين كل البطاقات بنفس الحجم)
func _fire_material(card_size: Vector2) -> ShaderMaterial:
	if _fire_mats.has(card_size):
		return _fire_mats[card_size] as ShaderMaterial
	if not FileAccess.file_exists(FIRE_SHADER):
		return null
	var sh := load(FIRE_SHADER) as Shader
	if sh == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = sh
	for k in FIRE_PARAMS:
		m.set_shader_parameter(k, FIRE_PARAMS[k])
	var noises := _fire_noise_textures()
	m.set_shader_parameter("noise_tex", noises[0])
	m.set_shader_parameter("noise_tex2", noises[1])
	m.set_shader_parameter("formato_custom_tex", _fire_border_texture(card_size))
	_fire_mats[card_size] = m
	return m


## مادة اللهب الذهبي: FIRE_PARAMS مدموجة بـ FIRE_GOLD — منفصلة عن الأزرق
func _fire_material_gold(card_size: Vector2) -> ShaderMaterial:
	if _fire_gold.has(card_size):
		return _fire_gold[card_size] as ShaderMaterial
	var base := _fire_material(card_size)
	if base == null:
		return null
	var g := ShaderMaterial.new()
	g.shader = base.shader
	for k in FIRE_PARAMS:
		g.set_shader_parameter(k, FIRE_PARAMS[k])
	for k in FIRE_GOLD:
		g.set_shader_parameter(k, FIRE_GOLD[k])
	var noises := _fire_noise_textures()
	g.set_shader_parameter("noise_tex", noises[0])
	g.set_shader_parameter("noise_tex2", noises[1])
	g.set_shader_parameter("formato_custom_tex", _fire_border_texture(card_size))
	_fire_gold[card_size] = g
	return g


## ضجيج قابل للتكرار (بلا حواف مرئية عند التمرير) — قناة R للنار وRG للتشوّه
func _fire_noise_textures() -> Array:
	if not _fire_noises.is_empty():
		return _fire_noises
	var noise_size := 128
	var a := _tile_field(noise_size, 8, 3, 11)
	var b := _tile_field(noise_size, 8, 3, 77)
	var c := _tile_field(noise_size, 8, 3, 913)
	var d1 := PackedByteArray()
	var d2 := PackedByteArray()
	d1.resize(noise_size * noise_size * 4)
	d2.resize(noise_size * noise_size * 4)
	for i in noise_size * noise_size:
		var ra := int(a[i] * 255.0)
		var ga := int(b[i] * 255.0)
		var rc := int(c[i] * 255.0)
		d1[i * 4] = ra
		d1[i * 4 + 1] = ga
		d1[i * 4 + 2] = ra
		d1[i * 4 + 3] = 255
		d2[i * 4] = rc
		d2[i * 4 + 1] = rc
		d2[i * 4 + 2] = rc
		d2[i * 4 + 3] = 255
	var t1 := ImageTexture.create_from_image(Image.create_from_data(noise_size, noise_size, false, Image.FORMAT_RGBA8, d1))
	var t2 := ImageTexture.create_from_image(Image.create_from_data(noise_size, noise_size, false, Image.FORMAT_RGBA8, d2))
	_fire_noises = [t1, t2]
	return _fire_noises


## حلبة الحدود: صورة شفافة توهج فيها شريط يتبع شكل البطاقة المستديرة من خارجها
func _fire_border_texture(card_size: Vector2) -> ImageTexture:
	if _fire_border.has(card_size):
		return _fire_border[card_size] as ImageTexture
	var w := int(card_size.x + FIRE_MARGIN * 2.0)
	var h := int(card_size.y + FIRE_MARGIN * 2.0)
	var data := PackedByteArray()
	data.resize(w * h * 4)
	var origin := Vector2(FIRE_MARGIN, FIRE_MARGIN)
	var inv_h := 1.0 / card_size.y
	for y in h:
		# اللهب يصعد: أقوى عند أعلى البطاقة وأضعف عند أسفلها
		var rise := 0.55 + 0.45 * (1.0 - clampf((float(y) - FIRE_MARGIN) * inv_h, 0.0, 1.0))
		for x in w:
			var d := _sd_round_rect(float(x), float(y), card_size.x, card_size.y, FIRE_CORNER, origin)
			# لسان اللهب: ضجيج رأسيّ الشكل (يتغيّر سريعًا أفقيًا وبطء رأسيًا) => قوادم واقفة
			var n := _vnoise1(float(x) * 0.09, float(y) * 0.035, 5) * 0.6 \
				+ _vnoise1(float(x) * 0.21, float(y) * 0.08, 613) * 0.4
			var tongue := smoothstep(0.30, 0.85, n) * rise
			# أساس رفيع عند الحافة + لسان يمتد للخارج — أطول عند الأعلى حيث تصعد النار
			var outer := (1.6 + 1.8 * rise) + 4.6 * tongue * rise
			var a := smoothstep(-1.5, 0.0, d) * (1.0 - smoothstep(outer - 2.0, outer, d))
			var i := (y * w + x) * 4
			data[i] = 255
			data[i + 1] = 255
			data[i + 2] = 255
			data[i + 3] = int(clampf(a, 0.0, 1.0) * 255.0)
	var tex := ImageTexture.create_from_image(
		Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data))
	_fire_border[card_size] = tex
	return tex


## المسافة إلى حدود مستطيل مستدير الأركان (سالبة للداخل، موجبة للخارج)
static func _sd_round_rect(px: float, py: float, w: float, h: float, r: float, origin: Vector2) -> float:
	var qx := absf(px - (origin.x + w * 0.5)) - (w * 0.5 - r)
	var qy := absf(py - (origin.y + h * 0.5)) - (h * 0.5 - r)
	var ax := maxf(qx, 0.0)
	var ay := maxf(qy, 0.0)
	return sqrt(ax * ax + ay * ay) + minf(maxf(qx, qy), 0.0) - r


## نويز قيمة دوري متعدد الأوكتاف — يكرّر بلا خطوط عند التمرير (شادر ي sample بـrepeat)
static func _tile_field(field_size: int, cells: int, octaves: int, seed_v: int) -> PackedFloat32Array:
	var acc := PackedFloat32Array()
	acc.resize(field_size * field_size)
	var amp := 1.0
	var total := 0.0
	var c := cells
	for o in octaves:
		var grid := _value_grid(c, seed_v + o * 1013)
		var cell_scale := float(c) / float(field_size)
		for y in field_size:
			var fy := float(y) * cell_scale
			var y0 := int(fy) % c
			var y1 := (y0 + 1) % c
			var ty := _quintic(fy - floorf(fy))
			var row0 := y0 * c
			var row1 := y1 * c
			for x in field_size:
				var fx := float(x) * cell_scale
				var x0 := int(fx) % c
				var x1 := (x0 + 1) % c
				var tx := _quintic(fx - floorf(fx))
				var v0 := lerpf(grid[row0 + x0], grid[row0 + x1], tx)
				var v1 := lerpf(grid[row1 + x0], grid[row1 + x1], tx)
				acc[y * field_size + x] += lerpf(v0, v1, ty) * amp
		total += amp
		amp *= 0.5
		c *= 2
	var inv := 1.0 / total
	for i in acc.size():
		acc[i] = clampf(acc[i] * inv, 0.0, 1.0)
	return acc


static func _value_grid(c: int, seed_v: int) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(c * c)
	for y in c:
		for x in c:
			g[y * c + x] = _hash01(x, y, seed_v)
	return g


static func _hash01(x: int, y: int, s: int) -> float:
	var h := (x * 374761393 + y * 668265263 + s * 1274126177) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


static func _quintic(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


## ضجيج قيمة متجانس (بلا حواف) — للسان اللهب
static func _vnoise1(fx: float, fy: float, seed_v: int) -> float:
	var x0 := int(floorf(fx))
	var y0 := int(floorf(fy))
	var tx := _quintic(fx - float(x0))
	var ty := _quintic(fy - float(y0))
	var v00 := _hash01(x0, y0, seed_v)
	var v10 := _hash01(x0 + 1, y0, seed_v)
	var v01 := _hash01(x0, y0 + 1, seed_v)
	var v11 := _hash01(x0 + 1, y0 + 1, seed_v)
	return lerpf(lerpf(v00, v10, tx), lerpf(v01, v11, tx), ty)
