extends Node

## 全局时间 / 暂停控制（服务层，D5 M5）。Autoload 注册名：TimeControl。
## 全项目"玩法暂停 / DNF 顿帧(hit-stop)"的【唯一】入口；禁止散落 Engine.time_scale= 或 OS.delay_*。
## 自身 process_mode = PROCESS_MODE_ALWAYS：get_tree().paused 只停 pausable 节点，本节点不受影响，
## 仍按真实帧推进 → hitstop 到期自行恢复，无需外部调度（规避 time_scale 自我拖慢的坑）。
## 与"编辑器暂停"区分：编辑器（远程调试器）暂停走引擎自身通道，不经本类；本类只管运行时玩法树的 paused。
## set_paused 的玩法暂停与 hitstop 相互独立、可叠加：任一激活即停，全部解除才恢复。
## 注意：与同批 EventBus 一致，本脚本【不声明 class_name】——访问入口 = project.godot 的 autoload 名
## `TimeControl`（全局标识符）。同名 class_name + autoload 会撞全局标识符，故由 autoload 提供。（§M5 草案
## 写 class_name，实现按 EventBus 先例统一省略，见 PLANNING D5 批次 2 执行记录。）
## 用法：
##   TimeControl.hitstop(0.05)      # 顿帧 50ms（真实秒），到期自动恢复并 emit hitstop_finished
##   TimeControl.set_paused(true)   # 玩法暂停（如暂停菜单）
##   TimeControl.is_paused()

## 手动暂停（set_paused）状态变更时触发；参数为最新暂停态。
signal pause_changed(paused: bool)
## 一次 hitstop 走完、玩法即将恢复时触发。
signal hitstop_finished

var _manual_paused := false       # set_paused 请求的玩法暂停（与 hitstop 独立）
var _hitstop_remaining := 0.0     # 顿帧剩余真实秒；>0 即处于 hitstop 中


func _ready() -> void:
	# Autoload 须在任意暂停发生前就脱离 pausable，_ready（启动期，未暂停）设置即足够。
	process_mode = Node.PROCESS_MODE_ALWAYS


## 运行帧推进 hitstop 计时。ALWAYS 模式下即使玩法树被暂停本节点仍每帧被调用。
func _process(delta: float) -> void:
	if _hitstop_remaining <= 0.0:
		return
	_hitstop_remaining -= delta
	if _hitstop_remaining <= 0.0:
		_hitstop_remaining = 0.0
		hitstop_finished.emit()
		_sync_tree_paused()


## 顿帧：玩法树暂停 seconds 真实秒后自动恢复。seconds 非正 → 忽略并告警（调用方 bug）。
## 已有 hitstop 进行中再次调用 → 取二者较大者：连击顿帧不被缩短，也不无限叠加。
func hitstop(seconds: float) -> void:
	if seconds <= 0.0:
		push_warning("TimeControl.hitstop: 时长须为正（收到 %.4f）" % seconds)
		return
	_hitstop_remaining = maxf(_hitstop_remaining, seconds)
	_sync_tree_paused()


## 玩法暂停开关（幂等：与当前手动暂停一致时无操作、不发信号）。
func set_paused(p: bool) -> void:
	if p == _manual_paused:
		return
	_manual_paused = p
	pause_changed.emit(p)
	_sync_tree_paused()


## 当前是否处于暂停：手动暂停或 hitstop 任一激活即视为暂停（供 UI/逻辑只读查询）。
func is_paused() -> bool:
	return _manual_paused or _hitstop_remaining > 0.0


## 把"是否应暂停"落到 SceneTree.paused（本类为该项目状态的唯一写者，写入前比较避免无谓赋值）。
func _sync_tree_paused() -> void:
	var should := _manual_paused or _hitstop_remaining > 0.0
	if get_tree().paused == should:
		return
	get_tree().paused = should
