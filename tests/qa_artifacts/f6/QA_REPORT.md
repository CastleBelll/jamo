# F6 Juice / Polish — QA 리포트

판정: **PASS**

일자: 2026-09-10 / 브랜치 `main` / Godot 4.7.stable
검증 수단: ziva-godot MCP 로 실행 중인 Godot 에디터에 붙어 `run_scene` 으로 게임 탭에서
직접 플레이(육안 판정) + 에디터 씬/리소스 확인 + 창 띄운 QA 하네스 2종 신규
(`tests/qa_f6_juice.tscn`, `tests/qa_f6_settings.tscn`) + 기존 하네스 12종 회귀.

---

## 0. 요약

| 항목 | 결과 |
|---|---|
| A. S0 이월 2건 (절차 1~2) | PASS |
| B. S1 클릭 피드백 4종 (절차 3~6) | PASS |
| C. S2 상태이상 VFX (절차 7~10) | PASS |
| D. S3 에너지 피드백 (절차 11~14) | PASS |
| E. S4 단어 완성 연출 (절차 15~18) | PASS |
| F. S5 Step SFX 구조 (절차 19~22) | PASS |
| G. S6 AudioManager / 설정 (절차 23~28) | PASS |
| H. 회귀 F1~F5 (절차 29~32) | PASS |
| 성능 60 FPS (v0.3 §36) | PASS |
| 자동 테스트 / 정적 | PASS |

**FAIL 0건.** 아래 3.2 에 LOW 관찰 3건을 남긴다(판정에 영향 없음).

**임시 변경 원복 완료.** 프로덕션 파일 수정 0건. QA 가 추가한 것은
`tests/qa_f6_juice.gd|tscn`, `tests/qa_f6_settings.gd|tscn`, `tests/qa_artifacts/f6/` 뿐이다.
`git diff resources/balance/game_balance.tres` 의 유일한 변경(`low_energy_warning = 3`)은
DEV 의 것이고 QA 는 손대지 않았다. `low_energy_warning` A/B(절차 14)는 파일이 아니라
**실행 중 메모리 값만** 6 으로 바꿨다가 3 으로 되돌렸고, 하네스가
`restored_threshold: 3` 으로 원복을 자체 확인한다. 세이브 파일도 검증 시작 전 상태
(= `user://jamo_save.json` 없음, `.qabak` 만 존재)로 되돌려 두었다.

---

## 1. DEV 인계문 검수 절차 — 번호별 결과

### 전제 (헤드리스 3종)

| 명령 | 결과 |
|---|---|
| `godot --headless --path . --quit` | **에러 2줄만** — `NotoSansKR-Regular.ttf` 누락(기존 이슈). 경고 0. |
| `res://tests/test_game_loop.tscn` | `OK - all game loop checks passed.` |
| `res://tests/test_day_flow.tscn` | `OK - day flow reached Day 2.` |

### A. S0 이월 2건

| # | 결과 | 근거 |
|---|---|---|
| 1 | PASS | `scenes/ui/hud.tscn:176` `tooltip_text = "단어 트리"`. 게임 실행 중 책 아이콘에 포인터를 올려 hover 하이라이트까지 확인(툴팁 팝업 자체는 임베디드 Game 탭 캡처에 렌더되지 않는다). "단어 도감" 문자열은 씬에 남아 있지 않다. |
| 2 | PASS | `word_tree.gd:191` shadowing 경고 **0줄**. 헤드리스 부팅/실행 로그 전체에 `hidden` 경고 없음. 폰트 에러 2줄만 남는다. |

### B. S1 클릭 피드백 4종

| # | 결과 | 근거 |
|---|---|---|
| 3 | PASS | 실제 마우스 좌클릭 1회 → 같은 프레임에 `animation_after_click: "hit"`(squash), `hitfx_emitting: 1`(먹가루 파티클), `damage_numbers_added: 1`(데미지 숫자). 소리 없음, 에러 없음. `juice_s1_single_click.png` — ㅅ 이 납작해지고 주변에 먹가루가 튀는 게 보인다. |
| 4 | PASS (F1 회귀) | `qa_critical_play` 재실행: 치명타 숫자 `8`(일반 `4`), `label_pixel_size 0.00448` vs 일반 `0.0028`(더 큼), `label_modulate (0.86,0.24,0.16)`(붉음), `max_shake_offset 0.0533` vs 일반 `0.0311`(더 흔들림). |
| 5 | PASS | 20회 연타 전부 명중(`clicks_that_hit: 20` — 에너지 소비량으로 계산). 평균 **60.00 FPS**. 파티클 끊김 없음. `juice_s1_burst_20.png`. |
| 6 | PASS | 에디터에서 `game_world.tscn` 열어 확인: `FXRoot/HitFXPool` 자식 **10개**, `FXRoot/DeathFXPool` 자식 **8개**가 미리 배치돼 있다. 20회 연타 후에도 `pool_before == pool_after`(10 / 8). 런타임 인스턴스화 0. 씬 configuration warning 0. |

