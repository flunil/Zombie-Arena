extends Control
## القائمة الرئيسية — أزرار المشهد تُكتشف وتُوصل تلقائيًا:
## أضف/انسخ/احذف/رتّب/أعد تسم أي زر دون تعديل الكود — الربط من اسم الزر (XxxButton → xxx)
## أو من خاصية metadata "action" على الزر (مثال: "shop" أو "overlay:res://scenes/ui/X.tscn")
## زر بإجراء غير معروف → تنبيه على الشاشة بدل الكسر

const ARENA_PATH: String = "res://scenes/main/Arena.tscn"
const SHOP_PATH: String = "res://scenes/ui/MetaUpgradeShop.tscn"
const DAILY_PATH: String = "res://scenes/ui/DailyReward.tscn"
const MISSIONS_PATH: String = "res://scenes/ui/MissionPanel.tscn"

## المكافأة اليومية تظهر مرة واحدة عند تشغيل اللعبة (وليست عند كل عودة للقائمة)
static var _daily_popup_done: bool = false

@onready var toast_label: Label = get_node_or_null("ToastLabel")
var _toast_serial: int = 0


func _ready() -> void:
	AudioManager.play_music("menu")  # حلقة القوائم
	if toast_label != null:
		toast_label.visible = false
	_fill_topbar()
	_fill_upgrades()
	_wire_buttons()
	# نافذة منبثقة: الصندوق اليومي عند تشغيل اللعبة (لها زر إغلاق + حالة "استُلم اليوم")
	if not _daily_popup_done:
		_daily_popup_done = true
		_open_overlay(DAILY_PATH)


## ملء الشريط العلوي: الذهب + الجواهر + القتلى (بيانات حقيقية من الحفظ)
func _fill_topbar() -> void:
	var gold_label := find_child("GoldValue", true, false) as Label
	if gold_label != null:
		gold_label.text = str(SaveSystem.get_gold())
	var gem_label := find_child("GemValue", true, false) as Label
	if gem_label != null:
		gem_label.text = str(int(SaveSystem.data.get("gems", 0)))
	var kills_label := find_child("KillsValue", true, false) as Label
	if kills_label != null:
		var stats: Variant = SaveSystem.data.get("stats", {})
		kills_label.text = str(int((stats as Dictionary).get("total_kills", 0)))


## ملء بطاقة التطورات الدائمة في وسط الشاشة (4 مسارات من الحفظ)
func _fill_upgrades() -> void:
	var paths := ["health", "speed", "damage", "ammo"]
	var bars := ["BarHealth", "BarSpeed", "BarDamage", "BarAmmo"]
	var lvls := ["LvlHealth", "LvlSpeed", "LvlDamage", "LvlAmmo"]
	for i in paths.size():
		var lvl := SaveSystem.get_level(paths[i])
		var bar := find_child(bars[i], true, false) as Control
		if bar != null:
			# الشريط يُملأ من اليمين لليسار (عربي) عبر تضييق مرساة اليسار
			var fill := bar.get_node_or_null("Fill") as TextureRect
			if fill != null:
				fill.anchor_left = 1.0 - float(lvl) / float(SaveSystem.MAX_LEVEL)
		var lbl := find_child(lvls[i], true, false) as Label
		if lbl != null:
			lbl.text = "%d/%d" % [lvl, SaveSystem.MAX_LEVEL]


## اكتشاف كل أزرار المشهد (بما في الأزرار داخل حاويات متداخلة) ووصلها
func _wire_buttons() -> void:
	for n in find_children("*", "Button", true, false):
		var b := n as Button
		if b == null:
			continue
		# بعض الأزرار مكتوب عليها IGNORE في المشهد — نرجّعها قابلة للنقر
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		# أبناء الزر (الأيقونة والنص داخل حاوية) لا يحجبون النقر عنه
		for c in b.find_children("*", "Control", true, false):
			var cc := c as Control
			if cc != null:
				cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(_on_menu_button.bind(b, _action_for(b)))


## الإجراء: meta("action") إن وُجد، وإلا من اسم الزر (نهاية "Button" تُحذف وتصغر)
func _action_for(b: Button) -> String:
	if b.has_meta("action"):
		return str(b.get_meta("action"))
	var n := String(b.name)
	if n.ends_with("Button"):
		n = n.substr(0, n.length() - "Button".length())
	return n.to_lower()


## موجّه واحد لكل الأزرار — الإجراءات المعروفة + overlay:/scene: + تنبيه لغير المعروف
func _on_menu_button(b: Button, action: String) -> void:
	match action:
		"start":
			GM.reset_run()
			SceneTransition.goto(ARENA_PATH)
		"shop":
			SceneTransition.goto(SHOP_PATH)
		"daily", "dailyreward":
			_open_overlay(DAILY_PATH)
		"missions":
			_open_overlay(MISSIONS_PATH)
		"settings":
			_toast("Settings coming soon (Phase 13)")
		"soon":
			_toast("Coming soon — this feature is on the way")
		"quit":
			get_tree().quit()
		_:
			if action.begins_with("overlay:"):
				_open_overlay(action.trim_prefix("overlay:"))
			elif action.begins_with("scene:"):
				SceneTransition.goto(action.trim_prefix("scene:"))
			else:
				_toast("Unconnected button: %s — set meta action" % b.name)


func _open_overlay(path: String) -> void:
	var scene := load(path) as PackedScene
	if scene == null:
		return
	add_child(scene.instantiate())


func _toast(msg: String) -> void:
	if toast_label == null:
		return
	toast_label.text = msg
	toast_label.visible = true
	_toast_serial += 1
	get_tree().create_timer(2.2).timeout.connect(_hide_toast.bind(_toast_serial))


## إخفاء المؤقت — يتجاهل المؤقت القديم إن جاء توست أحدث
func _hide_toast(serial: int) -> void:
	if serial != _toast_serial:
		return
	if toast_label != null:
		toast_label.visible = false
