# JAMO — 디테일 밸런스 계획서 v0.1

> 문서 역할: **숫자, 확률, 성장 곡선, 테스트 목표치만 관리한다.**  
> 게임 규칙: `JAMO_02_game_design_v0.6.md`  
> 스토리 용어: `JAMO_01_story_world_v0.2.md`

> 아래 수치는 출시 확정값이 아니라 **첫 프로토타입 테스트 기준값**이다.  
> 실제 재미 검증 후 로그 데이터를 기준으로 조정한다.

---

# 0. 밸런스 원칙

JAMO의 밸런스는 다음 순서로 판단한다.

```text
1. 플레이어에게 선택이 있는가
2. 원하는 빌드를 강제로 주지 않는가
3. 아무것도 할 수 없는 RUN이 지나치게 자주 나오지 않는가
4. 영구 성장만으로 모든 문제가 해결되지 않는가
5. 단어 조합이 클릭 전투보다 중요하게 느껴지는가
6. 실패해도 다음 도전 이유가 남는가
```

---

# 1. 목표 RUN 길이

Vertical Slice 기준 Wave 1~20.

목표:

```text
초보자 첫 RUN
5~10분

조금 성장한 사용자
10~18분

Wave 20 도달 RUN
15~25분
```

한 Wave 평균:

```text
일반 Wave
25~45초

중간보스
45~70초

단어 보스
60~100초
```

Wave Clear + Word Forge:

```text
20~40초
```

---

# 2. 클릭 입력

초기:

```text
Base Click Damage = 1
Manual Click Cooldown = 0.20초
```

이론 최대:

```text
초당 5회
```

목표:

- 초반 일반 적: 1~4회 클릭
- 중반 일반 적: 빌드가 없으면 3~7회
- 강한 빌드: 상태이상/자동 공격으로 클릭 부담 감소

권장 하한:

```text
0.12초
```

---

# 3. 마지막 문장

초기:

```text
Max Stability = 100
```

일반 적 도달 피해:

```text
기본 8
```

강화 적:

```text
10~16
```

중간보스 접촉/공격:

```text
15~25
```

단어 보스는 일반 접촉보다 패턴 피해 중심.

목표:

> 초반에는 일반 자모 약 12마리를 완전히 놓치면 패배하는 정도.

---

# 4. 일반 적 기본값

Wave 1 기준 일반 자모:

```text
HP = 2
Gold = 1
Move Speed = 1.00x
Last Sentence Damage = 8
```

기본 보정:

| 유형 | HP | 이동속도 | Gold | 특징 |
|---|---:|---:|---:|---|
| LIGHT | 0.8x | 1.25x | 1.0x | 작고 빠름 |
| NORMAL | 1.0x | 1.0x | 1.0x | 기준 |
| HEAVY | 1.8x | 0.75x | 1.5x | 느리고 단단 |
| SPECIAL | 별도 | 별도 | 2~4x | 패턴 보유 |

---

# 5. Wave HP 성장

일반 적 기본 HP 배율 권장:

```text
WaveHP = BaseHP × 1.11^(Wave - 1)
```

실제 게임에서는 WaveData에서 정수 구간값으로 관리한다.

초기 가이드:

```text
W1  : 2
W2  : 2
W3  : 3
W4  : 3

W6  : 4
W7  : 4
W8  : 5
W9  : 5

W11 : 6
W12 : 6
W13 : 7
W14 : 7

W16 : 8
W17 : 9
W18 : 10
W19 : 11
```

---

# 6. 일반 Wave 적 수

| Wave | 총 적 수 | 최대 동시 | Spawn 간격 |
|---|---:|---:|---:|
| 1 | 8 | 4 | 1.00s |
| 2 | 10 | 5 | 0.95s |
| 3 | 12 | 5 | 0.90s |
| 4 | 14 | 6 | 0.85s |
| 6 | 14 | 6 | 0.80s |
| 7 | 16 | 7 | 0.78s |
| 8 | 18 | 7 | 0.75s |
| 9 | 20 | 8 | 0.72s |
| 11 | 18 | 8 | 0.70s |
| 12 | 20 | 8 | 0.68s |
| 13 | 22 | 9 | 0.66s |
| 14 | 24 | 9 | 0.64s |
| 16 | 22 | 9 | 0.62s |
| 17 | 24 | 10 | 0.60s |
| 18 | 26 | 10 | 0.58s |
| 19 | 28 | 11 | 0.56s |

