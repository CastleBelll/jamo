# F8 DEV 인계문 (밸런싱 Phase 10 / S0~S6)

## 1) 변경 파일 목록

**밸런스 데이터 (.tres)**
- `resources/balance/game_balance.tres` — `gold_growth_per_day` 1.025 → 1.035
- `resources/upgrades/click_damage.tres` — Lv9 → Lv26 확장 (값·가격 전면 교체)
- `resources/upgrades/max_energy.tres` — 가격표 1/8 재척도
- `resources/upgrades/gold_bonus.tres` — 가격표 1/8 재척도
- `resources/upgrades/monster_capacity.tres` — 가격표 1/8 재척도
- `resources/upgrades/reroll.tres` — 가격표 1/8 재척도
- `resources/upgrades/critical_click.tres` — 가격표 1/8 재척도

**S0 (F7 이월)**
- `theme/jamo_theme.tres` — `SB_title_focus` 테두리색 잉크 → 크림, `expand_margin 3` 추가
- `scenes/ui/title_screen.tscn` — `OverwriteConfirm` 의 `size = Vector2i(460, 140)` 삭제
- `art/ui/title/title.png.import` / `title_bg.png.import` / `title_active_button.png.import`
  / `title_inactive_button.png.import` — `compress/mode=2`, `compress/high_quality=true`
- `art/ui/title/title_ex.png` → `art/_reference/title_ex.png` (이동, 삭제 아님)
- `art/_reference/.gdignore` — 신규 (해당 폴더를 Godot 파일시스템에서 제외)
- `art/ui/title/title_ex.png.import` — 삭제 (import 대상이 아니게 됨)

**테스트 / 하네스**
- `tests/sim_balance.gd` + `.tscn` + `.gd.uid` — 신규. Day 1~200 헤드리스 시뮬레이션
- `tests/qa_f8_focus.gd` + `.tscn` + `.gd.uid` — 신규. 포커스 대비 + 다이얼로그 크기 측정
- `tests/test_game_loop.gd` — 검증 3건 추가, 가격 하드코딩 3곳 제거

**문서 / 산출물**
- `docs/BALANCE_NOTES.md` — 신규. 조정/미조정 근거 전문
- `docs/DEV_ROADMAP.md` — F8 S0~S6 체크 및 결과 요약 (QA 확인 항목은 미체크)
- `tests/qa_artifacts/f8/sim_metrics.json`, `sim_report.md`, `focus_on_*.png`,
  `focus_off_*.png`, `overwrite_dialog_1280x720.png` — 신규 산출물

**원본 무수정:** `art/ui/title/*.png` 4장, `art/_reference/title_ex.png`.

---

## 2) 검수 절차

밸런스는 수치 판정이므로 **재현 명령과 기대 범위**를 함께 적는다.
모든 시뮬레이션은 seed `20260910` 고정이라 같은 `.tres` 면 같은 숫자가 나온다.

### A. 정적 로드

1. `godot --headless --path . --quit`
   → 기대: `NotoSansKR-Regular.ttf` 누락 2건 **외에 에러 0**. (폰트는 사전 존재 이슈)

### B. 기존 자동 테스트 (전부 통과해야 함)

2. `godot --headless --path . res://tests/test_game_loop.tscn`
   → 기대: `OK - all game loop checks passed.`
3. `godot --headless --path . res://tests/test_day_flow.tscn`
   → 기대: `OK - day flow reached Day 2.`
4. `godot --headless --path . res://tests/qa_f7_title.tscn`
   → 기대: `OK - title screen checks passed.` / `keyboard reachable: NewGameButton,
     SettingsButton, QuitButton` (ContinueButton 없음)

### C. Day 1~200 시뮬레이션 (S1~S5 근거)

