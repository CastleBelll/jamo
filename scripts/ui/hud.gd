extends CanvasLayer
## HUD (G10): Wave, 안정도, 남은 적, RUN Gold, 빌드 슬롯, 임시 회수. Reads RunController
## signals only; combat pushes enemy/drop counts through set_* calls.

@onready var wave_label: Label = %WaveLabel
@onready var stability_label: Label = %StabilityLabel
@onready var stability_bar: ProgressBar = %StabilityBar
@onready var enemies_label: Label = %EnemiesLabel
@onready var gold_label: Label = %GoldLabel
@onready var drops_label: Label = %DropsLabel
@onready var build_bar: HBoxContainer = $Root/BuildBar
@onready var hover_label: Label = %HoverLabel


func bind(run: RunController) -> void:
	run.wave_changed.connect(_on_wave_changed)
	run.stability_changed.connect(_on_stability_changed)
	run.gold_changed.connect(_on_gold_changed)
	_on_wave_changed(run.wave)
	_on_stability_changed(run.stability, run.stability_max)
	_on_gold_changed(run.gold_run)
	set_enemies_left(0)
	set_temp_drops(0)


## 빌드 아이콘 (G10): one slot per held word with its Rank; empty slots stay blank.
## `sealed` maps word id -> remaining seal seconds (G8: 봉인은 이름과 남은 시간을 표시).
func set_build(build: BuildState, db: ContentDB, sealed: Dictionary = {}) -> void:
	for i in build_bar.get_child_count():
		var slot := build_bar.get_child(i)
		for ch in slot.get_children():
			slot.remove_child(ch)  # detach now so readers never see the stale label
			ch.queue_free()
		if i < build.words.size():
			var word: WordData = db.words[build.words[i]["id"]]
			var l := Label.new()
			l.text = "%s %s%s" % [word.name, "●".repeat(build.words[i]["rank"]) + "○".repeat(3 - build.words[i]["rank"]), ("\n봉인 %.1f초" % sealed[word.id]) if sealed.has(word.id) else ""]
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.set_anchors_preset(Control.PRESET_FULL_RECT)
			slot.add_child(l)


## 적 Hover (G10): HP and variant of the enemy under the cursor, empty when none.
func set_hover(target: JamoMonster) -> void:
	if target == null:
		hover_label.text = ""
		return
	var kind := "보스" if target is Boss else target.variant_name()
	hover_label.text = "%s  %.1f/%.1f  %s" % [target.jamo if not (target is Boss) else target.data.name, target.hp, target.hp_max, kind]


func set_enemies_left(count: int) -> void:
	enemies_label.text = "적 %d" % count


func set_temp_drops(count: int) -> void:
	drops_label.text = "회수 %d" % count


func _on_wave_changed(wave: int) -> void:
	wave_label.text = "W%d" % wave


func _on_stability_changed(current: float, maximum: float) -> void:
	stability_label.text = "안정도 %.0f/%.0f" % [current, maximum]
	stability_bar.max_value = maximum
	stability_bar.value = current


func _on_gold_changed(gold: float) -> void:
	gold_label.text = "%d G" % int(gold)
