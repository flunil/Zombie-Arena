extends CanvasLayer
class_name SceneTransition
## انتقال سلس بين المشاهد — الاستخدام: SceneTransition.goto("res://scenes/main/Arena.tscn")

const FADE_TIME: float = 0.3


static func goto(path: String) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var overlay: CanvasLayer = _overlay()
	overlay.visible = true
	var rect: ColorRect = overlay.get_child(0) as ColorRect
	rect.color = Color(0, 0, 0, 0)
	var tw: Tween = overlay.create_tween()
	tw.tween_property(rect, "color:a", 1.0, FADE_TIME)
	tw.tween_callback(func() -> void:
		var old := tree.current_scene
		if old != null:
			_release_geometry(old)  # تنظيف إشارات المواد قبل تفكيك المشهد
		tree.change_scene_to_file(path)
	)
	tw.tween_interval(0.1)
	tw.tween_property(rect, "color:a", 0.0, FADE_TIME)
	tw.tween_callback(func() -> void:
		overlay.visible = false
	)


## إعادة تشغيل المشهد الحالي (زر "العب مرة أخرى")
static func reload_current() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	goto(tree.current_scene.scene_file_path)


static func _overlay() -> CanvasLayer:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Node = tree.root
	var n: CanvasLayer = root.get_node_or_null("SceneTransition") as CanvasLayer
	if n == null:
		n = CanvasLayer.new()
		n.name = "SceneTransition"
		n.layer = 100
		var rect: ColorRect = ColorRect.new()
		rect.color = Color(0, 0, 0, 0)
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.add_child(rect)
		root.add_child(n)
	return n


## إزالة كل إشارات المواد من عقد الرسم قبل تحرير المشهد — يمنع قراءة المحرك
## لـRID مُحرَّر أثناء التفكيك (أخطاء material-null عند «العب مرة أخرى»)
static func _release_geometry(n: Node) -> void:
	for c in n.get_children():
		_release_geometry(c)
		if c is GeometryInstance3D:
			var gi := c as GeometryInstance3D
			gi.material_override = null
			gi.visible = false
			if c is MeshInstance3D:
				(c as MeshInstance3D).mesh = null
