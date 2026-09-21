class_name DamageData
extends Resource

## 统一伤害载体（DNF 式命中数据的切片最小版）。
## 所有扣血必须经 HealthComponent.take_damage(DamageData)，
## 禁止在战斗逻辑里裸写 health -= n。

## 伤害数值。<=0 视为无效伤害（不触发扣血）。
@export var amount: int = 1

## 来源节点（命中者/技能施放者），运行期注入，可为空。
var source: Node = null


func _init(p_amount: int = 1, p_source: Node = null) -> void:
	amount = p_amount
	source = p_source
