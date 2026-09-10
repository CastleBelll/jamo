# F7 DEV 인계문 — 메인화면 / 타이틀 (S1~S6)

## 1) 변경 파일 목록

신규
- `scenes/ui/title_screen.tscn` — 타이틀 씬 (Control). 배경 Panel + CenterContainer/VBox,
  `%NewGameButton` `%ContinueButton` `%ContinueInfoLabel` `%SettingsButton` `%QuitButton`,
  `settings.tscn` 인스턴스(`%Settings`, `run_in_progress = false`), `%OverwriteConfirm`(ConfirmationDialog).
- `scripts/ui/title_screen.gd` — 타이틀 로직. `@export_file("*.tscn") game_scene_path`.
- `tests/qa_f7_title.gd` / `tests/qa_f7_title.tscn` — F7 전용 헤드리스 검증 씬.

수정
- `project.godot` — `run/main_scene` 을 `res://scenes/ui/title_screen.tscn` 로 변경.
- `autoload/save_manager.gd` — `has_save()`, `peek_save()`, `load_audio_settings()`,
  `save_settings()` 추가. `save_game()`/`save_settings()` 가 공유하는 `_write()` 분리.
  `load_game()` 은 `peek_save()` 를 쓰도록 정리(동작 동일) + `"day"` 키가 없는 파일은
  진행 없음으로 판정.
- `scripts/main.gd` — `@export_file("*.tscn") title_scene_path` 추가,
  `pause_menu.title_requested` 연결, 로드 실패 시 `GameState.from_dict({})` 로 초기화.
- `scenes/ui/pause_menu.tscn` — `%TitleButton`("저장 후 타이틀로") 추가. 설정과 종료 사이.
- `scripts/ui/pause_menu.gd` — `title_requested` 시그널 + `_on_title_pressed()` 추가.
- `scripts/ui/settings_panel.gd` — `@export var run_in_progress: bool = true` 추가.
  false 면 `%DeleteSaveButton` 숨김 + 닫을 때 `save_settings()` 사용.
- `theme/jamo_theme.tres` — `SB_title_focus` StyleBoxFlat + `TitleButton` 타입 변형 추가.
- `tests/test_game_loop.gd` — 타이틀 검증 3종 추가.

## 2) 검수 절차

사전: `%APPDATA%\Godot\app_userdata\JAMO\jamo_save.json` 이 세이브 파일이다.
1~4 는 세이브가 **없는** 상태에서 시작한다(파일 삭제).

1. Godot Editor 에서 F5(프로젝트 실행).
   - 기대: 경기장이 아니라 타이틀 화면이 뜬다. "자모 / JAMO" 제목,
     새 게임 / 이어하기 / 설정 / 종료 버튼이 세로로 보인다.
2. 마우스를 건드리지 말고 화면을 본다.
   - 기대: "새 게임" 버튼에 굵은 포커스 테두리가 이미 그려져 있다.
   - 기대: "이어하기" 는 회색(비활성)이고, 바로 아래에
     "저장된 게임이 없어 이어하기를 할 수 없습니다." 라는 **글자**가 보인다.
3. 키보드 아래/위 화살표만 눌러 본다.
   - 기대: 포커스 테두리가 새 게임 → 설정 → 종료 순으로 이동한다.
     비활성인 "이어하기" 는 건너뛴다. 마우스 없이 모든 버튼에 도달 가능하다.
4. "이어하기" 를 마우스로 눌러 본다.
   - 기대: 아무 일도 일어나지 않는다(비활성).
5. 포커스를 "설정" 으로 옮기고 Enter.
   - 기대: 인게임과 **같은** 설정 패널이 열린다.
   - 기대: "저장 데이터 삭제" 버튼이 **보이지 않는다**. 전체 화면 / 마스터 / 음악 / 효과음만 있다.
6. "효과음" 슬라이더를 화살표 키로 왼쪽 끝 근처까지 내린다.
   - 기대: 오른쪽 퍼센트 숫자가 같이 내려간다(예: 30%).
