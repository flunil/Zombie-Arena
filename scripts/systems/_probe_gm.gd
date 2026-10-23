extends Node
## اختبار: هل يتعرّف المحرر على class_name GM؟


func probe() -> int:
	return int(GM.state)
