extends Node

## 设置单例（服务层，2g-5c）。Autoload 注册名：Options。
## 与 EventBus/MetaProgress/Sfx 一致：本脚本【不声明 class_name】——访问入口 =
## project.godot 的 autoload 名 `Options`。测试用 load() 造实例 / save_path 指临时档。
## 职责：跨会话最小设置持久化（D1 Options 补齐 5 项，规格 §15）：
##   主音量(0..100) / 音效(0..100) / 伤害数字(开关) / 屏幕震动(开关) / 全屏(开关)。
## 音量落点（D27 拆分双总线）：**主音量 → Master**、**音效 → Sfx 独立总线**
## （sfx.gd 播放器已迁 Sfx；Sfx 总线由 _ensure_sfx_bus 建并显式路由输出 Master，主音量 0 仍全局静音）。
## 映射 v→dB：v<=0 → -80（静音），否则 linear_to_db(v/100)。音效默认 100 = 无额外衰减
## （主 80×音 100 ≈ 拆分前听感一致，无回归；偏离规格表 80，用户拍板 2026-09-09）。
## 全屏默认关（窗口化）——偏离规格表默认开，用户拍板（开发期 F5 友好），发售前可改回。
## 存读：ConfigFile 自动存 user://settings.cfg。缺档给默认（首启干净）。
## 改即生效 + 即落盘：set_master_volume/set_sfx_volume/set_screen_shake/set_fullscreen/
## set_damage_numbers；UI 直接调 setter（勿裸写字段，裸写不落盘不生效——字段仅存值，
## 磁盘/总线/窗口由 setter 负责）。

const DEFAULT_SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"
const DEFAULT_VOLUME := 80
const DEFAULT_SFX_VOLUME := 100
const DEFAULT_FULLSCREEN := false

## 存档路径。默认 user://settings.cfg；冒烟/GUT 指到临时文件隔离真实档。仅此一处与磁盘耦合。
var save_path: String = DEFAULT_SAVE_PATH

## 当前设置值（public 只读；改动走 set_*）。
var master_volume := DEFAULT_VOLUME      ## 0..100。
var sfx_volume := DEFAULT_SFX_VOLUME     ## 0..100（主音量的独立音效层）。
var show_damage_numbers := true
var screen_shake := true
var fullscreen := false

const BUS_MASTER := &"Master"
const BUS_SFX := &"Sfx"

func _ready() -> void:
	# 启动即读档并套到总线/窗口；此后 setter 即时应用。
	load_settings()
	_apply_master_volume()
	_apply_sfx_volume()
	_apply_fullscreen()


## ---- 改动入口（改即生效 + 落盘） ----

func set_master_volume(v: int) -> void:
	master_volume = clampi(v, 0, 100)
	_apply_master_volume()
	save_settings()


func set_sfx_volume(v: int) -> void:
	sfx_volume = clampi(v, 0, 100)
	_apply_sfx_volume()
	save_settings()


func set_damage_numbers(v: bool) -> void:
	show_damage_numbers = v
	save_settings()


func set_screen_shake(v: bool) -> void:
	screen_shake = v
	save_settings()


## 全屏：落盘 + 即时套窗口模式（离树/测试无窗口则只落盘，判空）。
func set_fullscreen(v: bool) -> void:
	fullscreen = v
	save_settings()
	var win := _window_or_null()
	if win != null:
		win.mode = Window.MODE_FULLSCREEN if v else Window.MODE_WINDOWED


## ---- 存读 ----

## 从磁盘读档。缺档 → 默认值（首启），不落盘。
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		_reset_in_memory()
		return
	master_volume = clampi(int(cfg.get_value(SECTION, "master_volume", DEFAULT_VOLUME)), 0, 100)
	sfx_volume = clampi(int(cfg.get_value(SECTION, "sfx_volume", DEFAULT_SFX_VOLUME)), 0, 100)
	show_damage_numbers = bool(cfg.get_value(SECTION, "show_damage_numbers", true))
	screen_shake = bool(cfg.get_value(SECTION, "screen_shake", true))
	fullscreen = bool(cfg.get_value(SECTION, "fullscreen", DEFAULT_FULLSCREEN))


## 写当前设置到磁盘（覆写）。失败 → push_warning（磁盘满/权限等，可预期，不打断玩法）。
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.set_value(SECTION, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION, "show_damage_numbers", show_damage_numbers)
	cfg.set_value(SECTION, "screen_shake", screen_shake)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	var err := cfg.save(save_path)
	if err != OK:
		push_warning("Options.save: 写档失败 err=%d path=%s" % [err, save_path])


## 归默认 + 套总线/窗口 + 落盘（测试隔离 / 调试入口）。
func reset() -> void:
	_reset_in_memory()
	_apply_master_volume()
	_apply_sfx_volume()
	_apply_fullscreen()
	save_settings()


func _reset_in_memory() -> void:
	master_volume = DEFAULT_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	show_damage_numbers = true
	screen_shake = true
	fullscreen = DEFAULT_FULLSCREEN


## 主音量 → Master 总线 dB（v<=0 静音 -80，否则线性刻度）。Master 总线恒在，直查不建。
func _apply_master_volume() -> void:
	var idx := AudioServer.get_bus_index(BUS_MASTER)
	if idx < 0:
		return
	var db := -80.0 if master_volume <= 0 else linear_to_db(float(master_volume) / 100.0)
	AudioServer.set_bus_volume_db(idx, db)


## 音效 → Sfx 总线 dB（同 Master 映射）。Sfx 总线可能缺省 → 先 _ensure_sfx_bus 自建。
## Sfx 总线由 _prepare_players 前自建并设默认路由（audio/sfx/default_bus_effect 未配时
## 新建总线默认路由到 Master 输出 → 主音量 0 仍全局静音）。无总线（headless 边缘）幂等跳过。
func _apply_sfx_volume() -> void:
	var idx := _ensure_sfx_bus()
	if idx < 0:
		return
	var db := -80.0 if sfx_volume <= 0 else linear_to_db(float(sfx_volume) / 100.0)
	AudioServer.set_bus_volume_db(idx, db)


## 确保存在名为 Sfx 的总线（无则新建，idx 返回；恒在则返回现有 idx）。仅本文件访问总线名。
## 建总线：add_bus() 返回 void → 新总线恒追加到末尾，idx = bus_count-1（bus 0 恒为 Master，
## 故 Sfx 追加在 Master 之后）。建后 set_bus_name 整条改名 + set_bus_send 显式路由到 Master
## （新总线默认 send 为空串，语义不明确 → 显式送 Master，保证"主音量 0 = 全局静音"）。
func _ensure_sfx_bus() -> int:
	var idx := AudioServer.get_bus_index(BUS_SFX)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	var new_idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(new_idx, BUS_SFX)
	AudioServer.set_bus_send(new_idx, BUS_MASTER)
	return new_idx


## 全屏套窗口模式（startup 读档后 / reset）。判空：编辑器/离树（无 project window）不硬切。
func _apply_fullscreen() -> void:
	if _window_or_null() != null:
		_window_or_null().mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED


## 当前主窗口，或 null（headless / 离树实例无窗口上下文）。本 autoload 运行时在树内 →
## get_window() 即主窗口；GUT 用 load() 造离树实例（未入树）→ 返回 null，只落盘不硬切。
func _window_or_null() -> Window:
	if DisplayServer.get_name() == "headless":
		return null
	return get_window() if is_inside_tree() else null
