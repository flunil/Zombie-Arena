extends Control
## الصندوق اليومي — 7 أيام، اليوم الحالي مُظلَّل، المكافآت معروفة مسبقاً

@onready var days_row: HBoxContainer = $Center/Dialog/VBox/Days
@onready var streak_label: Label = $Center/Dialog/VBox/StreakLabel
@onready var gems_label: Label = $Center/Dialog/VBox/GemsLabel
@onready var claim_button: Button = $Center/Dialog/VBox/ClaimButton
@onready var close_button: Button = $Center/Dialog/VBox/CloseButton
@onready var toast_label: Label = $ToastLabel


func _ready() -> void:
	toast_label.visible = false
	claim_button.pressed.connect(_on_claim)
	close_button.pressed.connect(_on_close)
	_rebuild()


func _rebuild() -> void:
	streak_label.text = "Login Streak: %d" % int(SaveSystem.data.get("login_streak", 0))
	gems_label.text = "Gems: %d" % int(SaveSystem.data.get("gems", 0))
	var current := int(SaveSystem.data["daily"].get("day_idx", 0)) % DailySystem.REWARDS_GEMS.size()
	for c in days_row.get_children():
		c.queue_free()
	for i in DailySystem.REWARDS_GEMS.size():
		days_row.add_child(_make_card(i, i == current))
	if DailySystem.can_claim():
		claim_button.text = "Claim Daily Reward"
		claim_button.disabled = false
	else:
		claim_button.text = "Claimed Today ✓"
		claim_button.disabled = true


## بطاقة يوم واحدة — مُظلَّلة ذهبي إن كان اليوم الحالي
func _make_card(day_idx: int, is_current: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(90, 112)  # 7×90+6×10=690 + هامش اللوحة 24 = 714 ≤720
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	if is_current:
		sb.bg_color = Color(1.0, 0.78, 0.25, 1)
		sb.set_border_width_all(2)
		sb.border_color = Color(1.0, 0.95, 0.7)
	else:
		sb.bg_color = Color(1, 1, 1, 0.08)
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var day_lbl := Label.new()
	day_lbl.text = "Day %d" % (day_idx + 1)
	day_lbl.add_theme_font_size_override("font_size", 18)
	day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_current:
		day_lbl.add_theme_color_override("font_color", Color(0.15, 0.1, 0.02))
	v.add_child(day_lbl)
	var gems_lbl := Label.new()
	gems_lbl.text = "◆ %d" % int(DailySystem.REWARDS_GEMS[day_idx])
	gems_lbl.add_theme_font_size_override("font_size", 22)
	gems_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_current:
		gems_lbl.add_theme_color_override("font_color", Color(0.15, 0.1, 0.02))
	v.add_child(gems_lbl)
	panel.add_child(v)
	return panel


func _on_claim() -> void:
	var gems := DailySystem.claim_reward()
	if gems > 0:
		_show_toast("You got %d gems ✓" % gems)
		_rebuild()
	else:
		_show_toast("Already claimed today")


func _on_close() -> void:
	queue_free()


func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	var t := get_tree().create_timer(1.4)
	t.timeout.connect(func() -> void: toast_label.visible = false)
