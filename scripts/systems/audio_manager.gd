extends Node
## AudioManager (Autoload) — أصوات وموسيقى مولّدة إجرائياً (PCM) بلا أي ملفات خارجية.
## كل المحتوى تحت ~2.5kHz (نغمات ≤1.4k + نويز مُفلتر) — لا أصوات حادة فوق 5kHz.

const SFX_POOL_SIZE: int = 10
const SFX_RATE: int = 22050
const MUSIC_RATE: int = 11025
const MUSIC_LEN: float = 4.0

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var _sfx_cache: Dictionary = {}      # id -> AudioStreamWAV
var _sfx_samples: Dictionary = {}    # id -> PackedFloat32Array (لاختبار التردد)
var _music_cache: Dictionary = {}    # kind -> AudioStreamWAV
var _music_samples: Dictionary = {}  # kind -> PackedFloat32Array
var _music_track: String = ""
var _intensity_tw: Tween = null


func _ready() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		add_child(p)
		_sfx_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_a.name = "MusicA"
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.name = "MusicB"
	add_child(_music_b)


## إيقاف كل المشغّلات قبل teardown لتحرير الـ playbacks (يمنع تحذير leak عند الإغلاق)
func _exit_tree() -> void:
	for p in _sfx_players:
		p.stop()
	if _music_a != null:
		_music_a.stop()
	if _music_b != null:
		_music_b.stop()


## تشغيل مؤثر صوتي — id غير معروف يُتجاهل بصمت
## forced_pitch > 0 يفرض مقياس الصوت (لسلسلة القتل الصاعدة) وإلا عشوائي حول pitch_jitter
func play_sfx(id: String, volume_db: float = 0.0, pitch_jitter: float = 0.05, forced_pitch: float = -1.0) -> void:
	var stream := _get_sfx(id)
	if stream == null:
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % SFX_POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	if forced_pitch > 0.0:
		p.pitch_scale = forced_pitch
	else:
		p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## موسيقى: "menu" | "arena" | "stop"
func play_music(track: String) -> void:
	if track == _music_track:
		return
	_music_track = track
	match track:
		"menu":
			_music_a.stream = _get_music("menu")
			_music_a.volume_db = -7.0
			_music_a.pitch_scale = 1.0
			_music_a.play()
			_music_b.stop()
		"arena":
			_music_a.stream = _get_music("calm")
			_music_a.volume_db = -6.0
			_music_a.pitch_scale = 1.0
			_music_a.play()
			_music_b.stream = _get_music("hot")
			_music_b.volume_db = -60.0
			_music_b.pitch_scale = 1.0
			_music_b.play()  # صامت حتى set_arena_intensity
		_:
			_music_a.stop()
			_music_b.stop()


## تكثيف موسيقى Arena مع تقدّم الموجات: طبقة حماسية من الموجة 3 + تسارع طفيف
func set_arena_intensity(wave: int) -> void:
	if _music_track != "arena":
		return
	var hot: bool = wave >= 3
	var pitch := clampf(1.0 + float(wave) * 0.012, 1.0, 1.12)
	if _intensity_tw != null and _intensity_tw.is_valid():
		_intensity_tw.kill()  # لا تتشابك تلاشيات سابقة
	_intensity_tw = create_tween()
	_intensity_tw.tween_property(_music_a, "volume_db", -9.0 if hot else -6.0, 0.8)
	_intensity_tw.parallel().tween_property(_music_b, "volume_db", -5.0 if hot else -60.0, 0.8)
	_music_a.pitch_scale = pitch
	_music_b.pitch_scale = pitch


func get_music_track() -> String:
	return _music_track


func is_sfx_playing() -> bool:
	for p in _sfx_players:
		if p.playing:
			return true
	return false


func is_music_layer_hot() -> bool:
	return _music_b.playing and _music_b.volume_db > -30.0


## مدة المؤثر بالثواني (0 إذا مجهول) — يُولِّد ويُخزِّن عند أول طلب
func get_sfx_duration(id: String) -> float:
	var s := _get_sfx(id)
	if s == null:
		return 0.0
	return float(_sfx_samples[id].size()) / float(SFX_RATE)


## تقدير أعلى تردد عبر عدد تقاطعات الصفر (الهدف السلامة: ≤ 5000Hz)
func get_sfx_peak_freq(id: String) -> float:
	if not _sfx_samples.has(id):
		if _get_sfx(id) == null:
			return 0.0
	return _peak_freq(_sfx_samples[id], SFX_RATE)


