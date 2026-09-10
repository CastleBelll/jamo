# JAMO — 총 프로젝트 개발 계획서 v0.4

> 프로젝트명: **JAMO**  
> 장르: **한글 단어 조합 × 슬롯/덱빌딩 × 로그라이트 × 클릭커/아이들러 성장**  
> 엔진: **Godot 4.x**  
> 개발 규모: **1인 개발 기준**  
> 출시 목표: **Steam PC**  
> 이전 기준: `JAMO_total_project_development_plan_v0.3.md`  
> 본 문서 상태: **v0.4 전면 리디자인 기준서**

---

# 0. 이번 v0.4의 핵심 변경

v0.3의 JAMO는 다음 구조였다.

```text
자모 몬스터 클릭
→ 골드 획득
→ 에너지 소모
→ Day 종료
→ 자모 1개 선택
→ 단어 완성
→ 단어 능력 영구 적용
→ 다음 Day
```

이 구조는 한글 단어가 실제 능력이 된다는 차별점은 좋았지만,
플레이어가 한 번 해금한 단어와 능력이 계속 누적되기 때문에
시간이 지날수록 다음 문제가 발생할 가능성이 높았다.

- 한 판 안에서 빌드를 새롭게 만들 이유가 부족함
- 단어를 한 번 완성한 뒤에는 해당 단어에 대한 고민이 사라짐
- 후반에는 너무 많은 영구 효과가 동시에 발동함
- 선택보다 누적 수치가 중요해짐
- 실패와 재도전의 긴장감이 약함
- 콘텐츠 소비 속도가 매우 빠름

v0.4에서는 JAMO를 완전히 다음 구조로 전환한다.

```text
[영구 메타 성장]
골드 업그레이드
+ 단어 도감
+ 단어 숙련도
+ 최고 Wave 기록
+ 보스 해금

        ↓

[새로운 RUN 시작]
Wave 1부터 시작
→ 자모 몬스터 방어전
→ 자모 슬롯/단어 조합
→ 단어 아이템·유물·특수효과 획득
→ 자모 덱 정리
→ 시너지·합성어 빌드 구성
→ Wave 5 중간보스
→ Wave 10 단어 보스
→ 다음 구간
→ 실패할 때까지 반복

        ↓

[RUN 실패]
Wave 1부터 다시 시작

단,
골드 업그레이드 / 단어 도감 / 단어 숙련도 /
보스 해금 / 최고 기록은 영구 유지
```

JAMO v0.4의 핵심은 다음 한 문장으로 정의한다.

> **매 런 자모 덱을 조작해 단어를 만들고, 그 단어를 아이템·유물·규칙으로 조합해 Wave를 돌파하며, 실패해도 골드와 단어 도감은 영구적으로 성장하는 한글 로그라이트 클릭커.**

---

# 1. 게임의 핵심 정체성

JAMO의 경쟁력은 단순히 “한글이 나오는 게임”이 아니다.

한글의 구성 방식 자체가 게임 시스템이어야 한다.

```text
자모
→ 글자
→ 단어
→ 의미
→ 능력
→ 단어 간 의미 연결
→ 빌드
```

플레이어가 `불`이라는 단어를 만들면
아이콘에 FIRE 속성이 붙는 것이 아니라
**“불이라는 단어를 만든 행위 자체”가 화상 능력을 획득하는 과정**이 된다.

따라서 JAMO의 핵심 규칙은 다음과 같다.

1. 자모는 전투 대상이자 덱의 구성 요소다.
2. 단어는 단순 수집품이 아니라 현재 런의 빌드다.
3. 같은 단어라도 현재 런의 다른 단어에 따라 가치가 달라진다.
4. 런은 실패하면 초기화된다.
5. 플레이한 시간은 골드와 도감 성장으로 절대 완전히 사라지지 않는다.
6. 단어의 의미와 효과가 최대한 직관적으로 연결되어야 한다.

---

# 2. 채택하는 핵심 시스템 7개

이번 v0.4에서는 다음 시스템을 JAMO의 정식 핵심 시스템으로 채택한다.

## 2.1 자모 슬롯 보드

전투 사이에 자모 슬롯 보드가 열린다.

기본:

```text
[ㄱ] [ㅓ] [ㅁ] [ㅂ] [ㅜ] [ㄹ]
```

플레이어는 현재 자모 덱에서 자모를 뽑아 슬롯을 채운다.

가능한 행동:

- 자모 잠금
- 잠기지 않은 슬롯 재추첨
- 유효한 단어 선택
- 단어 제작
- 필요 없는 결과 포기
- 덱 조작 보상 선택

기본값 권장:

```text
슬롯 수: 4
기본 재추첨: 0회 (해금)
기본 잠금: 0칸 (해금)
한 번의 제작 단계에서 기본 단어 제작: 1개
```

단순 슬롯머신처럼 결과를 바라보기만 하는 것이 아니라,
플레이어가 **잠글 자모와 버릴 자모를 직접 판단**한다.

---

## 2.2 단어가 곧 아이템

JAMO에서는 일반 로그라이트의 검, 갑옷, 유물 카드를
별도의 이름으로 지급하지 않는다.

**플레이어가 만든 단어 자체가 아이템이다.**

예:

```text
검
분류: 장비 / 공격
효과: 클릭 피해 증가
```

```text
벽
분류: 장비 / 방어
효과: 문장핵이 받는 피해 감소
```

```text
불
분류: 특수효과 / 상태이상
효과: 클릭 시 일정 확률로 화상
```

```text
운
분류: 유물
효과: 희귀 보상 등장 확률 증가
```

```text
돈
분류: 유물 / 경제
효과: RUN 중 획득 골드 증가
```

단어는 개발자가 사전에 정의한 `WordData` Resource를 사용한다.

---

## 2.3 합성어 시스템

현재 런에서 특정 단어 조합을 갖고 있으면
상위 단어 또는 합성어를 만들 수 있다.

예시는 반드시 실제 게임 데이터에서 별도로 검수한다.

