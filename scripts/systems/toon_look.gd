extends WorldEnvironment
## مظهر كرتوني للمشهد: تلوين مشبع + حدّ تباين + توهّج خفيف على المُنصِّات
## + تحويل مواد البيئة الثابتة إلى cel مع حبر outline + إسقاط ظلالها
## + توحيد كل المجسمات على أساس y=0.
## يُرفَّق على عقدة WorldEnvironment في Arena.tscn (عبر MCP script_attach).
## كل قيم الإضاءة/التدرّج/التوهّج مكشوفة في Inspector وتُطبَّق فورًا عند التغيير.

@export_group("Lighting")
@export_range(0.0, 3.0, 0.01) var sun_energy := 1.42:
	set(v):
		sun_energy = v
		_apply_lights(get_parent())
@export var sun_color := Color(1.0, 0.93, 0.78):
	set(v):
		sun_color = v
		_apply_lights(get_parent())
@export_range(0.0, 2.0, 0.01) var fill_energy := 0.42:
	set(v):
		fill_energy = v
		_apply_lights(get_parent())
@export var fill_color := Color(1.0, 0.91, 0.80):
	set(v):
		fill_color = v
		_apply_lights(get_parent())
@export_range(0.0, 3.0, 0.01) var ambient_energy := 1.08:
	set(v):
		ambient_energy = v
		_apply_env()
@export var ambient_color := Color(0.78, 0.74, 0.66):
	set(v):
		ambient_color = v
		_apply_env()
@export var fog_color := Color(0.84, 0.78, 0.66):
	set(v):
		fog_color = v
		_apply_env()

@export_group("Screen Tone")
@export_range(0.5, 1.5, 0.01) var saturation := 1.18:
	set(v):
		saturation = v
		_apply_env()
@export_range(0.5, 1.5, 0.01) var contrast := 1.08:
	set(v):
		contrast = v
		_apply_env()
@export_range(0.0, 2.0, 0.01) var glow_intensity := 0.4:
	set(v):
		glow_intensity = v
		_apply_env()


func _ready() -> void:
	_apply_env()
	_apply_to_arena.call_deferred()


## انتظار إطارين: الديكور (أرصفة/نباتات/أعمدة) يُضاف مؤجّلًا بعد _ready
## فلا يُطبَّق التوحيد/الحبر/الظلال قبل اكتماله
func _apply_to_arena() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_convert_arena()


func _apply_env() -> void:
	var env := environment
	if env == null:
		return
	env.adjustment_enabled = true
	## 1.18/1.08 حدود أمان: saturation 1.25+ كان يقصق الأحمر للأصفر تاريخيًا (step 79)
	env.adjustment_saturation = saturation
	env.adjustment_contrast = contrast
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = glow_intensity
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	## حشو صباحي دافئ بلون كريمي فاتح (ambient كان SKY ثم كريمي داكن)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	env.fog_light_color = fog_color


## إضاءة كرتونية صباحية: شمس ذهبية + حشو كريمي دافئ — القيم من Inspector
func _apply_lights(arena: Node) -> void:
	if arena == null:
		return
	var sun := arena.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = sun_color
		sun.light_energy = sun_energy
	var fill := arena.get_node_or_null("Fill") as DirectionalLight3D
	if fill != null:
		fill.light_color = fill_color
		fill.light_energy = fill_energy


## لوحة موحّدة للأرض (دافئة — أفلام كرتون نهارية): طريق دافئ/رصيف رملي/عشب أخضر مائل للأصفر
const ASPHALT := Color(0.33, 0.31, 0.29)
const SIDEWALK := Color(0.58, 0.56, 0.52)
const GRASS := Color(0.38, 0.66, 0.28)
const CURB := Color(0.92, 0.90, 0.86)
const GROUND_FILL := Color(0.50, 0.47, 0.43)

## لوحة المباني (دافئة): طوب/تان/خرسانة دافئة + رمادي محايد دافئ للوحات
const B_BRICK := Color(0.75, 0.28, 0.22)
const B_TAN := Color(0.72, 0.52, 0.36)
const B_SLATE := Color(0.50, 0.48, 0.45)
const B_TEAL := Color(0.34, 0.54, 0.48)
const B_ROOF := Color(0.38, 0.35, 0.31)
const B_CONCRETE := Color(0.72, 0.70, 0.66)
const B_DARK := Color(0.16, 0.14, 0.12)
const B_WHITE := Color(0.94, 0.92, 0.87)


