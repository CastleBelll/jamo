# JAMO P6 word icons

24 icons: all 22 basic + 2 compound IDs from `resources/words/*.tres`. 256×256 straight-alpha PNGs, charcoal ink brush texture plus a single chromatic accent, no baked text. Canvas-only crop/resize with 16px minimum principal-silhouette inset; original alpha retained. Source PNGs and full prompts: `art/_source_p6/words/`; that source folder is excluded from Godot runtime imports.

Production: built-in ImageGen, then `normalize_words.py` (Pillow). No downloaded third-party images, no external fonts rendered into these icons. Generated images authored for JAMO; distribution follows the project's policy, not an asserted CC0 stock license. Model font OFL licensing is separately documented in `art/models/MODELS.md`.

Validation: all resource IDs match exactly, 24 RGBA outputs are 256×256 with actual transparent alpha. Hashes: `art/_source_p6/words/WORD_VALIDATION.json`. All icons were visually reviewed together in `WORDS_CONTACT.jpg` for meaning, brush texture, readable silhouette, and absence of letters. W09 is snow (its data tag is 냉기); C02 depicts crying/tears, not another water-ripple icon. W01/W07/W08 have distinct sword/spear/knife silhouettes; W02/C01 have distinct flame/fire-trail silhouettes. Actual UI size/contrast testing and resource connections remain the coordinator's work.

| ID | Word | File | Subject | Accent |
|---|---|---|---|---|
| W01 | 검 | `word_W01.png` | a sword with a long straight blade and small crossguard | muted gold |
| W02 | 불 | `word_W02.png` | one clear curling flame | vermilion |
| W03 | 독 | `word_W03.png` | a poison droplet above a small unmarked vial | moss green |
| W04 | 벽 | `word_W04.png` | a compact protective brick wall | muted gold |
| W05 | 돌 | `word_W05.png` | a rugged heavy rock | muted gold |
| W06 | 활 | `word_W06.png` | a curved bow with taut string and one arrow | muted gold |
| W07 | 창 | `word_W07.png` | a long spear with pointed head | muted gold |
| W08 | 칼 | `word_W08.png` | a short single-edged knife | muted gold |
| W09 | 눈 | `word_W09.png` | a six-armed snow crystal | icy blue |
| W10 | 물 | `word_W10.png` | one water drop above gentle concentric ripples | icy blue |
| W11 | 실 | `word_W11.png` | a rounded spool of thread with a trailing strand | muted gold |
| W12 | 숨 | `word_W12.png` | three airy flowing breath strokes emerging from a small soft puff | muted gold |
| W13 | 돈 | `word_W13.png` | three old round coins with square holes | muted gold |
| W14 | 운 | `word_W14.png` | one four-leaf clover with a tiny lucky sparkle | moss green |
| W15 | 복 | `word_W15.png` | a tied blessing pouch with a small tassel, no inscription | muted gold |
| W16 | 길 | `word_W16.png` | a winding path receding between two simple edges | muted gold |
| W17 | 비 | `word_W17.png` | one small ink cloud with distinct falling raindrops | icy blue |
| W18 | 봄 | `word_W18.png` | a flowering branch with two open blossoms | soft coral |
| W19 | 밤 | `word_W19.png` | a crescent moon above a quiet dark hill and two stars | muted gold |
| W20 | 욕심 | `word_W20.png` | an overfilled hoard of coins grasped by a curling claw | muted gold |
| W21 | 광기 | `word_W21.png` | a fractured circular eye-like spiral with jagged radiating cracks | vermilion |
| W22 | 폭주 | `word_W22.png` | a wild rushing streak of ink with a broken restraint chain | vermilion |
| C01 | 불길 | `word_C01.png` | a flame flowing along a curling trail of fire | vermilion |
| C02 | 눈물 | `word_C02.png` | a single large falling teardrop beneath a subtle eye arc | icy blue |

Rebuild/validate: `python art/words/normalize_words.py` (Pillow required).
