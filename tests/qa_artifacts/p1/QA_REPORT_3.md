# JAMO P1-QA-3 — 문장핵 애셋 연결 검증 — QA 리포트 3

**판정: PASS**

근거: 문장핵이 실제 게임에서 **책 + 한지 낱장 모델**로 그려지고, 임시 프리미티브
(`Pillar` / `Cap`)는 씬·코드 어디에도 남아 있지 않다. 피격은 눈에 보이고, **반복 피격 8회
(절반은 애니메이션을 끊음) 후에도 모델의 9개 서피스 색이 한 개도 변하지 않았다** — 공유
재질 오염 0. `reach_radius 1.1` 은 실측상 몬스터를 **책 폭 바깥 0.12~0.13 m** 에서 걷어내
겹침도 조기 소멸도 없다. P1 본체 회귀와 전체 회귀는 전부 유지된다.

- 검증 환경: Godot 4.7.stable.official (5b4e0cb0f), Windows 11, Intel UHD Graphics 770,
  Vulkan 1.4.323 / Forward+.
- **헤드리스만으로 판정하지 않았다.** ziva-godot MCP 로 에디터에 `sentence_core.tscn` 을 열어
  3D 뷰포트와 씬 트리를 눈으로 확인했고, 같은 세션에서 `main.tscn` 을 **라이브로 실행해 실제
  마우스 클릭 18회**를 넣어 Wave 2 까지 플레이했다. 창 모드 하네스 12종이 이를 보조한다.
- **프로덕션 코드는 DEV 가 남긴 그대로다.** QA 가 추가한 것은 `tests/` 아래 신규 하네스
  2파일과 스크린샷뿐이다 (8절).

> 태스크 지시의 `mcp__ziva-godot__start_godot` 툴은 이 환경의 ziva-godot 서버에 **존재하지
> 않는다.** 대신 이미 이 프로젝트를 연 채 붙어 있는 에디터(PID 64728)에 `open_scene` /
> `get_scene_tree` / `get_screenshot` / `run_scene` 으로 접속해 §4 3·4번을 충족했다.
> 09-10 자 헤드리스 godot 프로세스 3개(PID 40896 / 47052 / 53240)는 **건드리지 않았다.**

---

## 0. 요약표

| 구분 | 항목 | 결과 |
|---|---|---|
| **A** | 문장핵 애셋 연결 (1~4) | **PASS** |
| **B** | 피격 표현 (5~8) | **PASS** |
| **C** | `reach_radius` 조정 (9~10) | **PASS** |
| **D** | LOW 이월 (11~12) | **PASS** |
| **E** | P1 본체 회귀 (13~19) | **PASS** |
| **F** | 전체 회귀 (20~22) | **PASS** |

신규 결함: **CRITICAL 0 / HIGH 0 / MEDIUM 0 / LOW 4** (7절). LOW 4건 중 3건은 DEV 의
증거·하네스 쪽 문제이고 1건은 §46 교체 계약의 잔여 리스크다. 게임 동작 결함은 0건이다.

---

## A. 문장핵 애셋 연결

### A-1. 실제 게임에서 책+한지 모델로 보이는가 — PASS

에디터에서 `main.tscn` 을 **라이브 실행**해 눈으로 봤다. 슬랩 위쪽 꼭짓점 안쪽에 펼친
고서가 놓이고, 그 위에 세로로 선 종이에 `문`(ㅁ+ㅜ+ㄴ) 먹 글씨, 오른쪽 앞에 붉은 인장이
보인다. **실린더+큐브는 없다.**

프리미티브가 남아 있지 않다는 것을 3중으로 확인했다.

```
1) 씬 데이터   scenes/objective/sentence_core.tscn 의 VisualRoot 자식은 Model 하나뿐
2) 런타임      core.visual_root.find_child("Pillar"/"Cap") == null   (qa_p1_core_asset)
3) 전체 검색   grep -rn "Pillar|\"Cap\"|/Cap" --include=*.gd --include=*.tscn --include=*.tres
               → 프로덕션 0건 (히트는 전부 tests/qa_p1_core_asset.gd 의 단언문)
```

에디터 씬 트리(`get_scene_tree`):

```
SentenceCore (Node3D, script sentence_core.gd)
├─ VisualRoot (Node3D)
│  └─ Model (Node3D, instanced_from res://art/objective/sentence_core.glb, 자식 7)
│     ├─ Binding / BindingThread / BookPages / CoreInk / CorePaper / Seal / SentenceInk
├─ HitAnchor (Marker3D)
└─ AnimationPlayer
```

애셋 README 3절이 약속한 파츠 이름 7개가 그대로 살아 있다.

증거: `core_asset/00_core_idle.png` (문장핵 20/20, 아이들),
`core_qa3/10_reach_field.png`, 에디터 3D 뷰포트 캡처(본 리포트 작성 세션).

