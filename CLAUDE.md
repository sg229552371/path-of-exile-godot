# CLAUDE.md — 流放之路 项目记忆

> 本文件由 Claude Code 启动时自动读取，是 AI 助手在本项目中的持久化上下文。
> 基础设施移植自 D:\AI-game（AI-GameW《流放者》），2026-09-21，见 `docs/PLANNING.md` D1。
> 📋 项目规划与待决决策见 `docs/PLANNING.md`（影响架构的改动，先记录决策再动手）。

## 项目身份

- **名称**：流放之路
- **类型**：Godot 4.7.1 2D 游戏（玩法定位待定，见 `docs/PLANNING.md`）
- **脚本语言**：GDScript（Godot 4）
- **主场景**：**待建**（建好后写入 `project.godot` 的 `run/main_scene` 并更新本节）
- **AI 编辑器集成**：`addons/godot_ai`（MCP 插件，服务名 `godot-ai`）

## 目录约定

```
流放之路/
├── scripts/        # GDScript（.gd，snake_case；节点脚本加 class_name PascalCase）
│   ├── core/       # 服务层 + 纯逻辑地基（EventBus/TimeControl/StatModel…，已就绪）
│   ├── combat/     # 战斗判定地基（DamageData/Hitbox/Hurtbox，已就绪）
│   └── <模块>/     # 后续玩法模块按此模式分子目录
├── scenes/         # .tscn 场景文件
├── assets/         # 美术 / 音频 / 字体（sprites/ audio/ fonts/）
├── addons/         # 第三方插件（godot_ai / gut，勿手改；godot_gameplay_systems 为蓝本未启用）
├── test/unit/      # GUT 单测（test_<目标>.gd，镜像 scripts/ 结构）
├── docs/           # 规划与设计文档（PLANNING.md、DEVELOPMENT_GUIDE.md）
├── project.godot   # 引擎配置
├── CLAUDE.md       # 本文件
├── .mcp.json       # godot_ai MCP 配置（由 dock Configure 写入，勿手编）
├── .editorconfig   # 代码风格
└── .claude/
    ├── settings.json      # 权限（allow/deny）
    ├── commands/          # 6 个 slash 命令（plan/verify/commit/review/test-gen/debug-runtime）
    └── rules/             # godot-gdscript / testing / parallel-dev-spec 三份规范
```

## ⚠️ 多 AI / 多线程并行开发

**开工前必读 `.claude/rules/parallel-dev-spec.md`**（并行开发规范，与本文档、`rules/godot-gdscript.md`、`rules/testing.md` 叠加生效）。三条最关键：

1. **共享/中枢文件每波次最多一个 owner**，改前显式声明占用。
2. **跨模块只能"加"不能"改"**：改已有函数签名/常量值/信号参数必须先走契约登记。
3. **GUT 的 `Scripts` 计数必须核对**（脚本解析失败会被整份静默跳过却仍报 `Passing Tests`）。

## 常用命令

```bash
# 引擎不在 PATH：先按 .claude/rules/parallel-dev-spec.md §3 定义 $ENG（GodotHub 全路径）
ENG="C:/Users/Administrator/AppData/Roaming/Ryko.GodotHub/godot-versions/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe"

"$ENG" --editor               # 打开编辑器（建议用 GodotHub 打开）
"$ENG"                        # 运行主场景（建好后）
"$ENG" --headless --quit-after 3   # 无头运行自检（脚本/场景加载错误）
# 测试（GUT 已装）：
"$ENG" --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
```

## godot_ai MCP 集成

- **服务名**：`godot-ai`（连字符，非下划线）。
- 在 Godot 编辑器中通过 **Godot AI** dock 的 **Configure** 按钮写入 `.mcp.json`（项目级 scope）。
- 默认 HTTP 端点：`http://127.0.0.1:8000/mcp`（端口见 EditorSetting `godot_ai/http_port`，默认 8000；WebSocket 默认 9500）。
- 可用 MCP 工具前缀：`mcp__godot-ai__*`（如 `node_create`、`scene_save`、`scene_get_hierarchy`、`node_get_properties`、`project_run`、`logs_read`、`game_manage` 等）。
- **不要手编 `.mcp.json` 的 command/args**——由 dock 动态写入（含端口/会话令牌）。

## 已就绪的底层模块（scripts/core + scripts/combat）

服务层 Autoload（`project.godot` 已注册，顺序勿乱——save 迁移先于使用者的原则已按 D1 简化）：

