# JAMO — 게임 세부 계획서 v0.5

> 장르: **2D 한글 단어 조합 × 덱빌딩 × 로그라이트 × 클릭 전투 × 영구 성장**  
> 엔진: **Godot 4.x**  
> 플랫폼: **Steam PC**  
> 개발 규모: **1인 개발 기준**  
> 스토리/세계관: `JAMO_01_story_world_v0.2.md`  
> 숫자 밸런스: `JAMO_03_balance_detail_v0.2.md`

---

# 0. 이 문서의 역할

이 문서는 JAMO의 실제 게임 규칙만 정의한다.

여기에서 다루는 것:

- Main Hub
- RUN
- Wave
- 클릭 전투
- 마지막 문장 방어
- 자모 몬스터
- 자모 드랍
- Run Jamo Deck
- 슬롯/Lock/Reroll
- 단어 복원
- 단어 아이템
- 합성어
- 시너지
- 위험 단어
- 중간보스
- 단어 보스
- 지형/맵
- UI/UX
- 저장
- Godot 구조
- 개발 순서

수치가 필요한 경우 밸런스 문서를 따른다.

---

# 1. 게임 한 줄 정의

> **뜻을 잃은 자모를 정화해 현재 RUN의 자모 덱을 만들고, 슬롯에서 단어를 복원해 장비·유물·특수효과 빌드를 완성하며, Wave 10마다 등장하는 단어 보스를 돌파하는 로그라이트 클릭 게임.**

---

# 2. 최종 핵심 루프

```text
[마지막 서고]

영구 업그레이드
복원 사전
최고 기록 확인

        ↓

[RUN START]

Wave 1

        ↓

자모 몬스터 접근
        ↓
클릭으로 정화
        ↓
Gold 획득
        ↓
일정 확률로 동일 자모 드랍
        ↓

Wave Clear

        ↓

이번 Wave에서 떨어진 자모 중 선택
        ↓
Run Jamo Deck에 추가/교체
        ↓

Word Forge
        ↓
6개 자모 Draw
        ↓
Lock / Reroll
        ↓
단어 복원
        ↓

장비 / 유물 / 특수효과 / 위험 단어
        ↓

다음 Wave

        ↓

Wave 5 : 중간보스
Wave 10 : 단어 보스

        ↓

실패할 때까지 반복

        ↓

RUN RESULT

Gold / 복원 사전 / 복원도 / 기록 영구 저장

        ↓

다시 Wave 1
```

---

# 3. 영구 성장과 RUN 성장

## 3.1 영구 유지

- Gold
- 영구 업그레이드
- 복원 사전
- 단어 복원도
- 발견 합성어
- 발견 시너지 정보
- 정화한 단어 보스
- 해금된 단어 풀
- 최고 Wave
- 통계
- 업적
- 설정

## 3.2 RUN 종료 시 초기화

- 현재 Wave
- 현재 Run Jamo Deck
- 이번 RUN에 추가/삭제/교체한 자모
- 복원한 단어
- 장비 단어
- 유물 단어
- 특수효과 단어
- 위험 단어
- Run Rank
- 현재 시너지
- 합성어
- RUN 전용 리롤
- 마지막 문장의 현재 안정도

---

# 4. 에너지 시스템 삭제

v0.4의 `클릭할 때마다 에너지 -1` 구조는 제거한다.

## 4.1 최종 원칙

> **수동 클릭은 별도의 에너지를 소모하지 않는다.**

이유:

- 핵심 재미가 단어 조합인데 클릭 자원이 흐름을 끊음
- 좋은 빌드를 만들었는데 클릭할 수 없는 상황이 재미없음
- 자원이 과도하게 많아지는 것을 방지
- 자원 관리는 자모 덱/리롤/Lock/슬롯으로 충분함

## 4.2 클릭 연타 제한

매크로성 광클을 막기 위해 **입력 쿨다운**만 둔다.

```text
Manual Click Cooldown
```

이 수치는 스태미나가 아니라 공격 속도 제한이다.

---

# 5. 전투 목표 — 마지막 문장 방어

각 전투 페이지에는 `마지막 문장`이 존재한다.

적 자모는 스폰 지점에서 마지막 문장 쪽으로 이동한다.

```text
Spawn
↓
페이지의 문장 행을 따라 이동
↓
마지막 문장 도달
↓
안정도 피해
```

마지막 문장의 안정도가 0이 되면 RUN 실패.

플레이어 캐릭터를 직접 움직이지 않는다.

플레이어의 입력은:

- 클릭 공격
- UI 조작
- 단어/자모 선택
- 보상 선택

에 집중한다.

---

# 6. 자모 몬스터

자모는 단순 텍스트가 아니다.

각 자모는 형태에 맞는 고유 Motion Profile을 가진다.

기존 v0.3 방향 유지:

```text
HEAVY_STEP
LIGHT_STEP
BOUNCE
ROLL
SWAY
GLIDE
```

