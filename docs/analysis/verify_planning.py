"""Planning-only calculator; no game implementation or third-party dependencies.
Run: python docs/analysis/verify_planning.py
"""
from collections import Counter
from itertools import combinations
from math import comb, sqrt
import random
import json
import sys
import re
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

WORDS = {
    '검': 'ㄱㅓㅁ', '불': 'ㅂㅜㄹ', '독': 'ㄷㅗㄱ', '벽': 'ㅂㅕㄱ',
    '돌': 'ㄷㅗㄹ', '활': 'ㅎㅗㅏㄹ', '창': 'ㅊㅏㅇ', '칼': 'ㅋㅏㄹ',
    '눈': 'ㄴㅜㄴ', '물': 'ㅁㅜㄹ', '실': 'ㅅㅣㄹ', '숨': 'ㅅㅜㅁ',
    '돈': 'ㄷㅗㄴ', '운': 'ㅇㅜㄴ', '복': 'ㅂㅗㄱ', '길': 'ㄱㅣㄹ',
    '비': 'ㅂㅣ', '봄': 'ㅂㅗㅁ', '밤': 'ㅂㅏㅁ',
    '욕심': 'ㅇㅛㄱㅅㅣㅁ', '광기': 'ㄱㅗㅏㅇㄱㅣ', '폭주': 'ㅍㅗㄱㅈㅜ',
}
DECKS = {
    'A': 'ㄱㄱㄴㄷㄹㄹㅁㅂㅅㅇㅎㅏㅓㅗㅜㅜㅊㅣㅣㅕ',
    'B': 'ㄱㄴㄴㄷㄹㅁㅁㅂㅅㅇㅎㅏㅓㅗㅜㅜㅋㅣㅣㅕ',
}
RECIPES = {word: Counter(chars) for word, chars in WORDS.items()}

