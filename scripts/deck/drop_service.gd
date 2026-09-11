class_name DropService
extends RefCounted
## 회수 judgement (B4): 25% per normal purify (+word bonus, capped), pity after 4 misses in
## a row, at most 6 per Wave, counter reset at Wave start. Uses its own RNG stream (B5).

var rng := RandomNumberGenerator.new()
var chance: float = 0.25
var chance_cap: float = 0.40
var pity_misses: int = 4
var cap_per_wave: int = 6
var bonus: float = 0.0

var misses: int = 0
var drops: Array[String] = []


func setup(balance: BalanceConfig, seed: int) -> void:
	chance = balance.drop_chance
	chance_cap = balance.drop_chance_cap
	pity_misses = balance.drop_pity_misses
	cap_per_wave = balance.drop_cap_per_wave
	rng.seed = seed


func start_wave() -> void:
	misses = 0
	drops.clear()


func effective_chance() -> float:
	return minf(chance + bonus, chance_cap)


func is_capped() -> bool:
	return drops.size() >= cap_per_wave


## Called once per normal purify with the purified jamo. Returns true when it was recovered.
## After the Wave cap no judgement happens at all (G4).
func roll(jamo: String) -> bool:
	if is_capped():
		return false
	var guaranteed := misses >= pity_misses
	var success := guaranteed or rng.randf() < effective_chance()
	if success:
		misses = 0
		drops.append(jamo)
	else:
		misses += 1
	return success


## Boss body drops (B4) bypass the cap and never touch the pity counter.
func add_guaranteed(jamo: String) -> void:
	drops.append(jamo)


func snapshot() -> Dictionary:
	return {"drops": drops.duplicate(), "misses": misses, "rng_state": str(rng.state), "bonus": bonus}


func restore(d: Dictionary) -> void:
	drops.clear()
	for j in d.get("drops", []):
		drops.append(String(j))
	misses = int(d.get("misses", 0))
	bonus = float(d.get("bonus", 0.0))
	if d.has("rng_state"):
		rng.state = String(d["rng_state"]).to_int()
