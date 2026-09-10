@tool
class_name GameBalance
extends Resource

## Global balance constants. Edit in the Inspector via
## res://resources/balance/game_balance.tres - no code change required.
## Doc v0.4 section 46: balance never lives in a gameplay script.

@export_group("Wave / Energy")
## Energy a wave starts with at upgrade level 0. Doc v0.4 section 7.1.
@export var start_max_energy: int = 20
## Energy consumed by one manual click. Doc v0.4 section 7.1.
@export var click_energy_cost: int = 1

## Energy remaining at which the HUD starts warning that manual clicks are
## nearly out. Raise it here rather than in hud.gd so the warning can be
## retuned without a code change.
@export_range(0, 20) var low_energy_warning: int = 3

@export_group("Click")
## Click damage at upgrade level 0. Doc v0.4 section 8.
@export var base_click_damage: float = 1.0
## CritMultiplier before run word bonuses are added. Doc v0.4 section 8.
@export_range(1.0, 10.0, 0.1) var base_crit_multiplier: float = 2.0

@export_group("Monster Scaling")
## TEMPORARY, Phase 0 only: the v0.3 Day curve mapped one-to-one onto Wave so
## the game still runs. v0.4 section 5.2 wants a wave curve that raises speed,
## count, special ratio and spawn rate rather than HP alone, and section 52
## warns against reusing the Day numbers. The real curve is Phase 1 / Phase 12.
## HP = base_monster_hp * pow(hp_growth_per_wave, wave - 1).
@export var base_monster_hp: float = 3.0
@export var hp_growth_per_wave: float = 1.035
## Gold = base_monster_gold * pow(gold_growth_per_wave, wave - 1).
@export var base_monster_gold: float = 2.0
@export var gold_growth_per_wave: float = 1.025

@export_group("Field")
## Simultaneous monsters at upgrade level 0. Doc v0.4 section 13.
@export var base_monster_capacity: int = 8

@export_group("Special Monsters")
## Chance one spawn is drawn from the Special Pool instead of the normal one,
## before the 운 luck multiplier. growth_balance v0.2 section 2.
@export_range(0.0, 1.0, 0.005) var special_spawn_chance: float = 0.02
## Same, for the Golden Pool. Only rolled once the word 금 is completed.
## Doc v0.3 section 9.3.
@export_range(0.0, 1.0, 0.005) var golden_spawn_chance: float = 0.02

@export_group("Jamo Slot")
## Jamo drawn onto the slot board, before permanent upgrades. Doc v0.4 section
## 9.1 raises this to 4; the board itself is Phase 2.
@export var base_jamo_candidates: int = 2

@export_group("Run")
## 문장핵 HP a run starts with, at upgrade level 0. Doc v0.4 section 6.1.
@export var base_core_hp: float = 20.0
## Seconds to let lingering damage-over-time resolve before the run result UI.
@export_range(0.0, 3.0, 0.05) var run_end_settle_seconds: float = 0.8


## HP of a normal monster on the given wave, rounded to a whole number.
func monster_hp_for_wave(wave: int) -> float:
	return roundf(base_monster_hp * pow(hp_growth_per_wave, wave - 1))


## Gold dropped by a normal monster on the given wave. Kept fractional on
## purpose; only the HUD rounds it.
func monster_gold_for_wave(wave: int) -> float:
	return base_monster_gold * pow(gold_growth_per_wave, wave - 1)
