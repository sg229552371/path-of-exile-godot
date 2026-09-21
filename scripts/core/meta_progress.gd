extends Node

## 元进度单例（服务层，P5 D13.2 / 2g-5a 扩展）。Autoload 注册名：MetaProgress。
## 注意：与 EventBus/TimeControl 一致，本脚本【不声明 class_name】——访问入口 =
## project.godot 的 autoload 名 `MetaProgress`（全局标识符）。测试用 load() 造实例。
## 职责：跨对局的**最小持久化统计 + 危险解锁 + 图鉴已见**（用户拍板"最小可存档"）。
## 统计：总局数/总击杀/总胜场/最高存活波数，随每局结算累加。
## 危险解锁（2g-5a，规格 §9/§18.8 残骸）：通关危险 n → 解锁 n+1（封顶 5），危险 0 初始可玩。
## 图鉴已见（2g-5a，规格 §15）：胜/败都给"残骸"——把本局最终构筑(武器/道具 id) + 见过的敌记入
## 可见列表，只解锁图鉴内容，不加任何战力（§18.8）。
## 存读：ConfigFile 自动存 user://meta_progress.cfg。缺档给零初值（首启干净）。
##
## 用法：
##   MetaProgress.record_match(win, wave, kills)                      # 旧统计入口（legacy，语义不变）
##   MetaProgress.record_result(win, danger, wave, kills, seen_w, seen_i, seen_e)  # 完整结算（统计+解锁+图鉴）
##   MetaProgress.games_played()/kills()/wins()/best_wave()           # 只读统计
##   MetaProgress.highest_unlocked_danger()/seen_weapons()/seen_items()/seen_enemies()  # 解锁/图鉴只读
##   MetaProgress.reset()                                             # 清零（测试/调试）
##
## 存读容错：load 缺档/损坏都归零初值并 push_warning（可预期输入，非 push_error——
## 见 rules/testing：可测的预期失败用 warning）。

const DEFAULT_SAVE_PATH := "user://meta_progress.cfg"
const SECTION := "meta"
const DANGER_MAX := 5  ## 危险 0..5，通关最高封顶解锁到 5。

## 存档路径。默认 user://meta_progress.cfg；GUT 测试把它指到临时文件以隔离真实档
## （见 test_meta_progress.gd）。仅此一处与磁盘耦合，非投机扩展。
var save_path: String = DEFAULT_SAVE_PATH

var _games_played := 0
var _total_kills := 0
var _wins := 0
var _best_wave := 0
var _unlocked_danger := 0      ## 最高可选危险等级（0..5）。通关当前最高级 → 下一级解锁。
var _seen_weapons: Array = []  ## 已见武器 id（String 列表，去重；Codex 已见/??? 数据源）。
var _seen_items: Array = []
var _seen_enemies: Array = []


func _ready() -> void:
	# 对局外壳先于任何 scene 用本单例；启动即读档，主菜单显示统计前就绪。
	load_save()


## ---- 结算记录 ----

## 旧统计入口（legacy slice 用）：只累加四计数。保留语义，供既有调用/测试。
func record_match(win: bool, wave: int, kills: int) -> void:
	_record_core(win, wave, kills)
	save_save()


## 完整一局结算（2g-5a 流放者入口）：统计累加 + 危险解锁 + 图鉴残骸收录，单次落盘。
## win=通关；danger=本局危险等级；wave=本局最高波；kills=本局击杀。
## seen_weapons/seen_items/seen_enemies：本局"残骸"带回来的可见 id 列表（胜/败都收录，只解锁图鉴）。
func record_result(win: bool, danger: int, wave: int, kills: int,
		seen_weapons: Array = [], seen_items: Array = [], seen_enemies: Array = []) -> void:
	_record_core(win, wave, kills)
	if win:
		# 通关当前最高可玩危险 → 解锁其下一级（danger+1，封顶 5）。重玩低危险不倒退/不越级。
		_unlocked_danger = maxi(_unlocked_danger, mini(danger + 1, DANGER_MAX))
	_merge_seen(_seen_weapons, seen_weapons)
	_merge_seen(_seen_items, seen_items)
	_merge_seen(_seen_enemies, seen_enemies)
	save_save()