def decompose(word):
    initials = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ'
    vowels = 'ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ'
    finals = ' ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ'
    chars = ''
    for char in word:
        code = ord(char) - 0xAC00
        chars += initials[code // 588]
        vowel = vowels[(code % 588) // 28]
        chars += 'ㅗㅏ' if vowel == 'ㅘ' else vowel
        if code % 28:
            chars += finals[code % 28]
    return Counter(chars)

def available(hand):
    counts = Counter(hand)
    return [word for word, needed in RECIPES.items() if needed <= counts]

def exact(deck, slots):
    failures = 0
    total_candidates = 0
    target = 0
    for ids in combinations(range(len(deck)), slots):
        options = available([deck[i] for i in ids])
        failures += not options
        total_candidates += len(options)
        target += '불' in options
    count = comb(len(deck), slots)
    return {'hands': count, 'first_fail': failures / count,
            'mean_candidates': total_candidates / count, 'fire_first': target / count}

def trial(rng, deck, slots, locks, rerolls, policy):
    draw = list(deck)
    rng.shuffle(draw)
    hand = [draw.pop() for _ in range(slots)]
    discard = []
    for turn in range(rerolls + 1):
        options = available(hand)
        if policy == 'any' and options:
            return True, len(options)
        if policy == 'fire' and '불' in options:
            return True, len(options)
        if turn == rerolls:
            return bool(options) if policy == 'any' else '불' in options, len(options)
        counts = Counter(hand)
        feasible = [(word, req) for word, req in RECIPES.items() if req <= Counter(deck)]
        target = RECIPES['불'] if policy == 'fire' else min(
            feasible, key=lambda item: (sum((item[1] - counts).values()),
                                        -sum((item[1] & counts).values()), item[0]))[1]
        remaining = target.copy()
        kept = []
        for char in hand:
            if remaining[char] and len(kept) < locks:
                kept.append(char)
                remaining[char] -= 1
            else:
                discard.append(char)
        while len(kept) < slots:
            if not draw:
                draw, discard = discard, []
                rng.shuffle(draw)
            kept.append(draw.pop())
        hand = kept

def simulate(deck, slots, locks, policy, n=20000):
    rng = random.Random(20260911)
    successes = candidates = 0
    for _ in range(n):
        ok, count = trial(rng, deck, slots, locks, 2, policy)
        successes += ok
        candidates += count
    p = successes / n
    return {'n': n, 'success': p, 'ci95_halfwidth': 1.96 * sqrt(p*(1-p)/n),
            'mean_candidates_at_stop': candidates / n}

def expected_drop(kills):
    states = {(0, 0): 1.0}
    for _ in range(kills):
        nxt = Counter()
        for (miss, count), mass in states.items():
            if count == 6:
                nxt[(miss, count)] += mass
                continue
            p = 1.0 if miss == 4 else .25
            nxt[(0, count+1)] += mass*p
            nxt[(miss+1, count)] += mass*(1-p)
        states = nxt
    return {'mean': sum(count*p for (_, count), p in states.items()),
            'zero': sum(p for (_, count), p in states.items() if count == 0)}

def validate_documents():
    docs = Path(__file__).resolve().parents[1]
    files = [docs / name for name in [
        'JAMO_01_story_world_v0.3.md', 'JAMO_02_game_design_v0.7.md',
        'JAMO_03_balance_detail_v0.3.md', 'JAMO_PLANNING_CHANGELOG.md',
        'analysis/JAMO_probability_report.md']]
    balance = files[2].read_text(encoding='utf-8')
    rows = re.findall(r'^\| (W\d{2}) ([가-힣]+) / ([ㄱ-ㅣ]+) \|', balance, re.M)
    assert [row[0] for row in rows] == [f'W{i:02}' for i in range(1, 23)]
    assert {word: chars for _, word, chars in rows} == WORDS
    for _, word, chars in rows:
        assert Counter(chars) == decompose(word)
        assert len(chars) <= 7
    compounds = re.findall(r'^\| (C\d{2}) ([가-힣]+) / ([ㄱ-ㅣ]+) \|', balance, re.M)
    assert len(compounds) == 2
    for _, word, chars in compounds:
        assert Counter(chars) == decompose(word)
    for name, deck in DECKS.items():
        match = re.search(r'Starter ' + name + r'\([^\n]*?`([^`]+)`', balance)
        assert match and ''.join(match.group(1).split()) == deck
    frequency_rows = re.findall(r'^\| ([ㄱ-ㅣ]) \| (\d+) \| (\d+) \| (\d+) \| (\d+) \|', balance, re.M)
    full = Counter(''.join(WORDS.values()))
    fresh = Counter(''.join(chars for word, chars in WORDS.items()
                            if word not in ['욕심', '광기', '폭주']))
    assert len(frequency_rows) == len(full)
    for char, f, all_f, w, all_w in frequency_rows:
        assert int(f) == fresh[char] and int(all_f) == full[char]
        assert int(w) == (fresh[char]+2 if fresh[char] else 0)
        assert int(all_w) == full[char]+2
    wave_rows = re.findall(r'^\| (\d+) \| (\d+) \| (\d+) \| ([\d.]+) \| (\d+) \| (\d+) \| (\d+)% \|', balance, re.M)
    assert sorted(int(r[0]) for r in wave_rows) == [i for i in range(1, 21) if i % 5]
    assert sum(int(r[1]) * (1 if int(r[0]) < 10 else 2) for r in wave_rows) == 438
    link_count = 0
    for file in files:
        content = file.read_text(encoding='utf-8')
        assert '\ufffd' not in content and not re.search('[\u3040-\u30ff]', content), file
        assert content.count('```') % 2 == 0, file
        for target in re.findall(r'\]\(([^)]+)\)', content):
            assert (file.parent / target.split('#')[0]).exists(), (file, target)
            link_count += 1
        widths = []
        for line in content.splitlines() + ['']:
            if line.startswith('|'):
                widths.append(line.count('|'))
            else:
                assert not widths or len(set(widths)) == 1, (file, widths)
                widths = []
    return {'documents': len(files), 'links': link_count, 'basic_words': len(rows),
            'compounds': len(compounds), 'wave_rows': len(wave_rows),
            'frequency_rows': len(frequency_rows), 'status': 'PASS'}

if __name__ == '__main__':
    validation = validate_documents()
    if '--validate-only' in sys.argv:
        print(json.dumps(validation, ensure_ascii=False, indent=2))
        raise SystemExit(0)
    for word, recipe in RECIPES.items():
        assert recipe == decompose(word), word
    freq = Counter(''.join(WORDS.values()))
    fresh_freq = Counter(''.join(chars for word, chars in WORDS.items()
                                 if word not in ['욕심', '광기', '폭주']))
    total_weight = sum(count+2 for count in freq.values())
    report = {'document_validation': validation,
              'base_words': len(WORDS), 'frequency_total': sum(freq.values()),
              'symbols': len(freq), 'weight_total': total_weight,
              'frequency': {char: {'count': count, 'weight': count+2,
                                   'percent': 100*(count+2)/total_weight}
                            for char, count in sorted(freq.items())},
              'fresh_frequency': dict(sorted(fresh_freq.items())),
              'fresh_weight_total': sum(c+2 for c in fresh_freq.values()),
              'decks': {}, 'drop': {k: expected_drop(k) for k in [8, 10, 14, 20, 24]}}
    # Empty-build starter baseline: only the 19 initially unlocked words.
    RECIPES = {word: req for word, req in RECIPES.items()
               if word not in ['욕심', '광기', '폭주']}
    for name, deck in DECKS.items():
        assert len(deck) == 20
        assert set(deck) <= set(fresh_freq)
        report['decks'][name] = {'size': len(deck),
            'impossible': [word for word, req in RECIPES.items() if not req <= Counter(deck)],
            '6_slots_2_locks': {'exact': exact(deck, 6), 'any': simulate(deck, 6, 2, 'any')},
            '7_slots_3_locks': {'exact': exact(deck, 7), 'any': simulate(deck, 7, 3, 'any'),
                                'fire': simulate(deck, 7, 3, 'fire')}}
    print(json.dumps(report, ensure_ascii=False, indent=2))
