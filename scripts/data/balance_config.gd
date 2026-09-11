class_name BalanceConfig
extends Resource
## Global tuning (B1, B3, B4, B5, B10, B11). Every value is a start value.

# B1 combat
@export var manual_base_damage: float = 1.0
@export var manual_interval: float = 0.25
@export var manual_damage_bonus_cap: float = 1.0
@export var stability_max: float = 100.0
@export var stability_max_cap: float = 110.0
@export var reach_damage: float = 8.0
@export var crit_chance_base: float = 0.0
@export var crit_chance_cap: float = 0.35
@export var crit_multiplier: float = 1.5
@export var damage_reduction_cap: float = 0.35
@export var auto_base_damage: float = 1.0
@export var clear_heal: float = 4.0
@export var status_tick: float = 1.0
@export var min_speed_ratio: float = 0.5
@export var shield_cap: float = 20.0

# B2 variants
@export var variant_weights: Dictionary = {"LIGHT": 40, "HEAVY": 40, "GUARD": 20}
@export var light_hp_mult: float = 0.8
@export var light_speed_mult: float = 1.25
@export var heavy_hp_mult: float = 1.6
@export var heavy_speed_mult: float = 0.8
@export var guard_damage_reduction: float = 0.25

# B3 deck / forge
@export var starter_size: int = 20
@export var deck_min: int = 14
@export var deck_max: int = 26
@export var hand_size: int = 7
@export var reroll_base: int = 2
@export var lock_max: int = 3
@export var restores_per_forge: int = 1
@export var build_slots: int = 6
@export var risk_slot_max: int = 1
@export var forge_fail_heal: float = 8.0
@export var forge_fail_bonus_reroll: int = 1
@export var forge_fail_bonus_reroll_cap: int = 1
@export var tutorial_hand: Array[String] = ["ㄱ", "ㅓ", "ㅁ", "ㅂ", "ㅜ", "ㄹ", "ㅣ"]

# B4 drops
@export var drop_chance: float = 0.25
@export var drop_chance_cap: float = 0.40
@export var drop_pity_misses: int = 4
@export var drop_cap_per_wave: int = 6
@export var reward_picks_normal: int = 1
@export var reward_picks_boss: int = 2
@export var reward_removes_boss: int = 1

# B5 spawn weights
@export var spawn_weight_bonus: int = 2
@export var pin_weight_mult: float = 1.15

# B10 gold
@export var gold_per_kill_early: int = 1
@export var gold_per_kill_late: int = 2
@export var gold_late_from_wave: int = 11
@export var mastery_thresholds: Array[int] = [1, 3, 6]

# B11 screen (logical 1920x1080)
@export var logical_size: Vector2 = Vector2(1920, 1080)
@export var combat_rect: Rect2 = Rect2(220, 150, 1480, 710)
@export var sentence_y_range: Vector2 = Vector2(880, 940)
@export var lane_x: Array[float] = [480.0, 960.0, 1440.0]
@export var lane_spawn_y: float = 370.0
@export var lane_end_y: float = 850.0
@export var sub_path_offset: float = 65.0
@export var enemy_visual_px: float = 56.0
@export var enemy_click_diameter: float = 76.0
@export var enemy_min_spacing: float = 92.0
@export var pattern_target_px: float = 90.0
@export var max_normal_enemies: int = 8
@export var max_boss_minions: int = 4
@export var sfx_max_voices: int = 8
@export var particle_cap: int = 256


func validate() -> Array[String]:
	var errors: Array[String] = []
	if hand_size < 6 or lock_max > hand_size:
		errors.append("balance: hand/lock out of range")
	if deck_min > starter_size or starter_size > deck_max:
		errors.append("balance: starter must sit inside deck min/max")
	if enemy_click_diameter < enemy_visual_px or enemy_min_spacing < enemy_click_diameter:
		errors.append("balance: click circle must cover visual and fit spacing")
	if tutorial_hand.size() != hand_size:
		errors.append("balance: tutorial hand must have hand_size tokens")
	return errors
