class_name EventKeys
extends RefCounted

## 跨系统事件键集中声明（P1，D7.4）。
## EventBus 的 fire/on 一律引用本类常量，禁止魔法字符串散落；
## 后续阶段新增事件先在此登记并注明语义。

## 玩家当前生命（arg: int = 当前 HP）。player 在 ready 与每次血量变化时发，供 HUD/UI 刷新。
const PLAYER_HP := &"player_hp"

## 敌人被击杀（arg: null）。enemy 死亡时发，供 HUD 击杀计数 / 波次计数。
const ENEMY_KILLED := &"enemy_killed"

## 拾取经验豆（arg: int = 豆数量）。xp_orb 被玩家拾取时发，供 HUD/经验累计。
const XP_PICKED := &"xp_picked"

## 玩家死亡（arg: null）。player 生命归零发，触发对局结束流程。
const PLAYER_DIED := &"player_died"

## 对局结束（arg: null）。round_flow 收到 PLAYER_DIED 延迟后发，触发 GameOver UI。
const GAME_OVER := &"game_over"

## 波次开始（arg: int = 波号）。wave_manager 每波开刷时发，供 HUD 显示"第 N 波"。
const WAVE_STARTED := &"wave_started"

## 剩余对局时间（arg: int = 剩余秒）。round 计时器周期发，供 HUD 刷倒计时。
const ROUND_TIME := &"round_time"

## 对局胜利（arg: int = 存活波数）。存活到时间归零发，触发胜利结算。
const ROUND_WON := &"round_won"

## 对局失败（arg: null）。玩家死亡发（P1 PLAYER_DIED 路径汇总到结算）。
const ROUND_LOST := &"round_lost"

## 玩家持武/装备快照（arg: { slots: [{id,name}], equipped: int }）。拾取/切换时 player 发，供 HUD 槽位条刷新。
const WEAPON_SLOTS := &"weapon_slots"