### A-2. 3/4 직교 카메라 실루엣 / 슬랩 안 / 접근 경로 — PASS

**눈으로 판정.** 3/4 직교 시점에서 책의 가로 실루엣과 그 위에 수직으로 선 종이가 확실히
갈라져 읽힌다. 몬스터(ㅇ 지름 ~1.0 unit)와 비교해 확연히 크고, "지켜야 할 것" 으로 읽힌다.
`CoreInk`(먹 글씨)가 종이 위에 남아 `문` 이 계속 판독된다.

슬랩 안 배치는 실측으로도 맞다.

```
world bounds: pos=(-0.9525, 0.0, -2.83)  size=(1.905, 1.47, 1.26)
footprint corner |x|+|z| max 3.78 of 3.96      (여유 0.18)
```

접근 경로: 20마리 동시 필드(`core_asset/95_full_field_20.png`)와 Wave 진행 캡처
(`core_qa3/22~25_wave*.png`)에서 앞·좌·우 스폰에서 오는 개체가 **책을 돌아가거나 책 위로
겹쳐 서는 장면이 없다.** 책은 슬랩 뒤쪽 꼭짓점 근처에 있고 그 앞의 마름모 전체가 비어
있어 보행 레인을 막지 않는다. `monsters outside their walkable diamond: 0` (`qa_p1_play`).

### A-3. 에디터에서 `Model` 이 교체 가능한 노드인가 (§46) — PASS

```
Model class=Node3D  scale=(0.75, 0.75, 0.75)
scene_file_path=res://art/objective/sentence_core.glb
```

- `Model` 은 평범한 **Node3D 인스턴스**이고 `.tscn` 에 `transform = Transform3D(0.75, …)` 가
  **노드 오버라이드로** 저장돼 있다 — 이것이 정확히 Inspector 에서 Scale 을 만졌을 때
  생기는 형태다. 씬 끝에 `[editable path="VisualRoot/Model"]` 가 있어 7개 파츠가 에디터
  트리에 펼쳐진다(위 A-1 트리가 그 결과다).
- **교체를 실제로 해 봤다.** `Model` 을 떼어내고 `MeshInstance3D`(BoxMesh)를 같은 이름으로
  붙인 뒤 `hit` 을 재생했다 → `VisualRoot:scale` 이 1 → 1.106 → 1.0, `position` 0 으로 복귀.
  **눌렸다 돌아오는 연출과 카메라 shake 는 교체 후에도 그대로 산다.** 잃는 것은 종이
  플래시 하나뿐이고, 그것도 크래시가 아니라 `_update_caches` 경고로 끝난다 (→ 7절 LOW-4).

### A-4. 스크립트가 `visual_root` 너머를 참조하지 않는가 — PASS

`scripts/objective/sentence_core.gd` 전문 46줄을 읽었다. 참조는 두 곳뿐이다.

```gdscript
@export var visual_root: Node3D              # :13
if visual_root == null:                      # :31  (null 경고만)
@onready var _animation: AnimationPlayer = $AnimationPlayer   # :26  (형제 노드)
```

`find_child` / `"CorePaper"` / `"VisualRoot/"` 같은 하위 경로 문자열이 **한 건도 없다**
(`grep -rn "visual_root|VisualRoot|CorePaper|find_child" scripts/`). 애셋 교체가 스크립트
때문에 깨지는 경로는 없다. **다만 씬 데이터(애니메이션 트랙)는 너머를 참조한다 → LOW-4.**

---

## B. 피격 표현

### B-5. 눈에 보이는 변화가 있는가 — PASS

**있다.** 서 있는 종이가 진사홍으로 번쩍이고, 책 전체가 옆으로 넓어지며 납작해졌다가
돌아온다. 상단 HUD 가 한 칸 줄어든다.

| 시점 | 캡처 | 보이는 것 |
|---|---|---|
| 전 | `core_asset/00_core_idle.png` | 미색 종이, `문장핵 20 / 20` |
| 중 | `core_asset/01_core_hit_flash.png` | 종이가 진사홍, 먹 글씨 `문` 은 검게 남음, 책 납작 |
| 후 | `core_asset/02_core_hit_recovered.png` | 미색 복귀, 책 원형 복귀 |
| 실전 | `core_asset/45_wave4_core_hit.png` | Wave 4 / `문장핵 15 / 20` / 플래시 + `ENERGY 0 / 10` |

플래시 색 실측: `albedo (0.86, 0.24, 0.16)` vs 종이 `(0.9163, 0.8323, 0.6726)`.
`materials/core_hit.tres` 는 진사홍 + `emission_energy_multiplier 0.6` 이고 월드 Environment
에 glow 패스가 없어 번지지 않는다 — 캡처에서 확인된다.

### B-6. 공유 재질 오염 — PASS (QA 신규 하네스 + negative control)

