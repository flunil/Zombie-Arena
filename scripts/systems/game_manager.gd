extends Node
class_name GM
## Singleton (Autoload: GameManager) — حالة اللعبة العامة.
## الوصول عبر class_name GM (ثابت) ليعمل في المحرر واللعبة معاً.

enum State { MENU, PLAYING, WAVE_CLEARED, GAME_OVER }

static var state: int = State.MENU
static var total_kills: int = 0
static var waves_completed: int = 0
static var run_gold: int = 0


static func set_state(new_state: int) -> void:
	state = new_state


static func is_playing() -> bool:
	return state == State.PLAYING


static func is_game_over() -> bool:
	return state == State.GAME_OVER


## بدء جولة جديدة (يُستدعى عند إعادة التشغيل)
static func reset_run() -> void:
	total_kills = 0
	waves_completed = 0
	run_gold = 0
	UnlockSystem.reset()
	UpgradeManager.reset_run()
	set_state(State.PLAYING)


func _ready() -> void:
	DailySystem.check_on_boot()  # فحص التاريخ/السلسلة/توليد المهام عند بدء التشغيل
	_bind_gamepad_input()  # عصا يسار + زر تبديل السلاح للأجوي الفيزيائي
	if DisplayServer.get_name() != "headless":
		var overlay_script: GDScript = load("res://scripts/ui/perf_overlay.gd")
		if overlay_script != null:
			add_child(overlay_script.new())  # عدّاد F3 (يُطفأ في headless — لا عقد ولا رسم)


## ربط الأحداث اللعبية وقت التشغيل (بلا تعديل project.godot — idempotent)
func _bind_gamepad_input() -> void:
	_ensure_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_ensure_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_ensure_joy_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_ensure_joy_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_ensure_joy_button("switch_weapon", JOY_BUTTON_RIGHT_SHOULDER)


static func _ensure_joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion and ev.axis == axis and is_equal_approx(ev.axis_value, value):
			return
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)


static func _ensure_joy_button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == button:
			return
	var e := InputEventJoypadButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)


## حاكم دقة تكيّفي: عند تراكم البطء يُخفض رسم 3D ثم يعود تدريجيًا (حدّ اللاقط على iGPU)
const SCALE_HIGH := 0.7
const SCALE_LOW := 0.55
const GOV_SLOW_MS := 40.0
const GOV_FAST_MS := 28.0
var _gov_slow := 0.0
var _gov_fast := 0.0


func _process(delta: float) -> void:
	if OS.get_environment("PERF_PROBE") != "":  # قياس perf_probe: يتحكم بالدقة بنفسه
		return
	var vp := get_viewport()
	if vp == null:
		return
	var dt_ms := delta * 1000.0
	if vp.scaling_3d_scale > SCALE_HIGH - 0.01:
		if dt_ms > GOV_SLOW_MS:
			_gov_slow += delta
			if _gov_slow > 1.5:
				vp.scaling_3d_scale = SCALE_LOW
				_gov_slow = 0.0
		else:
			_gov_slow = maxf(0.0, _gov_slow - delta * 0.5)
	elif dt_ms < GOV_FAST_MS:
		_gov_fast += delta
		if _gov_fast > 4.0:
			vp.scaling_3d_scale = SCALE_HIGH
			_gov_fast = 0.0
	else:
		_gov_fast = 0.0


## حفظ التقدم عند إغلاق النافذة/إيقاف التطبيق (عقدة GameManager في الجذر)
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		SaveSystem.save()