func _convert_arena() -> void:
	var arena := get_parent()
	if arena == null:
		return
	_apply_lights(arena)
	var n := CelMaterial.apply_tree(arena)
	var flat := _flatten_props(arena)
	var stripped := _strip_flat_outlines(arena)
	var recolored := _unify_flat_palette(arena)
	var brecolored := _unify_building_palette(arena)
	var off := _disable_prop_shadows(arena)
	var sobel := _disable_sobel(arena)
	print("ToonLook: converted ", n, " materials; flattened ", flat,
		" nodes to y=0; stripped ", stripped, " outlines; recolored ", recolored,
		" ground tiles + ", brecolored, " building mats; shadows OFF on ", off,
		" prop meshes; sobel quad OFF=", sobel)


## إسقاط مربّع sobel الشاشي تحت الكاميرا: يقرأ عمق الشاشة ويرسم حبرًا حيث
## توجد خطوات عمق — على الأرض المسطّحة تظهر خطوط تموضع (أقواس/درزات رفيعة).
## الحدّ المقلوب للـcel (next_pass هندسي) يكفي تمامًا للحبر الكرتوني.
func _disable_sobel(arena: Node) -> int:
	var q := arena.get_node_or_null("Player/Camera3D/OutlineQuad") as MeshInstance3D
	if q != null and q.visible:
		q.visible = false
		return 1
	return 0


## توحيد ألوان البلاطات المسطّحة: طريق/رصيف/عشب/حواف — تُصنَّف حسب لون المادة
func _unify_flat_palette(arena: Node) -> int:
	var props: Array = []
	_collect_props(arena, props)
	var n := 0
	for mi in props:
		var m := mi as MeshInstance3D
		var gab: AABB = m.global_transform * m.get_aabb()
		if gab.size.y > 0.6:
			continue
		for s in m.get_surface_override_material_count():
			var mat := m.get_active_material(s)
			if not (mat is ShaderMaterial):
				continue
			var c := CelMaterial.color_of(mat)
			var nc := _categorize(c)
			if nc != c:
				CelMaterial.set_color(mat, nc)
				n += 1
	# أرضية الحشو تحت البلاطات: نفس عائلة الرصيف لاختفاء الفراغات الداكنة
	var gm := arena.get_node_or_null("Ground/Mesh") as MeshInstance3D
	if gm != null:
		var gmat := gm.get_active_material(0)
		if gmat is ShaderMaterial:
			(gmat as ShaderMaterial).set_shader_parameter("color", GROUND_FILL)
			n += 1
	return n


func _categorize(c: Color) -> Color:
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	var sat := mx - mn
	if mx > 0.78 and sat < 0.14:
		return CURB  # خطوط الطريق والحواف البيضاء
	if c.g > c.r * 1.22 and c.g > c.b * 1.22 and sat > 0.1:
		return GRASS
	if sat < 0.2:
		return ASPHALT if mx < 0.30 else SIDEWALK
	return c  # ألوان مميزة (طوب/لافتات) تبقى كما هي


## توحيد ألوان المباني: ألوان الواجهات (طوب أحمر/تيل/تان) مخبّأة في ألوان
## رؤوس الشبكة (vertex colors) والمواد كلها مشتركة بنسيج رمادي — فالدفء
## يُطبَّق كمعامل عام على اللون الموحد. (الـtint لكل نسيج كان ي boosts الأخضر
## عالميًا ويجعل كل المباني زيتونية.)
const B_WARM_MUL := Color(1.04, 0.99, 0.90)


func _unify_building_palette(arena: Node) -> int:
	var props: Array = []
	_collect_props(arena, props)
	var n := 0
	for mi in props:
		var m := mi as MeshInstance3D
		var gab: AABB = m.global_transform * m.get_aabb()
		if gab.size.y <= 0.6:
			continue
		for s in m.get_surface_override_material_count():
			var mat := m.get_active_material(s)
			if mat is ShaderMaterial:
				var sm := mat as ShaderMaterial
				var tex := sm.get_shader_parameter("base_texture") as Texture2D
				var c := CelMaterial.color_of(sm)
				if tex != null:
					# مادة مشتركة بين كل المباني — تُضبط مرة واحدة فقط
					if c != B_WARM_MUL:
						sm.set_shader_parameter("color", B_WARM_MUL)
						n += 1
				else:
					var nc := _classify_building(c)
					if nc != c:
						sm.set_shader_parameter("color", nc)
						n += 1
			elif mat is BaseMaterial3D:
				var bm := mat as BaseMaterial3D
				var nc2 := _classify_building(bm.albedo_color)
				if nc2 != bm.albedo_color:
					bm.albedo_color = nc2
					if bm.emission_enabled:
						bm.emission = Color(nc2.r, nc2.g, nc2.b)
					n += 1
	return n


