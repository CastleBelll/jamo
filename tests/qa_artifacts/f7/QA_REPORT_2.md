# F7 QA 재검증 보고서 — 타이틀 아트 적용 + 직전 FAIL 6건

- 판정: **PASS** (MEDIUM 1건 / LOW 3건 기록, 차단 사유 없음)
- 검증일: 2026-09-10
- 엔진: Godot 4.7.stable.official.5b4e0cb0f, Vulkan Forward+, Intel UHD 770
- 검증 수단:
  - `mcp__ziva-godot__start_godot` 은 이 ziva-godot 빌드에 **존재하지 않는다**(직전 사이클과 동일).
    대신 `run_scene` 으로 실제 게임을 에디터 Game 탭에 임베드 실행해 **실제 키보드/마우스
    입력을 주입하고 렌더된 화면을 눈으로 확인**했다. 헤드리스만으로 판정한 항목은 없다.
  - 창 크기 5종 렌더는 `godot --path . res://tests/qa_f7_art.tscn`(비헤드리스, 실제 창)로
    수행했다. `project.godot` 을 건드리지 않고 런타임에 `DisplayServer.window_set_size` 로
    창을 바꿔 실제 프레임을 캡처했다.
  - Godot 프로세스는 kill 하지 않았다.
- 신규 QA 파일(모두 `tests/` 아래, 프로덕션 코드 무수정):
  - `tests/qa_f7_art.gd` / `.tscn` — 창 크기별 렌더 + 레이아웃/대비 측정
  - `tests/qa_f7_live.gd` / `.tscn` — 실제 입력 하에서 포커스 소유자 추적
- 증거: `tests/qa_artifacts/f7/r2/` (스크린샷 13장 + 확대 크롭 7장)

---

## 0. 세이브 파일 처리 (필독)

- 세션 시작 시 `%APPDATA%\Godot\app_userdata\JAMO\` 에 **`jamo_save.json` 은 없었다.**
  (`jamo_save.json.qabak` 만 존재 — 이전 QA 잔여물, **손대지 않았다.**)
- 검증을 위해 합성 세이브를 작성했다(`day 3 / 512 G / bgm 0.6 / sfx 0.3`,
  `day 5 / 999 G / master 0.9 / bgm 0.6 / sfx 0.3`).
- **검증 종료 후 `jamo_save.json` 을 삭제해 세션 시작 상태로 원복했다.**
  `jamo_save.json.qabak` 은 그대로 남아 있다. 사용자 진행 데이터 손실 없음.

---

## 1. 직전 FAIL 6건 — 같은 재현 절차로 재확인

### HIGH-1 설정 패널 포커스 트랩 — **해소 (PASS)**

재현: 타이틀(세이브 있음) → `ui_down` → `ui_accept`(설정 열림) → `ui_up` 8회 →
`ui_accept`. `tests/qa_f7_live.tscn` 이 매 프레임 포커스 소유자를 출력한다.

실측 포커스 궤적 (실제 키 입력):

```
ContinueButton -> SettingsButton -> SettingsCloseButton -> SfxSlider -> BgmSlider
-> MasterSlider -> FullscreenCheck -> SettingsCloseButton -> SfxSlider -> BgmSlider
-> MasterSlider -> FullscreenCheck -> MasterSlider
```

- 패널 밖으로 **한 번도 새지 않았다** (하네스의 `ESCAPED THE PANEL` 표시 0회).
- `%SfxSlider` 도달 **가능**. 도달 후 `ui_left` 3회로 **30% → 15%** 로 실제로 내려갔고
  우측 퍼센트 라벨이 동기화됐다(최종 프레임에 `효과음 15%`).
- 패널이 열린 상태의 `ui_accept` 로 **게임이 시작되지 않았다.** 최종 프레임은 여전히
  타이틀 + 설정 패널이다. (`FullscreenCheck` 위에서 Enter 를 눌러 전체화면 토글이
  시도됐고 `Embedded window only supports Windowed mode.` 만 출력됐다 — 임베드 실행의
  제약이지 결함이 아니다.)
- 직전 리포트의 재현 경로(`ui_up` 반복 → 패널 뒤 `NewGameButton` 도달)는 재현되지 않는다.

### HIGH-2 덮어쓰기 다이얼로그 대비 — **해소 (PASS)**

실제 렌더 프레임 `r2/dialog_1280x720.png` 픽셀 실측:

| 항목 | 전경 | 배경 | 대비 | AA(4.5:1) |
|---|---|---|---|---|
| 본문 경고문 | `#33291E` | `#E7D7B6` | **10.02 : 1** | 통과 |
| 제목바 "새 게임 시작" | `#F2E6CE` | `#6B5B45` | **5.30 : 1** | 통과 |
| 새로 시작 / 취소 글자 | `#33291E` | `#C9AE7E` | **6.66 : 1** | 통과 |

