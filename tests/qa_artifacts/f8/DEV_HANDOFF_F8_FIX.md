# F8 DEV 인계문 (2차) — QA FAIL 수정

대상: F8 QA 리포트의 **F-1 (CRITICAL)** 과 조건 **C-1 / C-2 / C-3**.
밸런스 수치는 하나도 건드리지 않았다. `gold_growth_per_day` 는 총지휘자 승인대로 **1.035 유지**.

---

## 1) 변경 파일 목록

**신규**
- `art/ui/focus_ring.png` — 32×32 RGBA 9-patch 링. 바깥 검정(`#000000`) 2 px + 안쪽 흰색(`#FFFFFF`) 4 px,
  corner radius 7, 가운데는 완전 투명. 무손실 임포트(`compress/mode=0`, 밉맵 없음)
- `art/ui/focus_ring.png.import` — Godot 자동 생성
- `tests/qa_artifacts/f8/DEV_HANDOFF_F8_FIX.md` — 이 문서

**수정**
- `theme/jamo_theme.tres`
  - `SB_title_focus` 를 `StyleBoxFlat` → **`StyleBoxTexture`** 로 교체
    (`texture = art/ui/focus_ring.png`, `texture_margin 12`, `expand_margin 6`,
    `content_margin` 16/9/16/9 는 그대로 유지 — 버튼 크기·위치 불변)
  - 파일 상단에 `[ext_resource]` 1 줄 추가
  - 그 외 스타일박스는 무수정
- `tests/test_game_loop.gd` — `_test_day_200_curve_comes_from_the_balance_resource()` 에
  골드 리터럴 앵커 2 개 추가 / `_test_tuned_values_come_from_resources()` 의 잘못된 인과 주석 정정
- `docs/BALANCE_NOTES.md` — 3-1 근거 전면 재작성, 8 장 이월 1 번 기록 갱신 + 8-1 재측정 표 신설
- `docs/DEV_ROADMAP.md` — S0 포커스 항목 표기 정정, **F8 후속(v0.4 기준 문서 개정)** 절 신설

**무수정 확인**: `resources/**` 전부, `scenes/ui/title_screen.tscn`,
`tests/qa_f8_focus_all.gd`(QA 하네스 원본 그대로), 타이틀 원본 `.png` 4 장,
`docs/JAMO_total_project_development_plan_v0.3.md`, `docs/hangul_idle_growth_balance_v0.2.md`.

---

## 2) 검수 절차

### A. 정적 로드

1. `godot --headless --path . --quit`
   → 기대: `NotoSansKR-Regular.ttf` 누락 2 건 **외에 에러 0**, exit 0.
     (테마가 새 `ext_resource` 를 물고도 파싱 에러가 없어야 한다는 뜻이다)

### B. 자동 테스트 4 종 (전부 통과해야 함)

2. `godot --headless --path . res://tests/test_game_loop.tscn`
   → 기대: `OK - all game loop checks passed.`
3. `godot --headless --path . res://tests/test_day_flow.tscn`
   → 기대: `OK - day flow reached Day 2.`
4. `godot --headless --path . res://tests/qa_f7_title.tscn`
   → 기대: `OK - title screen checks passed.` /
     `keyboard reachable: NewGameButton, SettingsButton, QuitButton`
5. `godot --headless --path . res://tests/sim_balance.tscn`
   → 기대: `OK - simulated Day 1..200.`
     `sim_report.md` 는 F8 1 차와 **바이트 단위로 동일**해야 한다 (밸런스 무변경 증거).
     md5 `2a494b8e…` 유지 확인.

### C. 【핵심】 포커스 대비 — 4 개 버튼 전부 측정