5. `godot --headless --path . res://tests/sim_balance.tscn`
   → 기대: 마지막 줄 `OK - simulated Day 1..200.`, 에러 0.
   → 기대: `tests/qa_artifacts/f8/sim_metrics.json` 과 `sim_report.md` 가 갱신된다.
   → 기대: 실행 전후로 `%APPDATA%\Godot\app_userdata\JAMO\jamo_save.json` 이 **생기지도
     사라지지도 않는다** (하네스가 실행 중에만 옆으로 치웠다가 되돌린다).

6. 출력된 표에서 아래 값을 확인한다. **기대 범위 (±5 % 이내)**:

   | 항목 | 기대값 |
   |---|---|
   | Day 10 Gold/Day | 72 (범위 68~76) |
   | Day 25 Gold/Day | 173 (범위 164~182) |
   | Day 50 Gold/Day | 680 (범위 646~714) |
   | Day 100 Gold/Day | 3,568 (범위 3,390~3,746) |
   | Day 200 Gold/Day | 54,144 (범위 51,437~56,851) |
   | Day 200 Kills | 18 (17~19) |
   | Day 길이 | 22.8 ~ 39.3 초 (전 구간) |
   | 가장 긴 무구매 구간 | **16 일** (반드시 20 일 이하) |
   | 단어 10개 완성 Day | 마지막 단어 `체력` Day 42 (40~45) |
   | 놓친 특수/황금 | **0 마리** |
   | 특수+황금 킬 비중 | 6.32 % (5~8 %) |

   판정 기준: 무구매 최장 구간이 20 일을 넘거나 Day 200 Gold/Day 가 0 이면 **FAIL**.

7. `sim_report.md` 의 `Upgrade purchase interval` 표에서
   → 기대: 6개 트랙 **전부 구매 횟수 > 0**, `클릭 피해` 25회, `최대 에너지` 10회,
     `치명 클릭` 5회, `골드 획득량` 10회, `동시 몬스터 수` 6회, `리롤` 3회.

### D. S0-1 포커스 대비 + S0-4 다이얼로그 (창 모드, `--headless` 아님)

8. `godot --path . res://tests/qa_f8_focus.tscn`
   → 기대: `--- 1280x720 changed=2960 median=15.32:1 above_3.0=2936 (99.2%)`
   → 기대: 1920x1080 / 2560x1080 도 median 15:1 대, 3:1 이상 비율 99 % 이상
   → 기대: `--- overwrite dialog size=(622, 104) contents_minimum=(622.0, 104.0)`
   → 기대: 마지막 줄 `OK - focus indicator meets 3.0:1 and the dialog fits its contents.`
   → 판정 기준: median 이 **3.00:1 미만이면 FAIL** (WCAG 2.2 SC 2.4.11).

9. `tests/qa_artifacts/f8/focus_on_1280x720.png` 과 `focus_off_1280x720.png` 를
   나란히 열어 본다.
   → 기대: `새 게임` 붓자국 **바깥쪽**으로 크림색 테두리가 한 겹 보이고, off 프레임에는
     없다. 테두리가 붓자국 위에 겹치거나 허공에 떠 있지 않다. 버튼 위치·크기 변화 없음.

### E. S0 나머지 눈 확인 (ziva-godot MCP 실제 실행)

10. 게임을 띄우고 타이틀에서 방향키로 `새 게임 → 이어하기 → 설정 → 종료` 를 순회한다.
    → 기대: 포커스가 옮겨갈 때마다 크림 테두리가 따라다니고, 4개 버튼 위치가 흔들리지 않는다.
11. 세이브가 있는 상태에서 `새 게임` → Enter.
    → 기대: 덮어쓰기 확인 창이 뜨고 **본문 한 줄이 잘리지 않는다**. 기본 포커스는 `취소`.
      Enter 한 번에 취소되어 타이틀로 돌아오고 진행이 유지된다.
12. 타이틀·일시정지 메뉴·단어 트리를 눈으로 본다.
    → 기대: 타이틀 로고/배경/버튼 붓자국에 압축 아티팩트(계단·색 번짐)가 보이지 않는다.
      인게임 버튼(잉크 테두리)의 포커스 표시는 이전과 동일하다 — `SB_btn_focus` 는 안 건드렸다.
