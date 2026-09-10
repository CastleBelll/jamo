# JAMO P0 (v0.4 전환) — DEV 완료 보고

## 1) 변경 파일 목록

### 신규
```
autoload/meta_state.gd (+ .uid)           MetaState — 영구 (S1)
autoload/run_state.gd (+ .uid)            RunState — 런 한정 (S2)
scripts/ui/run_result.gd (+ .uid)         RUN 결과 화면 (S8, §35)
scenes/ui/run_result.tscn
scripts/ui/placeholder_panel.gd (+ .uid)  도감/기록 자리표시 패널 (S8)
scenes/ui/placeholder_panel.tscn
tests/test_state_split.gd / .tscn         신규 테스트: State 경계 / RUN 실패 / v0.3 세이브
tests/test_run_flow.gd / .tscn            신규 테스트: P0 완료 기준 전체 경로
_deprecated_v03/.gdignore + README.md     v0.3 보류 자산 설명
tests/_deferred_v03/.gdignore + README.md 보류 테스트 설명
P0_DEV_REPORT.md                          이 보고서
```

### 삭제
```
autoload/game_state.gd (+ .uid)           MetaState / RunState 로 완전 이관 (S3)
```

### 이동 (삭제 아님, `.gdignore` 로 Godot 로드 제외) — S5
```
scenes/ui/day_end.tscn        -> _deprecated_v03/scenes/ui/day_end.tscn
scenes/ui/jamo_choice.tscn    -> _deprecated_v03/scenes/ui/jamo_choice.tscn
scenes/ui/jamo_card.tscn      -> _deprecated_v03/scenes/ui/jamo_card.tscn
scenes/ui/word_tree.tscn      -> _deprecated_v03/scenes/ui/word_tree.tscn
scripts/ui/day_end.gd         -> _deprecated_v03/scripts/ui/day_end.gd
scripts/ui/jamo_choice.gd     -> _deprecated_v03/scripts/ui/jamo_choice.gd
scripts/ui/jamo_card.gd       -> _deprecated_v03/scripts/ui/jamo_card.gd
scripts/ui/word_tree.gd       -> _deprecated_v03/scripts/ui/word_tree.gd
scripts/word_system/candidate_generator.gd -> _deprecated_v03/scripts/word_system/
(각 .uid 동반. scripts/word_system/ 는 비어서 사라짐)
```

### 이동 (보류 테스트, `.gdignore`)
```
tests/test_day_flow.*  test_game_loop.*  sim_balance.*
tests/qa_critical_play.*  qa_f3_compat.*  qa_f3_play.*  qa_f3_pool.*
tests/qa_f4_hud.*  qa_f4_special.*  qa_f5_tree.*  qa_f6_juice.*  qa_f6_settings.*
tests/qa_reroll_play.*  qa_shop_gate.*  qa_f8_choice.*  qa_f8_shop.*  qa_f8_variant.*
   -> tests/_deferred_v03/   (총 17개 파일군, 삭제 0개)
```

