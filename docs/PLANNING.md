# PLANNING.md — 流放之路 规划与决策台账

> 本文件是项目的**决策与执行记录**（移植自 D:\AI-game 的流程铁律：先文档 → 校验 → 再代码 → 闭环回写）。
> 每个决策一个段号（D1, D2, …），只在自己段内**追加**，不重排他人段落。
> 方法与架构约定见 `docs/DEVELOPMENT_GUIDE.md`；编码/测试/并行规范见 `.claude/rules/`。

---

## D2 — 资产管线首次端到端演练：一张商品卡片（Spike，2026-09-21）

### 目标

验证「生图 → 落盘 → Godot 控件组装 → 游戏内截图 → 视觉审图」全流程可行，暴露环节问题。**产出是流程结论，非正式功能**；产物标记为一次性（`_spike_` 前缀/测试目录）。

### 方案（用户拍板：卡片 Spike，非完整商店）

范围 = 一张商品卡片：卡底板（九宫格）+ 1 图标 + 品名 + 2 属性行 + 价格行。8 个环节：

1. 风格定妆照（`og-image-2` 出 Brotato 风卡底板，精调 1–2 次）
2. 图标生成（`/v1/images/edits` 参考定妆照出蓝盾图标，验证风格延续）
3. 落盘切片（图标/底板 → `assets/_spike/`，Python 切片脚本 `tools/_spike_slice.py`）
4. Theme + 九宫格（`theme_manage` 建 Spike 主题，StyleBoxTexture 九宫格卡底）
5. 控件组装（`ui_manage.build_layout`：PanelContainer+Label+TextureRect，**真字体**中文）
6. 游戏内截图（`project_run` + `editor_screenshot(game)`）
7. 视觉审图（`gpt-5.4-mini` 对比设计稿与游戏截图）
8. 结论回写本段（流程可行性 + 环节问题清单 + 正式开发修正项）

### 影响面 / 回滚

- 新建：`assets/_spike/`（生成图）、`tools/_spike_slice.py`、`scenes/_spike_card.tscn`、`docs/superpowers/specs/` 无涉
- 不动：core/combat 模块、GUT 基线（Spike 场景不注册 main_scene）
- 回滚：删除上述新建文件 + Spike 主题资源即可，零耦合

### 实际执行 + 验证结果（2026-09-22 回写，含 09-22 崩溃恢复）

**8 环节全部走通，流程可行 ✅**。逐环节结果：

1. **风格定妆照 ✅**：`og-image-2` 1024x1024 出 Brotato 风卡底板（奶油底+厚棕描边），一次过。
2. **图标生成 ✅**：`/v1/images/edits`（multipart）以定妆照为参考出蓝盾图标，风格（描边/高光/色板）完全延续——**img2img 定妆照路线验证成功**，且实测 og-image-2 在 edits 端点可用（此前只测过 nano-banana-2-lite）。
3. **落盘切片 ✅**：Pillow 裁出 `card_panel.png`（640x880）、色键抠透明出 `icon_shield_trans.png`。色键抠图对纯底色图标可用但边缘糙，正式期改 alpha 阈值/让生图直接出透明底。
4. **九宫格 ✅（走了弯路）**：StyleBoxTexture（texture_margins 60）直接在节点上配，未建独立 Theme——Spike 单场景够用，正式 UI 必须落到 Theme 资源（见修正项）。
5. **控件组装 ✅（踩 3 坑）**：build_layout + 手工修，真字体中文清晰无错字。三坑：①PanelContainer 多子节点同矩形堆叠，必须内嵌 VBoxContainer；②TextureRect 默认 Keep Size 会拿 1024 原图把容器撑爆，须 `expand_mode=1`；③PanelContainer 无 `separation`（BoxContainer 才有）——`batch_execute` 一条错**整批回滚**。
6. **游戏内截图 ✅**：`project_run` + `editor_screenshot(game)`，3 轮迭代（全屏锚点→图标撑爆→边框压字）收敛到合格。
7. **视觉审图 ✅**：`gpt-5.4-mini` 双图对比结论：风格一致（描边/色板同向）、无截断溢出；差距集中在渐变/阴影/留白等"抛光"维度——与"两阶段方案里 lite/快速稿先行、定稿期再抛光"的预期完全吻合。
8. **回写 ✅**：本段。