구조 예:

```text
불 + 꽃
→ 불꽃

돌 + 벽
→ 돌벽

눈 + 사람
→ 눈사람
```

합성 방식은 두 종류로 나눈다.

### A. 합체형

두 단어를 소비하고 하나의 강력한 단어로 합친다.

```text
A + B
→ C

기존 A/B 슬롯이 비고
C 하나가 더 강한 효과를 가짐
```

장점:

- 슬롯 압축
- 후반 빌드 정리
- 조합 완성의 보상감

### B. 공존형

A와 B를 모두 가지고 있으면
별도의 시너지 효과가 활성화된다.

```text
A 보유
+ B 보유
= 세트 효과 발동
```

합성어는 무조건 많이 만드는 것이 아니라
**플레이어가 기억할 수 있을 정도로 의미 있는 조합**만 선별한다.

---

## 2.4 자모 덱 압축

런마다 플레이어는 별도의 `Run Jamo Deck`을 가진다.

초기 자모 덱은 모든 자모를 동일 비율로 넣지 않는다.

프로토타입에서는
초기 제작 가능한 단어들이 실제로 나올 수 있도록
의도된 스타터 덱을 사용한다.

자모 덱은 일반 카드 덱처럼 동작한다.

```text
Draw Bag
→ 슬롯에 Draw
→ 사용/버림
→ Discard Bag
→ Draw Bag이 비면 Shuffle
```

런 도중 다음 보상을 얻을 수 있다.

- 자모 1개 추가
- 자모 1개 제거
- 자모 A를 B로 교체
- 동일 자모 복제
- 불필요한 자모 삭제
- 특정 자음/모음 비율 조정

중요:

> 황금 ㄱ, 불타는 ㄱ 같은 자모 자체의 등급/속성 변형은 기본 시스템으로 사용하지 않는다.

JAMO의 재미는 특수 자모 수집이 아니라
**순수한 자모의 확률을 조절해 원하는 단어가 나오는 덱을 만드는 것**에 둔다.

---

## 2.5 단어 계열 시너지

모든 단어는 하나 이상의 의미 태그를 가질 수 있다.

초기 태그 예:

```text
무기
방어
불
독
전기
얼음
경제
행운
제어
자동화
회복
위험
```

예:

```text
검
→ 무기

불
→ 불 / 상태이상

운
→ 행운

벽
→ 방어
```

동일 계열 단어를 일정 수 이상 보유하면
런 한정 시너지가 활성화된다.

예:

```text
무기 2개
→ 클릭 피해 +10%

무기 4개
→ 치명타 확률 추가

불 2개
→ 화상 지속시간 증가

불 4개
→ 화상 중인 적 사망 시 주변 전이
```

단, 화면에 단순히 컬러 아이콘만 붙이는 방식보다
**단어 의미가 실제로 연결된다는 느낌**을 우선한다.

---

## 2.6 금지어 / 위험 단어

일부 단어는 매우 강력하지만
명확한 대가를 가진다.

이 계열을 `위험 단어`로 정의한다.

예:

```text
욕심
장점: RUN 골드 획득량 크게 증가
단점: 문장핵이 받는 피해 증가
```

```text
광기
장점: 클릭 피해 크게 증가
단점: 클릭 에너지 소비 증가
```

```text
폭주
장점: 자동 공격 속도 크게 증가
단점: 일정 시간마다 문장핵 HP 감소
```

```text
도박
장점: 희귀 보상 등장 확률 크게 증가
단점: 일반 보상 중 일부가 빈 보상으로 변경될 가능성
```

위험 단어는 단순한 저주 아이템이 아니다.

> **플레이어가 일부러 선택해 강력한 빌드를 만들 수 있는 고위험 고보상 단어군**으로 설계한다.

---

## 2.7 단어 도감 = 영구 성장

런에서 단어를 처음 만들면
해당 단어가 영구 도감에 등록된다.

도감 상태:

```text
미발견
발견
숙련 Lv1
숙련 Lv2
숙련 Lv3
숙련 Lv4
숙련 Lv5
```

도감은 단순 컬렉션이 아니다.

해당 단어를 여러 런에서 반복해서 사용하면
영구 숙련 경험치를 얻는다.

중요:

> 도감 숙련은 해당 단어를 처음부터 주는 시스템이 아니다.

런에서 그 단어를 실제로 다시 만들어야
숙련 효과가 적용된다.

예:

```text
불 숙련 Lv1
→ 기본 효과 그대로

불 숙련 Lv2
→ 화상 피해 +5%

불 숙련 Lv3
→ 화상 지속시간 +5%

불 숙련 Lv4
→ 화상 피해 추가 +5%

불 숙련 Lv5
→ 합성/시너지 힌트 완전 공개
```

따라서 영구 성장은 존재하지만
매 런 `불`을 다시 만드는 과정은 필요하다.

---

# 3. 영구 성장과 RUN 성장의 완전한 분리

## 3.1 영구 유지

런 실패 후에도 남는다.

```text
보유 Gold
Gold 영구 업그레이드
단어 도감 등록
단어 숙련도
발견한 합성어
발견한 시너지 정보
처치한 단어 보스
해금된 단어 풀
최고 도달 Wave
통계
업적
설정
```

---

## 3.2 RUN 종료 시 초기화

다음은 실패하면 전부 사라진다.

```text
현재 Wave
현재 RUN 자모 덱
현재 슬롯 상태
RUN 중 제작한 단어
장비 단어
유물 단어
특수효과 단어
위험 단어
현재 RUN 단어 Rank
현재 활성 시너지
합성어
RUN 전용 버프
문장핵 현재 HP
RUN 전용 리롤
RUN 전용 자모 추가/삭제
```

---

# 4. 전체 게임 루프

