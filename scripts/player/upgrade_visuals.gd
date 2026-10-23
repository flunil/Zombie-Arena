extends Node3D
class_name UpgradeVisuals
## مؤثرات بصرية حية أثناء اللعب لتأثيرات الترقيات:
## فقاعة الدرع حول اللاعب + هالة الغاضب + وميض الشفاء + نبضة لون الندرة عند الاختيار + وميض الانبعاث

const BUBBLE_R := 0.95  # نصف قطر فقاعة الدرع (تغطي اللاعب كاملًا)
const BERS_R := 1.12
const BUBBLE_C := Color(0.35, 0.75, 1.0, 1.0)
const BERS_C := Color(1.0, 0.25, 0.12, 1.0)

var _health: HealthComponent = null
var _bubble: MeshInstance3D = null
var _bers: MeshInstance3D = null
var _bubble_mat: StandardMaterial3D = null
var _bers_mat: StandardMaterial3D = null
var _t := 0.0
var _flash := 0.0  # وميض عند تغيّر الدرع (مكسب/امتصاص)
var _last_shield := 0.0
var _last_heal_fx := -10.0  # منع تكرار وميض الشفاء سريعًا


func _ready() -> void:
	var p := get_parent()
	if p != null:
		_health = p.get_node_or_null("Health") as HealthComponent
	_bubble = _make_sphere(BUBBLE_R, BUBBLE_C)
	_bers = _make_sphere(BERS_R, BERS_C)
	_bers.visible = false
	if _health != null:
		_last_shield = _health.shield
		if not _health.healed.is_connected(_on_healed):
			_health.healed.connect(_on_healed)


func _make_sphere(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, 0.0)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.6
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, 1.0, 0.0)
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	if _health == null or _bubble == null:
		return
	_t += delta
	var s := _health.shield
	if s > _last_shield + 0.01:
		_flash = minf(1.0, _flash + 0.7)   # مكسب درع (كمية/دفعة) → وميض زائد
	elif s < _last_shield - 0.01:
		_flash = minf(1.0, _flash + 0.35)  # درع يمتص ضررًا → رجفة
	_last_shield = s
	_flash = maxf(0.0, _flash - delta * 2.5)

	# فقاعة الدرع: مرئية فقط ما دام الدرع > 0 — الشفافية تتناسب مع المقدار + نبض حي
	var on := s > 0.0
	_bubble.visible = on
	if on and _bubble_mat != null:
		var base_a := 0.14 + 0.30 * clampf(s / 40.0, 0.0, 1.0)
		var a := clampf(base_a + 0.45 * _flash, 0.0, 0.9)
		_bubble_mat.albedo_color = Color(BUBBLE_C.r, BUBBLE_C.g, BUBBLE_C.b, a)
		_bubble.scale = Vector3.ONE * (1.0 + 0.03 * sin(_t * 6.0))

	# هالة الغاضب (Berserker): تحت 50% صحة — تزداد حمرة كلما قلّت الصحة
	var hp_pct := 1.0
	if _health.max_health > 0.0:
		hp_pct = clampf(_health.health / _health.max_health, 0.0, 1.0)
	var want_bers := UpgradeManager.has("berserker") and hp_pct < 0.5 and not _health.is_dead()
	_bers.visible = want_bers
	if want_bers and _bers_mat != null:
		var a2 := clampf((0.5 - hp_pct) * 0.8 + 0.05 * sin(_t * 9.0), 0.0, 0.55)
		_bers_mat.albedo_color = Color(BERS_C.r, BERS_C.g, BERS_C.b, a2)
		_bers.scale = Vector3.ONE * (1.0 + 0.04 * sin(_t * 7.0))


## أي شفاء (علاج ذاتي/موجة/سرقة حياة) → وميض أخضر خفيف — بحد أدنى 0.2ث بين الومضات
func _on_healed(_amount: float, _new_health: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_heal_fx < 0.2:
		return
	_last_heal_fx = now
	FxLibrary._spawn(FxLibrary._flash_sphere(
		global_position + Vector3.UP * 1.0, 0.55, Color(0.35, 1.0, 0.5), 0.4))


## نبضة بلون الندرة عند اختيار الترقية من الشاشة
func play_pick(rarity: int) -> void:
	var col := UpgradeManager.rarity_color(rarity)
	FxLibrary._spawn(FxLibrary._flash_sphere(
		global_position + Vector3.UP * 1.1, 0.7, col, 0.5))
	FxLibrary._spawn(FxLibrary._burst(
		global_position + Vector3.UP * 1.2, col, 26, 4.5, 0.5, 0.11,
		Vector3.UP, 40.0, Vector3(0, -6, 0)))


## انبعاث Revive: وميض أبيض-أزرق قوي + انبثاق
func play_revive() -> void:
	FxLibrary._spawn(FxLibrary._flash_sphere(
		global_position + Vector3.UP * 1.0, 1.0, Color(0.7, 0.9, 1.0), 0.6))
	FxLibrary._spawn(FxLibrary._burst(
		global_position + Vector3.UP * 1.0, Color(0.5, 0.85, 1.0), 40, 6.0, 0.7, 0.14,
		Vector3.UP, 70.0, Vector3(0, 2.0, 0)))
