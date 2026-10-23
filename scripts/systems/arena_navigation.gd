extends NavigationRegion3D
## يبني شبكة الملاحة للساحة عند التشغيل
## يقرأ كل StaticBody في المشهد (الأرض/الجدران/مباني المدينة/الديكور) عبر جذر المشهد
## التنفيذ مؤجَّل (call_deferred) حتى تكتمل عناصر City/Decor بعد _ready


func _ready() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.cell_size = 0.5
	nav_mesh.agent_height = 1.75
	nav_mesh.agent_radius = 0.5
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 0xFFFFFFFF
	navigation_mesh = nav_mesh
	call_deferred("_bake")


func _bake() -> void:
	var nav_mesh := navigation_mesh
	if nav_mesh == null:
		return
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, src, get_parent())
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, src)
	navigation_mesh = nav_mesh  # إعادة التعيين تُزجج المصفوفة الجديدة إلى الخادم
	print("[NAV] arena navigation baked polys=", nav_mesh.polygons.size())
