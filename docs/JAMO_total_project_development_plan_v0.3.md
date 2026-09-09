# JAMO — 총 프로젝트 개발 계획서 v0.3

> 프로젝트명: **JAMO**  
> 장르: **2.5D 클릭커 / 아이들러 / 영구 성장 / 단어 테크트리**  
> 엔진: **Godot 4.x**  
> 개발 규모: **1인 개발 기준**  
> 출시 목표: **Steam PC**  
> 기준 문서: `hangul_idle_word_tree_v0.1.md`, `hangul_idle_growth_balance_v0.2.md`

---

# 0. 이 문서의 목적

이 문서는 JAMO를 실제로 Godot에서 제작하기 위한 **총괄 개발 기준서**다.

기획 아이디어 설명에 그치지 않고 다음을 하나의 기준으로 묶는다.

- 게임 핵심 루프
- 2.5D 화면 구성
- 자모 개체별 이동/보행 성격
- 클릭 전투
- 에너지와 Day 구조
- 골드 성장
- 자모 선택
- 단어 제작
- 단어 테크트리
- 상태이상
- 특수 몬스터
- UI/UX
- Godot 씬 구조
- Resource 기반 데이터 관리
- 저장 구조
- VFX/SFX
- 개발 단계
- 테스트 기준
- Steam 출시 준비

이 문서 이후 구현 시 기존 두 문서의 세부 수치를 참고하되, 충돌하는 값은 **본 문서의 통합 기준을 우선**한다.

---

# 1. 게임 한 줄 정의

> **살아 움직이는 한글 자모를 클릭해 골드를 벌고, 하루가 끝날 때 자모 하나를 선택해 단어를 완성하며, 완성한 단어의 의미가 실제 영구 능력이 되는 2.5D 클릭커 게임.**

핵심은 단순히 한글을 조합하는 퍼즐이 아니다.

```text
몬스터 클릭
→ 골드 획득
→ 에너지 소모
→ Day 종료
→ 자모 1개 선택
→ 단어 완성
→ 새로운 시스템/능력 영구 해금
→ 다음 Day
```

`불`을 만들면 진짜 화상이 생기고, `독`을 만들면 독이 쌓이며, `번개`를 만들면 연쇄 공격이 생기는 식으로 **단어의 의미가 게임 규칙으로 변환**된다.

---

# 2. 핵심 개발 원칙

## 2.1 리셋 없는 영구 성장

JAMO는 로그라이크식 런 초기화 게임이 아니다.

다음은 모두 영구 유지한다.

- 현재 Day
- 보유 골드
- 골드 업그레이드
- 완성한 단어
- 단어 능력
- 단어 트리 진행도
- 자모 연구
- 해금한 몬스터
- 특수 몬스터
- 자동화
- 환경 연구

플레이어는 하나의 세이브를 계속 성장시킨다.

## 2.2 Day는 시간이 아니라 에너지로 끝난다

기본 에너지: **20**

수동 클릭 1회:

```text
에너지 -1
+ 클릭 피해
+ 클릭으로 발동되는 모든 효과
```

에너지 0:

```text
현재 Day 종료
→ 자모 선택
→ 단어 진행
→ 업그레이드
→ 다음 Day
```

따라서 화상/독/연쇄/출혈 등 **클릭 이후 발생하는 추가 피해는 에너지를 추가로 소모하지 않는다.**

이 구조 때문에 단어 능력은 단순 DPS 상승이 아니라 **에너지 효율 상승**의 의미를 가진다.

## 2.3 골드와 단어 성장 역할 분리

### 골드

안정적인 숫자 성장과 편의 기능.

예:

- 클릭 피해 +1
- 에너지 +1
- 골드 +5%
- 리롤 +1
- 클릭 범위 증가

### 단어

게임 규칙 또는 신규 시스템 해금.

예:

- `불` → 화상 해금
- `번개` → 연쇄 공격
- `금` → 황금 개체
- `절약` → 에너지 미소모
- `산불` → 화상 연쇄 전이

단어 핵심 능력을 골드로 직접 구매하지 않는다.

---

# 3. 비주얼 방향 — 2.5D

## 3.1 기본 화면

JAMO는 **고정 3/4 탑다운 2.5D**를 기본으로 한다.

권장 구성:

- 3D 월드
- Orthographic Camera3D 우선 검토
- 얕은 원근감
- 평면/책상/종이 같은 작은 경기장
- 자모는 얇은 입체 오브젝트
- UI는 2D Control

플레이어가 카메라를 직접 회전하지 않는다.

이유:

- 클릭 게임에서 카메라 조작이 피로를 유발함
- 한글 가독성 유지
- 자모의 정면 실루엣 유지
- 모바일게임처럼 보이지 않는 독특한 2.5D 연출 가능

## 3.2 자모 비주얼

각 자모는 단순한 텍스트가 아니라 **작은 생명체처럼 행동하는 타이포그래피 캐릭터**로 보이게 한다.

모델은 복잡한 캐릭터를 만들지 않고 다음 정도로 제한한다.

- 앞면: 자모 글자
- 두께: 얕은 Extrude
- 재질: 종이/먹/도자기/돌 느낌 중 하나
- 눈/팔/다리 추가 없음 또는 극도로 최소화
- 행동은 글자 실루엣 자체의 움직임으로 표현

핵심은 “자모에 인간형 다리를 붙였다”가 아니라 **글자 자체가 걷는 것처럼 느끼게 하는 것**이다.

---

# 4. 자모 몬스터 — 이동이 아니라 '보행'

기존의 단순 랜덤 이동 방식은 사용하지 않는다.

모든 자모는 목적지까지 이동하더라도 **각 자모의 형태적 특징에 맞는 보행 사이클**을 가진다.

## 4.1 공통 이동 구조

각 자모 몬스터는 다음 상태를 가진다.

```text
Idle
→ ChooseTarget
→ Walk
→ Turn
→ Idle
→ Walk
...
```

몬스터는 플레이어를 공격하지 않는다.

맵 안에서:

