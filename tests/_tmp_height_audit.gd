extends Node
## تدقيق ارتفاعات المجسمات الثابتة في Arena (قبل توحيد الارتفاع)

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := (load("res://scenes/main/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	for i in 6:
		await get_tree().process_frame
	var ground: Node = arena.get_node_or_null("Ground/Mesh")
	if ground is MeshInstance3D:
		var gmi := ground as MeshInstance3D
		var gab := gmi.global_transform * (gmi.get_aabb())
		print("AUDIT ground pos=", gmi.global_position, " aabb_min_y=", gab.position.y, " aabb_max_y=", gab.end.y)
	var ys := {}
	var bases := {}
	var samples := []
	var n := 0
	for c in _all_props(arena):
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		n += 1
		var y := snappedf(mi.global_position.y, 0.01)
		ys[y] = int(ys.get(y, 0)) + 1
		var gab := mi.global_transform * mi.get_aabb()
		var by := snappedf(gab.position.y, 0.01)
		bases[by] = int(bases.get(by, 0)) + 1
		if samples.size() < 12:
			samples.append("%s pos_y=%s base_y=%s top_y=%s" % [
				mi.get_path(), y, by, snappedf(gab.end.y, 0.01)])
	print("AUDIT props=", n, " unique_node_y=", ys.size(), " unique_base_y=", bases.size())
	print("AUDIT node_y hist: ", ys)
	print("AUDIT base_y hist: ", bases)
	for s in samples:
		print("AUDIT sample ", s)
	# تجميع حسب الأب المباشر (باستثناء الزومبي المجمّد: Skeleton/HealthBar/Zombie/@CharacterBody)
	var by_parent := {}
	var real_bases := {}
	for c in _all_props(arena):
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		var p := str(mi.get_parent().name)
		if p.contains("Skeleton") or p.contains("HealthBar") or p.contains("Zombie") or p.contains("CharacterBody"):
			continue
		by_parent[p] = int(by_parent.get(p, 0)) + 1
		var gab2: AABB = mi.global_transform * mi.get_aabb()
		var by := snappedf(gab2.position.y, 0.001)
		real_bases[by] = int(real_bases.get(by, 0)) + 1
	print("AUDIT by_parent: ", by_parent)
	print("AUDIT real_bases (props only): ", real_bases)
	get_tree().quit(0)


func _all_props(node: Node) -> Array:
	var out := []
	for c in node.get_children():
		if c.name == &"Player":
			continue
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_all_props(c))
	return out