DEV 하네스는 **1회 피격**만 본다. 반복 피격은 QA 가 신규 `tests/qa_p1_core_qa3.tscn` 으로
직접 쟀다. **8회 연속 피격, 그중 홀수 회차는 애니메이션이 끝나기 전에 다음 피격으로
끊었다.**

```
-- A. repeated and interrupted hits
    before: paper (0.9163, 0.8323, 0.6726, 1.0) pages (0.8489, 0.7548, 0.6012, 1.0) ink (0.2294, 0.168, 0.1177, 1.0)
    8 of 8 hits raised a flash, 8 moved the shake pivot
    after:  paper (0.9163, 0.8323, 0.6726, 1.0) pages (0.8489, 0.7548, 0.6012, 1.0) ink (0.2294, 0.168, 0.1177, 1.0)
    9 part surfaces compared, 0 drifted
    fresh instance of the same GLB: paper (0.9163, 0.8323, 0.6726, 1.0) pages (0.8489, 0.7548, 0.6012, 1.0)
```

- 8회 전부 플래시가 올라오고 8회 전부 카메라 pivot 이 움직였다.
- 마지막(끊긴) 피격 뒤에도 `material_override == null`, `VisualRoot` scale/position 원위치.
- **모델의 9개 서피스 albedo 를 전부 스냅샷해 비교했고 0개가 변했다.** 표면 단위로 본 이유는
  아래 negative control 에서 드러났다.
- **같은 GLB 를 다시 인스턴스화한 사본**도 원색 그대로다. 공유 리소스가 변조됐다면 캐시된
  같은 `Material` 을 물고 나오므로 여기서 잡힌다.

**negative control (QA 가 직접 오염시켜 봄).** 하네스 안에서 README 3절이 경고한 방식
—`paper.get_active_material(0).albedo_color = Color.RED`— 을 한 줄 넣었다.

```
    after:  paper (1.0, 0.0, 0.0, 1.0) pages (0.8489, 0.7548, 0.6012, 1.0)
  FAIL: CorePaper is back on its own colour
    fresh instance of the same GLB: paper (1.0, 0.0, 0.0, 1.0) pages (...)
  FAIL: a fresh instance of the GLB still has the original paper colour
FAILED - 2 check(s) failed.                                          exit 1
```

이때의 화면 캡처에서 **책 펼친 페이지까지 통째로 붉어졌다.** 즉 GLB 안에서 `CorePaper` 의
재질이 `BookPages` 의 **두 번째 서피스**와 공유된다(9 surfaces / 6 materials). README 3절이
문자 그대로 지시한 "`get_active_material(0)` 을 `duplicate()` 해서 쓴다" 도 위험했고,
**DEV 가 택한 별도 `core_hit.tres` + `material_override` 는 이 경로가 구조적으로 막힌다.**
DEV 의 설계 판단이 옳았다. (그 오염 캡처는 증거로 남기지 않고 원복 후 재생성했다.)

### B-7. 카메라 shake — PASS

`take_hit()` 경로 그대로다: `RunState.damage_core` → `hit` 재생 → `camera_rig.shake(0.06, 0.2)`.
8회 피격 전부에서 `ShakePivot.position != Vector3.ZERO` 를 관측했다(8/8). `sentence_core.tscn`
의 `hit_shake_strength = 0.06` / `hit_shake_duration = 0.2` 도 F6/P1 확정값 그대로다.

### B-8. HP 구간별 손상 표현을 §41 로 미룬 것 — **타당하다** (FAIL 사유 아님)

**동의한다.** 근거:

1. 애셋에 균열/파손 단계 모델이 없다(README 3절 명시). 지금 가능한 것은 `CoreInk` 숨김이나
   종이 어둡히기뿐인데, `CoreInk` 를 숨기면 **`문` 이 안 읽혀 오브젝트의 정체성이 사라진다.**
   종이만 어둡히면 "손상" 이 아니라 조명 버그처럼 보일 위험이 크다. DEV 판단 그대로다.
2. §41 은 VFX·타이포그래피가 품질을 좌우한다고 못박는다. 손상 단계는 파티클/셰이더와
   한 묶음으로 설계돼야 일관되게 나온다.
3. 지금도 **정보 손실이 없다**: HUD 상단 `문장핵 N / 20` 게이지가 상시 노출되고 매 피격마다
   플래시 + shake 가 나온다. 색만으로 정보를 전달하지 않는다.

**추가 의견 (P2+ 권고, 이번 FAIL 아님).** 구조는 이미 열려 있다 — `SignalBus.core_hp_changed`
가 있고 `HitAnchor(0, 1.1, 0)` 가 비어 있다. 다만 **`HitAnchor` 의 y 가 새 모델과 맞지 않는다**:
scale 0.75 에서 `문` 종이 중심은 y ≈ 0.95 다. §41 에서 VFX 앵커로 쓸 때 y 를 0.95 로 내리는
것을 같이 처리하기를 권한다. DEV 도 주의 8번에 같은 취지를 적어 뒀고, 지금은 참조하는
코드가 없어 동작에 영향이 없다.