13. 파일 확인: `art/_reference/title_ex.png` 가 **존재**하고 `art/ui/title/title_ex.png` 는
    없다. Godot 에디터 FileSystem 독에 `art/_reference/` 폴더가 **보이지 않는다**.

### F. 에디터 가시성 (v0.3 §37)

14. Godot 에디터에서 `resources/upgrades/click_damage.tres` 를 연다.
    → 기대: Inspector 의 `costs` 26개 / `values` 26개, 마지막 값 3607 / 1650000.
15. `resources/balance/game_balance.tres` 를 연다.
    → 기대: `Monster Scaling` 그룹에 `Gold Growth Per Day = 1.035`, `Hp Growth Per Day = 1.035`.
    → 기대: `Special Monsters` 그룹의 두 확률이 **0.02 그대로**.

### G. 회귀

16. Day 1 → Day 2 기본 루프 (클릭 → 에너지 0 → 요약 → 자모 선택 → 상점 → Day 2).
    → 기대: 정상 진행. 상점 첫 화면에서 `최대 에너지 6 G`, `클릭 피해 12 G`,
      `골드 획득량 12 G`, `동시 몬스터 수 25 G` 로 보인다 (가격이 내려간 것이 화면에 반영).
17. Day 1 에서 20클릭을 다 쓴다.
    → 기대: 12~15 G 사이를 번다. (구조적 상한 13.3 G, `BALANCE_NOTES.md` 4-1 참조)

---

## 3) 주의/보류 사항

### 스펙과 다르게 처리한 부분

1. **문서 수치를 바꿨다.** S4 가 허용한 범위 안이지만 상위 문서에 닿는다.
   - `gold_growth_per_day` 1.025 → **1.035**. v0.3 §8.1 과 growth_balance §4 의 골드
     공식/표가 바뀐다. 근거: HP 3.5 % 복리 vs 골드 2.5 % 복리의 **1 %p 차이가 수입을
     하루 1 %씩 복리로 깎아** Day 150 부터 골드가 0 이 됐다. 가격으로는 못 고친다.
   - `클릭 피해` 트랙을 **Lv9 → Lv26** 으로 확장. growth_balance §8.1 표 교체.
     근거: Lv9(피해 10)로 Day 200 몬스터(HP 2,820)를 잡으려면 282 클릭이 필요하다.
   - 나머지 5개 트랙 **가격을 1/8** 로. 값·레벨 수·해금 Day 는 문서 그대로.
     근거: 조정 전 200일 총수입 8,631 G 인데 문서 가격표 총액이 562,250 G (65배).
   - 전부 `docs/BALANCE_NOTES.md` 3장에 유도 과정과 함께 기록했고, **v0.4 문서 개정
     항목**으로 명시해 뒀다. 문서를 직접 고치지는 않았다(범위 밖).

2. **S5 는 변경 없음이 결론이다.** 확률 2 %→4 % A/B, 황금 `hp_multiplier` 1.0→0.35
   A/B 를 둘 다 돌린 뒤 되돌렸다. 근거는 `BALANCE_NOTES.md` 5장. "조정하라"는 지시에
   변경 0 건으로 답한 것이므로 QA 가 확인해야 할 판단이다.

3. **growth_balance §3 HP 표가 식과 어긋난다** (Day 100 = 91 vs 90, Day 200 = 2,824 vs
   2,820). 오차 ≤0.15 %. **식(런타임)이 맞고 표가 반올림 오차**라고 판단해 코드는
   손대지 않았다. 정오표 대상으로만 기록했다.

### 하위 호환 위험

