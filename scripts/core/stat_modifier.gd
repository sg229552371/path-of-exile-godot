class_name StatModifier
extends RefCounted

## 单个属性修正（纯逻辑数据，可 GUT 直测）。
## 两模式：
##   FLAT    —— 加/减固定值（如 +10 攻击）。
##   PERCENT —— 百分比（如 +50% 攻速 → value=0.5），按 (1 + Σpct) 乘。
## source 携带来源引用（某把武器/某个 buff），供 StatModel 按来源整组移除。

enum Mode { FLAT, PERCENT }

## 目标属性名（StringName，如 &"attack"）。
var stat: StringName = &""
## 数值（FLAT 为绝对值；PERCENT 为小数，0.5 = +50%）。
var value: float = 0.0
## Mode.FLAT / Mode.PERCENT。
var mode: int = Mode.FLAT
## 来源引用（Object / 原始值均可），用于分组移除。
var source: Variant = null

## 由 StatModel.add_modifier 绑定的句柄；未绑定 = -1。
var _bound_id: int = -1


static func make_flat(p_stat: StringName, p_value: float, p_source: Variant = null) -> StatModifier:
	var m := StatModifier.new()
	m.stat = p_stat
	m.value = p_value
	m.mode = Mode.FLAT
	m.source = p_source
	return m


static func make_percent(p_stat: StringName, p_value: float, p_source: Variant = null) -> StatModifier:
	var m := StatModifier.new()
	m.stat = p_stat
	m.value = p_value
	m.mode = Mode.PERCENT
	m.source = p_source
	return m


func _to_string() -> String:
	var kind := "flat" if mode == Mode.FLAT else "pct"
	return "StatModifier(%s %s %s src=%s)" % [stat, kind, value, str(source)]