- 천천히 배회
- 멈춰 있음
- 방향을 바꿈
- 서로 약간 피함
- 맵 가장자리에서 방향 전환

### 공통 이동 변수

```text
move_speed
walk_frequency
step_height
step_distance
sway_amount
rotation_amount
idle_min
idle_max
turn_speed
avoidance_radius
personality_id
```

각 자모별로 이 값을 다르게 사용한다.

---

# 5. 자모별 보행 성격 v0.1

아래는 실제 프로토타입에서 우선 적용할 기본 성격이다.

## 5.1 ㄱ — 절뚝이는 한쪽 스텝

형태가 한쪽으로 꺾여 있기 때문에 좌우 대칭 보행보다 **기울었다가 튕기는 걸음**이 어울린다.

```text
이동속도: 1.00x
스텝 빈도: 1.0x
상하 바운스: 4%
좌우 기울기: ±7°
턴 시: 모서리를 축으로 피벗
```

걷기:

```text
기울기 → 앞으로 짧게 이동 → 착지 → 반대쪽으로 복원
```

## 5.2 ㄴ — 발을 끌며 걷기

하단 가로획이 바닥을 딛는 느낌.

```text
이동속도: 0.90x
스텝 빈도: 0.85x
상하 바운스: 2%
전후 기울기: ±5°
```

한 번 앞으로 밀고, 짧게 멈추고, 다시 밀어낸다.

## 5.3 ㄷ — 묵직한 두 발 보행

넓은 하단 때문에 **쿵쿵 걷는 탱커형**.

```text
이동속도: 0.80x
스텝 빈도: 0.75x
상하 바운스: 6%
착지 squash: Y 0.92 / XZ 1.04
```

클릭 시 타격감도 가장 무겁게 만든다.

## 5.4 ㄹ — 지그재그 보행

형태 자체가 꺾여 있기 때문에 경로가 완전 직선이 아니라 약한 좌우 흔들림.

```text
이동속도: 1.05x
좌우 sway: 이동 폭의 6%
회전: ±4°
```

경로 진행 방향을 기준으로 좌우 Sin 이동을 추가한다.

## 5.5 ㅁ — 통통 뛰는 정사각형

대표적인 둔중형.

```text
이동속도: 0.75x
보행: 짧은 점프
점프 높이: 몸 높이의 10%
착지 squash 강함
```

걷는다기보다 **두 발로 동시에 깡충 이동하는 느낌**.

## 5.6 ㅂ — 좌우 교대 보행

두 개의 내부 공간/대칭성을 이용한다.

```text
이동속도: 0.90x
좌우 롤: ±5°
보행 주기: 좌 → 우 → 좌
```

특수종에서는 처치 시 둘로 분열하는 행동과 연결 가능.

## 5.7 ㅅ — 빠른 까치발 보행

날카로운 아래 두 끝을 발처럼 사용.

```text
이동속도: 1.30x
스텝 빈도: 1.5x
바운스: 작음
좌우 롤: ±8°
```

빠르게 `톡톡톡` 걷는 느낌.

## 5.8 ㅇ — 굴러가는 것처럼 걷기

단순 직선 이동 금지.

실제 Transform은 조금씩 회전시키되 **글자가 완전히 뒤집혀 읽기 어려워지지 않도록 정면 Orientation은 유지**한다.

연출:

```text
몸체의 Z축 회전 시늉
+ 좌우 스쿼시
+ 작은 바운스
```

이동속도: **1.20x**.

## 5.9 ㅈ — ㅅ보다 조금 무거운 빠른 보행

```text
이동속도: 1.15x
스텝 빈도: 1.3x
상단 획이 관성으로 흔들리는 느낌
```

## 5.10 ㅊ — 상단이 흔들리는 경쾌한 보행

ㅈ보다 상하 반동이 더 크다.

```text
이동속도: 1.10x
바운스: 7%
상단 흔들림 느낌 강조
```

## 5.11 ㅋ — 큰 보폭

```text
이동속도: 1.00x
보폭: 1.25x
빈도: 0.8x
```

느리게 움직이지만 한 번에 크게 이동.

## 5.12 ㅌ — 둔중한 스탬프

```text
이동속도: 0.85x
착지 squash 큼
착지 시 작은 먼지 파티클
```

## 5.13 ㅍ — 넓은 좌우 균형 보행

```text
이동속도: 0.85x
좌우 흔들림: 적음
바운스: 3%
```

안정적으로 걷는 느낌.

## 5.14 ㅎ — 가볍게 떠서 걷기

완전한 부유가 아니라 발이 없는 듯 **바닥을 살짝 스치는 보행**.

```text
이동속도: 1.00x
base_hover: 0.04~0.08m
vertical_sine: 작음
```

황금/특수종으로 사용하기 좋은 형태.

---

# 6. 모음별 보행 성격

모음도 동일한 이동 애니메이션을 사용하지 않는다.

## 6.1 ㅏ / ㅓ

세로획을 중심으로 좌우 작은 획이 균형추처럼 흔들린다.

- 이동속도 1.0x
- 좌우 롤 ±6°
- 세로 바운스 4%

## 6.2 ㅑ / ㅕ

작은 획이 2개라 ㅏ/ㅓ보다 움직임이 바쁘다.

- 이동속도 1.05x
- 스텝 빈도 1.2x
- 반동 조금 큼

## 6.3 ㅗ / ㅜ

가로획을 발판처럼 사용.

- 이동속도 0.90x
- 짧은 슬라이드 + 점프
- 착지 시 가로로 눌리는 squash

ㅗ는 위쪽으로 가볍게 튀고, ㅜ는 아래로 눌렸다 튕기는 느낌을 차별화한다.

## 6.4 ㅛ / ㅠ

ㅗ/ㅜ보다 두 번 짧게 디디는 패턴.

```text
step → tiny step → pause
```

## 6.5 ㅡ

낮고 넓은 형태.

- 거의 바닥을 미끄러지듯 이동
- 매우 작은 상하 움직임
- 좌우 길이 방향으로 탄성

