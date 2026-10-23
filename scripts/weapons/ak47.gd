extends Node3D
## سلاح AK-47: إطلاق تلقائي مستمر عند الضغط + إعادة تعبئة تلقائية عند النفاد

signal ammo_changed(current: int, max_ammo: int)

@export var weapon_data: WeaponResource
@export var bullet_scene: PackedScene

var _ammo: int = 0
var _cooldown: float = 0.0
var _reload_left: float = 0.0


func _ready() -> void:
	if weapon_data == null:
		weapon_data = WeaponResource.new()
	_ammo = weapon_data.ammo_max
	ammo_changed.emit(_ammo, weapon_data.ammo_max)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			_ammo = weapon_data.ammo_max
			ammo_changed.emit(_ammo, weapon_data.ammo_max)


func get_ammo() -> int:
	return _ammo


func is_reloading() -> bool:
	return _reload_left > 0.0


## محاولة إطلاق طلقة واحدة في اتجاه معيّن
func try_fire(direction: Vector3) -> void:
	if _reload_left > 0.0 or _cooldown > 0.001:
		return
	if _ammo <= 0:
		_start_reload()
		return
	_ammo -= 1
	_cooldown = 1.0 / maxf(0.01, weapon_data.fire_rate)
	_fire_bullet(direction)
	ammo_changed.emit(_ammo, weapon_data.ammo_max)
	if _ammo <= 0:
		_start_reload()


func _start_reload() -> void:
	if _reload_left > 0.0:
		return
	_reload_left = maxf(0.05, weapon_data.reload_time)


func _fire_bullet(direction: Vector3) -> void:
	if bullet_scene == null:
		return
	if direction.length() < 0.001:
		direction = Vector3(0, 0, -1)
	direction = direction.normalized()
	if weapon_data.spread > 0.0:
		direction = direction.rotated(Vector3.UP, randf_range(-weapon_data.spread, weapon_data.spread))
	var bullet: Area3D = bullet_scene.instantiate()
	bullet.damage = weapon_data.damage
	bullet.speed = weapon_data.bullet_speed
	bullet.direction = direction
	bullet.life = weapon_data.max_range / maxf(1.0, weapon_data.bullet_speed)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = get_parent().global_position  # من مركز اللاعب
