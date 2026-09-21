class_name Hurtbox
extends Area2D

## 受击判定盒（实体上的 Area2D）。收到 Hitbox 命中时发 hit_received。
## 组件不反向引用实体：实体在 _ready 订阅本信号再决定扣血/受击表现。

signal hit_received(damage: DamageData)


func take_hit(damage: DamageData) -> void:
	if damage == null or damage.amount <= 0:
		return
	# 能力钩（D15/2f 道具数值引擎）：伤害源若提供 modify_outgoing_damage（如玩家带暴击/吸血），
	# 先经它重算最终伤害再发。无钩 = 原样（旧行为不变，向后兼容近战/远程/接触全链路）。
	var amount := damage.amount
	var src = damage.source
	if src != null and src.has_method("modify_outgoing_damage"):
		amount = src.call("modify_outgoing_damage", amount)
		if amount <= 0:
			return
	hit_received.emit(DamageData.new(amount, damage.source))
	# 命中通知钩（D15/2g-1 引擎，规格 §6 触发道具依赖）：伤害源若提供 on_hit_enemy（如带荆棘反伤/
	# 冰霜新星/复仇者炮台计数），结算后通知 受害敌根节点 + 最终伤害。无钩 = 零开销，向后兼容。
	if src != null and src.has_method("on_hit_enemy"):
		src.on_hit_enemy(get_parent(), amount)
