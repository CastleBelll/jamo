extends Control
## 마지막 서고 (G10) skeleton: Gold / 발견 수 / 최고 기록 placeholders and the RUN button.
## Meta persistence arrives in P4; until then the counters show zero.

const RUN_SCENE := "res://scenes/run/run_game.tscn"


func _ready() -> void:
	%RunButton.pressed.connect(func(): get_tree().change_scene_to_file(RUN_SCENE))
	%RunButton.grab_focus()
