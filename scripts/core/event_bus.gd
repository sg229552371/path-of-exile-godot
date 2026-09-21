extends Node

## 跨模块事件中枢（服务层，D5 M1）。Autoload 注册名：EventBus。
## 注意：作为 Autoload 单例，本脚本【不声明 class_name】——访问入口 = project.godot 的
## autoload 名 `EventBus`（全局标识符）。测试注入用 load() 造实例，不经 Autoload。
## 模块之间"互不知晓"的解耦通道（架构铁律#2）：战斗→UI、world→HUD、掉落→统计
## 等跨模块事件走这里；模块【内部】仍优先用自带的类型化 signal，两者不混。
##
## 取舍（显式声明）：StringName 键 + 单 Variant 载荷的【通用】总线，而非为每个事件
## 声明类型化信号——跨模块事件全集在内容落地前不可知，通用总线不随功能膨胀改签名。
## 缺点 = 弱类型（键拼错运行时才暴露），用键命名约定 + GUT 缓解。这是架构层有意取舍。
##
## 用法：
##   EventBus.on(&"enemy_died", _on_enemy_died)   # 订阅（回调统一签名 func(arg: Variant)）
##   EventBus.fire(&"enemy_died", enemy)          # 发布（同步）
##   EventBus.off(&"enemy_died", _on_enemy_died)  # 退订（释放前必须 off，防悬垂）
##
## 同步派发：fire 遍历快照，逐个 call；单个回调失效（目标已释放）被跳过，不打断其它监听
## （GDScript 无 try/catch，错误回调本身仍会冒泡到引擎，见 PLANNING D5 偏差记录）。

## 订阅表：StringName 键 -> Array[Callable]（数组本身可变，fire 内遍历副本）。
var _listeners := {}


## 订阅。同名回调重复订阅 → push_warning 并忽略（防忘 off 造成重复触发）。
## 回调统一签名：func cb(arg: Variant) -> void。
func on(key: StringName, callable: Callable) -> void:
	if not callable.is_valid():
		push_warning("EventBus.on: 忽略无效回调")
		return
	if not _listeners.has(key):
		_listeners[key] = []
	var bucket: Array = _listeners[key]
	if bucket.has(callable):
		push_warning("EventBus.on: 键 %s 已存在该回调，忽略重复订阅" % key)
		return
	bucket.append(callable)


## 退订。key 无监听或回调不在其中 → 无操作（幂等，便于在释放路径无条件调用）。
func off(key: StringName, callable: Callable) -> void:
	if not _listeners.has(key):
		return
	var bucket: Array = _listeners[key]
	bucket.erase(callable)
	if bucket.is_empty():
		_listeners.erase(key)


## 同步派发：遍历该键全部监听（快照，允许回调内 on/off 安全）。无监听为 no-op。
## 单个 Callable 若目标已释放（is_valid 为 false）→ 跳过，不打断其它监听。
func fire(key: StringName, arg: Variant = null) -> void:
	if not _listeners.has(key):
		return
	var snapshot: Array = _listeners[key].duplicate()  # Variant 方法调用须显式类型（项目警告升级为错误）
	for callable in snapshot:
		if not callable.is_valid():
			continue
		callable.call(arg)


func has_listeners(key: StringName) -> bool:
	return _listeners.has(key) and not _listeners[key].is_empty()


## 清空全部订阅（场景卸载/热重载时用）。
func clear() -> void:
	_listeners.clear()