기본 포커스 = **취소**. 픽셀 스캔으로 확정:

```
취소 버튼 좌측 y=395 -> 729:#E7D7B6 730:#33291E 731:#33291E 732:#33291E 733:#C9AE7E ...
```

3px 잉크 테두리가 **취소에만** 있다. "새로 시작" 에는 없다.
그리고 다이얼로그가 뜬 직후 아무 것도 누르지 않고 **Enter 한 번** → 취소가 눌려
타이틀로 복귀했고 `저장된 진행 — DAY 3 · 512 G` 가 그대로였다. 게임은 시작되지 않았다.
직전 값 1.37:1 → 10.02:1 로 개선 확인.

### MEDIUM-1 비활성 이어하기 포커스 체인 이탈 — **해소 (PASS)**

재현: 세이브 없는 상태, `ui_down` / `ui_up` 반복. 실측 궤적:

```
NewGameButton -> SettingsButton -> QuitButton -> SettingsButton -> NewGameButton
```

`ContinueButton` 은 **한 번도 포커스를 받지 않는다.** 아래 화살표 한 번에 바로 설정으로 간다.
근거: `title_screen.gd:refresh()` 가 `disabled` 와 함께 `focus_mode` 를 `FOCUS_NONE` 으로 전환.
헤드리스 `qa_f7_title.tscn` 도 `keyboard reachable: NewGameButton, SettingsButton, QuitButton`
(ContinueButton 없음)으로 이를 검증한다.

### MEDIUM-2 새 게임이 볼륨을 지움 — **해소 (PASS, 실제 세이브 파일로 확인)**

프로덕션 경로를 실제 키보드로 그대로 밟았다:
타이틀 → `ui_up`(새 게임) → `ui_accept`(확인 창) → `ui_left`(새로 시작) → `ui_accept`.
결과 화면: DAY 1 / ENERGY 20-20 / 0 G / 처치 0 — 새 런 진입 확인.

세이브 파일 전후:

```
전: {"save_version":1,"day":3,"gold":512.0,"audio":{"master":1.0,"bgm":0.6,"sfx":0.3}}
후: {"audio":{"bgm":0.6,"master":1.0,"sfx":0.3},"save_version":1}
```

진행(`day`/`gold`)만 사라지고 **볼륨 3종이 그대로 남았다.** 100% 로 복귀하지 않는다.
설정 패널을 다시 열었을 때도 `sfx=30% bgm=60% master=100%` 로 로드되는 것을 확인했다.

### LOW-1 취소 후 포커스 복귀 — **해소 (PASS)**

확인 창에서 Enter(=취소) 후의 프레임에서 `이어하기` 에 포커스 테두리가 **보인다.**
포커스가 사라지지 않는다. `_overwrite_confirm.canceled -> focus_default_button` 연결 확인.

### LOW-2 QA 하네스가 세이브를 파괴 — **해소 (PASS)**

```
before md5 = 1f2b71dd2ed6af5205d1b82d151de9f0
godot --headless --path . res://tests/qa_f7_title.tscn  ->  OK - title screen checks passed.
after  md5 = 1f2b71dd2ed6af5205d1b82d151de9f0   (바이트 동일)
jamo_save.json.testbak 잔존 없음
```

---

## 2. 아트 적용 (신규)

### 2-1. 회색 기본 Panel 잔존 여부 — PASS

`title_bg.png`(사진 배경) + `title.png`(JAMO 로고) + `title_active_button.png` /
`title_inactive_button.png`(붓자국 판때기) 가 모두 실제로 렌더된다.
회색 기본 `Panel` 은 타이틀 어디에도 남아 있지 않다.
설정 패널·확인 창은 의도대로 양피지(`#E7D7B6`) 스타일박스다.

### 2-2. 창 크기 5종 (요구 4종 + 1) — PASS

