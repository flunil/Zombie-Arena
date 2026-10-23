extends Node
class_name ObjectPool
## تجميع الكائنات (Object Pool) — منع queue_free على الزومبي والرصاص

var _scene: PackedScene = null
var _parent: Node = null
var _free: Array[Node] = []
var _created: int = 0


func setup(scene: PackedScene, parent: Node, prewarm: int = 0) -> void:
	_scene = scene
	_parent = parent
	for i in range(prewarm):
		_free.append(_make())


func _make() -> Node:
	var n: Node = _scene.instantiate()
	_parent.add_child(n)
	n.visible = false
	n.set_process(false)  # توفير: لا _process للمخزّن (revive يعيد set_process(true))
	n.set_physics_process(false)
	if n is CollisionObject3D:
		n.collision_layer = 0  # مخفي = خارج كل التصادمات (وإلا سدّ الأصل الاستعلامات)
	_created += 1
	return n


func get_instance() -> Node:
	var n: Node
	if _free.size() > 0:
		n = _free.pop_back()
	else:
		n = _make()
	return n


func return_instance(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	n.visible = false
	n.set_process(false)
	n.set_physics_process(false)
	if n is CollisionObject3D:
		n.collision_layer = 0  # خارج التصادمات أثناء تخزينه (revive يعيدها)
	_free.append(n)


func available() -> int:
	return _free.size()


func total_created() -> int:
	return _created
