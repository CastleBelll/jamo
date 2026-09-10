# F7 QA FAIL 수정 인계문 — 포커스 트랩 / 확인 다이얼로그 대비

대상: QA_REPORT.md 의 HIGH-1, HIGH-2, MEDIUM-1, MEDIUM-2, LOW-1, LOW-2.
(참고 항목 9 "기본 Button 에 focus 스타일 없음" 은 HIGH-2 의 "확인/취소 버튼 포커스
표시가 보여야 한다" 를 만족시키려면 피할 수 없어 함께 처리했다. 아래 3) 참조.)

## 1) 변경 파일 목록

- `theme/jamo_theme.tres`
  - 신규 StyleBoxFlat 3개: `SB_btn_focus`(투명 배경 + 3px 잉크 테두리),
    `SB_dialog_panel`(양피지 배경 + 갈색 테두리), `SB_window_border`(임베드 창 테두리/제목바).
  - 신규 항목: `AcceptDialog/styles/panel`, `Window/styles/embedded_border`,
    `Window/styles/embedded_unfocused_border`, `Window/colors/title_color`,
    `Button/styles/focus`, `Button/colors/font_focus_color`.
- `scenes/ui/settings.tscn`
  - 패널 내부 6개 컨트롤(FullscreenCheck / MasterSlider / BgmSlider / SfxSlider /
    DeleteSaveButton / SettingsCloseButton)에 `focus_neighbor_*` 4방향 + `focus_next` /
    `focus_previous` 를 링(ring)으로 연결. **씬에만 기록했고 코드로 노드를 만들지 않았다.**
- `scripts/ui/settings_panel.gd`
  - `%DeleteSaveButton` 핸들러를 `_on_delete_pressed()` 로 분리 → 팝업 후 **취소**에 포커스.
  - `_delete_confirm.canceled` → `%DeleteSaveButton.grab_focus`.
  - `_on_delete_confirmed()` 가 `delete_save()` 대신 `clear_progress()` 사용.
- `scripts/ui/title_screen.gd`
  - `refresh()` 에서 `_continue_button.focus_mode` 를 `disabled` 에 맞춰 전환.
  - `_on_new_game_pressed()` 가 팝업 후 **취소**에 포커스.
  - `_overwrite_confirm.canceled` → `focus_default_button()`.
  - `_on_overwrite_confirmed()` 가 `clear_progress()` 사용.
- `autoload/save_manager.gd`
  - `clear_progress()` 추가 — 파일을 `{"save_version":1,"audio":{...}}` 로 다시 써서
    진행만 지우고 볼륨은 남긴다. `delete_save()` 는 파일 통삭제로 그대로 두고 주석만 갱신.
- `tests/qa_f7_title.gd`
  - 실제 세이브를 `user://jamo_save.json.testbak` 로 옮겨 두고 끝나면 되돌린다.
  - 검증 추가: 비활성 이어하기가 포커스 체인에 없다 / 설정 패널이 열린 동안 포커스가
    패널 밖으로 새지 않고 슬라이더 3종에 모두 도달한다.
- `tests/test_game_loop.gd`
  - `_test_new_game_keeps_the_volume_settings()` — 덮어쓰기 창이 취소에 포커스를 두는지 +
    진행 삭제 후 볼륨이 살아남는지.
  - `_test_disabled_continue_leaves_the_focus_chain()` — 비활성/활성 전환에 따라
    이어하기가 포커스 체인에서 빠지고 다시 들어오는지.

## 2) 검수 절차

사전: 세이브는 `%APPDATA%\Godot\app_userdata\JAMO\jamo_save.json`.
1~7 은 세이브가 **없는** 상태에서 시작한다(파일 삭제).

1. F5 로 실행. 화면을 보고 마우스를 건드리지 않는다.
   - 기대: 타이틀. "새 게임" 에 굵은 테두리, "이어하기" 는 회색이고 그 아래에
     "저장된 게임이 없어 이어하기를 할 수 없습니다." 가 보인다.
2. 아래 화살표를 **한 번** 누른다.
   - 기대: 포커스 테두리가 "이어하기" 를 **건너뛰고 바로 "설정"** 에 간다. (MEDIUM-1)
   - 한 번 더 누르면 "종료", 위 화살표로 되돌아온다.
3. "설정" 에 포커스를 두고 Enter → 설정 패널이 열린다.
4. **마우스를 쓰지 말고 위 화살표만 8번 이상** 반복해서 누른다. 매번 어디에
   테두리/하이라이트가 있는지 본다.
   - 기대 순환 순서: 닫기 → 효과음 슬라이더 → 음악 슬라이더 → 마스터 슬라이더 →
     전체 화면 스위치 → (다시) 닫기 → …
   - 기대: 포커스가 **패널 밖으로 절대 나가지 않는다.** 패널 뒤의 "새 게임" /
     "종료" 에 테두리가 그려지면 FAIL. (HIGH-1)
   - Tab / Shift+Tab 으로도 같은 6개 안에서만 돈다.
5. 포커스를 "효과음" 슬라이더에 두고 **왼쪽 화살표**를 여러 번 누른다.
   - 기대: 오른쪽 퍼센트 숫자가 같이 내려간다(예: 100% → 30%).
     슬라이더 손잡이(grabber)가 흰색으로 밝아져 있어 어디에 있는지 보인다.
   - 기대: 이 상태에서 Enter 를 눌러도 **게임이 시작되지 않는다.** (HIGH-1 부작용)
6. 위/아래로 "닫기" 로 이동해 Enter.
   - 기대: 패널이 닫히고 포커스가 타이틀 버튼("새 게임")으로 돌아온다.
7. 창을 닫고 다시 F5 → 설정을 연다.
   - 기대: 5에서 내린 효과음 값이 그대로다.
8. "새 게임" 으로 들어가 Day 2 까지 진행한다. ESC → "저장 후 타이틀로".
   - 기대: 타이틀에 "저장된 진행 — DAY 2 · N G" 가 보이고 "이어하기" 가 활성.
   - 기대: 이제 아래 화살표를 누르면 "이어하기" 에 **포커스가 온다**(활성이므로).
9. "새 게임" 을 눌러 확인 창을 띄운다. **여기서 대비를 측정한다.**
   - 기대: 창 본문 "저장된 진행 상황이 사라지고 DAY 1부터 다시 시작합니다.
     되돌릴 수 없습니다." 가 **양피지색 배경(#E7D7B6) 위 잉크색 글자(#33291E)** 로 읽힌다.
     실측 대비 **10.02 : 1** (WCAG AA 4.5:1 통과). 캡처에서 픽셀을 찍어 확인할 것.
   - 기대: 제목바는 갈색(#6B5B45) 배경에 크림색(#F2E6CE) 글자, 대비 **5.29 : 1**.
   - 기대: "새로 시작" / "취소" 버튼은 탄색(#C9AE7E) 배경에 잉크색 글자, 대비 **6.66 : 1**.
   - 기대: **"취소" 쪽에 3px 잉크색 포커스 테두리**가 있다(대비 6.66:1).
     "새로 시작" 에 테두리가 있으면 FAIL. (HIGH-2)
10. 아무 것도 누르지 말고 그대로 **Enter**.
    - 기대: 취소가 눌려 타이틀로 돌아온다. **게임이 시작되면 FAIL.**
    - 기대: "이어하기" 가 여전히 활성이고 DAY 표시가 그대로다.
    - 기대: 타이틀 버튼 중 하나에 포커스 테두리가 **보인다**(사라지지 않는다). (LOW-1)
11. 타이틀 → 설정 → 효과음 30%, 음악 60% 로 맞추고 닫기.
    그 다음 "새 게임" → 좌우 화살표로 "새로 시작" 으로 옮겨 Enter.
    - 기대: DAY 1 / 0 G 새 게임으로 들어간다.
12. ESC → 설정을 연다.
    - 기대: **효과음 30%, 음악 60% 가 그대로 남아 있다.** 100% 로 돌아가면 FAIL. (MEDIUM-2)
13. 인게임 설정 패널에서 위/아래 화살표를 반복해 순환을 본다.
    - 기대: 전체 화면 → 마스터 → 음악 → 효과음 → **저장 데이터 삭제** → 닫기 → 순환.
      (인게임에서는 삭제 버튼이 링에 포함된다.) 포커스가 패널 밖 일시정지 버튼으로
      새면 FAIL.
14. "저장 데이터 삭제" 에서 Enter → 확인 창.
    - 기대: 9번과 같은 양피지 배경 / 잉크 글자, **"취소" 에 포커스 테두리**.
15. 확인 창에서 좌우 화살표로 "삭제" 로 옮겨 Enter.
    - 기대: 게임이 DAY 1 로 재시작된다.
16. 다시 ESC → 설정.
    - 기대: **효과음 30%, 음악 60% 가 여전히 남아 있다.** (MEDIUM-2, 인게임 경로)
17. 기존 화면 회귀: ESC 일시정지 메뉴에서 위/아래 화살표를 눌러 본다.
    - 기대: "계속하기 / 설정 / 저장 후 타이틀로 / 저장 후 종료" 에 **3px 잉크색
      포커스 테두리가 새로 보인다.** 글자는 잉크색 그대로 읽힌다(흰 글자면 FAIL).
    - 기대: 상점 / 자모 선택 / 단어 트리 / HUD 도 같은 규칙으로 테두리만 추가됐을 뿐
      배경·글자색은 그대로다.
18. LOW-2 확인 — 실제 세이브가 살아남는지.
    - `jamo_save.json` 이 있는 상태에서 md5 를 기록한다.
    - `godot --headless --path . res://tests/qa_f7_title.tscn` 실행.
    - 기대: `OK - title screen checks passed.` 가 뜨고,
      **`jamo_save.json` 이 그대로 있으며 md5 가 동일**하다.
      `jamo_save.json.testbak` 이 남아 있으면 FAIL.

헤드리스 (보조, 본 사이클에서 실행해 통과 확인):
- `godot --headless --path . --quit` → NotoSansKR 폰트 누락 2건 외 에러 0
- `res://tests/test_game_loop.tscn` → `OK - all game loop checks passed.`
- `res://tests/test_day_flow.tscn` → `OK - day flow reached Day 2.`
- `res://tests/qa_f7_title.tscn` → `OK - title screen checks passed.`
  로그에 `settings focus ring: SettingsCloseButton, SfxSlider, BgmSlider, MasterSlider,
  FullscreenCheck` 와 `keyboard reachable: NewGameButton, SettingsButton, QuitButton`
  (ContinueButton 없음) 이 찍힌다.

## 3) 주의 / 보류 사항

**전역 Button 포커스 스타일을 건드렸다 (범위 판단)**
- HIGH-2 가 "확인/취소 버튼도 읽히고 포커스 표시가 보여야 한다" 를 요구하는데,
  `AcceptDialog` 의 OK/Cancel 버튼은 엔진이 만드는 자식이라 `theme_type_variation` 을
  씬에서 붙일 수 없다. 테마 리소스만으로 해결하려면 `Button/styles/focus` 밖에 없다.
  QA_REPORT 항목 9 가 지적한 "기본 Button 에 focus 스타일 없음" 과 같은 지점이다.
- 그래서 `Button/styles/focus`(투명 배경 + 3px 잉크 테두리)와
  `Button/colors/font_focus_color`(잉크색)를 추가했다. normal / hover / pressed /
  disabled 는 손대지 않았으므로 **평상시 외형은 그대로고, 포커스된 버튼에만 테두리가
  새로 생긴다.** F1~F6 화면 전부에 영향이 가므로 명시한다(17번 절차로 확인 가능).
- `font_focus_color` 를 함께 넣은 이유: 넣지 않으면 Godot 기본값인 흰 글자가 쓰여서
  탄색 버튼 위 대비가 **2.14 : 1** 로 떨어진다. 실제로 렌더해 보고 발견해서 고쳤다.
  `TitleButton` / `TreeSlot` / `HudIconButton` 변형은 `base_type = Button` 이라
  글자색만 함께 개선되고 각자의 focus 스타일은 그대로 유지된다.

**포커스 트랩 구현 방식**
- 설정 패널을 `Window` 팝업으로 바꾸지 않고 `focus_neighbor_*` 링으로 닫았다.
  씬 구조 변경이 없고 인게임/타이틀 두 사용처가 같은 씬을 공유하기 때문이다.
- 타이틀에서는 `%DeleteSaveButton` 이 숨겨져 있는데, Godot 의 `focus_neighbor` 는
  대상이 안 보이면 **그 노드의 같은 방향 이웃으로 체인을 이어간다.** 그래서
  링을 하나만 정의해 두 사용처(5칸 / 6칸)를 모두 처리한다. 헤드리스 로그의
  `settings focus ring` 줄이 실제로 5칸으로 도는 것을 보여준다.
- **한계**: 이 트랩은 키보드 포커스만 막는다. 패널 루트 Control 이 마우스를 막고 있어
  클릭은 원래대로 새지 않지만, 패널이 화면 전체를 덮지는 않으므로 뒤 버튼이 시각적으로
  보이는 것은 그대로다(F7 QA 에서 이미 PASS 처리된 기존 외형).

**슬라이더 포커스 표시**
- 슬라이더는 포커스를 받으면 Godot 기본 동작대로 손잡이가 `grabber_highlight`(흰색)로
  밝아진다. 버튼 테두리만큼 강하지는 않다. 테마에 `HSlider` 전용 포커스 스타일 항목이
  없어 스타일 리소스만으로 더 강하게 만들 수 없고, 트랙/손잡이 색을 새로 정의하는 것은
  이번 범위를 넘는다고 판단해 **보류**한다. 값 자체는 옆 퍼센트 라벨로 항상 읽힌다.

**세이브 하위 호환**
- `clear_progress()` 는 파일을 지우지 않고 `{"save_version":1,"audio":{...}}` 로 다시 쓴다.
  `has_save()` 는 예전 그대로 `"day"` 키 유무로 판정하므로, 구버전 세이브(항상 `day`
  보유)나 `audio` 키가 없던 세이브 모두 영향이 없다.
- `delete_save()` 는 파일 통삭제로 **남겨 뒀다.** 테스트 하네스가 깨끗한 상태를 만들 때만
  쓴다. 프로덕션 경로(타이틀 새 게임 / 인게임 저장 데이터 삭제)는 둘 다
  `clear_progress()` 로 바꿨다.
- 볼륨은 `AudioManager` 의 현재 값에서 가져온다. 즉 "지금 들리는 볼륨" 이 그대로 남는다.

**테스트로 잡지 못하는 부분**
- `title_screen._on_overwrite_confirmed()` 와 `settings_panel._on_delete_confirmed()` 는
  각각 `change_scene_to_file()` / `reload_current_scene()` 로 끝나 헤드리스 테스트에서
  그대로 호출하면 테스트 씬이 날아간다. 그래서 `test_game_loop.gd` 는
  (a) 확인 창이 취소에 포커스를 두는지, (b) `clear_progress()` 가 진행만 지우고 볼륨을
  남기는지를 각각 검증한다. 두 핸들러가 실제로 `clear_progress()` 를 부르는지는
  검수 절차 11~12 / 15~16 의 육안 확인으로 덮는다.
- 확인 창의 대비는 스크립트로 측정하기 어려워 **실제 렌더 캡처의 픽셀로 측정했다**
  (본문 10.02:1, 제목 5.29:1, 버튼 6.66:1). 위 9번 절차로 재현 가능하다.

**기타**
- NotoSansKR 폰트 누락 에러 2건은 사전 존재 이슈로 그대로다.
- `tests/qa_f6_settings.tscn` 은 `-- write|read|legacy` 인자를 받는 창모드 3단계
  수동 하네스라 인자 없이 헤드리스로 돌리면 끝나지 않는다. 이번 완료 조건에 없어
  실행하지 않았다(F6 사이클 절차 그대로 두었다).
- 검증 중 만든 임시 프로브 스크립트와 PNG 는 모두 삭제했다. `git status` 는 이번
  변경 파일 외에 늘어난 것이 없다. 사용자 세이브는 `jamo_save.json.qabak`(이전 QA 잔여)
  만 남아 있고 손대지 않았다.
