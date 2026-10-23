extends Control
## ورشة تطوير الأسلحة — بنمط HTML: موارد + عرض سلاح + بطاقات ترقية + ترسانة
## مربوطة بالأنظمة الحقيقية: gold/gems من SaveSystem + 9 أسلحة من resources/weapons

const MENU_PATH: String = "res://scenes/ui/MainMenu.tscn"

## مسارات أصول المشروع
const ICON_GEM := "res://assets/ui/Icons/Gem.png"
const ICON_SHOP := "res://assets/ui/Icons/Shop.png"
const ICON_CHECK := "res://assets/ui/Icons/Check.png"
const ICON_LOCK := "res://assets/ui/20Free_WithOutline_Icons/LockBronze.png"
const ICON_PLAY := "res://assets/ui/20Free_WithOutline_Icons/PlayBlue.png"
const ICON_UP := "res://assets/ui/20Free_WithOutline_Icons/UpBlue.png"
const ICON_LIGHTNING := "res://assets/ui/20Free_WithOutline_Icons/LightningBlue.png"
const BTN_DEFAULT := "res://assets/ui/Icons/Buttons/Button_Long_Orange.png"
const BAR_YELLOW := "res://assets/ui/Vector_UI_Pack_dobo_ui/ProgressBars/progressBar_yellow.png"
const BAR_GREEN := "res://assets/ui/Vector_UI_Pack_dobo_ui/ProgressBars/progressBar_green.png"
const BAR_BASE := "res://assets/ui/Vector_UI_Pack_dobo_ui/ProgressBars/progressBarBase_black.png"
const ICON_ARROW := "res://assets/ui/Icons/Arrow_Left.png"
const THUMB_DIR := "user://weapon_thumbs/"

## أيقونات نصية لكل سلاح (بديلة عن صور HTML)
const EMOJI_MAP: Dictionary = {
	"ak47": "🔫", "shotgun": "💥", "heavymg": "🔥",
	"laserifle": "⚡", "flamethrower": "🔥", "grenadelauncher": "💣",
	"rocketlauncher": "🚀", "teslacoil": "⚡", "smokelauncher": "💨",
}

## ألوان اللعبة المتسقة (بنمط MetaShop / DailyReward / MissionPanel)
const COLOR_GOLD := Color(1.0, 0.78, 0.2)  # الذهبي الأساسي في اللعبة
const COLOR_GOLD_DARK := Color(0.85, 0.55, 0.1)
const COLOR_GREEN := Color(0.5, 1.0, 0.6)  # أخضر متوافق مع اللعبة
const COLOR_BLUE := Color(0.35, 0.75, 1.0)  # أزرق فاتح للأرقام
const COLOR_TEXT := Color(1, 1, 1, 0.95)
const COLOR_TEXT_DIM := Color(1, 1, 1, 0.6)
const COLOR_PANEL_BG := Color(1, 1, 1, 0.07)  # لوحات شفافة بنمط اللعبة
const COLOR_PANEL_BG_DARK := Color(0, 0, 0, 0.35)
const COLOR_BG := Color(0.08, 0.1, 0.15)  # خلفية داكنة متناسقة

@onready var gold_label: Label = $MainVBox/TopBar/TopHBox/Resources/GoldChip/GoldHBox/GoldValue
@onready var gem_label: Label = $MainVBox/TopBar/TopHBox/Resources/GemChip/GemHBox/GemValue
@onready var display_name: Label = $MainVBox/Body/PreviewArea/PreviewVBox/PreviewRow/InfoPanel/InfoVBox/WeaponNameRow/NameLabel
@onready var display_icon: Label = $MainVBox/Body/PreviewArea/PreviewVBox/PreviewRow/InfoPanel/InfoVBox/WeaponNameRow/WeaponIconSlot/WeaponIcon
@onready var display_level: Label = $MainVBox/Body/PreviewArea/PreviewVBox/PreviewRow/InfoPanel/InfoVBox/LevelBadge
@onready var display_bar: ProgressBar = $MainVBox/Body/PreviewArea/PreviewVBox/PreviewRow/InfoPanel/InfoVBox/BarOverlay/LevelBar
@onready var display_percent: Label = $MainVBox/Body/PreviewArea/PreviewVBox/PreviewRow/InfoPanel/InfoVBox/BarOverlay/PercentLabel
@onready var equip_button: Button = $MainVBox/Body/PreviewArea/PreviewVBox/EquipButton
@onready var weapon_holder: Node3D = $MainVBox/Body/PreviewArea/PreviewVBox/PreviewRow/ModelPreview/SubViewport/WeaponHolder
@onready var preview_cam: Camera3D = $MainVBox/Body/PreviewArea/PreviewVBox/PreviewRow/ModelPreview/SubViewport/Camera3D
@onready var stats_grid: GridContainer = $MainVBox/Body/StatsGrid
@onready var weapons_list: VBoxContainer = $MainVBox/ArsenalPanel/Scroll/Rows
@onready var arsenal_count: Label = $MainVBox/ArsenalCount
@onready var toast_label: Label = $ToastLabel
@onready var back_button: Button = $MainVBox/TopBar/TopHBox/BackButton

