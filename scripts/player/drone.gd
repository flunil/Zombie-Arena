extends Node3D
## روبوت مساعد: يتبع اللاعب ويطلق على أقرب عدو كل 0.6 ثانية

const FOLLOW_HEIGHT: float = 1.7
const FOLLOW_SIDE: float = 1.3
const FIRE_INTERVAL: float = 0.6
const ATTACK_RANGE: float = 14.0
const DAMAGE: float = 15.0
const BULLET_SPEED: float = 40.0

var _player: Node3D = null
var _fire_timer: float = 0.4
var _mesh: MeshInstance3D = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_build_visual()


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var target: Vector3 = _player.global_position + Vector3(FOLLOW_SIDE, FOLLOW_HEIGHT, 0.0)
	global_position = global_position.lerp(target, minf(1.0, delta * 4.0))
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = FIRE_INTERVAL
		_try_shoot()


func _try_shoot() -> void:
	var enemy := _nearest_enemy()
	if enemy == null:
		return
	# اعتراض: استهدف موضع الزومبي المستقبلي (سرعة منخفضة للطائرة)
	var aim: Vector3 = enemy.global_position
	if enemy is CharacterBody3D:
		var zv: Vector3 = (enemy as CharacterBody3D).velocity
		zv.y = 0.0
		var t := global_position.distance_to(aim) / BULLET_SPEED
		aim += zv * 0.85 * t
	var dir := (aim - global_position).normalized()
	var b: Node3D = load("res://scenes/weapons/Bullet.tscn").instantiate()
	b.damage = DAMAGE * UpgradeManager.get_drone_dmg_mult()  # DroneMaster: +50% ضرر
	b.speed = BULLET_SPEED
	b.direction = dir
	b.life = ATTACK_RANGE / BULLET_SPEED
	b.pierce = 0
	b.bullet_color = Color(0.3, 0.95, 0.9)
	get_tree().current_scene.add_child(b)
	b.global_position = global_position


## أقرب زومبي مرئي حيّ ضمن المدى
func _nearest_enemy() -> Node3D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	var best: Node3D = null
	var best_d: float = ATTACK_RANGE
	for c in tree.current_scene.get_children():
		if c is Node3D and c.has_meta("pool_type") and c.visible and c.has_method("take_damage"):
			if c.get("_dead") == true:
				continue
			var d: float = global_position.distance_to(c.global_position)
			if d < best_d:
				best_d = d
				best = c
	return best


## كرة مضيئة بسيطة كشكل للروبوت
func _build_visual() -> void:
	_mesh = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	_mesh.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 0.85)
	mat.emission_energy_multiplier = 2.0
	_mesh.material_override = mat
	add_child(_mesh)
