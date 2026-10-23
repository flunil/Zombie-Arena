extends Node
## لمرة واحدة: يطبّق تقنيات الفيديو (10x Godot perf) على Arena.tscn
## 1) LOD bias أقل (yبدّل للموديل الأقل تفصيلاً أبكر)
## 2) visibility_range_end (لا يرسم المباني البعيدة)
## 3) تعطيل ظل الشمس الحية (أكبر توفير GPU) — الاعتماد على ambient القوي 2.0
## 4) Occlusion culling (إخفاء المحجوب خلف المباني العالية) عبر BoxOccluder3D

const ARENA := "res://scenes/main/Arena.tscn"
## مسافة الظهور: ما دونها يبقى ظاهرًا (اللاعب داخل صالة ~130 وحدة) — ما بعدها يُكفّ
const VIS_END := 155.0
const LOD_BIAS := 0.5
## حد حجم AABB لتوليد محجّف: فقط المباني الكبيرة/العالية
const OCCLUDER_MIN_SIZE := 12.0


func _ready() -> void:
	var packed := load(ARENA) as PackedScene
	if packed == null:
		print("[VIDEO_OPT] FAIL load arena")
		get_tree().quit(1)
		return
	var arena := packed.instantiate() as Node3D

	# --- التقنية 3: تعطيل ظل الشمس الحية ---
	var sun := arena.get_node_or_null("Sun") as DirectionalLight3D
	var shadow_off := false
	if sun != null:
		sun.shadow_enabled = false
		shadow_off = true

	# --- التقنيتان 1+2 على كل MeshInstance3D (بلا roads/ground) + جمع مرشحي المحجّفات ---
	var occ_candidates := []  # [{pos, size}]
	_apply_to_meshes(arena, arena, occ_candidates)

	# --- التقنية 4: بناء OccluderInstance3D للمباني الكبيرة ---
	# إزالة عقدة Occluders القديمة (إن وُجدت) لتجنّب التكرار عند إعادة التشغيل
	var old := arena.get_node_or_null("Occluders")
	if old != null:
		arena.remove_child(old)
		old.free()
	var occ_root := Node3D.new()
	occ_root.name = "Occluders"
	arena.add_child(occ_root)
	occ_root.owner = arena
	var occ_count := 0
	for c in occ_candidates:
		var oi := OccluderInstance3D.new()
		var box := BoxOccluder3D.new()
		box.size = c["size"]
		oi.occluder = box
		oi.position = c["pos"]
		occ_root.add_child(oi)
		oi.owner = arena
		occ_count += 1

	# --- الحفظ ---
	var ps := PackedScene.new()
	var err := ps.pack(arena)
	if err == OK:
		err = ResourceSaver.save(ps, ARENA)
	print("[VIDEO_OPT] shadow_off=", shadow_off, " occluders=", occ_count, " save_err=", err)
	arena.free()
	get_tree().quit(0 if err == OK else 1)


## يمشي كل MeshInstance3D؛ يضبط lod_bias + visibility_range على غير الطرق/الأرض،
## ويجمع الأخذ بحساب AABB الكبير كمرشح محجّف.
func _apply_to_meshes(n: Node, arena: Node3D, occ: Array) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		# تخطي الطرق الأرضية وشبكة الأرض الأساسية (تبقى ظاهرة دائمًا)
		var is_ground := nm.begins_with("road") or nm == "Mesh" or nm == "Ground"
		if not is_ground:
			# التقنية 1: LOD bias أقل = تبديل أبكر للموديل الأقل
			mi.lod_bias = LOD_BIAS
			# التقنية 2: كتم الرسم لما بعد المسافة (لا يمسّ التصادم)
			mi.visibility_range_end = VIS_END
			mi.visibility_range_end_margin = 8.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			# التقنية 4 مرشح: AABB عالمي كبير = مبنى عالي محتمل الإخفاء
			var waabb := _world_aabb(mi)
			var sz := waabb.size
			if sz.x >= OCCLUDER_MIN_SIZE and sz.z >= OCCLUDER_MIN_SIZE and sz.y >= 8.0:
				occ.append({"pos": waabb.get_center(), "size": sz + Vector3(1, 1, 1)})
	for c in n.get_children():
		_apply_to_meshes(c, arena, occ)


## AABB بالحجم العالمي للمشبك (يلغي تأثير المقياس 100 في city parts)
## ملاحظة: لا نستخدم global_transform لأن arena خارج الشجرة (ينثني فقط) — نبني التحويل يدويًا.
func _world_aabb(mi: MeshInstance3D) -> AABB:
	var gt := _world_xform(mi)
	var laabb := mi.get_aabb()
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	for i in 8:
		var corner := gt * laabb.get_endpoint(i)
		min_v = Vector3(minf(min_v.x, corner.x), minf(min_v.y, corner.y), minf(min_v.z, corner.z))
		max_v = Vector3(maxf(max_v.x, corner.x), maxf(max_v.y, corner.y), maxf(max_v.z, corner.z))
	return AABB(min_v, max_v - min_v)


## تحويل عالمي محسوب من transform المحلي عبر آباء Node3D (يعمل خارج الشجرة)
func _world_xform(n: Node) -> Transform3D:
	var t: Transform3D
	if n is Node3D:
		t = (n as Node3D).transform
	else:
		t = Transform3D.IDENTITY
	var p := n.get_parent()
	while p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
