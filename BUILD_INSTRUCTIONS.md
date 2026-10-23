

```markdown
# BUILD_INSTRUCTIONS.md — Zombie Arena 3D
> لعبة Top-Down 3D Shooter ضد حشود الزومبي — Godot 4.3+ — للهاتف
> **هذا الملف تعليمات بناء صارمة. اتبع كل مرحلة بالترتيب. لا تتخطَّ أي مرحلة.**

---

## 🧭 قواعد عامة إلزامية للوكيل (اقرأها قبل البدء)

1. **لا تتخطَّ مرحلة أبداً.** كل مرحلة تعتمد على التي قبلها.
2. **بعد إتمام كل مرحلة، توقف فوراً** ونفّذ "قائمة التحقق" الخاصة بها.
3. إذا فشل بند واحد من قائمة التحقق → **أصلحه قبل الانتقال**.
4. إذا نجحت كل البنود → اكتب تقريراً قصيراً: `✅ المرحلة X مكتملة` ثم انتقل للتالية.
5. **لا تضف ميزات من مراحل لاحقة** أثناء العمل على مرحلة حالية (تجنب Scope Creep).
6. التزم بالبنية المقترحة للملفات في نهاية الملف.
7. استخدم **GDScript** فقط (لا C#).
8. راعِ **الأداء على الهاتف** في كل قرار.
9. اللغة داخل الكود: **إنجليزية**. التعليقات: **عربية مختصرة**.
10. اختم كل مرحلة بجملة: `STATUS: PHASE_X_DONE — AWAITING_USER_CONFIRMATION`

---

## 🎯 نظرة عامة على اللعبة

| العنصر | التفصيل |
|---|---|
| النوع | Top-Down 3D Horde Shooter |
| المنصة | Android / iOS |
| المحرك | Godot 4.3+ (Forward+ للديسكتوب، Mobile للهاتف) |
| التحكم | عصا يسار + إطلاق تلقائي يمين |
| الأسلحة | 9 أسلحة (AK-47 افتراضي) |
| الزومبي | 6 أنواع |
| الجمهور | 8+ (بدون دماء، كرتوني) |

---

# 🔹 المرحلة 0 — تهيئة المشروع

## 🎯 الهدف
إنشاء هيكل مشروع Godot نظيف وجاهز.

## 📦 المخرجات
- مشروع Godot 4.3 باسم `ZombieArena3D`
- إعدادات `project.godot`:
  - Renderer: `mobile` للهاتف
  - Physics: Jolt أو Godot Physics
  - Input Map: `move_left`, `move_right`, `move_up`, `move_down`, `shoot`, `switch_weapon`
- إنشاء المجلدات:
  ```
  res://
	scenes/
	  main/
	  player/
	  enemies/
	  weapons/
	  ui/
	scripts/
	  player/
	  enemies/
	  weapons/
	  systems/
	assets/
	  models/
	  textures/
	  audio/
	  fonts/
	resources/
  ```
- ملف `README.md` بسيط

## ✅ قائمة التحقق
- [ ] المشروع يفتح بدون أخطاء
- [ ] كل المجلدات موجودة
- [ ] Input Map مُعرَّف بكل الأزرار
- [ ] `project.godot` يحتوي على renderer = mobile

## 🚦 شرط الانتقال
كل البنود ✅ → انتقل للمرحلة 1.

---

# 🔹 المرحلة 1 — الساحة واللاعب (بدون قتال)

## 🎯 الهدف
لاعب مكعب يتحرك في ساحة مفتوحة بمنظور Top-Down.

## 📦 المخرجات
- `scenes/main/Arena.tscn`:
  - Plane أرضية 50×50 (رملي)
  - 4 جدران محيطة
  - إضاءة DirectionalLight3D مائلة
  - WorldEnvironment بسيط
- `scenes/player/Player.tscn`:
  - CharacterBody3D
  - CapsuleMesh (مؤقت)
  - Camera3D **بمنظور علوي مائل** (~70°)
  - CollisionShape3D
- `scripts/player/player.gd`:
  - حركة 8 اتجاهات عبر `move_*` actions
  - سرعة 8 وحدة/ثانية
  - يتحرك نسبةً لاتجاه الكاميرا
- `scripts/player/player_camera.gd`:
  - كاميرا تتبع اللاعب (Top-Down مائل، ثابتة الدوران)

## ✅ قائمة التحقق
- [ ] اللاعب يتحرك في 8 اتجاهات بالكيبورد
- [ ] الكاميرا تتبع اللاعب بسلاسة
- [ ] لا يمكن الخروج من الساحة (الجدران تصد)
- [ ] الأداء 60 FPS

## 🚦 شرط الانتقال
كل البنود ✅ + `STATUS: PHASE_1_DONE`.

---

# 🔹 المرحلة 2 — سلاح AK-47 والرماية

## 🎯 الهدف
اللاعب يطلق النار بشكل تلقائي، ويقتل أهدافاً وهمية.

## 📦 المخرجات
- `scenes/weapons/AK47.tscn` + `scripts/weapons/ak47.gd`:
  - `WeaponResource` (Resource مخصص) يحتوي: damage, fire_rate, ammo_max, reload_time, spread, range
  - يطلق RayCast3D من مركز اللاعب نحو اتجاه الحركة الأخير
  - معدل نار: 10 طلقة/ثانية
  - ضرر: 25
- `scenes/weapons/Bullet.tscn` (اختياري بدل RayCast):
  - Area3D يتحرك للأمام
  - يصطدم بالهدف → يطبّق ضرر → يختفي
- HUD بسيط يعرض: الذخيرة الحالية / الحد الأقصى
- زر `shoot` في Input Map → إطلاق تلقائي مستمر عند الضغط
- إعادة تعبئة تلقائية عند نفاذ الذخيرة

## ✅ قائمة التحقق
- [ ] الضغط على `shoot` يطلق النار باستمرار
- [ ] الذخيرة تنقص
- [ ] إعادة التعبئة تعمل
- [ ] عند إصابة هدف وهمي → يختفي + يؤثر على HUD (اختبار)
- [ ] الأداء مستقر مع 20 رصاصة متزامنة

## 🚦 شرط الانتقال
كل البنود ✅ + `STATUS: PHASE_2_DONE`.

---

# 🔹 المرحلة 3 — الزومبي الأساسي (Basic AI)

## 🎯 الهدف
زومبي يتبع اللاعب ويؤذيه عند الاقتراب.

## 📦 المخرجات
- `scenes/enemies/ZombieBasic.tscn` + `scripts/enemies/zombie_base.gd`:
  - CharacterBody3D
  - HealthComponent (script منفصل: `scripts/systems/health_component.gd`)
  - NavigationAgent3D لتتبع اللاعب
  - CapsuleMesh ملون بالأخضر
- سلوك:
  - إذا اللاعب ضمن 20 وحدة → يتحرك نحوه
  - إذا وصل إلى 1.5 وحدة → يضرب كل 1 ثانية (ضرر 10)
- عند الموت → يختفي + يُسقط 10 ذهباً (متغير فقط حالياً)
- HealthComponent:
  - إشارة `died` تُبث عند نهاية الصحة

## ✅ قائمة التحقق
- [ ] الزومبي يتبع اللاعب
- [ ] عند ملامسة اللاعب → يظهر نقص في HP اللاعب
- [ ] عند موت الزومبي → يختفي
- [ ] الأداء مع 20 زومبي ≥ 55 FPS

## 🚦 شرط الانتقال
كل البنود ✅ + `STATUS: PHASE_3_DONE`.

---

# 🔹 المرحلة 4 — نظام الموجات + Object Pooling

## 🎯 الهدف
موجات متزايدة الصعوبة + أداء مستقر.

## 📦 المخرجات
- `scripts/systems/wave_manager.gd`:
  - يبدأ الموجة 1 بعد 5 ثوان عد تنازلي
  - كل موجة: `count = 5 + (wave * 3)` زومبي
  - يوزع الزومبي على أطراف الساحة
  - عند قتل كل الزومبي → 5 ثوان راحة → الموجة التالية
  - يبث إشارات: `wave_started(wave_num)`, `wave_cleared(wave_num)`
- `scripts/systems/object_pool.gd`:
  - Pool للزومبي والرصاص
  - `get_instance()` / `return_instance()`
- `scripts/systems/game_manager.gd`:
  - Singleton (Autoload)
  - يتابع الحالة: Playing / WaveCleared / GameOver
- ساحة: إضافة `NavigationRegion3D` مع `NavigationMesh` محدّث

## ✅ قائمة التحقق
- [ ] الموجة تبدأ تلقائياً
- [ ] عدد الزومبي يزيد كل موجة
- [ ] عند موت كل الزومبي → تظهر الموجة التالية
- [ ] Object Pooling يعمل (لا `queue_free()` مباشر)
- [ ] 60 FPS مع 40 زومبي

## 🚦 شرط الانتقال
كل البنود ✅ + `STATUS: PHASE_4_DONE`.

---

# 🔹 المرحلة 5 — HUD وواجهة المستخدم + الموت

## 🎯 الهدف
واجهة واضحة للاعب + شاشة موت + إعادة.

## 📦 المخرجات
- `scenes/ui/HUD.tscn`:
  - شريط HP (ProgressBar)
  - الذخيرة
  - رقم الموجة
  - عداد الذهب
- `scenes/ui/GameOverScreen.tscn`:
  - "انتهت اللعبة"
  - عدد الموجات المكتملة
  - إجمالي القتلى
  - الذهب المُكتسب
  - زر "العب مرة أخرى"
- `scenes/ui/MainMenu.tscn`:
  - زر "ابدأ"
  - زر "إعدادات"
  - زر "خروج"
- `scripts/systems/scene_transition.gd`:
  - انتقال سلس بين المشاهد

## ✅ قائمة التحقق
- [ ] HUD يعرض كل القيم بشكل صحيح
- [ ] عند موت اللاعب → تظهر شاشة GameOver
- [ ] زر "العب مرة أخرى" يعيد التشغيل
- [ ] MainMenu تفتح Arena

## 🚦 شرط الانتقال
كل البنود ✅ + `STATUS: PHASE_5_DONE`.

---

# 🔹 المرحلة 6 — الأسلحة التسعة

## 🎯 الهدف
تنفيذ كل الأسلحة التسعة مع نظام تبديل + نظام فتح.

## 📦 المخرجات
- `resources/weapons/` تحتوي 9 ملفات `.tres`:
  | السلاح | damage | fire_rate | ammo | special |
  |---|---|---|---|---|
  | AK47 | 25 | 10 | 30 | — |
  | Shotgun | 15×5 | 2 | 8 | spread واسع |
  | HeavyMG | 20 | 15 | 100 | بطء حركة 30% |
  | GrenadeLauncher | 80 | 1.5 | 6 | انفجار 3m |
  | Flamethrower | 8/ث | مستمر | 200 | مدى 4m |
  | TeslaCoil | 30 | 3 | 50 | سلسلة 3 أهداف |
  | RocketLauncher | 150 | 0.8 | 4 | انفجار 5m |
  | SmokeLauncher | 5/ث | 1 | 10 | منطقة سامة 5m/5s |
  | LaserRifle | 40 | مستمر | 100 | اختراق خطي |

- `scripts/weapons/weapon_manager.gd`:
  - يدير السلاح الحالي
  - `switch_weapon(index)` — يمكن ربطها بأزرار UI
- `scripts/systems/unlock_system.gd`:
  - `unlock_weapon(weapon_id)` — يفتح السلاح
  - يُستدعى عند بلوغ Wave 3/5/7/8/9/10/11/12
- UI: أزرار تبديل الأسلحة المفتوحة (4 أزرار max على الشاشة)

## ✅ قائمة التحقق
- [ ] كل سلاح يطلق بشكل مميز
- [ ] الانفجارات تعمل (Grenade/Rocket)
- [ ] الليزر يخترق
- [ ] اللهب يعمل بشكل مستمر
- [ ] تبديل الأسلحة سلس
- [ ] لا يوجد سلاح يفتح قبل شرطه
- [ ] الأداء مستقر مع 60 زومبي + لهب + انفجارات

## 🚦 شرط الانتقال
كل البنود ✅ + `STATUS: PHASE_6_DONE`.

---

# 🔹 المرحلة 7 — أنواع الزومبي الستة

## 🎯 الهدف
تنويع الأعداء لتحدي أكبر.

## 📦 المخرجات
- `scenes/enemies/ZombieRunner.tscn` — سريع، HP 70
- `scenes/enemies/ZombieBrute.tscn` — ضخم، HP 300، ضرب قوي
- `scenes/enemies/ZombieExploder.tscn` — HP 80، ينفجر عند الموت (area 2.5m، damage 40)
- `scenes/enemies/ZombieShield.tscn` — HP 200، درع أمامي يصد الرصاص
- `scenes/enemies/ZombieBoss.tscn` — HP 1000، يستدعي 3 زومبي كل 5 ثوان
- `scripts/systems/enemy_factory.gd`:
  - يوزع الأنواع حسب الموجة:
	- Wave 1–3: Basic فقط
	- Wave 4–6: + Runner
	- Wave 7–9: + Exploder
	- Wave 10–12: + Shield
	- Wave 13+: + Brute
	- كل 5 موجات: Boss

## ✅ قائمة التحقق
- [ ] كل نوع يظهر في الموجة الصحيحة
- [ ] سلوك كل نوع يختلف فعلياً
- [ ] انفجار المتفجر يضر اللاعب والزومبي
- [ ] درع الزومبي يصد الرصاص من الأمام فقط
- [ ] الزعيم يستدعي زومبي
- [ ] 60 FPS مع 40 زومبي متنوع

## 🚦 شرط الانتقال
كل البنود ✅ + `STATUS: PHASE_7_DONE`.

---

# 🔹 المرحلة 8 — الترقيات داخل الموجة

## 🎯 الهدف
بعد كل موجة → 3 خيارات ترقية عشوائية.

## 📦 المخرجات
- `resources/upgrades/` — 12 ملف `.tres`:
  - DamageBoost (+15%)
  - FireRateBoost (+12%)
  - AmmoBoost (+25%)
  - Piercing (اختراق عدو إضافي)
  - Freeze (10% chance slow)
  - ExplosiveRounds (rصاص ينفجر)
  - AutoHeal (+2 HP/s)
  - EnergyShield (+30 shield)
  - DeathExplosion (الأعداء ينفجرون)
  - SecondWeapon (سلاح ثانوي مؤقت)
  - DroneAlly (روبوت يحارب معك)
  - TimeSlow (-30% سرعة 5 ثوان)
- `scenes/ui/UpgradeSelection.tscn`:
  - 3 بطاقات، كل واحدة تعرض: أيقونة، اسم، وصف
  - عند الاختيار → تطبيق فوري + إغلاق + بدء الموجة التالية
- `scripts/systems/upgrade_manager.gd`:
  - `apply_upgrade(upgrade_id)`
  - يختار 3 عشوائياً من المتاح

## ✅ قائمة التحقق
- [ ] تظهر 3 خيارات بعد كل موجة
- [ ] الاختيار يُطبَّق فوراً على اللاعب
- [ ] لا تظهر ترقيات مكررة في نفس الشاشة
- [ ] TimeSlow يعمل فعلياً
- [ ] DroneAlly يتبع اللاعب ويهاجم

## 🚦 شرط الانتقال
كل البنود ✅ + `STATUS: PHASE_8_DONE`.

---

# 🔹 المرحلة 9 — الترقيات الدائمة وحفظ التقدم

## 🎯 الهدف
تقدّم دائم يبقى بين الجلسات.

## 📦 المخرجات
- `scripts/systems/save_system.gd` (Autoload):
  - حفظ/تحميل من `user://save.dat`
  - البيانات: gold, gems, unlocked_weapons[], permanent_upgrades{}, stats{}, last_login_date, login_streak
  - تشفير بسيط (بدون تعقيد)