### 수정
```
project.godot                        autoload GameState -> MetaState + RunState, description
autoload/signal_bus.gd               day_started->wave_started, day_ended->run_failed,
                                     core_hp_changed / codex_word_registered 신규,
                                     target_word_changed / jamo_collected 제거
autoload/save_manager.gd             v2 meta/run/audio 분리 + v0.3 마이그레이션 (S7)
scripts/main.gd                      Day 시퀀스 -> RUN 실패 -> 결과 -> Hub (S8)
scripts/ui/title_screen.gd           Main Hub 로 확장 (S8)
scenes/ui/title_screen.tscn          버튼 7개 + 성장 readout + 패널 3종 인스턴스
scripts/ui/hud.gd, scenes/ui/hud.tscn   DAY->WAVE, 문장핵 HP 패널, 장착 단어 표시
scripts/ui/pause_menu.gd, .tscn      TitleButton -> HubButton, save_run()
scripts/ui/settings_panel.gd         save_game() -> save_run()
scripts/ui/upgrade_shop.gd, .tscn    Hub 전용, "다음 DAY 시작" -> "닫기"
scripts/ui/upgrade_row.gd            MetaState 참조, Day 잠금 표시 제거
scripts/upgrades/upgrade_manager.gd  LOCKED_BY_DAY / LOCKED_BY_NEXT_DAY 제거
scripts/combat/click_controller.gd   RunState 참조
scripts/combat/status_effect_container.gd, status_effect_instance.gd   주석
scripts/monsters/jamo_monster.gd     monster_hp_for_wave / RunState.register_kill
scripts/monsters/spawn_manager.gd    MetaState.get_monster_capacity / RunState 효과
scripts/data/word_data.gd            v0.4 §21 스키마 (S6)
scripts/data/word_effect_data.gd     주석
scripts/data/upgrade_data.gd         unlock_day / level_unlock_days 제거 (S4)
scripts/data/game_balance.gd         *_per_day -> *_per_wave, base_core_hp,
                                     run_end_settle_seconds, focus_* 제거
scripts/data/game_database.gd        주석
resources/balance/game_balance.tres  위 필드 반영 (값 유지)
resources/upgrades/*.tres (6개)      unlock_day / level_unlock_days 삭제, 설명 Wave 화
resources/words/*.tres (10개)        v0.4 스키마 마이그레이션
tests/qa_f5_arena.gd, qa_f5_margin_ab.gd, qa_f5_topdown.gd   State 이름 이식
tests/qa_f7_art.gd                   세이브 픽스처 v0.4 화, 숨은 노드 겹침 오탐 수정,
                                     _on_new_game_pressed -> _on_new_run_pressed
tests/qa_f8_title_shots.gd, qa_f9_verify_real_input.gd   세이브 픽스처 v0.4 화
docs/DEV_ROADMAP.md                  P0 체크 + "P1 으로 넘긴 임시 처리" 절 추가
docs/ORCHESTRATION_RULES.md          §7.1 신설 (QA 회귀 항목 교체, 헤드리스 가능 범위)
```

`art/Untitled.blend*` 은 이번 작업과 무관한 기존 untracked 파일이다.
손대지 않았고 스테이징도 하지 않았다. git index 는 비워 뒀다 — 커밋 범위는 총지휘자가 결정.

---

## 2) 검수 절차 (QA 가 그대로 따라 할 것)

### A. 정적 / 자동 테스트

1. `godot --headless --path . --quit`
   → **기대**: `NotoSansKR-Regular.ttf` 폰트 누락 에러 2줄만. 그 외 에러 0.
2. `godot --headless --path . res://tests/test_state_split.tscn`
   → **기대**: exit 0, 마지막 줄 `OK - meta/run split holds.`
3. `godot --headless --path . res://tests/test_run_flow.tscn`
   → **기대**: exit 0, 마지막 줄
     `OK - Wave 1 started, the run failed, and the hub came back.`
4. 창 모드 하네스 (**헤드리스 금지** — `frame_post_draw` 대기로 멈춘다):
   ```
   godot --path . res://tests/qa_f7_title.tscn
   godot --path . res://tests/qa_f8_labels.tscn
   godot --path . res://tests/qa_f8_focus.tscn
   godot --path . res://tests/qa_f8_focus_all.tscn
   godot --path . res://tests/qa_f8_hover_focus.tscn
   godot --path . res://tests/qa_f8_resize.tscn
   godot --path . res://tests/qa_f9_hover_focus.tscn
   godot --path . res://tests/qa_f7_art.tscn
   godot --path . res://tests/qa_f8_title_shots.tscn
   godot --path . res://tests/qa_f9_verify_real_input.tscn
   ```
   → **기대**: 전부 exit 0, `FAIL` 0건. `bright_plates=1` 이 모든 행에 나온다.

