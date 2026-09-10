# F7-DEV-3 인계문 — 타이틀 아트 에셋 적용 (해상도 대응)

## 1) 변경 파일 목록

- `scenes/ui/title_screen.tscn` — 전면 재구성 (아래 "레이아웃 구조" 참조).
- `theme/jamo_theme.tres` — `TitleButton/font_sizes/font_size` **20 → 26** 한 줄만.
  (`TitleButton` 변형은 타이틀 화면에서만 쓰인다. `pause_menu.tscn` 의 `TitleButton` 은
  노드 이름일 뿐 테마 변형이 아니라 영향 없음. grep 으로 확인)
- `art/ui/title/title_bg.png.import`
- `art/ui/title/title.png.import`
- `art/ui/title/title_active_button.png.import`
- `art/ui/title/title_inactive_button.png.import`
  → 4개 모두 `mipmaps/generate=false` → `true` 한 줄만. 에셋 원본(.png)은 손대지 않았다.

스크립트(`scripts/ui/title_screen.gd`)는 **한 줄도 고치지 않았다.** 노드는 전부
`unique_name_in_owner`(`%NewGameButton` 등) 로 접근하므로 씬 구조를 바꿔도 그대로 동작한다.

## 2) 레이아웃 구조 (왜 안 깨지는가)

```
TitleScreen (Control, full rect)
├── Background   TextureRect  title_bg.png   expand_mode=IGNORE_SIZE, stretch_mode=KEEP_ASPECT_COVERED
├── Scrim        ColorRect    #0B0806 alpha 0.28   (사진 배경 위 글자 대비 확보)
├── Safe         AspectRatioContainer  ratio=1.7777778, stretch_mode=FIT
│   └── Content  Control
│       ├── Logo TextureRect  title.png  anchors 0.20~0.80 / 0.05~0.32, KEEP_ASPECT_CENTERED
│       └── Box  VBoxContainer  anchors 0.345~0.655 / 0.37~0.95
│           ├── %NewGameButton     size_flags_vertical = EXPAND|FILL
│           ├── %ContinueButton    size_flags_vertical = EXPAND|FILL
│           ├── %ContinueInfoLabel (EXPAND 없음 — 글자 높이만 차지)
│           ├── %SettingsButton    size_flags_vertical = EXPAND|FILL
│           └── %QuitButton        size_flags_vertical = EXPAND|FILL
├── %Settings          (변경 없음)
└── %OverwriteConfirm  (변경 없음)
```

**핵심**: 프로젝트가 `canvas_items` + `aspect=expand` 라서 창이 커지면 UI 전체가 균등
스케일되고, 창 **비율**이 바뀔 때만 뷰포트가 한 축으로 늘어난다. `AspectRatioContainer`
(ratio 16:9, FIT)로 안전 영역을 잡아 두면 늘어난 축의 여백은 배경만 채우고 로고·메뉴의
상대 배치는 **어떤 창 비율에서도 픽셀 단위로 동일**해진다. 배경은 `KEEP_ASPECT_COVERED`
라 여백(레터박스)이 절대 생기지 않고 중앙 크롭만 된다.

로고·버튼 크기는 전부 앵커 비율과 `EXPAND|FILL` 로 결정된다. `custom_minimum_size` 나
좌표 offset 을 하드코딩한 곳은 없다. (VBox `separation = 6` 은 Godot 이 int px 만 받는
테마 상수라 예외)

## 3) 버튼 상태 처리

`Button` 노드를 유지하고 `theme_override_styles` 로 `StyleBoxTexture` 를 씬에 넣었다
(`TextureButton` 이 아니다 — 텍스트·disabled·포커스 동작을 전부 그대로 쓰기 위해).

| 상태 | 텍스처 | 비고 |
|------|--------|------|
| normal | `title_active_button.png` | region_rect `Rect2(112,157,1946,423)` = 알파 실측 붓자국 영역 |
| hover | 같은 텍스처 | `modulate_color` 1.12/1.09/1.02 |
| pressed | 같은 텍스처 | `modulate_color` 0.84/0.80/0.74 |
| disabled | `title_inactive_button.png` | region_rect `Rect2(116,149,1931,434)` |
| focus | 테마 `TitleButton/styles/focus` (`SB_title_focus`) | **덮어쓰지 않았다** |

- `region_rect` 로 투명 여백을 잘라내서 **버튼 rect == 눈에 보이는 붓자국**이 된다.
  덕분에 3px 포커스 테두리가 판때기에 딱 붙는다(허공에 뜨지 않는다).
- 비활성 판때기는 어두운 색(평균 RGB 50,44,41)이라 테마 기본 `font_disabled_color`
  (130,122,107)로는 3.24:1 밖에 안 나온다. `%ContinueButton` 에만
  `theme_override_colors/font_disabled_color = 크림(242,230,206)` 을 걸어 **11.8:1** 로 올렸다.
- 상태를 색/그림으로만 전달하지 않는다. `%ContinueInfoLabel` 의 사유 문구는 그대로다
  (크림 글자 + 8px 잉크색 아웃라인 → 글자/아웃라인 대비 **15.5:1**, 배경 사진과 무관하게 읽힘).

**실측 대비 (렌더 캡처 픽셀 측정, WCAG AA 4.5:1 기준)**

| 항목 | 대비 |
|------|------|
| 활성 버튼 글자 / 판때기 | 12.24 : 1 |
| 설정 버튼 글자 / 판때기 | 12.35 : 1 |
| 비활성 이어하기 글자 / 어두운 판때기 | 11.78 : 1 |
| 포커스 테두리 / 판때기 | 17.90 : 1 |
| 안내 문구 글자 / 아웃라인 | 15.51 : 1 |

## 4) 스크린샷 (`tests/qa_artifacts/f7/`)

| 파일 | 내용 |
|------|------|
| `title_1280x720.png` | 기준 해상도, 세이브 없음 |
| `title_1920x1080.png` | 16:9 확대 — 1280x720 과 배치 동일 |
| `title_720x1280_portrait.png` | 세로형 — 16:9 안전영역 중앙, 배경만 세로 크롭 |
| `title_1920x720_ultrawide.png` | 초광폭 — 안전영역 중앙, 배경 가로 확장 |
| `title_1280x720_continue.png` | 이어하기 활성 + 포커스 + "저장된 진행 — DAY 2 · 137 G" |
| `title_overwrite_dialog.png` | 덮어쓰기 확인창 (취소에 포커스, 양피지 대비 유지) |
| `title_settings_panel.png` | 타이틀 설정 패널 (삭제 버튼 숨김, 닫기에 포커스) |

## 5) 헤드리스 결과

- `godot --headless --path . --quit` → NotoSansKR 폰트 누락 2건 외 에러 0 (사전 존재 이슈)
- `res://tests/test_game_loop.tscn` → `OK - all game loop checks passed.`
- `res://tests/test_day_flow.tscn` → `OK - day flow reached Day 2.`
- `res://tests/qa_f7_title.tscn` → `OK - title screen checks passed.`
  (`entry focus: NewGameButton` / `keyboard reachable: NewGameButton, SettingsButton,
  QuitButton` / `settings focus ring: SettingsCloseButton, SfxSlider, BgmSlider,
  MasterSlider, FullscreenCheck` 그대로)