---

## C. `reach_radius` 조정

### C-9. 0.9 → 1.1 이 타당한가 — PASS (실플레이 실측)

신규 하네스가 **클릭을 한 번도 넣지 않고** 한 Wave 분량의 몬스터가 걸어 들어오는 것을
프레임마다 재, 개체별 최근접 거리를 모았다. 3회 반복 실행, 전부 같은 값대다.

```
    book footprint 1.90 x 1.26 m, reach_radius 1.10
    8 monster(s) got inside reach; closest centre 1.07~1.08 m from the core
    worst centre overlap past the book's widest half extent 0.95 m: -0.12 ~ -0.13 m
```

- **겹침 없음**: 도달한 8마리 중 가장 깊이 들어온 개체의 중심도 코어에서 1.07 m 로,
  책의 최대 반폭 0.95 m **바깥 0.12 m** 에서 사라졌다. 책 앞면(반깊이 0.63 m)을 파고든
  개체는 0마리다. `_is_at_objective()` 는 y 를 0 으로 눌러 **수평 반경**으로 재므로
  (`jamo_monster.gd:279~282`) 높이가 판정을 왜곡하지 않는다.
- **너무 멀리서 사라지지도 않는다**: 최대 여유가 책 앞면 기준 0.47 m 인데, 이는 몬스터
  본체 반폭(ㅇ 지름 ~1.0 → 반폭 ~0.5)보다 작다. 즉 화면상으로는 **몬스터가 책에 닿은
  그림**이 되고, 허공에서 증발하지 않는다. 캡처 `core_asset/45_wave4_core_hit.png` 에서
  ㅅ 이 책 왼쪽 가장자리에 붙은 채 플래시가 터지는 장면이 그것이다.
- 반경을 키운 방향은 안전하다. 반경이 커지면 **더 일찍** 닿을 뿐이고, `qa_p1_lockhunt` 는
  `core.reach_radius + 0.3` 을 동적으로 읽어 그대로 통과한다.

> 잔여 기하 (LOW 미만, INFO): 도달 판정은 **원**이고 책 발자국은 1.90 × 1.26 **사각형**이다.
> 대각선 방향의 책 모서리까지 거리는 √(0.95² + 0.63²) = 1.14 m 로 반경 1.1 보다 0.04 m 크다.
> 이론상 정확히 모서리 방향으로 들어오는 개체가 4 cm 겹칠 수 있다. 실측 3회에서 관측된
> 최근접은 1.07 m 라 실제로는 발생하지 않았고, 4 cm 는 이 카메라에서 1 px 미만이다.

### C-10. `@export` 노출 상태 — PASS

```gdscript
@export_range(0.1, 3.0, 0.05) var reach_radius: float = 0.9     # sentence_core.gd:16
```

`.tscn` 이 `reach_radius = 1.1` 로 덮어쓴다 — 스크립트 기본값 0.9 는 그대로 두고 씬에서
조정하는 형태라 §46 "Inspector Export" 원칙에 맞다. 하드코딩 0건.

---

## D. LOW 이월

### D-11. `spawn_manager.gd:358` 삼항 타입 경고 — PASS (사라짐)

수정 후 코드:

```gdscript
String(monster.monster_data.id) if monster.monster_data != null else "?",   # :358
```

양쪽이 `String` 이라 타입이 맞는다. **에디터 출력으로 확인했다** — 라이브 에디터의
GDScript 경고 목록(`get_godot_errors`)에는 `signal_bus.gd` 의 미사용 시그널 13건과
`wave_controller.gd:60` 의 `await` 경고만 있고 **`spawn_manager` 항목이 없다.**
`godot --headless --path . --editor --quit` (전체 스크립트 재파싱) 로그에도
`ternary` / `spawn_manager` 히트 0건, 에러는 폰트 2줄뿐이다.

> 참고: DEV 주의 10번의 `addons/ziva_agent` GDExtension DLL 복사 에러 4줄은 **이번 실행에서는
> 재현되지 않았다** (`--headless --editor --quit` 에러 2줄 = 폰트뿐).

### D-12. `max_energy.tres` 11~20 유지 — PASS (값 확인만, 변경 요구 없음)

```
costs  = PackedInt64Array(6, 12, 20, 35, 60, 110, 200, 350, 620, 1100)
values = PackedFloat32Array(11, 12, 13, 14, 15, 16, 17, 18, 19, 20)
```

**총지휘자 확정대로 11~20 그대로다.** `git status` 상 `resources/upgrades/max_energy.tres`
는 이번 사이클에 **수정되지 않았다.** 변경을 요구하지 않는다.
상점 회귀도 유지 — `qa_p1_resume_econ` 의 `5 of 6 tracks listed`, `문장핵` 행 없음.

---

## E. P1 본체 회귀

