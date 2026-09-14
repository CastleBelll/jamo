extends Control
## 마지막 서고 (G10/S7): tabs for the hub, 연구, 복원 사전 and 기록, the RUN 시작 구성 panel and
## the first-RUN opening (S5). Logic lives in LibraryService; this file only draws and routes.

const RUN_SCENE := "res://scenes/run/run_game.tscn"
const RECORD_ROWS := 10
const MENU_ICON_PX := 40
const RESEARCH_ICONS := {"max_stability": "hud_stability", "unlock_deck": "hud_drop"}
const CODEX_UNKNOWN_ALPHA := 0.55
const CODEX_ICON_PX := 96
const CODEX_GLYPH_PX := 40
const RANK_PIPS := 3
const LOCK_REASON_COLOR := Color(0.58, 0.18, 0.12, 1)
const BADGE_OFF_ALPHA := 0.5
const BADGES := [["first_compound", "badge_compound", "첫 합성"], ["first_clear", "badge_clear", "첫 완주"], ["twelve_words", "badge_twelve", "12종"]]

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
	%ResearchButton.pressed.connect(func(): _show_tab(1))
	%CodexButton.pressed.connect(func(): _show_tab(2))
	%RecordsButton.pressed.connect(func(): _show_tab(3))
	%SettingsButton.pressed.connect(func(): _show_tab(4))
	%CloseCardButton.pressed.connect(func(): _show_tab(0))
	AssetLib.apply(%Logo, "title_logo")
	%HubTitle.visible = %Logo.texture == null
	SettingsService.apply_all()
	Sfx.play_bgm("library")
	Juice.breathe(%Logo)
	Juice.breathe(%Title/TitleLogo)
	Juice.slide_in($Menu, [%ContinueButton, %RunButton, %ResearchButton, %CodexButton, %RecordsButton, %SettingsButton])
	if AssetLib.apply($BackgroundArt, "lib_bg_dim"):
		$MenuShade.visible = false
	else:
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
	var tab_icons := ["", "tab_research", "tab_codex", "tab_records", "tab_settings"]
	var menu_buttons := [null, %ResearchButton, %CodexButton, %RecordsButton, %SettingsButton]
	for i in range(1, mini(tab_icons.size(), %Tabs.get_tab_count())):
		var b: Button = menu_buttons[i]
		b.icon = AssetLib.tex_light(tab_icons[i])  # cream silhouette on the ink button
		b.add_theme_constant_override("icon_max_width", MENU_ICON_PX)
		b.expand_icon = true
	%Tabs.tab_changed.connect(_on_tab_changed)
	%Title.gui_input.connect(func(event): if event is InputEventMouseButton and event.is_pressed(): _dismiss_title())
	AssetLib.apply(%Title/TitleArt, "title_screen")
	AssetLib.apply(%Title/TitleLogo, "title_logo")
	SettingsService.apply_text_scale(self, int(Meta.setting("text_scale")))
	%SettingsPanel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())  # the card already draws the paper
	var embedded_title := %SettingsPanel.get_node_or_null("Box/Title")
	if embedded_title != null:
		embedded_title.visible = false  # the card header names the tab
	%SettingsPanel.open(self, true)  # lives inside the 설정 tab: never hidden, 서고로 returns to the hub tab
	%SettingsPanel.closed.connect(func(): _show_tab(0))
	%SettingsPanel.text_scale_changed.connect(_refresh)  # cards built in code take their size from SettingsService.px
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


## Menu buttons open one tab inside the paper card; tab 0 (서고) is the bare hub.
func _show_tab(index: int) -> void:
	if %Tabs.current_tab == index:
		_on_tab_changed(index)  # no tab_changed signal when the index is unchanged
	else:
		%Tabs.current_tab = index
	if index == 0:
		if Meta.has_run():
			%ContinueButton.grab_focus()
		else:
			%RunButton.grab_focus()


func _on_tab_changed(index: int) -> void:
	_dismiss_title()
	%ContentCard.visible = index != 0
	%CardTitle.text = %Tabs.get_tab_title(index)


