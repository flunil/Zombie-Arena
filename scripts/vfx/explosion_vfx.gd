extends Node3D
## VFX انفجار بثلاث أنظمة جسيمات فقط: Debris + Fire + Smoke.
## يطابق درس LegionGames حرفياً: "Easy Explosion Effect - Godot 3D VFX Tutorial"
## (youtu.be/RtJJVjjM_-Q, Godot 4.2) - بلا shaders وبلا textures.

@onready var debris: GPUParticles3D = $Debris
@onready var fire: GPUParticles3D = $Fire
@onready var smoke: GPUParticles3D = $Smoke
@onready var audio: AudioStreamPlayer3D = $Audio


func explode() -> void:
	## تشغيل الانفجار مرة واحدة ثم حذف العقدة بعد ثانيتين (كما في الدرس).
	debris.emitting = true
	fire.emitting = true
	smoke.emitting = true
	if audio.stream != null:
		audio.play()
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(queue_free)