var _selected_id: String = ""
var _weapons: Array[WeaponResource] = []
var _preview_model: Node3D = null
var _preview_angle: float = 25.0
var _preview_time: float = 0.0
var _row_thumbs: Dictionary = {}
var _thumb_cache: Dictionary = {}
var _capturing: bool = false


func _ready() -> void:
	toast_label.visible = false
	back_button.pressed.connect(_on_back)
	equip_button.pressed.connect(_on_equip)
	_apply_base_styles()
	_load_weapons()
	_selected_id = SaveSystem.get_selected_weapon()
	if _selected_id == "":
		for w in _weapons:
			if w.weapon_id in SaveSystem.get_unlocked_weapons():
				_selected_id = w.weapon_id
				break
		if _selected_id == "" and _weapons.size() > 0:
			_selected_id = _weapons[0].weapon_id
	_rebuild()
	if DisplayServer.get_name() != "headless":
		_capture_thumbs_async()


func _apply_base_styles() -> void:
	# شريط علوي شبه شفاف فوق الخلفية
	var top_bar := $MainVBox/TopBar
	if top_bar != null:
		var top_sb := StyleBoxFlat.new()
		top_sb.bg_color = Color(0.06, 0.1, 0.18, 0.92)
		top_sb.content_margin_left = 8
		top_sb.content_margin_top = 4
		top_sb.content_margin_right = 8
		top_sb.content_margin_bottom = 4
		top_sb.corner_radius_bottom_left = 14
		top_sb.corner_radius_bottom_right = 14
		top_sb.border_color = Color(1, 0.78, 0.2, 0.35)
		top_sb.border_width_bottom = 2
		top_bar.add_theme_stylebox_override("panel", top_sb)
	# شرائح الموارد
	for chip_path in ["MainVBox/TopBar/TopHBox/Resources/GoldChip", "MainVBox/TopBar/TopHBox/Resources/GemChip"]:
		var chip := get_node_or_null(chip_path) as PanelContainer
		if chip != null:
			var chip_sb := StyleBoxFlat.new()
			chip_sb.bg_color = Color(0, 0, 0, 0.55)
			chip_sb.content_margin_left = 10
			chip_sb.content_margin_top = 4
			chip_sb.content_margin_right = 10
			chip_sb.content_margin_bottom = 4
			chip_sb.set_corner_radius_all(18)
			chip_sb.set_border_width_all(2)
			chip_sb.border_color = Color(1, 0.78, 0.2, 0.6) if "Gold" in chip_path else Color(0.7, 0.4, 1, 0.6)
			chip.add_theme_stylebox_override("panel", chip_sb)
	# منطقة المعاينة — لوح داكن شبه شفاف خلف المحتوى (المدينة تبقى ظاهرة حول الحواف)
	var preview := get_node_or_null("MainVBox/Body/PreviewArea") as PanelContainer
	if preview != null:
		var p_sb := StyleBoxFlat.new()
		p_sb.bg_color = Color(0.03, 0.05, 0.1, 0.55)
		p_sb.set_corner_radius_all(16)
		p_sb.content_margin_left = 10
		p_sb.content_margin_top = 10
		p_sb.content_margin_right = 10
		p_sb.content_margin_bottom = 10
		p_sb.border_color = Color(1, 0.78, 0.2, 0.16)
		p_sb.set_border_width_all(1)
		preview.add_theme_stylebox_override("panel", p_sb)
	# لوح مسبك داكن خلف نموذج السلاح ثلاثي الأبعاد
	_wrap_model_preview_plate()
	# زر التجهيز — أصغر قليلاً (288×50)
	_apply_orange_button(equip_button, Vector2(288, 50))
	# لوحة معلومات السلاح — زوايا مائلة + حدود برتقالية (مثل الصورة)
	var info_panel := get_node_or_null("MainVBox/Body/PreviewArea/PreviewVBox/PreviewRow/InfoPanel") as PanelContainer
	if info_panel != null:
		var i_sb := StyleBoxFlat.new()
		i_sb.bg_color = Color(0.06, 0.1, 0.18, 0.95)
		i_sb.content_margin_left = 14
		i_sb.content_margin_top = 12
		i_sb.content_margin_right = 14
		i_sb.content_margin_bottom = 12
		i_sb.corner_radius_top_left = 16
		i_sb.corner_radius_top_right = 4
		i_sb.corner_radius_bottom_left = 4
		i_sb.corner_radius_bottom_right = 16
		i_sb.border_color = Color(1, 0.78, 0.2, 0.9)
		i_sb.set_border_width_all(2)
		info_panel.add_theme_stylebox_override("panel", i_sb)
	# خانة أيقونة السلاح
	var icon_slot := get_node_or_null("MainVBox/Body/PreviewArea/PreviewVBox/PreviewRow/InfoPanel/InfoVBox/WeaponNameRow/WeaponIconSlot") as PanelContainer
	if icon_slot != null:
		var slot_sb := StyleBoxFlat.new()
		slot_sb.bg_color = Color(0.12, 0.2, 0.38, 1)
		slot_sb.set_corner_radius_all(10)
		slot_sb.border_color = Color(0.3, 0.5, 0.8, 0.6)
		slot_sb.set_border_width_all(1)
		icon_slot.add_theme_stylebox_override("panel", slot_sb)
	# ترويسة الترسانة
	var arsenal_hdr := $MainVBox/ArsenalHeader
	if arsenal_hdr != null:
		var a_sb := StyleBoxFlat.new()
		a_sb.bg_color = Color(0.05, 0.08, 0.15, 0.9)
		a_sb.content_margin_left = 20
		a_sb.content_margin_top = 4
		a_sb.content_margin_right = 20
		a_sb.content_margin_bottom = 4
		a_sb.set_corner_radius_all(8)
		a_sb.border_color = Color(1, 0.78, 0.2, 0.4)
		a_sb.set_border_width_all(1)
		arsenal_hdr.add_theme_stylebox_override("panel", a_sb)
	# لوحة الترسانة — حاوية كبيرة تحيط بكل الصفوف (مثل الصورة)
	var arsenal_panel := get_node_or_null("MainVBox/ArsenalPanel") as PanelContainer
	if arsenal_panel != null:
		var ap_sb := StyleBoxFlat.new()
		ap_sb.bg_color = Color(0.04, 0.08, 0.15, 0.92)
		ap_sb.content_margin_left = 12
		ap_sb.content_margin_top = 10
		ap_sb.content_margin_right = 12
		ap_sb.content_margin_bottom = 10
		ap_sb.set_corner_radius_all(14)
		ap_sb.border_color = Color(0.35, 0.55, 0.85, 0.9)
		ap_sb.set_border_width_all(2)
		arsenal_panel.add_theme_stylebox_override("panel", ap_sb)
	# شريط المستوى
	var bar := $MainVBox/Body/PreviewArea/PreviewVBox/PreviewRow/InfoPanel/InfoVBox/BarOverlay/LevelBar
	if bar != null:
		var base_tex := load(BAR_BASE) as Texture2D
		var yellow_tex := load(BAR_YELLOW) as Texture2D
		if base_tex != null:
			var bg := StyleBoxTexture.new()
			bg.texture = base_tex
			bg.set_texture_margin_all(8)
			bar.add_theme_stylebox_override("background", bg)
		if yellow_tex != null:
			var fill := StyleBoxTexture.new()
			fill.texture = yellow_tex
			fill.set_texture_margin_all(8)
			bar.add_theme_stylebox_override("fill", fill)
	# زر الرجوع — سهم برتقالي على خلفية داكنة (مثل الصورة)
	var back_sb := StyleBoxFlat.new()
	back_sb.bg_color = Color(0.07, 0.12, 0.22, 0.95)
	back_sb.set_corner_radius_all(12)
	back_sb.border_color = Color(1, 0.78, 0.2, 0.7)
	back_sb.set_border_width_all(1)
	back_button.add_theme_stylebox_override("normal", back_sb)
	var back_hover := StyleBoxFlat.new()
	back_hover.bg_color = Color(0.12, 0.18, 0.32, 0.95)
	back_hover.set_corner_radius_all(12)
	back_button.add_theme_stylebox_override("hover", back_hover)
	back_button.add_theme_stylebox_override("pressed", back_hover)
	back_button.text = ""
	back_button.icon = _tint_texture_orange(load(ICON_ARROW) as Texture2D)