**环节问题清单（Spike 实录）**：
- **编辑器崩溃丢内存态**：第一轮布局修复（root 全屏锚、Content 重父级）只存于编辑器内存，编辑器崩溃后丢失。恢复方式：直接手写 `.tscn` 到磁盘再 `scene_open`，比重走 MCP 节点操作快。**教训：每完成一个结构修改就 `scene_save`，不攒批**。
- **生图资产的边界残留**：设计稿裁切带入了外圈深色底（裁切框偏大），九宫格拉伸后卡底四周出现深色晕边；content_margin(24) < texture_margin(60) 时文字压进描边区。后者以 content_margin=76 修复。
- **无主场景报错**：`--headless --quit-after 3` 报 "no main scene defined"；已用 `set_main_scene` 设 `res://scenes/_spike_card.tscn`（Spike 场景暂代，正式开发时替换）。

**正式开发修正项**：
1. **Theme 优先**：正式 UI 一开始就建 `theme/` 资源（九宫格 StyleBoxTexture、字体、色板全落 Theme），控件只挂 Theme 不逐节点覆盖——一致性靠 Theme 单源。
2. **边距规则**：StyleBoxTexture 的 content_margin ≥ texture_margin（描边厚度），否则内容压描边。
3. **TextureRect 进容器一律 `expand_mode=1`**，用 custom_minimum_size 控尺寸。
4. **保存纪律**：结构修改即存盘（崩溃安全）；`batch_execute` 前先小批试错，防整批回滚。
5. **抠图**：正式图标让生图直接出纯色/透明底，或用 alpha 阈值，别用色键硬抠。
6. **长文本容错**：卡片布局预留 autowrap/字号降级空间（审图指出当前布局长文案易溢出）。

**Spike 产物清单**（一次性，`_spike_` 标记，正式开发可整体删除）：`assets/_spike/`（4 图 + 截图）、`scenes/_spike_card.tscn`（暂挂 main_scene）。未建 `tools/_spike_slice.py`（切片用一次性 python -c 完成，无独立脚本）。

---

## D4 — 资产管线第二次演练：完整商店界面（Spike，2026-09-22）

### 目标

D2 验证了"一张卡片"的最小闭环；本次升级为**整屏 UI 演练**——以 `D:\AI-game-All\TESt-GAMe\AI生图测试\_09_商店.png`（og-image-2 生成的商店设计稿，1920×1080）为视觉规范，把它转换成可运行的 Godot UI。重点验证 D2 未覆盖的环节：**图标表网格切片、Theme 资源落地、多卡片数据驱动布局、整屏布局分区**。产出仍是流程结论（`_spike_` 标记），非正式功能。

### 方案

**设计稿拆解**（`_09_商店.png` 上的分区）：
- 顶栏：左"商店 - 第 5 波结束"标题牌 + 右金币栏（💰128）
- 商品区：4 张商品卡（护盾/手枪/铁头盔/炸弹，各 2 属性行 + 价格 + 锁）
- 武器槽区：标签"武器槽(6/6)" + 6 个已拥有武器槽（图标 + 出售按钮）
- 右侧：角色属性面板（3 组分类：基础/战斗/生存，各 3-4 行属性）
- 底栏：道具按钮（蓝瓶×3）+ 刷新 / 合并 / 出发 三个大按钮
- 背景：洞穴夜景（装饰整图）

**执行路线**（应用 D2 全部修正项）：

1. **文档本段** → verify: 本段存在。
2. **资产生产**（两阶段方案的 lite 速出档）：
   a. 切设计稿本身当装饰图：背景整图（顶部标题牌、金币框也从设计稿裁）→ verify: 裁切图落 `assets/_spike/`
   b. `nano-banana-2-lite` 出**4×1 图标表**（护盾/手枪/头盔/炸弹，同风格网格）+ **6×1 武器图标表**（剑/矛/弓/杖/锤/手里剑）→ verify: 2 张 sheet 落盘
   c. Pillow 切片脚本 `tools/_spike_slice_shop.py` 网格切片 → verify: 10 个图标 PNG
   d. `og-image-2` 出卡底板定妆照（复用 D2 的 `card_panel.png` 即可，不重复生成）
3. **Theme 资源落地**（D2 修正项#1 的实战）：`theme/spike_shop_theme.tres`——卡片九宫格、属性面板、按钮三式（蓝/绿/红）、Label 默认色字号 → verify: theme 落盘且被场景引用。
4. **场景组装** `scenes/_spike_shop.tscn`：
   - TextureRect 背景（设计稿裁切）+ 半透明黑罩（保证前景可读，模拟"AI 设计稿→真控件"混用）
   - 真控件重建全部功能区（背景装饰图只做底，前景全部控件）——卡片用数据驱动：定义 4 条商品数据字典，脚本循环生成 4 张卡（验证数据驱动路线）
   - verify: 场景保存、project_run 无报错
