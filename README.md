# Zombie Arena 3D

لعبة Top-Down 3D Shooter ضد حشود الزومبي — مبنية بمحرك **Godot 4.6** (Mobile renderer، Jolt Physics).

## نظرة عامة

| العنصر | التفصيل |
|---|---|
| النوع | Top-Down 3D Horde Shooter |
| المنصة | Android / iOS |
| التحكم | عصا يسار + إطلاق تلقائي يمين |
| الأسلحة | 9 أسلحة (AK-47 افتراضي) |
| الزومبي | 6 أنواع |
| الجمهور | 8+ (بدون دماء، كرتوني) |

## بنية المشروع

```
res://
├── scenes/    (main, player, enemies, weapons, ui)
├── scripts/   (player, enemies, weapons, systems)
├── assets/    (models, textures, audio, fonts)
└── resources/ (weapons, upgrades)
```

## التحكم (Input Map)

| Action | المفاتيح |
|---|---|
| `move_up` / `move_down` / `move_left` / `move_right` | W/A/S/D + الأسهم |
| `shoot` | زر الفأرة الأيسر |
| `switch_weapon` | Q / E |

## مراحل البناء

يُبنى المشروع عبر مراحل متتابعة وفق `BUILD_INSTRUCTIONS.md`.
لا تُنقل مرحلة إلا بعد اجتياز قائمة التحقق الذاتية وكتابة:
`GO AHEAD`.

## التشغيل

افتح المجلد في Godot 4.6+ ثم شغّل المشروع (F5).
