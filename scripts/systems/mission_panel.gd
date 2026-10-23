extends Control
## لوحة المهام اليومية — 3 مهام + شريط تقدم لكل

@onready var rows: VBoxContainer = $Center/VBox/Rows
@onready var gems_label: Label = $Center/VBox/GemsLabel
@onready var close_button: Button = $Center/VBox/CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close)
	_rebuild()


func _rebuild() -> void:
	MissionSystem.ensure_today()
	gems_label.text = "Gems: %d" % int(SaveSystem.data.get("gems", 0))
	for c in rows.get_children():
		c.queue_free()
	for m in MissionSystem.get_missions():
		rows.add_child(_make_row(m))


func _make_row(m: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 96)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.07)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 24)
	var target := float(int(m.get("target", 1)))
	var prog := float(int(m.get("progress", 0)))
	if bool(m.get("done", false)):
		title.text = "%s — Completed ✓ (+%d gem)" % [str(m.get("text", "")), int(m.get("gems", 0))]
		title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	else:
		title.text = str(m.get("text", ""))
	v.add_child(title)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(676, 26)
	bar.max_value = maxf(target, 1.0)
	bar.value = prog
	bar.show_percentage = true
	v.add_child(bar)

	panel.add_child(v)
	return panel


func _on_close() -> void:
	queue_free()