7. "닫기" 를 누른다.
   - 기대: 패널이 닫히고 포커스가 타이틀 버튼으로 돌아온다(테두리가 다시 보인다).
   - 기대: "이어하기" 는 **여전히 비활성**이다. 설정만 바꿨다고 세이브가 생기면 안 된다.
8. 창을 닫고 다시 F5 로 실행 → 설정을 연다.
   - 기대: 6에서 내린 효과음 값이 그대로 남아 있다.
9. "새 게임" 에서 Enter.
   - 기대: 확인 창 없이 바로 경기장(Day 1)으로 들어간다. HUD 가 DAY 1 / 골드 0 을 보여준다.
10. 몬스터를 몇 번 클릭해 에너지를 다 쓰고 Day 2 까지 진행한다.
    - 기대: 기존 F1~F6 흐름(요약 → 자모 선택 → 상점 → Day 2)이 그대로 동작한다.
11. ESC 를 눌러 일시정지 메뉴를 연다.
    - 기대: 계속하기 / 설정 / **저장 후 타이틀로** / 저장 후 종료 4개 버튼이 보인다.
12. "저장 후 타이틀로" 를 누른다.
    - 기대: 타이틀 화면으로 돌아간다. 게임이 멈춘 상태로 얼어붙지 않는다.
    - 기대: "이어하기" 가 **활성**이고, 그 아래에 "저장된 진행 — DAY 2 · N G" 처럼
      실제 진행이 글자로 보인다.
13. "이어하기" 에서 Enter.
    - 기대: DAY 2 와 골드, 보유 자모, 업그레이드가 12에서 본 값 그대로 복원된다.
14. 다시 ESC → "저장 후 타이틀로" → 이번엔 "새 게임" 을 누른다.
    - 기대: "저장된 진행 상황이 사라지고 DAY 1부터 다시 시작합니다. 되돌릴 수 없습니다."
      확인 창이 뜬다. 게임이 바로 시작되지 **않는다**.
15. 확인 창에서 "취소" 를 누른다.
    - 기대: 타이틀로 돌아오고 "이어하기" 는 **여전히 활성**이며 DAY 표시가 그대로다.
      즉 취소는 세이브를 지우지 않는다.
16. 다시 "새 게임" → "새로 시작" 을 누른다.
    - 기대: DAY 1, 골드 0 인 새 게임으로 들어간다. 이전 진행이 남아 있지 않다.
17. ESC → "저장 후 종료".
    - 기대: 기존과 동일하게 저장 후 게임이 종료된다(타이틀로 가지 않는다).
18. `scenes/ui/title_screen.tscn` 을 Godot Editor 로 연다.
    - 기대: 씬 트리에 Background / Center/Box/(버튼들) / Settings / OverwriteConfirm 이 보이고
      각 노드를 클릭하면 Inspector 에서 텍스트·폰트 크기·anchors 를 수정할 수 있다.
    - 기대: 루트 TitleScreen 을 선택하면 Inspector 에 `Game Scene Path` 가 보인다.
    - 기대: Settings 인스턴스를 선택하면 `Run In Progress` 체크박스가 보이고 꺼져 있다.
19. `scenes/main/main.tscn` 루트 Main 을 선택한다.
    - 기대: Inspector 에 `Title Scene Path` 가 보인다.

헤드리스 (보조):
- `godot --headless --path . --quit` → NotoSansKR 폰트 누락 외 에러 0
- `godot --headless --path . res://tests/test_game_loop.tscn` → `OK - all game loop checks passed.`
- `godot --headless --path . res://tests/test_day_flow.tscn` → `OK - day flow reached Day 2.`
- `godot --headless --path . res://tests/qa_f7_title.tscn` → `OK - title screen checks passed.`

## 3) 주의 / 보류 사항

**씬 전환 방식**
- `get_tree().change_scene_to_file()` 을 쓴다. autoload(SignalBus/GameState/SaveManager/
  AudioManager)는 SceneTree root 직속이라 전환 후에도 그대로 살아 있다.
