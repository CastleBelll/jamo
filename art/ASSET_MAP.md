# JAMO Asset Map

## Audio follow-up — synchronized boss layer and UI feedback

| Path | Length | Rate / codec | Decoded peak dBFS | Source / license |
|---|---:|---|---:|---|
| `art/audio/bgm_boss_layer.ogg` | 16.00s (705600 frames) | 44.1kHz mono / OGG Vorbis | -17.83 | project-original local synthesis; no third-party samples |
| `art/audio/sfx/ui_click.ogg` | 0.10s (4410 frames) | 44.1kHz mono / OGG Vorbis | -8.07 | project-original local synthesis; no third-party samples |
| `art/audio/sfx/ui_confirm.ogg` | 0.30s (13230 frames) | 44.1kHz mono / OGG Vorbis | -8.16 | project-original local synthesis; no third-party samples |
| `art/audio/sfx/ui_cancel.ogg` | 0.25s (11025 frames) | 44.1kHz mono / OGG Vorbis | -9.91 | project-original local synthesis; no third-party samples |
| `art/audio/sfx/ui_hover.ogg` | 0.05s (2205 frames) | 44.1kHz mono / OGG Vorbis | -24.14 | project-original local synthesis; no third-party samples |
| `art/audio/sfx/boss_purified.ogg` | 1.00s (44100 frames) | 44.1kHz mono / OGG Vorbis | -8.25 | project-original local synthesis; no third-party samples |

Boss layer: thin low A/E drone (55/110/165Hz) plus membrane-drum rhythm; 16.00 seconds / 705600 frames exactly matches combat. Existing combat source has a tonal A/E stack but no beat/BPM; new compatible 120 BPM grid gives 32 beats per loop. No whole-loop fade or seam silence; decoded boundary sample jump 0.00235, 10ms head/tail RMS nonzero. Combat+boss unity mix peak −12.86dBFS. UI click/hover are resonant wood taps; confirm is bright 660/880Hz two-note brush touch; cancel low220Hz; purified440Hz harmonic bell + upward shimmer. SFX leading/trailing below−60dBFS ≤3.02ms after decoding.

Provenance, source and read-only validation: `art/audio/FOLLOWUP_README.md`, `build_followup.py --check`, `FOLLOWUP_VALIDATION.json` (SHA-256 / codec / frames / peak / edge metrics). No downloads or paid provider jobs. Static waveform validation passed; engine registration, synchronized playback positions, listening and mix approval remain coordinator-owned. No code/scenes/project.godot changes.


v2 handoff: 94 final PNGs + 3 Nanum fonts, no required omissions (optional separate character shadows omitted; runtime draws ellipses). `python art/tools/validate_assets_v2.py` validates all final paths/dimensions/RGBA, transparency, vignette center and font files. HUD bottom fade corrected to alpha=0 during final validation. Scene wiring and in-game UI review remain coordinator-owned; no code/scenes/project settings changed in these commits. C/F are textured project-original procedural work, A/B/D/E use built-in ImageGen. 9-slice margins are listed in the C section.

## v2 E — battle desk and ink overlays

| Path | Size | 9-slice margin | Method |
|---|---|---|---|
| `art/backgrounds/combat_desk.png` | 1920×1080 | none | built-in ImageGen + size normalization |
| `art/backgrounds/sentence_row.png` | 1480×110 | none | built-in ImageGen + alpha-bound crop / size normalization |
| `art/backgrounds/sentence_row_hit.png` | 1480×110 | none | built-in ImageGen + alpha-bound crop / size normalization |
| `art/backgrounds/ink_vignette.png` | 1920×1080 | none | built-in ImageGen + size normalization |

Sources: `art/_source_v2/group_E/`, IDs: `group_E.json`. OpenAI Terms apply. Top-down desk: bright central hanji scroll, two subtle fold lines, warm lamp, brush/inkstone/tea props outside gameplay surface. Layout is approximate art only; B11 coordinates/click geometry unchanged. Sentence strips contain only faint decorative marks, blank center, charcoal underline; hit version has vermillion edge bleed. Vignette has alpha-transparent center. PNG modes, dimensions and transparency validated; no readable generated game text.

Prompt set: orthographic warm walnut desk, central1480×820 hanji at x220..1700/y130..950, two faint fold lines x≈760/1160, props only outside paper, no characters/text/UI; torn cream hanji sentence ribbon with faint illegible brush traces and charcoal underline, uniform center, transparent alpha; same ribbon with vermillion bleed; border-only sumi wash vignette, empty central80%, transparent alpha.