func get_music_duration(kind: String) -> float:
	var s := _get_music(kind)
	if s == null:
		return 0.0
	return float(_music_samples[kind].size()) / float(MUSIC_RATE)


func get_music_peak_freq(kind: String) -> float:
	if not _music_samples.has(kind):
		if _get_music(kind) == null:
			return 0.0
	return _peak_freq(_music_samples[kind], MUSIC_RATE)


## تقاطعات الصفر ÷ (2×المدة) ≈ أعلى تردد ضمني
func _peak_freq(samples: PackedFloat32Array, rate: int) -> float:
	if samples.size() < 4:
		return 0.0
	var crossings := 0
	var last_sign := 0
	for i in range(1, samples.size()):
		var v: float = samples[i]
		if absf(v) < 0.0005:
			continue
		var sgn_val := 1 if v > 0.0 else -1
		if last_sign != 0 and sgn_val != last_sign:
			crossings += 1
		last_sign = sgn_val
	return float(crossings) * float(rate) / (2.0 * float(samples.size()))


func _get_sfx(id: String) -> AudioStreamWAV:
	if _sfx_cache.has(id):
		return _sfx_cache[id] as AudioStreamWAV
	if not _KNOWN_SFX.has(id):
		return null
	var samples := _make_sfx(id)
	_sfx_samples[id] = samples
	var stream := _to_wav(samples, SFX_RATE, false)
	_sfx_cache[id] = stream
	return stream


func _get_music(kind: String) -> AudioStreamWAV:
	if _music_cache.has(kind):
		return _music_cache[kind] as AudioStreamWAV
	if kind != "menu" and kind != "calm" and kind != "hot":
		return null
	var samples := _make_music(kind)
	_music_samples[kind] = samples
	var stream := _to_wav(samples, MUSIC_RATE, true)
	_music_cache[kind] = stream
	return stream


