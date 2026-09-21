class_name StatModel
extends RefCounted

## 数值属性模型（纯逻辑，可 GUT 直测）：任意"属性数值"的地基。
## 结构：base（基础值）+ 一组修正（StatModifier，flat 加减 / percent 百分比）。
## 求值公式：value = (base + Σflat) × (1 + Σpercent)
## 每实体建独立实例（勿共享模板串状态，呼应架构铁律#4）。
## 写操作（set_base / add / remove）后若结果变化，发 changed(stat, value)。

signal changed(stat: StringName, value: float)

## stat(StringName) -> base(float)。未设过的 base 视为 0。
var _base := {}
## 已绑定的修正列表。
var _mods: Array[StatModifier] = []
## 修正句柄分配器。
var _next_id := 0
## 求值缓存（stat -> float）；任何写操作失效对应键，get_value 惰性重算。
var _cache := {}


func set_base(stat: StringName, v: float) -> void:
	if _base.has(stat) and is_equal_approx(_base[stat], v):
		return
	var before := get_value(stat)
	_base[stat] = v
	_cache.erase(stat)
	var after := get_value(stat)
	if not is_equal_approx(before, after):
		changed.emit(stat, after)


## 未设过的 base 返回 0。
func get_base(stat: StringName) -> float:
	return _base.get(stat, 0.0)


## 登记一个修正；绑定新句柄并返回。mod 已绑定过 → push_warning 并返其既有句柄。
func add_modifier(mod: StatModifier) -> int:
	if mod == null:
		push_warning("StatModel.add_modifier: mod 为 null")
		return -1
	if mod._bound_id != -1:
		push_warning("StatModel.add_modifier: 该修正已绑定 (id=%d)，勿重复添加" % mod._bound_id)
		return mod._bound_id
	var before := get_value(mod.stat)
	mod._bound_id = _next_id
	_next_id += 1
	_mods.append(mod)
	_cache.erase(mod.stat)
	var after := get_value(mod.stat)
	if not is_equal_approx(before, after):
		changed.emit(mod.stat, after)
	return mod._bound_id


## 按句柄移除（add_modifier 的返回值）。无此句柄 → push_warning 并无操作。
func remove_modifier(id: int) -> void:
	var idx := _find_index(id)
	if idx == -1:
		push_warning("StatModel.remove_modifier: 无句柄 %d" % id)
		return
	var mod := _mods[idx]
	var stat := mod.stat
	var before := get_value(stat)
	_mods.remove_at(idx)
	mod._bound_id = -1
	_cache.erase(stat)
	var after := get_value(stat)
	if not is_equal_approx(before, after):
		changed.emit(stat, after)


## 列出绑定在某个来源上的全部修正（source 未设置(=null)的也会被匹配到）。
func modifiers_for_source(source: Variant) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	for mod in _mods:
		if _same_source(mod.source, source):
			out.append(mod)
	return out


## 整组移除某个来源的全部修正；返回移除条数。任一受影响的属性变化都发 changed。
func remove_modifiers_from_source(source: Variant) -> int:
	var removed: Array[StatModifier] = []
	for mod in _mods:
		if _same_source(mod.source, source):
			removed.append(mod)
	if removed.is_empty():
		return 0
	# 受影响属性 + 移除前取值快照。
	var affected := {}
	for mod in removed:
		affected[mod.stat] = get_value(mod.stat)
	for mod in removed:
		_mods.erase(mod)
		mod._bound_id = -1
		_cache.erase(mod.stat)
	for stat in affected:
		var after := get_value(stat)
		if not is_equal_approx(affected[stat], after):
			changed.emit(stat, after)
	return removed.size()


## 求最终值：(base + Σflat) × (1 + Σpercent)。带缓存，写操作后自动失效。
func get_value(stat: StringName) -> float:
	if _cache.has(stat):
		return _cache[stat]
	var flat := 0.0
	var pct := 0.0
	for mod in _mods:
		if mod.stat != stat:
			continue
		if mod.mode == StatModifier.Mode.FLAT:
			flat += mod.value
		else:
			pct += mod.value
	var v := (get_base(stat) + flat) * (1.0 + pct)
	_cache[stat] = v
	return v


## 属性当前生效的修正总条数（调试/测试用）。
func modifier_count() -> int:
	return _mods.size()


func _find_index(id: int) -> int:
	for i in _mods.size():
		if _mods[i]._bound_id == id:
			return i
	return -1


## source 匹配：对象按同一实例、非对象按 ==。
func _same_source(a: Variant, b: Variant) -> bool:
	if a is Object and b is Object:
		return is_same(a, b)
	return a == b
