# 并行开发规范（多 AI / 多线程专属）

> **本文件是什么**：给"多个 AI 同时改这个仓库"这件事定的**硬规矩**。它不替代 `CLAUDE.md`（流程铁律 + Karpathy 四原则）、`.claude/rules/godot-gdscript.md`（编码）、`.claude/rules/testing.md`（测试）——那三份**叠加生效**，本文件只管**并行安全**。
>
> **一句话**：**一个波次一份文件所有权；跨模块只许加，不许改；共享文件串行；接口先冻，再并行。**
>
> **谁必须读**：每个新开的 AI 会话/子代理，开工前先读本文件 §2 硬约束 + §4 文件所有权 + §5 接口契约。
>
> **来源**：移植自 D:\AI-game 的 `exile-dev-spec.md`（2026-09-21，D1），文件所有权地图换成本项目占位；§3 环境命令换本机路径。

---

## 1. 为什么需要这份文件（并行开发的三个真实死因）

单人串行开发时，下面三件事不会发生；一旦并发就会：

1. **同文件双写**：两个 AI 都去改同一个中枢脚本，后写的覆盖先写的，且**覆盖是静默的**（git 只报 conflict，若不在同一行则连 conflict 都不报，直接逻辑丢失）。
2. **契约漂移**：A 在改某函数签名，B 同时按旧签名写调用 → A 合入后 B 的代码在运行期才炸（GDScript 动态调用不报错，`has_method` 兜底会静默走 fallback 分支）。
3. **假绿**：两个 AI 各自跑了自己那一小块测试，谁也没跑全量；合入后基线红，但没人认领。

**本规范的全部条款都在防这三件事。**

---

## 2. 硬约束（不可协商，违反即回滚重做）

| # | 约束 | 理由 |
| :- | :-- | :-- |
| H1 | **一个波次内，一个文件只有一个 owner**（见 §4 所有权地图）。非 owner 对该文件的任何改动都算违规。 | 防同文件双写 |
| H2 | **跨模块只能"加"，不能"改"**：新增函数/常量/信号/键是安全的；修改已有函数签名、改已有常量值、改已有信号参数——**必须**先走 §6 登记并同步给所有在用方。 | 防契约漂移 |
| H3 | **共享文件串行**：§4 标注 `🔒串行` 的文件，同一时刻全仓库只允许一个波次动它；改前必须**明确声明**你正在占用它。 | 同上 |
| H4 | **不手改 `addons/`**（含 `godot_ai`、`gut`）。任何"顺手修一下插件"都是违规。 | 项目铁律 |
| H5 | **新增带 `class_name` 的脚本后，必须跑 `<ENG> --headless --import`**，否则全局类缓存不更新 → 全仓库级联解析错误（表现：一堆"未声明标识符"，看着像别人的锅）。 | 源项目真实事故（PLANNING:1317） |
| H6 | **合并前必须跑全量 GUT，且核对 `Scripts` 计数**（见 §7.2）。只看 "All tests passed" 会漏掉被整份跳过的测试脚本。 | GUT 静默跳过 = 假绿 |
| H7 | **接口冻结后才允许并行**：契约未冻结，不得提前写依赖它的代码。 | 防返工 |
| H8 | **先文档 → 校验 → 再代码**（CLAUDE.md 流程铁律）。 | 项目铁律 |

---

## 3. 环境与命令（照抄，勿猜）

引擎不在 PATH 上。**每次开新 shell 先定义**：

```bash
ENG="C:/Users/Administrator/AppData/Roaming/Ryko.GodotHub/godot-versions/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe"
cd "D:/AI-game-All/TESt-GAMe/流放之路"
```

> **路径失效自查**（GodotHub 升级会改目录名，写死路径即失效）：若 `$ENG` 报
> `No such file or directory`，跑 `ls "C:/Users/Administrator/AppData/Roaming/" | grep -i godot`
> 与 `ls "C:/Users/Administrator/AppData/Roaming/Ryko.GodotHub/godot-versions/"` 找到当前实际目录，替换上面那行。
>
> **注意**：本机为**标准版**引擎（非 mono 版），路径不含 `mono`。当前 MCP 会话连的是另一台编辑器实例（D:\AI-game 项目）时，无头命令仍可用，但 MCP 写操作须先确认 `session_manage` 指向本项目。