5. **游戏内截图 + 迭代**（3 轮上限内收敛布局）→ verify: `editor_screenshot(game)` 无截断/溢出/错位。
6. **视觉审图**：`gpt-5.4-mini` 对比设计稿 vs 游戏截图 → verify: 输出差异清单。
7. **结论回写本段**：环节问题清单 + 正式开发修正项（含"图标表切片"路线的可用性判定）。

### 实际执行 + 验证结果（2026-09-22 回写）

**7 环节全部走通 ✅，且首帧即合格**（D2 是 3 轮迭代，本次 0 轮布局返工——D2 修正项直接生效的实证）。

逐环节结果：

1. **文档 ✅**：本段。
2. **资产生产 ✅**：
   - 装饰裁切：`bg_full/title_plate/coin_box/potion_btn` 从设计稿 Pillow 裁出；其中 `bg_full.png` 因设计稿 UI 烤死在图上被弃用，改用 `nano-banana-2-lite` 8s 现出纯景 `bg_cave.png`（与设计稿氛围一致）——**装饰图必须是"干净底图"，带 UI 的设计稿只能当局部装饰裁切源**。
   - 图标表：`nano-banana-2-lite` 两张 sheet（4 商品 + 武器 8 格），每张 ~6-7s。**提示词网格约束不严**：items 表图标偏下且自带白方块框，weapons 表把"1 行 6 列"生成了 2×4 且"魔杖"重复 3 次；靠连通域切片 + 人工选索引弥补。**结论：图标表路线可用，但切片前必须肉眼核图，提示词要写明"等间距、无白框、图标居中于各自格子"**。
   - 切片：`tools/_spike_slice_shop.py`（scipy 连通域 + 边缘 flood-fill 抠底 + 1px 羽化），12 个图标全部干净透明——**D2 修正项#5（alpha 抠图替代色键）落地成功**。
3. **Theme ✅**：`theme/spike_shop_theme.tres`——ShopCard（D2 九宫格卡底复用）/SlotPanel/StatPanel/GroupHeader + BtnBlue/BtnGreen/BtnRed 三色按钮（normal/hover/pressed）。本次全部样式经 Theme type_variation 生效，**场景零逐节点样式覆盖（除字号）**。
4. **场景组装 ✅**：`scenes/_spike_shop.tscn` + `scripts/_spike/spike_shop_builder.gd` 数据驱动——4 商品卡 / 6 武器槽 / 3 属性组全部由字典数组循环生成（`_ready` 内 build）。换商品数据=改字典，不动场景树。
5. **游戏内截图 ✅**：首帧无截断/溢出/错位（窗口 1280x720，1920×1080 canvas_items 拉伸生效）。
6. **视觉审图 ✅**（`gpt-5.4-mini` 设计稿 vs 截图）：分区完整性 6/6 无遗漏；扣分项集中在①卡片视觉语言（设计稿浅色圆角 vs 复用 D2 木框卡底）②版式间距松散③图标混贴感④属性面板细节⑤材质阴影抛光——**全部属于"定稿期抛光"范畴，无结构性问题**。
7. **回写 ✅**：本段。

**环节问题清单（本次实录）**：
- 生图对"网格布局"指令服从度低（行数/列数/重复项都不保真），图标表需人工核图后按索引取用。
- 设计稿整图不可直接当背景（UI 烤在图上）；本次为背景单独生了一张纯景，这是新增的一类资产需求（背景图也要进提示词模板库）。
- 主场景切换：`_spike_card.tscn` → `_spike_shop.tscn`（收尾保留 shop 为主场景，card Spike 场景保留供参照）。
- **（用户复核抓漏）滚动条未复现**：设计稿右侧属性面板有蓝色拉动条，首版只放了 ScrollContainer——内容不溢出时滚动条不显示，且未做样式，截图里等于没有。补法：①Theme 定制 `ScrollbarV`（grabber 蓝色圆角 + track 灰蓝）+ ScrollContainer 面板置空；②内容溢出才有 Grabber——属性行加高（52px）并补第 4 组数据使列表真实溢出。**教训：ScrollContainer 不溢出 = 滚动条不存在，验证时必须确认溢出或用 `vertical_scroll_mode = 2`（always show）**。
- **（用户复核抓漏）商品卡锁按钮缺失**：设计稿每张卡价格旁有锁形按钮，首版遗漏。补法：从设计稿裁锁按钮 PNG（flood-fill 抠底）+ TextureButton 与价格按钮同行（HBox，价格 `SIZE_EXPAND_FILL`）。**教训：首版拆解分区按"块"走漏了"块内小控件"，对照设计稿应逐卡核对控件清单**。