예:

```text
ㄷ → HEAVY_STEP
ㅁ → BOUNCE
ㅇ → ROLL
ㅅ → LIGHT_STEP
ㄹ → SWAY
ㅡ → GLIDE
```

---

# 7. 자모의 역할 3가지

자모 몬스터는 동시에 세 가지 역할을 한다.

## 7.1 전투 대상

정화하지 못하면 마지막 문장을 공격한다.

## 7.2 Gold 공급원

정화 시 Gold를 지급한다.

## 7.3 덱 재료 공급원

정화 시 일정 확률로 **같은 자모**를 드랍한다.

```text
ㄱ 정화
→ Gold
→ 일정 확률로 정화된 ㄱ
```

`ㄱ`을 잡았는데 무작위 `ㅜ`가 떨어지는 구조는 사용하지 않는다.

---

# 8. 자모 드랍

자모 드랍은 전투와 단어 조합을 연결하는 핵심 시스템이다.

```text
자모 정화
↓
동일 자모 드랍 판정
↓
드랍 성공
↓
Wave 임시 보관함
```

Wave 도중 바로 Run Deck에 넣지 않는다.

이유:

- 덱이 자동으로 비대해지는 것을 방지
- 플레이어 선택을 추가
- 원하는 단어를 고려해 자모를 고르게 함

---

# 9. Wave 종료 자모 선택

Wave 종료 시 이번 Wave에서 획득한 자모를 보여준다.

예:

```text
획득

[ㄱ] [ㄹ] [ㅜ] [ㅅ] [ㅏ]
```

플레이어는 정해진 개수만 선택한다.

선택한 자모는 `Run Jamo Deck`에 들어간다.

선택 방식:

```text
추가
또는
기존 자모와 교체
```

를 지원한다.

덱이 무조건 커지는 구조를 피한다.

---

# 10. Run Jamo Deck

각 RUN은 독립적인 자모 덱을 가진다.

기본 구조:

```text
Draw Bag
Discard Bag
```

Word Forge 시작:

```text
Draw Bag에서 자모 Draw
↓
Slot 배치
```

Forge 종료 후 사용된 자모와 사용하지 않은 자모는 Discard로 이동한다.

Draw Bag이 비면 Discard를 섞어 다시 Draw Bag으로 만든다.

---

# 11. 자모는 단어 제작 후 소멸하지 않는다

중요 규칙.

`불`을 만들었다고 해서 `ㅂ`, `ㅜ`, `ㄹ`이 Run Deck에서 영구 삭제되지 않는다.

해당 Forge에서 사용된 뒤 Discard로 이동할 뿐이다.

이유:

- 단어 반복 제작 가능
- 같은 단어 Run Rank 시스템 가능
- 덱빌딩 구조 유지
- 자모 부족으로 RUN이 막히는 현상 방지

---

# 12. 자모 덱 압축

RUN 도중 다음 행동이 가능하다.

- 자모 추가
- 자모 제거
- 자모 교체
- 같은 자모 복제
- 특정 자음/모음 비율 조정

특수 등급 자모는 기본 시스템으로 사용하지 않는다.

다음은 제외한다.

```text
황금 ㄱ
불타는 ㄱ
전설 ㄹ
독성 ㅁ
```

JAMO의 핵심은 **순수한 자모 확률을 조절하는 것**이다.

---

# 13. Word Forge

Wave Clear 후 단어를 복원하는 핵심 화면.

기본 구조:

```text
[ㄱ] [ㅓ] [ㅁ] [ㅂ] [ㅜ] [ㄹ]
```

플레이어 행동:

1. 현재 슬롯 확인
2. 만들 수 있는 단어 확인
3. 필요한 자모 Lock
4. 나머지 슬롯 Reroll
5. 만들 단어 선택
6. 단어 복원

---

# 14. Word Forge 제한 자원

에너지 대신 조합 과정에서 다음이 중요한 제한 자원이다.

- Slot 수
- Reroll 횟수
- Lock 가능 수
- Run Jamo Deck 구성
- 단어 슬롯 수

이 자원들이 플레이어의 판단을 만든다.

---

# 15. 슬롯 단어 판정

현재 슬롯 안에 특정 단어에 필요한 자모가 모두 존재하면 제작 후보로 노출한다.

예:

```text
[ㄱ][ㅓ][ㅁ][ㅂ][ㅜ][ㄹ]
```

가능:

```text
검
불
```

둘 다 만들 수 있어도 기본적으로 **하나만 선택**한다.

---

# 16. 단어 데이터

모든 단어는 개발자가 사전에 정의한다.

전체 국어사전을 자동 지원하지 않는다.

`WordData.tres`

```text
id
word
display_name

required_jamo
slot_type
tags

run_max_rank
effect_ids
rank_values

compound_recipe_ids
synergy_ids

is_risk_word
risk_effect_ids

codex_mastery_curve
hidden_before_discovery

unlock_condition
required_boss_id

icon
vfx_id
sfx_id
```