- `scenes/ui/MetaUpgradeShop.tscn`:
  - 4 مسارات دائمة:
	- Health: 5 مستويات (+20 HP لكل)
	- Speed: 5 مستويات (+5%)
	- Damage: 5 مستويات (+10%)
	- Ammo: 5 مستويات (+15%)
  - كل مستوى له تكلفة بالذهب
- `scripts/systems/stats_tracker.gd`:
  - يتتبع: total_kills, total_waves, total_gold_earned, accuracy, playtime

## ✅ قائمة التحقق
- [ ] التقدم يُحفظ عند الإغلاق
- [ ] التقدم يُستعاد عند الفتح
- [ ] الترقيات الدائمة تؤثر فعلياً في اللعب
- [ ] المتجر يمنع الشراء عند عدم وجود ذهب كافٍ
- [ ] الإحصائيات تتراكم بشكل صحيح

## 🚦 شرط الانتقال
كل البنود ✅ + `STATUS: PHASE_9_DONE`.

---

# 🔹 المرحلة 10 — الأنظمة اليومية (الإدمان الأخلاقي)

## 🎯 الهدف
مهام يومية + صندوق يومي + سلسلة أيام.

## 📦 المخرجات
- `scripts/systems/daily_system.gd`:
  - يتحقق من التاريخ عند كل بدء تشغيل
  - إذا تغيّر اليوم → يُصفّر المهام + يمنح الصندوق
  - يحسب `login_streak`
