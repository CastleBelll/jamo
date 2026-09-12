# JAMO UI 표현 분리: 에셋 vs 문구 (2026-09-12)

원칙 (G10/G12/S8): 숫자·상태·분류·행동은 **아이콘/에셋 + 숫자**로, 문장은 **한 줄 18자 이내**로, 상세는 **선택·Hover·Tooltip에서만**. 색만으로 구분하지 않고 아이콘 모양으로 구분한다. 실제 한글은 검수된 폰트로만 그린다.

## 1. 에셋으로 표현 (제작 목록)

| ID | 용도 (화면) | 크기 | 비고 |
|---|---|---|---|
| glyph_{ㄱ…ㅣ} 20종 | 전투 자모 (jamo_monster VisualPivot/Sprite2D) | 56×56 | 먹색 활자, 얇은 그림자, 정지 1장 |
| variant_light / heavy / guard | 변형 표식 (VisualPivot/VariantMark 대체) | 24×24 | 화살표 잔상 / 이중 외곽선 / 끊어진 사각 |
| status_burn / poison / slow | 상태 아이콘 (StatusAnchor) | 24×24 | 불꽃 / 방울 / 눈송이, 옆에 숫자만 |
| paper_bg, ink_overlay | corrupted_page Paper / Overlays | 1920×1080 | 밝은 종이 / 외곽 먹 번짐(알파) |
| sentence_row | LastSentence 배경 띠 | 1480×90 | 문장 행, 피격 시 붉은 테두리 프레임 1장 추가 |
| boss_mieum / silence / ieung / greed | 보스 글자 (boss_base Glyph 대체) | 360×100 | 교정 기호·검은 교정선·맴도는 원·금빛 고리 |
| marker_target | 공통 대응물 (pattern_target Ring/Cross 대체) | 90×90 | 숫자 표시 자리 비움 |
| hud_wave / stability / enemy / gold / drop | HUD 상단 아이콘 | 32×32 | 옆에 숫자만 표기 |
| slot_frame, rank_pip_on / off, seal_lock | 빌드 슬롯 프레임·Rank 핍·봉인 자물쇠 | 90×90, 12×12, 20×20 | 단어명 + 핍 3개 |
| cat_equip / relic / special / risk | 분류 아이콘 (E/R/S/X) | 24×24 | 사전·Forge 후보 |
| tag_{무기,화염,지속,방어,자동,냉기,경제,행운,위험} | 태그 아이콘 9종 | 20×20 | 시너지·후보 |
| act_add / replace / skip / remove | 자모 정리 행동 버튼 아이콘 | 32×32 | + / ⇄ / → / − |
| lock_on / lock_off, reroll, pin, restore, compound | Forge 아이콘 | 32×32 | 손패 타일 위 자물쇠 오버레이 |
| tile_jamo, tile_selected | 손패/덱 활자 타일 프레임 | 72×72 | 선택 하이라이트 |
| cand_new / cand_rankup / cand_replace | 후보 분류 배지 | 24×24 | 신규 / ↑ / 교체 필요 |
| result_fail / abandon / complete, cause_reach / pattern | 결과 화면 아이콘 | 40×40 | S3 문구 옆 |
| bookmark_silver / gold, badge_compound / clear / twelve | 복원도 책갈피·배지 3종 | 24×24, 48×48 | 사전·기록 탭 |
| lib_bg, lib_layer_{lamp,spines,lines,handwriting,openbook} | 서고 배경 + 상태 레이어 5종 | 1920×1080 | 켜고 끄는 알파 레이어 |
| tab_{hub,research,codex,records,settings} | 서고 탭 아이콘 | 32×32 | |
| title_screen, title_logo | 타이틀 | 1920×1080, 600×200 | 참고 art/_reference/title_ex.png |
| theme: panel_9slice, button_{normal,hover,pressed,disabled}, slider, check | Theme 리소스 | 9-slice | resources/ui/theme.tres 확장 |
| font_kr (OFL) | 본문/숫자 폰트 | | Pretendard 또는 Noto Sans KR, 라이선스 기록 |
| sfx: hit_ink, purify, sentence_hit, boss_warning, boss_intro, page_turn / bgm_library, bgm_combat | 음향 | ogg | Sfx.streams 등록 |

## 2. 문구로 표현 (규칙)

| 화면 | 남기는 문구 | 규칙 |
|---|---|---|
| HUD | 숫자만 (`W3`, `92/100`, `5`, `12G`, `2`) | 라벨 단어 제거, 아이콘이 의미 |
| Wave 준비 | `W5 · 거대한 ㅁ` + 대응 한 줄 (`표식 3번 → 착지 막기`) | 18자 이내 |
| Wave Clear | `정화 8 · 놓침 0 · 손실 8 · 회수 2` | 아이콘 도입 후 숫자만 |
| 자모 정리 | `덱 21/26 · 선택 1 · 제거 0`, 후보 힌트 `검·길 (ㄱ 부족 1)` | 설명문 제거, 버튼은 아이콘+한 단어 |
| Forge | `잠금 1/3`, `Reroll 2 (바뀜 6)`, 후보 `검  신규` / `불  R1→2` / `길  교체`, 상태 한 줄 | 효과 비교는 후보 선택 시에만, 2줄 |
| 효과 설명 | `수동 +30%`, `화상 3초 0.8/초`, `2초마다 앞 적 1.0` … | 단위·숫자 위주, 조사 최소 |
| 결과 | S3 문장 1줄 + `W5 도달 · W4 클리어`, `손실 적 70 · 패턴 30`, `빌드 검 R1`, `신규 검`, `12G`, `다음 · 칼: ㅋ 회수` | 항목당 1줄 |
| 서고 | 연구 `안정도 강화 I  30G` / `100 → 105` / 사유 1줄, 사전 `검 ㄱㅓㅁ  Ⅱ`, 덱 `Starter A · 20장 · 제작 17` | 상세는 선택 시 |
| 설정 | 슬라이더 값 숫자, 항목명 2~4자 | |

## 3. 적용 상태

- 문구 축약: 이 커밋에서 코드 반영(hud, run_game, reward/forge 패널, effect_text, library).
- 에셋: Codex 세션이 `art/` 아래에 제작(`art/ASSET_MAP.md`에 ID→파일 매핑), 이후 씬에 연결. 연결 전까지는 텍스트 폴백 유지.