**正式开发修正项（在 D2 六条之上新增）**：
7. **数据驱动 UI 为默认路线**：列表类界面（商品/槽位/属性）一律"数据字典 + 循环 build"，场景树只搭静态骨架。
8. **图标表提示词硬约束**：明确"每个图标单独居中于自身等分格、无背景框、纯色底、等间距"，生成后先肉眼核图再切片。
9. **背景是独立资产类**：需单独的纯景提示词模板（无 UI 无角色），不能从带 UI 设计稿抠。
10. **Theme type_variation 命名即设计语言**：ShopCard/BtnBlue 这类语义化变体名就是给策划/美术的契约，正式期沿用此模式。
11. **滚动区必须显式声明滚动条策略**：内容可能不溢出的 ScrollContainer 用 `vertical_scroll_mode = 2`（always）或验证时确认溢出；ScrollbarV/ScrollbarH 样式进 Theme。
12. **设计稿对照要逐块清点控件**：不只对分区，还要对"每个分区内的控件清单"（按钮/角标/锁/徽章），防小控件遗漏——本次靠用户复核抓出两处。

**产物清单**（一次性，`_spike_` 标记）：`assets/_spike/shop/`（12 图标 + 5 装饰 + 截图 + `_review_slice.png`）、`tools/_spike_slice_shop.py`、`theme/spike_shop_theme.tres`、`scenes/_spike_shop.tscn`（暂挂 main_scene）、`scripts/_spike/spike_shop_builder.gd`。

### 影响面 / 回滚

- 新建：`assets/_spike/shop/`（裁切图 + 图标）、`tools/_spike_slice_shop.py`、`theme/spike_shop_theme.tres`、`scenes/_spike_shop.tscn`
- 不动：core/combat 模块、GUT 基线；`main_scene` 切到本场景，收尾切回 `_spike_card.tscn`
- 回滚：删除上述新建文件即可，零耦合

---

## D5 — 全 UI 界面批量制作波次：14 屏静态壳（2026-09-22）

### 目标

以 `任务列表/任务目标/_NN_*.png`（14 张 1920×1080 Brotato 卡通风设计稿）为视觉规范，批量制作全部 UI 界面。**完成标准（用户拍板）：静态壳 + 假数据**——每屏可运行场景，数据驱动填假数据，游戏内截图对齐设计稿；不接真实功能、不接屏间跳转。并行机制=单会话子代理；验收=截图 + 逐块清点 + 审图，3 轮上限。

### 用户拍板的资产产线（本段核心约束）

1. **图标走 4×4 网格 sheet 标准产线**：提示词 `"a 4×4 grid sheet of 16 fantasy RPG item icons, all in identical style: ..."`，生成后脚本切网格得 16 张风格统一小图。独立游戏 AI 产图标的标准做法。
2. **图标分 4–5 张 sheet 分批生成**：按类分组（武器类 / 防具类 / 消耗品类 / 材料货币类 / UI 符号类…），单次失败不拖垮全批。
3. **按钮和 UI 框（九宫格底板）也走同一生图管线**，与图标同一风格锚——**风格统一是本波次第一验收项**。
4. **严格两阶段顺序**：先草图快速迭代阶段（`nano-banana-2-lite`，~8s/张）→ 全部草图确认后，才进入 UI 设计稿 / 高保真参考图阶段（`og-image-2` + `quality:"hd"`）。同模板同尺寸，两阶段只换模型不改模板。

### 屏幕清单与分组（14 屏，编号对齐任务列表）

| 组 | 屏幕 | 布局家族 | 子代理 |
| :-- | :-- | :-- | :-- |
| A | 01 主菜单 / 04 难度选择 / 10 设置 / 14 MOD | 全屏菜单族（大按钮+背景） | A |
| B | 02 角色选择 / 03 武器选择 / 07 升级选择 | 卡片选择族（卡格+图标） | B |
| C | 06 暂停菜单 / 08 宝箱 / 13 游戏结束 | 弹窗覆盖族（面板+遮罩） | C |
| D | 05 战斗HUD / 11 进度成就 / 12 图鉴 | 数据密集族（多栏+列表） | D |
| — | 09 商店 | （D4 Spike 已实现，直接转正，不重做） | 主会话 |

另加开发工具：`scenes/ui/ui_gallery.tscn` 屏幕浏览器（按钮列表跳 14 屏，供逐屏查看；纯开发工具，不算屏间跳转）。

### 分步执行清单

**阶段 0：契约冻结 + 资产集中生产（主会话串行）**

