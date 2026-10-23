extends Node
## أداة تحقق مرئي: تفتح الورشة، تلتقط صورة، وتخرج (للتطوير فقط)


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	var scene := load("res://scenes/ui/WeaponList.tscn") as PackedScene
	var wl := scene.instantiate()
	add_child(wl)
	# انتظار التقاط صور الأسلحة ثلاثية الأبعاد
	await get_tree().create_timer(6.0).timeout
	var img := get_viewport().get_texture().get_image()
	print("SHOT size=", img.get_width(), "x", img.get_height(), " empty=", img.is_empty())
	img.save_png("user://weapon_list_shot.png")
	img.save_png("C:/Users/admin/AppData/Local/Temp/opencode/weapon_list_shot2.png")
	get_tree().quit()