## v2 D — title and menu lighting

| Path | Size | 9-slice margin | Method |
|---|---|---|---|
| `art/title/title_logo.png` | 1200×420 | none | ImageGen source + user-authorized local subtitle crop / center |
| `art/title/title_screen.png` | 1920×1080 | none | built-in ImageGen + size normalization |
| `art/library/lib_bg_dim.png` | 1920×1080 | none | built-in ImageGen + size normalization |

Retained unchanged: `art/library/lib_bg.png` (1920×1080). Selected sources: `art/_source_v2/group_D/`, IDs: `group_D.json`. OpenAI Terms apply. Logo is RGBA cream dry-brush JAMO with glow and **no Korean subtitle**. The original baked subtitle was reported misspelled and removed, correcting the earlier visual-check claim. User authorized local postprocessing after ImageGen hit its limit: `art/title/crop_logo_only.py` crops the retained original above the subtitle, keeps the entire JAMO lettering/visible glow and centers it on a 1200×420 straight-alpha canvas. Subtitle is coordinator-rendered font text, not image data. Title background has four walking porcelain figures in the lower quarter and calm center; no menus. Dim library is an ImageGen lighting edit: left 40% dark walnut vignette fading to unchanged warm right. Reference `art/_reference/title_ex.png` used for style/composition. Dim edit preserves overall composition but is generative, not pixel-identical to the original.

Prompt set: isolated cream dry-brush uppercase JAMO with exact subtitle and transparent alpha; warm dusk dark-walnut library desk background with ㄱ/ㅁ/ㅇ/ㄴ walking lower center, no UI/text; edit original library lighting only, left40% dark vignette for menus, preserve objects and sunset.


## v2 B — porcelain bosses

| Path | Size | 9-slice margin | Method |
|---|---|---|---|
| `art/bosses/boss_mieum.png` | 512×512 | none | built-in ImageGen + canvas normalization |
| `art/bosses/boss_silence.png` | 512×512 | none | built-in ImageGen + canvas normalization |
| `art/bosses/boss_ieung.png` | 512×512 | none | built-in ImageGen + canvas normalization |
| `art/bosses/boss_greed.png` | 512×512 | none | built-in ImageGen + canvas normalization |

Sources: `art/_source_v2/group_B/`; model source IDs: `group_B.json`. All four RGBA cutouts visually reviewed. Prompt set: exact guide topology; black cracked ink-porcelain square ring / blank gray silhouette dissolving to ink particles / tilted running circular ring / gold-leaf bieup; warm rim light, two feet, front view, no ground/scenery/text, transparent alpha. OpenAI Terms apply; no third-party stock assets. Boss silhouette, hole topology and empty silence face checked.


Source codes: **FONT** = locally rendered Noto Sans KR (OFL-1.1); **PROC** = deterministic
project-original geometry (JAMO use, no third-party restriction); **IMG** = OpenAI
ImageGen output (OpenAI Terms); **AUDIO** = project-original procedural synthesis encoded
as Vorbis (JAMO use, no third-party restriction).

## Jamo glyphs