### C. S2 상태이상 VFX

| # | 결과 | 근거 |
|---|---|---|
| 7 | PASS | 자모 ㅂ/ㅜ/ㄹ 지급 → `complete_ready_words()` 로 `불` 완성, `GameState.get_burn_effect()` 가 non-null. |
| 8 | PASS | `effects_changed` 소비 확인: 적용 전 `emitting=false` → 적용 직후 `true`. 크롭 `crop_burn_ember_on.png` 에 자모 위 작은 **주황 ember 입자 몇 알**만 보인다. 불기둥 아님. |
| 9 | PASS | 화상 만료(3.0초) 시점에 `emitting=false` 로 자동 전환(강제 off 아님 — 실제 `effects_changed` 경로). 파티클 lifetime(0.7초)까지 더 기다린 뒤에도 잔여 입자 0 — `crop_burn_ember_cleared.png` 에 주황 픽셀이 하나도 없다. |
| 10 | PASS | `돈` → `금` 순서로 선행까지 완성해야 `golden_unlocked: true` 가 된다(선행 게이트 정상). 황금 개체에 `StatusEffectAnchor/GoldSparkle` 존재, `emitting: true`, `amount: 10`. |
| **Bloom 판정 (v0.3 §24)** | PASS | `WorldEnvironment.glow_enabled = false` — 화면에 glow 패스 자체가 없다. 두 머티리얼 모두 `shading_mode = 0`(unshaded), emission 없음. 스크린샷상 흰 번짐 0. |

### D. S3 에너지 피드백

| # | 결과 | 근거 |
|---|---|---|
| 11 | PASS | 에너지 변화마다 `EnergyPulseAnim` 이 `pulse` 재생(`pulse_anim_name: "pulse"`). |
| 12 | PASS | 에너지 3에서 `EnergyWarnLabel.visible=true`, 텍스트 `"⚠ 에너지 부족"`, `EnergyWarnAnim` 이 `warn` 재생 중(깜빡임), 게이지 `self_modulate (1.0, 0.55, 0.45)` 로 붉어짐. **색 + 텍스트 + ⚠ 기호 + 깜빡임** 4중 신호이므로 색 단독 전달이 아니다. `juice_s3_low_energy_warning.png`. |
| 13 | PASS | 에너지 0 즉시에는 Dim/DayEnd **둘 다 false**, 경고 라벨은 그 순간 사라진다. 이후 **756~774 ms**(설정값 0.8초) 뒤 Dim + Day Complete. 그 정산 창 안에서 화상 틱이 몬스터를 잡았고 `kills_delta: 1`, `gold_earned_delta: 4.08 G` 로 **골드가 정상 지급**됐다. `juice_s3_energy_zero_settling.png` → `juice_s3_day_end.png`. 실제 플레이(45클릭 소진)에서도 Dim + "DAY 25 종료 / 처치한 자모 9 / 획득한 골드 36 G" 확인. |
| 14 | PASS | 임계값을 **메모리 상에서만** 6으로 바꿔: 에너지 6 → 경고 표시, 에너지 7 → 경고 없음. 3으로 되돌린 뒤 에너지 6 → 경고 없음. HUD 가 상수가 아니라 `GameBalance.low_energy_warning` 을 읽는다는 증거. `.tres` 파일 미변경. |

### E. S4 단어 완성 연출 — 단계별 스크린샷