## 6.6 ㅣ

가장 가볍고 빠른 직립형.

- 이동속도 1.25x
- 좌우 기울기 ±10°
- 좁은 보폭 빠르게 반복

## 6.7 복합 모음

ㅘ, ㅝ, ㅢ 등은 초기에 별도 모델로 만들지 않는다.

단어 제작 데이터에서는 복합 모음을 하나의 구성 단위로 처리할 수 있지만, 필드 몬스터용 자모는 **기본 자음/모음 우선**으로 구현한다.

추후 복합 자모가 필드에 등장하면 구성 획을 이용해 더 복잡한 보행을 추가한다.

---

# 7. 보행 구현 원칙

## 7.1 AnimationPlayer를 적극 사용

보행을 전부 `_process()`에서 수식으로 하드코딩하지 않는다.

각 자모 씬에는 가능하면 다음을 둔다.

```text
JamoMonster
├─ VisualRoot
│  └─ MeshInstance3D
├─ Collision
├─ Shadow
├─ AnimationPlayer
├─ HitFXAnchor
└─ StateMachine/Script
```

`AnimationPlayer`에서 다음 애니메이션을 **Godot 에디터에서 직접 볼 수 있게** 만든다.

```text
idle
walk
turn
hit
spawn
death
special
```

스크립트는 상태 전환과 속도 계산을 담당하고, 실제 보행의 흔들림/스쿼시/회전은 **AnimationPlayer 또는 Tween이 담당**한다.

## 7.2 공통 모션 + 자모별 Override

30개 이상의 완전 개별 애니메이션을 만들지 않는다.

먼저 6개 Motion Profile을 만든다.

```text
HEAVY_STEP
LIGHT_STEP
BOUNCE
ROLL
SWAY
GLIDE
```

각 자모는 기본 프로필 + 개별 파라미터로 조절한다.

예:

```text
ㄷ = HEAVY_STEP
ㅁ = BOUNCE
ㅇ = ROLL
ㅅ = LIGHT_STEP
ㄹ = SWAY
ㅡ = GLIDE
```

이렇게 하면 자모마다 성격은 다르지만 유지보수 비용은 줄어든다.

---

# 8. 몬스터 기본 구조

## 8.1 일반 몬스터

통합 초기값:

```text
Day 1 HP: 3
Base Gold: 2G
```

HP:

```text
HP = 3 × 1.035^(Day - 1)
```

Gold:

```text
BaseGold = 2 × 1.025^(Day - 1)
```

## 8.2 몬스터 행동

몬스터는 공격하지 않는다.

행동 목적은 **클릭 타겟의 성격 차이**를 만드는 것이다.

```text
wander
idle
turn
avoid
special movement
```

## 8.3 클릭 난이도 변수

- 이동속도
- 몸체 크기
- 클릭 판정 크기
- 갑작스러운 턴 빈도
- 잠깐 정지 여부
- 특수 행동

작은 자모일수록 CollisionShape3D는 시각 크기보다 약간 크게 잡는다.

---

# 9. 특수 자모 몬스터

## 9.1 큰 ㅁ

- HP ×3
- 이동속도 ×0.6
- Gold ×3
- 강한 착지
- 클릭하기 쉬움

## 9.2 빠른 ㅇ

- HP ×0.75
- 이동속도 ×1.8
- Gold ×2
- 방향 전환 빈도 높음

## 9.3 황금 ㅎ

- `금` 단어 해금 이후 등장
- 기본 출현 확률 2%
- Gold ×5
- `황금` 해금 후 ×8
- 금속 재질 + 작은 Glow
- 일반 개체보다 체류 시간이 짧음

## 9.4 분열 ㅂ

- 처치 시 작은 ㅂ 2개 생성
- 작은 ㅂ 각각 원본 HP의 35%
- 작은 ㅂ 보상 각각 원본 Gold의 30%
- 상태이상 전이는 별도 밸런스 검토

## 9.5 점멸 ㅅ

- 일정 주기로 0.6초 반투명
- 반투명 중 클릭 판정은 유지 또는 후반 난이도에서 비활성
- Gold ×2

## 9.6 희귀 개체 공통

특수 개체는 새로운 그림 애셋을 대량 제작하지 않는다.

차이는 다음으로 만든다.

- Scale
- Material
- Emission
- 이동 프로필
- Particle
- Trail
- 행동 스크립트

---

# 10. 클릭 전투 시스템

수동 클릭 순서:

```text
1. 마우스 RayCast
2. Monster Area3D 판정
3. 에너지 사용 가능 확인
4. 에너지 -1 또는 절약 판정
5. 클릭 피해 계산
6. 상태이상/치명/단어 효과 처리
7. Hit Feedback
8. HP <= 0이면 처치
9. 골드 지급
```

## 10.1 최종 클릭 피해

```text
FinalClickDamage =
(BaseClickDamage + FlatWordBonus)
× WordDamageMultiplier
× CriticalMultiplier
× TargetTakenDamageMultiplier
```

### 통합 수정

기존 `힘: 기본 클릭 피해 1 → 2`는 값 덮어쓰기를 사용하지 않는다.

본 문서에서는:

```text
힘 = FlatWordBonus +1
```

으로 처리한다.

골드 업그레이드와 충돌하지 않기 때문이다.

## 10.2 치명/강타 통합

골드 `치명 클릭`과 단어 `강타`는 별도의 2회 RNG가 아니라 **하나의 Critical 시스템**으로 통합한다.

예:

```text
BaseCritChance = GoldCritChance
+ StrongHitWordBonus

BaseCritMultiplier = 2.0
+ WordCritMultiplierBonus
```

`강타`:

- CritChance +10%p

`괴력`:

- 추가 +5%p
- CritMultiplier ×2 → ×2.5

이 구조로 중복 판정 폭주를 방지한다.

---

# 11. 에너지 시스템

초기:

```text
Max Energy = 20
Manual Click Cost = 1
```

Gold Max Energy:

```text
Lv0 20
Lv1 21 / 50G
Lv2 22 / 90G
Lv3 23 / 160G
Lv4 24 / 280G
Lv5 25 / 500G
Lv6 26 / 900G
Lv7 27 / 1,600G
Lv8 28 / 2,800G
Lv9 29 / 5,000G
Lv10 30 / 9,000G
```

전체 최종 권장 상한:

```text
40~50
```

## 11.1 에너지 미소모

Gold 연구 + 단어 `절약`이 같은 시스템에 합산된다.

전체 상한:

```text
20%
```

---

# 12. Day 구조

## Day Start

- Day 표시
- 에너지 최대치까지 충전
- Day 시작 효과 처리
- 몬스터 Spawn Pool 설정
- Day 기반 HP/Gold 적용

## During Day

- 자모 몬스터 보행
- 클릭
- 골드
- 상태이상
- 특수 개체

## Energy 0

즉시 모든 것을 정지시키지 않는다.

권장:

1. 마지막 클릭 결과/상태이상 0.5~1초 정산
2. 살아 있는 몬스터는 배경 처리
3. 화면 Dim
4. Day Complete
5. 자모 선택 UI

상태이상으로 에너지 0 이후 몬스터가 죽었을 경우 해당 처치 골드는 정상 지급한다.

---

# 13. 자모 선택 시스템

기본 후보: **2개**

업그레이드:

```text
2 → 3 (Day 10 / 2,000G)
3 → 4 (Day 40 / 25,000G)
```

최대 4.

Day마다 선택하는 자모는 기본적으로 **1개**다.

## 13.1 리롤

```text
Lv1: 1회 / Day 5 / 1,000G
Lv2: 2회 / Day 25 / 7,500G
Lv3: 3회 / Day 60 / 50,000G
```

## 13.2 Lock

- Day 15
- reroll Lv1 필요
- 5,000G
- 최대 1개 잠금

## 13.3 목표 단어 Focus

현재 제작 가능한 단어 1개를 Target으로 지정.

필요 자모 등장 가중치:

```text
+5 / +10 / +15 / +20%
```

확정 출현은 금지.

## 13.4 후보 생성 안전 규칙

후보 생성기는 완전히 무작위로 만들지 않는다.

각 후보는 다음 Pool에서 가중 추출한다.

```text
A. 현재 Target 단어에 필요한 자모
B. 제작 가능한 다른 단어에 필요한 자모
C. 아직 사용 가능성이 있는 일반 자모
```

완전한 사망 선택지는 최대한 제거한다.

목표:

> 선택지가 어려울 수는 있지만, 아무 의미 없는 자모만 나오는 상황은 최소화한다.

---

# 14. 단어 제작 시스템

## 14.1 기본

단어는 개발자가 사전에 정의한다.

임의의 한국어 사전 전체를 지원하지 않는다.

각 단어는:

```text
word_id
표시 단어
필요 자모 sequence
category
prerequisites
effects
```

를 가진다.

## 14.2 단어 완성

예:

```text
ㅂ → ㅜ → ㄹ
= 불
```

완성:

1. 자모들이 화면 중앙으로 이동
2. 한글 음절로 합성
3. `불` 텍스트/3D Glyph 등장
4. 화염 VFX
5. 효과 설명
6. 영구 저장
7. 다음 제작 가능 단어 갱신

단어 완성은 게임의 주요 보상 순간이므로 **강한 연출 포인트**로 만든다.

---

# 15. 단어 테크트리

기존 `hangul_idle_word_tree_v0.1.md`를 세부 기준으로 사용한다.

## 15.1 화염

```text
불
├─ 화염
│  └─ 고열
│     └─ 폭염
├─ 불꽃
│  └─ 화재
│     └─ 산불
└─ [폭염 + 산불] → 화염폭발
```

핵심:

- 불: 3초, 1초 틱, 1 피해
- 화염: 틱 2
- 고열: 5초
- 폭염: 0.75초 틱
- 불꽃: 사망 시 80px 1명 전이
- 화재: 120px / 2명
- 산불: 최대 3연쇄
- 화염폭발: 15%, 100px, 틱×3 폭발

## 15.2 독

```text
독
├─ 중독
│  └─ 맹독
│     └─ 극독
├─ 독성
│  └─ 독기
└─ [맹독 + 독기] → 부식
```

- 8초
- 2초 틱
- 기본 최대 3스택
- 중독 → 5스택
- 맹독 → 스택당 2
- 극독 → 최대 스택에서 남은 피해 30% 즉발
- 독성 → 12초
- 독기 → 100px, 20%, 최대 전파 2스택
- 부식 → 스택당 클릭 피해 +4%

## 15.3 전기

```text
전기
├─ 감전
├─ 번개
│  └─ 연쇄
├─ 벼락
└─ [연쇄 + 벼락] → 낙뢰
```

- 기본 Proc 20%
- 감전 2초 40% 감속
- 번개 1연쇄 70%
- 연쇄 최대 3
- 벼락 Proc 30%
- 낙뢰 매 10번째 클릭 확정, 무작위 3명 ×2

## 15.4 출혈

```text
피
└─ 출혈
   ├─ 상처
   │  └─ 과다출혈
   └─ 혈흔
      └─ 혈폭
```

움직임 기반 피해이므로 **자모 보행 시스템과 직접 시너지**가 난다.

- 50px 이동마다 피해
- 빠른 ㅇ/ㅅ 계열에 강함

## 15.5 얼음

```text
얼음
└─ 냉기
   ├─ 빙결
   │  └─ 서리
   │     └─ 동상
   └─ 한파
```

클릭 난이도 제어 계열.

## 15.6 힘/충격

```text
힘
└─ 강타
   ├─ 괴력
   └─ 충격
      └─ 충격파
         └─ 파괴
```

본 문서에서는:

- 힘 = Click Flat Bonus +1
- 강타/괴력 = Critical 시스템 강화

## 15.7 경제

```text
돈
├─ 금 → 황금
└─ 재물 → 부자
[황금 + 부자] → 대박
```

## 15.8 에너지