4. **기존 세이브는 그대로 로드된다.** 저장하는 것은 `upgrade_levels` 의 **레벨 번호**
   뿐이라 가격이 바뀌어도 깨지지 않는다. 다만 이미 `클릭 피해 Lv5` 이상인 세이브는
   피해량이 **6 → 7 로 오른다**(값 곡선이 Lv5 부터 기하급수로 바뀜). 손해가 나는 방향은
   없다. 레벨을 줄인 트랙이 없으므로 만렙 초과 상태도 생기지 않는다.
5. **F1 QA 산출물의 가격 텍스트가 낡았다.** `tests/qa_artifacts/f1/` 의 스냅샷은
   `치명 클릭 1,500 G` 시절 값이다. 게이트 **로직**은 그대로고
   `test_game_loop.gd::_test_critical_click` 이 통과한다. 필요하면 QA 가 F1 하네스를
   재실행해 갱신하면 된다. (이 파일은 건드리지 않고 원복해 뒀다.)
6. **`tests/test_game_loop.gd` 에서 가격 하드코딩 3곳을 `.tres` 읽기로 바꿨다**
   (`50G`/`49G`/`1000G`). 앞으로 가격을 다시 튜닝해도 이 테스트는 빨개지지 않는다.

### 사전 존재 이슈 (이번 사이클과 무관)

7. `NotoSansKR-Regular.ttf` 누락 에러 2건. F7 부터 있던 이슈.
8. `tests/qa_shop_gate.tscn`, `qa_critical_play.tscn` 등 F1~F6 QA 하네스는
   `await RenderingServer.frame_post_draw` 를 쓰므로 **`--headless` 로 돌리면 멈춘다.**
   각 파일 헤더에 `godot --path .` (창 모드)라고 적혀 있다. 내 변경 때문이 아니다.
9. `art/Untitled.blend`, `tests/qa_f7_live.gd.uid` 가 untracked 로 남아 있다. 내가 만든
   것이 아니다.

### 다음 사이클로 미룬 것 (근거는 BALANCE_NOTES 7장)

10. **화상(DoT)이 Day 20 이후 죽은 기능이 됐다.** 누적 피해의 0.4 %, 200일 동안 화상
    킬 2마리. `WordEffectData.base_value` 가 고정 피해라 HP 복리를 못 따라간다.
    최대 HP 비율 틱으로 바꾸는 것이 정석이지만 **효과 타입 변경 = 시스템 변경**이라
    이번 금지 범위다. **현재 `불` 계열 전체가 함정 선택지다.**
11. **Day 42 이후 자모 후보가 0 개다.** 단어 10개를 다 만들면 `filler_jamo` 가 빈
    배열이라 후보 풀이 비고, 하루 종료 화면이 158 일 동안 아무것도 주지 않는다.
    단어 DB 확대나 `filler_jamo` 채우기가 필요하다. 새 단어 추가는 금지 범위.
12. **Day 194 에 전 트랙 만렙**이 되어 이후엔 살 것이 없다. Day 201+ 무한 성장 구간에는
    프레스티지/무한 레벨이 필요하다.
13. **Day 100 수입이 문서 목표 하한의 71 %** 다. 클릭/킬이 이미 1.03(한 방)이고
    에너지·수용량도 §19 상한에 닿아 **남은 레버가 없다.** Phase 8 자동화가 들어와야 닫힌다.
14. **Day 1~5 수입이 문서 목표의 절반**이다. HP 3 / 피해 1 / 에너지 20 / 골드 2G 가 전부
    v0.3 확정값이라 상한이 13.3 G 다. growth_balance §5 의 "25~40 G" 와 "1~2 클릭 처치"가
    같은 문서 §2 와 모순이다. 문서 정정 대상으로만 기록했다.
15. **v0.3 §34 의 `Automation share` / `Candidate frustration` 은 수집하지 않았다.**
    자동화는 미구현, frustration 은 후보가 항상 유용해 사건이 발생하지 않는다.
16. **하네스의 `SECONDS_PER_CLICK = 1.1` 은 창작 상수다.** "Day length" 초 단위 수치는
    전부 여기에 비례하므로 절대값이 아니라 상대 비교로만 읽어야 한다.