| # | 결과 | 근거 |
|---|---|---|
| 15 | PASS | 4단계 전부 육안 확인. ① `juice_s4_1_gather_ring.png` — 필요한 자모 3개가 중앙을 둘러싼 반경 240px 원 위에 배치(`ring_spread_px: 240.0`). ② `juice_s4_2_gather_midway.png` — 시차를 두고 이동 중(TRANS_BACK 특성상 살짝 바깥으로 감았다가 들어간다). ③ `juice_s4_3a_reveal_overshoot.png` / `..._3b_reveal_settled.png` — 패널이 작게 나타났다 튀며 자리잡음(`RevealAnim` 의 `reveal` 재생 중). ④ `juice_s4_4_camera_zoom.png` — 직교 카메라 `size` 9.60 → **8.17**(= 9.6 × 0.85) → 9.60 복귀. 배경 종이가 커졌다 돌아온다. ⑤ 사운드 없음(정상). |
| 16 | PASS | 집결 도중 마우스 클릭: 즉시 패널 등장, 단어 `불` / 자모 `ㅂ + ㅜ + ㄹ` / 설명 텍스트 정상, FlyLayer 숨김. **Enter(ui_accept)** 도 동일. 스킵 후 `확인` 으로 정상 종료(`closed_after_continue: true`). `juice_s4_6_skip_click.png`, `juice_s4_6_skip_accept.png`. |
| 17 | PASS | 두 단어를 한 큐에 넣으면 첫 단어 확인 후 **두 번째 단어도 집결 연출부터 재생**(`second_word_gathers_again: true`, `second_gather_jamo: 3`, `second_panel_hidden_during_gather: true`), 두 번째 단어 텍스트 `돈` 정상. 큐 소진 후 패널 숨김. `juice_s4_5_second_word_gather.png`. |
| 18 | PASS | 에디터에서 `word_complete.tscn` 열어 `FlyLayer/FlyJamo0~7`, `RevealAnim` 노드 확인, configuration warning 0. `Gather Seconds / Gather Stagger / Gather Radius / Gather Start Angle` 이 Inspector 노출(property list 의 `PROPERTY_USAGE_EDITOR` 확인). `RevealAnim` 에 `reveal` 애니메이션 존재. |

### F. S5 MotionProfile 별 Step SFX

| # | 결과 | 근거 |
|---|---|---|
| 19 | PASS | `heavy_step.tres` → `step_sfx_path` 가 Inspector 노출(`PROPERTY_USAGE_EDITOR=true`, hint 13 = `@export_file`, 필터 `*.ogg,*.wav,*.mp3`), 값 `res://art/audio/sfx/step_heavy.ogg`. |
| 20 | PASS | `light_step`→`step_light`, `bounce`→`step_bounce`, `roll`→`step_roll`, `glide`→`step_glide` 로 **5종 전부 서로 다르다**. 파생 프로필도 의도대로 공유: `heavy_bounce`→bounce, `roll_fast`→roll, `sway`→glide, `upright`→light. 9개 프로필 모두 노출됨. |
| 21 | PASS | `walk_library.tres` 의 **walk 애니메이션 7종 전부**에 `play_step_sfx` Call Method 트랙 + 키 존재(`walk_light_step` 2키, `walk_heavy_step` 2, `walk_bounce` 2, `walk_roll` 2, `walk_sway` 2, `walk_upright` 2, `walk_glide` 1). walk 이 아닌 `idle/turn/hit/death/spawn` 에는 0키(정상). |
| 22 | PASS | 몬스터가 20초 넘게 걸어다니는 실제 플레이 3회 동안 콘솔에 **에러·경고 0**(폰트 2줄 제외). 무음. 9개 프로필 경로 전부 `play_sfx_path()` 로 직접 호출해도 에러 없음. |

### G. S6 AudioManager / 설정

| # | 결과 | 근거 |
|---|---|---|
| 23 | PASS | 게임에서 설정 아이콘 클릭 → **마스터 / 음악 / 효과음** 3슬라이더 + 오른쪽 퍼센트(기본 100%) 확인. 실제 게임 화면으로 육안 확인. |
| 24 | PASS | 효과음 0.5 → 라벨 즉시 `50%`, `AudioManager` 볼륨 0.5, SFX 버스 `-6.02 dB`. `settings_sfx_50.png`. |
| 25 | PASS | 닫기 → 저장 → **프로세스 완전 종료 후 재실행**: 패널을 열기도 전에 `AudioManager` 가 master 0.0 / bgm 0.25 / sfx 0.5 로 복원돼 있고, 슬라이더/라벨도 `0% / 25% / 50%`. `settings_restored.png`. |
| 26 | PASS | 런타임 `AudioServer` 버스 3개 = `["Master","BGM","SFX"]`, `audio/buses/default_bus_layout = res://default_bus_layout.tres`. 코드가 아니라 레이아웃 파일에서 온다(BGM/SFX 는 Master 로 send). |
| 27 | PASS | `sfx_library.tres` 슬롯 6개 = `click / click_critical / click_golden / kill / word_complete / bgm`, 전부 `@export_file` 로 Inspector 노출, **현재 전부 빈 문자열**. |
| 28 | PASS | 마스터 0% → `AudioServer.is_bus_mute(Master) == true`, `volume_db = -60`. 아주 작은 소리가 아니라 진짜 mute. `settings_master_0.png`. |

