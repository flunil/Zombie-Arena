extends StaticBody3D
## هدف وهمي لاختبار الرماية — يختفي فور استقبال الضرر


func take_damage(_amount: float, _from_direction: Vector3 = Vector3.ZERO) -> void:
	queue_free()