- `scripts/systems/mission_system.gd`:
  - 3 مهام يومية من قائمة:
	- "اقتل 50 زومبي"
	- "أكمل 3 موجات"
	- "اجمع 1000 ذهب"
	- "اقتل 5 زعماء"
	- "أكمل موجة بدون ضرر"
  - تتبع التقدم تلقائياً
  - عند الإكمال → منح جواهر
- `scenes/ui/DailyReward.tscn`:
  - 7 أيام، اليوم الحالي مُظلَّل
  - المكافآت معروفة مسبقاً (شفافية)
- `scenes/ui/MissionPanel.tscn`:
  - عرض المهام اليومية الثلاث + تقدمها

## ✅ قائمة التحقق
- [ ] الصندوق يظهر مرة واحدة يومياً فقط
- [ ] المهام تتتبع بشكل صحيح
- [ ] Streak يزيد مع كل يوم متتالٍ
- [ ] Streak لا يُصفَّر عند يوم انقطاع واحد فقط (يُصفَّر بعد يومين)
- [ ] كل شيء يعمل بعد إعادة تشغيل اللعبة

## 🚦 شرط الانتقال
كل البنود ✅ + `STATUS: PHASE_10_DONE`.

---

# 🔹 المرحلة 11 — المؤثرات البصرية والصوتية