func _wrap_model_preview_plate() -> void:
	# تغليف SubViewportContainer بلوح PanelContainer داكن (المسارات لا تنكسر لأن
	# weapon_holder / preview_cam تم حلّها في @onready قبل إعادة التنظيم)
	var preview_row := get_node_or_null("MainVBox/Body/PreviewArea/PreviewVBox/PreviewRow") as Container
	var model_preview := get_node_or_null("MainVBox/Body/PreviewArea/PreviewVBox/PreviewRow/ModelPreview") as Control
	if preview_row == null or model_preview == null:
		return
	if model_preview.get_parent() is PanelContainer:
		return
	var idx := preview_row.get_children().find(model_preview)
	var plate := PanelContainer.new()
	plate.name = "GunPlate"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.09, 0.72)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 6
	sb.content_margin_top = 6
	sb.content_margin_right = 6
	sb.content_margin_bottom = 6
	sb.border_color = Color(1, 0.78, 0.2, 0.35)
	sb.set_border_width_all(1)
	plate.add_theme_stylebox_override("panel", sb)
	preview_row.add_child(plate)
	preview_row.move_child(plate, idx)
	preview_row.remove_child(model_preview)
	plate.add_child(model_preview)
	model_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _tint_texture_orange(tex: Texture2D) -> ImageTexture:
	# تلوين السهم الأبيض إلى برتقالي ذهبي ليطابق التصميم
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var tint := Color(1.45, 0.92, 0.2)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
	return ImageTexture.create_from_image(img)