```text
밥
└─ 체력
   ├─ 휴식
   │  └─ 활력 조건
   └─ 절약
      └─ 집중
```

## 15.9 행운

```text
운
├─ 행운 → 기회
└─ 복 → 대운
[기회 + 대운] → 기적
```

## 15.10 자동화

기존 문서와 Gold 연구의 중복을 다음처럼 통합한다.

### 단어 역할

```text
손 → 클릭 판정 +10px
손길 → 추가 +10px
자동 → Auto Click 시스템 자체를 해금
속도 → AutoClick Interval Modifier -15%
기계 → AutoClick Interval Modifier 추가 -15%
공장 → 고가치 Target Priority 해금
```

### Gold 역할

단어 `자동`을 해금한 뒤 또는 Day 50 이후 조건을 만족해야 Gold Auto 연구가 열린다.

Gold 연구는 실제 주기 수치를 강화한다.

```text
15s → 12s → 10s → 8s → 6s
```

즉:

> **단어 = 기능 해금/규칙 변화**  
> **골드 = 성능 강화**

---

# 16. 상태이상 처리 구조

각 몬스터는 EffectContainer를 가진다.

```text
BurnEffect
PoisonEffect
BleedEffect
SlowEffect
FreezeEffect
ShockEffect
```

상태이상을 Monster 스크립트 하나에 전부 하드코딩하지 않는다.

권장:

```text
StatusEffect Resource
+ Runtime StatusEffectInstance
```

필드:

```text
id
duration
tick_interval
stack
max_stack
source
value
```

이 방식으로 단어 추가 시 기존 Monster 코드를 최소 수정한다.

---

# 17. 후반 효과 폭주 방지

모든 단어가 영구 해금되므로 후반에 효과가 지나치게 많아질 수 있다.

MVP에서는 우선 모든 해금 효과를 사용할 수 있게 구현한다.

하지만 다음 문제를 계측한다.

- 한 클릭에 VFX가 너무 많음
- 상태 아이콘 과다
- DPS 폭증
- 플레이어가 무엇 때문에 적이 죽었는지 모름

문제가 확인될 경우 **전투 속성 슬롯 3개**를 1순위 해결책으로 검토한다.

단, 초기 MVP에는 슬롯 시스템을 먼저 넣지 않는다.

---

# 18. 골드 업그레이드

기존 `hangul_idle_growth_balance_v0.2.md`를 기본 수치표로 유지한다.

핵심 범주:

```text
[활동]
최대 에너지
에너지 보존

[클릭]
클릭 피해
클릭 범위
치명 클릭

[경제]
골드 증가
특수 개체
황금 개체

[자모 연구]
후보 수
리롤
잠금
목표 집중
힌트

[환경]
동시 몬스터 수
특수 체류시간
자동화
```

## 통합 기본값

기존 v0.1의 일반 몬스터 1G가 아니라 **v0.2의 2G를 기준값으로 확정**한다.

```text
Day 1 Normal Monster Gold = 2G
```

---

# 19. Godot 개발 원칙 — 매우 중요

> **JAMO는 스크립트만으로 화면과 구조를 생성하는 프로젝트로 만들지 않는다.**

개발 결과를 사용자가 Godot Editor에서 열었을 때:

- 씬 구조를 볼 수 있어야 함
- 오브젝트 위치를 직접 조절할 수 있어야 함
- Collision을 눈으로 볼 수 있어야 함
- Camera를 조절할 수 있어야 함
- UI를 직접 편집할 수 있어야 함
- AnimationPlayer를 열어 애니메이션을 볼 수 있어야 함
- Resource를 Inspector에서 수정할 수 있어야 함
- 숫자 밸런스를 코드 파일을 열지 않고도 조절할 수 있어야 함

## 19.1 금지하는 개발 방식

다음 방식은 특별한 이유가 없으면 사용하지 않는다.

```text
런타임에 Node를 전부 코드로 생성
런타임에 UI 전체를 코드로 생성
코드 내부에 몬스터 데이터 하드코딩
코드 내부에 단어 DB 하드코딩
코드 내부에 업그레이드 가격 하드코딩
코드 내부에 애니메이션 keyframe 하드코딩
```

예:

```gdscript
var label = Label.new()
var panel = Panel.new()
var button = Button.new()
...
```

처럼 메인 UI를 전부 코드에서 생성하지 않는다.

## 19.2 권장 방식

```text
.tscn = 구조
.tres = 데이터
AnimationPlayer = 시각 애니메이션
Theme Resource = UI 스타일
.gd = 로직/상태/계산
```

스크립트는 **로직을 담당**하고, Godot Editor는 **구조/디자인/튜닝을 담당**한다.

---

# 20. Godot 프로젝트 폴더 구조

```text
res://
├─ autoload/
│  ├─ game_state.gd
│  ├─ save_manager.gd
│  ├─ signal_bus.gd
│  └─ audio_manager.gd
│
├─ scenes/
│  ├─ main/
│  │  ├─ main.tscn
│  │  └─ main.gd
│  ├─ world/
│  │  ├─ game_world.tscn
│  │  ├─ arena.tscn
│  │  └─ camera_rig.tscn
│  ├─ monsters/
│  │  ├─ jamo_monster_base.tscn
│  │  ├─ consonant/
│  │  ├─ vowel/
│  │  └─ special/
│  ├─ effects/
│  │  ├─ hit_fx.tscn
│  │  ├─ burn_fx.tscn
│  │  ├─ poison_fx.tscn
│  │  ├─ electric_fx.tscn
│  │  └─ death_fx.tscn
│  └─ ui/
│     ├─ hud.tscn
│     ├─ day_end.tscn
│     ├─ jamo_choice.tscn
│     ├─ word_complete.tscn
│     ├─ word_tree.tscn
│     ├─ upgrade_shop.tscn
│     └─ settings.tscn
│
├─ resources/
│  ├─ monsters/
│  ├─ motion_profiles/
│  ├─ words/
│  ├─ upgrades/
│  ├─ status_effects/
│  └─ balance/
│
├─ scripts/
│  ├─ combat/
│  ├─ monsters/
│  ├─ word_system/
│  ├─ upgrades/
│  └─ ui/
│
├─ materials/
├─ shaders/
├─ audio/
├─ fonts/
└─ art/
```

