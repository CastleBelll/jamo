extends Node

## Global signal hub. UI listens here instead of reaching into MetaState or
## RunState, which keeps the scene tree free of hard references between panels.

## Emitted whenever the permanent gold balance changes. `total` is the new value.
signal gold_changed(total: float)
## Emitted whenever energy changes, including the wave-start refill.
signal energy_changed(current: int, maximum: int)
## Emitted when a wave begins. Fired after the refill. Doc v0.4 section 5.
signal wave_started(wave: int)
## Energy hit zero. Damage-over-time and automatic effects keep running.
signal energy_depleted()
## The 문장핵 took damage. Doc v0.4 section 6.1.
signal core_hp_changed(current: float, maximum: float)
## The run ended. RunState is already inactive; the result screen reads these.
signal run_failed(wave: int, kills: int, gold_earned: float)

## A monster died. `gold` is the amount already granted to the player.
signal monster_killed(jamo: String, gold: float, world_position: Vector3)
## Damage was applied somewhere in the world, for floating numbers and shake.
## `is_critical` only ever comes from a click; status ticks never crit.
signal damage_dealt(world_position: Vector3, amount: float, is_critical: bool)

## A word was crafted and equipped for the current run. Its effects are active.
signal word_completed(word: WordData)
## A word entered the codex for the first time. Permanent. Doc v0.4 section 2.7.
signal codex_word_registered(word_id: StringName)
## The word completion panel reached its reveal beat. The camera listens for
## this to run the word-complete zoom.
signal word_revealed()
## A permanent upgrade level was bought.
signal upgrade_purchased(upgrade_id: StringName, level: int)