### B. Main Hub (S8, §27)

5. 세이브가 있으면 백업 후 삭제하고 게임 실행 (`godot --path .`).
   → **기대**: 타이틀 아트 위에 판때기 버튼이
     `RUN 시작 / 영구 업그레이드 / 단어 도감 / 기록 / 설정 / 종료` 순으로 보인다.
     **`RUN 이어하기` 는 화면에 없다.** 진입 포커스는 `RUN 시작`.
6. 우상단 "영구 성장" 패널을 본다.
   → **기대**: `GOLD 0 G` / `최고 WAVE 1` / `발견 단어 0 / 10` / `처치 보스 0`.
7. 키보드 ↓↑ 로 버튼을 옮긴다.
   → **기대**: **밝은 판때기는 항상 정확히 1개.** 포커스 사각 박스 없음.
8. 마우스를 다른 버튼 위로 옮긴다.
   → **기대**: 밝은 판때기가 마우스 쪽으로 **이동**한다(2개가 되지 않는다).
     그 상태에서 다시 키보드 ↓ → 밝은 판때기가 키보드 쪽으로 이동.
9. 창 크기를 1280x720 → 1920x1080 → 1024x576 으로 바꾼다.
   → **기대**: 버튼 크기가 화면 비율에 따라 커지고 작아진다(픽셀 고정 아님).
     `RUN 이어하기` 유무와 무관하게 나머지 버튼 높이가 같다.
10. `영구 업그레이드` 클릭.
    → **기대**: "영구 업그레이드" 상점이 열린다. **Day 조건 문구("Day N 필요")가 하나도 없다.**
      `리롤` 행이 Day 5 게이트 없이 처음부터 보이고 가격만 걸려 있다.
      `치명 클릭` 은 `클릭 피해 Lv.3 필요` 로만 잠긴다. `닫기` 로 나온다.
11. `단어 도감` 클릭 → **기대**: "단어 도감 / 아직 등록된 단어가 없다 / … P4 …" 자리표시.
    `기록` 클릭 → **기대**: "기록 / 최고 WAVE 1 · 발견 단어 0 / 10 · 처치 보스 0 …" 자리표시.
12. `설정` 클릭 → **기대**: 기존 설정 패널. 볼륨 슬라이더 동작. 닫으면 포커스가 허브로 복귀.

### C. RUN 시작 → 실패 → Main Hub (P0 완료 기준, §48 Phase 0)

13. `RUN 시작` 클릭.
    → **기대**: 게임 화면 진입. HUD 좌상단이 **`WAVE 1`** (DAY 아님).
      그 옆에 **`문장핵 20 / 20`** 게이지. `ENERGY 20 / 20`, `0 G`, `처치 0`.
      좌하단 "장착 단어" 패널에 `장착한 단어 없음 — 자모 슬롯은 P2`.
14. 자모 몬스터를 클릭해서 잡는다.
    → **기대**: ENERGY 가 1씩 줄고 GOLD 가 오른다. 마지막 3 에너지에서 `⚠ 에너지 부족` 점멸.
15. 에너지를 0까지 전부 쓴다.
    → **기대**: 0.8초 뒤 화면이 어두워지고 **RUN 종료** 결과 화면이 뜬다.
      `도달 WAVE 1` / `처치 N` / `획득 GOLD N G (유지됨)` /
      `GOLD · 단어 도감 · … 는 그대로 남는다`. 최고 기록 갱신이면 `★ 최고 WAVE 기록 갱신`.
16. `메인 허브로` 클릭.
    → **기대**: Main Hub 로 돌아온다. **`RUN 이어하기` 가 보이지 않는다**(패배는 복구 불가).
      우상단 GOLD 가 방금 번 만큼 **남아 있다**. 최고 WAVE 가 1 이상.
      ← **15~16 이 P0 완료 기준이다.**

### D. State 분리가 실제로 지켜지는지 (§3, §44 — QA FAIL 판정 핵심)

