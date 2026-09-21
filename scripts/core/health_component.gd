class_name HealthComponent
extends Node

## 生命组件：全项目唯一的扣血/加血入口。
## 挂在玩家/敌人上；HUD 等只订阅 health_changed / died 信号，不反向引用。

signal health_changed(current: int)
signal died

## 生命上限。current_health 在 _ready（进场景树）或 setup() 时初始化为该值。
@export var max_health: int = 10

## -1 表示尚未初始化（未进树且未调用 setup）。
var current_health: int = -1


func _ready() -> void:
	if current_health < 0:
		current_health = max_health


## 显式初始化（测试/代码注入场景树前调用，保证确定性）。
func setup(maximum: int) -> void:
	max_health = maximum
	current_health = maximum


## 复活复位：回到满血（不改 max_health）。供对象池复用 / 重新生成前调用。
func reset() -> void:
	current_health = max_health


func is_dead() -> bool:
	return current_health == 0


## 唯一伤害入口。死亡/空伤害/无效伤害一律短路。
func take_damage(damage: DamageData) -> void:
	if current_health <= 0:
		return
	if damage == null or damage.amount <= 0:
		return
	current_health = maxi(current_health - damage.amount, 0)
	health_changed.emit(current_health)
	if current_health == 0:
		died.emit()


## 治疗（死亡实体不可复活）。
func heal(amount: int) -> void:
	if current_health <= 0 or amount <= 0:
		return
	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health)


## 只抬上限不补血（P3，D9.2：+最大生命升级项）。amount<=0 → 忽略。上限变化发一次 health_changed。
func raise_max(amount: int) -> void:
	if amount <= 0:
		return
	max_health += amount
	health_changed.emit(mini(current_health, max_health))