func _apply_orange_button(btn: Button, min_size: Vector2) -> void:
	if min_size.x > 0:
		btn.custom_minimum_size = min_size
	var tex := load(BTN_DEFAULT) as Texture2D
	if tex != null:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.set_texture_margin_all(16)
		btn.add_theme_stylebox_override("normal", sb)
		# الهوفر: نفس الزر البرتقالي أفتح قليلاً (لا نستخدم adventureButtonPressed — فيها سيفان!)
		var sb_hover := StyleBoxTexture.new()
		sb_hover.texture = tex
		sb_hover.set_texture_margin_all(16)
		sb_hover.modulate_color = Color(1.12, 1.12, 1.12)
		btn.add_theme_stylebox_override("hover", sb_hover)
		# الضغط: نفس الزر معتّم قليلاً
		var sb_press := StyleBoxTexture.new()
		sb_press.texture = tex
		sb_press.set_texture_margin_all(16)
		sb_press.modulate_color = Color(0.82, 0.82, 0.82)
		btn.add_theme_stylebox_override("pressed", sb_press)
	var dis := StyleBoxTexture.new()
	dis.texture = tex
	dis.set_texture_margin_all(16)
	dis.modulate_color = Color(0.5, 0.5, 0.5)  # معطّل: البرتقالي نفسه باهت (ليس لوحًا رماديًا)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.7))


func _make_bar_with_texture(fill_ratio: float, use_gold: bool) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = 100.0
	bar.value = fill_ratio * 100.0
	bar.show_percentage = false
	var base_tex := load(BAR_BASE) as Texture2D
	var fill_tex := load(BAR_YELLOW if use_gold else BAR_GREEN) as Texture2D
	if base_tex != null:
		var bg := StyleBoxTexture.new()
		bg.texture = base_tex
		bg.set_texture_margin_all(8)
		bar.add_theme_stylebox_override("background", bg)
	if fill_tex != null:
		var fill := StyleBoxTexture.new()
		fill.texture = fill_tex
		fill.set_texture_margin_all(8)
		bar.add_theme_stylebox_override("fill", fill)
	return bar


