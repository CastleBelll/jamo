# F5 QA FAIL 수정 — DEV 인계문 (2차)

대상: `F5-QA-1` (키보드로 트리를 열 수 없음), `F5-QA-2` (큰 ㅁ 아레나 이탈). 브랜치 `main`.
이 두 건 외 변경 없음.

---

## 1) 변경 파일 목록

### 수정
- `theme/jamo_theme.tres` — `HudIconButton` theme type variation 신규
  (`base_type = Button`, normal / hover / pressed / **focus** 4종 StyleBoxFlat).
  포커스는 3px 크림색(0.949, 0.902, 0.808) 테두리 + 반투명 진갈색 바탕.
- `scenes/ui/hud.tscn` — 상단바 3버튼(`DictionaryButton` / `SettingsButton` / `PauseButton`)을
  `TextureButton` → `Button` 으로 교체. `focus_mode = 2`(ALL),
  `theme_type_variation = &"HudIconButton"`, `icon` + `expand_icon`.
  노드 이름·`unique_name_in_owner`·툴팁·48×48 최소 크기는 그대로다.
- `scripts/ui/hud.gd` — `focus_first_button()` public 추가,
  `_unhandled_input()` 에서 "포커스 오너가 없을 때 Tab" 을 잡아 상단바로 포커스를 준다.
- `scripts/main.gd` — `WordTree.closed` → `HUD.focus_first_button` 연결(트리를 닫으면 포커스가
  책 버튼으로 돌아온다).
- `scripts/monsters/jamo_monster.gd` — 몸통 footprint 실측(`_collect_body_meshes()`,
  `_measure_body()`, `get_body_half_extents()`), `get_walkable_half_extents()` 가
  슬래브에서 몸통 크기를 빼도록 변경, `arena_half_extents` 기본값 3.4 → 3.95,
  `_process()` 에서 재클램프.
- `scenes/monsters/jamo_monster_base.tscn` — 루트에 `process_priority = 1`
  (AnimationPlayer 가 포즈를 잡은 뒤에 클램프가 돌게 하는 실행 순서).
- `scripts/monsters/spawn_manager.gd` — `arena_half_extents` 기본값 3.4 → 3.95 + 주석.
- `scenes/world/game_world.tscn` — `SpawnManager.arena_half_extents = (3.95, 3.95)`.
- `scripts/data/jamo_monster_data.gd` — `arena_margin` 기본값 0.35 → **0.0**, 의미 변경
  (몸통 크기는 자동 계산되므로 이 값은 "추가 여백" 전용).
- `resources/monsters/big_mieum.tres` — `arena_margin = 0.55` 제거(0.0). 더 이상 필요 없다.
- `tests/test_game_loop.gd` — 검증 2종 추가(아래 3-I, 실행 시간 주의).
- `tests/qa_f5_arena.gd`, `tests/qa_f5_margin_ab.gd` — **QA 하네스의 이탈 측정식 수정**.
  자세한 이유는 3) 주의사항 A.

### 신규
- `tests/qa_artifacts/f5/before_fix/` — 수정 전 QA 증거(PNG/JSON) 백업. 하네스를 다시
  돌리면 원본이 덮어써지므로 미리 복사해 뒀다.
- `tests/qa_artifacts/f5/DEV_HANDOFF_FIX.md` (이 문서)

---

## 2) 검수 절차

전제: `godot --path . scenes/main/main.tscn` (또는 ziva-godot MCP `run_scene`).
세이브를 지우고 Day 1 부터.

### A. 정적 / 자동
1. `godot --headless --path . --quit`
   → 기대: `NotoSansKR-Regular.ttf` 폰트 누락 에러 2줄만. 그 외 에러 0.
2. `godot --headless --path . tests/test_game_loop.tscn` (약 30초 걸린다)
   → 기대: `OK - all game loop checks passed.`
3. `godot --headless --path . tests/test_day_flow.tscn`
   → 기대: `OK - day flow reached Day 2.`

