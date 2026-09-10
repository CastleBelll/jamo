extends Control

## RUN 결과 화면. Doc v0.4 section 35.
##
## Phase 0 shows the minimum the spec calls for: the wave that was reached, the
## kills, and the gold that was earned and kept. The rest of the section 35
## readout - new codex words, mastery gains, compounds, bosses, the run build -
## needs systems that do not exist yet and arrives with the phase that adds them.
##
## PHASE 1 REVERT POINT. The SubtitleLabel in run_result.tscn names the stand-in
## failure condition - running out of energy - because the 문장핵 is Phase 1 work
## and nothing damages it yet (see Main.end_run_when_energy_depleted). It used to
## read "문장핵이 무너졌다..." while the HUD still showed 문장핵 20/20, which was a
## lie on screen. When Phase 1 turns that flag off and the core becomes the real
## failure, set the subtitle back to
##   "문장핵이 무너졌다. 다음 RUN 은 WAVE 1 부터 시작한다."

signal hub_requested()

@onready var _wave_label: Label = %ResultWaveLabel
@onready var _kills_label: Label = %ResultKillsLabel
@onready var _gold_label: Label = %ResultGoldLabel
@onready var _record_label: Label = %ResultRecordLabel
@onready var _hub_button: Button = %ResultHubButton


func _ready() -> void:
	hide()
	_hub_button.pressed.connect(_on_hub_pressed)


## `gold_earned` is what this run added to the permanent balance. It is stated
## as kept, because doc v0.4 section 14 is explicit that a defeat never takes
## gold back and the screen has to make that obvious.
func open(wave: int, kills: int, gold_earned: float, is_record: bool) -> void:
	_wave_label.text = "도달 WAVE  %d" % wave
	_kills_label.text = "처치  %d" % kills
	_gold_label.text = "획득 GOLD  %d G  (유지됨)" % int(floorf(gold_earned))
	# The record line is text, not a colour flash, so the cue survives for a
	# player who cannot tell the two states apart by hue.
	_record_label.visible = is_record
	show()
	_hub_button.grab_focus()


func _on_hub_pressed() -> void:
	hide()
	hub_requested.emit()