func _make_icon_rect(icon_path: String, size: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = size
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var tex := load(icon_path) as Texture2D
	if tex != null:
		tr.texture = tex
	return tr


func _process(delta: float) -> void:
	# ميلان لطيف حول زاوية3/4 (بدون دوران كامل يُخفي السلاح)
	if _preview_model != null and is_instance_valid(_preview_model):
		_preview_time += delta
		_preview_angle = 25.0 + sin(_preview_time * 0.7) * 16.0
		_preview_model.rotation_degrees = Vector3(-18, _preview_angle, 0)


func _load_weapons() -> void:
	_weapons.clear()
	var dir := DirAccess.open("res://resources/weapons")
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var w := load("res://resources/weapons/" + f) as WeaponResource
			if w != null:
				_weapons.append(w)
	_weapons.sort_custom(func(a: WeaponResource, b: WeaponResource) -> bool:
		return a.unlock_wave < b.unlock_wave)


func _rebuild() -> void:
	_update_resources()
	_update_display()
	_update_stats()
	_update_arsenal()


func _update_resources() -> void:
	gold_label.text = str(SaveSystem.get_gold())
	gem_label.text = str(int(SaveSystem.data.get("gems", 0)))


func _update_display() -> void:
	var w := _get_weapon(_selected_id)
	if w == null:
		return
	var unlocked := w.weapon_id in SaveSystem.get_unlocked_weapons()
	var level := SaveSystem.get_weapon_overall_level(w.weapon_id)
	var max_lv := SaveSystem.WEAPON_MAX_LEVEL * SaveSystem.WEAPON_STAT_DEFS.size()
	var progress := float(level) / float(max_lv)
	display_icon.text = _emoji_for(w.weapon_id)
	display_name.text = w.display_name
	display_level.text = "Overall Level %d/%d" % [level, max_lv]
	display_bar.value = progress * 100.0
	display_percent.text = "%d%%" % int(progress * 100.0)
	var is_equipped := w.weapon_id == SaveSystem.get_selected_weapon()
	if not unlocked:
		equip_button.text = "🔒 Locked — Wave %d" % w.unlock_wave
		equip_button.disabled = true
		equip_button.modulate = Color.WHITE  # نمط المعطّل (برتقالي باهت) يكفي للإشارة
	elif is_equipped:
		equip_button.text = "✓ Equipped"
		equip_button.disabled = true
		equip_button.modulate = Color.WHITE
	else:
		equip_button.text = "Equip Weapon ▶"
		equip_button.disabled = false
		equip_button.modulate = Color.WHITE
	# تحميل نموذج السلاح ثلاثي الأبعاد
	_load_weapon_model(w.weapon_id)


func _load_weapon_model(weapon_id: String) -> void:
	# مسح النموذج السابق
	for c in weapon_holder.get_children():
		c.queue_free()
	_preview_model = null
	_preview_angle = 0.0
	var model_path := "res://scenes/weapons/models/%s.tscn" % weapon_id
	var packed := load(model_path) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		return
	weapon_holder.add_child(model)
	_preview_model = model
	_preview_time = 0.0
	# تكبير/تدوير النموذج ليملأ الإطار (مقياس افتراضي صغير من GLB)
	model.scale = Vector3(8, 8, 8)
	model.rotation_degrees = Vector3(-18, 25, 0)
	# وضع الكاميرا على بعد مناسب لحجم النموذج
	_fit_camera_to_model(model)


func _fit_camera_to_model(model: Node3D) -> void:
	# انتظار frame لحساب AABB الصحيح
	await get_tree().process_frame
	if not is_instance_valid(model) or not is_instance_valid(preview_cam):
		return
	var aabb := _compute_aabb(model)
	if aabb.size.length() < 0.001:
		return
	var center := aabb.get_center()
	var radius := aabb.size.length() * 0.5
	var dist := radius / tan(deg_to_rad(preview_cam.fov * 0.5)) * 0.9
	# من الجانب (+X) لأن أنابيب الأسلحة تتجه إلى -Z — من الأمام تُرى نقطة صغيرة
	preview_cam.position = center + Vector3(dist, 0.2, 0)
	preview_cam.look_at(center, Vector3.UP)


func _compute_aabb(node: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	for c in _all_mesh_instances(node):
		var local := c.get_aabb()
		# تحويل كل رؤوس AABB إلى الفضاء العالمي يدويًا
		var points := PackedVector3Array([
			local.position,
			local.position + Vector3(local.size.x, 0, 0),
			local.position + Vector3(0, local.size.y, 0),
			local.position + Vector3(0, 0, local.size.z),
			local.position + Vector3(local.size.x, local.size.y, 0),
			local.position + Vector3(local.size.x, 0, local.size.z),
			local.position + Vector3(0, local.size.y, local.size.z),
			local.position + local.size,
		])
		var gt := c.global_transform
		var corners: Array[Vector3] = []
		for p in points:
			corners.append(gt * p)
		var min_v := corners[0]
		var max_v := corners[0]
		for v in corners:
			min_v = min_v.min(v)
			max_v = max_v.max(v)
		var global_aabb := AABB(min_v, max_v - min_v)
		if first:
			aabb = global_aabb
			first = false
		else:
			aabb = aabb.merge(global_aabb)
	return aabb


func _all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_all_mesh_instances(c))
	return out


func _update_stats() -> void:
	for c in stats_grid.get_children():
		c.queue_free()
	var w := _get_weapon(_selected_id)
	if w == null:
		return
	if w.weapon_id not in SaveSystem.get_unlocked_weapons():
		var lock_lbl := Label.new()
		lock_lbl.text = "🔓 Unlock this weapon first (Wave %d)" % w.unlock_wave
		lock_lbl.add_theme_font_size_override("font_size", 20)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_grid.add_child(lock_lbl)
		return
	for stat_id in SaveSystem.WEAPON_STAT_DEFS.keys():
		var card := _make_stat_card(w.weapon_id, str(stat_id))
		stats_grid.add_child(card)


func _make_stat_card(weapon_id: String, stat_id: String) -> PanelContainer:
	var defs: Dictionary = SaveSystem.WEAPON_STAT_DEFS[stat_id]
	var lvl := SaveSystem.get_weapon_upgrade(weapon_id, stat_id)
	var max_lv := SaveSystem.WEAPON_MAX_LEVEL
	var cost := SaveSystem.get_weapon_upgrade_cost(weapon_id, stat_id)
	var is_max := cost < 0

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 176)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.09, 0.17, 0.94)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12
	sb.content_margin_top = 10
	sb.content_margin_right = 12
	sb.content_margin_bottom = 10
	sb.border_color = COLOR_GREEN if is_max else Color(0.3, 0.5, 0.8, 0.85)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)

	# رأس البطاقة: أيقونة دائرية + الاسم + المستوى
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	v.add_child(header)
	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(54, 54)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color(0.07, 0.12, 0.22, 1)
	icon_sb.set_corner_radius_all(27)
	icon_sb.border_color = Color(1, 0.78, 0.2, 0.85)
	icon_sb.set_border_width_all(2)
	icon_box.add_theme_stylebox_override("panel", icon_sb)
	header.add_child(icon_box)
	var icon_lbl := Label.new()
	icon_lbl.text = _stat_icon(stat_id)
	icon_lbl.add_theme_font_size_override("font_size", 26)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_box.add_child(icon_lbl)
	var name_lbl := Label.new()
	name_lbl.text = str(defs["name"])
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(name_lbl)
	var lvl_lbl := Label.new()
	lvl_lbl.text = "%d/%d" % [lvl, max_lv]
	lvl_lbl.add_theme_font_size_override("font_size", 16)
	lvl_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	lvl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(lvl_lbl)

	# خط فاصل رفيع (مثل الصورة)
	var separator := ColorRect.new()
	separator.custom_minimum_size = Vector2(0, 1)
	separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	separator.color = Color(1, 0.78, 0.2, 0.25)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(separator)

	# القيم: +1.00 → +1.12
	var vals := HBoxContainer.new()
	vals.alignment = BoxContainer.ALIGNMENT_CENTER
	vals.add_theme_constant_override("separation", 8)
	v.add_child(vals)
	var mult := float(defs.get("mult", 0.1))
	var current_mult := 1.0 + lvl * mult
	var next_mult := 1.0 + (lvl + 1) * mult
	var from_lbl := Label.new()
	from_lbl.text = "+%.2f" % current_mult
	from_lbl.add_theme_font_size_override("font_size", 19)
	from_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vals.add_child(from_lbl)
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 19)
	arrow.add_theme_color_override("font_color", COLOR_GREEN)
	vals.add_child(arrow)
	var to_lbl := Label.new()
	to_lbl.text = "+%.2f" % next_mult if not is_max else "MAX"
	to_lbl.add_theme_font_size_override("font_size", 19)
	to_lbl.add_theme_color_override("font_color", COLOR_GREEN)
	vals.add_child(to_lbl)

	# زر الترقية برتقالي طويل / شارة MAX
	if is_max:
		var max_badge := Label.new()
		max_badge.text = "⭐ Max Level"
		max_badge.add_theme_font_size_override("font_size", 17)
		max_badge.add_theme_color_override("font_color", COLOR_GREEN)
		max_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(max_badge)
	else:
		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 18)
		var can_pay := SaveSystem.get_gold() >= cost
		btn.text = "💰 Upgrade %d" % cost
		btn.disabled = not can_pay
		btn.pressed.connect(_on_upgrade.bind(weapon_id, stat_id))
		_apply_orange_button(btn, Vector2(0, 48))
		v.add_child(btn)
	return panel