17. 다시 `RUN 시작` → 몬스터 몇 마리 잡아 GOLD 를 올린다 → 현재 GOLD 를 적어둔다.
18. `ESC` → `저장 후 메인 허브로`.
    → **기대**: 허브에 **`RUN 이어하기` 가 나타나고** 그 아래
      `진행 중인 RUN — WAVE 1 · 문장핵 20`. GOLD 는 17에서 적은 값 그대로.
19. `RUN 이어하기` → **기대**: 같은 WAVE / 같은 남은 ENERGY 로 복귀.
20. 그 상태에서 에너지를 전부 써서 **패배**시키고 `메인 허브로`.
    → **기대**: `RUN 이어하기` 가 **사라진다**. GOLD 는 그대로 유지.
      런 데이터(Wave/에너지/장착 단어)는 사라졌고 영구 데이터(GOLD)는 남았다.
21. 세이브 파일을 직접 연다: `%APPDATA%\Godot\app_userdata\JAMO\jamo_save.json`
    → **기대**: 최상위에 `"meta"` 만 있고 `"run"` 키가 **없다**.
      `"meta"` 안에 `gold / permanent_upgrade_levels / codex_words / codex_mastery_exp /
      codex_mastery_levels / discovered_compounds / discovered_synergies /
      defeated_word_bosses / highest_wave / statistics` 가 전부 있다.
      `"meta"` 안에 `current_wave` / `core_hp` / `equipped_words` 같은 런 필드가
      **하나도 없어야 한다.** 있으면 FAIL.
22. 18단계처럼 RUN 중에 허브로 나온 뒤 같은 파일을 연다.
    → **기대**: `"run"` 블록이 생기고 그 안에 `current_wave / core_hp / current_energy /
      jamo_draw_bag / equipped_words / …` 가 있다.
      `"run"` 안에 `gold` / `highest_wave` / `codex_words` 가 **하나도 없어야 한다.**

### E. v0.3 세이브 호환 (S7)

23. 게임을 끄고 세이브 파일을 아래 내용으로 덮어쓴다.
    ```json
    {"save_version":1,"day":42,"gold":1234.5,"upgrade_levels":{"click_damage":3},
     "unlocked_words":["fire_001"],"jamo_inventory":{"ㅂ":2},"target_word":"fire_002"}
    ```
24. 게임 실행.
    → **기대**: 크래시 없음. GOLD `1234 G`. 발견 단어 `1 / 10`. **최고 WAVE 는 1**
      (Day 42 를 Wave 42 로 주지 않는다). 우상단에 노란 안내문
      `v0.3 세이브를 불러왔다. GOLD·업그레이드·단어는 유지, DAY 기록은 …` 이 뜬다.
      `RUN 이어하기` 없음.
25. `영구 업그레이드` 를 열어본다 → **기대**: `클릭 피해 Lv.3` 로 표시된다.
26. 세이브 파일을 다시 연다 → **기대**: `save_version: 2`, `meta` 블록,
    그리고 **`legacy_v03` 키 안에 원본 v0.3 페이로드가 통째로 보존**돼 있다.

### F. 에디터 가시성 (§46)

27. Godot Editor 로 프로젝트를 연다.
28. `scenes/ui/title_screen.tscn` 열기 → **기대**: 버튼 7개 + `GrowthPanel` 하위 라벨들이
    씬 트리에 노드로 보인다. `UpgradeShop` / `Codex` / `Records` 가 인스턴스로 붙어 있다.
    `Codex` 선택 → Inspector 에 `Title Text` / `Body Text` 가 편집 가능하게 노출.
29. `scenes/ui/run_result.tscn` 열기 → **기대**: 라벨/버튼이 전부 노드.
30. `resources/words/him.tres` 열기 → **기대**: Inspector 에 `Slot Type`(Equipment),
    `Tags`, `Run Max Rank`, `Base Effects`, `Rank Effect Values`, `Risk` 그룹,
    `Codex` 그룹, `Unlock` 그룹, `Presentation` 그룹이 전부 보인다.