## 🎯 الهدف
إحساس لعبة احترافية.

## 📦 المخرجات
- **VFX**:
  - `MuzzleFlash` لكل سلاح
  - `ImpactEffect` عند إصابة عدو أو جدار
  - `ExplosionEffect` للقنابل والصواريخ
  - `BloodlessDeathEffect` (جزيئات خضراء بدل الدم)
  - `LevelUpEffect` عند الترقية
- **SFX**:
  - صوت لكل سلاح
  - صوت موت زومبي (كوميدي)
  - صوت اختيار ترقية
  - صوت بداية موجة
  - صوت نهاية موجة
- **موسيقى**:
  - Menus loop
  - Arena loop (يتصاعد مع الموجة)
- **Screen Shake** خفيف عند:
  - الانفجارات
  - استقبال ضرر
- **Hit Flash**: العدو يومض بالأبيض عند الإصابة

## ✅ قائمة التحقق
- [ ] كل سلاح له صوت ومؤثر
- [ ] لا أصوات صادمة (>5kHz)
- [ ] لا دماء (استخدام جزيئات خضراء)
- [ ] Screen shake خفيف، لا يُسبب دوار
- [ ] الأداء لا ينخفض

## 🚦 شرط الانتقال
كل البنود ✅ + `STATUS: PHASE_11_DONE`.