| ID | Path | Size | Source / license |
|---|---|---:|---|
| glyph_giyeok | `art/glyphs/glyph_giyeok.png` | 56×56 | FONT / OFL-1.1 |
| glyph_nieun | `art/glyphs/glyph_nieun.png` | 56×56 | FONT / OFL-1.1 |
| glyph_digeut | `art/glyphs/glyph_digeut.png` | 56×56 | FONT / OFL-1.1 |
| glyph_rieul | `art/glyphs/glyph_rieul.png` | 56×56 | FONT / OFL-1.1 |
| glyph_mieum | `art/glyphs/glyph_mieum.png` | 56×56 | FONT / OFL-1.1 |
| glyph_bieup | `art/glyphs/glyph_bieup.png` | 56×56 | FONT / OFL-1.1 |
| glyph_siot | `art/glyphs/glyph_siot.png` | 56×56 | FONT / OFL-1.1 |
| glyph_ieung | `art/glyphs/glyph_ieung.png` | 56×56 | FONT / OFL-1.1 |
| glyph_jieut | `art/glyphs/glyph_jieut.png` | 56×56 | FONT / OFL-1.1 |
| glyph_chieut | `art/glyphs/glyph_chieut.png` | 56×56 | FONT / OFL-1.1 |
| glyph_kieuk | `art/glyphs/glyph_kieuk.png` | 56×56 | FONT / OFL-1.1 |
| glyph_pieup | `art/glyphs/glyph_pieup.png` | 56×56 | FONT / OFL-1.1 |
| glyph_hieut | `art/glyphs/glyph_hieut.png` | 56×56 | FONT / OFL-1.1 |
| glyph_a | `art/glyphs/glyph_a.png` | 56×56 | FONT / OFL-1.1 |
| glyph_eo | `art/glyphs/glyph_eo.png` | 56×56 | FONT / OFL-1.1 |
| glyph_yeo | `art/glyphs/glyph_yeo.png` | 56×56 | FONT / OFL-1.1 |
| glyph_o | `art/glyphs/glyph_o.png` | 56×56 | FONT / OFL-1.1 |
| glyph_yo | `art/glyphs/glyph_yo.png` | 56×56 | FONT / OFL-1.1 |
| glyph_u | `art/glyphs/glyph_u.png` | 56×56 | FONT / OFL-1.1 |
| glyph_i | `art/glyphs/glyph_i.png` | 56×56 | FONT / OFL-1.1 |

## Combat field, boss, status, and HUD

| ID | Path | Size | Source / license |
|---|---|---:|---|
| variant_light | `art/ui/variant_light.png` | 64×64 | v2 PROC |
| variant_heavy | `art/ui/variant_heavy.png` | 64×64 | v2 PROC |
| variant_guard | `art/ui/variant_guard.png` | 64×64 | v2 PROC |
| status_burn | `art/ui/status_burn.png` | 48×48 | v2 PROC |
| status_poison | `art/ui/status_poison.png` | 48×48 | v2 PROC |
| status_slow | `art/ui/status_slow.png` | 48×48 | v2 PROC |
| paper_bg | `art/backgrounds/paper_bg.png` | 1920×1080 | IMG / OpenAI Terms |
| ink_overlay | `art/backgrounds/ink_overlay.png` | 1920×1080 | PROC |
| sentence_row | `art/backgrounds/sentence_row.png` | 1480×110 | v2 IMG |
| sentence_row_hit | `art/backgrounds/sentence_row_hit.png` | 1480×110 | v2 IMG |
| boss_mieum | `art/bosses/boss_mieum.png` | 512×512 | v2 IMG |
| boss_silence | `art/bosses/boss_silence.png` | 512×512 | v2 IMG |
| boss_ieung | `art/bosses/boss_ieung.png` | 512×512 | v2 IMG |
| boss_greed | `art/bosses/boss_greed.png` | 512×512 | v2 IMG |
| marker_target | `art/ui/marker_target.png` | 90×90 | PROC |
| hud_wave | `art/hud/hud_wave.png` | 64×64 | v2 PROC |
| hud_stability | `art/hud/hud_stability.png` | 64×64 | v2 PROC |
| hud_enemy | `art/hud/hud_enemy.png` | 64×64 | v2 PROC |
| hud_gold | `art/hud/hud_gold.png` | 64×64 | v2 PROC |
| hud_drop | `art/hud/hud_drop.png` | 64×64 | v2 PROC |
| slot_frame | `art/ui/slot_frame.png` | 160×160 | v2 textured brush ring / PROC |
| rank_pip_on | `art/ui/rank_pip_on.png` | 12×12 | PROC |
| rank_pip_off | `art/ui/rank_pip_off.png` | 12×12 | PROC |
| seal_lock | `art/ui/seal_lock.png` | 20×20 | PROC |

## Categories, tags, actions, and Forge