```text
MAIN HUB

영구 업그레이드 확인
도감 확인
기록 확인

        ↓

RUN START

Wave 1
        ↓
전투
        ↓
Wave Clear
        ↓
보상 선택
        ↓
자모 슬롯 / 단어 제작
        ↓
자모 덱 조정
        ↓
다음 Wave

...

Wave 5
→ 중간보스

Wave 10
→ 단어 보스

Wave 11
→ 다음 Tier

...

문장핵 HP 0
또는 Wave 실패

        ↓

RUN END

Gold 정산
도감 경험치 정산
신규 단어 등록
신규 보스 기록

        ↓

MAIN HUB

Gold 영구 업그레이드

        ↓

다시 Wave 1
```

---

# 5. Wave 시스템

기존 Day 시스템은 완전히 제거한다.

`current_day` 대신 `current_wave`를 사용한다.

## 5.1 기본 구조

```text
Wave 1~4
일반 Wave

Wave 5
중간보스

Wave 6~9
강화 일반 Wave

Wave 10
단어 보스

Wave 11~14
Tier 2 일반 Wave

Wave 15
중간보스

Wave 20
단어 보스
```

규칙:

```text
5, 15, 25, 35 ...
→ 중간보스

10, 20, 30, 40 ...
→ 단어 보스
```

---

## 5.2 Wave 증가 요소

Wave가 오를수록 다음이 상승한다.

```text
적 HP
적 이동속도
동시 등장 수
특수 자모 비율
보스 패턴 수
적 스폰 속도
일부 상태 저항
```

단순 HP 배율만 올리는 방식은 피한다.

---

# 6. 전투 구조

v0.3의 클릭 전투와 자모별 고유 보행은 유지한다.

다만 몬스터가 단순 배회만 하는 구조는
Wave 게임에 맞게 변경한다.

## 6.1 문장핵

전투 맵 중앙 또는 후방에
플레이어가 지켜야 하는 `문장핵`이 존재한다.

임시 명칭:

```text
문장핵
```

추후 세계관에 맞춰 이름 변경 가능.

적 자모는 각자의 보행 방식으로
문장핵 방향으로 이동한다.

플레이어는 적을 클릭해 제거한다.

```text
적 Spawn
→ 고유 보행으로 문장핵 접근
→ 플레이어 클릭
→ HP 감소
→ 상태이상
→ 처치
```

적이 문장핵에 도달하면 피해를 준다.

문장핵 HP가 0이 되면 현재 RUN 종료.

---

# 7. 에너지 시스템 재설계

에너지는 제거하지 않는다.

기존의 좋은 아이디어였던
**“수동 클릭은 제한된 자원이다”**를 Wave 구조에 맞게 재사용한다.

## 7.1 Wave Energy

기본:

```text
Max Energy = 10
Manual Click Cost = 1
```

Wave 시작:

```text
Energy = Max Energy
```

클릭:

```text
Energy -1
→ 클릭 피해
→ 단어 효과
```

Energy 0:

```text
수동 클릭 불가
```

하지만 Wave는 즉시 종료되지 않는다.

다음은 계속 작동한다.

- 화상
- 독
- 연쇄
- 자동 공격
- 유물 효과
- 특수효과
- 소환/보조 효과

따라서 좋은 빌드는
**같은 에너지로 더 많은 Wave 압박을 처리하는 빌드**가 된다.

Wave Clear 시 에너지는 다시 최대치로 회복한다.

---

# 8. 클릭 전투 계산

기본 구조:

```text
FinalClickDamage =
(BaseClickDamage + PermanentFlatBonus + RunFlatBonus)
× PermanentMultiplier
× WordMultiplier
× CriticalMultiplier
× TargetTakenDamageMultiplier
```

영구 업그레이드와
RUN 단어 효과를 계산 레이어에서 분리한다.

권장 순서:

```text
Base
→ Permanent Meta
→ Current RUN Word
→ Synergy
→ Risk Modifier
→ Target Modifier
→ Final
```

---

# 9. 자모 슬롯 보드 상세

## 9.1 슬롯 기본값

```text
Slot Count: 4
Reroll: 0
Lock Count: 0
```

플레이어가 슬롯에서 하나 이상의 유효 단어를 만들 수 있으면
가능 단어가 하이라이트된다.

예:

```text
[ㄱ][ㅓ][ㅁ][ㅂ][ㅜ][ㄹ]

가능:
검
불
```

플레이어는 둘 중 하나를 선택한다.

이 선택이 중요하다.

```text
현재 무기 빌드
→ 검 선택

현재 화상 빌드
→ 불 선택
```

---

## 9.2 완전 꽝 방지

무의미한 슬롯만 계속 나오는 상황은 금지한다.

Candidate Generator는 다음을 참고한다.

```text
현재 Run Jamo Deck
현재 장착 단어
현재 시너지
제작 가능한 WordData
아직 발견하지 못한 단어
보유 리롤 수
```

단, 원하는 단어를 확정으로 주지는 않는다.

목표:

> 운이 나쁠 수는 있어도 아무 판단도 할 수 없는 결과는 최소화한다.

---

# 10. 단어 슬롯 구조

모든 단어를 무제한으로 들고 다니지 않는다.

이전 JAMO의 가장 큰 문제였던
효과 무한 누적을 막기 위해 슬롯 제한을 둔다.

초기 권장:

```text
장비 단어: 4칸
유물 단어: 3칸
특수효과 단어: 2칸
위험 단어: 별도 최대 2칸
```

분류는 `WordData.slot_type`에서 관리한다.

슬롯이 가득 찼을 때 새 단어를 만들면:

```text
기존 단어 교체
또는
신규 단어 포기
```

를 선택한다.

---

# 11. 동일 단어 재제작

현재 런에서 이미 보유한 단어를 다시 만들 수 있다.

이 경우 새 슬롯을 차지하지 않고
`Run Rank`가 상승한다.

예:

```text
불 Rank 1
→ 불 Rank 2
→ 불 Rank 3
```

Run Rank는 현재 런 한정이다.

도감 숙련도와 반드시 분리한다.

```text
Codex Mastery
= 영구

Run Rank
= 현재 RUN 한정
```

---