---

# 17. 단어 종류

## 17.1 장비 단어

직접적인 전투 능력.

예:

- 검
- 칼
- 활
- 창
- 벽

## 17.2 유물 단어

런의 규칙이나 확률을 바꾼다.

예:

- 돈
- 운
- 복

## 17.3 특수효과 단어

상태이상/연쇄 등.

예:

- 불
- 독
- 얼음
- 번개

## 17.4 위험 단어

강한 장점과 명확한 단점을 동시에 가진다.

예:

- 욕심
- 광기
- 폭주
- 탐욕

---

# 18. 단어 슬롯

모든 단어를 무한 보유하지 않는다.

슬롯 종류:

```text
장비
유물
특수효과
위험
```

슬롯이 가득 찬 상태에서 새 단어를 만들면:

```text
기존 단어 교체
또는
새 단어 포기
```

를 선택한다.

---

# 19. 동일 단어 재복원 — Run Rank

현재 RUN에서 이미 가지고 있는 단어를 다시 만들면 새로운 슬롯을 차지하지 않는다.

대신:

```text
Run Rank +1
```

예:

```text
불 Rank 1
→ 불 Rank 2
→ 불 Rank 3
```

Run Rank는 현재 RUN에서만 유지된다.

---

# 20. 복원도와 Run Rank는 다르다

```text
복원도
= 영구

Run Rank
= 현재 RUN
```

예:

```text
복원 사전의 불: 복원도 III

새 RUN 시작
→ 불 미보유

이번 RUN에서 불 제작
→ 불 Rank 1
→ 복원도 III의 영구 보너스 적용
```

복원도가 높아도 단어를 자동으로 가지고 시작하지 않는다.

---

# 21. 단어 계열 시너지

모든 단어는 의미 태그를 가진다.

초기 태그:

```text
무기
방어
화염
독
전기
얼음
경제
행운
자동화
회복
위험
```

시너지는 태그 또는 특정 단어 조합으로 발동한다.

예:

```text
무기 2
→ 작은 공격 보너스

무기 4
→ 추가 전투 효과

화염 2
→ Burn 강화

경제 + 행운
→ 보상 선택 관련 보너스
```

---

# 22. 합성어

특정 단어가 함께 존재할 때 상위 단어를 만들 수 있다.

## 22.1 합체형

```text
A + B
→ C
```

A/B를 소비하고 C를 만든다.

장점:

- 슬롯 압축
- 강한 보상
- 빌드 진화

## 22.2 공존형

A와 B를 유지한 채 별도 시너지만 활성화한다.

합성어는 실제 한국어 의미가 자연스러운 조합을 우선한다.

억지 합성어를 대량 생산하지 않는다.

---

# 23. 위험 단어

위험 단어는 고위험 고보상 선택지다.

UI에는 장점과 단점을 동시에 표시한다.

예:

```text
욕심

장점
Gold 획득 증가

단점
마지막 문장이 받는 피해 증가
```

숨겨진 페널티는 사용하지 않는다.

---

# 24. Wave 구조

기본 규칙:

```text
1~4
일반 Wave

5
중간보스

6~9
일반/강화 Wave

10
단어 보스
```

반복:

```text
5, 15, 25, 35 ...
→ 중간보스

10, 20, 30, 40 ...
→ 단어 보스
```

---

# 25. 일반 Wave

일반 Wave는 다음을 조합해 난이도를 만든다.

- 적 수
- 자모 종류
- 이동속도
- HP
- Spawn 간격
- 특수 자모 비율
- 접근 경로
- 동시에 살아 있는 적 수

단순히 HP만 계속 올리지 않는다.

---

# 26. 중간보스

완성된 단어가 아니라 **강화된 자모 개체**를 중심으로 만든다.

예:

### 거대한 ㅁ

- 높은 HP
- 착지 시 작은 충격
- 일정 HP 이하에서 작은 ㅁ 생성

### 질주 ㅇ

- 빠른 이동
- 큰 원을 그리다 마지막 문장으로 돌진
- 클릭 타이밍 요구

중간보스는 자모 덱을 크게 정리할 수 있는 보상을 준다.

---

# 27. 단어 보스

Wave 10마다 등장.

완성된 단어 자체가 보스다.

핵심 규칙:

> **보스의 패턴은 단어의 의미와 일치해야 한다.**

예:

```text
침묵
→ 단어 일시 봉인

탐욕
→ Gold 획득과 연동된 보호막

망각
→ 단어 일시 비활성

분열
→ 자모 단위로 분해

거울
→ 반복 피해 유형 적응
```

---

# 28. 단어 보스 해금

단어 보스를 처음 정화하면:

- 복원 사전 등록
- 보스 기록 해금
- 일부 고급/위험 단어 제작 풀 해금
- 큰 Gold 보상
- 서고 변화 가능

