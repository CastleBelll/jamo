# F6 Juice / Polish — DEV 인계문

대상: DEV_ROADMAP F6 / S0~S6. 브랜치 main. Godot 4.7.stable.

---

## 1. 변경 파일 목록

### 신규
| 파일 | 내용 |
|------|------|
| `autoload/audio_manager.gd` | AudioManager 로직 (버스 볼륨 / SFX 풀 / 스트림 캐시 / 세이브) |
| `autoload/audio_manager.tscn` | AudioManager autoload 씬. `SfxPool` 아래 `SfxPlayer0~7`, `BgmPlayer` |
| `autoload/audio_manager.gd.uid` | Godot 생성 |
| `default_bus_layout.tres` | 오디오 버스 레이아웃 Master / BGM / SFX |
| `scripts/data/audio_library.gd` | `AudioLibrary` Resource — 이름 붙은 SFX 슬롯을 파일 경로로 보관 |
| `scripts/data/audio_library.gd.uid` | Godot 생성 |
| `resources/audio/sfx_library.tres` | AudioLibrary 인스턴스 (현재 전 슬롯 빈 문자열) |
| `materials/burn_ember.tres` | 화상 ember 머티리얼 (unshaded, emission 없음) |
| `materials/gold_sparkle.tres` | 황금 sparkle 머티리얼 (unshaded, emission 없음) |
| `art/audio/sfx/README.txt` | 아직 없는 오디오 애셋의 기대 파일명·경로 문서 |
| `tests/qa_f5_topdown.gd.uid` | Godot 생성 (에디터 임포트 부산물) |

### 수정
| 파일 | 내용 |
|------|------|
| `project.godot` | `AudioManager` autoload 등록, `[audio] buses/default_bus_layout` 지정 |
| `autoload/signal_bus.gd` | `word_revealed()` 시그널 추가 |
| `autoload/save_manager.gd` | 세이브 페이로드에 `audio` 섹션 추가 / 로드 시 복원 |
| `scripts/ui/word_tree.gd` | S0-1: 지역변수 `hidden` → `hidden_count` (shadowing 경고 제거) |
| `scenes/ui/hud.tscn` | S0-2: 책 아이콘 툴팁 "단어 도감" → "단어 트리". S3: `EnergyWarnLabel`, `EnergyPulseAnim`, `EnergyWarnAnim` 추가 |
| `scripts/ui/hud.gd` | S3: `LOW_ENERGY_WARNING` 상수 제거, `GameBalance.low_energy_warning` 사용. pulse / warn 재생 |
| `scripts/data/game_balance.gd` | `low_energy_warning` export 추가 |
| `resources/balance/game_balance.tres` | `low_energy_warning = 3` |
| `scenes/fx/hit_fx.tscn`, `scenes/fx/death_fx.tscn` | 풀링 대상으로 변경 (`emitting=false`, 자체 Timer/queue_free 제거) |
| `scenes/world/game_world.tscn` | `FXRoot/HitFXPool`(10개), `FXRoot/DeathFXPool`(8개) 추가, 풀 NodePath 연결 |
| `scripts/world/game_world.gd` | 파티클 씬 인스턴스화 → 풀 라운드로빈 재사용. kill SFX |
| `scripts/combat/click_controller.gd` | 클릭 SFX 큐 선택 (`click` / `click_critical` / `click_golden`) |
| `scenes/monsters/jamo_monster_base.tscn` | `StatusEffectAnchor/BurnEmber` CPUParticles3D 추가 |
| `scripts/monsters/jamo_monster.gd` | `effects_changed` 구독 → ember on/off. `play_step_sfx()` 추가 |
| `scenes/monsters/special/monster_golden_hieut.tscn` | `StatusEffectAnchor/GoldSparkle` CPUParticles3D 추가 |
| `scripts/data/motion_profile.gd` | `step_sfx_path` (`@export_file`) 추가 |
| `resources/motion_profiles/*.tres` (9개) | 프로필별 step SFX 경로 지정 |
| `resources/animations/walk_library.tres` | 7개 walk 애니메이션에 `play_step_sfx` method 트랙 추가 |
| `scenes/ui/word_complete.tscn` | `FlyLayer/FlyJamo0~7`, `RevealAnim` 추가 |
| `scripts/ui/word_complete.gd` | 자모 집결 → 합성 → 등장 연출, 스킵 처리 |
| `scripts/world/camera_rig.gd` | `word_revealed` 구독 → `zoom_punch()` |
| `scenes/ui/settings.tscn` | 마스터 / 음악 / 효과음 슬라이더 + 퍼센트 라벨 3행 추가 |
| `scripts/ui/settings_panel.gd` | 슬라이더 ↔ AudioManager 연동, 닫을 때 저장 |
| `tests/test_game_loop.gd` | F6 검증 7건 추가 |