# 12. 단어 도감 숙련도

## 12.1 숙련 경험치

같은 단어를 무한 반복해 농사하는 것을 막기 위해
런별 숙련 경험치에 감소 보정을 둔다.

예:

```text
해당 RUN 첫 제작: 100%
두 번째: 50%
세 번째 이후: 20%
```

또는 한 RUN당 단어별 숙련 EXP 상한을 둔다.

---

## 12.2 숙련도 효과 원칙

영구 숙련도는 강하지만
해당 단어를 만들 필요가 없어질 정도로 강하면 안 된다.

허용:

- 단어 기본 수치 소폭 증가
- 해당 단어 Run Rank 효율 증가
- 합성어 힌트 해금
- 시너지 정보 공개
- 해당 단어 관련 보스 정보 공개

금지:

- 런 시작부터 단어 자동 지급
- 단어 효과가 항상 활성
- 숙련도만으로 조합 과정 생략

---

# 13. Gold 영구 업그레이드

Gold 업그레이드는 **MAIN HUB에서만 구매**한다.

전투 도중 영구 업그레이드를 구매하지 않는다.

## 13.1 전투 기초

```text
기본 클릭 피해
최대 에너지
문장핵 최대 HP
기본 치명타 확률
기본 치명타 배율
```

## 13.2 경제

```text
Gold 획득량
중간보스 Gold 보너스
단어 보스 Gold 보너스
```

## 13.3 조합 편의

너무 강한 기능 해금보다
RNG 완화를 중심으로 한다.

```text
기본 Reroll 추가
기본 Lock 증가
도감 힌트 범위 증가
슬롯 결과 미리보기 개선
```

중요:

> Gold로 특정 단어를 직접 구매하지 않는다.

---

# 14. RUN Gold

몬스터와 보스를 처치해 얻은 Gold는
런 실패 여부와 관계없이 영구 Gold에 추가한다.

따라서 실패해도 최소한 다음이 남는다.

```text
Gold
도감 경험치
신규 단어 발견
보스 기록
```

이것이 JAMO의 아이들러/영구 성장 감각을 담당한다.

---

# 15. 자모 몬스터

v0.3의 자모별 고유 보행 성격은 유지한다.

예:

```text
ㄷ
→ HEAVY_STEP

ㅁ
→ BOUNCE

ㅇ
→ ROLL

ㅅ
→ LIGHT_STEP

ㄹ
→ SWAY

ㅡ
→ GLIDE
```

다만 목적지가 단순 랜덤 포인트가 아니라
문장핵 방향이 된다.

자모별 보행 차이는
Wave 전투의 클릭 난이도로 연결한다.

예:

```text
ㅅ
빠르고 작은 적

ㄷ
느리고 HP가 높은 적

ㅇ
굴러가듯 빠르게 접근

ㅁ
점프 때문에 클릭 타이밍이 달라짐
```

---

# 16. 특수 자모

기존 특수종 개념도 유지 가능하다.

예:

```text
큰 ㅁ
→ HP 높음

빠른 ㅇ
→ 이동속도 높음

분열 ㅂ
→ 처치 시 분열

점멸 ㅅ
→ 일정 시간 클릭 판정 변화
```

단,
특수 자모가 별도 아트 에셋을 대량 요구하지 않도록 한다.

차이는 다음으로 만든다.

```text
Scale
Material
Motion Profile
Particle
Trail
Behavior
```

---

# 17. 중간보스

Wave 5 단위 중
10의 배수가 아닌 Wave에 등장한다.

```text
5
15
25
35
...
```

중간보스는 주로
**거대한 자모 또는 특수 자모**로 만든다.

예:

```text
거대한 ㅁ
→ 높은 HP
→ 착지 충격
→ 일정 간격으로 작은 ㅁ 생성
```

```text
질주 ㅇ
→ 맵을 크게 회전하며 문장핵으로 돌진
```

중간보스 처치 보상은 일반 Wave보다 강하다.

권장 보상:

```text
희귀 단어 제작 기회
자모 제거
자모 교체
추가 Reroll
유물 단어 후보
```

---

# 18. 단어 보스

JAMO의 대표 콘텐츠.

Wave:

```text
10
20
30
40
...
```

단어 보스는 자모 한 글자가 아니라
**완성된 단어 자체가 거대한 적으로 등장**한다.

보스의 능력은 단어 의미와 직접 연결한다.

이 시스템은 JAMO의 시각적/게임플레이적 대표 특징으로 사용한다.

---

# 19. 단어 보스 예시

아래는 설계 방향 예시다.
최종 이름과 밸런스는 프로토타입 후 확정한다.

## Wave 10 — 침묵

특징:

```text
일정 시간마다 현재 장착 단어 하나를 임시 비활성화
```

대응:

- 한 단어 의존 빌드에 강함
- 여러 효과를 분산한 빌드는 상대적으로 안정적

---

## Wave 20 — 탐욕

특징:

```text
현재 Wave에서 Gold를 얻을 때마다
보스에게 소량의 보호막 생성
```

대응:

- 경제 빌드가 무조건 정답이 되지 않게 함
- 순간 폭딜 또는 보호막 제거 효과가 중요

주의:

영구 보유 Gold를 빼앗지는 않는다.

---

## Wave 30 — 망각

특징:

```text
일정 주기로 RUN 단어 하나의 효과를 짧게 봉인
```

보스 처치 후 원상 복귀한다.

영구 도감이나 숙련도를 삭제하지 않는다.

---

## Wave 40 — 분열

특징:

```text
HP 구간마다 여러 글자 조각으로 분열
각 조각을 따로 처리해야 본체 재등장
```

---

## Wave 50 — 거울

특징:

```text
같은 피해 유형을 연속으로 받을수록 해당 유형 저항 증가
```

대응:

- 단일 빌드 극단화에 제동
- 복합 시너지 빌드 가치 증가

---

## Wave 60 — 폭주

특징:

```text
시간이 지날수록 이동속도와 공격 주기가 상승
```