### B. F5-QA-1 — 마우스 없이 트리를 열고 닫는다
4. Day 1 화면에서 마우스를 **한 번도 쓰지 않고** Tab 을 1회 누른다.
   → 기대: 우측 상단 **책 아이콘 둘레에 굵은 크림색 사각 테두리**가 나타난다
     (진갈색 반투명 바탕 위). 어두운 배경과 대비가 확실해 눈에 바로 띈다.
5. Tab 을 한 번 더 누른다. 또 한 번 누른다.
   → 기대: 포커스가 **책 → 설정(톱니) → 일시정지(‖)** 순으로 왼쪽에서 오른쪽으로 옮겨간다.
     테두리도 같이 옮겨간다. 순서가 상단바 배치와 같다.
6. Shift+Tab 을 누른다.
   → 기대: 역순으로 되돌아간다.
7. 포커스를 **책 아이콘**에 두고 Enter(또는 Space)를 누른다.
   → 기대: `단어 트리` 패널이 열린다. 첫 슬롯에 포커스가 잡혀 있다(기존 동작).
8. 트리 안에서 Tab 으로 `닫기` 까지 가서 Enter 를 누른다.
   → 기대: 트리가 닫히고 **포커스가 책 아이콘으로 되돌아온다**(테두리가 다시 책에 보인다).
     Tab 을 더 누르지 않아도 바로 설정/일시정지로 이어갈 수 있다.
9. 화면 아무 데나(몬스터가 아닌 빈 곳) 마우스로 클릭해 포커스를 흘린 뒤 Tab 을 1회 누른다.
   → 기대: 다시 책 아이콘에 포커스가 잡힌다. "Tab 을 눌러도 아무 데도 포커스가 안 잡히는"
     상태가 재현되지 않는다.
10. 포커스가 잡힌 상태로 몬스터를 마우스로 20번 클릭해 에너지를 소진한다.
    → 기대: 클릭·처치·에너지 소모가 평소와 똑같다. 포커스 테두리는 그대로 남아 있고
      몬스터 클릭을 전혀 방해하지 않는다.
11. 상단바 3버튼을 마우스로 hover / 클릭해 본다.
    → 기대: hover 시 옅은 크림색 바탕, 누르는 동안 조금 더 진한 바탕이 보인다.
      아이콘 그림 자체는 이전과 같다(책/톱니/‖).
12. QA 하네스: `godot --path . tests/qa_f5_tree.tscn` 실행 후
    `tests/qa_artifacts/f5/qa_f5_tree.json` 의 `keyboard_open` 을 연다.
    → 기대: `"tree_opened_after_tabs": 1`, `tab_focus_chain` 의 첫 항목이
      `.../HUD/TopBar/Buttons/DictionaryButton`, `"tree_visible": true`.
      (수정 전에는 전부 `(none)`, `-1` 이었다.)

### C. F5-QA-2 — 어떤 크기의 개체도 슬래브를 넘지 않는다
13. `godot --path . tests/qa_f5_arena.tscn` (몇 분 걸린다) 실행 후
    `tests/qa_artifacts/f5/qa_f5_arena.json` 을 연다.
    → 기대: `big_mieum` / `normal_jamo` / `mixed` 세 항목 모두
      `"worst_body_overhang_m": 0.0`, `"offenders": {}`,
      `"peak_monster_count": 20`. `worst_case_corner.body_overhang_m` 도 `0.0`.
      **이탈 프레임 비율 0%.**
14. 같은 JSON 의 `slab_rotation_y_rad` 를 본다.
    → 기대: `0.7854`. 슬래브가 45도 돌아 있다는 사실이 리포트에 남는다(3-A 참조).
15. `godot --path . tests/qa_f5_margin_ab.tscn` 실행.
    → 기대: 두 줄 모두 `worst_overhang=0.000 over_ratio=0.000`.
      `margin=0.00` 에서도 0 이다 — 이제 이탈을 막는 것은 margin 이 아니라 몸통 실측이다.
