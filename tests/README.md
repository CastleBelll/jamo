# Tests

Headless Godot 4.7 scenes. Each prints `PASS`/`FAIL` and exits non-zero on failure.
Run them one at a time; a GDScript parse error can hang a headless run, so wrap in `timeout`.

```powershell
# once per fresh checkout: build .godot/ class cache
godot --headless --path . --import
# content data (B2/B6/B7/B8/B9/B10/G11 tables, cross references, Hangul decomposition)
godot --headless --path . tests/test_content.tscn
# G2 state machine + screen skeleton (paths, HUD, phase panels)
godot --headless --path . tests/test_run_controller.tscn
# W1 combat: spawn coordinates/lanes, click overlap + cooldown, purify/reach once, spacing, clear vs defeat
godot --headless --path . tests/test_combat.tscn
# deck tokens, drop pity/cap/rate, reward picks/replace/remove, 자모 정리 panel flow
godot --headless --path . tests/test_deck.tscn
# Forge: full shuffle, non-replacement draws, lock/reroll, candidates, restore transaction, failure pity, pin, screen flow
godot --headless --path . tests/test_forge.tscn
# word effects: B1 formulas, burn/poison/slow, auto hits without procs, counters, kill triggers, clear heal, gold, drops
godot --headless --path . tests/test_effects.tscn
# W5 boss: capsule, patterns/대응물, minions, phase 2, purify cleanup + body drops, result screen, 재도전, 복 removes
godot --headless --path . tests/test_boss.tscn
# variants LIGHT/HEAVY/GUARD, 합성 recipes/preview/once-per-confirm, 위험 pool snapshot, HUD hover
godot --headless --path . tests/test_variants.tscn
# W10 침묵 seal, W15 질주 ㅇ lane markers, W20 탐욕 shield/ring, W20 completion
godot --headless --path . tests/test_bosses_late.tscn
```