DPS 체크형 보스.

---

## Wave 70 — 고집

특징:

```text
동일 단어 효과의 반복 발동 효율 감소
```

서로 다른 단어를 섞은 빌드가 유리.

---

## Wave 80 — 혼돈

특징:

```text
일정 주기로 장착 단어 슬롯 위치를 섞고
일부 시너지 조건을 잠시 교란
```

---

## Wave 90 — 공허

특징:

```text
낮은 Run Rank 단어의 효과를 크게 감소
```

핵심 단어를 여러 번 강화한 빌드를 요구.

---

## Wave 100 — 종말

특징:

```text
이전 단어 보스 능력 일부를 단계별로 사용
```

첫 장기 목표 보스.

---

# 20. 단어 보스와 도감 연결

단어 보스를 처음 처치하면
해당 보스 단어가 도감에 등록된다.

일부 보스 단어는 이후 RUN에서
위험 단어 또는 고급 단어로 제작 가능해진다.

예:

```text
탐욕 보스 첫 처치
→ 도감 '탐욕' 등록
→ 이후 RUN에서 위험 단어 '탐욕' 제작 가능
```

이렇게 하면 보스가 단순 장애물이 아니라
**새로운 빌드 요소를 해금하는 콘텐츠**가 된다.

---

# 21. 단어 데이터 구조

`WordData.tres`

권장 필드:

```text
id
word
display_name

slot_type
tags

required_jamo
run_max_rank

base_effect_ids
rank_effect_values

compound_recipe_ids
synergy_ids

is_risk_word
risk_effect_ids

codex_mastery_curve
codex_hidden_before_discovery

unlock_condition
required_boss_id

icon
vfx_id
sfx_id
```

---

# 22. 합성어 데이터

`CompoundRecipeData.tres`

```text
id
result_word_id

required_word_ids
consume_ingredients

required_run_rank
required_synergy

result_rank
discovery_hidden
```

합성 가능 여부는 런타임에
현재 단어 목록으로 계산한다.

---

# 23. 시너지 데이터

`WordSynergyData.tres`

```text
id
display_name

required_tags
required_counts
required_word_ids

effect_ids

tier
hidden_before_discovery
```

시너지 UI는
현재 몇 개를 보유 중인지 명확히 보여준다.

예:

```text
무기 2 / 4
```

---

# 24. 위험 단어 데이터

별도 클래스를 만들기보다
WordData에 위험 정보를 포함한다.

```text
is_risk_word = true

positive_effect_ids
negative_effect_ids
```

장점과 단점은 UI에서 동시에 보여준다.

플레이어가 단점을 모른 채 선택하는 구조는 금지한다.

---

# 25. Wave 데이터

`WaveData.tres`

```text
wave_number

enemy_pool
enemy_count
spawn_interval
max_alive

hp_multiplier
speed_multiplier
gold_multiplier

special_spawn_rate

wave_type
boss_id

reward_tier
```

`wave_type`:

```text
NORMAL
ELITE
MINI_BOSS
WORD_BOSS
```

---

# 26. 단어 보스 데이터

`WordBossData.tres`

```text
id
word
wave_tier

base_hp
move_profile
phase_count

ability_ids
phase_thresholds

resistances
weakness_rules

reward_table
codex_unlock_word_id

scene
vfx_profile
audio_profile
```

---

# 27. MAIN HUB

메인 화면은 단순 Start 버튼만 있는 화면이 아니다.

JAMO의 영구 성장 공간이다.

권장 메뉴:

```text
[RUN 시작]

[영구 업그레이드]

[단어 도감]

[기록]

[설정]
```

메인 화면에서 현재 성장 상태를 한눈에 보여준다.

```text
Gold
최고 Wave
발견 단어 수 / 전체
처치 단어 보스 수
```

---

# 28. 영구 업그레이드 화면

기존 Day 결산 화면의 업그레이드 구조는
MAIN HUB로 이동한다.

카테고리:

```text
[전투]
클릭 피해
치명타
문장핵

[에너지]
최대 에너지
에너지 효율

[경제]
Gold 획득

[조합]
기본 Reroll
Lock
힌트
```

게임 도중 구매 불가.

---

# 29. 단어 도감 UI

단어 도감은 JAMO의 두 번째 핵심 화면이다.

표시 정보:

```text
단어
분류
태그
첫 발견 날짜/기록
제작 횟수
최고 Run Rank
숙련 Lv
현재 숙련 EXP
효과
발견한 합성 관계
발견한 시너지
관련 단어 보스
```

미발견 단어:

```text
???
```

단,
힌트 업그레이드 또는 관련 단어 발견 시
일부 자모/카테고리를 보여줄 수 있다.

---

# 30. 인게임 HUD

권장:

좌상단:

```text
WAVE 17
```

상단 중앙:

```text
문장핵 HP
```

하단 또는 좌하단:

```text
ENERGY 14 / 25
```

우상단:

```text
GOLD
```

우측 또는 하단 접이식 영역:

```text
현재 단어
현재 시너지
위험 단어
```

화면을 카드 UI로 덮지 않는다.

---

# 31. Wave Clear 화면

Wave Clear마다 긴 메뉴를 강제로 띄우지 않는다.

연출:

```text
Wave Clear
→ 짧은 정산
→ 보상 선택
→ Word Forge
→ 다음 Wave
```

빠르게 진행하고 싶은 사용자는
짧은 애니메이션으로 넘길 수 있어야 한다.

---

# 32. Word Forge UI

가장 중요한 UI 중 하나.

중앙:

```text
[ㄱ][ㅓ][ㅁ][ㅂ][ㅜ][ㄹ]
```

하단:

```text
REROLL 2
LOCK 0 / 2
```

옆:

```text
만들 수 있는 단어

검
불
```

단어 Hover:

```text
분류
현재 효과
현재 시너지 예상
새로운 도감 단어 여부
합성 가능 여부
```

정보가 너무 많으면
기본/상세 Tooltip을 분리한다.

