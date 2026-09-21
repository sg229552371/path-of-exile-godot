extends Node

## P6（D14.4）程序化合成音效 autoload。注册名：Sfx（无 class_name，仿 EventBus——访问
## 入口 = project.godot 的 autoload 名 `Sfx`）。零素材：所有短音在内存用 AudioStreamWAV
## 合成（16-bit PCM 22050Hz 单声道），一次性生成供轮转播放。
##
## 设计取舍：8 个 AudioStreamPlayer 轮转（round-robin），同帧多音不叠爆；全部短促
## （0.03~0.35s），不做音轨混音/总线。headless（GUT/CI）下 DisplayServer.get_name()
## 为 "headless" → 整体禁用（无音频设备警告、测试零噪音）。
##
## 接线点（每处一行 + 判空）见各调用方；新增音在 _register_builders() 注册 + 公开 play_xxx()。
##
## 规格 §18-12 音效事件名（权威真源，无资源也留名；资源后接真音，仅换合成函数）：
##   sfx_buy          → play_buy()        （购入成功/替换成交；合成成功也用 buy 系）
##   sfx_error        → play_error()      （金币不足/无合成对/未选中，操作无效）
##   sfx_levelup      → play_levelup()    （升级四选一）
##   sfx_wave         → play_wave()       （每波开场）
##   sfx_hit          → play_hit()        （敌人命中）
##   sfx_die          → play_death()      （玩家死亡）
##   sfx_pickup_gold  → play_pickup()     （豆拾取：XP/金币共用，规格只留名不拆）
##   sfx_combine      → play_combine()    （合成成功专用）

const SAMPLE_RATE := 22050
const PLAYERS := 8

## 音色注册表：名称 → 合成函数。每个函数返回 PackedFloat32Array（0..1 采样）。
var _builders := {}
## 名称 → 预合成 AudioStreamWAV。
var _streams := {}
## 轮转播放器游标。
var _cursor := 0
var _players: Array[AudioStreamPlayer] = []
## headless 下为 true → 全部 play_xxx() 早退（零噪音，不生成流）。
var _disabled := false


func _ready() -> void:
	_disabled = DisplayServer.get_name() == "headless"
	if _disabled:
		return
	_register_builders()
	_prepare_players()
	for key in _builders:
		_streams[key] = _synthesize(_builders[key] as Callable)


## 注册全部音色合成函数（短促、无素材）。
func _register_builders() -> void:
	_builders[&"hit"] = func() -> PackedFloat32Array:  # 命中：短促噪声+方波下降沿
		return _tone(0.09, 220.0, 0.5, 0.5, 0.3, 0.5)
	_builders[&"hurt"] = func() -> PackedFloat32Array:  # 受击：低音下坠
		return _tone(0.16, 160.0, 0.35, 0.9, 0.25, 0.4)
	_builders[&"shoot"] = func() -> PackedFloat32Array:  # 射击：短促上扫
		return _tone(0.05, 520.0, 0.7, 0.3, 0.0, 0.25)
	_builders[&"slash"] = func() -> PackedFloat32Array:  # 挥砍：中频锯齿瞬态
		return _tone(0.07, 360.0, 0.6, 0.4, 0.0, 0.3)
	_builders[&"pickup"] = func() -> PackedFloat32Array:  # 拾取：上行叮（两音）
		var a := _tone(0.06, 880.0, 0.5, 0.0, 0.0, 0.4)
		var b := _tone(0.08, 1320.0, 0.4, 0.0, 0.0, 0.35)
		return _concat(a, b)
	_builders[&"levelup"] = func() -> PackedFloat32Array:  # 升级：三音上行琶音
		var a := _tone(0.08, 660.0, 0.45, 0.0, 0.0, 0.4)
		var b := _tone(0.08, 990.0, 0.45, 0.0, 0.0, 0.4)
		var c := _tone(0.12, 1320.0, 0.5, 0.0, 0.0, 0.4)
		return _concat(_concat(a, b), c)
	_builders[&"death"] = func() -> PackedFloat32Array:  # 玩家死亡：低频下坠长音
		return _tone(0.4, 110.0, 0.3, 1.0, 0.2, 0.5)
	_builders[&"ui"] = func() -> PackedFloat32Array:  # UI 点击：短促木鱼
		return _tone(0.05, 980.0, 0.4, 0.0, 0.0, 0.5)
	_builders[&"win"] = func() -> PackedFloat32Array:  # 胜利：上行三音（上扬）
		var a := _tone(0.1, 523.0, 0.5, 0.0, 0.0, 0.4)
		var b := _tone(0.1, 659.0, 0.5, 0.0, 0.0, 0.4)
		var c := _tone(0.18, 784.0, 0.55, 0.0, 0.0, 0.45)
		return _concat(_concat(a, b), c)
	_builders[&"buy"] = func() -> PackedFloat32Array:  # 购入成功：短促双音上行（§18-12 sfx_buy）
		var a := _tone(0.06, 660.0, 0.5, 0.0, 0.0, 0.4)
		var b := _tone(0.09, 990.0, 0.5, 0.0, 0.0, 0.4)
		return _concat(a, b)
	_builders[&"error"] = func() -> PackedFloat32Array:  # 操作无效：低嘟下滑（§18-12 sfx_error）
		return _tone(0.18, 180.0, 0.35, 0.6, 0.0, 0.45)
	_builders[&"wave"] = func() -> PackedFloat32Array:  # 波次开场：短促方波号角（§18-12 sfx_wave）
		return _tone(0.12, 392.0, 0.5, 0.0, 0.15, 0.35)
	_builders[&"combine"] = func() -> PackedFloat32Array:  # 合成成功：清脆双音上行（§18-12 sfx_combine）
		var a := _tone(0.07, 784.0, 0.5, 0.0, 0.0, 0.4)
		var b := _tone(0.1, 1176.0, 0.5, 0.0, 0.0, 0.4)
		return _concat(a, b)