6. `godot --path . res://tests/qa_f8_focus_all.tscn` (**창 모드, `--headless` 아님**)
   → 기대 출력: 마지막 줄 `OK - focus indicator meets 3.0:1 and the dialog fits its contents.`
   → 기대 개별값 (median, 3 해상도 × 활성 버튼 전부 **≥ 3.0:1**):

   | 해상도 | 새 게임 | 설정 | 종료 |
   |---|---:|---:|---:|
   | 1280×720 | 18.20 | 5.44 | 4.12 |
   | 1920×1080 | 12.91 | 4.02 | 3.69 |
   | 2560×1080 | 12.97 | 3.53 | **3.51** ← 최저 |

   → `--- 1280x720 ContinueButton SKIPPED (disabled)` 는 **정상**이다.
     세이브가 없으면 `scripts/ui/title_screen.gd` 가 `focus_mode = FOCUS_NONE` 으로 두므로
     포커스를 못 받는다 = SC 2.4.11 대상이 아니다.

7. **`이어하기` 까지 4 개 전부 재기 (권장)**
   a. 게임을 띄워 `새 게임` → 게임 진입 → 타이틀 복귀
      (이때 `user://jamo_save.json` 이 생긴다) → 종료
   b. 다시 `godot --path . res://tests/qa_f8_focus_all.tscn`
   → 기대: `ContinueButton` 이 SKIPPED 되지 않고 median **9~11:1** 대로 찍힌다.
     (DEV 실측: 1280×720 11.24 / 1920×1080 9.27 / 2560×1080 10.82)

8. **추가 해상도까지 보고 싶으면** `tests/qa_f8_focus_all.gd` 의 `SIZES` 에
   `Vector2i(1024, 600)`, `Vector2i(1600, 900)`, `Vector2i(3840, 2160)` 을 임시로 더한다.
   → DEV 실측 최저값: 1024×600 종료 3.70 / 1600×900 종료 3.62 / 3840×2160 종료 3.72.
     **6 해상도 × 4 버튼 24 조합 전부 ≥ 3.51:1.** 전체 표는 `docs/BALANCE_NOTES.md` 8-1.

### D. 육안

9. 6 번이 남긴 `tests/qa_artifacts/f8/variants/on_QuitButton_1280x720.png` 와
   `off_QuitButton_1280x720.png` 를 나란히 본다.
   → 기대: on 프레임에만 버튼 붓자국 **바깥**에 흰 띠 + 그 바깥 검은 띠가 한 겹씩.
     붓자국 자체·글자·버튼 크기/위치는 두 프레임이 동일.
     (1 차 크림 단색과 달리 밝은 나무 바닥 위에서도 링이 묻히지 않는다)
10. `on_NewGameButton_1280x720.png` — 어두운 문간 위에서도 같은 링이 보인다.
    검은 띠는 배경에 묻히지만 흰 띠가 살아 있다. 이것이 2 색으로 만든 이유다.

### E. 문서

11. `docs/BALANCE_NOTES.md` 3-1
    → 기대: ① 붕괴의 **직접 원인 = 클릭 피해 Lv9 상한**이라고 적혀 있다
      ② QA 반례 표(골드 1.025 복귀 시 Day 200 **3,921 G/일**)가 실려 있다
      ③ "가격 곡선으로는 못 고친다" 는 초판 주장을 **틀렸다고 명시**한다
      ④ §42 이중 확정 주장과 56 HP 계산이 **정정**돼 있다 (§42-4 는 Day 1 2G 만 고정 / 2.5 % 면 408 HP)
      ⑤ **v0.3 §8.1 과 충돌**한다는 사실과 **§41 우선순위상 1 순위를 2 순위에 맞춘 선택**이라는
        점이 숨김 없이 적혀 있다
      ⑥ growth_balance §5 를 **정본**으로, §4 표를 정오표 대상으로 삼았다고 명시돼 있다
12. `docs/DEV_ROADMAP.md` → `### F8 후속 — 기준 문서 개정 (v0.4 …)` 절에 v0.3 §8.1 개정이
    미체크 항목으로 올라와 있다. **v0.3 문서 자체는 무수정**(`git status` 에 안 뜬다).