31. `resources/balance/game_balance.tres` 열기 → **기대**: `Wave / Energy`, `Run`
    그룹이 보이고 `Base Core Hp = 20`, `Hp Growth Per Wave = 1.035`.

---

## 3) 주의 / 보류 사항

### 임시로 매핑한 수치 (P1/P12 에서 재산출 필요)

1. **Wave 곡선**: HP `3 × 1.035^(Wave-1)`, Gold `2 × 1.035^(Wave-1)`.
   Day 곡선을 Wave 에 **1:1 로 그대로 매핑**했다. `hp_growth_per_day` → `hp_growth_per_wave`
   로 이름만 바뀌었고 값(1.035 / 1.035, F8 튜닝 결과)은 유지했다.
   §5.2 가 요구하는 이동속도·동시 등장 수·특수 자모 비율·스폰 속도 상승은 **없다.**
   `game_balance.gd` 의 Monster Scaling 그룹에 TEMPORARY 주석으로 명시해 뒀다.
2. **문장핵 HP 기본값 20**(`base_core_hp`) 은 근거 없는 임시값이다. P1/P5 에서 잡아야 한다.

### 스펙과 다르게 처리한 것 (판단 근거 포함)

3. **RUN 실패 조건이 에너지 0 이다.** 문장핵과 Wave 컨트롤러는 P1 이라 지금은 코어를
   깎는 주체가 없다. P0 완료 기준("Wave 1 시작 후 실패해서 Hub 복귀")을 실제로 도달
   가능하게 만들려면 실패 경로가 하나는 있어야 해서, `scripts/main.gd` 의
   `@export var end_run_when_energy_depleted` 로 대체해 뒀다.
   **§7.1 은 에너지 0 이 Wave 를 끝내면 안 된다고 명시한다. P1 에서 이 플래그를 끄고
   `RunState.damage_core()` 로 옮겨야 한다.**
   (`damage_core()` / `core_hp_changed` 는 이미 구현돼 있고 HUD 도 표시한다.)
4. **Wave 2 로 넘어가는 경로가 없다.** `RunState.advance_wave()` 는 있지만 호출부가 없다.
   Wave Clear 는 P1 범위라 당겨오지 않았다.
5. **`WordData.base_effect_ids` 를 `base_effects: Array[WordEffectData]` 로 구현했다.**
   §21 은 id 목록을 적었지만, id → Resource 룩업 테이블을 새로 만들면 §46 의
   "데이터는 Inspector 에서 보이는 .tres 로" 원칙에 역행하고, 기존에 동작하던 화상/골드
   효과 배선을 깨뜨린다. Resource 직접 참조가 더 강한 계약이라고 판단했다.
   `risk_effect_ids` 는 아직 소비처가 없어 §21 대로 StringName 배열로 뒀다.
   판단 근거를 `word_data.gd` 헤더 주석에 남겼다.
6. **`WordData.prerequisites` 를 제거했다.** v0.4 에 선행 단어 개념이 없다
   (§22 합성어, §20 보스 해금이 대체). 대체 필드로 `unlock_condition` / `required_boss_id` /
   `compound_recipe_ids` 를 넣었다. `category` 는 `tags` 로 이관, `tier` 는 §21 에 없어 삭제.
7. **`scenes/ui/title_screen.tscn` 경로를 유지했다.** §43 은 `scenes/main_hub/main_hub.tscn`
   을 그리지만, 옮기면 F7~F9 타이틀 아트/테스트 10개가 전부 깨진다. 씬 트리 재편 Phase 로 미뤘다.
8. **`UpgradeData.required_word` 는 남겼다.** 단, 의미를 "MetaState 도감 등록 필요"로
   재해석했다(§38: RUN 장착으로는 열리지 않는다). 현재 이 필드를 쓰는 .tres 는 없다.