| ID | Path | Size | Source / license |
|---|---|---:|---|
| cat_equip | `art/ui/cat_equip.png` | 96×96 | v2 PROC |
| cat_relic | `art/ui/cat_relic.png` | 96×96 | v2 PROC |
| cat_special | `art/ui/cat_special.png` | 96×96 | v2 PROC |
| cat_risk | `art/ui/cat_risk.png` | 96×96 | v2 PROC |
| tag_weapon | `art/ui/tag_weapon.png` | 20×20 | PROC |
| tag_fire | `art/ui/tag_fire.png` | 20×20 | PROC |
| tag_dot | `art/ui/tag_dot.png` | 20×20 | PROC |
| tag_guard | `art/ui/tag_guard.png` | 20×20 | PROC |
| tag_auto | `art/ui/tag_auto.png` | 20×20 | PROC |
| tag_cold | `art/ui/tag_cold.png` | 20×20 | PROC |
| tag_econ | `art/ui/tag_econ.png` | 20×20 | PROC |
| tag_luck | `art/ui/tag_luck.png` | 20×20 | PROC |
| tag_risk | `art/ui/tag_risk.png` | 20×20 | PROC |
| act_add | `art/ui/act_add.png` | 64×64 | v2 PROC |
| act_replace | `art/ui/act_replace.png` | 64×64 | v2 PROC |
| act_skip | `art/ui/act_skip.png` | 64×64 | v2 PROC |
| act_remove | `art/ui/act_remove.png` | 64×64 | v2 PROC |
| lock_on | `art/ui/lock_on.png` | 64×64 | v2 PROC |
| lock_off | `art/ui/lock_off.png` | 64×64 | v2 PROC |
| reroll | `art/ui/reroll.png` | 64×64 | v2 PROC |
| pin | `art/ui/pin.png` | 64×64 | v2 PROC |
| restore | `art/ui/restore.png` | 64×64 | v2 PROC |
| compound | `art/ui/compound.png` | 64×64 | v2 PROC |
| tile_jamo | `art/ui/tile_jamo.png` | 144×144 | v2 PROC |
| tile_selected | `art/ui/tile_selected.png` | 72×72 | PROC |
| cand_new | `art/ui/cand_new.png` | 96×96 | v2 PROC |
| cand_rankup | `art/ui/cand_rankup.png` | 96×96 | v2 PROC |
| cand_replace | `art/ui/cand_replace.png` | 96×96 | v2 PROC |

## Results, records, and library

| ID | Path | Size | Source / license |
|---|---|---:|---|
| result_fail | `art/ui/result_fail.png` | 96×96 | v2 PROC |
| result_abandon | `art/ui/result_abandon.png` | 96×96 | v2 PROC |
| result_complete | `art/ui/result_complete.png` | 96×96 | v2 PROC |
| cause_reach | `art/ui/cause_reach.png` | 64×64 | v2 PROC |
| cause_pattern | `art/ui/cause_pattern.png` | 64×64 | v2 PROC |
| bookmark_silver | `art/ui/bookmark_silver.png` | 64×64 | v2 PROC |
| bookmark_gold | `art/ui/bookmark_gold.png` | 64×64 | v2 PROC |
| badge_compound | `art/ui/badge_compound.png` | 64×64 | v2 PROC |
| badge_clear | `art/ui/badge_clear.png` | 64×64 | v2 PROC |
| badge_twelve | `art/ui/badge_twelve.png` | 64×64 | v2 FONT + PROC / OFL-1.1 |
| lib_bg | `art/library/lib_bg.png` | 1920×1080 | IMG / OpenAI Terms |
| lib_layer_lamp | `art/library/lib_layer_lamp.png` | 1920×1080 | PROC |
| lib_layer_spines | `art/library/lib_layer_spines.png` | 1920×1080 | PROC |
| lib_layer_lines | `art/library/lib_layer_lines.png` | 1920×1080 | PROC |
| lib_layer_handwriting | `art/library/lib_layer_handwriting.png` | 1920×1080 | PROC |
| lib_layer_openbook | `art/library/lib_layer_openbook.png` | 1920×1080 | PROC |
| tab_hub | `art/ui/tab_hub.png` | 64×64 | v2 PROC |
| tab_research | `art/ui/tab_research.png` | 64×64 | v2 PROC |
| tab_codex | `art/ui/tab_codex.png` | 64×64 | v2 PROC |
| tab_records | `art/ui/tab_records.png` | 64×64 | v2 PROC |
| tab_settings | `art/ui/tab_settings.png` | 64×64 | v2 PROC |

## Title and Theme