| 用途 | 命令 | 通过标准 |
| :-- | :-- | :-- |
| 无头自检 | `"$ENG" --headless --quit-after 3` | 退出码 0，无解析/加载错误 |
| **类缓存重生**（H5） | `"$ENG" --headless --import` | 无错误；跑完再跑自检 |
| 全量测试 | `"$ENG" --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit` | 全绿 **且** `Scripts` 计数正确 |
| 单文件测试 | 同上 + `-gtest=res://test/unit/test_xxx.gd` | 同上（仅该文件） |
| 编辑器 | 用 GodotHub 打开，勿用命令行 `--editor` | — |

> Git Bash 下 `godot` 不在 PATH，必须用 `$ENG` 全路径。
> GUT 全量约 **1–3 分钟**，建议 `run_in_background: true`，跑的同时做别的。

---

## 4. 文件所有权地图

> **读法**：`owner` = 当前波次可以改它的人；`只读` = 任何人可以读、可以**加**（H2），但改已有成员要登记。
> `🔒串行` 文件 = 全仓库同时只有一个 owner，改前声明占用。
>
> **本项目现状（D1 移植时）**：玩法代码尚未开建，下表为**占位框架**；每开一个新模块，先在此表登记归属再开工。

### 4.1 🔒 串行文件（每波次唯一 owner，必须显式声明占用）

| 文件 | 为什么串行 |
| :-- | :-- |
| `project.godot` | autoload / main_scene / input map |
| `docs/PLANNING.md` | 决策与执行记录台账——**追加**：各波次只在自己的 D 段内追加，不重排他段 |
| （待建）游戏主状态机/中枢脚本与主场景 | 出现第一个接线中枢脚本后登记在此 |

### 4.2 独占文件（owner 独占，别人只读）

| 模块/任务 | owner 文件 |
| :-- | :-- |
| （示例）新玩法模块 X | `scripts/<模块>/`、`test/unit/test_<模块>_*.gd` |
| （待建后按模块逐条登记） | |

### 4.3 共享只读（任何人可读；要**改已有成员**须走 §6 登记）

`scripts/core/*.gd`（event_bus / event_keys / health_component / meta_progress / options / sfx / stat_model / stat_modifier / time_control）、`scripts/combat/*.gd`（damage_data / hitbox / hurtbox）、上述模块的单测。

---

## 5. 接口契约（冻结面 — 这些是"宪法"，改 = 破坏并行）

> **规则**：以下 API 的**签名/语义**已冻结。要改，必须**先**在 §6 登记表登记 + 得到用户批准 + 通知所有在用方，再改。
> **读法**：`加` = 允许任何人新增（安全）；`冻` = 签名冻结，只能新增重载式的新函数，不能改这个。

### 5.1 数据载体

```gdscript
# scripts/combat/damage_data.gd —— 冻
DamageData.new(amount: int, source: Node)   # .amount / .source

# scripts/core/health_component.gd —— 冻
HealthComponent.setup(max: int)
HealthComponent.take_damage(data: DamageData)   # 唯一伤害入口（铁律，禁止裸改 current_health）
signal died
var current_health / max_health

# scripts/combat/hurtbox.gd —— 冻
Hurtbox.take_hit(data: DamageData)   # 受击入口
signal hit_received(data: DamageData)
```

### 5.2 服务层 Autoload（签名冻结，方法可加）

```gdscript
# EventBus —— 冻
EventBus.on(key: StringName, callable: Callable)      # 订阅
EventBus.fire(key: StringName, arg: Variant = null)   # 发布（同步）
EventBus.off(key: StringName, callable: Callable)     # 退订（释放前必须 off，防悬垂）

# EventKeys —— 加（新键只许追加，不许改名/删键）
EventKeys.PLAYER_HP / ENEMY_KILLED / XP_PICKED / ...

# TimeControl —— 冻
TimeControl.hitstop(duration: float)      # 顿帧（真实秒），到期自动恢复
TimeControl.set_paused(p: bool)           # 玩法暂停
TimeControl.is_paused() -> bool
signal pause_changed(paused: bool) / hitstop_finished

# StatModel / StatModifier —— 冻
StatModel.set_base(stat: StringName, base: float)
StatModel.add_modifier(mod: StatModifier) -> int      # 返回句柄
StatModel.remove_modifier(handle: int)
StatModel.get_value(stat: StringName) -> float        # (base + Σflat) × (1 + Σpercent)
signal changed(stat: StringName, value: float)
```