| Autoload | 职责 |
| :-- | :-- |
| `EventBus` | 跨模块事件总线（`fire`/`on`/`off`，键用 `EventKeys` 常量，禁魔法字符串） |
| `TimeControl` | 玩法暂停 + 顿帧（hitstop）唯一入口，禁散落 `Engine.time_scale=` |
| `MetaProgress` | 元进度/跨局统计存档 |
| `Sfx` | 程序化合成音效（零素材；headless 自动禁用） |
| `Options` | 跨会话设置持久化（音量双总线：Master + Sfx） |

纯逻辑组件（GUT 可直测）：

- `StatModel` / `StatModifier`：数值属性 = (base + Σflat) × (1 + Σpercent)，写后发 `changed`
- `HealthComponent`：**唯一伤害入口** `take_damage(DamageData)`，禁止裸改血量（六铁律#2）
- `DamageData` / `Hitbox` / `Hurtbox`：伤害数据载体 + 攻击/受击判定盒
- `EventKeys`：事件键集中声明，新增事件先在此登记

---

## 流程铁律：先文档 → 校验 → 再代码（移植自源项目，2026-09-21）

> 本项目的**一切规划/新功能/改动**（含系统引入、重构、目录重组）都必须按此流程走。**记录在文档，方便后续所有流程追溯。**

1. **先写文档**：在 `docs/PLANNING.md` 追加「设计决策 + 分步执行清单」（每步带验证点），或为大型事项新建专项设计文档。写明目标、方案、影响面、回滚方式。
2. **再校验**：文档定稿后先做静态校验/确认——无头跑通、跑测试、引用影响核对，或经用户批准方案。
3. **后进代码**：校验通过，才动手改代码/文件；每步改动可回溯到文档步骤。
4. **闭环回写**：完成后回文档补记「实际执行 + 验证结果」，供后续流程查阅。
5. 琐碎改动（单行修复、拼写）可用判断力跳过全流程。

---

## Karpathy 四原则（编码行为准则）

本项目的 AI 编码行为遵循 Andrej Karpathy 提出的四条原则。来源：[andrej-karpathy-skills](https://github.com/thesunofdog/andrej-karpathy-skills)。

### 1. Think Before Coding（先想后写）

**不要假设。不要隐藏困惑。呈现权衡。**

- **显式陈述假设**——不确定就问，而非猜。
- **给出多种解释**——存在歧义时不要静默选定一个。
- **该据理力争时就提**——若有更简单方案，明说。
- **困惑时停下**——指明哪里不清楚并请求澄清。

### 2. Simplicity First（极简优先）

**用解决问题的最少代码。不做投机性设计。**

- 不添加未被要求的功能；不为一次性代码建抽象。
- 不加未被要求的"灵活性"或"可配置性"；不为不可能的场景写错误处理。
- **检验**：资深工程师会不会觉得这过度复杂？会，就简化。

### 3. Surgical Changes（外科手术式改动）

**只动必须动的。只清理自己造成的混乱。**

- 不"顺手改进"相邻代码、注释或格式；不重构未坏的东西。
- 发现无关死代码，提一句——不要删。
- **检验**：每一行改动都应能直接追溯到用户请求。

### 4. Goal-Driven Execution（目标驱动执行）

**定义可验证的成功标准。循环直到达成。**

把祈使句任务转成可验证目标："加校验"→"为非法输入写测试，然后让其通过"；"修 bug"→"写一个能复现的测试，然后修复使其通过"。

多步任务先给出简短计划，每步附验证点：

```
1. [步骤] → verify: [检查]
2. [步骤] → verify: [检查]
```

> 这套原则偏向**谨慎优先于速度**。对琐碎改动可用判断力，不必套用全套流程。

## 项目专属约定

- GDScript 脚本置于 `scripts/`，按模块分子目录；文件名 snake_case。
- 节点脚本用 `class_name PascalCase` + `extends <节点类型>`；导出用 `@export`，常量/组名用 `const X := &"..."`（StringName）。
- 缩进用 **Tab**（Godot 默认）；公共 API 尽量显式类型标注。
- 提交前先 `/verify`（无头运行 + 测试）。
- 编码细节见 `.claude/rules/godot-gdscript.md`；测试约定见 `.claude/rules/testing.md`。
- `addons/` 下的插件代码（含 `godot_ai`、`gut`）禁止手动修改。