---

## 2. 검수 절차

전제: `godot --headless --path . --quit` 및
`godot --headless --path . res://tests/test_game_loop.tscn`,
`res://tests/test_day_flow.tscn` 은 먼저 돌려서 통과를 확인한다.
아래는 **창을 띄우고 눈과 귀로** 하는 절차다.

### A. S0 이월 2건

1. 게임을 실행하고 상단 우측 **책 아이콘에 마우스를 올린다**.
   기대: 툴팁이 **"단어 트리"** (이전의 "단어 도감" 이 아니다).
2. 실행 콘솔 로그를 처음부터 끝까지 훑는다.
   기대: `word_tree.gd:191` 의 `hidden` shadowing 경고가 **한 줄도 없다**.
   (`NotoSansKR-Regular.ttf` 폰트 누락 에러 2줄은 기존 이슈이므로 무시)

### B. S1 클릭 피드백 4종

3. 몬스터 한 마리를 **한 번 클릭**한다. 다음 4가지가 **동시에** 나와야 한다.
   - 자모가 **납작하게 눌렸다가 돌아온다** (squash — `hit` 애니메이션)
   - 자모 위쪽에서 **작은 먹가루 조각이 튄다** (HitFX 파티클, 위로 퍼졌다가 낙하)
   - **데미지 숫자**가 자모 위에 떠올라 위로 이동하며 사라진다
   - **소리는 나지 않는다** (아래 3절 오디오 애셋 주의사항 참조. 이것이 정상이다)
4. 치명타가 뜰 때까지 클릭을 반복한다(치명 확률이 낮으면 상점에서 치명 업그레이드를 산다).
   기대: 치명타에서 **숫자가 눈에 띄게 커지고 붉어지며**, **화면이 살짝 흔들린다**.
   (F1 에서 검증된 동작이 그대로 남아 있는지 확인하는 회귀 항목)
5. 클릭을 **빠르게 20회 이상 연타**한다.
   기대: 파티클이 끊기지 않고 계속 나온다. **프레임이 눈에 띄게 떨어지지 않는다.**
   (파티클은 10개 인스턴스를 돌려쓰는 방식이라 클릭마다 새로 만들지 않는다)
6. 에디터에서 `scenes/world/game_world.tscn` 을 열어 씬 트리에서
   `FXRoot/HitFXPool` 아래 `HitFX0~9`, `FXRoot/DeathFXPool` 아래 `DeathFX0~7` 이
   **미리 배치되어 있는지** 확인한다.
   기대: 게임을 오래 돌려도(Remote 트리 기준) 이 개수가 늘지 않는다.

### C. S2 상태이상 VFX

7. `불`(ㅂ ㅜ ㄹ)을 완성해 화상을 해금한다.
8. 몬스터를 한 번 클릭하고 **죽이지 말고 지켜본다**.
   기대: 자모 **머리 위(StatusEffectAnchor 높이)에서 작은 주황색 ember 입자가
   천천히 위로 피어오른다.** 불기둥처럼 크지 않다. 화면이 하얗게 번지는 Bloom 이 없다.
9. 화상이 끝날 때까지(또는 몬스터가 죽을 때까지) 기다린다.
   기대: 화상이 끝나는 순간 **ember 가 멈춘다.** 죽은 뒤에도 남아 있으면 FAIL.
10. `금`(ㄱ ㅡ ㅁ)을 완성해 황금 개체를 해금하고, 황금 ㅎ 가 나올 때까지 기다린다.
    기대: 황금 개체 주위에 **아주 작은 옅은 금색 sparkle 이 상시 반짝인다.**
    과도한 Bloom / 눈부심이 없다.