16. `tests/qa_artifacts/f5/arena_big_mieum_1400.png` 과 `arena_big_mieum_final.png` 을 본다.
    → 기대: 큰 ㅁ 20마리가 밀집해도 **몸통과 그림자가 모두 종이 판 안**에 있다.
      판 가장자리를 넘는 개체가 없다.
17. `tests/qa_artifacts/f5/arena_normal_jamo_final.png` 을 본다.
    → 기대: 일반 자모 20마리가 여전히 판 **전체에 넓게** 퍼진다. 가운데로 뭉치지 않는다.
      (JSON `normal_jamo.furthest_centre_from_origin_m` ≈ 2.96 로, 수정 전 3.05 와 거의 같다.)
18. 게임에서 상점 `동시 등장` 을 최대로 올리고 큰 ㅁ 가 섞인 밀집 상태를 30초 이상 눈으로 본다.
    → 기대: 어느 순간에도 글자 몸통이 판 밖으로 튀어나오지 않는다.
19. Godot Editor 에서 `resources/monsters/big_mieum.tres` 를 선택한다.
    → 기대: Inspector `Movement` 그룹에 `Arena Margin` 이 보이고 값은 **0.0**,
      슬라이더로 조절 가능하다. 다른 자모도 기본 0.0.
20. `Arena Margin` 을 0.0 → 1.0 으로 올리고 게임을 실행한다.
    → 기대: 큰 ㅁ 가 판 안쪽으로 더 들어와 돈다(여백 조절이 실제로 먹힌다).
      **확인 후 0.0 으로 되돌릴 것.**
21. `scenes/world/game_world.tscn` 의 `SpawnManager` 를 선택한다.
    → 기대: `Field > Arena Half Extents` 가 **(3.95, 3.95)** 이고 씬에서 조절 가능하다.
      주석에 "슬래브 자체의 half-diagonal(2.8 × √2)" 이라고 적혀 있다.
22. `scenes/monsters/jamo_monster_base.tscn` 을 Editor 로 연다.
    → 기대: 루트 `JamoMonster` 의 `Process Priority` 가 `1` 이다. 구성 경고 0.

### D. 회귀
23. Day 1 → Day 2 루프를 한 바퀴 돈다(클릭 → 에너지 0 → Day End → 자모 선택 →
    (리롤) → 상점 → 다음 Day).
    → 기대: F1~F5 동작 그대로. 트리/Target/HUD 하단 `TARGET:` 줄 모두 정상.
24. 트리를 열어 목표를 지정/해제하고, 마우스 클릭과 키보드 Enter 양쪽으로 해 본다.
    → 기대: 이전 QA 에서 PASS 였던 12~19번, 23~26번 동작이 그대로다.

---

## 3) 주의 / 보류 사항

### A. QA 하네스의 이탈 측정식을 고쳤다 (중요 — 먼저 읽을 것)
- QA 리포트의 원인 분석 중 **"슬래브는 축정렬 정사각형이고 `game_world.tscn` 의 Arena 에는
  회전이 없다"** 는 부분은 사실과 다르다. `scenes/world/arena.tscn` 의 **루트 노드 `Arena`
  자체에 `rotation = Vector3(0, 0.7854, 0)`** 이 걸려 있고, `game_world.tscn` 은 이를
  오버라이드하지 않으므로 인스턴스에도 그대로 적용된다.
  실측: `PaperTop` 의 월드 AABB 는 `(-3.9598 … 3.9598)`, `Arena.global_rotation.y = 0.7854`.
  카메라에는 yaw 가 없으므로 화면의 마름모는 카메라 때문이 아니라 **판이 실제로 45도 돌아
  있기 때문**이다.