0.1 本段文档 → verify: 本段存在
0.2 `theme/main_theme.tres`：从 `spike_shop_theme.tres` 迁移 + 补齐预判变体；注册为项目默认主题（唯一一次改 `project.godot`，此后子代理禁碰）→ verify: 无头自检通过
0.3 草图阶段批量生图（全部走 lite）：
  - 13 张纯景背景（无 UI 无角色，D4 修正项#9）
  - 4–5 张 4×4 图标 sheet（按类分批）→ `tools/slice_grid.py` 切网格 → verify: 每张 sheet 肉眼核图（D4 修正项#8）后切片落盘
  - 按钮/UI 框九宫格底板（同风格锚）→ verify: 落 `theme/` 配套资产
  - 主菜单 Logo 定妆照（img2img 三板斧路线，预期多 1–2 轮）
0.4 草图全批确认（用户过目或按锚图自检）→ **进入高保真阶段：同模板同尺寸切 og-image-2+hd 重生成全部定稿资产** → verify: 落盘 `assets/ui/<屏名>/`
0.5 商店转正：`_spike_shop.tscn` → `scenes/ui/09_shop.tscn`，资产搬 `assets/ui/shop/` → verify: 运行无报错
0.6 所有权地图登记（§4 追加）→ verify: 表已更新

**阶段 1：4 个子代理并行组装（13 屏）**

每个子代理产物（所有权独占，互不交叉）：
- `scenes/ui/NN_xxx.tscn` + `scripts/ui/NN_xxx_builder.gd`（数据驱动，D4 修正项#7）
- `theme/<家族>_theme.tres`（家族专属变体，只挂自己场景根；公共部分只读 main_theme）
- `test/unit/test_ui_<家族>.gd`（冒烟：场景可实例化、卡片数=数据数）
- 自带 D4 全部 12 条修正项 + 逐块清点控件清单验收
- 循环：实现 → 单测 → 截图 → 审图 → 修复；3 轮上限，超限带问题上报（§10.3 护栏）

**阶段 2：收尾（主会话）**

2.1 全量 GUT + Scripts 计数核对（H6）+ 无头自检 → verify: 全绿且计数相符
2.2 ui_gallery 逐屏截图汇总交用户过目 → 用户反馈单列修复清单
2.3 PLANNING 闭环回写本段

### 文件所有权登记（§4 地图本波次追加）

| 文件/目录 | owner |
| :-- | :-- |
| `docs/PLANNING.md`、`project.godot`、`theme/main_theme.tres`、`assets/ui/`（阶段0）、`scenes/ui/ui_gallery.tscn` | 主会话 |
| 组 A：`scenes/ui/01_*.tscn` `04_*` `10_*` `14_*` + `scripts/ui/` 对应 builder + `theme/menu_family_theme.tres` + `test/unit/test_ui_menu.gd` | 子代理 A |
| 组 B：`scenes/ui/02_*` `03_*` `07_*` + 同上 + `theme/card_family_theme.tres` + `test/unit/test_ui_card.gd` | 子代理 B |
| 组 C：`scenes/ui/06_*` `08_*` `13_*` + 同上 + `theme/popup_family_theme.tres` + `test/unit/test_ui_popup.gd` | 子代理 C |
| 组 D：`scenes/ui/05_*` `11_*` `12_*` + 同上 + `theme/data_family_theme.tres` + `test/unit/test_ui_data.gd` | 子代理 D |
| `09_shop.tscn`（转正期间） | 主会话 |

命名规范：场景/资产带两位编号前缀（`01_main_menu`），与任务列表图号一一对应。

### 已知风险

- 主菜单 Logo 艺术字生图不可靠 → 定妆照 img2img + 字体兜底，预算 1–2 轮。
- 资产量大（~23+ 张生成图）→ 分 sheet 分批（本段约束#2）控单次失败影响面；阶段 0 是串行瓶颈。
- og-image-2 慢（~112s/张）→ 仅定稿阶段使用，lite 阶段先全部收敛构图。

### 影响面 / 回滚

- 新建：`theme/main_theme.tres` 及 4 个家族 theme、`assets/ui/`、`scenes/ui/`（15 场景含 gallery）、`scripts/ui/`、`test/unit/test_ui_*.gd`（4 份）、`tools/slice_grid.py`
- 修改：`project.godot`（默认主题 + main_scene 切至 gallery/ui）、商店 Spike 文件迁移（原 `_spike_` 产物保留至收尾后清理）
- 不动：core/combat 模块、EventKeys 契约、既有 6 份单测
- 回滚：删除上述新建文件；`project.godot` 还原默认主题与 main_scene 两键；Spike 文件原样在盘，零数据损失

---

