class_name Hitbox
extends Area2D

## 攻击判定盒（玩家攻击时活动的 Area2D）。挂在攻击者上。
## 命中规则：与目标 Hurtbox 的 Area2D 面积重叠 → hurtbox.take_hit()。
## 活动窗口由攻击者状态机控制（防幽灵命中）：只在 activate()~deactivate() 期间判定。

## 本盒单次攻击伤害。
@export var damage_amount: int = 1

## 攻击者（DamageData.source 用），默认取父节点。
var source_node: Node


func _ready() -> void:
	if source_node == null:
		source_node = get_parent()
	monitoring = false
	area_entered.connect(_on_area_entered)


## 开启命中判定；补扫一次已重叠目标（贴脸起手不丢命中）。
func activate() -> void:
	monitoring = true
	for area: Area2D in get_overlapping_areas():
		_on_area_entered(area)


## 关闭命中判定。
func deactivate() -> void:
	monitoring = false


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox != null:
		hurtbox.take_hit(DamageData.new(damage_amount, source_node))
