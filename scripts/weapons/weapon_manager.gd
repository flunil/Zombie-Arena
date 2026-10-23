extends Node3D
class_name WeaponManager
## يدير الأسلحة: التبديل بين المفتوحة + الإطلاق + فتح جديد عند الموجات

signal ammo_changed(current: int, max_ammo: int)
signal weapon_changed(index: int, weapon_id: String, display_name: String)
signal weapons_unlocked(ids: Array)

@export var weapon_resources: Array[WeaponResource] = []
@export var bullet_scene: PackedScene

var _weapons: Array[Node3D] = []
var _current: int = -1
var _hands: Array[Node3D] = []  # موازٍ لـ _weapons: عقد سلاح اليد المطابقة (null إن غابت)


func _ready() -> void:
	# البناء مؤجل حتى لا نفشل أثناء تجهيز شجرة المشهد
	call_deferred("_build_weapons")
	var wm: Node = get_tree().get_first_node_in_group("wave_manager")
	if wm != null and wm.has_signal("wave_started"):
		wm.wave_started.connect(_on_wave_started)


func _build_weapons() -> void:
	for data in weapon_resources:
		if data == null:
			continue
		var w: WeaponBase = WeaponBase.new()
		w.weapon_data = data
		w.bullet_scene = bullet_scene
		w.visible = false
		w.set_physics_process(false)
		w.hand_node = _find_hand_weapon(data.weapon_id)  # مصدر المجسم البصري = عقدة اليد
		# تمرير إشارة الذخيرة إلى الواجهة مع كل طلقة أو انتهاء تعبئة
		w.ammo_changed.connect(func(cur: int, mx: int) -> void: ammo_changed.emit(cur, mx))
		add_child(w)
		_weapons.append(w)
		_hands.append(w.hand_node)
	# السلاح المختار من صفحة القائمة إن كان مفتوحًا، وإلا أول مفتوح
	var chosen := SaveSystem.get_selected_weapon()
	if chosen != "" and UnlockSystem.is_unlocked(chosen):
		for i in _weapons.size():
			if _weapons[i].weapon_data.weapon_id == chosen:
				_select(i)
				return
	for i in _weapons.size():
		if UnlockSystem.is_unlocked(_weapons[i].weapon_data.weapon_id):
			_select(i)
			return


## جذر عقد أسلحة اليد في Player.tscn (BoneAttachment3D على عظمة Rifle — تثبيت يدوي للمستخدم)
func _hand_root() -> Node3D:
	return get_node_or_null("../Characters_Lis/CharacterArmature/Skeleton3D/Rifle") as Node3D


## إيجاد عقدة سلاح اليد المطابقة لـ weapon_id (مطابقة غير حساسة لحالة الأحرف)
func _find_hand_weapon(id: String) -> Node3D:
	var root := _hand_root()
	if root == null:
		return null
	for c in root.get_children():
		if c is Node3D and String(c.name).to_lower() == id.to_lower():
			return c
	return null


func _on_wave_started(wave: int) -> void:
	var newly: Array[String] = UnlockSystem.on_wave_started(wave, weapon_resources)
	if newly.size() > 0:
		weapons_unlocked.emit(newly)


func get_current() -> Node3D:
	if _current < 0 or _current >= _weapons.size():
		return null
	return _weapons[_current]


func get_weapon_count() -> int:
	return _weapons.size()


func get_current_index() -> int:
	return _current


func get_data(index: int) -> WeaponResource:
	if index < 0 or index >= _weapons.size():
		return null
	return _weapons[index].weapon_data


## فهرس أزرار الواجهة: المفتوحة فقط (4 كحد أقصى في UI)
func get_unlocked_indices() -> Array[int]:
	var out: Array[int] = []
	for i in _weapons.size():
		if UnlockSystem.is_unlocked(_weapons[i].weapon_data.weapon_id):
			out.append(i)
			if out.size() >= 4:
				break
	return out


func get_move_mult() -> float:
	var w: Node3D = get_current()
	if w == null:
		return 1.0
	return w.weapon_data.move_mult


func switch_weapon(index: int) -> void:
	if index < 0 or index >= _weapons.size():
		return
	if not UnlockSystem.is_unlocked(_weapons[index].weapon_data.weapon_id):
		return  # لا تبديل لسلاح مغلق
	if index == _current:
		return
	_select(index)


func switch_next() -> void:
	var unlocked: Array[int] = get_unlocked_indices()
	if unlocked.is_empty():
		return
	var pos: int = unlocked.find(_current)
	_select(unlocked[(pos + 1) % unlocked.size()])


func switch_prev() -> void:
	var unlocked: Array[int] = get_unlocked_indices()
	if unlocked.is_empty():
		return
	var pos: int = unlocked.find(_current)
	_select(unlocked[(pos - 1 + unlocked.size()) % unlocked.size()])


func try_fire(direction: Vector3) -> void:
	var w: Node3D = get_current()
	if w != null:
		w.try_fire(direction)


func _select(index: int) -> void:
	if _current >= 0 and _current < _weapons.size():
		_weapons[_current].visible = false
		_weapons[_current].set_physics_process(false)
	_current = index
	var w: Node3D = _weapons[_current]
	w.visible = true
	w.set_physics_process(true)
	# سلاح اليد المرئي = المطابق للحالي فقط (يظهر مع تبديل السلاح على العظمة)
	for i in _hands.size():
		if _hands[i] != null and is_instance_valid(_hands[i]):
			(_hands[i] as Node3D).visible = (i == index)
	weapon_changed.emit(_current, w.weapon_data.weapon_id, w.weapon_data.display_name)
	if w.has_signal("ammo_changed"):
		ammo_changed.emit(w.get_ammo(), w.get_ammo_max())
