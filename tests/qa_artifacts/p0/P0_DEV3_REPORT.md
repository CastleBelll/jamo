# JAMO P0-DEV-3 — 하네스 커버리지 후퇴 복구 (QA_REPORT_2 MEDIUM #2)

대상: `tests/qa_p0_plates_all` 이 삭제된 `qa_f8_title_shots` 의 4해상도 × 2상태 단언을 되찾도록 한다.
제품 코드는 손대지 않았다 (QA_REPORT_2 §2-3 이 제품은 정상임을 296쌍으로 확인).

## 1) 변경 파일 목록

| 파일 | 변경 |
|---|---|
| `tests/qa_p0_plates_all.gd` | 4해상도 × 2상태마다 판때기별 검사 + 포커스 해제 검사 추가. 창/뷰포트 좌표 스케일 보정. 표에 window 열 추가 |
| `docs/ORCHESTRATION_RULES.md` §7.1 | QA 결함 #2 문장 1곳 수정: 4해상도가 레이아웃에만 걸린다는 오해가 없도록 "4해상도 × 세이브 유/무 2상태에서 측정, 순서쌍 sweep 만 1280x720" 으로 명시 |
| `tests/qa_artifacts/p0/P0_DEV3_REPORT.md` | 이 문서 |

`hub_plates.gd` 는 그대로다. 판때기 목록은 계속 씬에서 유도된다 (`HubPlates.problem()` 가드 호출도 그대로).
임시 negative control 스크립트(`tests/_nc_plates.gd/.tscn`)는 검증 후 삭제했다. 내용은 §4 에 있다.

### 무엇이 어떻게 바뀌었나

`_ready()` 의 1단계 루프가 해상도마다 `_measure_layout` 뒤에 두 가지를 더 돈다.

- `_sweep_each_plate(state, plates)` — 판때기 N개에 대해 2N+1 프레임:
  1. 포인터가 열을 위에서 아래로 한 칸씩 훑는다. 호버가 포커스를 가져가야 하고, 그 판때기만 밝아야 한다.
  2. 포인터를 마지막 판때기에 둔 채 **실제 방향키**로 위로 되짚는다. 키보드 판때기만 밝고, 포인터가 남은 판때기는 어두워야 한다 (F8 MEDIUM-4 케이스).
  3. 포인터를 메뉴 밖으로 뺀다. 키보드 판때기가 계속 혼자 밝아야 한다.
  각 프레임마다 밝은 판때기 == 1 이고 == 키보드 판때기, 그리고 선택 대비 ≥ 3.0:1 을 단언한다.
- `_measure_nothing_focused(state)` — `gui_release_focus()` 후 밝은 판때기 0개. **4해상도 × 2상태 = 8회** 단언 (이전 1회).

2단계 순서쌍 전수 sweep(74쌍)은 1280x720 에서 그대로 1회 돈다. 어떤 판때기가 밝은지는 포커스/호버 상태로 결정되고 창 크기와 무관하다.
창 크기가 바꾸는 것은 히트테스트와 프레임 안의 판때기 위치이므로, 해상도마다는 sweep 사본 대신 판때기별 검사를 돈다 (중복 최소화, 요구사항 4).

**좌표 보정** (QA_REPORT_2 §2-3 하네스 주석이 경고한 지점): 이 프로젝트는 `canvas_items/expand` 스트레치라
1280x720 을 벗어나면 창 좌표 ≠ 뷰포트 좌표다. `_warp_to()` 는 뷰포트 점을 창 점으로 바꿔 warp 하고,
`_plate_luma()` 는 캡처 프레임(창 크기) 에 맞게 샘플 위치를 스케일한다. 보정 없이는 1920/2560 에서 호버가 빗나가고
720x1280 에서 판때기 밖 배경 픽셀(어두움 → "안 밝음")을 읽어 붙어 있는 판때기가 통과한다.

### 삭제된 `qa_f8_title_shots` 와의 대조 (QA_REPORT_2 §2-1 표 기준)

