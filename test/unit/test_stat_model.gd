extends GutTest
## StatModel + StatModifier：base + flat/percent 修正的求值与 changed 信号。

const ATK := &"attack"
const SPD := &"speed"


func _model() -> StatModel:
	var m := StatModel.new()
	m.set_base(ATK, 10.0)
	return m


## 收集 changed 事件：records = [{stat, value}]。
func _capture(model: StatModel) -> Array:
	var records := []
	model.changed.connect(func(stat: StringName, value: float) -> void:
		records.append({"stat": stat, "value": value}))
	return records


func test_base_only() -> void:
	var m := StatModel.new()
	m.set_base(ATK, 10.0)
	assert_eq(m.get_value(ATK), 10.0)
	assert_eq(m.get_base(ATK), 10.0)


func test_unset_stat_defaults_zero() -> void:
	var m := StatModel.new()
	assert_eq(m.get_value(&"nonexistent"), 0.0)
	assert_eq(m.get_base(&"nonexistent"), 0.0)


func test_flat_modifiers_stack() -> void:
	var m := _model()
	m.add_modifier(StatModifier.make_flat(ATK, 5.0))
	m.add_modifier(StatModifier.make_flat(ATK, 3.0))
	assert_eq(m.get_value(ATK), 18.0)


func test_percent_modifiers_stack_multiplicatively() -> void:
	var m := _model()
	m.add_modifier(StatModifier.make_percent(ATK, 0.5))
	m.add_modifier(StatModifier.make_percent(ATK, 0.5))
	assert_eq(m.get_value(ATK), 20.0)  # 10 × (1+1.0)


func test_flat_and_percent_combine_by_formula() -> void:
	var m := _model()
	m.add_modifier(StatModifier.make_flat(ATK, 2.0))       # 12
	m.add_modifier(StatModifier.make_percent(ATK, 0.5))    # ×1.5 → 18
	assert_eq(m.get_value(ATK), 18.0)


func test_remove_by_handle_restores_base() -> void:
	var m := _model()
	var id := m.add_modifier(StatModifier.make_flat(ATK, 5.0))
	assert_eq(m.get_value(ATK), 15.0)
	m.remove_modifier(id)
	assert_eq(m.get_value(ATK), 10.0)
	assert_eq(m.modifier_count(), 0)


func test_remove_by_source_group() -> void:
	var m := _model()
	var sword := RefCounted.new()
	var boots := RefCounted.new()
	m.add_modifier(StatModifier.make_flat(ATK, 5.0, sword))
	m.add_modifier(StatModifier.make_percent(ATK, 0.5, sword))
	m.add_modifier(StatModifier.make_flat(SPD, 3.0, boots))
	assert_eq(m.modifiers_for_source(sword).size(), 2)
	var removed := m.remove_modifiers_from_source(sword)
	assert_eq(removed, 2)
	assert_eq(m.get_value(ATK), 10.0)  # sword 的修正整组消失
	assert_eq(m.get_value(SPD), 3.0)   # boots 的不受影响
	assert_eq(m.modifiers_for_source(boots).size(), 1)


func test_negative_values_are_debuffs() -> void:
	var m := _model()
	m.add_modifier(StatModifier.make_flat(ATK, -4.0))
	assert_eq(m.get_value(ATK), 6.0)
	m.add_modifier(StatModifier.make_percent(ATK, -0.5))
	assert_eq(m.get_value(ATK), 3.0)  # 6 × 0.5


func test_changed_emits_on_value_change() -> void:
	var m := StatModel.new()
	var records := _capture(m)
	m.set_base(ATK, 10.0)
	assert_eq(records.size(), 1)
	assert_eq(records[0].stat, ATK)
	assert_eq(records[0].value, 10.0)

	var id := m.add_modifier(StatModifier.make_flat(ATK, 5.0))
	assert_eq(records.size(), 2)
	assert_eq(records[1].value, 15.0)

	m.remove_modifier(id)
	assert_eq(records.size(), 3)
	assert_eq(records[2].value, 10.0)


func test_changed_not_emitted_when_no_change() -> void:
	var m := StatModel.new()
	var records := _capture(m)
	m.set_base(ATK, 10.0)   # 首次触发
	m.set_base(ATK, 10.0)   # 同值 → 不触发
	assert_eq(records.size(), 1)

	var id := m.add_modifier(StatModifier.make_flat(SPD, 0.0))  # 0 修正不改值
	assert_eq(records.size(), 1)
	m.remove_modifier(id)   # 移除 0 修正也不改值
	assert_eq(records.size(), 1)


func test_modifier_of_different_stat_does_not_affect_others() -> void:
	var m := _model()
	m.add_modifier(StatModifier.make_percent(SPD, 0.2))
	assert_eq(m.get_value(ATK), 10.0)  # SPD 的修正不碰 ATK
	assert_eq(m.get_value(SPD), 0.0)   # SPD 无 base → 仅自身修正基于 0 → 0
