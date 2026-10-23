extends Node
class_name PerfOverlay
## عدّاد أداء للمطوّر: F3 يفتح/يغلق اللوحة (FPS/زمن الإطار/الفيزياء/أوامر الرسم)
## يطبع ملخص [PERF] كل ثانيتين إلى الـ Output — أساس القياس قبل/بعد تحسينات اللاقط

var _layer: CanvasLayer = null
var _label: Label = null
var _shown: bool = false
var _acc := 0.0
var _frames := 0
var _sum_ms := 0.0
var _max_ms := 0.0
var _proc_sum := 0.0
var _phys_sum := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_layer = CanvasLayer.new()
	_layer.layer = 200
	add_child(_layer)
	_label = Label.new()
	_label.position = Vector2(10, 10)
	_label.visible = false
	_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	_layer.add_child(_label)


func _input(event: InputEvent) -> void:
	if _label == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_shown = not _shown
		_label.visible = _shown


func _process(delta: float) -> void:
	_frames += 1
	_sum_ms += delta * 1000.0
	_max_ms = maxf(_max_ms, delta * 1000.0)
	_proc_sum += Performance.get_monitor(Performance.TIME_PROCESS)
	_phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	_acc += delta
	if _acc < 2.0:
		return
	var n := float(maxi(_frames, 1))
	var fps := int(Performance.get_monitor(Performance.TIME_FPS))
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var s := "FPS=%d frame_avg=%.1fms frame_max=%.1f proc=%.2fms phys=%.2fms draws=%d nodes=%d" % [
		fps, _sum_ms / n, _max_ms, _proc_sum / n, _phys_sum / n, draws, nodes]
	if _shown:
		_label.text = s
	print("[PERF] ", s)
	_acc = 0.0
	_frames = 0
	_sum_ms = 0.0
	_max_ms = 0.0
	_proc_sum = 0.0
	_phys_sum = 0.0