| 항목 | 삭제 전 | 지금 |
|---|---|---|
| 뷰포트 이탈 / 행 간격 / 열 정렬 | 4해상도 × 2상태 | 동일 (`_measure_layout`) |
| 세이브 유무로 판때기 높이 불변 | 4해상도 | 동일 |
| 선택된 판때기 1개 (버튼별 포커스) | 4해상도 × 2상태, stylebox 구조 검사 | **4해상도 × 2상태**, 픽셀 휘도 + 대비 ≥ 3.0:1, 포인터/키보드 양쪽 경로 |
| 포커스 해제 = 0개 | 4해상도 × 2상태 | **4해상도 × 2상태** (8/8, 로그 `focus released -> 0 lit in 8/8`) |
| 버튼 폭 % / 로고 하단 y 출력 | 출력만 | 미복구 (단언 아님, QA 도 "출력만"으로 분류) |

## 2) 검수 절차

1. `godot --headless --path . --quit` 실행. 기대: `NotoSansKR-Regular.ttf` 누락 외 에러 0.
2. `godot --headless --path . res://tests/test_state_split.tscn` → 마지막 줄 `OK - meta/run split holds.`, exit 0.
3. `godot --headless --path . res://tests/test_run_flow.tscn` → `OK - Wave 1 started, the run failed, and the hub came back.`, exit 0.
4. `godot --path . res://tests/qa_p0_plates_all.tscn` (창 모드). 창이 1280x720 → 1920x1080 → 720x1280 → 2560x1080 순으로 두 번(세이브 없음 → 있음) 바뀌며 포인터가 판때기를 훑는 것이 보인다. 약 2분 40초.
5. 로그에서 `--- <창>_<상태>_nothing_focused nothing focused: bright=[]` 줄을 센다. 기대: **8줄** (`1280x720`/`1920x1080`/`720x1280`/`2560x1080` × `nosave`/`save`), 전부 `bright=[]`.
6. 표 `| window | state | pointer on | keyboard on | bright | … | contrast |` 의 행을 window+state 로 묶어 센다. 기대:
   `1280x720 nosave 43` / `1280x720 save 57` / 나머지 3해상도는 `nosave 12`, `save 14` 씩. 합계 **178**.
   (1280x720 = 순서쌍 sweep 31/43 + 판때기별 12/14. 다른 해상도 = 판때기별 2N+1, N=6 또는 7.)
7. 모든 행의 `bright` 열이 `1`, `contrast` 열이 `3.0:1` 이상. 이번 실행 최저 **3.85:1**, 720x1280 은 4.18:1.
8. 마지막 줄 `OK - one bright plate across all 7 hub plates, 178 pointer/keyboard frames at 4 sizes x 2 save states, focus released -> 0 lit in 8/8.` exit 0.
9. `tests/qa_artifacts/p0/plates/` 에 `1920x1080_save_pointer_QuitButton_keyboard_NewGameButton.png` 같은 창 접두 PNG 가 생겼는지 연다. 기대: 키보드 판때기(새 게임)만 밝고 포인터가 남은 종료 판때기는 어둡다. `720x1280_nosave_nothing_focused.png` 은 판때기 전부 어둡다.
10. Negative control (선택): §4 의 스크립트를 `tests/_nc_plates.gd/.tscn` 으로 만들어 `godot --path . res://tests/_nc_plates.tscn` 실행. 기대: exit 1, FAIL 이 `1920x1080_*` (대비 2.00:1), `2560x1080_save_*` (2개 밝음), `720x1280_nosave_nothing_focused` (해제 후 1개 밝음) 에만 나오고 `1280x720_*` 에는 없다. 끝나면 두 파일과 `.uid` 를 지운다.
11. 나머지 창 모드 하네스 `qa_p0_flow` / `qa_f7_title` / `qa_f7_art` / `qa_f8_labels` / `qa_f8_focus_all` / `qa_f8_resize` 각각 exit 0.
12. 실행 후 `user://jamo_save.json` 이 실행 전과 같은지 확인 (하네스가 stash/restore).

## 3) 주의/보류 사항