func _to_wav(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


const _KNOWN_SFX: Array = [
	"fire_ak47", "fire_shotgun", "fire_heavymg", "fire_laserifle", "fire_flamethrower",
	"fire_grenadelauncher", "fire_rocketlauncher", "fire_teslacoil", "fire_smokelauncher",
	"zombie_death", "upgrade_pick", "wave_start", "wave_end", "explosion", "kill_streak",
	"reel_tick", "reel_lock",
]


## توليد المؤثر حسب id (مركّب من نغمات + نويز مُفلتر)
func _make_sfx(id: String) -> PackedFloat32Array:
	match id:
		"fire_ak47":
			return _mix2(_tone(300.0, 140.0, 0.07, 0.45), _noise(0.05, 2200.0, 0.35, 6.0))
		"fire_shotgun":
			return _mix2(_tone(160.0, 70.0, 0.16, 0.55), _noise(0.14, 1400.0, 0.5, 5.0))
		"fire_heavymg":
			return _mix2(_tone(220.0, 90.0, 0.1, 0.5), _noise(0.08, 1800.0, 0.4, 6.0))
		"fire_laserifle":
			return _tone(1200.0, 350.0, 0.14, 0.45, 0.003)
		"fire_flamethrower":
			return _mix2(_noise(0.16, 2000.0, 0.3, 3.0), _tone(200.0, 150.0, 0.16, 0.1))
		"fire_grenadelauncher":
			return _mix2(_tone(180.0, 90.0, 0.12, 0.55), _noise(0.06, 1200.0, 0.3, 6.0))
		"fire_rocketlauncher":
			return _mix2(_tone(90.0, 60.0, 0.3, 0.5, 0.01), _noise(0.3, 1500.0, 0.3, 3.0))
		"fire_teslacoil":
			return _mix2(_zap(0.1, 1250.0, 90.0, 0.4), _noise(0.08, 2800.0, 0.18, 6.0))
		"fire_smokelauncher":
			return _mix2(_noise(0.2, 900.0, 0.4, 4.0), _tone(140.0, 100.0, 0.1, 0.2))
		"zombie_death":
			# موت كوميدي: نغمة هابطة بارتعاج + طقطقة خفيفة
			var s := _wobble_tone(500.0, 130.0, 0.3, 0.45, 18.0)
			_mix_into(s, _noise(0.04, 1500.0, 0.3, 8.0), 0.27)
			return s
		"upgrade_pick":
			var s2 := _tone(880.0, 880.0, 0.25, 0.35, 0.006)
			_mix_into(s2, _tone(1318.0, 1318.0, 0.16, 0.35, 0.006), 0.07)
			return s2
		"wave_start":
			return _mix2(_tone(220.0, 330.0, 0.45, 0.4, 0.02), _tone(110.0, 165.0, 0.45, 0.22, 0.02))
		"wave_end":
			var s3 := _tone(660.0, 660.0, 0.45, 0.3, 0.006)
			_mix_into(s3, _tone(880.0, 880.0, 0.3, 0.35, 0.006), 0.1)
			return s3
		"explosion":
			return _mix2(_noise(0.4, 900.0, 0.65, 5.0), _tone(70.0, 45.0, 0.35, 0.55, 0.006))
		"kill_streak":
			# نغمة صاعدة قصيرة — تُعزَّر بمقياس صوت متصاعد مع كل قتيل متتالٍ
			return _tone(520.0, 780.0, 0.1, 0.5, 0.003)
		"reel_tick":
			# طقطقة بكرة ماكينة الحظ (نشّاط خفيف عالي التردد)
			return _mix2(_tone(1750.0, 1550.0, 0.035, 0.22, 0.001), _noise(0.018, 3000.0, 0.14, 7.0))
		"reel_lock":
			# قفل البكرة: طبقة ساطعة متدرجة صاعدة
			var s4 := _tone(660.0, 660.0, 0.14, 0.38, 0.002)
			_mix_into(s4, _tone(880.0, 880.0, 0.2, 0.36, 0.002), 0.05)
			_mix_into(s4, _tone(1320.0, 1320.0, 0.24, 0.3, 0.002), 0.1)
			return s4
	return PackedFloat32Array()


## نغمة جيبية بتدرّج ترددي + غلاف أُسّي ب.attack ناعم (بدون نقرات)
func _tone(f0: float, f1: float, dur: float, vol: float, attack: float = 0.004) -> PackedFloat32Array:
	var n := int(dur * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SFX_RATE
		var f := lerpf(f0, f1, clampf(t / dur, 0.0, 1.0))
		phase += TAU * f / float(SFX_RATE)
		var env := exp(-4.0 * t / dur)
		if t < attack:
			env *= t / attack
		out[i] = sin(phase) * env * vol
	return out


## نغمة بارتعاج (vibrato) هابطة — للصوت الكوميدي
func _wobble_tone(f0: float, f1: float, dur: float, vol: float, wobble_hz: float) -> PackedFloat32Array:
	var n := int(dur * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SFX_RATE
		var f := lerpf(f0, f1, clampf(t / dur, 0.0, 1.0)) * (1.0 + 0.08 * sin(TAU * wobble_hz * t))
		phase += TAU * f / float(SFX_RATE)
		var env := exp(-3.5 * t / dur)
		out[i] = sin(phase) * env * vol
	return out


## نغمة مُعدَّدة (AM) — لصدمة tesla الكهربائية (المحتوى ≈ carrier ± mod < 2kHz)
func _zap(dur: float, carrier: float, mod_hz: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SFX_RATE
		var am := 0.5 + 0.5 * sin(TAU * mod_hz * t)
		var env := exp(-6.0 * t / dur)
		if t < 0.003:
			env *= t / 0.003
		out[i] = sin(TAU * carrier * t) * am * env * vol
	return out


## نويز أبيض مُفلتر منخفض (one-pole) بغلف هابط — المحتوى < cutoff
func _noise(dur: float, cutoff: float, vol: float, decay: float) -> PackedFloat32Array:
	var n := int(dur * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var alpha := 1.0 - exp(-TAU * cutoff / float(SFX_RATE))
	var y := 0.0
	for i in n:
		var t := float(i) / SFX_RATE
		y += alpha * ((randf() * 2.0 - 1.0) - y)
		var env := exp(-decay * t / dur)
		if t < 0.003:
			env *= t / 0.003
		out[i] = y * env * vol
	return out


func _mix2(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size())
	for i in a.size():
		out[i] = a[i]
	_mix_into(out, b, 0.0)
	return out


func _mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, at_sec: float) -> void:
	var off := int(at_sec * SFX_RATE)
	for i in src.size():
		var j := off + i
		if j >= dst.size():
			break
		dst[j] += src[i]


## مولّد الموسيقى: حلقات 4 ثوانٍ بمحتوى منخفض — اكتمال الدورات يمنع النقر عند التكرار
func _make_music(kind: String) -> PackedFloat32Array:
	var n := int(MUSIC_LEN * MUSIC_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	match kind:
		"menu":
			for i in n:
				var t := float(i) / MUSIC_RATE
				var lfo := 1.0 + 0.25 * sin(TAU * 0.25 * t)  # 0.25Hz = دورة واحدة في 4ث
				var v := 0.15 * sin(TAU * 110.0 * t) * lfo
				v += 0.07 * sin(TAU * 164.75 * t) * (1.0 + 0.3 * sin(TAU * 0.25 * t + 1.7))
				v += 0.05 * sin(TAU * 220.0 * t) * lfo
				var hb := fmod(t, 2.0)
				if hb < 0.35:
					var w := sin(PI * hb / 0.35)
					v += 0.2 * sin(TAU * 55.0 * t) * w * w  # نبضة خفيفة كل ثانيتين
				buf[i] = v
		"calm":
			# باص 8نغمات + ضربات دفء كل ثانية + طرقات خفيفة (نويز مُفلتر ≤2.2k)
			var notes: Array[float] = [82.5, 82.5, 98.0, 82.5]
			var kick_phase := 0.0
			var ny := 0.0
			var na := 1.0 - exp(-TAU * 2200.0 / float(MUSIC_RATE))
			for i in n:
				var t := float(i) / MUSIC_RATE
				var v := 0.0
				var eb := fmod(t, 0.5)
				var f: float = notes[int(t / 0.5) % 4]
				var wb := sin(PI * eb / 0.5)
				var env_b := minf(eb / 0.006, 1.0) * exp(-3.5 * eb) * (wb * wb + 0.35 * wb)
				v += 0.32 * (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t)) * env_b
				var kf := fmod(t, 1.0)
				if kf < 0.14:
					var fr := lerpf(60.0, 40.0, clampf(kf / 0.14, 0.0, 1.0))
					kick_phase += TAU * fr / float(MUSIC_RATE)
					var w2 := sin(PI * kf / 0.14)
					v += 0.5 * sin(kick_phase) * w2 * w2
				ny += na * ((randf() * 2.0 - 1.0) - ny)
				var hf := fmod(t - 0.25, 0.5)
				if t >= 0.25 and hf < 0.04:
					var w3 := sin(PI * hf / 0.04)
					v += 0.12 * ny * w3 * w3
				buf[i] = clampf(v, -1.0, 1.0)
		"hot":
			# نفس الأساس + طرقات 16 ند + سنير + نغمة حماسية (نويز مُفلتر ≤2.2k)
			var notes2: Array[float] = [82.5, 82.5, 98.0, 82.5]
			var lead: Array[float] = [220.0, 261.75, 330.0, 392.0]
			var kick_phase2 := 0.0
			var ny := 0.0
			var na := 1.0 - exp(-TAU * 2200.0 / float(MUSIC_RATE))
			for i in n:
				var t := float(i) / MUSIC_RATE
				var v := 0.0
				var eb := fmod(t, 0.5)
				var f := notes2[int(t / 0.5) % 4]
				var wb := sin(PI * eb / 0.5)
				var env_b := minf(eb / 0.006, 1.0) * exp(-3.5 * eb) * (wb * wb + 0.35 * wb)
				v += 0.3 * (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t)) * env_b
				var kf := fmod(t, 1.0)
				if kf < 0.14:
					var fr := lerpf(60.0, 40.0, clampf(kf / 0.14, 0.0, 1.0))
					kick_phase2 += TAU * fr / float(MUSIC_RATE)
					var w2 := sin(PI * kf / 0.14)
					v += 0.5 * sin(kick_phase2) * w2 * w2
				ny += na * ((randf() * 2.0 - 1.0) - ny)
				var hf := fmod(t, 0.125)
				var wh := sin(PI * hf / 0.125)
				v += 0.1 * ny * minf(hf / 0.002, 1.0) * exp(-20.0 * hf) * wh * wh
				if t >= 0.5:
					var sf := fmod(t - 0.5, 1.0)
					if sf < 0.1:
						var ws := sin(PI * sf / 0.1)
						v += 0.22 * ny * ws * ws
				var lt := fmod(t, 0.25)
				if lt < 0.12:
					var fl: float = lead[int(t / 0.25) % 4]
					var wl := sin(PI * lt / 0.12)
					v += 0.16 * sin(TAU * fl * t) * wl * wl * exp(-3.0 * lt)
				buf[i] = clampf(v, -1.0, 1.0)
	return buf
