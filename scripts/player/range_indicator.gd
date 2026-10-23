@tool
extends "res://addons/constructive_telegraphs/src/con_telegraph_instance_3d.gd"
## حلقة المدى تحت اللاعب (constructive telegraphs) — نصف قطرها يتبع max_range للسلاح
## شريط حلقة رفيع فقط (donut)؛ يحمر عندما يدخل زومبي ضمن دائرة المدى

## عرض شريط الحلقة — الفرق بين radius و min_radius
const RING_OUTLINE := 0.35

## مستقبل الحلقة: طائرة شفافة فوق طرق المدينة تحمل مادة next_pass
## (الأرض وحدها تحملها — الطريق يغطي الحلقة ويخفيها)
## الحجم ديناميكي: يساوي مدى السلاح + هامش — بدل 40×40 ثابتة (تقليل ~4 أضعاف لمساحة الشادر)
const RECEIVER_SIZE := 40.0
const RECEIVER_MARGIN := 2.0
const NEXT_PASS_MAT := "res://addons/constructive_telegraphs/resources/con_telegraph_next_pass.tres"

## سرعة دوران الشقوق أثناء التنبيه (راديان/ثانية) — دورة كاملة ≈ 10 ثوانٍ
const ALERT_SPIN_SPEED := 0.6

## إزاحة مركز الحلقة — بلا إزاحة: مركزها أقدام اللاعب
@export var screen_center_offset: Vector3 = Vector3.ZERO

## ألوان الخاملة: أخضر فاتح #A5FF99 (مطابق لـ weapon_range_family.tres) — معزَّة لتُرى على الأرضية السوداء
const IDLE_BASE := Color(0.647059, 1.0, 0.6, 0.2)
const IDLE_OUTLINE := Color(0.647059, 1.0, 0.6, 1.0)
const IDLE_FILL := Color(0.647059, 1.0, 0.6, 0.32)
const IDLE_HIGHLIGHT := Color(0.78, 1.0, 0.72, 0.5)

## ألوان التنبيه: أحمر عند دخول زومبي ضمن دائرة المدى
const ALERT_BASE := Color(1.0, 0.3, 0.25, 0.2)
const ALERT_OUTLINE := Color(1.0, 0.22, 0.18, 1.0)
const ALERT_FILL := Color(1.0, 0.3, 0.25, 0.38)
const ALERT_HIGHLIGHT := Color(1.0, 0.45, 0.4, 0.55)

## هل يوجد زومبي داخل دائرة المدى الآن؟
var _alert: bool = false

## نصف قطر دائرة التنبيه — يتبع max_range للسلاح (يساوي نصف قطر الحلقة)
var _alert_radius: float = 10.0

## مرجع مستقبل الحلقة لتصفية حجمه مع تغيّر مدى السلاح
var _receiver_plane: PlaneMesh = null

@onready var _area: Node3D = get_node_or_null("Area")


func _ready() -> void:
	super._ready()  # انضمام مجموعة telegraph — شرط للعرض في المحرر واللعبة
	_ensure_ring_receiver()
	if _area != null:
		_area.position = screen_center_offset  # نصف القطر يُضبط لاحقًا في _update_range
	if Engine.is_editor_hint():
		return  # المحرر: حلقة ثابتة فقط (الأسلحة لا تُبنى في المحرر)
	# نسخة مستقلة للمورد: لا نلوّث الـ .tres المشترك داخل جلسة المحرر
	if family != null:
		family = family.duplicate() as ConTelegraphFamily
	_apply_colors(false)
	var wm := _weapon_manager()
	if wm != null and wm.has_signal("weapon_changed"):
		wm.weapon_changed.connect(_on_weapon_changed)
	_update_range()  # الأسلحة تُبنى مؤجلًا — يعاد الاستدعاء عند weapon_changed
	call_deferred("_update_range")


func _on_weapon_changed(_index: int, _weapon_id: String, _display_name: String) -> void:
	_update_range()


