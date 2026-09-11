extends PanelContainer
## Word Forge screen (G5/G10): hand with Lock toggles, Reroll with preview, candidates with
## effect compare, goal pin with lacking jamo, one restore transaction, 빌드 확정.

signal finished
signal state_changed

var run: RunController
var forge: ForgeService
var db: ContentDB
var selected: StringName = &""
var replace_target: StringName = &""

@onready var hand_row: HBoxContainer = %HandRow
@onready var lock_label: Label = %LockLabel
@onready var reroll_button: Button = %RerollButton
@onready var build_label: Label = %BuildLabel
@onready var candidates_box: VBoxContainer = %Candidates
@onready var compare_label: Label = %CompareLabel
@onready var replace_row: HBoxContainer = %ReplaceRow
@onready var restore_button: Button = %RestoreButton
@onready var pin_option: OptionButton = %PinOption
@onready var pin_label: Label = %PinLabel
@onready var status_label: Label = %StatusLabel
@onready var compound_box: VBoxContainer = %CompoundBox
@onready var compound_label: Label = %CompoundLabel
@onready var compound_button: Button = %CompoundButton
@onready var skip_restore_button: Button = %SkipRestoreButton
var selected_compound: StringName = &""
@onready var finish_button: Button = %FinishButton


func _ready() -> void:
	reroll_button.pressed.connect(_on_reroll)
	restore_button.pressed.connect(_on_restore)
	pin_option.item_selected.connect(_on_pin_selected)
	finish_button.pressed.connect(func(): finished.emit())
	compound_button.pressed.connect(_on_compound)
	skip_restore_button.pressed.connect(func(): forge.skip_restore(); _refresh(); state_changed.emit())


func open(controller: RunController, content: ContentDB) -> void:
	run = controller
	db = content
	forge = run.start_forge()
	selected = &""
	replace_target = &""
	selected_compound = &""
	_fill_pin_options()
	_refresh()
	finish_button.grab_focus()


func _fill_pin_options() -> void:
	pin_option.clear()
	pin_option.add_item("목표 핀 없음")
	pin_option.set_item_metadata(0, &"")
	var idx := 1
	for w in run.word_pool():
		pin_option.add_item(w.name)
		pin_option.set_item_metadata(idx, w.id)
		if w.id == run.pinned_word:
			pin_option.select(idx)
		idx += 1


func _refresh() -> void:
	if forge == null:
		return
	_rebuild_hand()
	lock_label.text = "Lock %d / %d" % [forge.locked.size(), forge.lock_max]
	reroll_button.text = "Reroll (%d) · 바뀔 칸 %d" % [forge.rerolls_left, forge.reroll_slots()]
	reroll_button.disabled = not forge.can_reroll()
	build_label.text = "보유 %d / %d: %s" % [forge.build.words.size(), forge.build.slots, _build_text()]
	_rebuild_candidates()
	_rebuild_replace_row()
	var c := forge.candidate_for(selected) if selected != &"" else {}
	var needs_swap: bool = not c.is_empty() and (c["needs_replace"] or c["replace_risk"])
	restore_button.disabled = c.is_empty() or not forge.can_restore() or (needs_swap and replace_target == &"")
	restore_button.text = "복원" if not needs_swap else "교체하고 복원"
	# 복원 건너뛰기 only matters while a restore is still open and a 합성 is waiting (G6 order).
	skip_restore_button.visible = not forge.restore_closed() and not forge.build.compound_options(db).is_empty()
	compare_label.text = _compare_text(c)
	pin_label.text = _pin_text()
	status_label.text = _status_text()
	_rebuild_compounds()


func _rebuild_hand() -> void:
	for ch in hand_row.get_children():
		hand_row.remove_child(ch)
		ch.queue_free()
	for t in forge.hand:
		var b := Button.new()
		b.text = t["jamo"]
		b.custom_minimum_size = Vector2(72, 72)
		b.toggle_mode = true
		b.button_pressed = forge.is_locked(t["id"])
		b.disabled = forge.restored_word != &""
		var token_id: int = t["id"]
		b.pressed.connect(func(): _on_token(token_id))
		hand_row.add_child(b)


