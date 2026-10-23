class_name TimeFX
## التحكم بزمن اللعبة (بطيء/تجميد) — يُستدعى عند آخر قتيل في الموجة
##
## إصلاح حرج: كان كل تأثير يحفظ قيمة "السابقة" لـ Engine.time_scale ويستعيدها
## لاحقًا. عند تداخل "التجميد" (0.02) مع "البطيء" (0.3) كانت القيمة المستعادة
## 0.02 → تعلّق اللعب عند 2% من السرعة (Slow Motion دائم) من المرة الثالثة
## للترقية فصاعدًا. الآن كل التأثيرات تتشارك حالة واحدة ويستعيد كل منها
## القيمة الصحيحة (1.0 أو سلّم البطء النشط).
##
## إصلاح ثانٍ: أثناء قائمة التطويرات تكون الشجرة متوقفة (paused) وأي تجميد
## لحظي (hit_stop) كان يخفض السرعة إلى 0.02 → أنيميشن الواجهة (البكرة وبطلة
## الاختيار) يمشي بـ 2% فيبدو وكأن اللعبة علّقت لنصف دقيقة. لذلك نتجاهل
## التأثيرات الزمنية تمامًا أثناء التوقف، ونجعل تويتات الواجهة تتجاهل time_scale.

static var _slow_pending: bool = false
static var _slow_scale: float = 1.0
static var _hitstop_active: bool = false
static var _slow_gen: int = 0
static var _hitstop_gen: int = 0
static var _hitstop_ready_at: int = 0

## أقل فاصل زمني (بالثواني الحقيقية) بين تجميدين لحظيين.
## بدونه: كل قتلة/انفجار يعيد تشغيل التجميد → مع السلاح السريع تتجمد اللعبة
## عند 2% من السرعة بشكل شبه دائم (= بطء شديد). مع الفاصل يبقى التجميد
## "مكافأة" للضربة القاتلة دون أن يجمّد اللعب المستمر.
const HIT_STOP_COOLDOWN: float = 0.2


## إيقاف كل التأثيرات الزمنية وإعادة السرعة الطبيعية (يُستدعى عند فتح/إغلاق الشاشات)
static func reset() -> void:
	_slow_gen += 1      # تبطل أي مؤقتات بطء معلّقة
	_hitstop_gen += 1   # تبطل أي مؤقتات تجميد معلّقة
	Engine.time_scale = 1.0
	_slow_pending = false
	_hitstop_active = false
	_slow_scale = 1.0


## تبطيء الزمن إلى scale لمدة duration ثوانٍ حقيقية (تتجاوز time_scale) ثم الاستعادة
static func slow_motion(scale: float, duration: float) -> void:
	if _slow_pending:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if tree.paused:
		return  # أثناء قوائم الإيقاف لا لعب داخل العالم — لا داعي للتبطيء
	_slow_pending = true
	_slow_scale = scale
	Engine.time_scale = scale
	_slow_gen += 1
	var gen := _slow_gen
	var timer := tree.create_timer(duration, true, false, true)  # ignore_time_scale = زمن حقيقي
	timer.timeout.connect(_restore_slow.bind(gen))


## تجميد لحظي (Hit-stop) — يتشارك الحالة مع البطء الزمني دون أن يفسد استعادته
static func hit_stop(duration: float = 0.06) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if tree.paused:
		return  # القائمة مفتوحة: تجميد العالم هنا يجمّد أنيميشن الواجهة أيضًا
	# لا نتداخل مع البطيء الزمني أو تجميد جارٍ
	if _slow_pending or _hitstop_active:
		return
	if Engine.time_scale < 0.9:
		return
	# فترة سماح: تجميد لحظي حديث → نتخطاه (إلا ذهب كل وقت اللعبة إلى 2%)
	var now := Time.get_ticks_msec()
	if now < _hitstop_ready_at:
		return
	_hitstop_active = true
	Engine.time_scale = 0.02  # تجميد شبه تام
	_hitstop_ready_at = now + int((duration + HIT_STOP_COOLDOWN) * 1000.0)
	_hitstop_gen += 1
	var gen := _hitstop_gen
	var timer := tree.create_timer(duration, true, false, true)  # ignore_time_scale = زمن حقيقي
	timer.timeout.connect(_restore_hitstop.bind(gen))


## انتهاء البطء الزمني: نعود للسرعة الطبيعية ما لم يكن هناك تجميد نشط
static func _restore_slow(gen: int) -> void:
	if gen != _slow_gen:
		return  # مؤقت قديم أُبطل بـ reset()
	_slow_pending = false
	if _hitstop_active:
		Engine.time_scale = 0.02
	else:
		Engine.time_scale = 1.0


## انتهاء التجميد: نعود لسرعة البطء إن كان نشطًا، وإلا للسرعة الطبيعية
static func _restore_hitstop(gen: int) -> void:
	if gen != _hitstop_gen:
		return  # مؤقت قديم أُبطل بـ reset()
	_hitstop_active = false
	if _slow_pending:
		Engine.time_scale = _slow_scale
	else:
		Engine.time_scale = 1.0