| ID | Path | Size | Source / license |
|---|---|---:|---|
| title_screen | `art/title/title_screen.png` | 1920×1080 | IMG / OpenAI Terms |
| title_logo | `art/title/title_logo.png` | 1200×420 | v2 IMG |
| panel_9slice | `art/ui/panel_9slice.png` | 64×64 | PROC |
| button_normal | `art/ui/button_normal.png` | 64×32 | PROC |
| button_hover | `art/ui/button_hover.png` | 64×32 | PROC |
| button_pressed | `art/ui/button_pressed.png` | 64×32 | PROC |
| button_disabled | `art/ui/button_disabled.png` | 64×32 | PROC |
| slider_track | `art/ui/slider_track.png` | 64×8 | PROC |
| slider_grabber | `art/ui/slider_grabber.png` | 24×24 | PROC |
| check_on | `art/ui/check_on.png` | 24×24 | PROC |
| check_off | `art/ui/check_off.png` | 24×24 | PROC |
| font_noto_sans_kr | `art/fonts/NotoSansKR-Regular.ttf` | variable TTF | Noto Project Authors / OFL-1.1 |
| font_license | `art/fonts/OFL.txt` | text | SIL / OFL-1.1 |

## Audio

| ID | Path | Duration | Source / license |
|---|---|---:|---|
| hit_ink | `art/audio/sfx/hit_ink.ogg` | 0.22 s | AUDIO |
| purify | `art/audio/sfx/purify.ogg` | 0.65 s | AUDIO |
| sentence_hit | `art/audio/sfx/sentence_hit.ogg` | 0.52 s | AUDIO |
| boss_warning | `art/audio/sfx/boss_warning.ogg` | 0.85 s | AUDIO |
| boss_intro | `art/audio/sfx/boss_intro.ogg` | 1.20 s | AUDIO |
| page_turn | `art/audio/sfx/page_turn.ogg` | 0.48 s | AUDIO |
| bgm_library | `art/audio/bgm_library.ogg` | 16.00 s loop | AUDIO |
| bgm_combat | `art/audio/bgm_combat.ogg` | 16.00 s loop | AUDIO |

## v2 C — painterly UI surfaces

All images are RGBA PNG with straight (not premultiplied) alpha. Margins are symmetric
left/top/right/bottom pixel values; `—` means not intended for 9-slice stretching.

| Path | Size | 9-slice margin | Generation method |
|---|---:|---:|---|
| `art/ui/btn_ink_normal.png` | 512×112 | 48 | textured bristle mask + charcoal material |
| `art/ui/btn_ink_hover.png` | 512×112 | 48 | brighter wet-ink bleed |
| `art/ui/btn_ink_pressed.png` | 512×112 | 48 | flattened dark ink stroke |
| `art/ui/btn_ink_disabled.png` | 512×112 | 48 | translucent grey ink stroke |
| `art/ui/btn_paper_normal.png` | 512×112 | 48 | cream paper brush stroke |
| `art/ui/btn_paper_hover.png` | 512×112 | 48 | brighter paper brush stroke |
| `art/ui/btn_paper_pressed.png` | 512×112 | 48 | warm compressed paper stroke |
| `art/ui/panel_paper.png` | 512×512 | 72 | ragged hanji silhouette + fiber texture + alpha shadow |
| `art/ui/panel_ink.png` | 512×512 | 48 | translucent ragged ink material |
| `art/ui/hud_bar.png` | 1920×140 | — | dark wood grain + lower alpha fade |
| `art/ui/slot_frame.png` | 160×160 | — | multi-bristle circular brush stroke |
| `art/ui/slot_frame_empty.png` | 160×160 | — | interrupted circular brush stroke |
| `art/ui/bar_track.png` | 512×40 | 20 | ink stability track |
| `art/ui/bar_fill.png` | 512×40 | 20 | antique-gold stability fill |
| `art/ui/tab_active.png` | 256×80 | — | cream book-tab silhouette |
| `art/ui/tab_inactive.png` | 256×80 | — | ink book-tab silhouette |
| `art/ui/tooltip_arrow.png` | 32×16 | — | ink tooltip pointer |

Source: `art/tools/build_ui_v2.py`, project-original procedural texture/geometry (PROC).

## v2 F — ink icons and ceramic tiles

All icons have straight-alpha transparent backgrounds and no box-shaped backing.
Category/candidate/result icons use the request's 96px group size; other icons are 64px,
except 48px status markers. All margins below are `—` (no 9-slice).

