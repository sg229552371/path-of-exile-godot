---
description: 诊断 Godot 运行时问题（读日志/场景/节点）
argument-hint: <问题描述或报错信息>
---
诊断运行时问题：$ARGUMENTS

遵循原则 1（先想后写）：不要急于改代码，先建立事实。

流程：
1. 用 godot_ai MCP 工具 `editor_state` 与 `logs_read` 获取当前编辑器状态与日志。
2. 用 `scene_get_hierarchy` 检查相关场景结构；对可疑节点用 `node_get_properties` 查属性。
3. 如需复现，用 `project_run` 运行并再次 `logs_read` 抓取运行期日志。
4. 定位根因后，提出**最小改动**方案（原则 3：外科手术式改动），说明每行改动如何对应到问题。

禁止：在未定位根因前做"顺手重构"或大面积改动；不修改 `addons/` 下的插件代码。