9. **`monster_capacity` / `critical_click` 업그레이드를 남겼다.** §13 의 P5 목록 5종
   (Click Damage / Max Energy / Core HP / Gold Bonus / Base Reroll) 과 다르지만 정리는 P5 범위다.
   **Core HP 업그레이드는 아직 없다.**

### v0.4 에서 역할이 바뀐 기존 단어 10개 (S6)

| 단어 | id | v0.3 | v0.4 slot_type / tags | 비고 |
|---|---|---|---|---|
| 힘 | power_001 | 영구 클릭 피해 +1 | EQUIPMENT / weapon, power | RUN 장착 시에만 적용 |
| 강타 | power_002 | 영구 치명 +10%p (선행 힘) | EQUIPMENT / weapon, power | 선행 관계 제거 |
| 불 | fire_001 | 영구 화상 해금 | SPECIAL / fire | 상태이상이라 특수효과 슬롯 |
| 화염 | fire_002 | 화상 틱 강화 (선행 불) | RELIC / fire | 규칙 변경이라 유물. 선행 제거 |
| 불꽃 | fire_003 | 화상 전이 (선행 불) | RELIC / fire | 동상 |
| 돈 | gold_001 | 영구 골드 +10% | RELIC / economy | §48 Phase 2 최초 단어 |
| 금 | gold_002 | 황금 몬스터 해금 (선행 돈) | RELIC / economy, luck | 이제 장착해야 발동 |
| 운 | luck_001 | 특수 몬스터 확률 | RELIC / luck | §48 Phase 2 최초 단어 |
| 밥 | energy_001 | 최대 에너지 +2 | EQUIPMENT / sustain | Wave 에너지로 의미 이동 |
| 체력 | energy_002 | 최대 에너지 +3 (선행 밥) | EQUIPMENT / sustain | 선행 제거 |

**§48 Phase 2 최초 단어 6개(검/불/돈/운/벽/힘) 중 검·벽은 아직 없다.** P2 범위라 만들지 않았다.
기존 10개는 하나도 지우지 않았다. 시너지 태그는 `syn_weapon` / `syn_fire` / `syn_fortune`
세 계열로 임시 배정했다(§23 SynergyData 자체는 P6).

### 세이브 호환 처리 방식 (S7)

10. **마이그레이션했다(초기화 아님).** v0.3 파일(`day` 키 존재)을 열면
    `gold` / `upgrade_levels` → `permanent_upgrade_levels` / `unlocked_words` → `codex_words`
    로 옮긴다. **`day` 는 `highest_wave` 로 옮기지 않았다** — Day 40 클릭커와 Wave 40
    로그라이트는 다른 축이라, 옮기면 플레이어가 얻지 않은 기록을 주는 셈이 된다.
    `statistics.migrated_from_v03_day` 에 숫자만 보관한다.
    `jamo_inventory` / `target_word` / `rerolls_left` 는 v0.4 에 대응물이 없다.
11. **원본을 지우지 않는다.** 마이그레이션 시 파일을 v2 로 다시 쓰면서 **원본 v0.3
    페이로드 전체를 `legacy_v03` 키에 그대로 보존**한다. 허브에 안내문도 띄운다.
12. **Day 기반 업그레이드 해금이 사라졌다** → `critical_click` 의 Day 25, `reroll` 의
    Day 5/25/60 게이트가 없어져 Gold 만 있으면 첫 Hub 방문부터 살 수 있다.
    밸런스 영향 있음, P5 대상.

### 테스트 처리 (전부 보고)