### D. S3 에너지 피드백

11. 클릭할 때마다 상단 **ENERGY 패널을 본다**.
    기대: 클릭할 때마다 **패널이 아주 짧게 커졌다 돌아온다** (pulse).
12. 에너지를 **3 이하**로 줄인다.
    기대: ENERGY 패널 아래에 **"⚠ 에너지 부족" 텍스트가 나타나 깜빡인다.**
    동시에 게이지 색이 붉게 물든다. **색만이 아니라 글자와 깜빡임이 함께 온다.**
13. 에너지를 0으로 만든다.
    기대: **즉시 멈추지 않는다.** 약 0.8초 동안 남은 화상 틱과 마지막 처치가 정산된 뒤
    화면이 어두워지고(Dim) Day Complete 패널이 뜬다.
    "⚠ 에너지 부족" 은 0 이 되는 순간 사라진다(0 은 경고가 아니라 종료다).
14. `resources/balance/game_balance.tres` 를 Inspector 에서 열어
    **`Low Energy Warning` 값을 6 으로 바꾸고** 게임을 다시 실행한다.
    기대: 에너지 6 부터 경고가 뜬다. **확인 후 값을 3 으로 되돌린다.**

### E. S4 단어 완성 연출

15. 자모를 모아 아무 단어나 완성한다(가장 빠른 것은 `밥` = ㅂ ㅂ ㅏ).
    기대 순서:
    1) 화면 중앙을 둘러싼 **원 위에 필요한 자모가 큼직하게 나타난다**
    2) 자모들이 **하나씩 시차를 두고 중앙으로 빨려 들어가며 사라진다**
    3) 중앙에서 **완성 패널이 작게 나타났다 튀듯 커지며(overshoot) 자리를 잡는다**
    4) 그 순간 **뒤쪽 3D 화면이 살짝 확대됐다가 천천히 되돌아온다** (카메라 Zoom)
    5) UI Sting 사운드는 **나지 않는다** (오디오 애셋 없음)
16. 단어를 하나 더 완성하고, **자모가 중앙으로 모이는 도중에 마우스를 클릭**한다.
    기대: **집결 연출이 즉시 끝나고 완성 패널이 바로 나온다.** 단어/자모/설명 텍스트가
    정상이다. Enter(ui_accept) 로도 같아야 한다.
17. 한 번에 두 단어가 동시에 완성되는 상황을 만든다(예: `불` 과 `밥` 재료를 같이 모은 뒤 마지막 자모 획득).
    기대: 첫 단어 연출 → 확인 → **두 번째 단어도 집결 연출부터 다시 재생**된다.
18. 에디터에서 `scenes/ui/word_complete.tscn` 을 연다.
    기대: Inspector 에 `Gather Seconds` / `Gather Stagger` / `Gather Radius` /
    `Gather Start Angle` 이 보이고 값을 바꿀 수 있다. `RevealAnim` 의 `reveal`
    애니메이션을 타임라인에서 재생해 볼 수 있다.

### F. S5 MotionProfile 별 Step SFX

19. 에디터에서 `resources/motion_profiles/heavy_step.tres` 를 Inspector 로 연다.
    기대: **Audio 그룹에 `Step Sfx Path` 가 보이고** `res://art/audio/sfx/step_heavy.ogg` 다.
20. 같은 방식으로 `light_step` / `bounce` / `roll` / `glide` 를 확인한다.
    기대: 각각 `step_light` / `step_bounce` / `step_roll` / `step_glide` 로 **서로 다르다**.
21. 에디터에서 아무 몬스터 씬(예: `scenes/monsters/monster_giyeok.tscn`)을 열고
    `AnimationPlayer` 에서 `walk_light_step` 을 선택한다.
    기대: 트랙 목록 맨 아래에 **`play_step_sfx` 를 호출하는 Call Method 트랙**이 있고
    타임라인에 키가 찍혀 있다.