### E-13. 상태 기계 잠금 방지 — PASS (기존 2종 + **QA 직접 유발**)

기존 하네스:

```
qa_p1_stall     exit 0  | OK - Wave 5 cleared on its own after 0 frames.
qa_p1_lockhunt  exit 0  | OK - no click in any state parked a monster; every wave cleared itself.
```

**QA 가 직접 넣은 잠금 시도** (신규 `qa_p1_core_qa3` C절). 새 문장핵 위치(z -2.2)와 새
`reach_radius` 위에서, **문장핵 HP 를 고정해 놓고**(= 클릭이 Wave 를 해소하는 수단이 될 수
없게) 모든 개체의 **SPAWN / TURN 진입마다 비치명 클릭**을 넣었다. HP 1 남은 개체는 클릭하지
않는다 — Wave 는 **오직 몬스터가 스스로 걸어 문장핵에 닿아야만** 끝난다.

```
    non-lethal clicks by state: { "SPAWN": 37, "TURN": 21 }
    waves cleared: [2, 3, 4, 5, 6] in 3242 frames
    field at the end: 0 alive
```

3회 연속 실행(3242 / 3587 / 3159 프레임) 전부 5개 Wave 자력 Clear, 종료 시 생존자 0,
`SpawnManager: ... never resolved` **0건**. 잠김 0.

> 한 번(budget 8000 프레임이던 시점) Wave 6 이 예산 안에 안 끝나고 1마리가 남은 실행이
> 있었다. **stall 경고는 뜨지 않았고**(= 30초 이상 미해소가 아님) 검수 범위인 Wave 1~5 는
> 그 실행에서도 전부 Clear 됐다. 예산을 20000 으로 올린 뒤 3회 전부 정상이며, 하네스에
> **생존자가 걸었는지 박혔는지 구분하는 진단**(개체별 이동 거리, 0.5 m 미만이면 FAIL)을
> 추가해 두었다. 잠금이 아니라 Wave 6 진행 속도 편차다.

### E-14. 에너지 0 이어도 Wave 계속, 결과 화면 안 뜸 — PASS

```
    wave | count | hp | energy | clicks | kills | core lost | core left | cleared
       3 |     8 |  2 |     10 |     10 |     5 |         3 |        17 | true
       4 |     9 |  2 |     10 |     10 |     5 |         5 |        12 | true
       5 |    10 |  3 |     10 |     10 |     3 |         7 |         5 | true
```

Wave 3·4·5 모두 클릭 10회(= 에너지 소진) 뒤에도 Clear 까지 진행했다.
`test_wave_combat` 의 `energy 0 ends nothing` 블록 FAIL 0. **눈으로도 확인** —
`core_asset/45_wave4_core_hit.png` 에 `ENERGY 0 / 10` + 붉은 `수동 클릭 불가 — WAVE 는
계속된다` 문구가 떠 있고 결과 화면은 없다.

### E-15. 문장핵 0 이 유일한 실패 조건 / 부제 — PASS

`qa_p1_play`: Wave 6 에서 `core left 0` 일 때만 `cleared false`.

```
subtitle: 문장핵이 무너졌다. 다음 RUN 은 WAVE 1 부터 시작한다.
```

`test_run_flow` / `test_wave_combat` 도 동일 결론(`the core is the only failure`).

### E-16. 실패해도 RUN Gold 가 MetaState 에 남음 — PASS

```
result: 도달 WAVE  6 | 처치  27 | 획득 GOLD  71 G  (유지됨)
banked gold after the defeat: 71.10, highest wave 6
```

### E-17. 보행 6종 구별 — PASS

`qa_p1_gait` 실측. 상태 기계·애셋 변경이 걸음을 뭉개지 않았다.

```
    jamo         profile      walk animation    scale      m/s    bob m  idles  turns
    digeut       heavy_step   walk_heavy_step    0.75     0.95    0.036      1      1
    mieum        bounce       walk_bounce        0.90     0.90    0.062      1      1
    ieung        roll         walk_roll          1.10     1.45    0.018      1      1
    siot         light_step   walk_light_step    1.50     1.55    0.014      1      1
    giyeok       sway         walk_sway          1.00     1.19    0.030      1      1
    i            upright      walk_upright       1.60     1.49    0.016      1      1
    6 distinct walk animations, speed spread 0.65 m/s, bob spread 0.048 m
```

QA-2 표와 소수 둘째 자리까지 사실상 동일(ㅇ 1.42→1.45 등 측정 노이즈 범위). 애니메이션 6종,
속도 분산, **수직 bob 진폭이 살아 있고 서로 다르다**(ㅁ 0.062 가 최대, ㅅ 0.014 가 최소).
`resources/motion_profiles/` · `resources/animations/` · `scenes/monsters/` 는 이번 사이클에
한 글자도 바뀌지 않았다(`git status`).

