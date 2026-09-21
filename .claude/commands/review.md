---
description: 代码审查（对照 Karpathy 四原则与项目规则）
argument-hint: [可选：目标文件 / PR / commit 范围]
---
对 $ARGUMENTS 范围内的改动做代码审查（为空则审查当前未提交改动）。

先获取改动：`git status` + `git diff`（含已暂存）。然后逐项给结论：

- **极简优先**：有无投机性抽象 / 未被要求的功能 / 过长实现？
- **外科手术式改动**：diff 中每行是否都对应明确需求？有无顺手重构或无关格式变更？
- **空引用**：`get_node_or_null` / 强类型 cast 后是否判空？信号 connect 前节点是否存在？
- **Godot/GDScript 约定**：文件 snake_case？节点脚本 `class_name PascalCase` + `extends`？`@export` 而非裸字段？组名/信号名用 `const X := &"..."`（StringName）？缩进为 Tab？
- **资源加载**：`load`/`preload` 选用是否合理？`res://` 路径存在？
- **测试**：新增/改动的逻辑是否有对应测试？
- **安全**：有无命令注入 / 路径穿越 / 不安全反序列化？

最后分列：
- **必须修复**（blocker）
- **建议项**（nice-to-have）