22. 게임을 실행해 몬스터들이 걸어다니는 동안 **콘솔에 에러가 올라오지 않는지** 본다.
    기대: 발소리 파일이 없으므로 **무음이고, 에러도 경고도 없다.**

### G. S6 AudioManager / 설정

23. 게임에서 상단 **설정 아이콘**을 누른다.
    기대: 설정 패널에 **마스터 / 음악 / 효과음** 3개 슬라이더가 있고, 오른쪽에
    **퍼센트 숫자**가 표시된다(기본 100%).
24. **효과음 슬라이더를 50% 로** 내린다.
    기대: 옆 숫자가 **50%** 로 즉시 바뀐다.
25. 설정을 **닫고, 게임을 완전히 종료한 뒤 다시 실행**해 설정을 다시 연다.
    기대: **효과음이 50% 로 유지**되어 있다(세이브에 포함됨).
26. 에디터 하단 **Audio 패널**을 연다.
    기대: **Master / BGM / SFX 3개 버스**가 보인다. 코드가 아니라
    `default_bus_layout.tres` 에서 온다.
27. 에디터에서 `resources/audio/sfx_library.tres` 를 Inspector 로 연다.
    기대: `Click` / `Click Critical` / `Click Golden` / `Kill` / `Word Complete` / `Bgm`
    슬롯이 보이고 파일을 지정할 수 있다. **현재는 전부 비어 있다.**
28. 마스터 슬라이더를 **0% 로** 내린다.
    기대: 에디터 Audio 패널에서 Master 버스가 **음소거**된다(값이 아주 작은 소리가 아니라 mute).

### H. 회귀 (F1~F5)

29. Day 1 → 에너지 소진 → Day 요약 → 자모 선택(리롤 포함) → 단어 확인 → 상점 → Day 2 까지
    한 바퀴 돈다. 기대: 막힘 없이 진행된다.
30. 마우스를 쓰지 않고 **Tab 만으로** 상단바 버튼(트리/설정/일시정지)에 포커스가 가는지 확인한다.
    기대: F5 와 동일하게 동작한다. 트리를 닫으면 포커스가 상단바로 돌아온다.
31. 몬스터 20마리 가까이 채워진 상태에서 화면 가장자리를 본다.
    기대: 자모가 **종이 밖으로 삐져나오지 않는다** (아레나 클램프 회귀).
32. 단어 트리에서 Target 을 지정하고 HUD 하단을 본다.
    기대: `TARGET: <단어>` 와 `[ㅂ][ㅜ][ ]` 슬롯이 F5 와 동일하게 나온다.

---

## 3. 주의 / 보류 사항

### 3.1 오디오 애셋이 저장소에 하나도 없다 (가장 중요)

- `art/audio/` 아래에 **`.ogg` / `.wav` / `.mp3` 파일이 단 한 개도 없다.** 태스크 지시대로
  **만들지 않았다.**
- 따라서 **이번 사이클에서 추가한 모든 소리는 실제로는 들리지 않는다.**
  클릭 / 치명 / 황금 / 처치 / 단어 완성 sting / 발소리 5종 / BGM 전부 무음이다.
- 이것은 **버그가 아니라 의도된 상태**다. 경로만 연결해 두고, 파일이 없으면
  `AudioManager._stream_for()` 가 `ResourceLoader.exists()` 로 먼저 확인한 뒤
  **조용히 null 을 캐시**한다. **로드 에러도 경고도 나오지 않는다.**
  (`tests/test_game_loop.gd` 의 `_test_missing_audio_files_are_skipped` 가 이것을 검증한다.)
- 파일을 넣기만 하면 바로 소리가 난다. 기대 경로/파일명은 `art/audio/sfx/README.txt` 에 있다.
  - Step: `res://art/audio/sfx/step_{heavy,light,bounce,roll,glide}.ogg`
    (`resources/motion_profiles/*.tres` 의 `step_sfx_path`)
  - Click/UI: `resources/audio/sfx_library.tres` 의 6개 슬롯을 Inspector 에서 지정
- **QA 는 "소리가 안 난다" 를 FAIL 사유로 삼지 말 것.** 확인해야 하는 것은
  "무음이면서 에러가 없다" 이다.

### 3.2 스펙과 다르게 처리한 부분