- 일시정지 메뉴는 **직접 씬을 바꾸지 않는다**. 저장 → unpause → `title_requested` 시그널만
  올리고, 실제 전환은 `main.gd` 가 한다. 기존에 `settings_requested` 를 main.gd 가 받는
  구조와 같은 패턴이고, 덕분에 헤드리스 테스트가 씬을 날려먹지 않고 "저장됐는지" 만 검증할 수 있다.

**기존 테스트 호환**
- `main.tscn` 단독 실행 경로는 그대로다. `test_day_flow.gd` / `test_game_loop.gd` 는
  수정 없이 통과한다(실제로 재실행해 확인).
- 다만 `main.gd._ready()` 에 **동작 변경이 하나 있다**: `SaveManager.load_game()` 이 false 면
  `GameState.from_dict({})` 로 초기화한다. 이게 없으면 "타이틀 → 새 게임" 왕복 시 이전 런의
  GameState 가 그대로 남아 DAY 1 인데 골드/업그레이드가 살아 있는 버그가 난다.
  세이브가 있는 경우의 동작은 이전과 동일하다.

**세이브 파일 형식**
- 타이틀에서 설정만 바꾸면 `{"save_version":1,"audio":{...}}` 만 든 파일이 생긴다.
  진행 데이터가 아니므로 `has_save()` 는 `"day"` 키 유무로 판정한다.
  구버전 세이브(항상 `day` 를 가짐)는 영향 없다.
- `load_game()` 이 이제 오디오 설정을 항상 먼저 적용한다. 진행이 없어도 볼륨은 복원된다.

**설정 화면 노출 판단 (S4 요구 항목)**
- "저장 데이터 삭제" 는 **타이틀에서 숨겼다.** 이유 두 가지.
  (1) 타이틀에는 이미 "새 게임 + 덮어쓰기 확인" 이라는 같은 결과의 경로가 있어 중복이고,
      되돌릴 수 없는 버튼이 한 화면에 둘 있는 게 더 위험하다.
  (2) 기존 핸들러가 `reload_current_scene()` 로 끝나는데, 이건 인게임(main.tscn 재시작)을
      전제로 쓰인 동작이다.
  인게임에서는 기존 그대로 노출된다(`run_in_progress` 기본값 true).
- 전체 화면 / 볼륨 3종은 타이틀에서도 그대로 의미가 있어 노출을 유지했다.

**접근성**
- 포커스 테두리는 `theme/jamo_theme.tres` 에 `TitleButton` 타입 변형으로 추가했다
  (`SB_title_focus`: 투명 배경 + 3px 잉크색 테두리). F5 의 `TreeSlot` / `HudIconButton`
  focus 패턴과 같은 방식이다.
- **보류**: 테마의 기본 `Button` 에는 여전히 focus 스타일이 없다. 즉 일시정지/설정/상점 등
  기존 패널 버튼의 포커스 표시는 이번 사이클에서 손대지 않았다(F7 범위 밖이라 판단).
  전역 개선이 필요하면 `Button/styles/focus` 한 줄로 해결되지만 F1~F6 화면 전부의 외형이
  바뀌므로 별도 사이클로 미룬다.
- 색 대비: 타이틀 버튼 글자/배경 약 6.6:1, 안내 문구/패널 약 10:1 로 WCAG AA 통과.
  비활성 "이어하기" 자체는 약 2.5:1 이지만 WCAG 는 비활성 컨트롤을 대비 요건에서 제외하고,
  사유는 바로 아래 본문 대비 10:1 텍스트로 따로 제공하므로 색만으로 정보를 전달하지 않는다.

**기타**
- `godot --headless` 실행 과정에서 `tests/qa_f6_juice.gd.uid`, `tests/qa_f6_settings.gd.uid`
  두 개가 새로 생성됐다(엔진이 만든 것, 내용 없음). 커밋 포함 여부는 총지휘자 판단.
- NotoSansKR 폰트 누락 에러는 사전 존재 이슈로 그대로다.
