class_name EffectText
extends RefCounted
## Short Korean descriptions of EffectData lines for the Forge compare UI (G10).


static func describe(e: EffectData) -> String:
	var pct := "%+d%%" % roundi(e.value * 100.0)
	match e.kind:
		&"manual_damage_pct": return "수동 %s" % pct
		&"manual_damage_pct_lowhp": return "HP%d%%↓ 수동 %s" % [roundi(e.value2 * 100.0), pct]
		&"manual_damage_pct_near_end": return "문장 근접 적 수동 %s" % pct
		&"crit_chance": return "치명 %s" % pct
		&"apply_burn": return "화상 %.0f초 %.1f/초" % [e.duration, e.value]
		&"burn_spread": return "정화 시 화상 전이 %d" % e.target_count
		&"apply_poison": return "중독 %.0f초 %.2f/초 ×%d" % [e.duration, e.value, e.max_stacks]
		&"apply_slow": return "둔화 %d%% %.1f초" % [roundi(e.value * 100.0), e.duration]
		&"stability_damage_pct": return "받는 피해 %s" % pct
		&"stability_taken_pct": return "받는 피해 %s" % pct
		&"damage_front": return "%.1f초마다 앞 적 %d에 %.1f" % [e.interval, e.target_count, e.value]
		&"damage_lane_front_other": return "%d타마다 통로 앞 적 %.1f" % [e.every_n, e.value]
		&"damage_near_other": return "%s근처 적 %.1f" % ["%d타마다 " % e.every_n if e.every_n > 0 else "정화 시 ", e.value]
		&"heal_stability": return "정화 %d회마다 안정도 +%.0f" % [e.every_n, e.value]
		&"clear_heal_bonus": return "Clear 회복 +%.0f" % e.value
		&"gold_pct": return "Gold %s" % pct
		&"heal_per_gold": return "Clear %.0fG당 +%.0f (최대 %.0f)" % [e.value2, e.value, e.cap]
		&"drop_chance_add": return "회수 확률 %+d%%p" % roundi(e.value * 100.0)
		&"extra_remove_every_n": return "W%d배수 제거 +1" % e.every_n
		&"enemy_speed_pct": return "적 속도 %s" % pct
		&"enemy_speed_mult": return "적 속도 ×%.2f" % e.value
		&"shield": return "보호막 %.0f" % e.value
		&"dot_damage_pct": return "지속 피해 %s" % pct
		&"input_interval": return "입력 간격 %.2f초" % e.value
		&"auto_period_mult": return "자동 주기 ×%.1f" % e.value
		&"reward_pick_add": return "자모 선택 +%d" % int(e.value)
	return String(e.kind)


static func describe_rank(word: WordData, rank: int) -> String:
	var parts: Array[String] = []
	for e in word.effects_at(rank):
		parts.append(describe(e))
	return " / ".join(parts)