## D1 — 从 D:\AI-game（《流放者》/AI-GameW）移植 AI 开发基础设施（2026-09-21）

### 背景

新项目《流放之路》（`D:\AI-game-All\TESt-GAMe\流放之路`）几乎为空（仅 project.godot + 图标）。
源项目 `D:\AI-game`（AI-GameW，《流放者》）沉淀了一套经 60+ 开发段验证的 AI 协作开发基础设施。
用户拍板（2026-09-21）：**移植"基础设施 + 底层模块"，不带《流放者》游戏内容，不带美术资源**。

### 目标

新项目开箱即得：MCP 编辑器集成、GUT 测试框架、编码/测试/并行规范、可复用底层模块（零游戏耦合、零美术依赖）及其单测。

### 移植清单

**IN（移植）**：

| 类别 | 内容 | 说明 |
| :-- | :-- | :-- |
| 插件 | `addons/godot_ai`（MCP 集成，v4.0.0） | AI 编辑器操控核心；含 runtime/game_helper.gd（需 autoload） |
| 插件 | `addons/gut`（GUT 测试框架） | 单测框架，源项目全量在用 |
| 插件 | `addons/godot_gameplay_systems`（168K，纯 GDScript） | 背包/属性/交互系统**蓝本**（源项目未启用，仅参考，保持不启用） |
| 脚本 | `scripts/core/` 9 个：event_bus / event_keys / health_component / meta_progress / options / sfx / stat_model / stat_modifier / time_control | 服务层+纯逻辑地基，零游戏耦合、零素材（sfx 为程序化合成） |
| 脚本 | `scripts/combat/` 3 个：damage_data / hitbox / hurtbox | 战斗判定地基；已核无 exile 依赖 |
| 测试 | `test/unit/` 6 个：test_event_bus / test_health_component / test_meta_progress / test_options_settings / test_stat_model / test_damage_data | 与上表脚本一一对应（含 .uid 一起复制） |
| 配置 | `CLAUDE.md`（**适配版**）、`.editorconfig`、`.gitignore`（精简版）、`.gitattributes` | 项目记忆与代码风格 |
| 配置 | `.claude/settings.json`（权限）、`.claude/commands/` 6 个 slash 命令 | commit / debug-runtime / plan / review / test-gen / verify |
| 规则 | `.claude/rules/godot-gdscript.md`、`testing.md`（原文）；`parallel-dev-spec.md`（**适配版**，源 exile-dev-spec.md 去 exile 化） | 编码 / 测试 / 并行开发三份规范 |
| 文档 | `docs/DEVELOPMENT_GUIDE.md`（**适配版**：保留 AI 协作流程 + 数据健康六铁律，路线图留空待补） | 方法论 |
| 引擎配置 | `project.godot` 增补 `[autoload]` 6 项 + `[editor_plugins]` 2 项 | autoload 顺序保持源相对序（EventBus→TimeControl→MetaProgress→Sfx→Options→_mcp_game_helper） |

**OUT（明确不移植，及理由）**：

| 内容 | 理由 |
| :-- | :-- |
| `scripts/exile/`、`scripts/content/`、`scenes/`、`ui/` | 《流放者》游戏内容（用户拍板不带） |
| `assets/`（maps/sprites） | **美术，按用户要求不带** |
| `scripts/combat/projectile.gd` | 依赖 `ExileEnemy.aoe_at` + `exile_burn_zone`（游戏耦合），不干净 |
| `scripts/core/save_migration.gd` | 旧档迁移器；新项目无旧档，投机性保留违反极简优先 |
| `addons/limboai`（11M 原生 DLL） | 源项目未启用；为 mono 版引擎编译；行为树可用 GDScript FSM 替代；需要时再取 |
| `tools/`（d*_verify.gd 等） | exile D 段一次性验证脚本 |
| `docs/PLANNING.md`（源，8336 行）、`docs/ART_*`、`docs/specs/`、`docs/项目核心参考/` | exile 决策台账 / 美术 / 玩法设计文档，属游戏内容 |
| `init-godot.sh`、`builds/`、`export_presets.cfg`、`config/CLAUDE.md` | 脚手架/构建产物，本项目已初始化 |
| 源 `project.godot` 的 `[input]` 段 | 输入映射属玩法，待本项目有玩法再定 |

### 适配差异（源 → 本项目）