func _refresh() -> void:
	%GoldIcon.texture = AssetLib.tex_light("hud_gold")
	%DiscoveredIcon.texture = AssetLib.tex_light("tab_codex")
	%BestIcon.texture = AssetLib.tex_light("hud_wave")
	%GoldLabel.text = str(Meta.gold)
	%DiscoveredLabel.text = "%d / %d" % [LibraryService.base_discovered(db), _base_word_count()]
	%BestLabel.text = "W%d · 클리어 W%d" % [Meta.best_reached, Meta.best_cleared] if Meta.best_reached > 0 else "-"
	%SentenceLabel.text = LibraryService.sentence_text(db)
	%ContinueButton.visible = Meta.has_run()
	%RunButton.text = "새 RUN" if Meta.has_run() else "RUN 시작"
	%RunButton.theme_type_variation = &"" if Meta.has_run() else &"PrimaryButton"
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


func _base_word_count() -> int:
	var n := 0
	for w in db.words.values():
		if not w.is_compound:
			n += 1
	return n


func _clear(container: Node) -> void:
	for ch in container.get_children():
		container.remove_child(ch)
		ch.queue_free()


# --- 연구 (G10 서고 연구 row) ---------------------------------------------------------

func _refresh_research() -> void:
	_clear(%ResearchRows)
	for row in LibraryService.research_rows(db):
		%ResearchRows.add_child(_research_card(row))


## G10 readability: icon + name + "before → after" + price + one button. Words only where a
## picture cannot carry it (the lock reason), and only while it applies.
func _research_card(row: Dictionary) -> Control:
	var r: ResearchData = row["research"]
	var card := PanelContainer.new()
	card.theme_type_variation = &"Panel"
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(56, 56)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for key in RESEARCH_ICONS:
		if r.effect.has(key):
			AssetLib.apply(pic, RESEARCH_ICONS[key])
	box.add_child(pic)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name := Label.new()
	name.text = r.name
	name.add_theme_font_size_override("font_size", SettingsService.px(32))
	text.add_child(name)
	var change := Label.new()
	change.text = _research_change(r)
	change.theme_type_variation = &"MutedLabel"
	text.add_child(change)
	if not row["purchased"] and not row["allowed"]:
		var why := Label.new()
		why.text = row["reason"]
		why.theme_type_variation = &"MutedLabel"
		why.add_theme_color_override("font_color", LOCK_REASON_COLOR)
		text.add_child(why)
	box.add_child(text)
	var price := Label.new()
	price.text = "%dG" % r.price
	price.add_theme_font_size_override("font_size", SettingsService.px(30))
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(price)
	var b := Button.new()
	b.text = "완료" if row["purchased"] else "구매"
	b.custom_minimum_size = Vector2(150, 60)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not row["purchased"]:
		b.theme_type_variation = &"PrimaryButton"
	b.disabled = row["purchased"] or not row["allowed"] or not row["affordable"]
	b.tooltip_text = row["reason"] if b.disabled and not row["purchased"] else ""
	var id := r.id
	b.pressed.connect(func(): if LibraryService.buy_research(db, id): _refresh())
	box.add_child(b)
	return card


## "안정도 100 → 105" / "Starter B 잠김 → 선택 가능": numbers and states, no sentences.
func _research_change(r: ResearchData) -> String:
	if r.effect.has("max_stability"):
		var target := int(r.effect["max_stability"])
		# Purchased: stability_max already includes the bonus, so a "105 -> 105" line is noise.
		if Meta.has_research(r.id):
			return "안정도 %d" % target
		return "안정도 %.0f → %d" % [Meta.stability_max(db), target]
	if r.effect.has("unlock_deck"):
		return "Starter B 잠김 → 선택 가능" if not Meta.has_research(r.id) else "Starter B 선택 가능"
	return ""


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
			_add_codex_button(row["boss"].name, String(id), AssetLib.boss_glyph(id), row["purified"] > 0)
			if first == "":
				first = String(id)
	else:
		for w in db.words.values():
			if w.is_compound != (codex_tab == "compound"):
				continue
			var row := LibraryService.codex_row(db, w)
			# Icon + name only: undiscovered words are dimmed, locked ones carry a lock (no status words).
			var icon: Texture2D = AssetLib.word_icon(w.id) if row["unlocked"] else AssetLib.tex("lock_on")
			_add_codex_button(w.name, String(w.id), icon, row["discovered"])
			if first == "":
				first = String(w.id)
	if codex_selected == "":
		codex_selected = first
	_refresh_codex_detail()