## 纯累加四计数（不落盘；落盘由公开入口各自负责，避免双写）。
func _record_core(win: bool, wave: int, kills: int) -> void:
	_games_played += 1
	_total_kills += kills
	if win:
		_wins += 1
	if wave > _best_wave:
		_best_wave = wave


## 去重合并一条 id 列表进目标（存 String，跨 cfg 往返稳定）。
func _merge_seen(target: Array, ids: Array) -> void:
	for id in ids:
		var s := str(id)
		if s.is_empty() or target.has(s):
			continue
		target.append(s)


## ---- 只读查询（统计） ----

func games_played() -> int:
	return _games_played


func total_kills() -> int:
	return _total_kills


func wins() -> int:
	return _wins


func best_wave() -> int:
	return _best_wave


## ---- 只读查询（危险解锁 / 图鉴，2g-5a） ----

## 当前最高可选危险等级（0..5）。DangerSelect 亮 ≤ 此值，以上灰置「通关危险 n-1」。
func highest_unlocked_danger() -> int:
	return _unlocked_danger


func seen_weapons() -> Array:
	return _seen_weapons.duplicate()


func seen_items() -> Array:
	return _seen_items.duplicate()


func seen_enemies() -> Array:
	return _seen_enemies.duplicate()


## 图鉴已见条目总数（Result 残骸「收录 +N」用；结算前后差值 = 本局新增）。
func codex_total_seen() -> int:
	return _seen_weapons.size() + _seen_items.size() + _seen_enemies.size()


## ---- 存读 ----

## 从磁盘读档。缺档/损坏 → 归零初值（首启或异常），不视为错误。
func load_save() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(save_path)
	if err != OK:
		_reset_in_memory()
		return
	_games_played = int(cfg.get_value(SECTION, "games_played", 0))
	_total_kills = int(cfg.get_value(SECTION, "total_kills", 0))
	_wins = int(cfg.get_value(SECTION, "wins", 0))
	_best_wave = int(cfg.get_value(SECTION, "best_wave", 0))
	_unlocked_danger = clampi(int(cfg.get_value(SECTION, "unlocked_danger", 0)), 0, DANGER_MAX)
	_seen_weapons = _read_ids(cfg, "seen_weapons")
	_seen_items = _read_ids(cfg, "seen_items")
	_seen_enemies = _read_ids(cfg, "seen_enemies")


func _read_ids(cfg: ConfigFile, key: String) -> Array:
	var out: Array = []
	for v in cfg.get_value(SECTION, key, []):
		out.append(str(v))
	return out


## 写当前统计到磁盘（覆写）。失败 → push_warning（磁盘满/权限等，可预期，不打断玩法）。
func save_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "games_played", _games_played)
	cfg.set_value(SECTION, "total_kills", _total_kills)
	cfg.set_value(SECTION, "wins", _wins)
	cfg.set_value(SECTION, "best_wave", _best_wave)
	cfg.set_value(SECTION, "unlocked_danger", _unlocked_danger)
	cfg.set_value(SECTION, "seen_weapons", _seen_weapons)
	cfg.set_value(SECTION, "seen_items", _seen_items)
	cfg.set_value(SECTION, "seen_enemies", _seen_enemies)
	var err := cfg.save(save_path)
	if err != OK:
		push_warning("MetaProgress.save: 写档失败 err=%d path=%s" % [err, save_path])


## 清零全部统计/解锁/图鉴并落盘（测试隔离 / 调试入口）。
func reset() -> void:
	_reset_in_memory()
	save_save()


func _reset_in_memory() -> void:
	_games_played = 0
	_total_kills = 0
	_wins = 0
	_best_wave = 0
	_unlocked_danger = 0
	_seen_weapons = []
	_seen_items = []
	_seen_enemies = []