보스는 단순 체크포인트가 아니라 콘텐츠 해금 장치다.

---

# 29. RUN 실패

조건:

```text
마지막 문장 안정도 <= 0
```

실패 후:

```text
현재 RunState 제거
↓
RUN RESULT
↓
영구 데이터 정산
↓
마지막 서고
```

다음 RUN은 반드시 Wave 1부터 시작한다.

---

# 30. RUN 결과 화면

표시:

- 도달 Wave
- 최고 기록 갱신 여부
- 정화한 자모 수
- 획득 Gold
- 복원한 단어
- 신규 단어
- 복원도 상승
- 합성어
- 활성화했던 시너지
- 정화한 보스
- 이번 RUN 대표 빌드

---

# 31. Main Hub — 마지막 서고

메뉴:

```text
RUN 시작
영구 연구
복원 사전
기록
설정
```

표시:

```text
Gold
최고 Wave
복원 단어 수
정화한 단어 보스 수
```

---

# 32. 영구 연구

Gold는 Main Hub에서만 사용한다.

전투 중 영구 업그레이드를 구매하지 않는다.

카테고리:

## 전투

- 기본 클릭 피해
- 클릭 속도
- 마지막 문장 최대 안정도
- 기본 치명타

## 경제

- Gold 획득량
- 보스 Gold 보너스

## 복원 도구

- 기본 Reroll
- Lock
- Word Forge 슬롯 확장
- 힌트

---

# 33. 복원 사전

표시 정보:

```text
단어
분류
태그
효과
복원 횟수
최고 Run Rank
복원도
관련 단어
발견한 합성어
발견한 시너지
관련 단어 보스
```

미발견:

```text
???
```

힌트 연구에 따라 일부 정보 공개 가능.

---

# 34. 지형 설계 핵심

JAMO의 전투 지형은 **2D로 제작한 오염된 문서 한 장**이다.

일반적인 숲, 성, 던전처럼 이동 가능한 공간을 만드는 것이 아니다.

> **화면 전체에 펼쳐진 한 장의 페이지 위에서 자모들이 마지막 문장을 향해 내려오는 고정형 전장**

으로 정의한다.

플레이어 캐릭터 이동은 없으며, 맵의 역할은 다음에 집중한다.

- 어디서 자모가 내려오는지 즉시 파악
- 클릭해야 할 자모가 서로 겹치지 않도록 공간 제공
- 마지막 문장까지의 위험 거리를 직관적으로 표현
- Wave 진행에 따라 문서가 오염되는 모습 표현
- 단어 보스의 고유 연출 공간 제공

맵 자체가 단어 조합보다 복잡한 게임이 되어서는 안 된다.

---

# 35. 기본 화면과 카메라

JAMO는 **2D 고정 화면**을 기본으로 한다.

기준 해상도:

```text
1920 × 1080
```

Godot에서는 기본적으로 `Camera2D` 이동에 의존하지 않고,
한 화면 안에 전투 영역 전체가 항상 들어오게 구성한다.

배경 그림 자체에 약한 사선 원근감을 줄 수는 있다.
하지만 이것은 **2.5D/3D 공간이 아니라 2D 일러스트의 표현**이다.

권장 화면:

```text
┌────────────────────────────────────┐
│ Spawn A       Spawn B      Spawn C │
│    ↓             ↓            ↓    │
│                                    │
│      ㄱ          ㅁ        ㅅ       │
│          ㅇ           ㄹ            │
│                                    │
│       흐릿한 문장 / 먹자국         │
│                                    │
│              [마지막 문장]          │
└────────────────────────────────────┘
```

권장 위치:

- Spawn A: 좌상단
- Spawn B: 상단 중앙
- Spawn C: 우상단
- 마지막 문장: 하단 중앙
- Word/Build HUD: 하단 가장자리 또는 접이식 패널

플레이어 시선은 항상:

```text
Spawn → 접근 중인 자모 → 마지막 문장
```

방향으로 읽혀야 한다.

---

# 36. 3개의 접근 흐름

360도 모든 방향에서 적이 등장하지 않는다.

기본 전장은 세 개의 넓은 접근 흐름을 사용한다.

```text
LEFT FLOW
CENTER FLOW
RIGHT FLOW
```

각 Flow는 고정된 좁은 레일이 아니다.

자모가 각 영역 안에서 좌우로 약간 흔들리거나 서로 피하면서 내려올 수 있는 **넓은 통로**다.

이 구조를 쓰는 이유:

- 화면 전체를 빠르게 읽을 수 있음
- 자모 클릭 판정이 한 줄로 겹치지 않음
- 필요한 자모가 어디에 있는지 즉시 발견 가능
- 중간보스/특수 자모를 다른 Flow에 배치하기 쉬움
- 1인 개발로 Path 제어가 단순함

---

# 37. 문장 행은 시각적 경로