---

# 33. 단어 선택의 핵심 판단

플레이어는 매번 다음을 고민해야 한다.

```text
현재 빌드를 강화할까?

새로운 계열로 갈까?

합성어 재료를 모을까?

덱에서 필요 없는 자모를 제거할까?

지금 강한 단어를 만들까?

도감 미발견 단어를 노릴까?

위험 단어를 받아서 고점을 노릴까?
```

이 선택이 JAMO v0.4의 실제 재미다.

---

# 34. RUN 보상

일반 Wave:

```text
Gold
+ 기본 보상 선택
```

보상 후보:

```text
자모 추가
자모 제거
자모 교체
Reroll
Word Forge
기존 단어 Run Rank 강화
```

중간보스:

```text
희귀 Word Forge
강력한 덱 압축
유물 후보
```

단어 보스:

```text
고급 단어 후보
보스 단어 해금
도감 대량 숙련 EXP
Gold 보너스
```

---

# 35. 실패

RUN 실패 조건:

```text
문장핵 HP <= 0
```

실패 시:

```text
현재 RunState 삭제
→ 결과 화면
→ Main Hub
```

결과 화면:

```text
도달 Wave
처치 수
획득 Gold
새로 발견한 단어
숙련 상승 단어
발견한 합성어
처치한 보스
이번 RUN 핵심 빌드
```

그리고 다음 RUN은 반드시:

```text
Wave 1
```

부터 시작한다.

MVP에서는 중간 Wave부터 시작하는 체크포인트를 넣지 않는다.

---

# 36. 아이들러 요소

JAMO v0.4는 완전 방치형 게임으로 만들지 않는다.

아이들러 요소는 다음 수준으로 제한한다.

```text
자동 공격
DoT
연쇄 효과
소환/보조 효과
Gold 영구 성장
도감 숙련 성장
```

좋은 빌드를 만들면
후반 일부 적을 자동으로 처리할 수 있지만,
보스와 주요 선택에서는 사용자의 판단이 필요해야 한다.

MVP에서는 오프라인 진행을 넣지 않는다.

---

# 37. 자동화

자동화 단어를 현재 RUN에서 만들면
자동 공격 시스템을 활성화할 수 있다.

자동 공격도 기본적으로 에너지 규칙을 따른다.

단,
특정 RUN 단어/유물로
자동 공격의 에너지 비용을 줄이는 빌드는 허용할 수 있다.

자동화가 플레이어의 클릭을 완전히 무의미하게 만들지 않도록 한다.

---

# 38. 상태이상

기존 구조를 유지한다.

```text
Burn
Poison
Bleed
Slow
Freeze
Shock
```

각 상태이상은 `StatusEffect Resource`로 관리한다.

몬스터 코드 하나에 모든 효과를 하드코딩하지 않는다.

런 단어가 상태이상을 활성화하는 구조로 변경한다.

즉:

```text
도감에 불이 등록되어 있음
≠ 항상 Burn 활성

현재 RUN에서 불을 제작함
= Burn 활성
```

---

# 39. 맵

MVP는 1개 맵으로 시작한다.

2.5D 고정 3/4 뷰 유지.

구성:

```text
중앙/후방 문장핵
외곽 Spawn Point
자모 이동 경로
Arena
간단한 환경 장식
```

Wave Tier가 오르면
같은 맵에서 다음으로 진행감을 준다.

```text
조명
배경 패턴
종이/먹 표현
환경 VFX
```

---

# 40. 카메라

기존 원칙 유지.

```text
Camera3D
Orthographic 우선

고정 시점
자유 회전 없음
```

추가 연출:

```text
Critical Shake
문장핵 피격 Shake
중간보스 등장
단어 보스 등장 Zoom
Word Complete Zoom
Boss Death
```

---

# 41. VFX

외부 아트 리소스를 많이 사용하지 않으므로
VFX와 타이포그래피 연출이 품질을 좌우한다.

단어 제작:

```text
자모들이 중앙 정렬
→ 획이 맞물림
→ 완성 단어 등장
→ 해당 의미의 VFX
→ 아이템 카드/슬롯으로 이동
```

단어 보스 사망:

```text
완성된 단어
→ 균열
→ 자모 단위로 분리
→ 흩어짐
→ 도감 등록
```

---

# 42. 오디오

기존 자모별 보행 SFX를 유지한다.

추가:

```text
Wave Start
Wave Clear
Mini Boss Alert
Word Boss Intro
Word Complete
Compound Complete
Synergy Activate
Risk Word Select
Run Failed
Codex New Discovery
```

단어 완성과
단어 보스 처치는 별도 강한 Sting을 사용한다.

---

# 43. Godot 프로젝트 구조

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
│  ├─ main_hub/
│  │  ├─ main_hub.tscn
│  │  └─ main_hub.gd
│  │
│  ├─ run/
│  │  ├─ run_game.tscn
│  │  ├─ arena.tscn
│  │  ├─ wave_controller.tscn
│  │  └─ camera_rig.tscn
│  │
│  ├─ monsters/
│  │  ├─ jamo_monster_base.tscn
│  │  ├─ consonant/
│  │  ├─ vowel/
│  │  ├─ special/
│  │  └─ bosses/
│  │
│  ├─ objective/
│  │  └─ sentence_core.tscn
│  │
│  ├─ effects/
│  │
│  └─ ui/
│     ├─ hud.tscn
│     ├─ wave_clear.tscn
│     ├─ run_result.tscn
│     ├─ word_forge.tscn
│     ├─ run_word_inventory.tscn
│     ├─ synergy_panel.tscn
│     ├─ codex.tscn
│     ├─ permanent_upgrade.tscn
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
│
├─ materials/
├─ shaders/
├─ audio/
├─ fonts/
└─ art/
```

---

# 44. State 구조

## MetaState

영구 저장.

```text
save_version

gold

permanent_upgrade_levels

codex_words
codex_mastery_exp
codex_mastery_levels

discovered_compounds
discovered_synergies

