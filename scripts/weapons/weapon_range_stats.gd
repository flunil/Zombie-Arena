extends Node3D
class_name WeaponRangeStats
## تحكّم بمدى السلاح وضرره من مشهد النموذج — يُطبَّق فوق weapon_data وقت التشغيل

@export_range(0, 300, 0.5, "or_greater") var damage: float = 0.0

## مدى السلاح: 10 خانات من 5م إلى 14م (السقف المسموح 15م) — يُخزَّن الفهرس لا القيمة
@export_enum("5m", "6m", "7m", "8m", "9m", "10m", "11m", "12m", "13m", "14m")
var range_slot: int = 5

## القيمة النهائية للمدى (5..14) — تُقرأ وقت التشغيل عبر weapon_base وتبقى داخل الحد 5-15
var max_range: float:
	get:
		return clampf(5.0 + float(range_slot), 5.0, 15.0)