1. `$ENG` 引擎路径改本机：`C:/Users/Administrator/AppData/Roaming/Ryko.GodotHub/godot-versions/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe`（**标准版**，源机器为 mono 版）。
2. `exile-dev-spec.md` → `parallel-dev-spec.md`：保留硬约束 H1–H8 / 契约登记 / GUT Scripts 计数 / 先文档后并行流程；文件所有权地图改为通用占位（本项目文件待建后补）。
3. `CLAUDE.md`：项目身份改为《流放之路》；主场景**待建**；版本号真源待入口脚本建立后指定（源规则绑定 exile_shell.gd，暂不搬）。
4. 不写 `.mcp.json`（由 Godot AI dock 的 Configure 按钮生成，见 CLAUDE.md）。

### 分步执行清单（每步带验证点）

1. 本文档定稿 → verify: 本文件存在且含本段。
2. 复制 3 插件 → verify: `addons/{godot_ai,gut,godot_gameplay_systems}/plugin.cfg 或目录` 存在。
3. 复制 9+3 脚本与 6 测试（含 .uid） → verify: 文件数核对；无头 `--import` 无解析错误。
4. 写 `.claude/`（settings/commands/rules）+ 适配文档 → verify: 各文件存在。
5. `project.godot` 增补 autoload + editor_plugins → verify: 无头 `--quit-after 3` 退出码 0、日志无加载错误。
6. GUT 全量 → verify: 全绿，且 **`Scripts` 计数 = 6**（防脚本解析失败被静默跳过，见 parallel-dev-spec §7）。

### 回滚方式

删除移植的 `addons/`（3 个目录）、`scripts/`、`test/`、`docs/`、`.claude/`、`CLAUDE.md`、`.editorconfig`、`.gitignore`、`.gitattributes`，并还原 `project.godot`（去掉 `[autoload]` 与 `[editor_plugins]` 两段）。本项目尚无其他改动，回滚即回到移植前状态。

### 实际执行 + 验证结果（2026-09-21 回写）

| 步骤 | 结果 | 验证 |
| :-- | :-- | :-- |
| 1. 本文档定稿 | ✅ | 本段即为记录 |
| 2. 复制 3 插件 | ✅ | `addons/{godot_ai,gut,godot_gameplay_systems}` 均在，game_helper.gd / plugin.cfg 核对通过 |
| 3. 复制 9+3 脚本与 6 测试 | ✅ | 计数核对：core 9 / combat 3 / test 6；`--headless --import` 退出码 0，无解析错误 |
| 4. `.claude/` + 适配文档 | ✅ | settings.json + 6 命令 + 3 规则 + CLAUDE.md / parallel-dev-spec.md / DEVELOPMENT_GUIDE.md / .editorconfig / .gitignore / .gitattributes |
| 5. project.godot 增补 | ✅ | `[autoload]` 5 服务 + `_mcp_game_helper`，`[editor_plugins]` 2 项；无头 `--quit-after 3` 退出码 0（仅"无主场景"提示，符合预期——玩法场景待建） |
| 6. GUT 全量 | ✅ | **Scripts 6/6（计数核对通过）· Tests 44/44 · Asserts 125 · 全部通过 · 退出码 0** |

**偏差记录**：

1. `save_migration.gd` 按计划未移植（OUT 表），autoload 因此少一项，顺序其余保持源相对序。
2. `projectile.gd` 未移植（依赖 ExileEnemy）；若后续需要弹丸，从源项目连同其依赖一起取。
3. 目标项目 `addons/ziva_agent`（第三方 AI 插件 v3.2.6，含 CEF 二进制 ~180 文件）**移植前已存在**（本机装 Ziva 桌面助手时自动带入），非本次移植内容；未启用、未改动。是否保留由用户决定。
4. 本机引擎为 4.7.1 **标准版**（源为 mono 版），`$ENG` 路径已按本机写入 `parallel-dev-spec.md` §3 与 CLAUDE.md。
5. 源 `.gitignore` 中 exile 专属条目（C# 残留、G_Artist、tools 截图等）按本项目现状精简。

---

## D3 — 验证闭环自动化（A）+ 自主波次协议（B）（2026-09-21）

> 段号勘误：本段执行期间与资产管线 Spike 波次并发写入，双方段号撞为 D2；按"不重排他人段落"原则，本段重编为 D3，Spike 段保留 D2。

### 背景

