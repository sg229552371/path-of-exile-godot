extends GutTest
## HealthComponent：唯一扣血/加血入口。

func _make_health(maximum: int = 10) -> HealthComponent:
	var h := HealthComponent.new()
	h.setup(maximum)
	add_child_autofree(h)
	return h


func test_take_damage_reduces_and_emits_changed() -> void:
	var h := _make_health(10)
	var changed: Array[int] = []
	var deaths := [0]
	h.health_changed.connect(func(v: int) -> void: changed.append(v))
	h.died.connect(func() -> void: deaths[0] += 1)

	h.take_damage(DamageData.new(3))

	assert_eq(h.current_health, 7)
	assert_eq(changed, [7])
	assert_eq(deaths[0], 0)


func test_overkill_clamps_at_zero_and_dies_once() -> void:
	var h := _make_health(5)
	var deaths := [0]
	h.died.connect(func() -> void: deaths[0] += 1)

	h.take_damage(DamageData.new(99))
	assert_eq(h.current_health, 0)
	assert_true(h.is_dead())
	assert_eq(deaths[0], 1)

	# 死后再次受伤不再触发 died。
	h.take_damage(DamageData.new(10))
	assert_eq(deaths[0], 1)
	assert_eq(h.current_health, 0)


func test_heal_caps_at_max() -> void:
	var h := _make_health(10)
	h.take_damage(DamageData.new(6))
	h.heal(100)
	assert_eq(h.current_health, 10)
	h.heal(3)
	assert_eq(h.current_health, 10)


func test_null_and_nonpositive_damage_are_noop() -> void:
	var h := _make_health(10)
	h.take_damage(null)
	h.take_damage(DamageData.new(0))
	h.take_damage(DamageData.new(-5))
	assert_eq(h.current_health, 10)


func test_heal_on_dead_is_noop() -> void:
	var h := _make_health(3)
	h.take_damage(DamageData.new(3))
	h.heal(5)
	assert_eq(h.current_health, 0)