defeated_word_bosses

highest_wave
statistics
```

## RunState

현재 RUN 전용.

```text
current_wave

core_hp
current_energy

jamo_draw_bag
jamo_discard_bag

current_slot_jamo
rerolls
locks

equipped_words
run_word_ranks

active_synergies
active_compounds
risk_words

run_modifiers
run_statistics
```

실패 시 RunState 초기화.

게임 종료/강제 종료를 대비해
현재 RUN을 임시 저장하여 이어하기 기능은 만들 수 있다.

단,
패배 후에는 복구할 수 없다.

---

# 45. Save 원칙

저장 시점:

```text
Gold 획득 정산
영구 업그레이드 구매
도감 신규 등록
숙련도 상승
단어 보스 처치
RUN Wave Clear
게임 종료
```

Resource 자체를 저장하지 않는다.

항상:

```text
id
level
value
```

기반으로 저장한다.

---

# 46. Godot 개발 원칙

기존 v0.3의 원칙을 그대로 유지한다.

> **코드 전용 Godot 프로젝트로 만들지 않는다.**

다음은 반드시 Editor에서 확인 가능해야 한다.

```text
.tscn
.tres
AnimationPlayer
Control
Node3D
Inspector Export
Theme Resource
```

금지:

```text
메인 UI 전체를 GDScript에서 생성
단어 DB 하드코딩
Wave 데이터 하드코딩
보스 데이터 하드코딩
업그레이드 가격 하드코딩
자모 덱 내용을 gameplay script에 직접 하드코딩
```

---

# 47. AI 개발 지시 고정 문구

Claude / Codex / Ziva 등에게 구현을 요청할 때
다음을 항상 포함한다.

```text
Do not implement JAMO as a code-only Godot project.

Use Godot scenes (.tscn), Resources (.tres), AnimationPlayer,
Control nodes, Node3D hierarchy, Theme Resources,
Inspector-exposed properties, and reusable packed scenes wherever appropriate.

I must be able to open the project in the Godot Editor and visually inspect,
move, configure, animate, and tune the objects without rewriting code.

Do not create the main UI entirely from GDScript.

Do not hard-code wave data, word data, jamo deck data,
boss data, synergy data, compound recipes,
monster data, permanent upgrades, or balance tables
inside gameplay scripts when they can be represented as Resources.

Scripts should control logic and runtime state.

Scenes and Resources should represent structure,
visuals, editable configuration, and balance data.

Permanent MetaState and temporary RunState
must be implemented as separate systems.

A failed run must clear all temporary run words,
run jamo-deck changes, synergies, relics, and run ranks,
while preserving Gold upgrades, Codex progress,
Word Mastery, defeated bosses, and highest-wave records.
```

---

# 48. 개발 Phase

## Phase 0 — 기존 프로젝트 정리

- Day 시스템 제거
- Main Hub 분리
- MetaState / RunState 분리
- current_day → current_wave
- 기존 영구 단어 효과 제거
- 기존 단어 데이터 마이그레이션

완료 기준:

> Wave 1을 시작하고 실패 후 Main Hub로 돌아올 수 있다.

---

## Phase 1 — Wave 전투

- 문장핵
- 자모 Spawn
- 접근 AI
- 클릭 전투
- Energy
- Wave Clear
- Wave Fail
- Gold 획득

완료 기준:

> Wave 1~5를 플레이할 수 있다.

---

## Phase 2 — 자모 슬롯

- Run Jamo Deck
- Draw Bag / Discard Bag
- 6 Slot
- Lock
- Reroll
- Word Candidate
- Word Craft

최초 단어:

```text
검
불
돈
운
벽
힘
```

---

## Phase 3 — RUN 단어 슬롯

- 장비
- 유물
- 특수효과
- 위험 단어
- 교체
- 동일 단어 Run Rank

---

## Phase 4 — 단어 도감

- 첫 발견
- 숙련 EXP
- 숙련 Lv
- 도감 UI
- 합성/시너지 힌트

---

## Phase 5 — Gold 영구 성장

우선 5종:

```text
Click Damage
Max Energy
Core HP
Gold Bonus
Base Reroll
```

---

## Phase 6 — 단어 시너지

최초 3계열:

```text
무기
불
행운/경제
```

---

## Phase 7 — 합성어

최초 5~8개 레시피.

합체형과 공존형 모두 테스트한다.

---

## Phase 8 — 위험 단어

최초:

```text
욕심
광기
폭주
```

---

## Phase 9 — 중간보스

Wave 5
Wave 15

최소 2종.

---

## Phase 10 — 단어 보스

Vertical Slice:

```text
Wave 10 침묵
Wave 20 탐욕
```

---

## Phase 11 — Juice

- Word Complete
- Boss Intro
- Boss Death
- Damage Number
- Core Hit
- Camera Shake
- VFX
- SFX
- UI Animation

---

## Phase 12 — Content / Balance

- 단어 DB 확대
- 합성어
- 시너지
- 보스
- Wave 곡선
- 골드 경제
- 숙련 곡선

---

# 49. Vertical Slice

첫 외부 테스트 목표는 Wave 1~20이다.

포함:

```text
맵 1개

기본 자모 12종 이상
특수 자모 3종

Wave 1~20

중간보스
Wave 5
Wave 15

단어 보스
Wave 10 침묵
Wave 20 탐욕

단어 20~30개

장비 단어
유물 단어
특수효과 단어

위험 단어 3개

합성어 5개 이상
시너지 3계열 이상

자모 슬롯
자모 덱 압축

Gold 영구 업그레이드 5종

단어 도감
단어 숙련 Lv

Run Result

Save / Load
```

이 단계에서 재미가 없으면
단어 수를 100개로 늘리지 않는다.

---

# 50. 우선 제작할 단어군

최초 데이터는
효과가 직관적인 단어부터 만든다.

예:

```text
[공격]
검
칼
힘
강타

[상태]
불
독
전기
얼음

[방어]
벽

[경제]
돈
금