- 그래서 `qa_f5_arena.gd` / `qa_f5_margin_ab.gd` 의 `SLAB_HALF = 2.8` 축정렬 비교는
  잘못된 기준이었다. x = 2.85 에 선 개체를 "0.05 이탈" 로 셌지만 그 지점은 실제 판 안이고,
  반대로 대각선 방향의 진짜 이탈은 과소평가했다. QA 가 적은 수치(0.61 / 0.70 m)는
  이 잘못된 기준에서 나온 값이다.
- **이탈 자체는 실재했다.** 올바른 기준(슬래브 로컬 프레임)으로 재보면 수정 전 이탈은
  giyeok 0.620 / digeut 0.717 / mieum 0.647 / **big_mieum 0.922** m 였다.
  QA 의 판정(FAIL)은 맞고, 원인 설명과 수치만 어긋나 있었다.
- 두 하네스의 `_overhang` / `_body_overhang` 을 **AABB 8개 꼭짓점을 슬래브 로컬 프레임으로
  옮겨 `|x| ≤ 2.8`, `|z| ≤ 2.8` 로 검사**하도록 고쳤다. (회전 프레임에서 박스를 통째로
  다시 바운딩하면 부풀어서 없는 이탈을 만들어내므로 꼭짓점 단위로 옮긴다.)
  `qa_f5_arena.json` 에 `slab_rotation_y_rad` 를 추가해 이 가정이 리포트에 남게 했다.
- QA 규칙상 DEV 가 테스트 파일을 고치는 건 예외적이지만, **틀린 기준으로는 "이탈 0%" 를
  만들 수 없다**(판 안에 있어도 이탈로 셈). 이 부분은 특히 다시 봐 주기 바란다.

### B. 원인과 수정 방식
- 진짜 원인은 "마름모 vs 정사각형" 이 아니라 **걷기 영역이 몬스터 몸통 크기를 전혀 고려하지
  않은 것**이다. 걷기 다이아몬드(월드 `|x| + |z| ≤ h`)와 슬래브 다이아몬드(`≤ 3.9598`)는
  같은 모양이지만, 축정렬 몸통이 중심에서 `halfX + halfZ` 만큼 그 합을 더 밀어 올린다.
  `arena_margin` 0.55 는 큰 ㅁ 의 몸통(합 1.52 m)을 덮기에 턱없이 작았다.
- 수정: `arena_half_extents` 를 **슬래브 실제 치수(3.95 ≈ 2.8 × √2)** 로 되돌리고,
  걷기 영역 = 슬래브 − (몸통 halfX + halfZ) − `arena_margin` 으로 정의했다.
  몸통 크기는 `.gd` 상수가 아니라 **VisualRoot 아래 MeshInstance3D 의 실제 AABB 를 매 프레임
  실측**해 얻는다. 그래서 `visual_scale` 을 얼마로 바꾸든, 새 자모를 추가하든 자동으로 맞는다.
  `tests/test_game_loop.gd` 가 `visual_scale = 5.0` 짜리 과장 개체까지 검증한다.
- `arena_margin` 은 남겨 뒀지만 **의미가 바뀌었다**: 몸통 보정이 아니라 "추가 여백" 이다.
  기본값 0.0, big_mieum 도 0.0. 미관상 더 안쪽으로 돌리고 싶을 때만 올린다.

### C. 실행 순서 때문에 `_process()` 클램프를 추가했다
- AnimationPlayer 는 기본이 idle(프레임) 콜백이라 **물리 프레임의 클램프가 끝난 뒤에** 글자
  포즈를 바꾼다. 그래서 물리에서만 클램프하면 "이번 프레임에 몸이 더 넓어진" 순간이
  한 프레임 동안 판 밖으로 그려졌다(실측 잔여 이탈 0.163 m).
- `JamoMonster._process()` 에서 한 번 더 클램프하고, `jamo_monster_base.tscn` 루트에
  `process_priority = 1` 을 줘서 자식 AnimationPlayer 보다 **나중에** 돌게 했다.
  이 두 가지를 넣은 뒤 이탈이 0.000 이 됐다.
