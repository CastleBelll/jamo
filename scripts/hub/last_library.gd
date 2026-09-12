extends Control
## 마지막 서고 (G10/S7): tabs for the hub, 연구, 복원 사전 and 기록, the RUN 시작 구성 panel and
## the first-RUN opening (S5). Logic lives in LibraryService; this file only draws and routes.

const RUN_SCENE := "res://scenes/run/run_game.tscn"

var db: ContentDB
var codex_tab: String = "base"
var codex_selected: String = ""
var setup_deck: StringName = &"starter_a"


func _ready() -> void:
	db = ContentDB.load_all()
	%RunButton.pressed.connect(_open_setup)
	%ContinueButton.pressed.connect(_on_continue)
	%NewProfileButton.pressed.connect(func(): Meta.new_profile(); _refresh())
	%CodexBaseButton.pressed.connect(func(): _set_codex_tab("base"))
	%CodexCompoundButton.pressed.connect(func(): _set_codex_tab("compound"))
	%CodexBossButton.pressed.connect(func(): _set_codex_tab("boss"))
	%SetupBackButton.pressed.connect(func(): %RunSetup.visible = false; %RunButton.grab_focus())
	%SetupStartButton.pressed.connect(_start_run)
	%SetupPinOption.item_selected.connect(func(i): Meta.pinned_word = String(%SetupPinOption.get_item_metadata(i)); _refresh_setup())
	%OpeningStartButton.pressed.connect(_start_first_run)
	SettingsService.apply_all()
	Sfx.play_bgm("library")
	AssetLib.apply($BackgroundArt, "lib_bg")
	for layer in ["lamp", "spines", "lines", "handwriting", "openbook"]:
		var rect := TextureRect.new()
		rect.name = "Art_" + layer
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if AssetLib.apply(rect, "lib_layer_" + layer):
			$LayerArt.add_child(rect)
		else:
			rect.free()
	var tab_icons := ["tab_hub", "tab_research", "tab_codex", "tab_records", "tab_settings"]
	for i in mini(tab_icons.size(), %Tabs.get_tab_count()):
		var t := AssetLib.tex(tab_icons[i])
		if t != null:
			%Tabs.set_tab_icon(i, t)
	%Tabs.tab_changed.connect(func(_i): _dismiss_title())
	%Title.gui_input.connect(func(event): if event is InputEventMouseButton and event.is_pressed(): _dismiss_title())
	AssetLib.apply(%Title/TitleArt, "title_screen")
	AssetLib.apply(%Title/TitleLogo, "title_logo")
	SettingsService.apply_text_scale(self, int(Meta.setting("text_scale")))
	%SettingsPanel.open(self, true)  # lives inside the 설정 tab: never hidden, 서고로 returns to the hub tab
	%SettingsPanel.closed.connect(func(): %Tabs.current_tab = 0; %RunButton.grab_focus())
	var returned := LibraryService.record_return(db)
	_refresh()
	%NoticeLabel.text = returned
	%NoticeLabel.visible = returned != ""
	if not Meta.first_run_done and not Meta.has_run():
		_show_opening()
	elif AssetLib.tex("title_screen") != null and not Meta.title_seen:
		%Title.visible = true


func _unhandled_input(event: InputEvent) -> void:
	# S5: the opening skips on the next input; the title screen dismisses the same way.
	if %Opening.visible and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_start_first_run()
		get_viewport().set_input_as_handled()
	elif %Title.visible and event is InputEventKey and event.is_pressed():
		_dismiss_title()
		get_viewport().set_input_as_handled()


func _dismiss_title() -> void:
	%Title.visible = false
	Meta.title_seen = true


func _refresh() -> void:
	%GoldLabel.text = "Gold %d" % Meta.gold
	%DiscoveredLabel.text = "발견 %d" % LibraryService.base_discovered(db)
	%BestLabel.text = "최고 기록 도달 W%d · 클리어 W%d" % [Meta.best_reached, Meta.best_cleared] if Meta.best_reached > 0 else "최고 기록 -"
	%SentenceLabel.text = "원본: " + LibraryService.sentence_text(db)
	%ContinueButton.visible = Meta.has_run()
	%RunButton.text = "새 RUN (진행 중 RUN 삭제)" if Meta.has_run() else "RUN"
	%CorruptLabel.visible = Meta.corrupt
	%NewProfileButton.visible = Meta.corrupt and Meta.load_source == "none"
	if Meta.corrupt:
		%CorruptLabel.text = "저장 파일이 손상되어 백업으로 복구했습니다." if Meta.load_source == "backup" else "저장 파일이 손상되었습니다. 새 프로필을 만들면 기존 기록은 사라집니다."
	var layers := LibraryService.layers(db)
	%LayerTitleLamp.visible = layers["title_lamp"]
	%LayerSpines.visible = layers["spines"]
	%LayerLines.visible = layers["lines"]
	%LayerHandwriting.visible = layers["handwriting"]
	%LayerOpenBook.visible = layers["open_book"]
	for pair in [["lamp", "title_lamp"], ["spines", "spines"], ["lines", "lines"], ["handwriting", "handwriting"], ["openbook", "open_book"]]:
		var art := $LayerArt.get_node_or_null("Art_" + pair[0])
		if art != null:
			art.visible = layers[pair[1]]
	# Text layer labels only stand in while the art is missing.
	$Layers.visible = $LayerArt.get_child_count() == 0
	_refresh_research()
	_refresh_codex()
	_refresh_records()
	if Meta.has_run():
		%ContinueButton.grab_focus()
	else:
		%RunButton.grab_focus()


