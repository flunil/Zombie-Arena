extends "res://scripts/enemies/zombie_base.gd"
## زومبي زعيم: يستدعي 3 زومبي كل 5 ثوان — يستمع WaveManager لإشارة summon_requested

signal summon_requested(count: int)

const SUMMON_INTERVAL: float = 5.0
const SUMMON_COUNT: int = 3

var _summon_timer: float = SUMMON_INTERVAL


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _dead:
		return
	_summon_timer -= delta
	if _summon_timer <= 0.0:
		_summon_timer = SUMMON_INTERVAL
		summon_requested.emit(SUMMON_COUNT)


func revive(spawn_pos: Vector3) -> void:
	super.revive(spawn_pos)
	_summon_timer = SUMMON_INTERVAL