- **실행 시간**: `qa_p0_plates_all` 86초 → **160초** (Intel UHD 770 기준). 늘어난 74초는 프레임 대기가 대부분(측정마다 `_settle` 8프레임). 순서쌍 sweep 을 4해상도로 복제했으면 약 5분 30초였을 것이라 판때기별 검사로 대신했다.
- **PNG 개수**: `plates/` 에 프레임당 1장, 실행당 약 195장(이전 82장). `.gitignore` 로 제외돼 있다.
- **QA 결함 #3 (LOW, `qa_f7_art`/`qa_f7_title` 이 `HubPlates.problem()` 미호출)**: 이번 범위(1건) 밖이라 손대지 않았다. 다음 사이클 후보.
- **`qa2_plates_4res` (QA 작성)**: 그대로 두었다. 이제 `qa_p0_plates_all` 이 같은 8조합을 단언하므로 QA 판단으로 정리해도 된다.
- **`P0_CARRYOVER_REPORT.md` §3-2** 의 "검증 커버리지 손실은 없고" 문장은 앞 사이클 인계문 원문이라 고치지 않았다. 사실은 QA_REPORT_2 §2-1 과 이 문서 §1 대조표가 기준이다.
- 기존 이슈: `NotoSansKR-Regular.ttf` 누락 에러. `qa_f7_art` 의 `WARN: 1 edge sample(s) look like letterbox at save_1920x1080` 경고 2줄도 이번 변경 전부터 있던 것(exit 0).

## 4) Negative control 스크립트 (재현용)

`tests/_nc_plates.gd`:

```gdscript
extends "res://tests/qa_p0_plates_all.gd"

## NC1  2560x1080 + save   : QuitButton kept lit while another plate has focus
## NC2  720x1280  + nosave : NewGameButton lit after the focus is released
## NC3  1920x1080 (both)   : the focused plate painted dim grey (cue < 3.0:1)
## 1280x720 is left alone and must stay clean.

var _selected_art: StyleBox
var _dim := StyleBoxFlat.new()


func _init() -> void:
	_dim.bg_color = Color(0.45, 0.45, 0.45)


func _settle() -> void:
	_inject()
	await super()
	_inject()


func _inject() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	var window: String = _window_tag()
	var has_save: bool = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if focused != null and _selected_art == null:
		_selected_art = focused.get_theme_stylebox("normal")
	var quit: Button = _button("QuitButton")
	if window == "2560x1080" and has_save and focused != null and focused != quit:
		quit.add_theme_stylebox_override("normal", _selected_art)
	elif focused != quit:
		quit.remove_theme_stylebox_override("normal")
	if window == "720x1280" and not has_save and focused == null:
		_button("NewGameButton").add_theme_stylebox_override("normal", _selected_art)
	if window == "1920x1080" and focused != null:
		focused.add_theme_stylebox_override("normal", _dim)
```

`tests/_nc_plates.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/_nc_plates.gd" id="1_nc"]

[node name="NcPlates" type="Node"]
script = ExtResource("1_nc")
```

결과: §5.

## 5) 이번 실행 결과

| 검사 | 결과 |
|---|---|
| `godot --headless --path . --quit` | 에러 0 (폰트 누락 제외) |
| `test_state_split` / `test_run_flow` | exit 0, `OK - meta/run split holds.` / `OK - Wave 1 started, the run failed, and the hub came back.` |
| `qa_p0_plates_all` | exit 0, 160초. 178 프레임 (1280x720 nosave 43 / save 57, 나머지 3해상도 nosave 12 / save 14 씩). bright 전부 1, 최저 대비 3.85:1 (720x1280 은 4.18:1). `nothing_focused bright=[]` 8/8 |
| negative control (`_nc_plates`) | exit 1, `FAILED - 21 check(s) failed.` — 1920x1080 nosave 6 + save 7 (`selection cue is only 2.00:1`), 2560x1080 save 7 (`lit 2 plates [..., "QuitButton"]`), 720x1280 nosave 1 (`["NewGameButton"] stayed lit with nothing focused`). 1280x720 및 그 외 조합 FAIL 0 |
| `qa_p0_flow` / `qa_f7_title` / `qa_f7_art` / `qa_f8_labels` / `qa_f8_focus_all` / `qa_f8_resize` | 전부 exit 0 (13s / 2s / 12s / 6s / 31s / 3s) |
| 플레이어 세이브 | 실행 전과 같음 (없음. `.qabak` / `.qa2manualbak` 만 존재) |
