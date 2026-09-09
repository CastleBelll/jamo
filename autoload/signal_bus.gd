extends Node

## Global signal hub. UI listens here instead of reaching into GameState,
## which keeps the scene tree free of hard references between panels.

## Emitted whenever gold changes. `total` is the new balance.
signal gold_changed(total: float)
## Emitted whenever energy changes, including the day-start refill.
signal energy_changed(current: int, maximum: int)
## Emitted when the day counter advances. Fired after the refill.
signal day_started(day: int)
## Energy hit zero. The main scene waits out the settle delay, then ends the day.
signal energy_depleted()
## The day-end sequence finished its last panel and play resumed.
signal day_ended(day: int, kills: int, gold_earned: float)

## A monster died. `gold` is the amount already granted to the player.
signal monster_killed(jamo: String, gold: float, world_position: Vector3)
## Damage was applied somewhere in the world, for floating numbers and shake.
## `is_critical` only ever comes from a click; status ticks never crit.
signal damage_dealt(world_position: Vector3, amount: float, is_critical: bool)

## The player picked a jamo at day end.
signal jamo_collected(jamo: String)
## A word finished. Its effects are already active.
signal word_completed(word: WordData)
## An upgrade level was bought.
signal upgrade_purchased(upgrade_id: StringName, level: int)
