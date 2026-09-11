class_name HangulJamo
extends RefCounted
## Decomposes precomposed Hangul syllables into the token jamo used by the deck (G5).
## Compound vowels/tails outside SPLIT are returned as-is so the validator can reject them.

const LEADS := ["ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
const VOWELS := ["ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ", "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ"]
const TAILS := ["", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
## Only these compounds are split into tokens (G5). Others stay unsupported.
const SPLIT := {"ㅘ": ["ㅗ", "ㅏ"]}
const SYLLABLE_BASE := 0xAC00
const SYLLABLE_COUNT := 11172


static func decompose(text: String) -> Array[String]:
	var out: Array[String] = []
	for ch in text:
		var idx: int = ch.unicode_at(0) - SYLLABLE_BASE
		if idx < 0 or idx >= SYLLABLE_COUNT:
			out.append(ch)
			continue
		var lead: String = LEADS[idx / (21 * 28)]
		var vowel: String = VOWELS[(idx % (21 * 28)) / 28]
		var tail: String = TAILS[idx % 28]
		out.append(lead)
		out.append_array(SPLIT.get(vowel, [vowel]))
		if tail != "":
			out.append(tail)
	return out
