extends GutTest
## DamageData：统一伤害载体。短路/钳制责任在 HealthComponent，此处只测构造与默认值。

func test_default_amount_is_one() -> void:
	var d := DamageData.new()
	assert_eq(d.amount, 1)
	assert_null(d.source)


func test_init_sets_amount_and_source() -> void:
	var d := DamageData.new(5)
	assert_eq(d.amount, 5)


func test_negative_or_zero_amount_is_stored_as_given() -> void:
	# DamageData 不拦截非法数值；是否生效由 HealthComponent 短路保证。
	assert_eq(DamageData.new(0).amount, 0)
	assert_eq(DamageData.new(-3).amount, -3)