13. `tests/test_game_loop.gd` 에서 `gold_growth_per_day, 1.035` 와 `gold_200, 1880.0076`
    두 리터럴 앵커 확인.
    → **역검증**: `resources/balance/game_balance.tres` 의 `gold_growth_per_day` 를 1.025 로
      임시로 바꾸고 2 번을 다시 돌리면 `FAILED` 가 떠야 한다. 확인 후 반드시 되돌릴 것.

---

## 3) 주의 / 보류 사항

- **`SB_title_focus` 만 텍스처 스타일박스다.** `SB_btn_focus`(게임 화면 버튼) ·
  `SB_slot_focus`(단어 트리) · `SB_icon_focus` 는 손대지 않았다. 그쪽은 배경이 자체 패널이라
  단색 테두리로도 대비가 나온다. **타이틀만 사진 배경 위에 버튼이 놓여 있는 특수 상황**이다.
  다른 화면에 사진 배경을 깔면 같은 문제가 재발하므로 그때 같은 링을 재사용하면 된다.
- **흰색을 썼다.** 1 차의 크림(`#F2E6CE`)으로는 밝은 나무 바닥 위 median 이 3.31:1 까지밖에
  안 올라갔다. 순백으로 올려 최저 3.51:1 을 확보했다. 링은 붓자국 **바깥**에만 그려지므로
  아트 자체의 색감에는 닿지 않는다. 팔레트상 따뜻한 크림이 꼭 필요하다는 판단이 서면
  `art/ui/focus_ring.png` 의 안쪽 4 px 만 바꾸면 되고, 그때 최저값이 3.31:1 로 내려간다.
- **`focus_ring.png` 은 생성 스크립트를 리포에 남기지 않았다.** 파라미터(32×32 / radius 7 /
  검정 2 px + 흰색 4 px / 가운데 투명)를 `BALANCE_NOTES` 8 장에 적어 뒀다. 다시 만들 일이
  생기면 그 값으로 그리면 된다.
- **중앙 채우기 함정.** `StyleBoxFlat` 의 `shadow_color`/`shadow_size` 로 2 색을 흉내내면
  Godot 이 그림자를 **버튼 안쪽까지 채워** 붓자국 아트를 통째로 덮는다 (실측 확인함).
  9-patch 로 간 이유다. 나중에 "그림자로 하면 더 간단한데" 라는 제안이 나오면 이 문단을 볼 것.
- **`이어하기` 는 기본 상태에서 측정 불가.** 세이브가 없으면 포커스를 못 받는 것이 사양이다.
  자동 하네스가 SKIPPED 로 넘기므로, 회귀 방지 관점에서는 4 개 중 3 개만 상시 감시된다.
  QA 하네스를 고쳐 세이브 유무와 무관하게 4 개를 재게 만드는 건 QA 쪽 자산이라 손대지 않았다.
- **밸런스는 승인 그대로 유지.** `gold_growth_per_day = 1.035`. QA 가 반례로 든 (다) 안
  (골드 1.025 + Lv26 + 1/8 가격)은 **채택하지 않았다**. 근거는 BALANCE_NOTES 3-1 의
  구조적 상한 계산(§5 목표 50,000 G/일에 1.025 로는 도달 불가)이다.
- **v0.3 §8.1 은 여전히 코드와 어긋나 있다.** 개정은 총지휘자·사용자 판단 사항이라
  `DEV_ROADMAP` 후속 항목으로만 올렸다. 그 전까지 리포는 "코드가 1 순위 문서를 앞서간 상태"다.
- `sim_balance` 실행 전후로 `user://jamo_save.json` 은 생성·수정되지 않는다 (기존과 동일).
  단 위 검수 7-a 를 수행하면 세이브가 생긴다. 이후 다른 QA 항목에 영향이 없는지 유의할 것.
