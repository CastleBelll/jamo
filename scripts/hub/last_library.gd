extends Control
## 마지막 서고 (G10/G14): Gold, discoveries, best record, RUN / 이어하기, and the corrupt-save
## notice with the consent button for a new profile. Research/codex UI arrive next.

const RUN_SCENE := "res://scenes/run/run_game.tscn"


func _ready() -> void:
	%RunButton.pressed.connect(_on_new_run)
	%ContinueButton.pressed.connect(_on_continue)
	%NewProfileButton.pressed.connect(_on_new_profile)
	_refresh()


func _refresh() -> void:
	%GoldLabel.text = "Gold %d" % Meta.gold
	%DiscoveredLabel.text = "발견 %d" % Meta.codex.size()
	%BestLabel.text = "최고 기록 도달 W%d · 클리어 W%d" % [Meta.best_reached, Meta.best_cleared] if Meta.best_reached > 0 else "최고 기록 -"
	%ContinueButton.visible = Meta.has_run()
	%RunButton.text = "새 RUN (진행 중 RUN 삭제)" if Meta.has_run() else "RUN"
	var corrupt := Meta.corrupt
	%CorruptLabel.visible = corrupt
	%NewProfileButton.visible = corrupt and Meta.load_source == "none"
	if corrupt:
		%CorruptLabel.text = "저장 파일이 손상되어 백업으로 복구했습니다." if Meta.load_source == "backup" else "저장 파일이 손상되었습니다. 새 프로필을 만들면 기존 기록은 사라집니다."
	if Meta.has_run():
		%ContinueButton.grab_focus()
	else:
		%RunButton.grab_focus()


func _on_new_run() -> void:
	Meta.run = {}
	Meta.resume_pending = false
	Meta.save()
	get_tree().change_scene_to_file(RUN_SCENE)


func _on_continue() -> void:
	Meta.resume_pending = true
	get_tree().change_scene_to_file(RUN_SCENE)


func _on_new_profile() -> void:
	Meta.new_profile()
	_refresh()
