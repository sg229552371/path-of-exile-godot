# Godot GDScript 编码规则

> 适用于 AI-GameW（Godot 4.7.2）。AI 生成代码须遵守。
> 与 Karpathy 四原则叠加生效；本文件只列项目专属约定。

## 结构与命名

- 脚本置于 `scripts/`，按模块分子目录；文件名 **snake_case**。
- 节点脚本：`class_name PascalCase` + `extends <节点类型>`，暴露给 Godot 编辑器/类型系统；仅供场景内部挂载、不被其他脚本引用时可省略 `class_name`。
- 类名 PascalCase；函数 / 变量 snake_case；常量 CONSTANT_CASE；私有成员用 `_` 前缀表意（如 `_cache`、`_on_button_pressed`）。
- 文件路径 `res://`；运行时加载用 `load(...) as Type`。

## Godot API 约定

- 生命周期：重写 `_ready` / `_process` / `_physics_process` / `_input` / `_unhandled_input` 等，勿自造同名方法。
- 信号用 `signal` 声明，`connect` 连接；导出属性用 `@export`，勿公开裸字段。
- 常量/组名/信号名用 `const X := &"..."`（StringName 缓存），避免字符串拼接。
- 节点引用优先强类型：`get_node_or_null("Path") as Type` 或 `get_tree().get_first_node_in_group(&"...") as Type`，**使用前判空**。
- 连接信号后按需 `disconnect`（节点生命周期不由树管理时）。

## 语言与性能

- 尽量显式类型标注 `var x: float`；类型明显时可用 `:=` 推断。
- 渲染用 `_draw` + `queue_redraw`；物理放 `_physics_process`。
- `_process` 热路径避免每帧分配大对象 / `new`；用对象池、预计算缓存。
- 浮点比较用 `is_equal_approx`；禁用 `OS.delay_*`（阻塞线程）——用 Timer / Tween / await。
- 场景节点由场景树管理生命周期，勿手动 `free` 场景节点（用 `queue_free`）。

## 禁止

- 不手改 `addons/` 下的插件代码（含 `godot_ai`）。
- 不为投机性"未来需求"预建抽象（极简优先）。
- 不在 diff 中夹带与任务无关的重构或格式变更（外科手术式改动）。