페이지에 희미하게 남아 있는 글줄을 적의 이동 방향을 암시하는 데 사용한다.

단, 실제 게임에서 자모를 **글자 한 줄 위에 정확히 맞춰 걷게 만들 필요는 없다.**

문장 행은 플레이어에게 다음을 알려주는 시각 가이드다.

```text
여기에서 시작
↓
이 방향으로 침식
↓
마지막 문장
```

실제 이동은 `Path2D/Curve2D` 또는 단순 Target 이동을 사용하고,
문장 행과 대략적인 방향만 일치시키면 된다.

즉:

> 문장 행은 '길처럼 보이는 배경'이고, 실제 이동 로직은 별도의 보이지 않는 2D Path다.

---

# 38. 2D 맵 레이어 구조

배경 한 장에 모든 효과를 합쳐놓지 않는다.

권장 레이어:

```text
PageBackground
├─ PaperBase
├─ FadedTextLayer
├─ InkStainLayer
├─ TearLayer
├─ DecorationLayer
├─ PathGuideLayer
├─ SpawnFXLayer
├─ GameplayLayer
│  ├─ Jamo
│  ├─ Boss
│  └─ LastSentence
├─ EffectLayer
└─ UILayer
```

이렇게 분리하면 Wave가 올라갈 때 배경을 새로 만들지 않고:

- 먹 번짐 표시
- 일부 글줄 숨김
- 찢어진 종이 Overlay 표시
- 보스 전용 Overlay 활성화

만으로 변화시킬 수 있다.

---

# 39. 지형 오브젝트

MVP에서는 물리 충돌을 만드는 장애물을 거의 사용하지 않는다.

대부분의 요소는 **배경 장식 또는 Overlay**다.

사용 가능:

- 먹 번짐
- 종이 찢김
- 희미한 밑줄
- 교정부호
- 연필 자국
- 작은 종이 조각
- 책갈피 흔적
- 지워진 문장

피해야 할 것:

- 자모를 가리는 거대한 전경 오브젝트
- 복잡한 미로
- 클릭을 방해하는 장식
- 자모보다 눈에 띄는 배경 효과
- 깊은 원근 때문에 클릭 위치가 헷갈리는 구성

---

# 40. Wave에 따른 페이지 변화

여러 개의 맵을 만드는 대신 **같은 페이지가 점점 망가지는 방식**을 우선한다.

## Wave 1~10 — 빈 원고

- 밝은 아이보리 종이
- 아주 희미한 문장
- 소량의 먹자국
- 비교적 깨끗한 화면

## Wave 11~20 — 먹 번짐

- 페이지 외곽에서 먹이 조금씩 번짐
- 일부 문장이 흐려짐
- Spawn 지점 주변 오염 증가

## Wave 21~30 — 찢어진 기록

- 모서리/일부 가장자리 찢김 Overlay
- 문장 행 일부가 끊어짐
- 작은 종이 조각 연출

## Wave 31~40 — 뒤엉킨 기록

- 일부 문장 중첩
- 검은 교정선
- 자모 잔상
- 오염 범위 확대

## Wave 41~50 — 백지화

- 기존 글자가 오히려 사라지기 시작
- 여백 증가
- 마지막 문장만 상대적으로 선명

중요:

> 위 변화는 우선 **시각 변화**이며, 별도의 새 맵을 만들지 않는다.

---

# 41. 지형 기믹과 보스 페이지

MVP에서는 지형 기믹을 최소화한다.

재미 검증 이후 후보:

### 먹 웅덩이

지나는 자모의 이동속도가 소폭 변한다.

### 지워진 행

해당 영역에서 자모가 잠시 흐릿해진다.

### 찢어진 틈

일부 자모의 이동 경로가 우회된다.

### 붉은 교정부호

특정 조건에서 클릭 가능한 일회성 보조 오브젝트가 될 수 있다.

## 단어 보스 페이지 변화

새로운 3D 맵을 만드는 대신 현재 2D 페이지의 Overlay와 Shader를 바꾼다.

### 침묵

- 배경 문장 Fade Out
- SFX 감소
- 여백이 넓어 보이게 Dim 처리

### 분열

- 화면에 종이 균열선 Overlay
- 보스가 자모 단위로 흩어져 다른 Flow로 이동

### 거울

- 페이지 중앙 세로선
- 좌우 대칭 효과
- 일부 Spawn을 반사된 것처럼 표현

보스별 차별화는 **배경 새 제작보다 2D Overlay / Shader / Particle / UI 변화**를 우선한다.

---

# 42. UI 배치

권장 기본 HUD:

```text
좌상단
WAVE

상단 중앙
마지막 문장 안정도

우상단
Gold

하단
현재 단어 / 시너지 요약

우측 접이식
상세 빌드
```

전투 중 Word Forge UI는 닫혀 있어야 한다.

Wave Clear 후 별도 Overlay로 열린다.

---