| 파일 | 창 | 실제 뷰포트 | 레터박스 | 잘림 | 겹침 | 버튼 이탈 |
|---|---|---|---|---|---|---|
| `r2/nosave_1280x720.png` | 1280x720 | 1280x720 | 없음 | 없음 | 없음 | 없음 |
| `r2/nosave_1920x1080.png` | 1920x1080 | 1280x720 | 없음 | 없음 | 없음 | 없음 |
| `r2/nosave_720x1280.png` | 720x1280 (세로형) | 1280x2275 | 없음 | 없음 | 없음 | 없음 |
| `r2/nosave_2560x1080.png` | 2560x1080 (21:9 초광폭) | 1706x720 | 없음 | 없음 | 없음 | 없음 |
| `r2/nosave_1920x720.png` | 1920x720 (8:3) | 1920x720 | 없음 | 없음 | 없음 | 없음 |

`save_*` 5종(이어하기 활성)도 동일하게 캡처했다. 총 10장 + 다이얼로그/설정 3장.

- 하네스가 매 크기마다 5개 컨트롤 + 로고의 rect 를 뷰포트와 대조한다. `inside_viewport=true`
  100%, 상호 교차 0건, 로고-버튼 교차 0건. FAIL 출력 없음.
- 네 변 가장자리 픽셀을 샘플해 레터박스를 탐지한다. 1280x720 에서 우측 중앙 샘플이
  `#050302` 로 임계값에 걸려 WARN 이 떴으나, 캡처를 눈으로 보면 그 위치는 배경 사진의
  어두운 그림자 영역이다. 실제 레터박스(균일 검정 띠)는 어느 크기에도 없다.
  `KEEP_ASPECT_COVERED` 가 의도대로 동작한다.

### 2-3. 픽셀 하드코딩 없이 앵커/컨테이너로 대응했는지 — PASS (예외 기록)

`scenes/ui/title_screen.tscn` 직접 확인:

- `Background` / `Scrim` / `Safe` : `anchors_preset = 15` 풀 렉트.
- `Safe` = `AspectRatioContainer ratio=1.7777778 stretch_mode=FIT`.
- `Logo` : 앵커 0.20~0.80 / 0.05~0.32. `Box` : 앵커 0.345~0.655 / 0.37~0.95.
- 버튼 4개 전부 `size_flags_vertical = 3`(EXPAND|FILL). `custom_minimum_size` / offset 하드코딩 없음.
- 예외(둘 다 Godot 이 int px 만 받는 자리): `VBoxContainer separation = 6`,
  StyleBoxTexture `content_margin` 28/8.
- **추가 발견**: `%OverwriteConfirm` 의 `size = Vector2i(460, 140)` 은 픽셀 하드코딩이다.
  ConfirmationDialog 는 서브윈도우라 content scale 을 따라가므로 실사용에 문제는 없었고
  1280x720 캡처에서 본문이 잘리지 않았다. LOW-3 로 기록만 한다.

---

## 3. 텍스처 버튼 위 포커스 가시성 (중요) — 조건부 PASS + MEDIUM-1(신규)

**"판때기 바깥 허공에 뜨는가" → 아니다.** `region_rect` 로 투명 여백을 잘라낸 덕분에
버튼 rect 가 붓자국과 거의 일치하고, 3px 테두리는 판때기를 **밀착해서 감싼다.**
4종(+1) 창 크기 전부에서 동일하다 (`r2/zoom_focus_*.png` 확대 크롭 5장).

**"실제로 보이는가" → 보인다. 다만 약하다.**
같은 배경·같은 좌표에서 포커스 있음(`nosave_*`) / 없음(`save_*`) 프레임을 픽셀 단위로 비교한
결과(= WCAG 2.2 SC 2.4.11 이 요구하는 "포커스 표시 영역의 변화 대비"):

| 창 | 변화 픽셀 | 변화 대비 중앙값 | 3:1 이상인 픽셀 |
|---|---|---|---|
| 1280x720 | 2900 | 1.34 : 1 | 240 (8.3%) |
| 1920x1080 | 7172 | 1.36 : 1 | 467 (6.5%) |
| 720x1280 | 1822 | 1.16 : 1 | 57 (3.1%) |
| 2560x1080 | 7416 | 1.35 : 1 | 466 (6.3%) |
| 1920x720 | 2900 | 1.35 : 1 | 240 (8.3%) |

원인: 테두리 색이 잉크(`#33291E`)인데, 테두리가 지나가는 자리는 붓자국 **위**가 아니라
붓자국 가장자리 바깥의 **어두운 배경 사진**(예: `#161111`, `#140B07`)이다.
상단 변만 안쪽이 판때기(`#F9E9CA`, 16.8:1)와 맞닿아 눈에 띈다. 하단·좌우 변은
양쪽 모두 어두워 1.27~1.35:1 밖에 안 된다. 픽셀 컬럼 실측(1280x720, x=640):