---

# 🔹 المرحلة 12 — تحسين الأداء والهاتف

## 🎯 الهدف
اللعبة تعمل بسلاسة على هاتف متوسط.

## 📦 المخرجات
- **إعدادات Mobile في project.godot**:
  - Forward+ → Mobile renderer
  - Shadow quality منخفض
  - MSAA معطّل
- **تحسينات**:
  - استخدام `MultiMeshInstance3D` إذا أمكن
  - LOD يدوي للزومبي البعيدين
  - تقليل عدد أضواء الظل إلى 1
  - ضغط textures
- **تحكم لمس**:
  - `TouchScreenButton` أو `VirtualJoystick` مخصص
  - زر إطلاق على اليمين
  - أزرار تبديل السلاح
  - تكبير الأزرار لـ 44px+
- **اختبار**: تصدير APK وتشغيله على هاتف فعلي

## ✅ قائمة التحقق
- [ ] APK يُبنى ويُثبَّت
- [ ] التحكم يعمل باللمس
- [ ] 30+ FPS على هاتف متوسط
- [ ] لا تعطل خلال 30 دقيقة لعب
- [ ] استهلاك البطارية معقول

## 🚦 شرط الانتقال
كل البنود ✅ + `STATUS: PHASE_12_DONE`.

---

# 🔹 المرحلة 13 — اللمسات النهائية