func _update_arsenal() -> void:
	var unlocked := SaveSystem.get_unlocked_weapons()
	var open_count := 0
	for w in _weapons:
		if w.weapon_id in unlocked:
			open_count += 1
	arsenal_count.text = "%d of %d unlocked" % [open_count, _weapons.size()]
	_row_thumbs.clear()
	for c in weapons_list.get_children():
		weapons_list.remove_child(c)
		c.queue_free()
	for w in _weapons:
		weapons_list.add_child(_make_weapon_row(w))


func _capture_thumbs_async() -> void:
	# التقاط صور جانبية للأسلحة من نماذجها ثلاثية الأبعاد (مرة واحدة + كاش في user://)
	if _capturing:
		return
	_capturing = true
	DirAccess.make_dir_recursive_absolute(THUMB_DIR)
	# تحميل الصور المحفوظة مسبقاً
	for w in _weapons:
		var cache_path := THUMB_DIR + w.weapon_id + ".png"
		if FileAccess.file_exists(cache_path):
			var img := Image.load_from_file(cache_path)
			if img != null and not img.is_empty():
				_thumb_cache[w.weapon_id] = ImageTexture.create_from_image(img)
				_apply_thumb(w.weapon_id)
	# ما زال ناقصاً؟ صقه الآن
	var missing: Array[WeaponResource] = []
	for w in _weapons:
		if not _thumb_cache.has(w.weapon_id):
			missing.append(w)
	if missing.is_empty():
		_capturing = false
		return
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.size = Vector2i(256, 112)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 32.0
	vp.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 75, 0)
	light.light_energy = 1.5
	vp.add_child(light)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.9)
	env.ambient_light_energy = 0.85
	env_node.environment = env
	vp.add_child(env_node)
	for w in missing:
		if not is_inside_tree():
			break
		var model_path := "res://scenes/weapons/models/%s.tscn" % w.weapon_id
		var packed := load(model_path) as PackedScene
		if packed == null:
			continue
		var holder := Node3D.new()
		vp.add_child(holder)
		var model := packed.instantiate() as Node3D
		model.scale = Vector3(8, 8, 8)
		model.rotation_degrees = Vector3(-18, 25, 0)
		holder.add_child(model)
		await get_tree().process_frame
		await get_tree().process_frame
		var aabb := _compute_aabb(model)
		if aabb.size.length() > 0.001:
			var center := aabb.get_center()
			var radius := aabb.size.length() * 0.5
			var dist := radius / tan(deg_to_rad(cam.fov * 0.5)) * 1.0
			# جانبية (+X) — الأنبوب يتجه -Z
			cam.position = center + Vector3(dist, 0.1, 0)
			cam.look_at(center, Vector3.UP)
		await get_tree().process_frame
		var tex := vp.get_texture()
		if tex != null:
			var img2 := tex.get_image()
			if img2 != null and not img2.is_empty():
				img2.save_png(THUMB_DIR + w.weapon_id + ".png")
				_thumb_cache[w.weapon_id] = ImageTexture.create_from_image(img2)
				_apply_thumb(w.weapon_id)
		holder.queue_free()
	if is_instance_valid(vp):
		vp.queue_free()
	_capturing = false


