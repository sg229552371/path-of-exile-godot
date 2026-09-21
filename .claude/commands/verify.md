---
description: 工程自检（脚本解析 + 测试，提交前自检）
argument-hint: [可选：只针对某个测试目标]
---
对当前 Godot GDScript 项目执行验证闭环（遵循 Karpathy 原则 4：目标驱动执行）。

成功标准：
1. 无头运行 `"$ENG" --headless --quit-after 3` 退出码 0，无脚本/场景加载错误。
2. 若已安装 GUT 且有测试，全部通过。

步骤：
1. 运行 `"$ENG" --headless --quit-after 3`。若报解析/加载错误，定位根因做最小修复并重试，直到无错误。不要顺手重构无关代码（原则 3）。
2. 检查是否已装 GUT（`addons/gut/`）且有 `test/`。是则运行 `"$ENG" --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit`；否则报告"未安装 GUT，仅做解析自检"。
3. 若 $ARGUMENTS 非空，只针对指定目标运行。
4. **运行画面验证**（proof over claims，PLANNING D3）：以运行画面判定结果，不信"编译/测试通过"。**触发条件**：主场景已建 **且** 本次改动涉及玩法/渲染——纯逻辑改动（数值、服务层、数据结构）跳过本步并注明"跳过画面验证：纯逻辑改动"。
   - **轻量级（默认）**：godot_ai MCP `project_run` 启动 → `editor_screenshot(source="game")` 截图 → `logs_read(source="game")` 查运行期错误 → **看图判定**（画面符合预期？有无报错弹层？）。确认后 `project_manage(op="stop")`。
   - **重型级**（动作手感 / 动画 / 相机类改动）：短录屏逐帧审查——`"$ENG" --headless --write-movie screenshots/verify/frame.png --fixed-fps 30 --quit-after 150`（约 5 秒 @30fps，Windows 本机可用），必要时配 `game_manage` 的 `input_action`/`input_key` 模拟输入。完成后删除临时帧序列。
   - 画面验证发现问题 → 回到步骤 1 循环修复，不带着"能跑但画面不对"的状态收尾。

最终报告：
- 脚本/场景解析：成功/失败，报错数量。
- 测试：通过/失败计数（未装 GUT 则注明）。
- 画面验证：截图判定结论 / 录屏逐帧结论 / 跳过（注明理由）。
- 阻塞项：列出尚需修复的具体问题（若有）。