---

## 6. 契约变更登记表

> 改 §5 冻结面时，先在此追加一行（日期 | 改什么 | 为什么 | 同步给了谁），再动代码。

| 日期 | 变更 | 理由 | 通知 |
| :-- | :-- | :-- | :-- |
| — | — | — | — |

---

## 7. 测试与验证纪律

### 7.1 全量门禁

- 合并/收尾前：无头自检 0 错误 + **全量 GUT** 绿。
- 只跑自己那块的测试**不算**验证（防假绿）。

### 7.2 GUT `Scripts` 计数核对（H6，防静默跳过）

GUT 输出末尾的 `Scripts` 数 = **实际解析并载入的测试脚本数**。若某测试脚本解析失败（如它 import 的脚本挂了），GUT 会**整份静默跳过**，仍报 `Passing Tests` —— 总数看着是绿的，其实那一份根本没跑。

**核对方法**：全量跑完后，`Scripts` 数应等于 `test/unit/` 下 `test_*.gd` 文件数。当前基线：

| 日期 | test 文件数 | Scripts 基线 |
| :-- | :-- | :-- |
| 2026-09-21（D1） | 6 | 6 |

不相等 → 找出哪份被跳过（单跑可疑文件，看报错），修复后再合并。

---

## 8. 并行波次的走法（H8 的并行版）

1. **波次开工前**：主会话写 PLANNING 段（目标 + 文件分配 + 接口冻结面）→ 用户批准。
2. **冻结接口**：先改/建共享契约（§5），单独提交，跑 H5 类缓存重生。
3. **并行执行**：子代理按 §4 所有权分文件开工；串行文件单 owner；每个子代理收尾前跑自己模块的测试。
4. **合并收尾**：主会话跑 §7.1 全量门禁 + §7.2 计数核对，通过才算波次完成。
5. **闭环回写**：PLANNING 补记执行结果。

---

## 9. 提交信息模板

```
<一句话 why 优先>

- 段号：Dxx（涉及 PLANNING 段时）
- 版本：vX.Y.Z（建立版本号规则后启用）
- 测试：无头自检 0 错误；GUT 全绿（Scripts N/N）
```

---

## 10. 自主波次协议（D3，2026-09-21）

> **是什么**：PLANNING 段获批后，agent 在该段清单范围内**自主长跑**——循环执行「实现 → 单测 → 画面验证（`/verify` 第 4 步）→ 修复」，不逐步请示。这是 Godogen"自主长跑 + proof over claims"理念戴上本项目缰绳的版本。

### 10.1 前置条件（三者齐备才开跑，缺一不可）

1. **D 段获批**：PLANNING 对应段（目标 + 分步清单 + 验证点 + 回滚）经用户批准。
2. **接口冻结**（H7）：该波次依赖的共享契约已在 §5 冻结或按 §6 登记完毕。
3. **A 就绪**：`/verify` 运行画面验证可用（主场景已建；纯逻辑波次可豁免画面验证）。

### 10.2 自主循环与停靠点

循环内**不停**：实现、跑自己模块的单测、画面验证、修复、再验证——这些都属清单内工作，自主决定。

仅以下三处**必须停下**等用户：

| # | 停靠点 | 动作 |
| :-- | :-- | :-- |
| 1 | **H2 契约变更**：需要改已有函数签名/常量值/信号参数 | 走 §6 登记表 + 用户批准后才动 |
| 2 | **范围蔓延**：发现清单外的必要工作 | 汇报 + 用户决定是否纳入 |
| 3 | **波次收尾**：清单跑完 | §7.1 全量门禁 + §7.2 计数核对 + PLANNING 闭环回写，向用户交总结 |

### 10.3 护栏（防自主长跑失控）

- **修复上限**：同一问题**连续 3 次修复尝试未绿** → 停下，带上下文汇报（已试什么、怀疑什么、建议方向），不烧 token 死循环。
- **所有权照旧**（H1）：自主不等于越界——每份文件仍只有一个 owner，串行文件改前声明占用。
- **画面即证据**：波次内每轮以截图/录屏判定，不以"代码写完了"自评完成；发现问题回循环，不带病收尾。
- **停靠点优先级**：任何拿不准是否该停的时刻，**停下**。宁多停靠一次，不冒违规风险。