# 43. 자모 드랍 UI

정화 성공 시 자모 드랍:

- 자모 위에 작은 빛/먹 조각
- 자동으로 임시 보관함으로 이동
- 작은 아이콘만 표시
- 클릭해서 주울 필요 없음

전투 중 줍기 조작은 추가하지 않는다.

---

# 44. Word Forge UI

중앙:

```text
[ㄱ][ㅓ][ㅁ][ㅂ][ㅜ][ㄹ]
```

각 칸:

- 클릭 → Lock
- Lock 표시
- 사용 가능 단어에 포함되면 작은 연결 표시

하단:

```text
REROLL
남은 횟수
```

우측:

```text
현재 제작 가능 단어
```

Hover:

- 단어 뜻
- 분류
- 효과
- 현재 Run Rank
- 현재 시너지 변화
- 신규 도감 여부

---

# 45. 자모 선택 화면

Wave Clear 후:

```text
이번 Wave에서 회수한 자모
```

보여준다.

각 카드:

- 자모
- 현재 Run Deck 보유 수
- 이 자모로 접근 가능한 주요 단어 일부
- 추가 / 교체

초반에는 정보 과잉을 피하기 위해
가능 단어 힌트는 영구 연구와 연동 가능.

---

# 46. 완전 꽝 방지

JAMO는 RNG 게임이지만
`아무 단어도 못 만들고 아무 선택도 못 하는 상황`이 반복되면 안 된다.

보정 위치:

1. 자모 몬스터 Spawn
2. 자모 Drop Pity
3. Wave 종료 선택
4. Word Forge Reroll
5. 미성공 Forge 보상

원하는 단어를 확정 지급하는 것이 아니라,
**플레이 가능한 선택지를 보장**한다.

---

# 47. Spawn 보정

현재 Run Deck과 현재 단어 상태를 참고해
유용할 가능성이 있는 자모 Spawn 가중치를 아주 약하게 보정할 수 있다.

예:

`불` 관련 빌드를 가고 있어도 `ㄹ`이 확정 출현하지 않는다.

단지 극단적인 미출현만 줄인다.

---

# 48. Word Forge 실패

Reroll을 모두 사용했는데 유효 단어가 하나도 없는 경우.

MVP 보정:

```text
이번 Forge 포기
→ 다음 Forge Reroll +1
```

보정은 제한적으로 누적한다.

---

# 49. 자동화

완전 방치형을 목표로 하지 않는다.

자동 공격 단어/유물은 존재할 수 있다.

하지만:

- 단어 선택
- 덱 압축
- 보스 대응
- 위험 단어 선택

은 플레이어 판단 영역으로 남긴다.

오프라인 진행은 MVP에서 제외한다.

---

# 50. 상태이상

기존 구조 유지.

```text
Burn
Poison
Bleed
Slow
Freeze
Shock
```

중요:

```text
복원 사전에 '불'이 있음
≠ Burn 상시 활성

현재 RUN에서 '불'을 복원
= Burn 활성
```

상태이상은 `StatusEffect Resource` 기반.

---

# 51. 2D 아트 제작 방식

JAMO의 기본 제작 파이프라인은 **2D 전용**으로 한다.

## 51.1 Blender/3D 사용 여부

핵심 게임 제작에 Blender를 사용하지 않는다.

필요하지 않은 것:

- 3D 자모 모델링
- 리깅
- 3D 캐릭터 애니메이션
- 3D 전투맵 제작
- 3D 조명 세팅
- 3D 카메라 세팅

특별한 홍보 영상이나 별도 연출을 위해 3D를 실험할 수는 있지만,
게임 플레이 에셋의 필수 파이프라인으로 두지 않는다.

## 51.2 자모 제작

자모 기본 노드:

```text
JamoMonster (Node2D)
├─ AnimatedSprite2D
├─ Shadow (Sprite2D)
├─ ClickArea (Area2D)
│  └─ CollisionShape2D
├─ StatusFX (Node2D)
├─ DropFXAnchor (Marker2D)
├─ AnimationPlayer
└─ AudioStreamPlayer2D
```

자모는 프레임 애니메이션이 많지 않아도 된다.

Godot에서 다음 조합으로 움직임을 만든다.

- Sprite frame 2~6장
- Scale squash/stretch
- Position bounce
- Rotation
- Shadow scale
- Tween
- AnimationPlayer

즉, 자모 하나마다 16~30프레임 애니메이션을 제작하는 방식은 기본으로 요구하지 않는다.

## 51.3 맵 제작

맵은 다음 단위로 준비한다.

```text
paper_base.png
faded_text.png
ink_overlay_01.png
ink_overlay_02.png
tear_overlay.png
correction_marks.png
boss_overlay_xxx.png
```

배경 전체는 한 장의 2D 그림으로 만들 수 있고,
Wave 변화가 필요한 부분만 투명 PNG 레이어로 분리한다.

## 51.4 권장 스타일

