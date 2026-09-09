# F5 재검증 — 키보드 포커스 + 아레나 이탈 수정 확인 (QA 2차)

판정: **PASS**

일자: 2026-09-09 / 브랜치 `main` / Godot 4.7.stable / Intel UHD 770
검증 수단: ziva-godot MCP 로 실제 Godot 에디터 + Game 탭 실행(마우스/키보드 입력 주입),
헤드리스 자동 테스트, QA 하네스 4종(기존 3종 + QA 가 추가한 top-down 1종).

---

## 0. 요약

| 항목 | 결과 |
|---|---|
| DEV 절차 1~3 (정적/자동) | PASS |
| DEV 절차 4~12 (F5-QA-1 키보드) | PASS (9번만 문구와 다르게 동작, 결함 아님) |
| DEV 절차 13~22 (F5-QA-2 아레나) | PASS |
| DEV 절차 23~24 (회귀) | PASS |
| 태스크 1~10 | 전부 PASS (10번은 상태 기록만) |
| **아레나 회전에 대한 독립 확인** | **DEV 주장이 맞다. 1차 QA 의 원인 분석이 틀렸다.** |

**FAIL 0건.** 임시 데이터 변경 **없음**(아래 6절).

---

## 1. 아레나 회전 — QA 독립 확인 (가장 중요)

DEV 는 "1차 QA 가 슬래브를 축정렬 정사각형이라고 본 것은 틀렸고, 실제로는 45도 돌아 있다" 고
정정했다. QA 가 하네스를 신뢰하지 않고 **씬 파일과 런타임 양쪽에서 직접** 확인했다.

### 1-1. 씬 파일 원문 (`scenes/world/arena.tscn`)

```
[node name="Arena" type="Node3D"]
rotation = Vector3(0, 0.7854, 0)

[sub_resource type="BoxMesh" id="Mesh_top"]
size = Vector3(5.6, 0.08, 5.6)
```

루트 `Arena` 에 Y 회전 0.7854 rad 이 걸려 있다. `PaperTop` 은 로컬 5.6 × 5.6 (반폭 2.8).

### 1-2. 런타임 실측 (`game_world.tscn` 인스턴스 기준)

```
Arena.rotation      = (0.0, 0.7854, 0.0)
Arena.global_rot.y  = 0.78539997339249   deg = 45.0001
PaperTop local aabb = [P: (-2.8, -0.04, -2.8), S: (5.6, 0.08, 5.6)]
PaperTop world AABB pos=(-3.959798, -0.08, -3.959798) end=(3.959798, 0.0, 3.959798)
  corner = (-3.9598, 0.0000)   corner = (0.0000, 3.9598)
  corner = ( 0.0000,-3.9598)   corner = (3.9598, 0.0000)
CameraRig.rotation  = (0.0, 0.0, 0.0)
  ShakePivot rot=(0.0, 0.0, 0.0)
SpawnManager.arena_half_extents = (3.95, 3.95)
```

- `game_world.tscn` 의 `[node name="Arena" parent="." instance=...]` 에는 어떤 오버라이드도
  없다 → 인스턴스도 45도 회전을 그대로 상속한다.
- 종이 상판의 월드 꼭짓점은 `(±3.9598, 0)`, `(0, ±3.9598)` — **월드 좌표에서 마름모**다.
  half-diagonal 3.9598 = 2.8 × √2.
- `CameraRig` 의 yaw 는 0 이고 피치만 `Camera3D` 에 걸려 있다(`rotation = (-0.8727, 0, 0)`).
  즉 화면의 마름모는 카메라 때문이 아니라 **판이 실제로 45도 돌아 있기 때문**이다.

### 1-3. 결론