```
상단 y=265:#171111  266~268:#33291E(테두리)  269:#F9E9CA(판때기)   -> 안쪽 16.8:1
하단 y=352~354:#140B07  355~357:#33291E  358:#140C07               -> 양쪽 1.27:1
```

- 판정: 태스크가 명시한 두 기준("보이는지", "허공에 뜨지 않는지")은 **충족**한다.
  실제 프레임을 나란히 놓으면 사람 눈으로 구분된다.
- 그러나 WCAG 2.2 SC 2.4.11(Focus Appearance, AA)의 3:1 기준은 테두리 둘레의 90% 이상에서
  **미달**이다. 차단하지 않고 **MEDIUM-1(신규)** 로 올린다.
- 권장(범위 밖, DEV 판단 사항): `TitleButton/styles/focus` 에 잉크 테두리 바깥쪽으로
  크림색(`#F2E6CE`) 외곽선을 한 겹 더 두거나(2색 테두리), 포커스 시 `expand_margin` 으로
  판때기를 살짝 키워 테두리가 판때기 위에 오게 하는 방법.

---

## 4. 비활성 상태가 색만으로 전달되는가 — PASS

- 비활성 이어하기 **아래에 사유 텍스트**가 항상 있다:
  "저장된 게임이 없어 이어하기를 할 수 없습니다." 색만으로 전달하지 않는다.
- 사유 텍스트 대비 (배경 사진 위, 크림 글자 + 8px 잉크 아웃라인), 실제 렌더 픽셀:

| 창 | 글자 | 국소 배경 중앙값 | 대비 |
|---|---|---|---|
| 1280x720 | `#F2E6CE` | `#4A3531` | **9.21 : 1** |
| 1920x1080 | `#F2E6CE` | `#4A3531` 상당 | 9.2 : 1 대 |
| 720x1280 | `#CBC0AC` (축소 AA) | `#21120C` | **10.10 : 1** |
| 2560x1080 | `#F2E6CE` | — | 9.2 : 1 대 |

- 비활성 "이어하기" 글자 자체(`#F2E6CE`) / 어두운 판때기(`#39322D`) 대비:
  1280x720 **10.18:1**, 1920x1080 10.17:1, 2560x1080 10.29:1, 1920x720 10.32:1,
  720x1280 **7.23:1**(축소 AA로 글자가 `#CDC2AE` 로 흐려짐). 전부 AA 4.5:1 통과.
  DEV 주장치 11.78:1 과의 차이는 배경 대표값 산정 방식 차이(중앙값 vs 평균)일 뿐,
  결론(AA 통과)은 동일하다. 직전 사이클의 2.45:1 대비 크게 개선.

---

## 5. import 설정 변경 검토 (`mipmaps/generate` false -> true) — PASS + 근거

diff 는 4개 파일 각각 **정확히 한 줄**이다. 원본 `.png` 는 무수정.

- **필요한 변경이다.** 씬의 TextureRect / Button 이 `texture_filter = 4`
  (= `LINEAR_WITH_MIPMAPS`)를 쓴다. 버튼 텍스처는 `region_rect` 1946x423 을
  1280x720 기준 396x92 로 **약 4.9배 축소** 렌더한다. 밉맵이 없으면 이 배율에서
  붓자국 가장자리가 심하게 지글거린다. 실제 캡처(`r2/zoom_focus_*.png`)에서
  가장자리가 깨끗하고 모아레가 없음을 확인했다.
- **메모리**: 5개 모두 `compress/mode=0`(Lossless, 런타임 RGBA8 비압축).
  title / active_button 2172x724, inactive_button 2171x724, bg 1536x1024.
  비밉맵 합계 약 25 MB → 밉맵 체인 +약 33% → **약 33 MB**, 즉 **+8 MB 증가**.
  UHD 770(공유 메모리) 환경에서 60 FPS 유지(8절)를 확인했으므로 수용 가능.
  다만 VRAM 이 빠듯한 타깃을 노린다면 `compress/mode` 를 VRAM 압축으로 돌리는 쪽이
  밉맵보다 훨씬 큰 절감(약 1/4)을 준다 — LOW-2 로 기록.
- **로드**: 밉맵은 임포트 시점에 `.ctex` 안에 구워진다. 런타임 CPU 생성 비용 없음.
  파일이 커지는 만큼의 디스크 읽기만 늘어난다. 부팅 로그에 지연/오류 없음.