func _apply_thumb(weapon_id: String) -> void:
	if not _row_thumbs.has(weapon_id):
		return
	var rect := _row_thumbs[weapon_id] as TextureRect
	if rect == null or not is_instance_valid(rect):
		return
	var tex := _thumb_cache.get(weapon_id) as Texture2D
	if tex != null:
		rect.texture = tex
		rect.visible = true
		var emoji := rect.get_parent().get_node_or_null("EmojiLabel") as Label
		if emoji != null:
			emoji.visible = false


func _make_weapon_row(w: WeaponResource) -> PanelContainer:
	var is_unlocked := w.weapon_id in SaveSystem.get_unlocked_weapons()
	var is_selected := w.weapon_id == _selected_id
	var is_equipped := w.weapon_id == SaveSystem.get_selected_weapon()
	var level := SaveSystem.get_weapon_overall_level(w.weapon_id)
	var max_lv := SaveSystem.WEAPON_MAX_LEVEL * SaveSystem.WEAPON_STAT_DEFS.size()

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 88)
	var sb := StyleBoxFlat.new()
	if is_unlocked:
		sb.bg_color = Color(0.06, 0.1, 0.19, 0.95)
	else:
		# سلاح مقفل: خلفية رمادية داكنة + إطار أبيض باهت (مختلف بصرياً عن المفتوح)
		sb.bg_color = Color(0.05, 0.05, 0.07, 0.72)
	sb.set_corner_radius_all(12)
	if is_selected:
		sb.bg_color = Color(0.1, 0.15, 0.28, 0.98)
		sb.border_color = COLOR_GOLD
		sb.set_border_width_all(2)  # إطار ذهبي رفيع للتحديد
	elif is_equipped:
		sb.border_color = COLOR_GREEN
		sb.set_border_width_all(2)
	elif not is_unlocked:
		sb.border_color = Color(1, 1, 1, 0.18)
		sb.set_border_width_all(1)
	else:
		sb.border_color = Color(1, 0.78, 0.2, 0.25)
		sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(h)

	# صورة السلاح — تُلتقط من النموذج ثلاثي الأبعاد (بديل: إيموجي)
	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(128, 58)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color(0.04, 0.07, 0.13, 0.8)
	icon_sb.set_corner_radius_all(10)
	if is_selected:
		icon_sb.border_color = COLOR_GOLD
	elif not is_unlocked:
		icon_sb.border_color = Color(1, 1, 1, 0.15)
		icon_box.modulate = Color(0.55, 0.55, 0.62, 0.95)  # صورة السلاح المقفل رمادية
	else:
		icon_sb.border_color = Color(0.2, 0.35, 0.6, 0.5)
	icon_sb.set_border_width_all(1)
	icon_box.add_theme_stylebox_override("panel", icon_sb)
	h.add_child(icon_box)
	var thumb := TextureRect.new()
	thumb.name = "ThumbRect"
	thumb.custom_minimum_size = Vector2(124, 54)
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(thumb)
	var icon := Label.new()
	icon.name = "EmojiLabel"
	icon.text = _emoji_for(w.weapon_id)
	icon.add_theme_font_size_override("font_size", 28)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(icon)
	_row_thumbs[w.weapon_id] = thumb
	if _thumb_cache.has(w.weapon_id):
		thumb.texture = _thumb_cache[w.weapon_id] as Texture2D
		thumb.visible = true
		icon.visible = false

	# معلومات: الاسم + المستوى + شريط بنسبته داخله (مثل الصورة)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(info)
	var name_lbl := Label.new()
	name_lbl.text = w.display_name + (" ✓" if is_equipped else "")
	name_lbl.add_theme_font_size_override("font_size", 18)
	if is_equipped:
		name_lbl.add_theme_color_override("font_color", COLOR_GREEN)
	elif not is_unlocked:
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	else:
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	info.add_child(name_lbl)
	var lvl_lbl := Label.new()
	lvl_lbl.text = "Lv %d/%d" % [level, max_lv]
	lvl_lbl.add_theme_font_size_override("font_size", 14)
	lvl_lbl.add_theme_color_override("font_color", COLOR_GREEN if is_unlocked else Color(1, 1, 1, 0.4))
	info.add_child(lvl_lbl)

	# شريط تقدم + النسبة في منتصفه
	var bar_overlay := Control.new()
	bar_overlay.custom_minimum_size = Vector2(0, 18)
	bar_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(bar_overlay)
	var bar := _make_bar_with_texture(float(level) / float(max_lv), true)
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_overlay.add_child(bar)
	var pct_lbl := Label.new()
	pct_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pct_lbl.text = "%d%%" % int(float(level) / float(max_lv) * 100.0)
	pct_lbl.add_theme_font_size_override("font_size", 13)
	pct_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pct_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pct_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_overlay.add_child(pct_lbl)

	# زر العرض — برتقالي دائماً (مثل الصورة؛ الصف المختار يُميَّز بإطار ذهبي فقط)
	if is_unlocked:
		var sel_btn := Button.new()
		sel_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sel_btn.add_theme_font_size_override("font_size", 16)
		if is_selected:
			sel_btn.text = "✔ View"
		else:
			sel_btn.text = "View"
		sel_btn.pressed.connect(_on_select.bind(w.weapon_id))
		_apply_orange_button(sel_btn, Vector2(96, 42))
		h.add_child(sel_btn)
	else:
		var lock_hbox := HBoxContainer.new()
		lock_hbox.add_theme_constant_override("separation", 4)
		lock_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(lock_hbox)
		var lock_icon := _make_icon_rect(ICON_LOCK, Vector2(20, 20))
		lock_hbox.add_child(lock_icon)
		var wave_lbl := Label.new()
		wave_lbl.text = "Wave %d" % w.unlock_wave
		wave_lbl.add_theme_font_size_override("font_size", 14)
		wave_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
		lock_hbox.add_child(wave_lbl)
	return panel