Wave 5/10/15/20은 별도 BossData 사용.

---

# 7. 자모 드랍

초기 기준:

```text
Base Jamo Drop Chance = 25%
```

자모가 정화되면 **같은 자모**가 드랍된다.

예:

```text
ㅂ 정화
→ 25% 확률
→ ㅂ 드랍
```

---

# 8. 자모 Drop Pity

극단적인 운 나쁨을 줄인다.

같은 Wave 안에서:

```text
연속 4회 미드랍
→ 다음 일반 자모 정화 시 자모 드랍 확정
```

확정 드랍 후 카운터 초기화.

---

# 9. Wave당 드랍 상한

권장:

```text
Normal Wave Drop Cap = 6
```

6개 이후에는 자모 드랍 판정을 중지한다.

MVP에서는 단순하게 처리하고,
추후 소량 Gold 대체를 검토한다.

---

# 10. Wave 종료 자모 선택

Normal Wave:

```text
획득 자모 중 1개 선택
```

다음 조건에서는 2개 선택 가능:

```text
희귀 보상
특정 유물
중간보스 보상
단어 보스 보상
```

기본적으로 매 Wave 2개씩 넣지 않는다.

---

# 11. Run Jamo Deck 시작값

Starter Deck A:

```text
ㄱ ×2
ㄴ ×1
ㄷ ×1
ㄹ ×1
ㅁ ×1
ㅂ ×1
ㅅ ×1
ㅇ ×2
ㅎ ×1

ㅏ ×2
ㅓ ×1
ㅗ ×1
ㅜ ×2
ㅡ ×1
ㅣ ×1
```

총:

```text
19개
```

목적:

- 기본 자음/모음 노출
- 사용 빈도 높은 일부 자모 중복
- 지나치게 작은 덱으로 같은 단어만 반복되는 문제 방지

이 구성은 반드시 플레이테스트 후 재조정한다.

---

# 12. Run Deck 권장 크기

```text
초반
18~22

중반
20~28

후반
18~30
```

30개 이상이 자주 되면 덱 압축 의미가 약해질 가능성이 높다.

---

# 13. Word Forge 기본값

```text
Forge Slot Count = 6
Base Reroll = 2
Base Lock Count = 2
Word Craft per Forge = 1
```

목표:

- 첫 Draw에서 바로 만들면 기분 좋음
- Reroll 1~2회에서 의미 있는 선택 가능
- 원하는 특정 단어를 매번 확정할 수는 없음

---

# 14. Forge 슬롯 확장

영구 연구 후보:

```text
6 → 7
7 → 8
```

7/8 Slot은 긴 고급 단어를 만들 수 있는 콘텐츠 해금 역할도 할 수 있다.

권장:

```text
7 Slot = 중기
8 Slot = 후반
```

---

# 15. Reroll

기본:

```text
2회 / Forge
```

영구 연구:

```text
2 → 3
```

최대 권장:

```text
4
```

5회 이상이 되면 RNG를 사실상 무시할 가능성이 높다.

---

# 16. Lock

기본:

```text
2칸
```

영구 연구:

```text
2 → 3
```

최대 권장:

```text
4칸
```

---

# 17. Forge 실패 보정

Reroll을 모두 사용했는데 유효 단어가 하나도 없는 경우:

```text
다음 Forge Reroll +1
```

최대 누적:

```text
+2
```

단어를 만들면 보정 초기화.

---

# 18. Spawn 가중 보정

현재 Run Deck과 활성 빌드에서 유용할 가능성이 있는 자모의 Spawn Weight를 소폭 보정한다.

권장:

```text
+0% ~ +15%
```

15%를 크게 넘기지 않는다.

필요 자모를 확정 Spawn하지 않는다.

---

# 19. 단어 슬롯 초기값

프로토타입:

```text
장비: 3
유물: 3
특수효과: 2
위험: 1
```

중기 확장:

```text
장비: 최대 4
유물: 최대 4
특수효과: 최대 3
위험: 최대 2
```

---

# 20. Run Rank

기본:

```text
Rank 1
Rank 2
Rank 3
```