### E-18. Wave 1~5 를 실제 클릭으로 끝까지 플레이 (§48 Phase 1 완료 기준) — PASS

세 경로에서 확인했다.

| 경로 | 입력 | 결과 |
|---|---|---|
| `qa_p1_play` (창 모드) | 실제 `InputEventMouseButton` 52회 | **Wave 1~5 전부 `cleared true`**, Wave 6 에서 문장핵 0 → 결과 화면 → 허브 |
| `qa_p1_core_asset` (창 모드, 신 모델) | 실제 클릭, Wave 당 에너지 전량 | Wave 1~4 `true`, **Wave 5 에서 문장핵 0** (→ LOW-1/LOW-2) |
| **에디터 라이브 플레이** (ziva-godot) | **실제 마우스 클릭 18회, 전부 delivered** | 14초에 Wave 2 도달, `문장핵 17 / 20`, `73 G`, `처치 2`. 멈춰 선 개체 0, stall 경고 0 |

§48 Phase 1 의 기준은 "Wave 1~5를 플레이할 수 있다" 이고, **세 경로 모두 Wave 5 까지
잠김 없이 플레이된다.** `qa_p1_core_asset` 에서 Wave 5 중 패배하는 것은 그 하네스의 클릭
정책이 더 빡빡해서지(가장 앞선 개체만 타겟, 자체 피격 테스트로 HP 1 선실점) 잠김이 아니다.
같은 사이클의 `qa_p1_play` 누수 곡선(W3 3 / W4 5 / W5 7 / W6 5)은 QA-2(3 / 4 / 8 / 5)와
총합 20 으로 같아 **밸런스 회귀는 없다.**

### E-19. 20마리 + 새 모델에서 60 FPS — PASS

```
[qa_p1_core_asset]  20 alive: avg 60.0 FPS, min 60.0, low 1 pct 60.0
[qa_p1_play]        20 alive: avg 60.0 FPS, min 60.0, low 1 pct 60.0
                    monsters outside their walkable diamond: 0
```

DEV 보고(avg/min 60.0)와 일치. 새 모델은 2,780 삼각형 / 9 서피스 / 그림자 포함이다.
애셋 README 가 "20마리 동시 60 FPS 는 미실측" 으로 남긴 항목이 **이로써 닫힌다.**

---

## F. 전체 회귀

### F-20. 허브 규칙 / State 분리 / 마이그레이션 / 클램프 — PASS

| 항목 | 결과 | 근거 |
|---|---|---|
| Main Hub 판때기 규칙 (F7~F9) | PASS | `qa_p0_plates_all`: `one bright plate across all 7 hub plates, 178 pointer/keyboard frames at 4 sizes x 2 save states, focus released -> 0 lit in 8/8` |
| State 분리 | PASS | `test_state_split`: `MetaState 10 state fields, RunState 17`, 겹침 0 |
| v0.3 세이브 마이그레이션 | PASS | `qa_p0_flow`: `a real v0.3 save file is opened, not thrown away` |
| 마이그레이션 안내문 대비 | PASS | `notice contrast: … -> 12.44:1 (13776 px)` — WCAG AA 초과 |
| 아레나 클램프 | PASS | `qa_p1_play` 20마리 동시: `monsters outside their walkable diamond: 0` |
| 허브→RUN→결과→허브 (§4-5) | PASS | `qa_p0_flow` / `test_run_flow` |

### F-21. `godot --headless --path . --quit` — PASS

```
ERROR: Resource file not found: res://art/fonts/NotoSansKR-Regular.ttf (expected type: unknown)
ERROR: Error loading custom project font 'res://art/fonts/NotoSansKR-Regular.ttf'
EXIT=0
```

폰트 누락 2줄 외 에러 0. 애셋 관련 에러 0.

### F-22. 헤드리스 7종 + 창 모드 8종 — 전부 exit 0

**전부 한 번에 하나씩 돌렸다** (`user://jamo_save.json` 공유).

헤드리스 7종:

| 테스트 | exit | 마지막 줄 |
|---|---|---|
| `test_state_split` | 0 | `OK - meta/run split holds.` |
| `test_run_flow` | 0 | `OK - Wave 1 started, the core fell, and the hub came back.` |
| `test_wave_combat` | 0 | `OK - waves run on data, energy 0 ends nothing, the core is the only failure.` |
| `test_monster_state` | 0 | `OK - no state parks a clicked monster, and the probe can tell a parked one.` |
| `qa_p1_stall` | 0 | `OK - Wave 5 cleared on its own after 0 frames.` |
| `qa_p1_negctl` | 0 | `OK - the DoT-at-energy-0 claim survives its negative control.` |
| `qa_p1_lockhunt` | 0 | `OK - no click in any state parked a monster; every wave cleared itself.` |

7종 전부 `FAIL` 문자열 0건, `never resolved` 0건.

창 모드 8종(신규 `qa_p1_core_asset` 포함):

