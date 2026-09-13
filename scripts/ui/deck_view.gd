class_name DeckView
extends HFlowContainer
## Read-only deck picture (G10): one tile per jamo with a count badge, sorted in Hangul order,
## optionally highlighting the jamo currently in the Forge hand. Used by the Forge, the
## 자모 정리 panel and the RUN setup rows so "what is in my deck" is always one glance away.

const TILE := 64
const TILE_COMPACT := 48
const FONT_BIG := 34
const FONT_COMPACT := 26
const FONT_BADGE := 16
const ORDER := ["ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
	"ㅏ", "ㅑ", "ㅓ", "ㅕ", "ㅗ", "ㅛ", "ㅜ", "ㅠ", "ㅡ", "ㅣ"]


## `counts`: jamo -> number in the deck. `highlight`: jamo -> number currently in hand (drawn gold).
func show_counts(counts: Dictionary, highlight: Dictionary = {}, compact: bool = false) -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return _rank(a) < _rank(b))
	var size := TILE_COMPACT if compact else TILE
	for j in keys:
		add_child(_tile(String(j), int(counts[j]), int(highlight.get(j, 0)), size, compact))


static func _rank(j: String) -> int:
	var i := ORDER.find(j)
	return i if i >= 0 else ORDER.size() + j.unicode_at(0)


func _tile(jamo: String, count: int, in_hand: int, size: int, compact: bool) -> Control:
	var b := Button.new()
	b.text = jamo
	b.custom_minimum_size = Vector2(size, size)
	b.theme_type_variation = &"GhostButton"
	b.add_theme_font_size_override("font_size", FONT_COMPACT if compact else FONT_BIG)
	b.toggle_mode = true
	b.button_pressed = in_hand > 0  # gold frame = in the hand right now
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "%s ×%d%s" % [jamo, count, (" · 손패 %d" % in_hand) if in_hand > 0 else ""]
	if count > 1:
		var badge := Label.new()
		badge.text = "×%d" % count
		badge.add_theme_font_size_override("font_size", FONT_BADGE)
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.offset_left = -30
		badge.offset_top = -22
		badge.offset_right = -4
		badge.offset_bottom = -2
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
	return b


## Helper for token lists ({"jamo": ...}) as kept by DeckService / ForgeService.
static func counts_of(tokens: Array) -> Dictionary:
	var out := {}
	for t in tokens:
		out[t["jamo"]] = out.get(t["jamo"], 0) + 1
	return out
