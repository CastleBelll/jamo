class_name AssetLib
extends RefCounted
## Resolves art ids from art/ASSET_MAP.md to textures. Missing files return null so every
## scene keeps its text fallback (S8: 실제 한글은 검수된 폰트/글리프로만).

const GLYPH_NAMES := {"ㄱ": "giyeok", "ㄴ": "nieun", "ㄷ": "digeut", "ㄹ": "rieul", "ㅁ": "mieum", "ㅂ": "bieup",
	"ㅅ": "siot", "ㅇ": "ieung", "ㅈ": "jieut", "ㅊ": "chieut", "ㅋ": "kieuk", "ㅍ": "pieup", "ㅎ": "hieut",
	"ㅏ": "a", "ㅓ": "eo", "ㅕ": "yeo", "ㅗ": "o", "ㅛ": "yo", "ㅜ": "u", "ㅣ": "i"}
const DIRS := {"glyph": "art/glyphs", "char": "art/glyphs", "boss": "art/bosses", "combat": "art/backgrounds", "hud": "art/hud", "lib": "art/library",
	"title": "art/title", "paper": "art/backgrounds", "ink": "art/backgrounds", "sentence": "art/backgrounds"}
const TAG_NAMES := {"무기": "weapon", "화염": "fire", "지속": "dot", "방어": "guard", "자동": "auto",
	"냉기": "cold", "경제": "econ", "행운": "luck", "위험": "risk"}
const CATEGORY_NAMES := {"E": "equip", "R": "relic", "S": "special", "X": "risk"}
const BOSS_NAMES := {"B_MIEUM": "boss_mieum", "B_SILENCE": "boss_silence", "B_IEUNG": "boss_ieung", "B_GREED": "boss_greed"}

## Character sprites (char_*.png, 256px) stand on their shadow; glyph_*.png (56px) is the flat fallback.
const CHARACTER_MIN_SIZE := 200
const CHARACTER_SCALE := 0.6

static var _cache: Dictionary = {}


static func path_for(id: String) -> String:
	var prefix := id.split("_")[0]
	var dir: String = DIRS.get(prefix, "art/ui")
	return "res://%s/%s.png" % [dir, id]


static func tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var path := path_for(id)
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[id] = t
	return t


## Ink icons recoloured to cream for dark surfaces (the HUD wood bar): alpha kept, colour replaced.
static func tex_light(id: String) -> Texture2D:
	var key := id + "#light"
	if _cache.has(key):
		return _cache[key]
	var base := tex(id)
	var out: Texture2D = null
	if base != null:
		var img := base.get_image()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var a := img.get_pixel(x, y).a
				if a > 0.0:
					img.set_pixel(x, y, Color(0.95, 0.91, 0.82, a))
		out = ImageTexture.create_from_image(img)
	_cache[key] = out
	return out


static func glyph(jamo: String) -> Texture2D:
	if not GLYPH_NAMES.has(jamo):
		return null
	var character := tex("char_%s" % GLYPH_NAMES[jamo])
	return character if character != null else tex("glyph_%s" % GLYPH_NAMES[jamo])


static func tag_icon(tag: StringName) -> Texture2D:
	return tex("tag_%s" % TAG_NAMES.get(String(tag), "")) if TAG_NAMES.has(String(tag)) else null


static func category_icon(category: StringName) -> Texture2D:
	return tex("cat_%s" % CATEGORY_NAMES.get(String(category), "")) if CATEGORY_NAMES.has(String(category)) else null


static func boss_glyph(boss_id: StringName) -> Texture2D:
	return tex(BOSS_NAMES[String(boss_id)]) if BOSS_NAMES.has(String(boss_id)) else null


## Applies a texture to a TextureRect/Sprite2D/Button icon slot; returns whether one was found.
static func apply(node: Node, id: String) -> bool:
	var t := tex(id)
	if t == null or node == null:
		return false
	if node is TextureRect or node is Sprite2D:
		node.texture = t
	elif node is Button:
		node.icon = t
	return true
