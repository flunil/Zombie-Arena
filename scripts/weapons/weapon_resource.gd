extends Resource
class_name WeaponResource
## بيانات السلاح — طبقة DATA: مصدر واحد للحقيقة (قابل لحفظه كـ .tres)

@export var weapon_id: String = "ak47"
@export var display_name: String = "AK-47"
@export var damage: float = 25.0        # ضرر الرصاصة الواحدة
@export var fire_rate: float = 10.0     # طلقة/ثانية
@export var ammo_max: int = 30          # الذخيرة القصوى
@export var reload_time: float = 2.0    # زمن إعادة التعبئة بالثواني
@export var spread: float = 0.02        # انتشار بالراديان
@export var max_range: float = 10.0     # المدى (range) — مقيّد5..15
@export var bullet_speed: float = 30.0  # سرعة الرصاصة وحدة/ثانية
@export var pellets: int = 1             # طلقات لكل إطارة (Shotgun = 5)
@export var move_mult: float = 1.0       # مضاعف سرعة اللاعب (HeavyMG = 0.7)
@export var explosion_radius: float = 0.0  # نصف قطر الانفجار (Grenade 3 / Rocket 5)
@export var chain_targets: int = 0       # أهداف سلسلة التنين الكهربائي (Tesla = 3)
@export var pierce: int = 0              # عدد اختراق الرصاص (Laser)
@export var poison_radius: float = 0.0   # نصف قطر المنطقة السامة (Smoke = 5)
@export var poison_time: float = 0.0     # مدة المنطقة بالثواني (5)
@export var poison_dps: float = 0.0      # ضرر المنطقة للثانية (5)
@export var bullet_color: Color = Color(1, 0.9, 0.85, 1)  # لون الطلقة
@export var bullet_scale: float = 1.0    # حجم الطلقة
@export var unlock_wave: int = 1         # الموجة التي يُفتح فيها السلاح
