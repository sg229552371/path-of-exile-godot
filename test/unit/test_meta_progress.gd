extends GutTest
## P5 元进度单例（D13.2）：跨对局最小持久化统计——record_match 累加并落盘、load 读回一致、
## reset 归零、缺档给零初值。用 load() 造实例测（不经 autoload，防 GUT 改真实档）。
## 隔离：每实例把 save_path 指到唯一临时文件（user://tmp/…），测后清理——不污染真实
## user://meta_progress.cfg（否则 GUT 会把开发中的真实统计清零）。

const META_SCRIPT := preload("res://scripts/core/meta_progress.gd")

var _temp_files: Array = []


func _make_tmp_dir() -> void:
	# ConfigFile.save 到不存在的子目录会静默失败（err=7）——先递归建目录再写。
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive("tmp")


func after_each() -> void:
	# 清掉本用例产生的临时档（DirAccess 删 user:// 下临时文件）。
	for path in _temp_files:
		var dir_path: String = path.get_base_dir()
		var fname: String = path.get_file()
		var dir := DirAccess.open(dir_path)
		if dir != null and dir.file_exists(fname):
			dir.remove(fname)
	_temp_files.clear()


func _new_meta() -> Node:
	_make_tmp_dir()
	var m := META_SCRIPT.new()
	add_child_autofree(m)
	var tmp_path := "user://tmp/test_meta_%s.cfg" % str(Time.get_ticks_usec())
	_temp_files.append(tmp_path)
	m.save_path = tmp_path
	m.load_save()  # 指向空路径 → 归零初值（等价缺档）
	return m


func test_defaults_zero_when_no_save() -> void:
	# 临时路径缺档 → 零初值（首启干净）。
	var m := _new_meta()
	assert_eq(m.games_played(), 0, "总局数初值 0")
	assert_eq(m.total_kills(), 0, "总击杀初值 0")
	assert_eq(m.wins(), 0, "总胜场初值 0")
	assert_eq(m.best_wave(), 0, "最高波初值 0")


func test_record_match_accumulates() -> void:
	var m := _new_meta()
	m.record_match(false, 3, 5)   # 一败：3 波、5 击杀
	assert_eq(m.games_played(), 1, "败局也计 1 局")
	assert_eq(m.total_kills(), 5, "击杀累加 5")
	assert_eq(m.wins(), 0, "败局不加胜场")
	assert_eq(m.best_wave(), 3, "最高波 3")
	m.record_match(true, 4, 2)    # 一胜：4 波、2 击杀
	assert_eq(m.games_played(), 2, "累计 2 局")
	assert_eq(m.total_kills(), 7, "击杀累加 5+2=7")
	assert_eq(m.wins(), 1, "胜场 1")
	assert_eq(m.best_wave(), 4, "最高波升到 4")
	m.record_match(true, 2, 1)    # 更低波不胜于既有最高
	assert_eq(m.best_wave(), 4, "最高波只增不减")


func test_save_then_fresh_instance_loads() -> void:
	# 落盘后新实例（同 save 路径）读回一致——跨进程重启由同一磁盘文件承载。
	_make_tmp_dir()
	var path := "user://tmp/test_meta_persist.cfg"
	_temp_files.append(path)
	var m1 := META_SCRIPT.new()
	add_child_autofree(m1)
	m1.save_path = path
	m1.load_save()
	m1.record_match(true, 6, 12)
	var m2 := META_SCRIPT.new()
	add_child_autofree(m2)
	m2.save_path = path
	m2.load_save()  # 自磁盘读回
	assert_eq(m2.games_played(), 1, "读回 1 局")
	assert_eq(m2.total_kills(), 12, "读回击杀 12")
	assert_eq(m2.wins(), 1, "读回胜场 1")
	assert_eq(m2.best_wave(), 6, "读回最高波 6")


func test_reset_clears_and_persists() -> void:
	var m := _new_meta()
	m.record_match(false, 2, 3)
	m.reset()
	assert_eq(m.games_played(), 0, "reset 后总局数 0")
	assert_eq(m.total_kills(), 0, "reset 后击杀 0")
	assert_eq(m.wins(), 0, "reset 后胜场 0")
	assert_eq(m.best_wave(), 0, "reset 后最高波 0")
	var m2 := META_SCRIPT.new()
	add_child_autofree(m2)
	m2.save_path = m.save_path
	m2.load_save()
	assert_eq(m2.games_played(), 0, "reset 落盘后新实例也归零")


## ---- 2g-5a：record_result（危险解锁 / 图鉴残骸 / 落盘） ----

func test_record_result_loss_no_unlock_but_collects_remnant() -> void:
	var m := _new_meta()
	m.record_result(false, 3, 5, 10, ["w_bow"], [], ["enemy_grunt"])
	assert_eq(m.games_played(), 1, "败局计 1 局")
	assert_eq(m.total_kills(), 10, "击杀累加 10")
	assert_eq(m.wins(), 0, "败局不加胜场")
	assert_eq(m.highest_unlocked_danger(), 0, "败局不解锁危险")
	assert_eq(m.codex_total_seen(), 2, "败局也收残骸（w_bow+grunt）")
	assert_eq(m.seen_weapons(), ["w_bow"], "武器已见收录")
	assert_eq(m.seen_enemies(), ["enemy_grunt"], "敌已见收录")


func test_record_result_win_unlocks_next_danger_capped() -> void:
	var m := _new_meta()
	m.record_result(true, 0, 1, 3)
	assert_eq(m.highest_unlocked_danger(), 1, "通关危险0 → 解锁1")
	assert_eq(m.wins(), 1, "胜场 1")
	m.record_result(true, 0, 1, 1)
	assert_eq(m.highest_unlocked_danger(), 1, "低危重打不倒退")
	m.record_result(true, 5, 20, 9)
	assert_eq(m.highest_unlocked_danger(), 5, "通关危险5 封顶=5")


func test_record_result_merges_seen_dedupe() -> void:
	var m := _new_meta()
	m.record_result(false, 0, 1, 1, ["w_bow", "w_knife"], [], ["enemy_grunt"])
	m.record_result(true, 0, 1, 1, ["w_bow"], ["i_relic"], [])  # w_bow 重复、新 i_relic
	assert_eq(m.codex_total_seen(), 4, "去重后 4 类目（2武器+grunt+relic）")
	assert_eq(m.seen_weapons(), ["w_bow", "w_knife"], "武器去重保序")
	assert_eq(m.seen_items(), ["i_relic"], "道具已见收录")
	assert_eq(m.seen_enemies(), ["enemy_grunt"], "敌已见不重复")


func test_record_result_persists_unlock_and_seen() -> void:
	_make_tmp_dir()
	var path := "user://tmp/test_meta_result_persist.cfg"
	_temp_files.append(path)
	var m1 := META_SCRIPT.new()
	add_child_autofree(m1)
	m1.save_path = path
	m1.load_save()
	m1.record_result(true, 1, 6, 12, ["w_bow", "w_spear"], ["i_relic"], ["enemy_grunt"])
	var m2 := META_SCRIPT.new()
	add_child_autofree(m2)
	m2.save_path = path
	m2.load_save()  # 自磁盘读回
	assert_eq(m2.highest_unlocked_danger(), 2, "读回解锁2")
	assert_eq(m2.seen_weapons(), ["w_bow", "w_spear"], "读回武器已见")
	assert_eq(m2.seen_items(), ["i_relic"], "读回道具已见")
	assert_eq(m2.seen_enemies(), ["enemy_grunt"], "读回敌已见")
