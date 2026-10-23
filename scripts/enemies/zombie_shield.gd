extends "res://scripts/enemies/zombie_base.gd"
## زومبي درع: الدرع الأمامي يصد الرصاص القادم من الأمام فقط (الجوانب والخلف والانفجارات تمر)


func take_damage(amount: float, from_direction: Vector3 = Vector3.ZERO) -> void:
	if from_direction.length_squared() > 0.001 and _player != null and is_instance_valid(_player):
		var facing: Vector3 = _player.global_position - global_position
		facing.y = 0.0
		if facing.length_squared() > 0.001:
			facing = facing.normalized()
			# الرصاص المتجه عكس اتجاه الزومبي = يصيب الوجه الأمامي → يصد
			if from_direction.normalized().dot(facing) < -0.5:
				return
	super.take_damage(amount, from_direction)