| 하네스 | exit | 비고 |
|---|---|---|
| `qa_p0_flow` | 0 | 허브→RUN→결과→허브, 이어하기, v0.3 마이그레이션, 안내문 대비 12.44:1 |
| `qa_f7_title` | 0 | |
| `qa_f7_art` | 0 | letterbox WARN 6줄 — 기존 항목 (→ 7절 LOW-기존) |
| `qa_f8_labels` | 0 | |
| `qa_f8_focus_all` | 0 | `focus indicator meets 3.0:1` |
| `qa_f8_resize` | 0 | |
| `qa_p0_plates_all` | 0 | |
| **`qa_p1_core_asset`** | 0 | 신규. 2회 실행 모두 exit 0 |

추가로 돌린 창 모드 4종도 전부 exit 0: `qa_p1_play`, `qa_p1_gait`, `qa_p1_resume_econ`,
**`qa_p1_core_qa3`(QA 신규, 3회 연속 exit 0)**.

---

## 7. 결함 요약

게임 동작 결함 **0건**. 아래 4건은 전부 LOW 이며 증거·하네스·문서 쪽이다.

| 심각도 | 항목 | 위치 |
|---|---|---|
| **LOW-1 (신규)** | **DEV 인계문 §2-2 의 기대 출력이 실제와 다르다.** 인계문은 `wave log 1~5 전부 cleared true, 6 에서 false` 라고 적었는데, QA 가 같은 하네스를 2회 돌린 결과는 **두 번 다 Wave 5 가 `cleared false`**(문장핵 0 이 Wave 5 에서 온다). 재현: `godot --path . res://tests/qa_p1_core_asset.tscn`. 기대(인계문): W5 true / W6 false. 실제: 1회차 W3 -3 / W4 -6 / W5 -10 → 0, 2회차 W3 -5 / W4 -8 / W5 -6 → 0. **하네스는 Wave 5 를 단언하지 않으므로 exit 0 이라 이 불일치가 드러나지 않는다.** 후속 QA 가 이 줄을 합격선으로 쓰면 오판한다 | `tests/qa_artifacts/p1/DEV_HANDOFF_3.md:50` |
| **LOW-2 (신규)** | `qa_p1_core_asset.gd:75` 가 `for wave in range(1, TARGET_WAVE)` 라 **Wave 1~4 만 Clear 를 단언하고 Wave 5 는 단언하지 않는다.** §48 Phase 1 완료 기준이 Wave 1~5 이므로 기준의 마지막 한 칸을 이 하네스가 못 지킨다. `range(1, TARGET_WAVE + 1)` 이면 닫힌다(그러면 현재 상태에서 FAIL 이 나므로 클릭 예산 조정이 함께 필요하다). 지금은 `qa_p1_play` 와 QA 신규 `qa_p1_core_qa3` 가 메운다 | `tests/qa_p1_core_asset.gd:75` |
| **LOW-3 (신규)** | `core_asset/60_wave6_start.png` · `65_wave6_core_hit.png` 가 **현재 코드가 만들지 않는 낡은 캡처**다(QA 실행 2회 모두 Wave 5 에서 RUN 이 끝나 Wave 6 캡처가 갱신되지 않는다). 증거 폴더에 옛 실행 결과와 새 실행 결과가 섞여 있다 | `tests/qa_artifacts/p1/core_asset/` |
| **LOW-4 (신규)** | **§46 교체 계약의 잔여 리스크.** 스크립트는 `visual_root` 너머를 안 보지만 **씬 데이터가 본다** — `hit` 애니메이션 트랙 2가 `VisualRoot/Model/CorePaper:material_override` 를 절대 경로로 잡는다. QA 가 `Model` 을 다른 노드로 바꿔 재생해 확인: 눌림·shake 는 살고 **플래시만 조용히 사라진다**(`_update_caches` 경고 1줄, 크래시 없음). 애셋 워커가 GLB 를 다른 계층/이름으로 재수출하면 "피격이 안 보인다" 로 나타난다. DEV 도 주의 2번에 적어 뒀다. 권고: 애셋 README 3절 파츠 이름을 **계약**으로 고정하거나, P2 에서 `@export var hit_flash_target: MeshInstance3D` 로 Inspector 연결로 바꾼다 | `scenes/objective/sentence_core.tscn` (hit 트랙 2) |

기존 LOW (이번 범위 밖, 그대로 남음):