- 비용: 개체당 메시 2~4개의 AABB 변환이 프레임당 1회. 20마리 기준 무시할 수준이며
  메시 목록은 `_ready` 에서 한 번만 수집해 캐시한다.

### D. 일반 자모 이동 범위 영향 (부작용 확인)
- 걷기 반경(월드 원점 기준 실측 최대 도달거리): 수정 전 3.05 m → 수정 후 **2.96 m**.
  거의 차이가 없고, `siot` / `i` 처럼 얇은 글자는 오히려 이전보다 넓어졌다
  (몸통이 작아 inset 이 작다). `arena_normal_jamo_final.png` 에서 20마리가 판 전체에
  퍼져 있는 것을 눈으로 확인했다.
- 큰 ㅁ 는 2.84 → 2.62 m 로 줄었다. 몸통이 크니 당연한 값이고, 이게 이탈이 사라진 이유다.

### E. TextureButton → Button 으로 바꾼 이유
- Godot 4 의 `TextureButton` 에는 **stylebox theme item 이 아예 없다**. `texture_focused`
  이미지를 새로 만들어 넣는 방법뿐인데, 지시가 "포커스 표시는 테마로 처리, 코드로 스타일 생성
  금지" 였으므로 테마 stylebox 를 쓸 수 있는 `Button` + `icon` 으로 바꿨다.
- 노드 **이름·`unique_name_in_owner`·툴팁·크기**를 유지했으므로 `hud.gd` 의 `%DictionaryButton`
  등 기존 참조와 QA 하네스 경로는 그대로 동작한다. 아이콘 그림도 동일하다.
- 시각 변화: hover / pressed 에 옅은 배경이 생겼다(이전에는 아무 피드백이 없었다).

### F. 시작 시 포커스를 자동으로 잡지는 않는다
- 게임을 켜자마자 포커스 테두리가 보이면 마우스 사용자에게는 군더더기라, **첫 Tab 을 눌렀을 때**
  상단바로 포커스를 준다(데스크톱 앱의 일반적 동작). `hud.gd._unhandled_input()` 이
  "포커스 오너가 없을 때의 Tab / Shift+Tab" 만 가로챈다. 포커스가 이미 있으면 Godot 의 기본
  포커스 이동이 그대로 동작하고 이 코드는 전혀 끼어들지 않는다.
- 자동 테스트가 이 동작 자체를 검증한다(`_test_hud_buttons_take_keyboard_focus`).

### G. 이번에 손대지 않은 것 (범위 밖)
- **L1** `scripts/ui/word_tree.gd:191` 지역변수 `hidden` 이 `CanvasItem.hidden` 시그널을
  가리는 경고. 지시가 "위 2건 외 범위 변경 금지" 라 두었다. 변수명만 바꾸면 해소된다.
- **L2** `.godot/editor/editor_layout.cfg` 의 `word_dex.tscn` 잔재(에디터 캐시).
- **L3** 책 아이콘 툴팁이 여전히 `단어 도감`.
- **L4** `follow_focus` 는 현 데이터로 스크롤이 안 생겨 여전히 실측 불가.
- 힌트 업그레이드 / Focus 골드 업그레이드 트랙(이전 인계문 C·D)도 그대로 보류.

### H. QA 증거 백업
- 하네스를 다시 돌리면 `tests/qa_artifacts/f5/` 의 PNG/JSON 이 덮어써진다. 수정 전 증거를
  `tests/qa_artifacts/f5/before_fix/` 에 그대로 복사해 뒀다. 비교가 끝나면 지워도 된다.

### I. `test_game_loop` 실행 시간
- 아레나 검증이 몬스터 10 케이스 × (워밍업 300프레임 + 림 96샘플)을 실제로 돌리므로
  `test_game_loop.tscn` 이 **약 30초** 걸린다(이전엔 즉시 끝났다). 실패가 아니라 정상이다.
  워밍업은 걷기 애니메이션이 가장 넓은 포즈까지 도달하게 하려는 것이다.
