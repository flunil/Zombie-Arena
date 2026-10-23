extends Node3D
class_name ZombieBatchManager
## دفعات الرسوم: MultiMeshInstance3D واحد لكل نوع زومبي (رسم واحد بدل عشرات)
## القريب من اللاعب يبقى مفردًا متحركًا، والبعيد يُسجَّل هنا بتحويله فقط

static var instance: ZombieBatchManager = null

const START_CAP: int = 32
const BATCH_META: String = "batch_key"
const VIEW_MARGIN: float = 1.5  # هامش حول حدود الكاميرا حتى لا تومض الأشخاص عند حافة الشاشة

var _batches: Dictionary = {}
static var _fallback_mat: StandardMaterial3D = null  # مادة بيضاء مشتركة لأسطح FBX بلا مادة


func _ready() -> void:
	name = "ZombieBatches"
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


## تسجيل زومبي في دفعته — يعيد false لو تعذّر إيجاد شبكة (يبقى مفردًا)
func acquire(z: Node3D) -> bool:
	var key: String = str(z.get_meta("pool_type", "basic"))
	if z.has_meta(BATCH_META):
		var b0: Variant = _batches.get(str(z.get_meta(BATCH_META)))
		if b0 != null and (b0 as Dictionary).get("mmi") != null \
				and ((b0 as Dictionary)["active"] as Array).find(z) >= 0:
			return true
		z.remove_meta(BATCH_META)  # سجل قديم غير صالح (دافعيات)
	var b: Dictionary = _batches.get(key, {})
	if b.is_empty():
		b = _build_batch(z)
		_batches[key] = b  # يُخزَّن فارغًا أيضًا (فشل ← لا إعادة بناء كل نبضة)
	if b.is_empty() or b.get("mmi") == null:
		return false
	var cap: int = int(b["cap"])
	var arr: Array = b["active"]
	if arr.size() >= cap:
		cap *= 2
		(b["mmi"] as MultiMeshInstance3D).multimesh.instance_count = cap  # يُعاد كتابة كل التحويلات كل إطار
		b["cap"] = cap
	arr.append(z)
	z.set_meta(BATCH_META, key)
	return true


func release(z: Node3D) -> void:
	if not z.has_meta(BATCH_META):
		return
	var b: Variant = _batches.get(str(z.get_meta(BATCH_META)))
	z.remove_meta(BATCH_META)
	if b == null:
		return
	var arr: Array = (b as Dictionary)["active"]
	var idx: int = arr.find(z)
	if idx >= 0:
		arr.remove_at(idx)


## بناء الدفعة من أول زومبي للنوع: الشبكة + مادة معزولة عن وميض الأفراد
func _build_batch(z: Node3D) -> Dictionary:
	var mesh: Mesh = null
	var mat: Material = null
	var vis: Variant = z.get("_visual")
	if vis != null:
		mesh = _merge_visual_mesh(z)  # نموذج مفصّل (FBX) ← دمج ساكن بلا عظام
	else:
		var body := z.get_node_or_null("BodyMesh") as MeshInstance3D
		if body != null and body.mesh != null:
			mesh = body.mesh
			if body.material_override is Material:
				mat = (body.material_override as Material).duplicate()
	if mesh == null:
		return {}
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh  # الشبكة على المورد نفسه (لا خاصية mesh على العقدة)
	mm.instance_count = START_CAP
	mmi.multimesh = mm
	if mat != null:
		mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON  # ظل واحد لكل الدفعة
	add_child(mmi)
	return {"mmi": mmi, "active": [], "cap": START_CAP}