---

# 21. 주요 씬 구조

## 21.1 main.tscn

```text
Main
├─ World
│  └─ GameWorld
├─ CameraRig
├─ WorldEnvironment
├─ UI
│  ├─ HUD
│  ├─ OverlayLayer
│  ├─ DayEnd
│  ├─ JamoChoice
│  ├─ WordComplete
│  └─ UpgradeShop
└─ Audio
```

## 21.2 jamo_monster_base.tscn

```text
JamoMonsterBase (CharacterBody3D)
├─ VisualRoot (Node3D)
│  ├─ GlyphMesh (MeshInstance3D)
│  └─ Outline/Accent
├─ ClickArea (Area3D)
│  └─ CollisionShape3D
├─ MoveCollision (CollisionShape3D)
├─ AnimationPlayer
├─ StatusEffectAnchor
├─ HitFXAnchor
├─ LabelAnchor
└─ AudioStreamPlayer3D
```

Inspector에서 다음을 바꿀 수 있게 export한다.

```text
MonsterData
MotionProfile
Visual Material
Scale
Click Radius
```

---

# 22. Resource 설계

## 22.1 JamoMonsterData

```text
id
jamo
base_hp
base_gold
base_speed
scale
motion_profile
special_type
spawn_weight
click_radius
material
```

## 22.2 MotionProfile

```text
profile_name
move_speed_multiplier
step_frequency
step_height
sway_amount
roll_angle
pitch_angle
squash_amount
idle_min
idle_max
turn_frequency
```

Godot `.tres`로 만들어 Inspector에서 수정한다.

## 22.3 WordData

```text
id
word
category
required_jamo
prerequisites
effect_ids
tier
ui_icon
hidden_before_unlock
```

## 22.4 WordEffectData

```text
effect_type
base_value
value_type
duration
tick_interval
proc_chance
radius
max_stack
chain_count
```

## 22.5 UpgradeData

```text
id
name
category
max_level
costs
values
unlock_day
required_word
required_upgrade
```

---

# 23. UI/UX

## 23.1 인게임 HUD

화면을 많이 가리지 않는다.

상단 좌측:

```text
DAY 17
```

상단 중앙 또는 하단:

```text
ENERGY 14 / 23
```

상단 우측:

```text
Gold 1,284
```

하단 소형 영역:

- 현재 목표 단어
- 현재 조립된 자모

예:

```text
TARGET: 불
[ㅂ][ㅜ][ ]
```

단, 힌트 업그레이드가 없으면 Target 정보 노출량을 제한한다.

## 23.2 클릭 피드백

클릭 시 최소 4개 피드백:

1. 자모 squash
2. 작은 타격 파티클
3. Damage Number
4. 짧은 SFX

치명:

- Damage number 크기 증가
- 카메라 미세 shake
- 추가 impact ring

## 23.3 에너지 피드백

매 클릭마다 단순 숫자만 줄지 않는다.

- 게이지 pulse
- 마지막 3 에너지에서 약한 경고
- 0에서 Day End Transition

## 23.4 자모 선택 화면

2~4개의 자모가 **3D 또는 큰 카드 형태**로 등장.

각 후보를 Hover하면:

- 확대
- 소리
- 가능한 힌트
- Lock 여부

## 23.5 단어 트리

단어 트리는 기술 트리처럼 보여준다.

```text
불
├─ 화염
│  └─ 고열
└─ 불꽃
   └─ 화재
```

상태:

- 해금
- 제작 가능
- 선행 잠금
- 미발견

Node를 직접 클릭해 목표 단어로 지정 가능하도록 설계한다.

---

# 24. VFX 방향

JAMO의 외부 아트 리소스가 적은 대신 VFX가 게임 품질을 결정한다.

## 기본 클릭

- 작은 먹가루/종이 조각
- Scale punch
- Shadow squash

## Fire

- 짧은 불꽃
- burn 상태 작은 ember
- spread는 얇은 불꽃 Arc

## Poison

- 작은 보라/녹색 Bubble
- 과한 연기 금지

## Electric

- 자모 사이 Line3D/Trail 기반 arc

## Bleed

- 잉크 자국처럼 처리 가능
- 현실적인 피보다 스타일화

## Ice

- Frost edge
- freeze 시 material 변화

## Gold

- 아주 작은 sparkle
- 황금 개체는 과도한 Bloom 금지

---

# 25. 오디오 방향

자모의 재질감을 살리는 짧은 효과음이 중요하다.

각 이동 프로필에 Step SFX를 다르게 한다.

```text
HEAVY → 톡/툭 낮은 소리
LIGHT → 틱/탭
BOUNCE → 뽁/통
ROLL → 가벼운 구름 소리
GLIDE → 스윽
```

클릭:

- 일반
- Critical
- Kill
- Golden
- Word Complete

단어 완성은 별도 강한 UI Sting 사용.

---

# 26. 카메라

기본:

```text
Camera3D
Projection: Orthogonal 우선
Rotation X: 약 -50° ~ -60°
Rotation Y: 약 0° 또는 45° 계열 테스트
```

클릭 게임이므로 화면 왜곡이 적어야 한다.

카메라 기능:

- 기본 고정
- Hit Shake
- Word Complete Zoom
- Golden Spawn 약한 Focus

플레이어 자유회전 없음.

---

# 27. 맵

MVP는 **하나의 맵**만 만든다.

맵 다양성 대신 Day 진행과 단어 능력의 시각 변화가 핵심이다.

권장 맵:

- 작은 책상/종이 판
- 사각 또는 약간 둥근 Arena
- 자모가 낭떠러지 밖으로 나가지 않도록 Invisible Wall
- 단순한 장식 3~5개

맵 추가 제작을 초기 목표로 삼지 않는다.

후반 Day에:

- 조명 변화
- 배경 문양
- 잉크 농도
- 날씨 비슷한 VFX

정도로 진행감을 줄 수 있다.

---

# 28. Spawn 시스템

기본 동시 개체 8.

업그레이드 최대 20.

SpawnManager는 현재 Day와 해금 상태를 기반으로 Spawn Pool을 만든다.

```text
Normal Jamo Pool
+ Unlocked Special Pool
+ Golden Pool
```

같은 자모가 지나치게 겹치지 않도록 동일 종류 반복에 작은 패널티 가중치를 적용한다.

---

# 29. 자동화

자동화는 게임을 완전히 관전 게임으로 바꾸지 않는다.

Auto Click도:

```text
에너지 -1
```

단어 `자동` 해금 전에는 활성화 불가.

Gold 연구로 속도 강화.

ON/OFF Toggle 제공.

Auto Target 우선순위:

```text
Golden
→ Special
→ Expected Gold High
→ Normal
```

후반에는 자동화가 Day를 진행시키지만 수동 플레이는 빠른 희귀 개체, 특정 상태 스택, Target 선택에서 더 효율적이어야 한다.

---

# 30. 저장 시스템

저장 시점:

- Day 종료
- 단어 완성
- 골드 업그레이드 구매
- 옵션 변경
- 게임 종료 요청

핵심 데이터:

```text
save_version
current_day
current_gold

upgrade_levels
unlocked_words
word_tree_progress
current_word_progress
selected_target_word
unlocked_monsters
unlocked_specials
settings
```

Resource 자체를 저장하지 않고 `id + level`만 저장한다.

---

# 31. 개발 단계

## Phase 0 — 프로젝트 기반

목표: Godot에서 편집 가능한 프로젝트 뼈대.

- main.tscn
- GameWorld
- Camera3D
- Arena
- HUD
- GameState Autoload
- SaveManager
- Input Mapping

완료 조건:

> Godot Editor에서 Play 시 빈 2.5D 경기장과 HUD가 보인다.

## Phase 1 — 자모 보행 프로토타입

우선 6개 자모:

```text
ㄱ
ㄷ
ㅁ
ㅅ
ㅇ
ㅣ
```

Motion Profile:

```text
HEAVY_STEP
LIGHT_STEP
BOUNCE
ROLL
SWAY
GLIDE
```

완료 조건:

> 여섯 자모를 동시에 놓았을 때 실루엣뿐 아니라 **걷는 방식만 보고도 성격 차이가 느껴진다.**

## Phase 2 — 클릭/HP/골드/에너지

- Raycast 클릭
- ClickArea
- HP
- Damage Number
- Death
- Gold
- Energy
- Day End

완료 조건:

> Day 1을 처음부터 끝까지 플레이할 수 있다.

## Phase 3 — 자모 선택/단어 제작

- Candidate Generator
- Choice UI
- current word progress
- WordData Resource
- prerequisite
- Word Complete

최초 구현 단어:

```text
불
힘
돈
밥
```

완료 조건:

> 여러 Day를 진행해 실제 단어 하나를 완성하고 영구 능력이 적용된다.

## Phase 4 — Gold Upgrade

우선:

- Max Energy
- Click Damage
- Gold Bonus
- Monster Capacity
- Reroll

완료 조건:

> 저장/로드 후 구매 상태가 유지된다.

## Phase 5 — Combat Words

순서:

1. 불/Burn
2. 독/Poison
3. 전기/Electric
4. 피/Bleed
5. 얼음/Ice
6. 힘/Critical

완료 조건:

> 각 상태 효과가 서로 중첩되어도 예외/에러 없이 동작한다.

## Phase 6 — Word Tree UI

- Node graph
- Lock states
- target selection
- hint

## Phase 7 — Specials

- 큰 ㅁ
- 빠른 ㅇ
- 황금 ㅎ
- 분열 ㅂ
- 점멸 ㅅ

## Phase 8 — Automation

- 자동 word
- Gold research
- Auto Target

## Phase 9 — Juice / Polish

- VFX
- SFX
- Camera Shake
- Word Completion
- Transitions
- Hover
- UI animations

## Phase 10 — Content/Balancing

- 단어 DB 확대
- 1~200 Day 곡선
- 경제 튜닝
- 특수 개체 확률

## Phase 11 — Steam

- Steamworks
- achievements
- cloud save 검토
- capsule
- trailer
- store page
- localization

---

# 32. 우선 제작할 Vertical Slice

전체를 한 번에 개발하지 않는다.

첫 완성 버전은 다음만 포함한다.

```text
맵 1개
자모 6종
특수 2종
Day 1~20
단어 8~12개
Gold Upgrade 5종
Burn
Critical
Gold Word
Energy Word
Jamo Choice
Reroll
Save/Load
```

이 Vertical Slice가 재미없으면 단어를 100개 만들어도 해결되지 않는다.

---

# 33. 프로토타입 우선 단어 세트

추천 최초 10개:

```text
불
화염
불꽃
힘
강타
돈
금
밥
체력
운
```

이 조합으로 테스트 가능한 것:

- DoT
- Spread
- Crit
- Economy
- Golden Monster
- Energy
- Special Spawn

---

# 34. 플레이테스트 지표

최소 기록:

```text
Day length
Clicks per Day
Kills per Day
Gold per Day
Gold per Click
Average HP
Upgrade purchase interval
Days per Word
Reroll usage
Candidate frustration
Special kill rate
Missed special count
Damage source breakdown
Energy saved by status effects
Automation share
```

## 목표 감각

초반:

> 거의 매일 작은 성장.

중반:

> 며칠 모아서 큰 업그레이드 또는 상위 단어.

단어 완성:

> 골드 레벨업보다 훨씬 큰 변화.

---

# 35. 밸런스 경고 조건

## 에너지

하루 평균 실제 플레이가 너무 길어지면 Max Energy/절약을 조절한다.

## DoT

한 클릭 후 아무것도 하지 않아도 너무 많은 개체가 연쇄 사망하면 Spread/Proc를 조절한다.