13. **삭제한 테스트 0개.** 17개 파일군을 `tests/_deferred_v03/` + `.gdignore` 로 보류했고,
    같은 폴더 `README.md` 에 파일별로 "무엇을 검증했나 / 왜 지금 못 고치나 / 되살릴 Phase"
    를 표로 적었다. 요약:
    - `test_day_flow`, `qa_critical_play`, `qa_f4_special`, `qa_f6_settings` → **P1**
    - `qa_f3_pool`, `qa_reroll_play` → **P2**
    - `qa_f3_play`, `qa_f4_hud` → **P2/P3**
    - `qa_f5_tree` → **P4** · `qa_shop_gate`, `qa_f8_shop` → **P5**
    - `qa_f6_juice` → **P11** · `sim_balance`, `qa_f8_variant` → **P12**
    - `test_game_loop`(2122줄) → **P1~P5 로 분해 재배치**
    - `qa_f3_compat`(v0.2→v0.3 호환) → 역할을 `test_state_split` 이 대신함. 참고용 보존
    - `qa_f8_choice`(자모 선택 화면) → 되살릴 Phase 없음
14. **이식한 테스트 3개**: `qa_f5_arena` / `qa_f5_margin_ab` / `qa_f5_topdown` — State 이름만 교체.
15. **픽스처만 고친 테스트 3개**: `qa_f7_art` / `qa_f8_title_shots` / `qa_f9_verify_real_input`
    의 `_write_fake_save()` 를 v0.4 `meta`+`run` 형태로 바꿨다.
    `qa_f7_art` 은 추가로 **숨은 노드 겹침 오탐**을 고쳤다 — 버튼이 7개가 되면서 숨은
    `ContinueButton`/`ContinueInfoLabel` 의 낡은 rect 가 겹침으로 잡혔다. 실제 화면은 정상이고
    `save_*` 케이스는 원래부터 0건이었다. `_on_new_game_pressed` → `_on_new_run_pressed` 도 반영.
16. **신규 테스트 2개** 모두 통과:
    - `test_state_split` — 필드 겹침 0 / RUN 실패 시 RunState 전멸·MetaState 유지 /
      도감 등록 ≠ 효과 활성 / v0.3 세이브 무크래시 / 패배한 런은 복구 불가
    - `test_run_flow` — Hub → RUN 시작 → Wave 1 → 실패 → 결과 → Hub 전체 경로 (실제 씬 전환 포함)
17. `qa_f9_verify_real_input` 이 **1회차에 1건 FAIL(hover 포커스), 재실행에서 통과**했다.
    마우스 워프 타이밍 플레이크로 보인다. QA 가 FAIL 을 보면 1회 재실행할 것.

### 사전 존재 이슈 / 환경

18. `res://art/fonts/NotoSansKR-Regular.ttf` 누락 — 기존 이슈, P0 범위 아님.
19. **`qa_f7_*` / `qa_f8_*` / `qa_f9_*` 는 `--headless` 에서 영원히 멈춘다.**
    `await RenderingServer.frame_post_draw` 때문이며 P0 이전부터 그랬다. 창 모드로 돌려야 한다.
    `qa_f7_live` 는 설계상 종료하지 않는 실시간 관찰 하네스, `qa_f5_*` 는 3000프레임 관찰이라 느리다.
    이 내용을 `docs/ORCHESTRATION_RULES.md` §7.1 에 적어 뒀다.
20. **`ORCHESTRATION_RULES.md` §4 검증항목 5번("Day 1 → Day 2 기본 루프")은 이제 성립하지 않는다.**
    §7.1 에 대체 회귀 경로를 명시했다. 총지휘자가 §4 본문도 갱신할지 판단 바람.
21. `scenes/ui/word_complete.tscn` / `scripts/ui/word_complete.gd` 는 **남겼지만 현재
    아무도 인스턴스하지 않는다.** 단어 제작 연출은 P2/P11 에서 다시 쓴다.
    `SignalBus.word_revealed` 구독자(`camera_rig`)도 그때까지 휴면 상태다.
22. `art/Untitled.blend*` 은 세션 시작 시점부터 untracked 였다. 건드리지 않았고 스테이징도 안 했다.
    git index 는 비워 뒀다.