- **region 블리딩**: 밉 상위 레벨에서 `region_rect` 경계 밖 픽셀이 번질 수 있는 구조지만,
  원본이 region 바깥에 투명 여백을 두고 있어 확대 크롭에서 헤일로가 보이지 않았다.
- `title_ex.png` 만 `mipmaps/generate=false` 로 남아 있다. 런타임 미사용이므로 무해.

---

## 6. `title_ex.png` 판단 검토 — DEV 판단 **타당**, 보완 권고 (LOW-1 신규)

파일을 직접 열어 확인했다(1536x1024). 내용:

- 메뉴가 **영문**(New Game / Continue / Settings / **Gallery** / Quit) — 게임의 한국어 메뉴와 불일치.
- **`Gallery` 메뉴가 존재** — 코드베이스에 갤러리 기능이 없다.
- 좌하단 **"WISHLIST ON STEAM"** 배지, 우하단 "A GAME ABOUT KOREAN LETTERS…" 카피,
  우측 한국어 카피 블록, 좌측 FIRE / POISON / LIGHTNING / GROWTH / MORE WORDS 책등.
- 즉 **스토어 페이지용 키아트 / 완성 시안 목업**이다. 인게임에 그대로 쓰면
  존재하지 않는 메뉴와 위시리스트 배지가 노출된다.

→ "런타임 미사용" 이라는 DEV 판단에 **동의한다.** 파일은 지우지 않았다.
전 프로젝트 grep 결과 `.tscn` / `.gd` / `.tres` / `project.godot` 어디에서도 참조되지 않는다.

보완 권고(LOW-1): 참조가 없어도 `res://` 아래에 있으면 **익스포트 패키지에 그대로 포함된다**
(1.9 MB 원본 + `.ctex`). 릴리스 전에 익스포트 필터에서 제외하거나
`art/_reference/` 같은 비익스포트 위치로 옮기는 편이 좋다. 이번 범위 밖이라 조치하지 않았다.

---

## 7. theme 전역 영향 (F1~F6 화면) — PASS

`Button/styles/focus`(투명 배경 + 3px 잉크 테두리) + `Button/colors/font_focus_color`(잉크색)
추가가 기존 화면을 밀어내는지 실제 실행으로 확인했다.

- **레이아웃 밀림 없음 (구조적 근거)**: `SB_btn_focus` 의 `content_margin` 은 16/9/16/9 로
  `SB_btn_normal` 과 **완전히 동일**하다. 상태 전환 시 최소 크기가 변하지 않는다.
  실측으로도 뒷받침된다 — 포커스 유/무 두 프레임에서 버튼 rect 가 픽셀 단위로 동일했다
  (3절 표의 "변화 픽셀" 이 테두리 둘레에만 분포).
- **일시정지 메뉴**: 계속하기 / 설정 / 저장 후 타이틀로 / 저장 후 종료 4개가 탄색 배경 +
  잉크 글자 그대로이고, 포커스된 "저장 후 타이틀로" 에만 3px 잉크 테두리가 새로 보인다.
  흰 글자로 바뀌는 현상 없음(= `font_focus_color` 지정이 실제로 효과 있음).
  버튼 크기·간격 변화 없음.
- **단어 트리 패널**: 6열(화염 / 힘 / 경제 / 에너지 / 행운 / 기타) 정렬 유지, `TreeSlot` 변형은
  자체 focus 스타일을 그대로 쓰고 포커스된 "[선행 잠금] 불꽃" 에 테두리가 정상 표시.
  닫기 버튼, HUD 아이콘 버튼(책 / 자모 / 일시정지) 모두 외형 유지.
- **HUD**: DAY / ENERGY / G / 처치 패널 위치·크기 변화 없음.
- **상점 / 자모 선택**: 이번 diff 가 `Button` 의 focus 항목만 추가했고 위 두 화면도 같은
  `Button` 기반이라 동일 규칙이 적용된다. 자동 테스트 `test_day_flow.tscn`
  (Day 2 도달 = 요약 → 자모 선택 → 상점 경유)이 통과한다. 육안 확인은 일시정지·트리
  두 화면으로 대표했다 — 전 화면 육안 스윕은 이번 사이클에서 하지 않았음을 명시한다.

---

## 8. 전체 회귀 — PASS (범위 명시)