MVP 최대:

```text
Rank 3
```

성장:

```text
동일 단어 재복원
→ Rank +1
```

---

# 21. Run Rank 수치 증가

기본적인 숫자형 단어:

```text
Rank 1 = 100%
Rank 2 = 140%
Rank 3 = 180%
```

단순 배율만 주지 않고 Rank 2/3에서 기능 변화가 생기는 단어를 일부 섞는다.

---

# 22. 복원도

영구 복원도:

```text
I
II
III
IV
V
```

권장 누적 EXP:

```text
I   = 발견 즉시
II  = 100
III = 300
IV  = 700
V   = 1,500
```

---

# 23. 복원 EXP

한 RUN에서 동일 단어 반복 농사 방지.

```text
RUN 첫 복원
+40 EXP

두 번째
+20 EXP

세 번째 이후
+8 EXP
```

한 RUN 단어별 최대:

```text
80 EXP
```

---

# 24. 복원도 영구 전투 보너스

복원도 V 기준 전체 전투 보너스는 작게 유지한다.

예:

```text
I   0%
II  +3%
III +6%
IV  +9%
V   +12%
```

나머지는 다음으로 보상한다.

- 합성 힌트
- 관련 단어 공개
- 시너지 공개
- 보스 정보

---

# 25. Gold 획득

Normal:

```text
1G × Wave Gold Multiplier
```

Heavy:

```text
1.5~2G
```

Special:

```text
3~5G
```

중간보스:

```text
30~50G
```

단어 보스:

```text
80~150G
```

구간 배율:

```text
W1~10   1.0x
W11~20  1.4x
W21~30  2.0x
W31~40  2.8x
```

---

# 26. RUN당 Gold 목표

첫 RUN:

```text
100~250G
```

Wave 10 부근:

```text
250~500G 누적
```

Wave 20 클리어:

```text
700~1,200G 누적
```

초반에는 한 RUN 후 영구 연구 최소 1개를 구매할 수 있어야 한다.

---

# 27. Gold 영구 연구 — 1차 가격표

## 기본 클릭 피해

```text
Lv0 = 1

Lv1 +1 / 100G
Lv2 +1 / 250G
Lv3 +1 / 600G
Lv4 +1 / 1,400G
Lv5 +1 / 3,200G
```

초반 Wave가 지나치게 무의미해지면 Flat 증가 대신 배율형으로 변경한다.

## 마지막 문장 최대 안정도

```text
Lv0 100

Lv1 110 / 120G
Lv2 120 / 300G
Lv3 135 / 750G
Lv4 150 / 1,800G
Lv5 170 / 4,000G
```

## Gold 획득

```text
Lv0 +0%

Lv1 +5%  / 150G
Lv2 +10% / 400G
Lv3 +15% / 1,000G
Lv4 +20% / 2,500G
Lv5 +25% / 6,000G
```

## 클릭 속도

```text
Lv0 0.20s

Lv1 0.19s / 250G
Lv2 0.18s / 700G
Lv3 0.17s / 1,800G
Lv4 0.16s / 4,500G
```

## 기본 Reroll

```text
2 → 3
가격: 2,500G
조건: 최고 Wave 10
```

```text
3 → 4
가격: 15,000G
조건: 최고 Wave 30
```

## Lock

```text
2 → 3
가격: 3,500G
조건: 최고 Wave 15
```

```text
3 → 4
가격: 20,000G
조건: 최고 Wave 40
```

## Forge Slot

```text
6 → 7
가격: 8,000G
조건: 단어 보스 2종 정화
```

```text
7 → 8
가격: 35,000G
조건: 최고 Wave 50
```

---

# 28. 영구 성장 제한

Gold 연구만으로 Wave 1~10이 완전 자동 통과되면 실패.

영구 공격력은 기초 체급만 올리고,
RUN 단어 빌드가 실제 고점을 결정해야 한다.

---

# 29. 초기 단어 — 검

```text
종류: 장비
태그: 무기

Rank 1
Click Damage +15%

Rank 2
+25%

Rank 3
+40%
```

---

# 30. 초기 단어 — 칼

```text
종류: 장비
태그: 무기

Rank 1
Crit Chance +5%p

Rank 2
+8%p

Rank 3
+12%p
```

---