func _classify_building(c: Color) -> Color:
	var mx := maxf(c.r, maxf(c.g, c.b))
	var sat := mx - minf(c.r, minf(c.g, c.b))
	# نوافذ/عناصر شديدة العتمة
	if mx < 0.18:
		return B_DARK
	# إطارات/لافتات بيضاء
	if mx > 0.8 and sat < 0.14:
		return B_WHITE
	# طبيعة (أشجار/نباتات) — أخضر يفوق الأزرق بوضوح
	if c.g > c.r * 1.25 and c.g > c.b * 1.25:
		return c
	# رمادي: أسقف داكنة أو خرسانة فاتحة
	if sat < 0.18:
		return B_ROOF if mx < 0.62 else B_CONCRETE
	# تيل أخضر واضح فقط (أخضر يفوق الأزرق) — غير ذلك المائل للأزرق يصير رماديًا دافئًا
	if c.g > c.b and c.g > c.r * 1.25:
		return B_TEAL
	# أزرق مائل / رمادي مزرق → رمادي دافئ محايد (تحت ضوء دافئ لا يقرأ أزرقًا)
	if c.b >= c.r and c.b >= c.g * 0.92:
		return B_SLATE
	# أحمر قوي (طوب)
	if c.r > c.g * 1.45:
		return B_BRICK
	# بني/برتقالي دافئ
	return B_TAN


## بلاطات الأرض المسطّحة: حذف حدود الـcel حول كل بلاطة (تظهر كفواصل سوداء
## بين البلاطات المتجاورة وتبدو الخريطة مفكّكة). المباني/المجسمات الطويلة تبقى بحدودها.
func _strip_flat_outlines(arena: Node) -> int:
	var props: Array = []
	_collect_props(arena, props)
	var n := 0
	for mi in props:
		var m := mi as MeshInstance3D
		var gab: AABB = m.global_transform * m.get_aabb()
		if gab.size.y > 0.6:
			continue
		for s in m.get_surface_override_material_count():
			var mat := m.get_active_material(s)
			if mat is ShaderMaterial and (mat as ShaderMaterial).next_pass != null:
				(mat as ShaderMaterial).next_pass = null
				n += 1
	return n


## تجميع كل مجسمات البيئة الثابتة (باستثناء اللاعب وجموع fx/enemies)
func _collect_props(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c.name == &"Player" or c.is_in_group(&"fx") or c.is_in_group(&"enemies"):
			continue
		if c is MeshInstance3D:
			out.append(c)
		_collect_props(c, out)


## توحيد الارتفاع: كل قاعدة مجسم تلامس y=0 (الأرضية أولًا كاملةً mesh+تصادم)
func _flatten_props(arena: Node) -> int:
	var moved := 0
	var ground_body := arena.get_node_or_null("Ground") as Node3D
	var ground_mesh := arena.get_node_or_null("Ground/Mesh") as MeshInstance3D
	if ground_body != null and ground_mesh != null:
		var gab: AABB = ground_mesh.global_transform * ground_mesh.get_aabb()
		ground_body.global_position.y -= gab.position.y
		moved += 1
	var props: Array = []
	_collect_props(arena, props)
	print("ToonLook: collected prop meshes=", props.size())
	for mi in props:
		var m := mi as MeshInstance3D
		var gab: AABB = m.global_transform * m.get_aabb()
		var dy := -gab.position.y
		if absf(dy) > 0.0005:
			m.global_position.y += dy
			moved += 1
	return moved


## إسقاط ظلال المباني/الطرق الثابتة تمامًا (يبقى ظل اللاعب والأعداء)
func _disable_prop_shadows(arena: Node) -> int:
	var props: Array = []
	_collect_props(arena, props)
	var count := 0
	for mi in props:
		var m := mi as MeshInstance3D
		if m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			count += 1
	return count
