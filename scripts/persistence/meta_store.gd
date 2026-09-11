extends Node
## MetaStore (G13): profile facts that outlive a RUN. In-memory for now; SaveManager (P4)
## will load and persist it. Autoloaded as `Meta`.

## 거대한 ㅁ was purified at least once: 위험 words join the pool from the NEXT RUN (B5).
var mieum_purified: bool = false
## The tutorial rules (first W1 rewards, tutorial hand, guidance lines) apply once per profile.
var first_run_done: bool = false


func risk_unlocked_for_new_run() -> bool:
	return mieum_purified