[행운]
운
복

[자동화]
손
자동

[위험]
욕심
광기
폭주
```

실제 required_jamo와 합성 규칙은
별도 Word DB에서 검수한다.

---

# 51. 플레이테스트 지표

기존 Day 관련 지표는 Wave 기준으로 변경한다.

```text
Highest Wave

Wave Duration
Wave Clear Time

Clicks per Wave
Energy Used per Wave

Kills per Wave

Core Damage Taken
Core HP at Clear

Gold per Wave

Words Crafted per Run
Unique Words per Run
Repeated Word Rank Ups

Reroll Usage
Lock Usage

Jamo Added
Jamo Removed

Synergy Activation Count
Compound Count
Risk Word Pick Rate

Mini Boss Win Rate
Word Boss Win Rate

Failure Wave Distribution

Damage Source Breakdown

Codex New Discoveries per Run
Mastery EXP per Run
```

---

# 52. 밸런스 경고 조건

## 자모 RNG

원하는 빌드가 나오지 않는 문제가 아니라
**어떤 빌드도 만들 수 없는 상황**이 반복되면 실패.

## 한 단어 독점

특정 단어 하나가 모든 런에서
무조건 최우선이면 실패.

## 영구 성장 과잉

Gold 업그레이드만으로
초반 Wave가 의미 없이 자동 통과되면 실패.

## 도감 숙련 과잉

Mastery Lv이 높다는 이유만으로
해당 단어가 항상 정답이 되면 실패.

## 합성어 과잉

합성어를 만들지 않으면
후반 진행이 불가능할 정도면 실패.

## 위험 단어

단점이 체감되지 않거나
반대로 아무도 선택하지 않으면 실패.

## 보스

특정 단어 하나가 없으면
사실상 클리어 불가능한 하드 카운터는 피한다.

보스는 빌드 방향에 압박을 줄 뿐
정답 하나를 요구하지 않는다.

---

# 53. 난이도 철학

초반:

> 빠르게 단어를 만들고 빌드 방향을 잡는다.

중반:

> 자모 덱을 압축하고 단어 간 시너지를 완성한다.

후반:

> 강력한 단어 보스의 규칙을 현재 빌드로 해결한다.

실패 후:

> 이전보다 약간 강한 영구 성장 상태에서 다시 Wave 1에 도전한다.

---

# 54. JAMO v0.4가 지향해야 하는 감정

Wave 1:

> 이번에는 어떤 단어가 나올까?

Wave 3:

> 무기 빌드로 갈까, 불 빌드로 갈까?

Wave 5:

> 지금까지 만든 빌드가 중간보스에게 통한다.

Wave 7:

> 이 자모를 빼면 원하는 단어가 훨씬 잘 나오겠다.

Wave 10:

> 침묵 때문에 핵심 단어 하나가 막혔다. 다른 효과로 버텨야 한다.

Wave 14:

> 단어 두 개가 합성되면서 빌드가 완성되기 시작한다.

Wave 20:

> 이번 RUN의 결과물이 진짜 빌드처럼 느껴진다.

실패:

> 다 잃은 것 같지만 Gold와 도감 숙련은 남았다.

Main Hub:

> 한 번만 업그레이드하고 다시 해보자.

이 감정의 반복이 핵심이다.

---

# 55. 최종 개발 방향

JAMO v0.4는 더 이상

```text
단어를 하나씩 영구 해금하는 클릭커
```

가 아니다.

최종 방향은:

```text
자모를 상대한다
↓
자모 덱을 만든다
↓
슬롯에서 자모를 조합한다
↓
단어를 만든다
↓
단어가 아이템이 된다
↓
단어끼리 시너지가 생긴다
↓
합성어가 만들어진다
↓
위험 단어로 고점을 노린다
↓
단어 보스를 상대한다
↓
실패한다
↓
Gold와 도감은 성장한다
↓
다시 Wave 1
```

이다.

JAMO의 가장 강한 차별점은

> **“한글 단어가 스킬 이름인 게임”이 아니라  
> “한글을 조립하는 행위 자체가 로그라이트 빌드 과정인 게임”**

이 되는 것이다.

---

# 56. v0.4 확정 사항

1. 프로젝트명: **JAMO**
2. 엔진: **Godot 4.x**
3. 화면: **2.5D 고정 3/4 뷰**
4. 기존 Day 시스템 제거
5. **Wave 기반 RUN 시스템**으로 변경
6. 패배 시 **Wave 1부터 재시작**
7. Gold는 영구 유지
8. Gold 업그레이드는 **Main Hub에서만 구매**
9. 단어 도감은 영구 유지
10. 단어 숙련도는 영구 유지
11. 현재 RUN에서 제작한 단어는 패배 시 초기화
12. RUN 자모 덱 변경은 패배 시 초기화
13. 자모 슬롯 보드 도입
14. 단어 = 장비 / 유물 / 특수효과 / 위험 효과
15. 동일 단어 재제작 시 Run Rank 강화
16. 합성어 시스템 도입
17. 자모 덱 압축 시스템 도입
18. 단어 계열 시너지 도입
19. 위험 단어 도입
20. Wave 5, 15, 25... 중간보스
21. Wave 10, 20, 30... 단어 보스
22. 단어 보스마다 고유 규칙과 능력 보유
23. 일부 단어 보스 처치 시 해당 단어를 도감/제작 풀에 해금
24. 기존 자모별 고유 보행 유지
25. 기존 클릭 타격감 유지
26. Energy는 Day 종료가 아니라 **Wave당 클릭 자원**으로 변경
27. 기존 상태이상 Resource 구조 유지
28. MetaState와 RunState 완전 분리
29. Godot 코드 전용 구현 금지
30. `.tscn`, `.tres`, AnimationPlayer, Inspector 기반 편집 구조 필수

---

**문서 버전:** v0.4  
**프로젝트:** JAMO  
**용도:** Godot 실제 개발 / Claude·Codex·Ziva 개발 지시 / 밸런스 기준  