## 🎯 الهدف
لعبة جاهزة للإصدار.

## 📦 المخرجات
- **إعدادات**:
  - صوت (Master/Music/SFX)
  - تحكم (إطلاق تلقائي / يدوي)
  - إشعارات on/off
  - لغة (عربي/إنجليزي إن أمكن)
- **حماية أخلاقية**:
  - رسالة "خذ استراحة" بعد 30 دقيقة
  - فلترة الإشعارات (مرة/يوم)
- **إشعارات Push** (اختياري): "الحشد يقترب!"
- **Icon & Splash Screen**
- **سياسة خصوصية** بسيطة
- **بيانات المتجر**: وصف، لقطات شاشة، فيديو

## ✅ قائمة التحقق
- [ ] كل الإعدادات تعمل
- [ ] الإشعارات تُوقَف بضغطة
- [ ] رسالة الاستراحة تظهر بعد 30 دقيقة
- [ ] الأيقونة واضحة
- [ ] التصنيف العمري = 7+

## 🚦 شرط الانتقال
كل البنود ✅ + `STATUS: PHASE_13_DONE — GAME READY FOR RELEASE`.

---

# 📋 بروتوكول التحقق الذاتي (إلزامي بعد كل مرحلة)

بعد إتمام أي مرحلة، **قبل الانتقال للتالية**، نفّذ هذا التسلسل بالضبط:

```
1. STOP CODING.
2. اقرأ وصف المرحلة الحالية.
3. افتح قائمة التحقق.
4. لكل بند:
   - شغّل اللعبة
   - اختبر البند يدوياً أو عبر اختبار مؤقت
   - اكتب: ✅ PASSED أو ❌ FAILED
5. إذا كان هناك ❌:
   - أصلح المشكلة
   - أعد الاختبار
   - كرر حتى ✅
6. إذا كانت كلها ✅:
   - احفظ commit باسم: "phase-X-complete"
   - اطبع: "STATUS: PHASE_X_DONE — AWAITING_USER_CONFIRMATION"
   - توقف وانتظر تأكيد المستخدم.
```

