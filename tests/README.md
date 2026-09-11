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
```