# 31. 초기 단어 — 창

```text
종류: 장비
태그: 무기

Rank 1
클릭 시 15% 확률
뒤쪽 적 1명에게 50% 피해

Rank 2
20% / 60%

Rank 3
25% / 70%
```

---

# 32. 초기 단어 — 벽

```text
종류: 장비/방어

Rank 1
마지막 문장 피해 -8%

Rank 2
-14%

Rank 3
-20%
```

전체 피해 감소 상한:

```text
50%
```

---

# 33. 초기 단어 — 불

```text
종류: 특수효과
태그: 화염

Rank 1
클릭 시 25% 확률
3초
1초마다 1 피해

Rank 2
35%
4초

Rank 3
40%
4초
정화 시 주변 1명에게 30% 확률 전이
```

---

# 34. 초기 단어 — 독

```text
종류: 특수효과
태그: 독

Rank 1
클릭 시 30%
4초
2초마다 1
최대 3스택

Rank 2
최대 4스택

Rank 3
최대 5스택
최대 스택 적은 받는 클릭 피해 +10%
```

---

# 35. 초기 단어 — 얼음

```text
종류: 특수효과
태그: 얼음

Rank 1
20% 확률
2초간 이동속도 -25%

Rank 2
25%
-30%

Rank 3
30%
3초
-35%
```

Boss에는 둔화 효율 감소 적용 가능.

---

# 36. 초기 단어 — 돈

```text
종류: 유물
태그: 경제

Rank 1
RUN Gold +15%

Rank 2
+25%

Rank 3
+40%
```

영구 Gold Bonus와 RUN Gold Bonus가 지나치게 곱연산되지 않도록 한다.

---

# 37. 초기 단어 — 운

```text
종류: 유물
태그: 행운

Rank 1
Wave 종료 시 희귀 보상 가중치 +8%

Rank 2
+14%

Rank 3
+20%
```

희귀 보상을 확정하지 않는다.

---

# 38. 초기 단어 — 복

```text
종류: 유물
태그: 행운

Rank 1
Forge Reroll 사용 시 10% 확률 미소모

Rank 2
15%

Rank 3
20%
```

상한:

```text
25%
```

---

# 39. 초기 위험 단어

## 욕심

```text
RUN Gold +45%
마지막 문장 받는 피해 +20%
```

Rank 2:

```text
Gold +60%
피해 +25%
```

Rank 3:

```text
Gold +80%
피해 +30%
```

## 광기

```text
Click Damage +40%
Manual Click Cooldown -15%
마지막 문장 Max Stability -20%
```

## 폭주

자동 공격이 존재하는 빌드에서만 후보에 넣는다.

```text
Auto Interval -35%
특수 자모 Spawn Rate +20%
```

---

# 40. 시너지 수치

## 무기

```text
무기 2
Click Damage +10%

무기 4
Crit Damage +25%
```

## 화염

```text
화염 2
Burn Duration +20%

화염 4
Burn 중 정화 시
주변 전이 확률 +15%p
```

## 경제 + 행운

```text
경제 단어 1+
행운 단어 1+

Wave 보상에서
추가 선택지 출현 확률 10%
```

---

# 41. 합성어 밸런스 원칙

합성어 권장 가치:

```text
재료 2개 총합의 120~160%
```

추가 가치:

- 슬롯 1칸 압축
- 새 기능
- 시너지 연결

합성어가 모든 빌드의 필수 정답이 되면 실패.

---

# 42. 중간보스 기준

Wave 5:

```text
HP 약 30~40
전용 패턴 1개
```

Wave 15:

```text
HP 약 100~140
전용 패턴 1~2개
```

목표 전투 시간:

```text
40~70초
```

보상:

```text
Gold
+
자모 선택 2개
+
Deck 정리 1회
```

Deck 정리:

```text
자모 1개 제거
또는
자모 1개 교체
```

---

# 43. 단어 보스 기준

Wave 10:

```text
HP 120~160
Phase 2
패턴 2개
```

Wave 20:

```text
HP 300~450
Phase 2~3
패턴 2~3개
```

목표:

```text
60~100초
```

DPS 부족만으로 막기보다 패턴 대응을 섞는다.

---

# 44. Wave 10 — 침묵 초안

```text
HP = 140
```

패턴:

```text
12초마다
현재 장착 단어 중 1개
4초간 봉인
```

같은 단어 연속 봉인 방지.

Phase 2:

```text
HP 50% 이하
봉인 주기 10초
```

---

# 45. Wave 20 — 탐욕 초안

```text
HP = 380
```

패턴:

```text
전투 중 Gold 획득 시
Boss Shield 생성
```

초기 단순안:

```text
일반 적 Gold 발생
→ Shield +1

Special Gold
→ Shield +2
```

Shield 상한:

```text
Boss Max HP의 20%
```

경제 빌드를 완전히 무력화하지 않는다.

---

# 46. Special Jamo Rate

```text
W1~4   0~3%
W6~9   5%
W11~14 8%
W16~19 10%
```

위험 단어/보스 패턴으로 증가 가능.

---

# 47. 희귀 보상 확률

기본:

```text
Normal  75%
Rare    22%
Special  3%
```

`운` 등으로 Weight를 조절한다.

---

# 48. 자모 제거 보상 빈도

권장:

```text
평균 4~6 Wave마다 1회
```

주요 공급:

- 중간보스
- 희귀 보상
- 특정 유물
- 특정 단어 효과

---

# 49. 덱 교체 가치

교체:

```text
현재 Run Deck 자모 1개 제거
+
이번 Wave 자모 1개 추가
```

보상 가치는:

```text
Add < Replace < Remove+Choose
```

순서로 본다.

---

# 50. RNG 실패율 목표

Forge에서 제작 가능한 단어 0개:

```text
첫 Draw 기준
25~40%

Reroll 모두 사용 후
5~10% 이하
```

0%로 만들 필요는 없다.

---

# 51. 단어 선택 수 목표

Forge 완료 시:

```text
평균 유효 선택지
1.5~3.0개
```

항상 1개면 선택이 없고,
항상 5개 이상이면 덱 설계 의미가 약해진다.

---

# 52. 빌드 다양성 목표

Wave 1~20에서 최소 4개 방향이 명확해야 한다.

예:

```text
무기/치명
화염 DoT
경제/행운
방어/안정
```

위험 단어는 이 빌드를 변형하는 역할.

---

# 53. 초반 영구 성장 체감

권장:

```text
첫 3 RUN
매 RUN 최소 1개 연구 구매 가능
```

이후에는 매번 연구를 사지 못하는 구간이 생겨도 된다.

---

# 54. Wave 1 반복 피로 문제

패배 시 Wave 1부터 시작하므로 장기적으로 반복 피로가 생길 가능성이 높다.

해결 원칙:

1. Wave 1~5는 짧게
2. 영구 성장 후 이전 Wave는 빠르게 정리 가능
3. 최고 Wave가 높아지면 초기 Spawn 가속 검토
4. 2x Game Speed 해금 검토

체크포인트로 Wave를 건너뛰는 기능은 현재 기획에서 사용하지 않는다.

---

# 55. 초기 Wave 가속 후보

MVP 이후 검토:

```text
최고 Wave 20
→ 이미 정화한 일반 Wave에서 1.25x 허용

최고 Wave 40
→ 1.5x 허용
```

시작 Wave는 그대로 1.

---

# 56. 2D 화면 기준

기준 제작 해상도:

```text
1920 × 1080
```

UI는 Anchor/Container를 사용해 다른 해상도에 대응하고,
게임플레이 영역은 화면 비율 변화로 지나치게 넓어지지 않도록 안전 영역을 둔다.

권장 전투 안전 영역:

```text
X: 화면 폭의 약 8% ~ 92%
Y: 화면 높이의 약 10% ~ 82%
```

하단은 마지막 문장과 빌드 UI를 위해 여유를 둔다.

3개의 Spawn Zone은 화면 상단에 분리한다.

```text
LEFT   : X 15~30%
CENTER : X 45~55%
RIGHT  : X 70~85%
```

실제 좌표는 배경 일러스트에 맞춰 Resource/Marker2D에서 조절한다.

---

# 57. 지형 밸런스

MVP 지형:

```text
3개 Spawn Zone
3개 주요 문장 행
1개 마지막 문장
```

목표:

- 화면 어느 위치든 빠르게 커서 이동 가능
- 자모가 UI에 가려지는 비율 0%
- 적 겹침 때문에 개별 클릭 불가능한 상황 최소화

