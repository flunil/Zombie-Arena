extends Control
class_name VirtualJoystick
## جوي ستك للمس: يرسم قاعدة + مقبض ويُخرج Vector2 لتحريك اللاعب

signal vector_changed(value: Vector2)
signal double_tap(last_vector: Vector2)  ## نقرتان سريعتان → يطلقها اللاعب لتنفيذ القفزة

const DOUBLE_TAP_TIME := 0.35  ## أقصى زمن بين النقرتين (ثانية)

@export var radius: float = 95.0
@export var knob_radius: float = 42.0
@export var deadzone: float = 0.18

var _vector: Vector2 = Vector2.ZERO
var _knob_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _touch_index: int = -1
var _last_vector: Vector2 = Vector2.ZERO  # آخر متجه غير صفري (يبقى بعد رفع الإصبع)
var _last_tap_ts: float = -10.0           # زمن آخر نقرة (ثواني)


func _enter_tree() -> void:
	add_to_group("virtual_joystick")  # قبل _ready حتى يجده اللاعب


func _ready() -> void:
	_knob_pos = size * 0.5
	queue_redraw()


## متجه الحركة الحالي (0..1 لكل محور)
func get_move_vector() -> Vector2:
	return _vector


## آخر متجه حركة غير صفري (للقفزة بعد رفع الإصبع)
func get_last_vector() -> Vector2:
	return _last_vector


## هل الجوي مُسحَب الآن؟ (يمنع الرماية أثناء السحب)
func is_active() -> bool:
	return _dragging


## معالجة في _input حتى يستمر السحب حتى خارج حدود العنصر
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and get_global_rect().has_point(event.position):
			_register_tap()
			_start_drag(event.index, event.position)
			get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			_end_drag()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _touch_index != -1:
			return  # لمس حقيقي يتحكم بالفعل (محاكاة فأرة)
		if event.pressed:
			if get_global_rect().has_point(event.position):
				_register_tap()
				_start_drag(-1, event.position)
				get_viewport().set_input_as_handled()
		elif _dragging:
			_end_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging and _touch_index == -1:
		_update_drag(event.position)
		get_viewport().set_input_as_handled()


## تسجيل نقرة: إن كانت النقرة السابقة أحدث من DOUBLE_TAP_TIME → نقرة مزدوجة
func _register_tap() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_tap_ts <= DOUBLE_TAP_TIME:
		double_tap.emit(_last_vector if _last_vector.length_squared() > 0.0001 else _vector)
	_last_tap_ts = now


func _start_drag(index: int, pos: Vector2) -> void:
	_dragging = true
	_touch_index = index
	_update_drag(pos)


func _update_drag(pos: Vector2) -> void:
	var center: Vector2 = size * 0.5
	var local: Vector2 = get_global_transform().affine_inverse() * pos
	var offset: Vector2 = (local - center).limit_length(radius)
	_knob_pos = center + offset
	var v: Vector2 = offset / radius
	var magnitude: float = v.length()
	if magnitude < deadzone:
		v = Vector2.ZERO
	else:
		v = v.normalized() * ((magnitude - deadzone) / (1.0 - deadzone))
	_set_vector(v)


func _end_drag() -> void:
	_dragging = false
	_touch_index = -1
	_knob_pos = size * 0.5
	_set_vector(Vector2.ZERO)


func _set_vector(value: Vector2) -> void:
	if value.length_squared() > 0.0001:
		_last_vector = value  # يبقى محفوظاً بعد الرفع ليستخدمه زر القفز/الانزلاق
	if value.is_equal_approx(_vector):
		queue_redraw()
		return
	_vector = value
	queue_redraw()
	vector_changed.emit(_vector)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, radius, Color(1.0, 1.0, 1.0, 0.16))
	draw_arc(center, radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.45), 3.0, true)
	draw_circle(_knob_pos, knob_radius, Color(1.0, 1.0, 1.0, 0.55))
	draw_arc(_knob_pos, knob_radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.9), 2.0, true)