| Path | Size | 9-slice margin | Generation method |
|---|---:|---:|---|
| `art/hud/hud_wave.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/hud/hud_stability.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/hud/hud_enemy.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/hud/hud_gold.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/hud/hud_drop.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/act_add.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/act_replace.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/act_skip.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/act_remove.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/reroll.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/restore.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/compound.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/lock_on.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/lock_off.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/pin.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/cat_equip.png` | 96×96 | — | dry-brush ink silhouette + accent |
| `art/ui/cat_relic.png` | 96×96 | — | dry-brush ink silhouette + accent |
| `art/ui/cat_special.png` | 96×96 | — | dry-brush ink silhouette + accent |
| `art/ui/cat_risk.png` | 96×96 | — | dry-brush ink silhouette + accent |
| `art/ui/cand_new.png` | 96×96 | — | dry-brush ink silhouette + accent |
| `art/ui/cand_rankup.png` | 96×96 | — | dry-brush ink silhouette + accent |
| `art/ui/cand_replace.png` | 96×96 | — | dry-brush ink silhouette + accent |
| `art/ui/result_complete.png` | 96×96 | — | dry-brush ink silhouette + accent |
| `art/ui/result_fail.png` | 96×96 | — | dry-brush ink silhouette + accent |
| `art/ui/result_abandon.png` | 96×96 | — | dry-brush ink silhouette + accent |
| `art/ui/cause_reach.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/cause_pattern.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/tab_hub.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/tab_research.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/tab_codex.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/tab_records.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/tab_settings.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/bookmark_gold.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/bookmark_silver.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/badge_clear.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/badge_compound.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/badge_twelve.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/variant_light.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/variant_heavy.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/variant_guard.png` | 64×64 | — | dry-brush ink silhouette + accent |
| `art/ui/status_burn.png` | 48×48 | — | dry-brush ink silhouette + accent |
| `art/ui/status_poison.png` | 48×48 | — | dry-brush ink silhouette + accent |
| `art/ui/status_slow.png` | 48×48 | — | dry-brush ink silhouette + accent |
| `art/ui/tile_jamo.png` | 144×144 | — | glazed ceramic shading + alpha shadow |
| `art/ui/tile_jamo_selected.png` | 144×144 | — | glazed ceramic shading + alpha shadow |
| `art/ui/tile_jamo_locked.png` | 144×144 | — | glazed ceramic shading + alpha shadow |
## v2 G — OFL typography

| Path | Format | 9-slice margin | Source / license |
|---|---|---:|---|
| `art/fonts/NanumMyeongjo-Regular.ttf` | TTF regular | — | official google/fonts / SIL OFL-1.1 |
| `art/fonts/NanumMyeongjo-Bold.ttf` | TTF bold | — | official google/fonts / SIL OFL-1.1 |
| `art/fonts/NanumBrushScript-Regular.ttf` | TTF regular | — | official google/fonts / SIL OFL-1.1 |
| `art/fonts/OFL-NanumMyeongjo.txt` | license text | — | NHN Corporation / SIL OFL-1.1 |
| `art/fonts/OFL-NanumBrushScript.txt` | license text | — | NHN Corporation / SIL OFL-1.1 |

Download URLs and intended uses are recorded in `art/fonts/README.txt`.


## v2 A — porcelain jamo characters

20 front-facing porcelain figures. Built-in ImageGen; Noto Sans KR OFL-1.1 silhouettes used only as shape guides. Exact strokes, two dot eyes and two black feet visually reviewed; malformed and baked-checkerboard attempts excluded. Straight-alpha PNGs, canvas-only crop/resize, bottom baseline 12px inset. Selected sources and preview: `art/_source_v2/characters/`, `characters_contact.png`; source IDs: `character_sources.json`.

| Path | Size | 9-slice margin | Method |
|---|---|---|---|
| `art/glyphs/char_giyeok.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_nieun.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_digeut.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_mieum.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_rieul.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_bieup.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_siot.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_ieung.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_jieut.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_chieut.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_kieuk.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_pieup.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_hieut.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_a.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_eo.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_yeo.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_o.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_yo.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_u.png` | 256×256 | none | ImageGen + canvas normalization |
| `art/glyphs/char_i.png` | 256×256 | none | ImageGen + canvas normalization |

Prompt set: Exact attached Korean jamo silhouette, cream glazed ceramic miniature, fine glaze cracks, warm upper-left light, two black dot eyes and two short black feet, strict front view, no mouth/arms/props, genuine transparent alpha. Stroke topology named explicitly for each guide. Rieul and chieut regenerated to correct geometry/transparency. Variant/status overlays are included in v2 F.


## P6 A — rigged 3D models