### H. 회귀 (F1~F5)

| # | 결과 | 근거 |
|---|---|---|
| 29 | PASS | 실제 플레이로 Day 25 → 에너지 소진 → Dim → Day 요약 → 자모 선택 → 상점 → **Day 26 시작**까지 한 바퀴. 막힘 없음. 저장 파일에 `day: 26`, `jamo_inventory {"ㄴ":1}`, `audio` 섹션, `save_version: 1` 정상 기록. (`리롤`/`건너뛰기` 버튼은 이 세이브에서 최대 리롤 0 / 자모 풀이 비지 않아 **의도대로 숨겨져 있었고** 버그 아님 — `jamo_choice.gd:43,56`.) |
| 30 | PASS | `qa_f5_tree` 재실행: Tab **1회**로 상단바 트리 버튼에 포커스 → Enter 로 트리 열림(`tree_opened_after_tabs: 1`). 트리 안에서 방향키 이동, Tab 으로 Footer 까지 순회, 닫으면 상단바 복귀. F5 QA 의 FAIL #1 이 해소된 상태 그대로 유지. |
| 31 | PASS | `qa_f5_arena` 재실행: 몬스터 20마리 피크에서 `worst_body_overhang_m = 0.0` — normal / 큰 ㅁ / 혼합 3케이스 전부 이탈 0. F5 QA 의 FAIL #2 도 해소 상태 유지. |
| 32 | PASS | `qa_f5_tree` 의 Target 규칙 그대로 동작(미발견 단어 지정 거부 메시지 포함). 실제 플레이 화면 하단에 `TARGET: 없음 (트리에서 지정)` 표시 확인. |

---

## 2. 태스크 지시 1~10 항목별 결과

**1. 오디오 애셋 부재의 조용한 처리 — PASS**
`art/audio/` 에 `.ogg/.wav/.mp3` 0개(README.txt 만). 5개 큐 + 9개 step 경로를 전부 실제로
재생 호출했고 **로드 에러·경고 0**. `AudioManager._stream_for()` 가 `ResourceLoader.exists()` 로
먼저 걸러 null 을 캐시한다. 게임 부팅·플레이·종료 콘솔 로그를 처음부터 끝까지 확인했고
남는 것은 기존 폰트 에러 2줄뿐. 버스 레이아웃 Master/BGM/SFX 정상 로드.

**2. S1 클릭 피드백 4종 — PASS**
한 클릭에 squash + 파티클 + 데미지 숫자가 동시. 20회 연타에서 평균 60.00 FPS,
풀 크기 불변(10/8) → 풀링 검증됨.

**3. S2 상태이상 VFX — PASS**
화상 걸면 ember on, 화상 끝나면 off, 파티클 수명 후 완전 소멸. `effects_changed` 를
실제로 소비한다(강제 off 경로 없음). 황금 sparkle 상시. Bloom 없음(glow 비활성 + unshaded).

**4. S3 에너지 피드백 — PASS**
pulse 동작. 잔여 3 이하에서 색 + "⚠ 에너지 부족" 텍스트 + 깜빡임 애니메이션이 함께 온다.
에너지 0 에서 즉시 정지가 아니라 **0.76초 정산 후** Dim + Day End. 정산 창 안에서 화상으로
죽은 몬스터의 골드(4.08 G)와 처치 수(1)가 **정상 지급**된다.

**5. S4 단어 완성 연출 — PASS**
집결 → 합성 → 등장 → Zoom 4단계를 각각 스크린샷으로 남겼다(`juice_s4_1` ~ `juice_s4_4`).
카메라 zoom 은 직교 size 9.60 → 8.17 → 9.60 로 실측. 스킵은 마우스/Enter 둘 다 동작하고,
스킵 후 텍스트·보상 흐름·저장 모두 정상(두 단어 큐도 두 번째부터 다시 집결 재생).