func _add_codex_button(text: String, id: String, icon: Texture2D, known: bool) -> void:
	var b := Button.new()
	b.text = text
	if icon != null:
		b.icon = icon
		b.expand_icon = true
	if not known:
		b.modulate.a = CODEX_UNKNOWN_ALPHA
	b.theme_type_variation = &"GhostButton"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(316, 52)
	b.add_theme_font_size_override("font_size", SettingsService.px(24))
	b.toggle_mode = true
	b.button_pressed = id == codex_selected
	b.pressed.connect(func(): codex_selected = id; _refresh_codex())
	%CodexRows.add_child(b)


func _refresh_codex_detail() -> void:
	_clear(%CodexDetail)
	if codex_selected == "":
		return
	if codex_tab == "boss":
		_boss_detail(LibraryService.boss_row(db, db.bosses[StringName(codex_selected)]))
		return
	var row := LibraryService.codex_row(db, db.words[StringName(codex_selected)])
	var w: WordData = row["word"]
	var head := _detail_head(w.name, AssetLib.word_icon(w.id) if row["unlocked"] else AssetLib.tex("lock_on"))
	if not row["discovered"]:
		head.modulate.a = CODEX_UNKNOWN_ALPHA  # same dimming as the tile: not restored yet
	head.get_node("Text").add_child(_glyph_row(w.required_jamo))
	if not row["unlocked"]:
		_detail_line(row["condition"], &"MutedLabel", LOCK_REASON_COLOR)
	elif w.is_compound and row["condition"] != "":
		_detail_line(row["condition"], &"MutedLabel")
	# One row per rank: "R1" tag + effect; ranks not reached yet are muted.
	for i in row["effects"].size():
		var parts: PackedStringArray = String(row["effects"][i]).split(": ", true, 1)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var tag := Label.new()
		tag.text = parts[0]
		tag.custom_minimum_size = Vector2(44, 0)
		tag.theme_type_variation = &"MutedLabel"
		tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(tag)
		var effect := Label.new()
		effect.text = parts[1] if parts.size() > 1 else parts[0]
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i + 1 > int(row["best_rank"]):
			effect.theme_type_variation = &"MutedLabel"
		line.add_child(effect)
		%CodexDetail.add_child(line)
	var meta := HBoxContainer.new()
	meta.name = "Meta"
	meta.add_theme_constant_override("separation", 6)
	if row["discovered"] and w.is_compound:
		meta.add_child(_label("첫 합성 %s" % row["first_at"], &"MutedLabel"))  # B10: 합성은 복원도 없이 발견 기록만
	elif not w.is_compound:
		# Pips carry the state: all empty = not restored yet, filled = best rank reached.
		for i in RANK_PIPS:
			meta.add_child(_pip(i < int(row["best_rank"])))
		if row["discovered"]:
			meta.add_child(_label("×%d" % row["mastery"], &"MutedLabel"))
	%CodexDetail.add_child(meta)
	var boss := HBoxContainer.new()
	boss.add_theme_constant_override("separation", 8)
	if db.bosses.has(w.related_boss):
		boss.add_child(_icon(AssetLib.boss_glyph(w.related_boss), CODEX_GLYPH_PX))
	boss.add_child(_label(row["boss"], &"MutedLabel"))
	%CodexDetail.add_child(boss)


func _boss_detail(row: Dictionary) -> void:
	var boss: BossData = row["boss"]
	var head := _detail_head("%s (W%d)" % [boss.name, boss.wave], AssetLib.boss_glyph(boss.id))
	head.get_node("Text").add_child(_label("정화 ×%d" % row["purified"], &"MutedLabel"))
	_detail_line("대응 · " + row["hint"])
	for key in ["intro", "after"]:
		if row[key] != "":
			_detail_line(row[key], &"MutedLabel")


