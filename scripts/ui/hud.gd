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
@onready var top_bar: HBoxContainer = $Root/TopPanel/TopBar


func _ready() -> void:
	# HUD icons (G10): the label then carries only the number.
	for pair in [["WaveIcon", "hud_wave"], ["StabilityIcon", "hud_stability"], ["EnemyIcon", "hud_enemy"], ["GoldIcon", "hud_gold"], ["DropIcon", "hud_drop"]]:
		top_bar.get_node(pair[0]).texture = AssetLib.tex_light(pair[1])  # cream silhouettes on the wood bar
	for slot in build_bar.get_children():
		var frame := TextureRect.new()
		frame.name = "Frame"
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if AssetLib.apply(frame, "slot_frame"):
			slot.add_child(frame)
		else:
			frame.free()


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
			if ch.name == "Frame":
				continue
			slot.remove_child(ch)  # detach now so readers never see the stale label
			ch.queue_free()
		if i < build.words.size():
			var word: WordData = db.words[build.words[i]["id"]]
			var icon := AssetLib.word_icon(word.id)
			if icon != null:
				var pic := TextureRect.new()
				pic.texture = icon
				pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pic.set_anchors_preset(Control.PRESET_TOP_WIDE)
				pic.offset_top = 6
				pic.offset_bottom = 54
				slot.add_child(pic)
			var l := Label.new()
			# Two fixed lines (name / rank pips) so a 108px slot never wraps mid-token (G10).
			l.text = "%s\n%s%s" % [word.name, "●".repeat(build.words[i]["rank"]) + "○".repeat(3 - build.words[i]["rank"]), ("\n봉인 %.1f초" % sealed[word.id]) if sealed.has(word.id) else ""]
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if icon != null else VERTICAL_ALIGNMENT_CENTER
			l.add_theme_font_size_override("font_size", 18 if icon != null else 20)
			l.set_anchors_preset(Control.PRESET_FULL_RECT)
			l.offset_bottom = -4
			slot.add_child(l)
			var frame := slot.get_node_or_null("Frame")
			if frame != null:
				slot.move_child(frame, 0)
				AssetLib.apply(frame, "slot_frame")
		else:
			AssetLib.apply(slot.get_node_or_null("Frame"), "slot_frame_empty")


## 적 Hover (G10): HP and variant of the enemy under the cursor, empty when none.
func set_hover(target: JamoMonster) -> void:
	if target == null:
		hover_label.text = ""
		return
	var kind := "보스" if target is Boss else target.variant_name()
	hover_label.text = "%s  %.1f/%.1f  %s" % [target.jamo if not (target is Boss) else target.data.name, target.hp, target.hp_max, kind]


func has_icons() -> bool:
	return top_bar.get_node("WaveIcon").texture != null


func set_enemies_left(count: int) -> void:
	enemies_label.text = ("%d" if has_icons() else "적 %d") % count


func set_temp_drops(count: int) -> void:
	drops_label.text = ("%d" if has_icons() else "회수 %d") % count


func _on_wave_changed(wave: int) -> void:
	wave_label.text = "W%d" % wave


func _on_stability_changed(current: float, maximum: float) -> void:
	stability_label.text = ("%.0f/%.0f" if has_icons() else "안정도 %.0f/%.0f") % [current, maximum]
	stability_bar.max_value = maximum
	stability_bar.value = current


func _on_gold_changed(gold: float) -> void:
	gold_label.text = ("%d" if has_icons() else "%d G") % int(gold)
