extends Control
## Spike D4: data-driven shop UI builder. Throwaway — validates the
## "AI design -> data-driven Godot controls" route end to end.

const ITEMS := [
	{"name": "能量护盾", "icon": "res://assets/_spike/shop/item_0.png", "stats": [["护甲", "+5"], ["元素伤害", "+4"]], "price": 128},
	{"name": "手枪", "icon": "res://assets/_spike/shop/item_1.png", "stats": [["攻击力", "+8"], ["暴击率", "+6%"]], "price": 128},
	{"name": "铁头盔", "icon": "res://assets/_spike/shop/item_2.png", "stats": [["最大生命", "+12"], ["伤害减免", "+2"]], "price": 128},
	{"name": "炸弹", "icon": "res://assets/_spike/shop/item_3.png", "stats": [["暴击伤害", "+5%"], ["元素伤害", "+4"]], "price": 128},
]

const OWNED := [
	{"icon": "res://assets/_spike/shop/wpn_0.png"},
	{"icon": "res://assets/_spike/shop/wpn_1.png"},
	{"icon": "res://assets/_spike/shop/wpn_2.png"},
	{"icon": "res://assets/_spike/shop/wpn_3.png"},
	{"icon": "res://assets/_spike/shop/wpn_6.png"},
	{"icon": "res://assets/_spike/shop/wpn_7.png"},
]

const STAT_GROUPS := [
	{"title": "基础属性", "rows": [["最大生命", "+12"], ["攻击力", "+8"], ["护甲", "+3"]]},
	{"title": "战斗属性", "rows": [["移动速度", "+4%"], ["暴击率", "+6%"], ["暴击伤害", "+5%"], ["元素伤害", "+4"]]},
	{"title": "生存属性", "rows": [["伤害减免", "+2"], ["生命回复", "+2"], ["技能冷却缩减", "+5%"]]},
	{"title": "元素属性", "rows": [["火焰伤害", "+3"], ["冰霜伤害", "+3"], ["闪电伤害", "+3"], ["毒素抗性", "+4"]]},
]

@onready var _cards_row: HBoxContainer = %CardsRow
@onready var _slots_row: HBoxContainer = %SlotsRow
@onready var _stat_list: VBoxContainer = %StatList


func _ready() -> void:
	for item: Dictionary in ITEMS:
		_cards_row.add_child(_build_card(item))
	for wpn: Dictionary in OWNED:
		_slots_row.add_child(_build_slot(wpn))
	for group: Dictionary in STAT_GROUPS:
		_stat_list.add_child(_build_group(group))


func _build_card(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"ShopCard"
	card.custom_minimum_size = Vector2(270, 400)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)

	var icon := TextureRect.new()
	icon.texture = load(item["icon"])
	icon.custom_minimum_size = Vector2(120, 120)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)

	var name_label := Label.new()
	name_label.text = item["name"]
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)

	for stat: Array in item["stats"]:
		var row := HBoxContainer.new()
		var key := Label.new()
		key.text = str(stat[0])
		key.add_theme_font_size_override("font_size", 20)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val := Label.new()
		val.text = str(stat[1])
		val.add_theme_font_size_override("font_size", 20)
		row.add_child(key)
		row.add_child(val)
		box.add_child(row)

	var price_row := HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 10)
	box.add_child(price_row)

	var price_btn := Button.new()
	price_btn.text = "%d" % item["price"]
	price_btn.theme_type_variation = &"BtnBlue"
	price_btn.focus_mode = Control.FOCUS_NONE
	price_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_row.add_child(price_btn)

	var lock_btn := TextureButton.new()
	lock_btn.texture_normal = load("res://assets/_spike/shop/lock_btn.png")
	lock_btn.ignore_texture_size = true
	lock_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	lock_btn.custom_minimum_size = Vector2(56, 56)
	price_row.add_child(lock_btn)
	return card


func _build_slot(wpn: Dictionary) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.theme_type_variation = &"SlotPanel"
	slot.custom_minimum_size = Vector2(96, 96)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	slot.add_child(box)

	var icon := TextureRect.new()
	icon.texture = load(wpn["icon"])
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)

	var sell := Button.new()
	sell.text = "出售"
	sell.theme_type_variation = &"BtnRed"
	sell.add_theme_font_size_override("font_size", 16)
	sell.focus_mode = Control.FOCUS_NONE
	box.add_child(sell)
	return slot


func _build_group(group: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)

	var header := Label.new()
	header.theme_type_variation = &"GroupHeader"
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header.text = group["title"]
	box.add_child(header)

	for row: Array in group["rows"]:
		var row_box := HBoxContainer.new()
		row_box.custom_minimum_size = Vector2(0, 52)
		var key := Label.new()
		key.text = str(row[0])
		key.add_theme_font_size_override("font_size", 24)
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val := Label.new()
		val.text = str(row[1])
		val.add_theme_font_size_override("font_size", 24)
		val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row_box.add_child(key)
		row_box.add_child(val)
		box.add_child(row_box)
	return box
