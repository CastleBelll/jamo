@tool
class_name GameBalance
extends Resource

## Global balance constants. Edit in the Inspector via
## res://resources/balance/game_balance.tres - no code change required.

@export_group("Day / Energy")
## Energy available on Day 1 with no upgrades. Doc v0.3 section 11.
@export var start_max_energy: int = 20
## Energy consumed by one manual click. Doc v0.3 section 2.2.
@export var click_energy_cost: int = 1

@export_group("Click")
## Click damage at upgrade level 0. Doc v0.3 section 10.1.
@export var base_click_damage: float = 1.0
## CritMultiplier before word bonuses are added. Doc v0.3 section 10.2.
@export_range(1.0, 10.0, 0.1) var base_crit_multiplier: float = 2.0

@export_group("Monster Scaling")
## HP = base_monster_hp * pow(hp_growth_per_day, day - 1). Doc v0.3 section 8.1.
@export var base_monster_hp: float = 3.0
@export var hp_growth_per_day: float = 1.035
## Gold = base_monster_gold * pow(gold_growth_per_day, day - 1). Doc v0.3 section 8.1.
@export var base_monster_gold: float = 2.0
@export var gold_growth_per_day: float = 1.025

@export_group("Field")
## Simultaneous monsters at upgrade level 0. Doc v0.3 section 28.
@export var base_monster_capacity: int = 8

@export_group("Jamo Choice")
## Jamo candidates offered at day end, upgrade level 0. Doc v0.3 section 13.
@export var base_jamo_candidates: int = 2

@export_group("Day End")
## Seconds to let lingering damage-over-time resolve before the day-end UI.
## Doc v0.3 section 12 recommends 0.5~1.0s.
@export_range(0.0, 3.0, 0.05) var day_end_settle_seconds: float = 0.8


## HP of a normal monster on the given day, rounded to a whole number.
func monster_hp_for_day(day: int) -> float:
	return roundf(base_monster_hp * pow(hp_growth_per_day, day - 1))


## Gold dropped by a normal monster on the given day. Kept fractional on
## purpose; only the HUD rounds it. Doc v0.3 section 4.
func monster_gold_for_day(day: int) -> float:
	return base_monster_gold * pow(gold_growth_per_day, day - 1)