用户调研 [htdt/godogen](https://github.com/htdt/godogen)（AI 自主开发游戏框架，6.9k stars）后提出引入诉求，看中的是其**自主程度**（agent 长跑数小时自主构建游戏，以运行画面证明结果）。经评估（GitHub API 实测其 README/CHANGELOG/引擎指南）：其 Godot 路线为 **C#/.NET only**、面向**全新空仓库从零生成**、资产生成绑定 Gemini/Grok/Tripo3D 外部 API、测试平台不含 Windows——与本项目（GDScript 定位 / 已有基建存量 / 公司内网资产生成管线 / Windows）四项硬冲突，**不直接引入**。

**语言决策**：用户问"C# 还是 GDScript 好"。Godogen 官方对比文档（`docs/gdscript-vs-csharp.md`）确实证明 C# 对 AI 生成正确率更高（无 Variant 推断陷阱、单次编译全量抓错），但本项目工具链（godot_ai MCP 脚本工具、GUT、testing.md 对策铁律）全是 GDScript 原生，且 AI 的 Godot 训练数据偏 GDScript（Godogen 自认 C# 枚举名常猜错）。**决策：留在 GDScript**，设重访触发器（见下）。

用户拍板（2026-09-21）：**方案 A+B**——把 Godogen 的可借鉴理念（proof over claims + 自主长跑）移植进本项目现有体系，戴上项目自己的缰绳。

### 目标

1. **A 验证闭环自动化**：agent 能自己"看到"游戏运行画面并据此判定结果（不信编译通过），为 B 提供地基。
2. **B 自主波次协议**：PLANNING 段批准 + 接口冻结后，agent 在清单内自主循环（实现→测试→画面验证→修复），只在真决策点停靠，不逐步请示。

### 影响面（交付物）

| 文件 | 改动 | 所有权 |
| :-- | :-- | :-- |
| `docs/PLANNING.md` | 追加本段（D3） | 🔒串行，本波次已声明占用 |
| `.claude/commands/verify.md` | 增加第 4 步「运行画面验证」 | 命令文件独占 |
| `.claude/rules/parallel-dev-spec.md` | 新增 §10「自主波次协议」 | 🔒串行，本波次已声明占用 |

零游戏代码、零引擎配置改动；GUT 基线不受影响（Scripts 仍应为 6）。

### 方案要点

**A — verify 增加运行画面验证**（触发条件：主场景已建 **且** 本次改动涉及玩法/渲染；纯逻辑改动跳过）：
- 轻量级（默认）：godot_ai MCP `project_run` → `editor_screenshot(source="game")` → `logs_read` 查运行期错误 → **看图判定结果**。
- 重型级（动作手感/动画类改动）：`godot --headless --write-movie <png序列> --fixed-fps 30 --quit-after N` 短录屏逐帧审查（Windows 本机可用，无需 xvfb）。
- 输入模拟：`game_manage` 的 `input_action` / `input_key`，不引外部工具。

**B — parallel-dev-spec 新增 §10**：前置三条件（D 段获批 + 接口冻结 H7 + A 就绪）齐备才开自主跑；自主循环「实现→单测→画面验证→修复」不请示；仅三个停靠点（① H2 契约变更 ② 清单外范围蔓延 ③ 波次收尾全量门禁）；护栏 = 连续 3 次修复未绿停下汇报（默认值，用户已认可）。

### 重访触发器（C# 决策）

自主波次运行后，若 GDScript 类型坑频繁触发护栏（连续 3 次修复不绿成为常态）**且**游戏内容规模显著增长，重访 C# 切换——直接以 Godogen 的 `docs/gdscript-vs-csharp.md` 为迁移蓝本。记录在此，防止重新调研。

### 分步执行清单（每步带验证点）

1. 本文档定稿（本段）→ verify: 本段存在且含三交付物清单。
2. `verify.md` 增加第 4 步「运行画面验证」 → verify: 文件含新步骤且原步骤 1–3 未动。
3. `parallel-dev-spec.md` 新增 §10 → verify: 文件含 §10 且 §1–9 未动。
4. 无头自检回归 → verify: `"$ENG" --headless --quit-after 3` 退出码 0（文档改动不应影响，跑一次确认）。

### 回滚方式

还原 `verify.md` 与 `parallel-dev-spec.md` 两文件、删除 PLANNING.md 的 D3 段即回 D1 完成态。无代码/配置残留。

### 实际执行 + 验证结果（2026-09-21 回写）

| 步骤 | 结果 | 验证 |
| :-- | :-- | :-- |
| 1. 本文档定稿 | ✅ | 本段即为记录 |
| 2. verify.md 第 4 步 | ✅ | 步骤 1–3 原文未动；新增第 4 步 + 触发条件 + 两级验证 + 输入模拟；最终报告增加"画面验证"小节 |
| 3. parallel-dev-spec.md §10 | ✅ | §1–9 原文未动（§9 后追加 §10）；含前置三条件/自主循环/三停靠点/护栏/占用声明 |
| 4. 无头自检回归 | ✅ | 退出码 0，无加载错误；GUT 全量 Scripts 6/6 · Tests 44/44 全绿（文档改动不影响基线） |

