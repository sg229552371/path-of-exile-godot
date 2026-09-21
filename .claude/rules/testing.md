# 测试规则

> AI-GameW 的测试约定。遵循 Karpathy 原则 4：目标驱动执行——先定义可验证标准，再实现。

## 结构

- 测试框架：**GUT**（Godot Unit Test，Godot Asset Library）。尚未安装 GUT 前，以 godot_ai MCP 的运行期验证为主。
- 测试脚本镜像 `scripts/` 结构，置于 `test/unit/`，命名 `test_<snake_case 目标>.gd`，`extends GutTest`。
- 用例命名/结构：`test_<方法>_<状态>_<预期>`，Arrange / Act / Assert。

## 范围

- 测**公开行为**，不测 private / 引擎回调内部实现细节。
- 必须覆盖：正常路径、边界值、空/null、异常路径。
- 不为不可能的输入写测试；不为框架自身的行为写测试（极简优先）。

## 错误路径可测约定（2026-09-07 批次 1 实测）

- GUT 会把 `push_error` 记为 **Unexpected Errors → 该测试判失败**。因此"空数组 / 零总权 / 重复归还 / 无效句柄"等**可预期的输入校验失败**一律用 **`push_warning`**（开发期可见 + 异常路径可单测），**不要用 `push_error`**。
- `push_error` 仅留给"内部不变量被破坏（不该发生）"的真错误；若用了它，该分支将无法被 GUT 覆盖，属预期。
- Godot 本工程把"`:=` 从 Variant 推断类型""取 void 返回值"两类警告升级为**解析错误**：从 Variant-returning 调用处赋 `var x: Variant = ...`（勿用 `:=`），勿写 `arr.sort()` 作值使用。
- 同理，**运行的运行时错误也会被记为 Unexpected Errors → 判失败**：例如对 `RefCounted`（如 `ExileWeapon`）调 `free()` 会报 `Can't free a RefCounted object`。RefCounted 出作用域自释放，勿手动 free；只有 `Node` 才 `queue_free`。
- 静态类型收紧注意：`var x := <Variant-returning 调用>` 是解析错误（改用显式声明 + `as 类型`）；在基类静态类型上读子类属性（如 `Node2D` 上读 `Area2D.collision_layer`）是"无效属性"；测试辅助函数标注 `-> Node` 返回类型后，实例上 Node 不存在的成员访问会被拒（去掉返回类型标注即可）。

## 运行

- GUT 已安装：`"$ENG" --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit`（或编辑器内 GUT 面板）。
- 依赖 Godot 节点/场景的集成行为：
  - 用 godot_ai MCP 的 `test_handler` / `project_run` + `logs_read` 做运行期验证；或
  - 抽离纯逻辑后对其做 GUT 单测。
- 不要在单测里启动真实编辑器进程做断言式验证。

## 红绿循环

1. 写一个失败的测试（红）。
2. 写最小实现使其通过（绿）。
3. 重构（保持绿）。
每步后跑一次测试确认状态。

## 提交门禁

- `/commit` 前先 `/verify`：`"$ENG" --headless --quit-after 3` 无脚本/场景加载错误 + 测试全绿方可提交。
