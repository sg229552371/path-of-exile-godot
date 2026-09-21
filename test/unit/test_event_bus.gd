extends GutTest
## EventBus：跨模块事件中枢（D5 M1）。
## 测法：注入【独立实例】（load 脚本 .new()），不经 Autoload 全局，互不污染。
## 抛错隔离说明：GDScript 无 try/catch，但引擎运行时错误只中止"当前回调帧"，
## for 循环天然继续（探针实测）——因此本套件【不】写故意抛错回调（GUT 会把捕获到的
## SCRIPT ERROR 记为 Unexpected Error → 判失败，见 testing.md §错误路径可测约定）。
## 改测不发错误的健壮性契约：迭代中自移除、无效回调被忽略、重复订阅去重。

## 注入独立实例（不经 Autoload）。用 load() 动态取脚本再 .new()，避免把 preload
## 常量同时当类型注解/值用造成的解析歧义（见 2026-09-07 记录）。
func _make_bus() -> Node:
	var script := load("res://scripts/core/event_bus.gd")
	return autofree(script.new())


func test_fire_delivers_single_arg_to_listener() -> void:
	var bus := _make_bus()
	var got: Array = []
	bus.on(&"e", func(a: Variant) -> void: got.append(a))
	bus.fire(&"e", 42)
	assert_eq(got, [42])


func test_fire_null_arg_still_invokes() -> void:
	var bus := _make_bus()
	var marks: Array = []
	bus.on(&"e", func(_a: Variant) -> void: marks.append(1))
	bus.fire(&"e")  # 默认 arg=null，也应触发
	assert_eq(marks, [1])  # GDScript lambda 按值捕获局部，计数须经引用（数组）


func test_off_stops_future_calls() -> void:
	var bus := _make_bus()
	var got: Array = []
	var cb := func(a: Variant) -> void: got.append(a)
	bus.on(&"e", cb)
	bus.fire(&"e", 1)
	bus.off(&"e", cb)
	bus.fire(&"e", 2)
	assert_eq(got, [1])


func test_multiple_listeners_all_fire_in_order() -> void:
	var bus := _make_bus()
	var got: Array = []
	bus.on(&"e", func(a: Variant) -> void: got.append("a"))
	bus.on(&"e", func(a: Variant) -> void: got.append("b"))
	bus.on(&"e", func(a: Variant) -> void: got.append("c"))
	bus.fire(&"e", null)
	assert_eq(got, ["a", "b", "c"])


func test_fire_unregistered_key_is_noop() -> void:
	var bus := _make_bus()
	# 无任何监听也不应报错
	bus.fire(&"nonexistent", null)
	assert_true(true)


func test_clear_removes_all_listeners() -> void:
	var bus := _make_bus()
	var got: Array = []
	bus.on(&"a", func(x: Variant) -> void: got.append("a"))
	bus.on(&"b", func(x: Variant) -> void: got.append("b"))
	bus.clear()
	bus.fire(&"a", null)
	bus.fire(&"b", null)
	assert_eq(got, [])
	assert_false(bus.has_listeners(&"a"))
	assert_false(bus.has_listeners(&"b"))


func test_has_listeners_reflects_subscription() -> void:
	var bus := _make_bus()
	var cb := func(x: Variant) -> void: pass
	assert_false(bus.has_listeners(&"e"))
	bus.on(&"e", cb)
	assert_true(bus.has_listeners(&"e"))
	bus.off(&"e", cb)
	assert_false(bus.has_listeners(&"e"))


func test_duplicate_on_same_callable_dedupes() -> void:
	var bus := _make_bus()
	var marks: Array = []
	var cb := func(x: Variant) -> void: marks.append(1)
	bus.on(&"e", cb)
	bus.on(&"e", cb)  # 重复订阅 → 去重（push_warning 但不影响绿测）
	bus.fire(&"e", null)
	assert_eq(marks.size(), 1)


func test_off_not_registered_is_silent() -> void:
	var bus := _make_bus()
	bus.off(&"ghost", func(x: Variant) -> void: pass)  # 不应报错
	assert_true(true)


func test_removing_other_listener_mid_fire_uses_snapshot() -> void:
	var bus := _make_bus()
	var got: Array = []
	var other := func(x: Variant) -> void: got.append("other")
	var remover := func(x: Variant) -> void:
		got.append("remover")
		bus.off(&"e", other)  # 迭代中移除【其它】监听：快照语义，本轮仍触发它
	bus.on(&"e", remover)
	bus.on(&"e", other)
	bus.fire(&"e", null)
	bus.fire(&"e", null)
	# 本轮快照两者都跑；被移除后下一轮只剩 remover。
	assert_eq(got, ["remover", "other", "remover"])


func test_invalid_callable_on_is_ignored() -> void:
	var bus := _make_bus()
	bus.on(&"e", Callable())  # 空 Callable → 忽略（push_warning）
	assert_false(bus.has_listeners(&"e"))
	bus.fire(&"e", null)  # 不报错
	assert_true(true)