## 자모 RNG

목표 단어가 2~3배 이상 예상 기간을 초과하면 Candidate Weight를 조절한다.

## Gold

업그레이드 구매 없이 5 Day 이상 골드만 쌓이는 시점이 너무 이르면 가격곡선을 조절한다.

---

# 36. 성능 목표

PC Steam 기준이지만 저사양에서도 가볍게 동작하도록 한다.

1차 목표:

```text
20 active monsters
다수 상태이상
파티클
Damage Numbers
60 FPS
```

피해야 할 것:

- 몬스터마다 매 프레임 전체 몬스터 탐색
- 번개/전이마다 `get_nodes_in_group()` 남발
- 매 클릭 Resource 로드
- 매 프레임 새 Array/Dictionary 생성

근접 탐색은 MonsterManager/공간 분할 또는 캐시를 사용한다.

하지만 개체 최대 20 기준이므로 MVP에서 과도한 ECS 구조까지 도입하지 않는다.

---

# 37. 개발자가 Godot에서 반드시 직접 확인 가능해야 하는 것

외부 AI/Claude/Codex 등이 개발을 맡는 경우에도 다음 조건을 지킨다.

## 씬

모든 핵심 기능은 `.tscn`으로 존재한다.

## UI

Control node를 Editor에서 볼 수 있어야 한다.

## 애니메이션

AnimationPlayer Timeline에서 재생해 볼 수 있어야 한다.

## 밸런스

`.tres` Resource를 선택하면 Inspector에 값이 보여야 한다.

## 자모

각 자모 씬 또는 Data Resource를 선택하면:

```text
HP
Gold
Speed
Motion Profile
Scale
Click Radius
Spawn Weight
```

를 볼 수 있어야 한다.

## 단어

Word Resource를 선택하면:

```text
Prerequisites
Required Jamo
Effect
Values
```

를 볼 수 있어야 한다.

### 구현 지시 원칙

> **“기능이 동작하는 것”만 완료로 판단하지 않는다. Godot Editor 안에서 사람이 씬과 데이터를 열어보고 수정할 수 있는 구조까지 완료되어야 한다.**

---

# 38. AI 개발 지시 시 고정 문구

Claude/Codex/Ziva 등에게 기능 개발을 요청할 때 아래 원칙을 항상 포함한다.

```text
Do not implement this project as a code-only Godot project.

Use Godot scenes (.tscn), Resources (.tres), AnimationPlayer,
Control nodes, Node3D hierarchy, Inspector-exposed properties,
and reusable packed scenes wherever appropriate.

I must be able to open the project in the Godot Editor and visually inspect,
move, configure, animate, and tune the objects without rewriting code.

Do not create the main UI entirely from GDScript.
Do not hard-code balance data, word data, monster data, or upgrade tables
inside gameplay scripts when they can be represented as Resources.

Scripts should control logic. Scenes and Resources should represent structure,
visuals, editable configuration, and balance data.

For every implemented feature, leave the relevant nodes and exported
properties clearly named and editable in the Godot Inspector.
```

---

# 39. MVP 완료 기준

JAMO의 첫 외부 테스트 빌드는 다음을 만족해야 한다.

- 게임 실행
- 2.5D 맵
- 서로 다르게 걷는 자모
- 클릭 처치
- 에너지
- Day 종료
- 자모 선택
- 단어 완성
- 3개 이상 단어 계열
- 골드 업그레이드
- 특수 몬스터
- 저장/로드
- 설정
- 기본 SFX/VFX
- 30분 이상 진행 가능
- 심각한 진행 막힘 없음

---

# 40. 최종 개발 방향 요약

JAMO의 경쟁력은 그래픽 자산량이 아니다.

핵심 차별점은 다음 네 가지다.

### 1. 자모 자체가 캐릭터

`ㅇ`은 굴러가듯 걷고, `ㅁ`은 통통 뛰며, `ㅅ`은 빠르게 톡톡 걷는다.

### 2. 클릭 1회가 하루의 자원

무작정 연타가 아니라 **어떤 개체를 클릭할지**가 의미를 가진다.

### 3. 단어의 의미가 능력이 된다

```text
불 → Burn
독 → Poison
번개 → Chain
금 → Golden Monster
절약 → Energy Save
```

### 4. 전부 영구 성장

오늘 만든 단어와 업그레이드는 다음 Day에도 계속 남는다.

---

# 41. 기준 문서 우선순위

개발 중 수치 또는 설계가 충돌하면 다음 순서로 판단한다.

```text
1. JAMO_total_project_development_plan_v0.3.md
2. hangul_idle_growth_balance_v0.2.md
3. hangul_idle_word_tree_v0.1.md
```

단어별 상세 수치가 본 문서에 생략되어 있는 경우 `word_tree_v0.1`을 참고한다.

Gold 업그레이드의 전체 가격표가 필요한 경우 `growth_balance_v0.2`를 참고한다.

본 문서에서 명시적으로 변경한 사항은 본 문서를 우선한다.

---

# 42. v0.3에서 확정한 통합 수정 사항

1. 게임명: **JAMO**
2. 화면: **2.5D 고정 3/4 뷰**
3. 자모는 단순 배회가 아니라 **자모 형태별 고유 보행** 사용
4. Day 1 일반 몬스터 기본 Gold: **2G**
5. `힘`: Base Click Damage 덮어쓰기 → **Flat +1**
6. `강타` + Gold 치명 클릭 → **Critical 시스템 통합**
7. `절약` + Gold 에너지 보존 → 동일 Energy Save 시스템에 합산, 총 상한 20%
8. 자동화: **단어로 시스템/규칙 해금, Gold로 성능 강화**
9. Godot 프로젝트는 **코드 전용 방식 금지**
10. `.tscn`, `.tres`, AnimationPlayer, Inspector 기반의 **에디터 가시성/수정 가능성 필수**

---

**문서 버전:** v0.3  
**프로젝트:** JAMO  
**용도:** Godot 실제 개발 및 AI 개발 지시용 총 프로젝트 기준서