## 建 8 个轮转播放器（挂本 autoload 下，树生命周期管理，不手动 free）。
## D27：播放器走独立 **Sfx** 总线（主音量=Master、音效=Sfx 各自独立调；Options.autoload 启动
## _ensure_sfx_bus 已建该总线并默认路由输出 Master → 主音量 0 仍全局静音）。headless 无播放器。
func _prepare_players() -> void:
	for i in PLAYERS:
		var p := AudioStreamPlayer.new()
		p.bus = &"Sfx"
		add_child(p)
		_players.append(p)


## 公开播放入口（内部统一走这里，任何处接线只需调用对应 play_xxx）。
func _play(key: StringName) -> void:
	if _disabled or _players.is_empty() or not _streams.has(key):
		return
	var p := _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	p.stream = _streams[key]
	p.play()


## ---- 各接线点公开 API（一处一行 + 本文件判空，调用方无需判空） ----

## 敌人命中。
func play_hit() -> void:
	_play(&"hit")


## 玩家受击。
func play_hurt() -> void:
	_play(&"hurt")


## 远程射击。
func play_shoot() -> void:
	_play(&"shoot")


## 近战挥砍。
func play_slash() -> void:
	_play(&"slash")


## 经验豆拾取。
func play_pickup() -> void:
	_play(&"pickup")


## 升级选择。
func play_levelup() -> void:
	_play(&"levelup")


## 玩家死亡。
func play_death() -> void:
	_play(&"death")


## UI 按钮点击。
func play_ui() -> void:
	_play(&"ui")


## 胜利结算。
func play_win() -> void:
	_play(&"win")


## 购入成功（商店买武器/道具成交，§18-12 sfx_buy）。
func play_buy() -> void:
	_play(&"buy")


## 操作无效（金币不足/无合成对/未选中，§18-12 sfx_error）。
func play_error() -> void:
	_play(&"error")


## 波次开场（§18-12 sfx_wave）。
func play_wave() -> void:
	_play(&"wave")


## 合成成功（§18-12 sfx_combine）。
func play_combine() -> void:
	_play(&"combine")


## ---- 合成原语（PackedFloat32Array 0..1 采样，_ready 一次性转 AudioStreamWAV） ----

## 基音衰减音：freq 起始 / sweep 为频率下落比例（0=恒定）/ harmonic 谐波厚度 /
## falloff 指数衰减速率。返回 duration 秒采样（0..1）。
func _tone(duration: float, freq: float, vol: float, sweep: float, harmonic: float, falloff: float) -> PackedFloat32Array:
	var n := int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var f0 := freq
	var f1 := freq * (1.0 - sweep)
	var phase := 0.0
	var phase_inc := f0 * TAU / SAMPLE_RATE
	var phase_inc_delta := (f1 - f0) * TAU / SAMPLE_RATE / n
	for i in n:
		# 线性扫频相位：每样本累加当前瞬时角增量（频率滑落 → 相位随积分走，防漂移）。
		phase += phase_inc
		phase_inc += phase_inc_delta
		# 方波基音 + 少量谐波（相位乘 2 得高频方波），"电子质感"。
		var s := 1.0 if fmod(phase, TAU) < PI else -1.0
		var h := 1.0 if fmod(phase * 2.0 + 0.5, TAU) < PI else -1.0
		s = lerpf(s, h, harmonic)
		# 指数衰减包络（falloff 越大衰减越快）。
		var t := float(i) / SAMPLE_RATE
		s *= exp(-falloff * t * 8.0) * vol
		out[i] = s
	return out


## 拼接两个采样段（拾取/升级/胜利的多音上行）。
func _concat(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size() + b.size())
	for i in a.size():
		out[i] = a[i]
	for i in b.size():
		out[a.size() + i] = b[i]
	return out


## PackedFloat32Array(0..1) → 16-bit PCM AudioStreamWAV。
func _synthesize(builder: Callable) -> AudioStreamWAV:
	var samples := builder.call() as PackedFloat32Array
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	stream.data = bytes
	return stream
