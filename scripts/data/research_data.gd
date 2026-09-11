class_name ResearchData
extends Resource
## Library research (B10).

@export var id: StringName = &""
@export var name: String = ""
@export var price: int = 0
@export var description: String = ""
@export var requires_research: StringName = &""
@export var requires_reach_wave: int = 0
## Effect payload: {"max_stability": 105} or {"unlock_deck": "starter_b"}.
@export var effect: Dictionary = {}