- 심플한 일러스트
- 따뜻한 종이색
- 명확한 검은/먹색 자모
- 약한 그림자
- 너무 사실적인 질감 금지
- 과도한 광원/Glow 금지
- UI가 배경보다 선명해야 함

목표는 '웅장한 판타지 게임'이 아니라:

> **책상 위의 살아 움직이는 페이지를 직접 만지는 듯한 작고 아기자기한 게임**

이다.

---

# 52. Godot 폴더 구조

```text
res://

├─ autoload/
│  ├─ meta_state.gd
│  ├─ run_state.gd
│  ├─ save_manager.gd
│  ├─ signal_bus.gd
│  └─ audio_manager.gd
│
├─ scenes/
│  ├─ hub/
│  │  └─ last_library.tscn
│  │
│  ├─ run/
│  │  ├─ run_game.tscn
│  │  ├─ corrupted_page.tscn
│  │  ├─ page_background.tscn
│  │  ├─ path_layer.tscn
│  │  └─ wave_controller.tscn
│  │
│  ├─ monsters/
│  │  ├─ jamo_monster_base.tscn
│  │  ├─ consonant/
│  │  ├─ vowel/
│  │  ├─ special/
│  │  └─ bosses/
│  ├─ objective/
│  │  └─ last_sentence.tscn
│  ├─ effects/
│  └─ ui/
│     ├─ hud.tscn
│     ├─ wave_clear.tscn
│     ├─ jamo_reward.tscn
│     ├─ word_forge.tscn
│     ├─ run_word_inventory.tscn
│     ├─ synergy_panel.tscn
│     ├─ run_result.tscn
│     ├─ codex.tscn
│     ├─ permanent_research.tscn
│     └─ settings.tscn
│
├─ resources/
│  ├─ monsters/
│  ├─ motion_profiles/
│  ├─ words/
│  ├─ compound_recipes/
│  ├─ synergies/
│  ├─ bosses/
│  ├─ waves/
│  ├─ permanent_upgrades/
│  ├─ status_effects/
│  └─ balance/
│
├─ scripts/
│  ├─ combat/
│  ├─ wave/
│  ├─ monsters/
│  ├─ jamo_deck/
│  ├─ word_system/
│  ├─ codex/
│  ├─ upgrades/
│  └─ ui/
├─ shaders/
├─ audio/
├─ fonts/
└─ art/
   ├─ backgrounds/
   ├─ jamo/
   ├─ bosses/
   ├─ overlays/
   ├─ effects/
   └─ ui/
```

## 52.1 핵심 2D Scene 구조

`jamo_monster_base.tscn`:

```text
JamoMonsterBase (Node2D)
├─ AnimatedSprite2D
├─ Shadow (Sprite2D)
├─ ClickArea (Area2D)
│  └─ CollisionShape2D
├─ AnimationPlayer
├─ StatusEffectAnchor (Marker2D)
├─ DropFXAnchor (Marker2D)
└─ AudioStreamPlayer2D
```

`corrupted_page.tscn`:

```text
CorruptedPage (Node2D)
├─ PaperBase (Sprite2D)
├─ FadedTextLayer (Node2D)
├─ InkOverlayLayer (Node2D)
├─ TearOverlayLayer (Node2D)
├─ PathLayer (Node2D)
│  ├─ LeftPath (Path2D)
│  ├─ CenterPath (Path2D)
│  └─ RightPath (Path2D)
├─ SpawnPoints (Node2D)
├─ GameplayLayer (Node2D)
├─ EffectLayer (Node2D)
└─ LastSentence
```

---

# 53. MetaState

영구:

```text
save_version

gold
permanent_upgrade_levels

codex_words
codex_restoration_exp
codex_restoration_levels

discovered_compounds
discovered_synergies

defeated_word_bosses
highest_wave

statistics
settings
```

---

# 54. RunState

현재 RUN:

```text
current_wave

last_sentence_hp
last_sentence_max_hp

jamo_draw_bag
jamo_discard_bag

current_forge_slots
rerolls
locks

equipped_words
run_word_ranks

active_synergies
active_compounds
risk_words

temporary_jamo_drops
run_modifiers
run_statistics
```

---

# 55. 저장

영구 저장 시점:

- Gold 정산
- 영구 연구 구매
- 복원 사전 신규 등록
- 복원도 증가
- 단어 보스 정화
- RUN 종료
- 설정 변경

현재 RUN 이어하기용 임시 저장:

- Wave Clear 직후
- 게임 종료 요청

패배 후 임시 RunState는 삭제한다.

---

# 56. 개발 원칙

코드 전용 Godot 프로젝트 금지.

필수:

```text
.tscn = 구조
.tres = 데이터
AnimationPlayer = 연출
Theme Resource = UI
.gd = 로직
```

다음 데이터는 스크립트에 하드코딩하지 않는다.