func _rebuild_candidates() -> void:
	for ch in candidates_box.get_children():
		candidates_box.remove_child(ch)
		ch.queue_free()
	var list := forge.candidates()
	list.sort_custom(func(a, b): return String(a["word"].id) < String(b["word"].id))
	if selected != &"" and forge.candidate_for(selected).is_empty():
		selected = &""
	for c in list:
		var w: WordData = c["word"]
		var tag := "Rank %d→%d" % [forge.build.rank_of(w.id), forge.build.rank_of(w.id) + 1] if c["kind"] == ForgeService.KIND_RANK_UP else "신규"
		if c["needs_replace"]:
			tag += " · 교체 필요"
		if c["replace_risk"]:
			tag += " · 위험 교체 필요"
		var b := Button.new()
		b.text = "%s (%s) [%s]  %s" % [w.name, "".join(w.required_jamo), tag, EffectText.describe_rank(w, forge.build.rank_of(w.id) + 1)]
		b.custom_minimum_size = Vector2(0, 64)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = w.id == selected
		b.disabled = forge.restored_word != &""
		var id := w.id
		b.pressed.connect(func(): _select(id))
		candidates_box.add_child(b)
	if list.is_empty():
		var l := Label.new()
		l.text = "복원한 단어: %s" % db.words[forge.restored_word].name if forge.restored_word != &"" else "현재 손패로 만들 수 있는 단어 없음"
		candidates_box.add_child(l)


func _rebuild_replace_row() -> void:
	for ch in replace_row.get_children():
		replace_row.remove_child(ch)
		ch.queue_free()
	var c := forge.candidate_for(selected) if selected != &"" else {}
	var needs_swap: bool = not c.is_empty() and (c["needs_replace"] or c["replace_risk"])
	replace_row.visible = needs_swap
	if not needs_swap:
		replace_target = &""
		return
	var only_risk: bool = c["replace_risk"]
	var l := Label.new()
	l.text = "내보낼 단어:"
	replace_row.add_child(l)
	for held in forge.build.words:
		var w: WordData = db.words[held["id"]]
		if only_risk and not w.is_risk():
			continue
		var b := Button.new()
		b.text = "%s R%d" % [w.name, held["rank"]]
		b.custom_minimum_size = Vector2(120, 56)
		b.toggle_mode = true
		b.button_pressed = w.id == replace_target
		var id := w.id
		b.pressed.connect(func(): _select_replace(id))
		replace_row.add_child(b)


func _build_text() -> String:
	var parts: Array[String] = []
	for held in forge.build.words:
		parts.append("%s R%d" % [db.words[held["id"]].name, held["rank"]])
	return ", ".join(parts) if not parts.is_empty() else "없음"


## 효과 비교 (G10): current Rank line vs the Rank this restore would give, plus what a swap loses.
func _compare_text(c: Dictionary) -> String:
	if c.is_empty():
		return "후보를 고르면 효과 변화를 보여줍니다."
	var w: WordData = c["word"]
	var cur := forge.build.rank_of(w.id)
	var text := "%s: %s" % [w.name, EffectText.describe_rank(w, cur + 1)]
	if cur > 0:
		text = "%s Rank %d → %d\n지금: %s\n다음: %s" % [w.name, cur, cur + 1, EffectText.describe_rank(w, cur), EffectText.describe_rank(w, cur + 1)]
	if w.is_risk():
		text += "\n위험: 페널티는 효과에 포함되어 있습니다."
	if replace_target != &"":
		var old: WordData = db.words[replace_target]
		text += "\n잃는 효과 (%s R%d): %s" % [old.name, forge.build.rank_of(old.id), EffectText.describe_rank(old, forge.build.rank_of(old.id))]
	return text


func _pin_text() -> String:
	if run.pinned_word == &"":
		return "목표를 핀하면 부족한 자모와 덱 보유 수를 보여줍니다."
	var st := forge.pin_status(run.pinned_word)
	var w: WordData = st["word"]
	var parts: Array[String] = []
	for j in w.required_jamo:
		parts.append("%s(덱 %d)" % [j, st["deck_counts"].get(j, 0)])
	if st["possible"]:
		return "목표 %s: %s · 현재 덱으로 가능" % [w.name, " ".join(parts)]
	var lacking: Array[String] = []
	for j in st["missing"]:
		lacking.append("%s %d개 없음" % [j, st["missing"][j]])
	return "목표 %s: %s · 현재 덱에 %s" % [w.name, " ".join(parts), ", ".join(lacking)]


