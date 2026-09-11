class_name EffectText
extends RefCounted
## Short Korean descriptions of EffectData lines for the Forge compare UI (G10).


static func describe(e: EffectData) -> String:
	var pct := "%+d%%" % roundi(e.value * 100.0)
	match e.kind:
		&"manual_damage_pct": return "수동 피해 %s" % pct
		&"manual_damage_pct_lowhp": return "HP %d%% 이하 대상 수동 피해 %s" % [roundi(e.value2 * 100.0), pct]
		&"manual_damage_pct_near_end": return "남은 경로 %d%% 이하 적에 수동 피해 %s" % [roundi(e.value2 * 100.0), pct]
		&"crit_chance": return "치명 %s" % pct
		&"apply_burn": return "적중 시 화상 %.0f초, 초당 %.1f" % [e.duration, e.value]
		&"burn_spread": return "정화 시 %dpx 내 %d적에 화상 전이" % [int(e.radius_px), e.target_count]
		&"apply_poison": return "적중 시 중독 %.0f초, 스택당 초당 %.2f, 최대 %d" % [e.duration, e.value, e.max_stacks]
		&"apply_slow": return "적중 시 %.1f초 둔화 %d%%" % [e.duration, roundi(e.value * 100.0)]
		&"stability_damage_pct": return "안정도 피해 %s" % pct
		&"stability_taken_pct": return "받는 안정도 피해 %s" % pct
		&"damage_front": return "%.1f초마다 앞선 %d적에 %.1f 피해" % [e.interval, e.target_count, e.value]
		&"damage_lane_front_other": return "수동 %d회 적중마다 같은 통로 앞선 적에 %.1f 피해" % [e.every_n, e.value]
		&"damage_near_other": return "%s%dpx 내 다른 적에 %.1f 피해" % ["수동 %d회 적중마다 " % e.every_n if e.every_n > 0 else "정화 시 ", int(e.radius_px), e.value]
		&"heal_stability": return "직접 정화 %d회마다 안정도 %.0f 회복" % [e.every_n, e.value]
		&"clear_heal_bonus": return "Clear 회복 +%.0f" % e.value
		&"gold_pct": return "정화 Gold %s" % pct
		&"heal_per_gold": return "Clear 시 %.0fG당 안정도 %.0f 회복 (최대 %.0f)" % [e.value2, e.value, e.cap]
		&"drop_chance_add": return "회수 확률 %+d%%p" % roundi(e.value * 100.0)
		&"extra_remove_every_n": return "일반 Wave %d의 배수에서 제거 1회" % e.every_n
		&"enemy_speed_pct": return "적 이동속도 %s" % pct
		&"enemy_speed_mult": return "적 이동속도 x%.2f" % e.value
		&"shield": return "Wave 시작 보호막 %.0f" % e.value
		&"dot_damage_pct": return "화상·중독 피해 %s" % pct
		&"input_interval": return "입력 간격 %.2f초" % e.value
		&"auto_period_mult": return "자동 주기 x%.1f" % e.value
		&"reward_pick_add": return "일반 Wave 자모 선택 +%d" % int(e.value)
	return String(e.kind)


static func describe_rank(word: WordData, rank: int) -> String:
	var parts: Array[String] = []
	for e in word.effects_at(rank):
		parts.append(describe(e))
	return " / ".join(parts)