- Wave
- Monster
- Word
- Jamo Deck
- Synergy
- Compound
- Boss
- Permanent Upgrade
- Balance

---

# 57. AI 개발 지시 고정 문구

```text
Do not implement JAMO as a code-only Godot project.

Use Godot scenes (.tscn), Resources (.tres), AnimationPlayer,
Node2D, Sprite2D, AnimatedSprite2D, Area2D, CollisionShape2D,
Control nodes, Theme Resources, Inspector-exposed properties,
and reusable packed scenes.

Do not require Blender, 3D models, CharacterBody3D, MeshInstance3D,
or a 3D camera pipeline for the core game.

The project owner must be able to inspect and tune the game
inside the Godot Editor without rewriting gameplay code.

Do not hard-code wave data, word data, jamo-deck data,
boss data, synergy data, compound recipes,
monster data, permanent upgrades, or balance tables
inside gameplay scripts.

Separate permanent MetaState and temporary RunState.

A failed run must reset:
- current wave
- run jamo deck changes
- run words
- run ranks
- synergies
- compounds
- risk words

A failed run must preserve:
- Gold
- permanent research
- Codex discoveries
- Word Restoration levels
- defeated bosses
- highest-wave records.
```

---

# 58. 개발 Phase

## Phase 0 — 구조 재정리

- Day 제거
- Energy 제거
- Main Hub 분리
- MetaState / RunState 분리
- LastSentence 생성
- 기존 단어 영구 효과 제거

## Phase 1 — Wave 전투

- 페이지 맵
- Spawn
- 경로
- 클릭
- 마지막 문장 피해
- Gold
- Wave Clear/Fail

## Phase 2 — 자모 드랍

- 동일 자모 Drop
- 임시 보관함
- Wave Clear 선택
- Run Deck 추가/교체

## Phase 3 — Word Forge

- Draw Bag
- Discard Bag
- 6 Slot
- Lock
- Reroll
- 단어 판정
- 단어 복원

## Phase 4 — RUN 단어

- 장비
- 유물
- 특수효과
- 위험
- Run Rank
- 교체

## Phase 5 — 복원 사전

- 신규 등록
- 복원도
- 힌트
- UI

## Phase 6 — 영구 Gold 성장

- Main Hub 연구
- 저장

## Phase 7 — 시너지

최초 3계열.

## Phase 8 — 합성어

최초 5개 이상.

## Phase 9 — 중간보스

Wave 5 / 15.

## Phase 10 — 단어 보스

Wave 10 / 20.

## Phase 11 — 지형 연출

- 빈 원고
- 먹 번짐
- 찢어진 기록
- 보스별 페이지 변형

## Phase 12 — Juice

- 단어 복원 연출
- 정화
- 자모 Drop
- Boss Intro
- Camera Shake
- SFX/VFX

---

# 59. Vertical Slice

첫 재미 검증 범위:

```text
Wave 1~20

맵 1개
맵 시각 상태 2개

자모 12종 이상
특수 자모 3종

단어 20~30개

장비/유물/특수효과
위험 단어 3개

시너지 3계열
합성어 5개 이상

중간보스 2종
단어 보스 2종

복원 사전
복원도

Gold 영구 연구 6~8종

Save/Load
```

이 단계에서 재미가 없으면 단어 수나 맵 수를 늘리지 않는다.

---

# 60. MVP에서 하지 않을 것

- 전체 국어사전 자동 인식
- 100개 이상의 단어
- 여러 지역 맵
- 복잡한 NPC 시스템
- 오프라인 진행
- 온라인 기능
- 자모 등급 시스템
- 자모 장비 시스템
- 복잡한 지형 퍼즐
- 플레이어 캐릭터 이동
- 스토리 컷신 대량 제작

---

# 61. 현재 확정 핵심

1. Wave 기반 로그라이트
2. 실패 시 Wave 1
3. Gold 영구 유지
4. Gold 연구 영구 유지
5. 복원 사전 영구 유지
6. 복원도 영구 유지
7. RUN 단어 초기화
8. Run Jamo Deck 초기화
9. 자모를 정화하면 일정 확률로 동일 자모 드랍
10. Wave 종료 후 드랍 자모 중 선택
11. 선택 자모를 Run Deck에 추가/교체
12. 6칸 Word Forge
13. Lock / Reroll
14. 단어 = 아이템/유물/특수효과/위험
15. 동일 단어 재복원 = Run Rank
16. 단어 계열 시너지
17. 합성어
18. 위험 단어
19. 5 Wave 중간보스
20. 10 Wave 단어 보스
21. 클릭 에너지 삭제
22. 페이지형 2D 고정 전장
23. 마지막 문장 방어
24. 단어 뜻과 효과 일치
25. 코드 전용 Godot 구현 금지

---

**문서 버전:** v0.6  
**프로젝트:** JAMO  
**문서 역할:** 실제 게임 규칙 / 맵 / UI / 구현 기준
