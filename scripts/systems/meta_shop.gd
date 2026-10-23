extends Control
## المتجر الدائم — 4 مسارات × 5 مستويات (الصفوف تُبنى برمجياً)

const PATHS: Array[Dictionary] = [
	{"id": "health", "name": "Health", "desc": "+20 max HP per level"},
	{"id": "speed", "name": "Speed", "desc": "+5% move speed per level"},
	{"id": "damage", "name": "Damage", "desc": "+10% bullet damage per level"},
	{"id": "ammo", "name": "Ammo", "desc": "+15% magazine size per level"},
]
const MENU_PATH: String = "res://scenes/ui/MainMenu.tscn"

@onready var rows: VBoxContainer = $Center/VBox/Rows
@onready var gold_label: Label = $Center/VBox/GoldLabel
@onready var toast_label: Label = $ToastLabel
@onready var back_button: Button = $Center/VBox/BackButton


func _ready() -> void:
	toast_label.visible = false
	back_button.pressed.connect(_on_back_pressed)
	_rebuild()


func _rebuild() -> void:
	for c in rows.get_children():
		c.queue_free()
	gold_label.text = "Gold: %d" % SaveSystem.get_gold()
	for p in PATHS:
		rows.add_child(_make_row(str(p["id"]), str(p["name"]), str(p["desc"])))


func _make_row(id: String, title: String, desc: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(700, 76)  # ≤720 عرض الشاشة العمودية
	row.add_theme_constant_override("separation", 16)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_label := Label.new()
	title_label.text = "%s — Level %d/%d" % [title, SaveSystem.get_level(id), SaveSystem.MAX_LEVEL]
	title_label.add_theme_font_size_override("font_size", 24)
	info.add_child(title_label)
	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.modulate = Color(1, 1, 1, 0.7)
	info.add_child(desc_label)
	row.add_child(info)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(200, 56)
	buy_button.add_theme_font_size_override("font_size", 22)
	var level := SaveSystem.get_level(id)
	if level >= SaveSystem.MAX_LEVEL:
		buy_button.text = "Maxed"
		buy_button.disabled = true
	else:
		buy_button.text = "Buy (%d)" % SaveSystem.get_cost(id)
		buy_button.pressed.connect(_on_buy.bind(id))
	row.add_child(buy_button)
	return row


func _on_buy(id: String) -> void:
	if SaveSystem.buy(id):
		_show_toast("Purchased ✓")
		_rebuild()
	else:
		_show_toast("Not enough gold")


func _on_back_pressed() -> void:
	SceneTransition.goto(MENU_PATH)


func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	var t := get_tree().create_timer(1.2)
	t.timeout.connect(func() -> void: toast_label.visible = false)
