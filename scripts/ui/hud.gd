extends CanvasLayer
## HUD (G10): Wave, 안정도, 남은 적, RUN Gold, 빌드 슬롯, 임시 회수. Reads RunController
## signals only; combat pushes enemy/drop counts through set_* calls.

@onready var wave_label: Label = %WaveLabel
@onready var stability_label: Label = %StabilityLabel
@onready var stability_bar: ProgressBar = %StabilityBar
@onready var enemies_label: Label = %EnemiesLabel
@onready var gold_label: Label = %GoldLabel
@onready var drops_label: Label = %DropsLabel


func bind(run: RunController) -> void:
	run.wave_changed.connect(_on_wave_changed)
	run.stability_changed.connect(_on_stability_changed)
	run.gold_changed.connect(_on_gold_changed)
	_on_wave_changed(run.wave)
	_on_stability_changed(run.stability, run.stability_max)
	_on_gold_changed(run.gold_run)
	set_enemies_left(0)
	set_temp_drops(0)


func set_enemies_left(count: int) -> void:
	enemies_label.text = "남은 적 %d" % count


func set_temp_drops(count: int) -> void:
	drops_label.text = "회수 %d" % count


func _on_wave_changed(wave: int) -> void:
	wave_label.text = "Wave %d" % wave


func _on_stability_changed(current: float, maximum: float) -> void:
	stability_label.text = "안정도 %.1f / %.0f" % [current, maximum]
	stability_bar.max_value = maximum
	stability_bar.value = current


func _on_gold_changed(gold: float) -> void:
	gold_label.text = "%d G" % int(gold)
