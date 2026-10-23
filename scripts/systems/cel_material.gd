class_name CelMaterial
extends RefCounted
## مساعد تحويل المواد العادية إلى مواد خلوية (cel) مع حواف outline
## مبني على eldskald/godot4-cel-shader — الاستخدام: convertible() ثم from_base()/apply_tree()
## وقراءة/كتابة اللون عبر color_of()/set_color() (للميض والإضاءة الذاتية والاختبارات)

const BASE_SHADER := "res://shaders/cel/cel-shader-base.gdshader"
const OUTLINE_MAT := "res://shaders/cel/outline.tres"

static var _shader: Shader = null
static var _outline: ShaderMaterial = null


## الشادر الأساسي (يُحمَّل مرة واحدة ويُشارَك بين كل المواد)
static func base_shader() -> Shader:
	if _shader == null:
		_shader = load(BASE_SHADER) as Shader
	return _shader


## مادة الحواف المشتركة (next_pass) — يُحمَّل مرة واحدة
static func outline_material() -> ShaderMaterial:
	if _outline == null:
		_outline = load(OUTLINE_MAT) as ShaderMaterial
	return _outline


## هل المادة قابلة للتحويل؟ (لا: غير مُضاء ذاتيًا/شفاف/إضاءة ذاتية حقيقية/بلا تظليل)
static func convertible(m: Material) -> bool:
	if not (m is BaseMaterial3D):
		return false
	var b := m as BaseMaterial3D
	if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return false
	if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	if b.emission_enabled and b.emission.r + b.emission.g + b.emission.b > 0.05:
		return false
	return true


## تحويل مادة أساسية إلى ShaderMaterial خلوية (لون + نسيج + حواف)
static func from_base(src: BaseMaterial3D) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = base_shader()
	sm.set_shader_parameter("color", src.albedo_color)
	if src.albedo_texture != null:
		sm.set_shader_parameter("base_texture", src.albedo_texture)
	sm.next_pass = outline_material()
	return sm


## مادة خلوية بلون واحد (للمواد الإجرائية: أسلحة/عناصر بلا نسيج)
static func from_color(c: Color) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = base_shader()
	sm.set_shader_parameter("color", c)
	sm.next_pass = outline_material()
	return sm


## قراءة لون المادة (خلوية أو أساسية) — للاختبارات والوميض
static func color_of(m: Material) -> Color:
	if m is ShaderMaterial:
		var v: Variant = (m as ShaderMaterial).get_shader_parameter("color")
		if v is Color:
			return v
		return Color.WHITE
	if m is BaseMaterial3D:
		return (m as BaseMaterial3D).albedo_color
	return Color.WHITE


## كتابة لون المادة (خلوية أو أساسية) — للميض والإضاءة الذاتية
static func set_color(m: Material, c: Color) -> void:
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("color", c)
	elif m is BaseMaterial3D:
		(m as BaseMaterial3D).albedo_color = c


## تحويل مواد مِفرَدة عبر surface overrides (يحافظ على تعدّد الأسطح)
static func apply_to_mesh(mi: MeshInstance3D) -> int:
	var n := 0
	for s in mi.get_surface_override_material_count():
		var act := mi.get_active_material(s)
		if convertible(act):
			mi.set_surface_override_material(s, from_base(act as BaseMaterial3D))
			n += 1
	return n


## تحويل كل MeshInstance3D تحت جذر معين (يتجاهل ما هو خلو/شفاف/مضيء)
static func apply_tree(root: Node) -> int:
	if root == null:
		return 0
	var n := 0
	if root is MeshInstance3D:
		n += apply_to_mesh(root as MeshInstance3D)
	for c in root.get_children():
		n += apply_tree(c)
	return n