---

# 58. 적 겹침 제한

Local Avoidance 적용.

권장 최소 간격:

```text
Visual Width의 0.6~0.8배
```

작은 자모의 `Area2D/CollisionShape2D` 클릭 판정은 Sprite보다 크게 설정.

---

# 59. 클릭 판정

권장:

```text
Area2D / CollisionShape2D
Sprite2D 표시 영역 대비 110~130%
```

특히:

```text
ㅣ
ㅅ
ㅈ
```

등 얇은 자모는 더 크게.

---

# 60. 플레이테스트 로그

반드시 저장:

```text
Run Duration
Highest Wave
Failure Wave

Clicks per Wave
Missed Clicks
Jamo Restored per Wave

Last Sentence Damage Taken
Stability at Clear

Gold per Wave
Gold per Run

Jamo Drop Count
Jamo Chosen
Jamo Added
Jamo Replaced
Jamo Removed

Deck Size per Wave

Forge First Hand Success
Reroll Count
Forge Failure Count

Words Crafted
Unique Words
Run Rank Distribution

Synergy Activation
Compound Count
Risk Word Pick Rate

Boss Clear Time
Boss Fail Reason

Codex New Words
Restoration EXP
```

---

# 61. 밸런스 경고 기준

## 클릭 과다

일반 적 하나에 평균 10회 이상 클릭이 필요하면 피로 가능성이 높다.

## 클릭 무의미

자동 효과가 대부분의 Wave를 처리하면 실패.

## 드랍 과다

덱이 계속 비대해지면 실패.

## 드랍 부족

2 Wave 연속 아무 자모 선택도 못 하는 상황이 자주 발생하면 실패.

## Reroll 무의미

첫 Draw만으로 거의 항상 원하는 단어를 만들면 실패.

## Reroll 강제

모든 Forge에서 Reroll을 전부 써야 하면 실패.

## 영구 성장 과다

Gold 연구만으로 Boss 패턴을 무시하면 실패.

## 복원도 과다

복원도 V 단어가 새로운 단어보다 항상 우선이면 실패.

## 합성어 과다

합성하지 않으면 Wave 20 진행이 사실상 불가능하면 실패.

---

# 62. 첫 밸런스 테스트 순서

## Test A — 전투만

단어 없이 Wave 1~5.

확인:

- 클릭 피로
- 적 속도
- 마지막 문장 피해
- 화면 가독성

## Test B — 자모 드랍

확인:

- 25%가 적절한가
- Wave당 보관 자모 수
- 선택 재미

## Test C — Forge

```text
6 Slot
Reroll 2
Lock 2
Starter Deck 19
```

제작 실패율 측정.

## Test D — 단어 10개

- 공격
- 화염
- 경제
- 방어

빌드 차이가 실제로 느껴지는지 확인.

## Test E — Wave 10 Boss

`침묵`.

숫자 덩어리가 아니라 빌드 변화가 필요한지 확인.

---

# 63. Vertical Slice 성공 기준

Wave 1~20 테스트:

```text
첫 RUN 평균 도달
Wave 4~8

3~5 RUN 이후
Wave 8~14

적당한 영구 성장 이후
Wave 15~20 도전 가능
```

Wave 20 첫 클리어가 너무 빨리 나오면 콘텐츠 소비 속도가 빠른 것이다.

---

# 64. 현재 핵심 숫자 요약

```text
Click Damage: 1
Click Cooldown: 0.20s

Last Sentence Stability: 100

Jamo Drop: 25%
Drop Pity: 4연속 실패 후 확정
Wave Drop Cap: 6

Normal Wave Jamo Pick: 1

Starter Deck: 19

Forge Slot: 6
Reroll: 2
Lock: 2

Word Slot:
장비 3
유물 3
특수효과 2
위험 1

Run Rank Max: 3

Word Restoration:
I~V

Mini Boss:
Wave 5, 15, 25...

Word Boss:
Wave 10, 20, 30...
```

이 값들은 모두 첫 프로토타입 테스트 기준이다.

---

**문서 버전:** v0.2  
**프로젝트:** JAMO  
**문서 역할:** 수치 / 확률 / 성장 곡선 / 테스트 기준