func _on_select(weapon_id: String) -> void:
	_selected_id = weapon_id
	_rebuild()


func _on_equip() -> void:
	if _selected_id == "":
		return
	SaveSystem.set_selected_weapon(_selected_id)
	_show_toast("Weapon equipped ✓", true)
	_rebuild()


func _on_upgrade(weapon_id: String, stat_id: String) -> void:
	if SaveSystem.buy_weapon_upgrade(weapon_id, stat_id):
		var stat_name: String = str(SaveSystem.WEAPON_STAT_DEFS[stat_id].get("name", stat_id))
		var new_lvl := SaveSystem.get_weapon_upgrade(weapon_id, stat_id)
		_show_toast("Upgraded %s to level %d ✓" % [stat_name, new_lvl], true)
		_rebuild()
	else:
		_show_toast("Not enough gold", false)


func _on_back() -> void:
	SceneTransition.goto(MENU_PATH)


func _get_weapon(id: String) -> WeaponResource:
	for w in _weapons:
		if w.weapon_id == id:
			return w
	return null


func _emoji_for(weapon_id: String) -> String:
	return str(EMOJI_MAP.get(weapon_id, "🔫"))


func _stat_icon(stat_id: String) -> String:
	match stat_id:
		"damage": return "💥"
		"fire_rate": return "⚡"
		"range": return "🎯"
		"ammo": return "🛡️"
	return "📈"


func _show_toast(text: String, success: bool = false) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_label.add_theme_color_override("font_color", COLOR_GREEN if success else Color(0.973, 0.443, 0.443))
	var t := get_tree().create_timer(2.0)
	t.timeout.connect(func() -> void: toast_label.visible = false)
