extends Control

## Day summary shown the moment energy hits zero. Doc v0.3 section 12.

signal closed()

@onready var _title_label: Label = %DayEndTitle
@onready var _kills_label: Label = %DayEndKills
@onready var _gold_label: Label = %DayEndGold


func _ready() -> void:
	hide()
	%DayEndContinue.pressed.connect(_on_continue_pressed)


func open(day: int, kills: int, gold_earned: float) -> void:
	_title_label.text = "DAY %d 종료" % day
	_kills_label.text = "처치한 자모   %d" % kills
	_gold_label.text = "획득한 골드   %d G" % int(gold_earned)
	show()
	%DayEndContinue.grab_focus()


func _on_continue_pressed() -> void:
	hide()
	closed.emit()
