---
description: 为指定目标生成测试（目标驱动）
argument-hint: <目标脚本 / 函数>
---
为 $ARGUMENTS 生成测试，遵循 `.claude/rules/testing.md`。

流程（原则 4：目标驱动执行）：
1. 识别被测目标的**公开行为**与边界条件，列出用例：正常路径、边界值、空/null、异常路径。
2. 为每个用例写测试，命名 `test_<方法>_<状态>_<预期>`，结构 Arrange/Act/Assert。
3. 若未安装 GUT，先从 Godot Asset Library 安装（`addons/gut/`），在 `test/unit/` 下建 `test_<snake_case>.gd`（extends GutTest），镜像 `scripts/` 结构。
4. 运行 `"$ENG" --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit` 确认全绿（红 → 绿 → 重构循环）。

约束：
- 不为不可能的输入写测试；不为 private 实现细节写测试（原则 2）。
- 依赖 Godot 节点/场景的集成行为：抽离纯逻辑后做 GUT 单测，或用 godot_ai 的 `test_handler` / `project_run` + `logs_read` 做运行期验证；不启动真实编辑器断言。