**DEV 의 정정이 옳다. 1차 QA 리포트 3절의 원인 설명("축정렬 정사각형, Arena 에 회전 없음,
화면의 마름모는 아이소메트릭 카메라 탓")은 사실과 다르다.** 따라서 1차 QA 가 적은 이탈
수치(0.61 / 0.70 m)도 잘못된 기준에서 나온 값이다. 다만 **이탈이 실재했다는 판정 자체는
맞았다** (DEV 가 올바른 기준으로 재측정한 수정 전 값: big_mieum 0.922 m).

### 1-4. 수정된 하네스가 판정을 무르게 만들었는가 — 아니다

`tests/qa_f5_arena.gd` 의 측정식을 직접 읽고 검토했다.

```gdscript
func _body_overhang(monster: JamoMonster) -> float:
	var aabb := _world_aabb(monster)
	...
	for corner_index in 8:
		var corner: Vector3 = _to_slab * aabb.get_endpoint(corner_index)
		worst = maxf(worst, maxf(absf(corner.x), absf(corner.z)) - SLAB_HALF)
```

- `_to_slab` = `arena.global_transform.affine_inverse()` — 실제 슬래브 프레임이다.
  `SLAB_HALF = 2.8` 은 `PaperTop` 의 로컬 반폭과 정확히 일치한다.
- `_world_aabb()` 가 각 메시의 **월드 축정렬 AABB** 를 먼저 만들고(글리프가 회전해 있으면
  이 단계에서 이미 부풀어난다) 그 8 꼭짓점을 슬래브 프레임으로 옮긴다. 즉 실제 몸통보다
  **더 크게** 잡는다 → **관대한 게 아니라 보수적(엄격)** 이다.
- 회전 프레임에서 박스를 통째로 재바운딩하지 않고 꼭짓점 단위로 옮기는 것도 맞는 처리다.

하네스는 자기에게 유리하게 완화되지 않았다. 그럼에도 아래 1-5 의 육안 판정을 최종 근거로 삼았다.

### 1-5. 육안 판정 (최종 근거) — QA 가 추가한 top-down 촬영

기존 하네스 스크린샷은 아이소메트릭 카메라라 글자 **높이**가 판 가장자리 위로 겹쳐 보여
footprint 이탈과 구분이 어렵다. 그래서 QA 가 `tests/qa_f5_topdown.gd` / `.tscn` 을 새로
만들어(테스트 전용, 프로덕션 씬 미변경 — 자기 카메라를 붙이고 HUD 를 숨긴다)
**직교 투영 진짜 top-down** 으로 촬영했다. 이 시점에서는 화면상의 글자 실루엣이 곧 footprint 다.

| 증거 | 결과 |
|---|---|
| `topdown_big_mieum_0/700/1400/final.png` | 큰 ㅁ 20마리 밀집. **모든 글자가 크림색 종이 안**. 갈색 테두리에 닿는 개체 0 |
| `topdown_normal_0/700/1400/final.png` | 일반 자모 20마리. 전부 판 안, 판 전체 폭을 사용 |
| `topdown_scale4_final.png` | 런타임에서 `VisualRoot.scale` 을 ×4 로 강제한 과장 개체 20마리 — **여전히 전부 판 안** |

아이소메트릭 기존 샷도 확인했다: `arena_big_mieum_1400/final.png`, `arena_worst_case_corner.png`
모두 몸통·그림자가 종이 위에 있다. 수정 전 백업(`before_fix/arena_worst_case_corner.png`)과
비교하면 우측 큰 ㅁ 의 몸통·그림자가 판 오른쪽 꼭짓점을 넘던 것이 수정 후에는 안쪽에서 멈춘다.

**하네스 결과(0.0 m)와 육안 판정이 일치한다.**

### 1-6. 클램프 로직 자체 검토

`JamoMonster.get_walkable_half_extents()` = `arena_half_extents − (bodyHalfX + bodyHalfZ) − arena_margin`,
`_clamp_to_arena()` 는 `|x|/h + |z|/h ≤ 1` 마름모로 되민다.

QA 가 수식을 독립 유도한 결과 일치한다: 슬래브는 월드에서 `|x+z| ≤ 3.9598` 이고 `|x−z| ≤ 3.9598`.
축정렬 몸통의 최악 꼭짓점은 이 합을 `hx + hz` 만큼 밀어 올리므로, 걷기 마름모의 half-diagonal 은
`3.9598 − (hx + hz) − margin` 이어야 한다. 코드가 쓰는 3.95 는 3.9598 보다 **0.0098 m 더 보수적**이다.
`_body_extent` 는 관측 최대값을 누적(줄지 않음)하므로 회전하는 글자에도 안전 측이다.
`_worst_case_corner()` 가 개체를 `(h, 0)` 에 세우는 것도 실제로 가장 빡빡한 지점이 맞다.

---

## 2. DEV 인계문 검수 절차 — 번호별 결과

### A. 정적 / 자동

| # | 결과 | 근거 |
|---|---|---|
| 1 | PASS | `godot --headless --path . --quit` → `NotoSansKR-Regular.ttf` 누락 에러 2줄뿐, 종료코드 0 |
| 2 | PASS | `OK - all game loop checks passed.` (약 40초 소요, DEV 안내대로 정상) |
| 3 | PASS | `OK - day flow reached Day 2.` |

### B. F5-QA-1 — 마우스 없이 트리를 열고 닫는다

| # | 결과 | 근거 |
|---|---|---|
| 4 | PASS | Day 1 에서 마우스 미사용, Tab 1회 → **책 아이콘 둘레에 굵은 크림색 테두리**가 나타난다. 어두운 상단바 위에서 대비가 확실해 바로 보인다 |
| 5 | PASS | Tab 2·3회 → 포커스가 **책 → 설정 → 일시정지** 로 좌→우 이동. 테두리도 따라 이동 |
| 6 | PASS | Shift+Tab(`ui_focus_prev`) → 일시정지에서 **설정(가운데)** 으로 역순 복귀 |
| 7 | PASS | 책에 포커스 둔 채 Enter → `단어 트리` 가 열리고 **첫 슬롯 `[제작 가능] 불`** 에 포커스. 상단바 `DAY 1 / ENERGY 20 / 20 / 0 G / 처치 0` 전부 가려지지 않음 |
| 8 | PASS | 트리 안에서 Tab 10회 → `닫기`, Enter → 트리가 닫히고 **포커스가 책 아이콘으로 복귀**(테두리 재확인) |
| 9 | PASS(문구와 다름) | 빈 배경 클릭은 Godot 에서 Control 포커스를 뺏지 않는다. 그래서 이후 Tab 은 책이 아니라 **다음 버튼(설정)** 으로 간다. DEV 문구("다시 책에 포커스")와는 다르지만 요구사항인 **"Tab 을 눌러도 아무 데도 안 잡히는 상태"는 재현되지 않았다**. 결함 아님 |
| 10 | PASS | 포커스를 잡은 채 몬스터를 30회 클릭(사이사이 Tab) → `ENERGY 3 / 20`, `처치 1`, `2 G`. 클릭·처치·에너지 소모 정상, Tab 이 클릭을 전혀 막지 않음 |
| 11 | PASS | 마우스 hover 시 옅은 크림 바탕 + 툴팁(`단어 도감` / `설정`) 표시, 클릭 시 각각 트리 / `설정` 패널 / `일시정지` 패널이 열린다. 아이콘 그림은 이전과 동일 |
| 12 | PASS | `qa_f5_tree.json > keyboard_open` = `{"tab_focus_chain": [".../HUD/TopBar/Buttons/DictionaryButton"], "tree_opened_after_tabs": 1, "tree_visible": true}` (수정 전 `(none)` / `-1`) |

메커니즘 확인: `hud.gd._unhandled_input()` 은 `gui_get_focus_owner() != null` 이면 즉시 return 한다.
즉 포커스가 이미 있을 때는 Godot 기본 Tab 이동에 끼어들지 않는다 — 게임 플레이 방해 요인 없음.

### C. F5-QA-2 — 어떤 크기의 개체도 슬래브를 넘지 않는다

| # | 결과 | 근거 |
|---|---|---|
| 13 | PASS | `qa_f5_arena.json`: `big_mieum` / `normal_jamo` / `mixed` 모두 `worst_body_overhang_m = 0.0`, `offenders = {}`, `peak_monster_count = 20`. `worst_case_corner.body_overhang_m = 0.0` |
| 14 | PASS | `slab_rotation_y_rad = 0.785399973392487` 이 리포트에 남는다 (1절에서 독립 확인 완료) |
| 15 | PASS | `margin=0.00 worst_overhang=0.000 worst_centre=2.539 over_ratio=0.000` / `margin=0.55 worst_overhang=0.000 worst_centre=2.013 over_ratio=0.000`. margin 0 에서도 이탈 0 |
| 16 | PASS | `arena_big_mieum_1400.png`, `arena_big_mieum_final.png` — 20마리 밀집에도 몸통·그림자가 판 안 |
| 17 | PASS | `arena_normal_jamo_final.png` / `topdown_normal_*.png` — 판 전체에 퍼진다. `furthest_centre_from_origin_m = 2.855`(수정 전 3.05, mixed 는 3.030). 중앙 뭉침 없음 |
| 18 | PASS | 20마리 상한 상태를 하네스로 35초 이상(관찰 2100프레임 × 3풀) 실제 렌더링하며 관찰. 어느 프레임에서도 이탈 0 |
| 19 | PASS | `big_mieum.tres` 에 `arena_margin` 라인 자체가 없다 → 기본값 **0.0**. `@export_range(0.0, 3.0, 0.05)` 이라 인스펙터 슬라이더로 조절 가능. 다른 자모 `.tres` 에도 `arena_margin` 없음(전부 0.0) |
| 20 | PASS(방식 변경) | `.tres` 를 고치지 않고 `qa_f5_margin_ab` 가 **메모리 상 값만** 0.0 / 0.55 로 바꿔 A/B. `worst_centre` 2.539 → 2.013 으로 실제로 안쪽으로 들어온다. **파일 변경 0건이므로 원복 대상 없음** |
| 21 | PASS | `game_world.tscn` `SpawnManager.arena_half_extents = Vector2(3.95, 3.95)`, `spawn_manager.gd` 주석에 "arena.tscn turns a 5.6 x 5.6 square by 45 degrees, so both are 2.8 * sqrt(2)" 명시 |
| 22 | PASS | `jamo_monster_base.tscn` 루트 `[node name="JamoMonster" type="CharacterBody3D"] process_priority = 1`. 에디터에서 열어 **구성 경고 0** 확인 |

### D. 회귀

| # | 결과 | 근거 |
|---|---|---|
| 23 | PASS | 실제 플레이: Day 1 클릭 → `ENERGY 0 / 20` → `DAY 1 종료`(처치 4 / 8 G) → `자모 선택으로` → `오늘의 자모를 하나 선택하세요`(ㅂ / ㄹ 2장). HUD 하단 `TARGET: 없음 (트리에서 지정)` 정상 |
| 24 | PASS | 마우스 클릭(책 아이콘)과 키보드 Enter 양쪽으로 트리 개폐·목표 지정/해제 동작 확인. `qa_f5_tree.json` 의 12~19·23~26 해당 항목 전부 이전과 동일 |

---

## 3. 태스크 지시 1~10 결과

**1. F5-QA-1 해소 — PASS.**
마우스를 한 번도 쓰지 않고 `Tab(상단바 진입) → Enter(트리 열기) → ↓/→/↑(슬롯 이동) →
Enter/Space(목표 지정) → Tab ×7(목표 해제) → Tab ×10(닫기) → Enter(닫기)` 전 과정 완결.
포커스 표시는 상단바(굵은 크림 테두리)·트리 슬롯(굵은 진갈색 아웃라인) 모두 육안으로 보인다.
**트리를 닫은 뒤 포커스는 책 아이콘으로 돌아온다**(`main.gd` 가 `WordTree.closed → HUD.focus_first_button`).
하네스 근거: `keyboard_inside_tree.focus_on_open = Col0/Slot0`, `arrow_walk` 5스텝,
`target_after_enter = gold_001`, `target_after_space = power_001`, `target_after_clear = ""`,
`closed_after_tabs = 10`, `tree_visible_at_end = false`.

**2. TextureButton → Button 변경 부작용 — PASS.**
`hud.tscn` diff 확인: 세 버튼 모두 `custom_minimum_size = Vector2(48, 48)`,
`unique_name_in_owner`, `tooltip_text`, 아이콘 리소스(`2_dict` / `3_set` / `4_pause`) 그대로.
`ignore_texture_size + stretch_mode=5` → `expand_icon = true` 로 대체(비율 유지 중앙 정렬로 동등).
마우스 클릭 3종 전부 동작: 책 → 트리, 설정 → `설정` 패널(전체 화면 / 저장 데이터 삭제 / 닫기),
일시정지 → `일시정지` 패널(계속하기 / 설정 / 저장 후 종료). hover 시 옅은 배경 + 툴팁이 새로 생겼다
(이전에는 피드백 없음 — 의도된 개선).

**3. 게임 중 Tab 방해 없음 — PASS.**
Tab 을 섞어가며 몬스터 30회 클릭 → 에너지 20 → 3, 처치 1, 골드 2 G. 진행 방해 없음.
코드상으로도 `_unhandled_input` 이 포커스 오너가 있으면 즉시 return 하므로 개입 지점이 없다.

**4. F5-QA-2 해소 (육안 우선) — PASS.** 1-5 절 참조. top-down 직교 촬영에서 큰 ㅁ 20마리,
일반 자모 20마리, 혼합 모두 판 안. 일반 자모 이동 범위는 수정 전 3.05 m → 2.855 m 로
사실상 유지되고 판 전체를 쓴다. 중앙 몰림 없음.

**5. 어떤 스케일도 안전 — PASS.**
`topdown_scale4`: 런타임에서 큰 ㅁ 20마리의 `VisualRoot.scale` 을 ×4(권장 데이터에 없는 값)로
강제해도 전원 판 안. 자동 테스트 `_test_no_monster_size_leaves_the_slab()` 도 전 자모 +
`OVERSIZED_VISUAL_SCALE` 개체를 걷기 마름모 림을 따라 돌리며 검증한다.
**데이터 파일은 건드리지 않았다**(런타임 메모리 값만) → 원복 불필요.

**6. AnimationPlayer 재클램프 — PASS.**
`jamo_monster.gd._process()` 재클램프 + 루트 `process_priority = 1`(자식 AnimationPlayer 보다
나중 실행) 확인. 애니메이션이 도는 상태로 2100프레임 × 3풀 관찰에서 이탈 0.
`_clamp_to_arena()` 는 `spill <= 1.0` 이면 early return 하므로 판 안쪽 개체의 위치를
매 프레임 다시 쓰지 않는다 → 끊김 유발 구조가 없다. top-down 연속 샷에서도 이동이 자연스럽다.
비용: 20마리 60 FPS 유지(아래 8번).

**7. F5 기능 회귀 — PASS.**
- 상태 4종: `[완성] / [제작 가능] / [선행 잠금] / [미발견]` 대괄호 텍스트 태그(색 비의존).
- Target 지정 규칙: 선행 잠금 거부(`화염 은(는) 선행 단어가 잠겨 있어…`, 기존 목표 유지),
  미발견 거부(`고열 은(는) 아직 발견하지 못해…`), 완성 거부(`불 은(는) 이미 완성한 단어입니다.`).
- 저장/복원: `saved_value = restored = gold_001`, `target_word` 키 없는 구 세이브 → `""`.
- 자동 해제: `target_after_completing_it = ""`.
- 포커스 가중치: `_test_target_focus_raises_candidate_weight()` 통과(확정 출현 없음).
- HUD TARGET: `TARGET: 돈 | [ ][ ][ ]` → `[ㄷ][ㅗ][ㄴ]` → 완성 후 `TARGET: 없음 (트리에서 지정)`.
- 상단바 미가림: 창 1280×460 에서도 `panel_top = 88.0 > top_bar_bottom = 76.0`,
  `close_button_fully_on_screen = true`.
- 스크롤: `Scroll` = ScrollContainer(`follow_focus = true`) 존재. 현 데이터로는 세로 스크롤이
  발생하지 않아 추종 동작 실측은 여전히 불가(L4, 1차와 동일).

**8. 전체 회귀 — PASS.**
`test_game_loop.tscn` 이 F1 치명 클릭, F2 리롤(게이트/차감/재추첨/패널 상태/저장),
F3 단어 10개·화염 burn·불꽃 확산, F4 특수 3종 배율·황금 게이트·`운` 확률,
세이브 왕복까지 전부 통과. `test_day_flow.tscn` Day 2 도달. 실제 플레이로 Day 1 → 자모 선택 확인.
**60 FPS**: 큰 ㅁ 20마리 상한 상태 600프레임 샘플 → `fps_min=60.0 fps_p05=60.0 fps_avg=60.0`.

**9. 자동 테스트 — PASS.** (절차 1~3)

**10. DEV 가 범위 밖으로 남긴 것 — 상태 기록만 (FAIL 사유 아님).**
- `scripts/ui/word_tree.gd:191` 지역변수 `hidden` 이 `CanvasItem.hidden` 시그널을 가리는 경고
  **여전히 출력됨**. 실행할 때마다 1줄. 동작 문제 없음.
- HUD 책 아이콘 툴팁 **여전히 `단어 도감`** (스크린샷으로 확인). 트리로 개칭 안 됨.

---

## 4. INFO / LOW

- **L1** `word_tree.gd:191` shadowing 경고 잔존 (범위 밖, DEV 3-G).
- **L2** 책 아이콘 툴팁 `단어 도감` 잔존 (범위 밖, DEV 3-G).
- **L3** `autoload/signal_bus.gd` 의 미사용 시그널 경고 10줄이 실행마다 출력된다.
  F5 이전부터 있던 것이고 에러가 아니다. DEV 기대치 "경고 0" 과는 어긋난다.
- **L4** `follow_focus` 는 현 데이터로 스크롤이 발생하지 않아 여전히 실측 불가.
- **L5** DEV 절차 9번의 기대 문구("빈 곳 클릭 후 Tab → 다시 책")와 실제 동작(포커스가 유지되므로
  다음 버튼으로 이동)이 다르다. 요구사항(포커스 사각지대 없음)은 충족하므로 결함이 아니라
  **인계문 문구 부정확**으로 기록한다.
- **L6** 몬스터를 연속으로 많이 클릭한 뒤 상단바 포커스 테두리가 사라진 프레임이 1회 관측됐다
  (30회 클릭 시나리오). 재현 시도(3회 클릭)에서는 포커스가 유지됐다. 사라지더라도 Tab 1회로
  즉시 상단바에 다시 잡히므로(`_unhandled_input`) 키보드 조작이 막히는 상태는 만들어지지 않는다.
  **LOW / 관찰**.
- **L7** `arena_half_extents` 기본값 3.95 는 실측 3.9598 보다 0.0098 m 작다. 안전 측이라 무해.

---

## 5. 산출물

QA 가 이번에 추가한 것 (tests/ 하위만)
- `tests/qa_f5_topdown.gd` / `.tscn` — 직교 top-down 촬영 하네스. 자기 카메라를 붙이고 HUD 를
  숨겨 footprint 를 그대로 본다. 큰 ㅁ / 일반 자모 / 강제 ×4 스케일 3케이스.

증거 (`tests/qa_artifacts/f5/`)
- 신규: `topdown_big_mieum_{0,700,1400,final}.png`, `topdown_normal_{0,700,1400,final}.png`,
  `topdown_scale4_{0,700,1400,final}.png`
- 재생성: `qa_f5_tree.json`, `qa_f5_arena.json`, `arena_*.png`, `tree_*.png`
- 수정 전 비교본: `before_fix/` (DEV 가 남긴 것, 그대로 유지)
- 이 문서: `QA_REPORT_2.md`

---

## 6. 임시 변경 / 원복

**프로덕션 파일 변경 0건.** `git status` 상 QA 가 추가한 것은 `tests/qa_f5_topdown.gd|tscn` 과
`tests/qa_artifacts/f5/` 산출물뿐이다.

- `arena_margin` A/B(절차 20)는 실행 중 개체의 **메모리 값**만 덮어썼다 → `.tres` 무변경, 원복 불필요.
- `visual_scale ×4`(태스크 5)도 실행 중 `VisualRoot.scale` 만 바꿨다 → 파일 무변경, 원복 불필요.
- `[미발견]` / overflow 확인은 하네스의 메모리 probe GameDatabase 로만 수행했고,
  `overflow_probe.database_restored = true` 로 원복이 자체 확인된다.
- 검증용으로 잠시 만든 일회성 스크립트(`tests/_qa_probe_arena.gd`, `tests/_qa_probe_fps.gd|tscn`)는
  **삭제 완료**. 작업 트리에 남아 있지 않다.
