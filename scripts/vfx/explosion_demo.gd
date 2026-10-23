extends Node3D
## معاينة الانفجار: يعيد تثبيت نسخة جديدة كل 3 ثوانٍ ويفجّرها
## (explode() تحذف العقدة بعد 2 ثانية كما في الدرس).

const VFX := preload("res://scenes/vfx/ExplosionVFX.tscn")

var _current: Node3D


func _ready() -> void:
	_spawn()


func _spawn() -> void:
	if is_instance_valid(_current):
		_current.queue_free()
	_current = VFX.instantiate()
	add_child(_current)
	_current.explode()
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(_spawn)
