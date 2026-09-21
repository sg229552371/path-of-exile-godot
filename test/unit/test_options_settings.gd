extends GutTest
## D27 Options 补齐（规格 §15）：sfx_volume / screen_shake / fullscreen 三项新设置持久化。
## Options 无 class_name → 用 preload 造实例（不经 autoload，防 GUT 改真实档）。隔离：每实例
## save_path 指唯一临时档（同 test_meta_progress），测后清理，不污染 user://settings.cfg。
## AudioServer dB / Window mode 属引擎面（headless 无窗口/无断言语义）→ 只测字段 + 落盘读回 +
## 独立不串扰 + 归默认；引擎面（总线建名、窗口切换）走实机冒烟。

const OPTIONS_SCRIPT := preload("res://scripts/core/options.gd")

var _temp_files: Array = []


func after_each() -> void:
	for path in _temp_files:
		var dir_path: String = path.get_base_dir()
		var fname: String = path.get_file()
		var dir := DirAccess.open(dir_path)
		if dir != null and dir.file_exists(fname):
			dir.remove(fname)
	_temp_files.clear()


## 造离树 Options 实例，save_path 指唯一临时档（缺档 → 读空 = 默认初值）。
func _new_options() -> Node:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive("tmp")
	var o := OPTIONS_SCRIPT.new()
	add_child_autofree(o)
	var tmp_path := "user://tmp/test_options_%s.cfg" % str(Time.get_ticks_usec())
	_temp_files.append(tmp_path)
	o.save_path = tmp_path
	o.load_settings()  # 空路径 → 默认初值（等价首启干净）
	return o


## 同 save_path 另造一个实例，读档回显（跨重启语义由磁盘承载）。
func _new_options_on(path: String) -> Node:
	var o := OPTIONS_SCRIPT.new()
	add_child_autofree(o)
	o.save_path = path
	o.load_settings()
	return o


func test_defaults_when_no_save() -> void:
	var o := _new_options()
	assert_eq(o.master_volume, 80, "主音量默认 80（规格）")
	assert_eq(o.sfx_volume, 100, "音效默认 100（用户拍板，无额外衰减）")
	assert_eq(o.show_damage_numbers, true, "伤害数字默认开")
	assert_eq(o.screen_shake, true, "屏幕震动默认开")
	assert_eq(o.fullscreen, false, "全屏默认关（用户拍板，开发期窗口化）")


func test_set_sfx_volume_persists_and_clamps() -> void:
	var o := _new_options()
	o.set_sfx_volume(45)
	assert_eq(o.sfx_volume, 45, "setter 记 45")
	var o2 := _new_options_on(o.save_path)
	assert_eq(o2.sfx_volume, 45, "落盘读回 45")
	o.set_sfx_volume(300)
	assert_eq(o.sfx_volume, 100, "超上限 clamp 到 100")
	o.set_sfx_volume(-5)
	assert_eq(o.sfx_volume, 0, "低于下限 clamp 到 0")


func test_set_screen_shake_persists() -> void:
	var o := _new_options()
	o.set_screen_shake(false)
	assert_eq(o.screen_shake, false, "setter 记 false")
	var o2 := _new_options_on(o.save_path)
	assert_eq(o2.screen_shake, false, "落盘读回 false")


func test_set_fullscreen_persists() -> void:
	var o := _new_options()
	o.set_fullscreen(true)
	assert_eq(o.fullscreen, true, "setter 记 true（headless 离树无窗口 → 只落盘不硬切）")
	var o2 := _new_options_on(o.save_path)
	assert_eq(o2.fullscreen, true, "落盘读回 true")


func test_volumes_are_independent() -> void:
	var o := _new_options()
	o.set_master_volume(50)
	assert_eq(o.sfx_volume, 100, "调主音量不扰动音效")
	o.set_sfx_volume(30)
	assert_eq(o.master_volume, 50, "调音效不扰动主音量")


func test_reset_restores_defaults() -> void:
	var o := _new_options()
	o.set_master_volume(10)
	o.set_sfx_volume(20)
	o.set_damage_numbers(false)
	o.set_screen_shake(false)
	o.set_fullscreen(true)
	o.reset()
	assert_eq(o.master_volume, 80, "reset 主音量回 80")
	assert_eq(o.sfx_volume, 100, "reset 音效回 100")
	assert_eq(o.show_damage_numbers, true, "reset 伤害数字回开")
	assert_eq(o.screen_shake, true, "reset 屏幕震动回开")
	assert_eq(o.fullscreen, false, "reset 全屏回关")
	var o2 := _new_options_on(o.save_path)
	assert_eq(o2.sfx_volume, 100, "reset 落盘后新实例读回默认")
	assert_eq(o2.fullscreen, false, "reset 落盘后全屏读回关")