func _status_text() -> String:
	if forge.restored_word != &"":
		return "복원 완료: %s. 빌드 확정으로 다음 Wave." % db.words[forge.restored_word].name
	if forge.is_failed():
		return "복원 실패: 안정도 +%.0f, 다음 Forge Reroll +%d." % [db.balance.forge_fail_heal, db.balance.forge_fail_bonus_reroll]
	if forge.rerolls_left == 0 and not forge.candidates().is_empty():
		return "후보가 있습니다. 복원하지 않고 넘기면 보정은 없습니다."
	return "손패를 눌러 Lock, Reroll로 나머지를 다시 뽑습니다."


func _on_token(token_id: int) -> void:
	if not forge.toggle_lock(token_id):
		status_label.text = "Lock은 %d개까지입니다." % forge.lock_max
		_rebuild_hand()
		return
	_refresh()
	state_changed.emit()


func _on_reroll() -> void:
	if forge.reroll():
		_refresh()
		state_changed.emit()


func _select(id: StringName) -> void:
	selected = id
	replace_target = &""
	_refresh()


func _select_replace(id: StringName) -> void:
	replace_target = id
	_refresh()


func _on_restore() -> void:
	if forge.restore(selected, replace_target):
		selected = &""
		replace_target = &""
		_refresh()
		state_changed.emit()
		finish_button.grab_focus()


## 합성 (G6/G10 빌드 확정): recipes whose materials are held; preview shows what is lost.
func _rebuild_compounds() -> void:
	for ch in compound_box.get_children():
		compound_box.remove_child(ch)
		ch.queue_free()
	var options := forge.build.compound_options(db)
	compound_box.visible = not options.is_empty() or forge.compounded != &""
	compound_button.visible = compound_box.visible
	if forge.compounded != &"":
		compound_label.text = "합성 완료: %s. 이번 빌드 확정에서는 더 합성할 수 없습니다." % db.words[db.compounds[forge.compounded].result].name
		compound_button.disabled = true
		return
	if options.is_empty():
		compound_label.text = ""
		compound_button.disabled = true
		return
	if not forge.restore_closed():
		compound_label.text = "합성은 복원을 마친 뒤(또는 복원 건너뛰기 뒤) 빌드 확정 화면에서 선택합니다."
		compound_button.disabled = true
		return
	if selected_compound == &"" or db.compounds.get(selected_compound) == null or not (db.compounds[selected_compound] in options):
		selected_compound = options[0].id
	for c in options:
		var b := Button.new()
		var result: WordData = db.words[c.result]
		b.text = "%s + %s → %s" % [db.words[c.material_a].name, db.words[c.material_b].name, result.name]
		b.custom_minimum_size = Vector2(0, 56)
		b.toggle_mode = true
		b.button_pressed = c.id == selected_compound
		var id := c.id
		b.pressed.connect(func(): selected_compound = id; _refresh())
		compound_box.add_child(b)
	compound_label.text = _compound_preview_text(selected_compound)
	compound_button.disabled = not forge.can_compound()


func _compound_preview_text(id: StringName) -> String:
	var pv := forge.compound_preview(id)
	if pv.is_empty():
		return ""
	var c: CompoundData = pv["compound"]
	var result: WordData = pv["result"]
	var lines: Array[String] = []
	lines.append("잃는 효과: %s R%d (%s) / %s R%d (%s)" % [db.words[c.material_a].name, pv["material_a_rank"], EffectText.describe_rank(db.words[c.material_a], pv["material_a_rank"]),
		db.words[c.material_b].name, pv["material_b_rank"], EffectText.describe_rank(db.words[c.material_b], pv["material_b_rank"])])
	lines.append("얻는 효과: %s R1 (%s)" % [result.name, EffectText.describe_rank(result, 1)])
	lines.append("슬롯 2 → 1. 결과 Rank는 1로 고정되며 재료의 높은 Rank는 사라집니다.")
	if not pv["synergies_lost"].is_empty():
		var names: Array[String] = []
		for sid in pv["synergies_lost"]:
			names.append(String(sid))
		lines.append("꺼지는 시너지: %s" % ", ".join(names))
	return "\n".join(lines)


func _on_compound() -> void:
	if forge.compound(selected_compound):
		_refresh()
		state_changed.emit()
		finish_button.grab_focus()


func _on_pin_selected(index: int) -> void:
	run.pin_word(pin_option.get_item_metadata(index))
	_refresh()