func _clear(container: Node) -> void:
	for ch in container.get_children():
		container.remove_child(ch)
		ch.queue_free()


# --- 연구 (G10 서고 연구 row) ---------------------------------------------------------

func _refresh_research() -> void:
	_clear(%ResearchRows)
	for row in LibraryService.research_rows(db):
		var r: ResearchData = row["research"]
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 16)
		var text := Label.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var state: String = "구매 완료" if row["purchased"] else ("구매 가능" if row["allowed"] and row["affordable"] else row["reason"])
		text.text = "%s  %dG\n%s → %s\n%s" % [r.name, r.price, row["current"], row["after"], state]
		box.add_child(text)
		var b := Button.new()
		b.text = "구매" if not row["purchased"] else "완료"
		b.custom_minimum_size = Vector2(160, 64)
		b.disabled = row["purchased"] or not row["allowed"] or not row["affordable"]
		var id := r.id
		b.pressed.connect(func(): if LibraryService.buy_research(db, id): _refresh())
		box.add_child(b)
		%ResearchRows.add_child(box)


# --- 복원 사전 (G10 row) --------------------------------------------------------------

func _set_codex_tab(tab: String) -> void:
	codex_tab = tab
	codex_selected = ""
	_refresh_codex()


func _refresh_codex() -> void:
	_clear(%CodexRows)
	var first := ""
	if codex_tab == "boss":
		var ids := db.bosses.keys()
		ids.sort_custom(func(a, b): return db.bosses[a].wave < db.bosses[b].wave)
		for id in ids:
			var row := LibraryService.boss_row(db, db.bosses[id])
			_add_codex_button("%s · 정화 %d회" % [row["boss"].name, row["purified"]], String(id))
			if first == "":
				first = String(id)
	else:
		for w in db.words.values():
			if w.is_compound != (codex_tab == "compound"):
				continue
			var row := LibraryService.codex_row(db, w)
			var mark: String = ("발견 " + row["tier"]).strip_edges() if row["discovered"] else ("미발견" if row["unlocked"] else "잠김")
			_add_codex_button("%s %s  %s" % [w.name, row["materials"], mark], String(w.id))
			if first == "":
				first = String(w.id)
	if codex_selected == "":
		codex_selected = first
	_refresh_codex_detail()


func _add_codex_button(text: String, id: String) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 56)
	b.toggle_mode = true
	b.button_pressed = id == codex_selected
	b.pressed.connect(func(): codex_selected = id; _refresh_codex())
	%CodexRows.add_child(b)


func _refresh_codex_detail() -> void:
	if codex_selected == "":
		%CodexDetail.text = ""
		return
	if codex_tab == "boss":
		var row := LibraryService.boss_row(db, db.bosses[StringName(codex_selected)])
		var lines: Array[String] = ["%s (W%d)" % [row["boss"].name, row["boss"].wave], "대응: %s" % row["hint"], "정화 %d회" % row["purified"]]
		if row["intro"] != "":
			lines.append("등장: %s" % row["intro"])
		if row["after"] != "":
			lines.append("기록: %s" % row["after"])
		%CodexDetail.text = "\n".join(lines)
		return
	var row := LibraryService.codex_row(db, db.words[StringName(codex_selected)])
	var w: WordData = row["word"]
	var lines: Array[String] = ["%s %s · %s" % [w.name, row["materials"], " ".join(w.tags)]]
	if not row["unlocked"]:
		lines.append("잠김 · " + row["condition"])
	if w.is_compound and row["condition"] != "":
		lines.append("레시피: %s" % row["condition"])
	lines.append_array(row["effects"])
	if row["discovered"] and w.is_compound:
		lines.append("최초 발견 기록 · 첫 합성 %s" % row["first_at"])  # B10: 합성은 복원도 없이 발견 기록만
	elif row["discovered"]:
		lines.append("복원도 %s (%d회) · 최고 R%d" % [row["tier"], row["mastery"], row["best_rank"]])
	else:
		lines.append("미복원")
	lines.append("보스 · %s" % row["boss"])
	%CodexDetail.text = "\n".join(lines)


