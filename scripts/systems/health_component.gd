extends Node
class_name HealthComponent
## مكوّن صحة مستقل — يُبث إشارة died عند نفاد الصحة

signal damaged(amount: float, new_health: float)
signal healed(amount: float, new_health: float)
signal died

@export var max_health: float = 100.0

var health: float = 0.0
var shield: float = 0.0  # درع طاقة (EnergyShield) يمتص الضرر قبل الصحة
var _shield_peak := 0.0  # أعلى درع بلغه — حد لإعادة البناء (ShieldRegen)
var _is_player := false  # ترقيات الدفاع تُطبَّق على اللاعب فقط (الزومبي لا يملكها أصلًا)
var _quantum_acc := 0.0  # مراكم الدرع الكمي (كل 10ث)


func _ready() -> void:
	health = max_health
	var p := get_parent()
	_is_player = p != null and p.is_in_group("player")


## ShieldRegen: الدرع يعود حتى آخر مستوى بلغه | QuantumShield: +15 كل 10ث — للاعب فقط
func _process(delta: float) -> void:
	if shield > _shield_peak:
		_shield_peak = shield
	if not _is_player:
		return
	if UpgradeManager.has("quantum_shield"):
		_quantum_acc += delta
		if _quantum_acc >= 10.0:
			_quantum_acc -= 10.0
			shield += 15.0  # الذروة تُلحق في الإطار التالي فتُبنى هذه الزيادة أيضًا
	if UpgradeManager.has_shield_regen() and _shield_peak > 0.0 and shield < _shield_peak:
		shield = minf(_shield_peak, shield + 2.0 * delta)  # 2 درع/ثانية


func is_dead() -> bool:
	return health <= 0.0


func get_percent() -> float:
	return 0.0 if max_health <= 0.0 else health / max_health


func take_damage(amount: float) -> void:
	if health <= 0.0 or amount <= 0.0:
		return
	if _is_player:
		amount -= 1.0 * UpgradeManager.count_of("armor_flat")  # ArmorFlat: امتصاص نقاط
		if amount <= 0.0:
			return
		if UpgradeManager.has("iron_skin"):  # IronSkin: -25% من كل الضرر (ممتاز)
			amount *= maxf(0.25, 1.0 - 0.25 * UpgradeManager.count_of("iron_skin"))
		if amount <= 0.0:
			return
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		if amount <= 0.0:
			return
	health = maxf(0.0, health - amount)
	damaged.emit(amount, health)
	if health <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if health <= 0.0 or amount <= 0.0:
		return
	health = minf(max_health, health + amount)
	healed.emit(amount, health)


## إعادة الضبط (لإعادة استخدام العنصر من الـ Pool)
func reset_health() -> void:
	health = max_health