func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	# أخفِ الحلقة خارج القتال (القائمة/التأمل/الترقية) → area_count=0 → شادر الأرض يخرج مبكرًا ويوفر ~8-10ms
	visible = GM.is_playing()
	if visible:
		_update_alert()
		if _alert:
			# دوران خفيف للشقوق أثناء التنبيه — الحلقة دائرية فلا يتغير شكلها
			rotate_y(ALERT_SPIN_SPEED * delta)
	elif _alert:
		_alert = false
		_apply_colors(false)


## تبديل اللون عند دخول زومبي ضمن دائرة المدى أو خروجه
func _update_alert() -> void:
	var inside := _is_enemy_inside()
	if inside == _alert:
		return
	_alert = inside
	_apply_colors(inside)


## هل يوجد زومبي حي ضمن دائرة المدى (البعد الأفقي ≤ max_range)؟
func _is_enemy_inside() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var host := get_parent() as Node3D
	if host == null:
		return false
	var center := host.global_position
	var radius := _alert_radius
	var radius_sq := radius * radius
	for e in tree.get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n == null or not n.visible:
			continue
		if e.get("_dead") == true:
			continue
		var d: Vector3 = n.global_position - center
		d.y = 0.0  # القياس أفقي فقط على مستوى الأرض
		if d.length_squared() <= radius_sq:
			return true
	return false


## كتابة الألوان على العائلة — يقرأها con_telegraph_writer كل إطار فيتحدث الشادر فورًا
func _apply_colors(alert: bool) -> void:
	if family == null:
		return
	if alert:
		family.base_color = ALERT_BASE
		family.base_outline_color = ALERT_OUTLINE
		family.fill_color = ALERT_FILL
		family.fill_highlight_color = ALERT_HIGHLIGHT
	else:
		family.base_color = IDLE_BASE
		family.base_outline_color = IDLE_OUTLINE
		family.fill_color = IDLE_FILL
		family.fill_highlight_color = IDLE_HIGHLIGHT


## ينشئ طائرة شفافة (لا عمق، بلا رسم) كطفل تحت الحلقة — تخدم كسطح لرسم next_pass
## فتظهر الحلقة فوق الطرق والمباني بدل إخفائها تحتها
func _ensure_ring_receiver() -> void:
	if get_node_or_null("RingReceiver") != null:
		return
	var mi := MeshInstance3D.new()
	mi.name = "RingReceiver"
	var plane := PlaneMesh.new()
	plane.size = Vector2(RECEIVER_SIZE, RECEIVER_SIZE)
	_receiver_plane = plane
	mi.mesh = plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var base := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode blend_mix, depth_draw_never, cull_disabled, unshaded;\nvoid fragment() {\n\tALBEDO = vec3(0.0);\n\tALPHA = 0.0;\n}"
	base.shader = sh
	base.next_pass = load(NEXT_PASS_MAT)
	mi.material_override = base
	add_child(mi)


## عقدة WeaponManager تحت اللاعب نفسه
func _weapon_manager() -> Node:
	var p := get_parent()
	if p == null:
		return null
	return p.get_node_or_null("WeaponManager")


func _update_range() -> void:
	var wm := _weapon_manager()
	if wm == null:
		return
	var w: Node = wm.get_current()
	if w == null:
		return
	var data = w.get("weapon_data")
	if data != null:
		var r := float(data.max_range)
		_alert_radius = r  # طول دائرة التنبيه = المدى نفسه
		if _receiver_plane != null:
			# مستقبل الحلقة بالحجم اللازم فقط: مساحة أصغر = بكسلات أقل على شادر next_pass
			var s := 2.0 * (r + RECEIVER_MARGIN)
			_receiver_plane.size = Vector2(s, s)
		if _area != null:
			_area.radius = r  # الحلقة بحجم مدى السلاح
			_area.min_radius = maxf(r - RING_OUTLINE, 0.0)
