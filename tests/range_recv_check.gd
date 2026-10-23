extends Node
## اختبار: حلقة المدى تُشغّل _ready وتُنشئ RingReceiver بلا أخطاء


func _ready() -> void:
	var ri := load("res://scripts/player/range_indicator.gd").new() as Node3D
	add_child(ri)
	var recv := ri.get_node_or_null("RingReceiver")
	print("[RCV] receiver=", recv != null)
	if recv is MeshInstance3D:
		var mi := recv as MeshInstance3D
		var om := mi.material_override as ShaderMaterial
		print("[RCV] plane=", (mi.mesh as PlaneMesh).size,
				" next_pass=", om != null and om.next_pass != null)
	get_tree().quit(0 if recv != null else 1)