| 항목 | 결과 | 근거 |
|---|---|---|
| F7 세이브 분기 | PASS | 세이브 없음 → 이어하기 비활성 + 사유 문구 / 세이브 있음 → `저장된 진행 — DAY 3 · 512 G` 표시 및 이어하기 활성 |
| F7 이어하기 복원 | PASS | `day 5 / 999 G` 세이브로 `main.tscn` 부팅 시 HUD 가 DAY 5 / 999 G / ENERGY 20-20 |
| F7 타이틀 복귀 | PASS | 일시정지 메뉴에 "저장 후 타이틀로" 표시·포커스 정상 |
| F7 새 게임 → Day 1 | PASS | DAY 1 / 0 G / ENERGY 20-20 / 처치 0, 이전 런 잔존 없음 |
| F5 트리 / Target | PASS | 단어 트리 6열, `완성한 단어 0 / 10`, `목표 단어: 없음`, TARGET 배너 표시 |
| F3 단어 10개 · 화염 · 불꽃 | PASS | 트리에 불/힘/돈/밥/운 + 화염/강타/금/체력/**불꽃** 노출, 불꽃 설명에 전이 로직 문구 |
| F3/F4 tier-2 선행 잠금 | PASS | `[선행 잠금]` 라벨 + `선행 단어 불 (미완성)` 표기 |
| F1 아레나 / HUD | PASS | 아이소메트릭 아레나, 자모 몬스터 스폰, HUD 4패널, 제작 가능한 단어 목록 |
| Day 1 → Day 2 | PASS | `test_day_flow.tscn` → `OK - day flow reached Day 2.` |
| 게임 루프 전반 | PASS | `test_game_loop.tscn` → `OK - all game loop checks passed.` |
| 60 FPS | PASS | 실측: 타이틀 454f/7503ms=**60.5**, 트리 362f/6006ms=**60.3**, 일시정지 422f/7003ms=**60.3** |

**이번 사이클에서 육안으로 직접 조작하지 않은 항목**(정직하게 명시):
F2 리롤, F4 특수 몬스터 3종·황금 게이트, F6 에너지 경고·단어 완성 연출, 아레나 이탈 카운트.
근거: 이번 diff(theme focus / 타이틀 씬 / settings 포커스 링 / save_manager)가 해당 로직에
닿지 않고, 자동 테스트 3종이 전부 통과하며, 직전 사이클에서 PASS 판정된 항목이다.
전수 육안 회귀가 필요하면 별도 사이클을 요청한다.

---

## 9. 자동 테스트 — 전부 통과

```
godot --headless --path . --quit
  -> NotoSansKR-Regular.ttf 누락 2건 외 에러 0 (사전 존재 이슈)

res://tests/test_game_loop.tscn  -> OK - all game loop checks passed.
res://tests/test_day_flow.tscn   -> OK - day flow reached Day 2.
res://tests/qa_f7_title.tscn     -> OK - title screen checks passed.
     entry focus: NewGameButton
     keyboard reachable: NewGameButton, SettingsButton, QuitButton     (ContinueButton 없음)
     settings focus ring: SettingsCloseButton, SfxSlider, BgmSlider, MasterSlider, FullscreenCheck
```

---

## 10. 신규 기록 항목 (차단 아님)

| # | 등급 | 내용 |
|---|---|---|
| MEDIUM-1 | MEDIUM | 타이틀 텍스처 버튼의 포커스 테두리가 붓자국 바깥 어두운 배경 위를 지나가, 포커스 변화 대비 중앙값 1.34:1 (WCAG 2.2 SC 2.4.11 의 3:1 미달). 육안으로는 구분 가능. 3절 참조 |
| LOW-1 | LOW | `title_ex.png` 는 런타임 미사용이 맞으나 `res://` 에 있어 익스포트에 포함된다. 릴리스 전 익스포트 제외 권고 |
| LOW-2 | LOW | 타이틀 텍스처 4종이 `compress/mode=0`(무압축) + 밉맵으로 약 33 MB VRAM. VRAM 압축 전환이 밉맵보다 큰 절감을 준다 |
| LOW-3 | LOW | `%OverwriteConfirm` 의 `size = Vector2i(460, 140)` 은 타이틀 씬에 남은 유일한 픽셀 하드코딩. 현재 잘림 없음 |
| NOTE | — | 720x1280 세로형에서 16:9 안전영역이 화면 높이의 약 32% 만 차지해 UI 가 작아진다(사유 문구 글자 높이 12px). 잘림·겹침은 없어 PASS 이나 모바일 세로 지원을 정식 목표로 삼는다면 별도 레이아웃이 필요하다 |