# --- 기록 (S5/B10) --------------------------------------------------------------------

func _refresh_records() -> void:
	var b := LibraryService.badges(db)
	%BadgesLabel.text = "배지 · 첫 합성 %s · 첫 완주 %s · 12종 %s" % [_mark(b["first_compound"]), _mark(b["first_clear"]), _mark(b["twelve_words"])]
	_clear(%EventRows)
	var lines := LibraryService.event_lines(db)
	if lines.is_empty():
		var l := Label.new()
		l.text = "아직 기록이 없다."
		%EventRows.add_child(l)
	for line in lines:
		var l := Label.new()
		l.text = line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		%EventRows.add_child(l)


func _mark(on: bool) -> String:
	return "○" if on else "—"


# --- RUN 시작 구성 (G10 row) ------------------------------------------------------------

func _open_setup() -> void:
	setup_deck = Meta.chosen_deck if db.decks.has(Meta.chosen_deck) and Meta.deck_unlocked(db.decks[Meta.chosen_deck]) else &"starter_a"
	%SetupPinOption.clear()
	%SetupPinOption.add_item("목표 핀 없음")
	%SetupPinOption.set_item_metadata(0, "")
	var idx := 1
	for w in db.base_words():
		if w.unlock == &"start" or (w.unlock == &"after_mieum" and Meta.mieum_purified):
			%SetupPinOption.add_item(w.name)
			%SetupPinOption.set_item_metadata(idx, String(w.id))
			if String(w.id) == Meta.pinned_word:
				%SetupPinOption.select(idx)
			idx += 1
	_refresh_setup()
	%RunSetup.visible = true
	%SetupStartButton.grab_focus()


func _refresh_setup() -> void:
	_clear(%DeckRows)
	var ids := db.decks.keys()
	ids.sort()
	for id in ids:
		var row := LibraryService.deck_row(db, db.decks[id])
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = id == setup_deck
		b.disabled = not row["unlocked"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 64)
		var counts: Array[String] = []
		for j in row["counts"]:
			counts.append("%s%d" % [j, row["counts"][j]])
		b.text = "%s · %d장 · 제작 %d%s\n%s" % [row["deck"].name, row["size"], row["craftable"].size(), "" if row["unlocked"] else " · 잠김", " ".join(counts)]
		var deck_id: StringName = id
		b.pressed.connect(func(): setup_deck = deck_id; _refresh_setup())
		%DeckRows.add_child(b)
	var chosen := LibraryService.deck_row(db, db.decks[setup_deck])
	var pin_text := ""
	if Meta.pinned_word != "" and db.words.has(StringName(Meta.pinned_word)):
		var word: WordData = db.words[StringName(Meta.pinned_word)]
		var need := ForgeService.required_counts(word)
		var lacking: Array[String] = []
		for j in need:
			if chosen["counts"].get(j, 0) < need[j]:
				lacking.append(j)
		pin_text = "목표 %s · %s" % [word.name, "가능" if lacking.is_empty() else "부족 %s" % " ".join(lacking)]
	%SetupInfo.text = "못 만드는 단어 · %s\n%s" % [", ".join(chosen["blocked"]) if not chosen["blocked"].is_empty() else "없음", pin_text]


func _start_run() -> void:
	Meta.chosen_deck = setup_deck
	Meta.run = {}
	Meta.resume_pending = false
	Meta.save()
	get_tree().change_scene_to_file(RUN_SCENE)


func _on_continue() -> void:
	Meta.resume_pending = true
	get_tree().change_scene_to_file(RUN_SCENE)


# --- 오프닝 (G2/S5): first RUN skips the hub ------------------------------------------------

func _show_opening() -> void:
	var lines := db.narrative.line("S_OPEN").split("\n")
	%OpeningLine1.text = lines[0] if lines.size() > 0 else ""
	%OpeningLine2.text = lines[1] if lines.size() > 1 else ""
	%Opening.visible = true
	%OpeningStartButton.grab_focus()


func _start_first_run() -> void:
	%Opening.visible = false
	Meta.chosen_deck = &"starter_a"
	if "S_OPEN" not in Meta.events:
		Meta.events.append("S_OPEN")
	Meta.run = {}
	Meta.save()
	get_tree().change_scene_to_file(RUN_SCENE)