- **v0.3 §21.2 의 `AudioStreamPlayer3D`(몬스터별 3D 오디오)를 쓰지 않았다.**
  대신 `AudioManager` 의 비위치형 `AudioStreamPlayer` 풀 8개로 재생한다.
  이유: 이번 태스크의 성능 요구("오디오 인스턴스를 매 클릭 new 하지 말고 재사용")와
  "누락 시 조용히 넘어가라"를 한 군데에서 처리하기 위해서다. 위치별 패닝이 필요해지면
  다음 사이클에서 몬스터 씬에 `AudioStreamPlayer3D` 를 추가하고
  `play_step_sfx()` 의 호출 대상만 바꾸면 된다(호출 지점은 이미 애니메이션 트랙에 있다).
- **Damage Number 는 풀링하지 않았다.** 태스크의 성능 요구가 "파티클/오디오"를 지목했고,
  기존 QA 하니스(`tests/qa_critical_play.gd`)가 `FXRoot` 의 동적 자식에서 최신
  데미지 숫자를 찾는 구조라서 깨뜨리지 않으려고 그대로 두었다.
  파티클(HitFX/DeathFX)과 오디오는 전부 풀링했다.
- **`hit_fx.tscn` / `death_fx.tscn` 에서 자체 `Lifetime` 타이머와 `queue_free` 를 제거**했다.
  이제 풀 인스턴스로 살아 있고 `restart()` 로 재발사된다. 두 씬을 다른 곳에서
  `instantiate()` 하던 코드는 없었다(`game_world.gd` 가 유일했다).

### 3.3 하위 호환

- **기존 세이브 파일에 `audio` 키가 없다.** 이 경우 볼륨은 전부 기본값(100%)으로
  시작한다. 실패하지 않는다. `audio` 값이 Dictionary 가 아닌 손상 세이브도
  기본값으로 넘어간다.
- `save_version` 은 **1 그대로 두었다.** 추가된 섹션이 선택적이라 버전을 올릴 이유가 없다.
- 전체 화면(fullscreen) 설정은 **이전과 마찬가지로 저장되지 않는다.** 이번 범위 밖이다.

### 3.4 기존 이슈 / 미해결

- `res://art/fonts/NotoSansKR-Regular.ttf` 누락 에러 2줄은 **기존 이슈**이며 이번에
  건드리지 않았다.
- `tests/qa_f3_play`, `qa_f4_hud`, `qa_f4_special`, `qa_f5_arena`, `qa_f5_tree` 등
  **"Run windowed, it needs rendering" 이라고 스스로 명시한 QA 하니스는 headless 로
  돌리면 끝나지 않는다.** 이것은 이번 변경 이전에도 동일하다
  (`git stash` 로 원본 트리에서 `qa_f3_play` 를 돌려 확인했고,
  `qa_f3_play: could not land a click on any monster` 로 같은 지점에서 멈춘다).
  이 하니스들은 ziva-godot MCP 로 창을 띄운 상태에서 돌려야 한다.
- 헤드리스에서 실제로 통과를 확인한 것: `tests/test_game_loop.tscn`,
  `tests/test_day_flow.tscn`, `tests/qa_f3_compat.tscn`, `tests/qa_f3_pool.tscn`,
  `tests/qa_f5_margin_ab.tscn`.
- **60 FPS 20마리 유지**는 창을 띄워야 실측할 수 있다. 코드 쪽에서는 파티클/오디오의
  런타임 할당을 없앴고, 프레임마다 도는 새 루프는 추가하지 않았다. 실측은 QA 몫이다.

### 3.5 다음 사이클로 미룬 것

1. 오디오 애셋 제작/도입 (위 3.1)
2. 몬스터별 3D 위치 오디오 (위 3.2)
3. Damage Number 풀링
4. Poison / Electric / Bleed / Ice 상태이상 VFX — 해당 단어가 아직 없어서 데이터가 없다
   (v0.3 §24). 이번에는 Fire(ember)와 Gold(sparkle)만 구현했다.
5. BGM 트랙 자체. 버스와 `BgmPlayer`, `AudioLibrary.bgm` 슬롯은 준비되어 있다.