| 항목 | 위치 |
|---|---|
| NotoSansKR 폰트 누락 2줄 | `project.godot` `gui/theme/custom_font` |
| `"await" keyword is unnecessary` — P2 가 `_between_waves()` 를 채우면 해소 | `scripts/wave/wave_controller.gd:60` |
| `qa_f7_art` letterbox WARN. **QA-2 는 1줄로 적었으나 실제로는 6줄**이다(3해상도 × save/nosave 전 조합). 샘플링 경고이고 exit 0 | `tests/qa_f7_art.gd` |
| `signal_bus.gd` 미사용 시그널 경고 13건 (선언만 있고 emit 은 각 모듈에서) | `autoload/signal_bus.gd` |
| INFO: `HitAnchor(0, 1.1, 0)` 가 새 모델의 `문` 종이 중심(y ≈ 0.95)과 어긋난다. 참조 코드 0건이라 지금은 무해 | `scenes/objective/sentence_core.tscn` |
| INFO: 도달 판정 원(1.1) vs 책 발자국 사각형 — 대각선 모서리에서 이론상 4 cm 겹침 가능. 실측 3회 미발생 | C-9 참조 |

---

## 8. 임시 변경 원복

**프로덕션 코드는 DEV 가 남긴 상태 그대로다.** `git status` 로 확인했다.

| 임시 변경 | 목적 | 원복 |
|---|---|---|
| `tests/qa_p1_core_qa3.gd` 에 `paper_material.albedo_color = Color(1, 0, 0, 1)  # NEGCTL` 1줄 삽입 | B-6 negative control: 공유 재질 오염 검사가 실제로 살아 있는지 | **원복 완료.** 사전 백업본에서 복사 복원, `grep -c NEGCTL` → **0**. 오염된 상태로 찍힌 캡처는 원복 후 하네스를 다시 돌려 **전부 재생성**했다 |
| `art/objective/sentence_core.glb.import` / `sentence_core_preview.png.import` 의 줄바꿈 | (의도한 변경 아님) Godot 이 실행마다 CRLF → LF 로 재저장한다 | **원복 완료.** `git diff` 는 두 파일 모두 **비어 있었다**(내용 변화 0, 줄바꿈만). CRLF 로 되돌려 `git status` 에서 사라졌다 |

`git checkout --` 은 쓰지 않았다 — 워크트리에 커밋되지 않은 DEV 변경이 있어 위험하다.
파일 삭제 계열 명령도 쓰지 않았다.

최종 `git status --porcelain`:

```
 M docs/DEV_ROADMAP.md
 M scenes/objective/sentence_core.tscn
 M scenes/world/game_world.tscn
 M scripts/monsters/spawn_manager.gd
 M scripts/objective/sentence_core.gd
?? art/Untitled.blend                       (DEV 보고대로 무관한 untracked)
?? art/Untitled.blend.import
?? materials/core_hit.tres
?? tests/qa_artifacts/p1/DEV_HANDOFF_3.md
?? tests/qa_p1_core_asset.gd / .gd.uid / .tscn
?? tests/qa_p1_core_qa3.gd / .tscn          (QA 신규)
```

QA 가 추가한 것 (증거 자산이므로 남겨 둔다):

| 파일 | 목적 |
|---|---|
| `tests/qa_p1_core_qa3.gd` / `.tscn` | DEV 하네스가 안 보는 3가지: ① 반복·중단 피격 8회 후 **모델 9개 서피스 전수 색 비교 + 같은 GLB 새 인스턴스 대조** ② 클릭 없이 걸어 들어온 개체의 **최근접 거리 실측**으로 본 `reach_radius` 기하 ③ 새 코어 위치에서 **SPAWN/TURN 진입마다 비치명 클릭**, 5개 Wave 자력 Clear + 생존자 이동거리 진단 |
| `tests/qa_artifacts/p1/core_qa3/*.png` | 8장. 피격 플래시/복귀, 도달 필드, Wave 2~5, 종료 |
| `tests/qa_artifacts/p1/QA_REPORT_3.md` | 본 리포트 |

`QA_REPORT.md` / `QA_REPORT_2.md` 는 **덮어쓰지 않았다.**

---

## 9. 증거 목록

| 요구 | 파일 |
|---|---|
| 문장핵 모델 3/4 뷰 | `core_asset/00_core_idle.png`, `core_qa3/10_reach_field.png`, 에디터 3D 뷰포트 캡처 |
| 피격 전 / 중 / 후 | `core_asset/00_core_idle.png` / `01_core_hit_flash.png` / `02_core_hit_recovered.png`, `core_qa3/00_hit_flash_round0.png` / `01_hit_recovered_after_8.png` |
| 실전 피격 | `core_asset/35_wave3_core_hit.png` / `45_wave4_core_hit.png` / `55_wave5_core_hit.png` |
| Wave 1~5 플레이 | `core_asset/10_wave1_start.png` ~ `50_wave5_start.png`, `core_qa3/22_wave2.png` ~ `25_wave5.png`, `play/00_wave1_start.png` ~ `50_wave6_start.png` |
| 20마리 FPS | `core_asset/95_full_field_20.png`, `play/95_full_field_20.png` |
| 보행 6종 | `gait/00_walk.png` ~ `04_walk.png` |
| 에디터 가시성 (§46) | 씬 트리 덤프(A-1), 3D 뷰포트 캡처, `Model` 교체 실험 로그(A-3) |