**لا تنتقل لمرحلة جديدة قبل أن يكتب المستخدم: `GO AHEAD`**

---

# 🗂️ البنية النهائية للملفات (مرجع)

```
res://
├── project.godot
├── BUILD_INSTRUCTIONS.md
├── README.md
├── scenes/
│   ├── main/
│   │   ├── MainMenu.tscn
│   │   └── Arena.tscn
│   ├── player/
│   │   └── Player.tscn
│   ├── enemies/
│   │   ├── ZombieBasic.tscn
│   │   ├── ZombieRunner.tscn
│   │   ├── ZombieBrute.tscn
│   │   ├── ZombieExploder.tscn
│   │   ├── ZombieShield.tscn
│   │   └── ZombieBoss.tscn
│   ├── weapons/
│   │   ├── AK47.tscn
│   │   ├── Shotgun.tscn
│   │   ├── ... (7 أخرى)
│   │   └── Bullet.tscn
│   └── ui/
│       ├── HUD.tscn
│       ├── MainMenu.tscn
│       ├── GameOverScreen.tscn
│       ├── UpgradeSelection.tscn
│       ├── DailyReward.tscn
│       ├── MissionPanel.tscn
│       └── MetaUpgradeShop.tscn
├── scripts/
│   ├── player/
│   │   ├── player.gd
│   │   └── player_camera.gd
│   ├── enemies/
│   │   └── zombie_base.gd
│   ├── weapons/
│   │   ├── weapon_base.gd
│   │   └── weapon_manager.gd
│   └── systems/
│       ├── game_manager.gd (Autoload)
│       ├── save_system.gd (Autoload)
│       ├── wave_manager.gd
│       ├── object_pool.gd
│       ├── upgrade_manager.gd
│       ├── daily_system.gd
│       ├── mission_system.gd
│       ├── stats_tracker.gd
│       ├── enemy_factory.gd
│       ├── unlock_system.gd
│       ├── health_component.gd
│       └── scene_transition.gd
├── resources/
│   ├── weapons/*.tres (9)
│   └── upgrades/*.tres (12)
└── assets/
	├── models/
	├── textures/
	├── audio/
	│   ├── sfx/
	│   └── music/
	└── fonts/
```

---

# 🎨 قيود فنية إلزامية (طوال المشروع)

| القيد | التفصيل |
|---|---|
| ❌ لا دماء | استخدم جزيئات خضراء / دخان |
| ❌ لا أصوات صادمة | < 5kHz، لا رعب |
| ❌ لا Loot Boxes | ممنوع تماماً |
| ❌ لا إعلانات إجبارية | فقط Rewarded اختيارية |
| ✅ تحكم بيد واحدة ممكن | الإطلاق التلقائي افتراضي |
| ✅ أزرار ≥ 44×44 px | للهاتف |
| ✅ 60 FPS هدف، 30 حد أدنى | على الأجهزة المتوسطة |

---

# 🛑 ممنوعات صارمة على الوكيل

1. لا تستخدم `queue_free()` على الزومبي — استخدم ObjectPool.
2. لا تُنشئ مشهداً عملاقاً — قسّم إلى components.
3. لا تستخدم C# — GDScript فقط.
4. لا تضف ميزات من مرحلة لاحقة أثناء عمل مرحلة حالية.
5. لا تتخطَّ قائمة التحقق أبداً.
6. لا تنتقل لمرحلة جديدة بدون كتابة المستخدم: `GO AHEAD`.

---

# ✅ نقطة البداية

ابدأ الآن بـ **المرحلة 0**. عندما تنتهي، اطبع:

```
STATUS: PHASE_0_DONE — AWAITING_USER_CONFIRMATION
```

ثم **توقف** وانتظر حتى يكتب المستخدم `GO AHEAD`.

---

> **ملاحظة أخيرة:** إذا واجهت غموضاً في أي مرحلة، **اسأل المستخدم قبل التنفيذ**.
> لا تخمّن. الوضوح أهم من السرعة.
```

---