**6. S5 Step SFX 구조 — PASS**
9개 MotionProfile 전부 `Step Sfx Path` 가 Inspector 에 파일 필터와 함께 노출, 5종 서로 다름.
walk 애니메이션 7종 전부 `play_step_sfx` method 트랙 보유. 파일이 없어도 에러 없음.

**7. S6 AudioManager — PASS**
3슬라이더 동작 + 퍼센트 라벨 즉시 반영. 종료 후 재실행에 **실제 세이브 파일**로 복원 확인.
기존 세이브 구조 유지(`day/gold/jamo_inventory/rerolls_left/target_word/unlocked_words/upgrade_levels`
그대로, `audio` 만 추가, `save_version` 1 유지).
`audio` 키가 없는 **구버전 세이브도 정상 로드**(day 3 / gold 120 / click_damage Lv.2 복원,
볼륨은 100% 폴백, 경고·에러 0).

**8. 성능 (v0.3 §36) — PASS**
동시 **20마리 전원 화상 + HitFX 파티클 동시 발사** 상태에서 120프레임 샘플
**평균 60.00 FPS, 최악 프레임 16.67 ms**(= 60 FPS). 독립 확인으로 `qa_f4_special` 의
21마리(황금 6 + 특수 5 + 일반 10) 240프레임 샘플도 `average_fps 60.0 / worst_fps 60.0`.
(20연타 구간 샘플의 최악 프레임 37 ms 는 직전 PNG 저장이 끼어든 계측 아티팩트이고,
같은 구간 평균은 60.00 FPS 다.)

**9. 전체 회귀 — PASS**
F1 치명(클릭당 1회 판정, Day25 + 클릭피해 Lv.3 게이트: day24 행 숨김 / day25 "클릭 피해 Lv.3 필요"
잠금 / Lv.3 달성 시 구매 가능) · F2 리롤(리롤 행 day5 부터, 후보 중복 0, 포커스 가능) ·
F3 단어 10개 · 선행 잠금 · 화염 · 불꽃 전이 반경 게이트 · F4 특수 3종 · 황금 게이트
(잠김 시 2000회 draw 중 황금 0) · 체류시간 · F5 트리 4상태 · Target 규칙 · 키보드 전용 조작 ·
아레나 이탈 0 · Day 25 → Day 26 · 세이브/로드 — 전부 통과.

**10. 자동 테스트 — PASS**
`godot --headless --path . --quit` 에러는 폰트 2줄뿐, 경고 0.
`test_game_loop.tscn`, `test_day_flow.tscn` 통과. 추가로 기존 하네스 12종
(`qa_critical_play`, `qa_reroll_play`, `qa_shop_gate`, `qa_f3_compat`, `qa_f3_pool`,
`qa_f3_play`, `qa_f4_hud`, `qa_f4_special`, `qa_f5_arena`, `qa_f5_tree`,
`qa_f5_margin_ab`, `qa_f5_topdown`) 전부 창 띄운 상태로 재실행하여 통과.

---

## 3. DEV 주의/보류 사항 검증 + LOW 관찰

### 3.1 DEV 가 적은 주의사항 — 실제로 문제 없음

| DEV 항목 | 검증 결과 |
|---|---|
| 3.1 오디오 애셋 0개, 무음이지만 에러 없음 | **사실 확인.** 위 2-1 참조. FAIL 사유로 삼지 않았다. |
| 3.2 `AudioStreamPlayer3D` 대신 비위치형 풀 8개 | 스펙 이탈이지만 이번 사이클 요구(재사용/무음 폴백)를 만족한다. 8개 풀 라운드로빈이 20연타에서 프레임을 떨어뜨리지 않음을 실측했다. 3D 패닝은 다음 사이클 과제로 남기는 데 이견 없음. |
| 3.2 Damage Number 는 풀링하지 않음 | 20연타 + 20마리 화상에서 60 FPS 유지되므로 현재 부하에서 문제 없음. 기존 하네스(`qa_critical_play`)도 깨지지 않았다(재실행 통과). |
| 3.2 `hit_fx`/`death_fx` 의 자체 타이머·`queue_free` 제거 | 풀 자식 수가 20연타 후에도 10/8 로 불변, 누수 없음. 두 씬을 다른 곳에서 `instantiate()` 하는 코드가 없다는 것도 확인. |
| 3.3 구버전 세이브(`audio` 키 없음) 호환 | **실제 파일로 검증 통과.** 위 2-7 참조. |
| 3.3 `save_version` 1 유지 | 저장 파일에서 확인. 기존 키 손실 0. |
| 3.4 폰트 누락 2줄은 기존 이슈 | 사실 확인. 이번 변경과 무관. |
| 3.4 창을 띄워야 도는 하네스들 | 창 띄운 CLI 실행으로 **전부 통과**했다(`qa_f3_play` 포함). DEV 가 헤드리스에서 멈춘다고 적은 그대로였다. |