## دمج مجسّمات النموذج (جسم + عينان...) في ArrayMesh واحد ثابت (بلا عظام = بلا تهشير)
func _merge_visual_mesh(z: Node3D) -> Mesh:
	var vis: Variant = z.get("_visual")
	if vis == null:
		return null
	var base: Transform3D = z.global_transform
	var am := ArrayMesh.new()
	var found: bool = false
	for n in (vis as Node3D).find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		# تطوير transform العقدة داخل الرؤوس: سلسلة FBX تحمل مقياس الوحدة (×100) ويُفقدها النسخ الخام
		# (النسبة إلى جذر الزومبي ثابتة ← دمج واحد يكفي مهما دار الجذر لاحقًا)
		var xform: Transform3D = base.affine_inverse() * mi.global_transform
		var nrm_xf: Basis = xform.basis.inverse().transposed()
		var src: Mesh = mi.mesh
		for s in src.get_surface_count():
			var arrays: Array = src.surface_get_arrays(s)
			arrays[Mesh.ARRAY_BONES] = null  # إسقاط العظام: وضع مجمَّد بلا هيكل عظمي
			arrays[Mesh.ARRAY_WEIGHTS] = null
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vi in range(verts.size()):
				verts[vi] = xform * verts[vi]
			arrays[Mesh.ARRAY_VERTEX] = verts
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var nrms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for vi in range(nrms.size()):
					nrms[vi] = (nrm_xf * nrms[vi]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = nrms
			if arrays[Mesh.ARRAY_TANGENT] != null:
				var tans: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
				for vi in range(tans.size() >> 2):
					var tv := Vector3(tans[vi * 4], tans[vi * 4 + 1], tans[vi * 4 + 2])
					tv = xform.basis * tv
					tans[vi * 4] = tv.x
					tans[vi * 4 + 1] = tv.y
					tans[vi * 4 + 2] = tv.z
				arrays[Mesh.ARRAY_TANGENT] = tans
			# surface_get_primitive_type غير متاح على المجسّمات الإجرائية (QuadMesh) ← مثلثات
			var prim: int = Mesh.PRIMITIVE_TRIANGLES
			if src is ArrayMesh:
				prim = (src as ArrayMesh).surface_get_primitive_type(s)
			am.add_surface_from_arrays(prim, arrays)
			var surface_mat: Material = mi.get_active_material(s)
			if surface_mat == null:
				# أسطح FBX بلا مادة تُطلق أخطاء material-null كل إطار (casts_shadows/is_animated...)
				if _fallback_mat == null:
					_fallback_mat = StandardMaterial3D.new()
					_fallback_mat.albedo_color = Color(0.55, 0.6, 0.5)
				surface_mat = _fallback_mat
			am.surface_set_material(am.get_surface_count() - 1, surface_mat)
		found = true
	return am if found else null


func _process(_delta: float) -> void:
	# حدود الكاميرا (فرستم): داخلها يُرسم الزومبي، وخارجها يختفي من كل التمريرات (لون + ظل)
	var cam: Camera3D = get_viewport().get_camera_3d()
	var planes: Array[Plane] = []
	if cam != null:
		planes = cam.get_frustum()
	var inside_positive: bool = true
	if planes.size() > 0:
		# لافتة الاتجاه من أبعد مستوٍ عن مركز الكاميرا (بعد الكاميرا): داخلي = سالب (المستويات تشير للخارج)
		var best_d := 0.0
		var best_abs := -1.0
		for p in planes:
			var pd := p.distance_to(cam.global_position)
			if absf(pd) > best_abs:
				best_abs = absf(pd)
				best_d = pd
		inside_positive = best_d >= 0.0
	for key in _batches:
		var b: Dictionary = _batches[key]
		if b.get("mmi") == null:
			continue
		var mmi: MultiMeshInstance3D = b["mmi"]
		var arr: Array = b["active"]
		var count: int = 0
		for i in range(arr.size() - 1, -1, -1):
			var z: Variant = arr[i]
			if z == null or not is_instance_valid(z) or not (z as Node3D).visible:
				arr.remove_at(i)
				continue
			if not _in_view((z as Node3D).global_position, planes, inside_positive):
				continue  # خارج الكاميرا: يبقى في الدفعة لكن لا يُكتب تحويله
			mmi.multimesh.set_instance_transform(count, (z as Node3D).global_transform)
			count += 1
		mmi.multimesh.visible_instance_count = count
		mmi.visible = count > 0


## هل النقطة داخل فرستم الكاميرا (+هامش)؟ بلا كاميرا (headless/قائمة) ← true دائمًا
static func _in_view(pos: Vector3, planes: Array[Plane], inside_positive: bool) -> bool:
	if planes.is_empty():
		return true
	for p in planes:
		var d: float = p.distance_to(pos)
		if inside_positive:
			if d < -VIEW_MARGIN:
				return false
		elif d > VIEW_MARGIN:
			return false
	return true
