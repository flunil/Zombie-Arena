extends Resource
class_name UpgradeResource
## ترقية داخل الموجة: معرّف + اسم/وصف عربي + لون أيقونة + قابلية التكرار

@export var upgrade_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_color: Color = Color.WHITE
@export var stackable: bool = true
## الندرة: 0 = عادي (أزرق 50%)، 1 = نادر (ذهبي 30%)، 2 = ممتاز (بنفسجي 20%)
@export var rarity: int = 0