### 3.2 LOW 관찰 3건 (판정에 영향 없음)

- **LOW-1 — 에디터 GDScript 경고에 `word_revealed` 가 하나 추가된다.**
  에디터 스크립트 리로드 시 `The signal "word_revealed" is declared but never explicitly used`
  가 뜬다. 다만 이는 `signal_bus.gd` 의 **12개 시그널 전부**에 이미 붙어 있던 기존 패턴이고
  (`gold_changed`, `energy_changed` 등 11건이 F6 이전부터 존재),
  `godot --headless --path . --quit` 에는 나타나지 않는다. 규칙 §4.1 기준은 충족.
  근본 해결은 `signal_bus` 전체에 대한 별도 정리 과제.

- **LOW-2 — 집결 자모의 시인성이 낮은 편.**
  DEV 인계문은 "큼직하게 나타난다"라고 적었지만, 실제로는 1280×720 기준 약 30px 높이의
  어두운 글자가 어두운 배경 위에 놓여 눈에 잘 띄지 않는다(`juice_s4_1_gather_ring.png`).
  동작은 스펙대로이고 `Gather Radius` 등은 Inspector 에서 조절 가능하므로 밸런싱 사이클에서
  폰트 크기/대비만 올리면 된다.

- **LOW-3 — ember / sparkle 이 가독성 하한에 가깝다.**
  Bloom 금지(v0.3 §24)를 지키느라 매우 작다. 화상 ember 는 크롭해야 확실히 보이고
  (`crop_burn_ember_on.png`), 황금 sparkle 은 개체 자체가 금색이라 더 묻힌다
  (`crop_golden_sparkle.png`). "과도한 Bloom 이 아니다"라는 판정 기준은 충족하므로 PASS 이나,
  다음 사이클에 입자 크기나 amount 를 소폭 올리는 편이 낫다.

---

## 4. 증거 파일

`tests/qa_artifacts/f6/`

| 파일 | 내용 |
|---|---|
| `qa_f6_juice.json` | S1~S4 · 오디오 · 성능 관측치 전부 |
| `qa_f6_settings_write.json` / `_read.json` / `_legacy.json` | 설정 저장 → 재실행 복원 → 구버전 세이브 3단계 |
| `juice_s1_single_click.png`, `juice_s1_burst_20.png` | S1 클릭 피드백 / 20연타 |
| `juice_s2_burn_ember_on/off/cleared.png`, `crop_burn_ember_on/cleared.png` | S2 화상 ember on → off → 완전 소멸 |
| `juice_s2_golden_sparkle.png`, `crop_golden_sparkle.png` | S2 황금 sparkle |
| `juice_s3_low_energy_warning.png` | S3 잔여 3 경고(색 + 텍스트 + 깜빡임) |
| `juice_s3_threshold_6.png` | S3 임계값 6 A/B |
| `juice_s3_energy_zero_settling.png`, `juice_s3_day_end.png` | S3 에너지 0 → 0.76초 정산 → Dim + Day End |
| `juice_s4_1_gather_ring.png` → `juice_s4_4_camera_zoom.png` | **S4 연출 단계별 4장** |
| `juice_s4_5_second_word_gather.png`, `juice_s4_6_skip_click/accept.png` | S4 두 번째 단어 재생 / 스킵 2종 |
| `juice_perf_20_monsters_burning.png` | 20마리 전원 화상 상태 60 FPS |
| `settings_default/sfx_50/master_0/restored/legacy_save.png` | S6 설정 5장 |

신규 하네스: `tests/qa_f6_juice.gd|tscn`, `tests/qa_f6_settings.gd|tscn`
(둘 다 창을 띄워 실행: `godot --path . tests/qa_f6_juice.tscn`,
`godot --path . tests/qa_f6_settings.tscn -- write|read|legacy`).
