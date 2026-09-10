class_name UpgradeManager

## Purchase rules for permanent gold upgrades. Doc v0.4 sections 13 and 28.
##
## v0.4 removed the Day unlock gates entirely: the gold price curve is the only
## pacing, so every track is listed from the first visit to the hub. Upgrades are
## bought in the Main Hub only, never during a run.

enum Availability {
	## Buyable right now.
	AVAILABLE,
	## Already at the highest level.
	MAXED,
	## A prerequisite codex word is still missing.
	LOCKED_BY_WORD,
	## A prerequisite upgrade track is not high enough yet.
	LOCKED_BY_UPGRADE,
	## Unlocked but the player cannot afford the next level.
	TOO_EXPENSIVE,
}


## Every real track is listed. The locks that remain are spelled out in the row
## rather than hiding it, so the shop never looks shorter than it is.
static func is_visible(upgrade: UpgradeData) -> bool:
	return upgrade != null


static func get_availability(upgrade: UpgradeData) -> Availability:
	# The gate reads the codex, not the current run: a word that was known once
	# stays known. Doc v0.4 section 38.
	if upgrade.required_word != &"" and not MetaState.has_codex_word(upgrade.required_word):
		return Availability.LOCKED_BY_WORD
	if upgrade.required_upgrade != &"" \
			and MetaState.get_upgrade_level(upgrade.required_upgrade) < upgrade.required_level:
		return Availability.LOCKED_BY_UPGRADE
	var level := MetaState.get_upgrade_level(upgrade.id)
	if level >= upgrade.max_level():
		return Availability.MAXED
	if MetaState.gold < float(upgrade.cost_for_next(level)):
		return Availability.TOO_EXPENSIVE
	return Availability.AVAILABLE


## Buys one level. Returns true when the purchase went through.
static func purchase(upgrade: UpgradeData) -> bool:
	if get_availability(upgrade) != Availability.AVAILABLE:
		return false
	var level := MetaState.get_upgrade_level(upgrade.id)
	var cost := upgrade.cost_for_next(level)
	if not MetaState.spend_gold(float(cost)):
		return false
	MetaState.set_upgrade_level(upgrade.id, level + 1)
	SignalBus.upgrade_purchased.emit(upgrade.id, level + 1)
	# An upgrade is a permanent settle point. Doc v0.4 section 45.
	SaveManager.save_meta()
	return true