Blender MCP connection unavailable; authorized bpy fallback in Blender 5.2.1 LTS. All 24 GLBs pass independent binary/skin-pose validation. Exact OFL font outlines, locally authored packed glaze textures and four bone rig. Sources, licensing, per-file triangle/clip inspection and importer handoff notes: `art/models/MODELS.md`.

| Path | Rest height | Triangles | Bones | Clips | Method |
|---|---:|---:|---:|---|---|
| `art/models/char_a.glb` | 1 | 820 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_bieup.glb` | 1 | 864 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_chieut.glb` | 1 | 1322 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_digeut.glb` | 1 | 840 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_eo.glb` | 1 | 820 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_giyeok.glb` | 1 | 788 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_hieut.glb` | 1 | 1396 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_i.glb` | 1 | 764 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_ieung.glb` | 1 | 1392 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_jieut.glb` | 1 | 1282 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_kieuk.glb` | 1 | 844 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_mieum.glb` | 1 | 816 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_nieun.glb` | 1 | 816 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_o.glb` | 1 | 820 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_pieup.glb` | 1 | 944 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_rieul.glb` | 1 | 888 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_siot.glb` | 1 | 1214 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_u.glb` | 1 | 820 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_yeo.glb` | 1 | 876 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/char_yo.glb` | 1 | 876 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/boss_greed.glb` | 2 | 864 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/boss_ieung.glb` | 2 | 1392 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/boss_mieum.glb` | 2 | 816 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |
| `art/models/boss_silence.glb` | 2 | 612 | 4 | idle / walk / hit / purify | bpy + OFL outline / embedded PBR |


## P6 B — word icons

Built-in ImageGen + alpha-preserving canvas normalization. No baked words or lettering, no third-party stock assets. Source/prompt set, hashes and visual contact sheet: `art/_source_p6/words/`; semantic notes and distribution provenance: `art/words/README.md`. All 22 basic + 2 compound data IDs match; all 24 outputs pass size/RGBA-alpha validation.

| ID | Word | Path | Size | Method / accent |
|---|---|---|---|---|
| W01 | 검 | `art/words/word_W01.png` | 256×256 | ImageGen / muted gold |
| W02 | 불 | `art/words/word_W02.png` | 256×256 | ImageGen / vermilion |
| W03 | 독 | `art/words/word_W03.png` | 256×256 | ImageGen / moss green |
| W04 | 벽 | `art/words/word_W04.png` | 256×256 | ImageGen / muted gold |
| W05 | 돌 | `art/words/word_W05.png` | 256×256 | ImageGen / muted gold |
| W06 | 활 | `art/words/word_W06.png` | 256×256 | ImageGen / muted gold |
| W07 | 창 | `art/words/word_W07.png` | 256×256 | ImageGen / muted gold |
| W08 | 칼 | `art/words/word_W08.png` | 256×256 | ImageGen / muted gold |
| W09 | 눈 | `art/words/word_W09.png` | 256×256 | ImageGen / icy blue |
| W10 | 물 | `art/words/word_W10.png` | 256×256 | ImageGen / icy blue |
| W11 | 실 | `art/words/word_W11.png` | 256×256 | ImageGen / muted gold |
| W12 | 숨 | `art/words/word_W12.png` | 256×256 | ImageGen / muted gold |
| W13 | 돈 | `art/words/word_W13.png` | 256×256 | ImageGen / muted gold |
| W14 | 운 | `art/words/word_W14.png` | 256×256 | ImageGen / moss green |
| W15 | 복 | `art/words/word_W15.png` | 256×256 | ImageGen / muted gold |
| W16 | 길 | `art/words/word_W16.png` | 256×256 | ImageGen / muted gold |
| W17 | 비 | `art/words/word_W17.png` | 256×256 | ImageGen / icy blue |
| W18 | 봄 | `art/words/word_W18.png` | 256×256 | ImageGen / soft coral |
| W19 | 밤 | `art/words/word_W19.png` | 256×256 | ImageGen / muted gold |
| W20 | 욕심 | `art/words/word_W20.png` | 256×256 | ImageGen / muted gold |
| W21 | 광기 | `art/words/word_W21.png` | 256×256 | ImageGen / vermilion |
| W22 | 폭주 | `art/words/word_W22.png` | 256×256 | ImageGen / vermilion |
| C01 | 불길 | `art/words/word_C01.png` | 256×256 | ImageGen / vermilion |
| C02 | 눈물 | `art/words/word_C02.png` | 256×256 | ImageGen / icy blue |
