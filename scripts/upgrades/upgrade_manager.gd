class_name UpgradeManager

## Purchase rules for gold upgrades. Doc growth_balance v0.2 sections 13 and 17:
## both the gold price and the day requirement must be satisfied.

enum Availability {
	## Buyable right now.
	AVAILABLE,
	## Already at the highest level.
	MAXED,
	## Day requirement not reached yet, so it should not even be listed.
	LOCKED_BY_DAY,
	## A prerequisite word is still missing.
	LOCKED_BY_WORD,
	## A prerequisite upgrade track is not high enough yet.
	LOCKED_BY_UPGRADE,
	## Unlocked but the player cannot afford the next level.
	TOO_EXPENSIVE,
}


## Only the day gate hides a track completely (growth_balance v0.2 section 13:
## not every upgrade is shown on Day 1). The other locks stay listed so the
## shop can spell out which requirement is still missing.
static func is_visible(upgrade: UpgradeData) -> bool:
	return get_availability(upgrade) != Availability.LOCKED_BY_DAY


static func get_availability(upgrade: UpgradeData) -> Availability:
	if GameState.day < upgrade.unlock_day:
		return Availability.LOCKED_BY_DAY
	if upgrade.required_word != &"" and not GameState.is_word_unlocked(upgrade.required_word):
		return Availability.LOCKED_BY_WORD
	if upgrade.required_upgrade != &"" \
			and GameState.get_upgrade_level(upgrade.required_upgrade) < upgrade.required_level:
		return Availability.LOCKED_BY_UPGRADE
	var level := GameState.get_upgrade_level(upgrade.id)
	if level >= upgrade.max_level():
		return Availability.MAXED
	if GameState.gold < float(upgrade.cost_for_next(level)):
		return Availability.TOO_EXPENSIVE
	return Availability.AVAILABLE


## Buys one level. Returns true when the purchase went through.
static func purchase(upgrade: UpgradeData) -> bool:
	if get_availability(upgrade) != Availability.AVAILABLE:
		return false
	var level := GameState.get_upgrade_level(upgrade.id)
	var cost := upgrade.cost_for_next(level)
	GameState.gold -= float(cost)
	GameState.upgrade_levels[upgrade.id] = level + 1
	SignalBus.gold_changed.emit(GameState.gold)
	SignalBus.upgrade_purchased.emit(upgrade.id, level + 1)
	SaveManager.save_game()
	return true