## Icon + title block shared by word and boss details; the title is `%CodexDetail/Head/Text/Title`.
func _detail_head(title: String, icon: Texture2D) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 16)
	head.add_child(_icon(icon, CODEX_ICON_PX))
	var text := VBoxContainer.new()
	text.name = "Text"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_label := Label.new()
	name_label.name = "Title"
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", SettingsService.px(32))
	text.add_child(name_label)
	head.add_child(text)
	%CodexDetail.add_child(head)
	return head


func _detail_line(text: String, variation: StringName = &"", color: Color = Color.TRANSPARENT) -> void:
	var l := _label(text, variation)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if color != Color.TRANSPARENT:
		l.add_theme_color_override("font_color", color)
	%CodexDetail.add_child(l)


func _glyph_row(jamo: Array) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	for j in jamo:
		# Flat glyph, not the 256px character sprite AssetLib.glyph() prefers.
		var g := AssetLib.tex("glyph_%s" % AssetLib.GLYPH_NAMES[j]) if AssetLib.GLYPH_NAMES.has(j) else null
		box.add_child(_icon(g, CODEX_GLYPH_PX) if g != null else _label(j))
	return box


func _icon(texture: Texture2D, px: int) -> TextureRect:
	var pic := TextureRect.new()
	pic.texture = texture
	pic.custom_minimum_size = Vector2(px, px)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return pic


func _pip(on: bool) -> TextureRect:
	var pip := _icon(AssetLib.tex("rank_pip_on" if on else "rank_pip_off"), 24)
	pip.modulate.a = 1.0 if on else 0.6
	return pip


func _label(text: String, variation: StringName = &"") -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


# --- 기록 (S5/B10) --------------------------------------------------------------------

## Three badge icons, dimmed until earned; the narrative lines stay as they are.
func _refresh_records() -> void:
	var b := LibraryService.badges(db)
	_clear(%BadgeRow)
	for badge in BADGES:
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		var pic := _icon(AssetLib.tex(badge[1]), 72)
		pic.modulate.a = 1.0 if b[badge[0]] else BADGE_OFF_ALPHA
		column.add_child(pic)
		var caption := _label(badge[2], &"MutedLabel")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(caption)
		%BadgeRow.add_child(column)
	_clear(%EventRows)
	var lines := LibraryService.event_lines(db)
	if lines.is_empty():
		var l := Label.new()
		l.text = "아직 기록이 없다."
		%EventRows.add_child(l)
	# No scrolling (G10): the newest RECORD_ROWS lines, older ones summarised.
	var shown: Array[String] = lines.slice(maxi(lines.size() - RECORD_ROWS, 0))
	for line in shown:
		var l := Label.new()
		l.text = line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		%EventRows.add_child(l)
	if lines.size() > shown.size():
		var more := Label.new()
		more.text = "…이전 기록 %d개" % (lines.size() - shown.size())
		more.theme_type_variation = &"MutedLabel"
		%EventRows.add_child(more)


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
		b.theme_type_variation = &"GhostButton"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 84)
		b.text = "%s · %d장 · 단어 %d" % [row["deck"].name, row["size"], row["craftable"].size()]
		if not row["unlocked"]:
			b.icon = AssetLib.tex("lock_on")
			b.expand_icon = true
		var deck_id: StringName = id
		b.pressed.connect(func(): setup_deck = deck_id; _refresh_setup())
		%DeckRows.add_child(b)
		var view := DeckView.new()
		view.alignment = FlowContainer.ALIGNMENT_CENTER
		view.add_theme_constant_override("h_separation", 4)
		view.modulate.a = 1.0 if row["unlocked"] else 0.5
		view.show_counts(row["counts"], {}, true)
		%DeckRows.add_child(view)
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
	var blocked := "못 만듦 · %s" % ", ".join(chosen["blocked"]) if not chosen["blocked"].is_empty() else ""
	%SetupInfo.text = "\n".join([blocked, pin_text]).strip_edges()


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
