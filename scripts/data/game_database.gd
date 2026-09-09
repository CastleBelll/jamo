@tool
class_name GameDatabase
extends Resource

## Single entry point for every piece of tunable game data.
## Edit res://resources/balance/game_database.tres in the Inspector to add
## words or upgrades - no script change needed. Doc v0.3 section 19.1.

@export var balance: GameBalance

## Every craftable word, in unlock order.
@export var words: Array[WordData] = []

## Every gold upgrade track, in the order the shop should list them.
@export var upgrades: Array[UpgradeData] = []

## Extra jamo that may appear as day-end candidates even when no craftable word
## needs them. Leave empty to guarantee every candidate is useful.
## Doc v0.3 section 13.4.
@export var filler_jamo: PackedStringArray = PackedStringArray()


func find_word(word_id: StringName) -> WordData:
	for word: WordData in words:
		if word != null and word.id == word_id:
			return word
	return null


func find_upgrade(upgrade_id: StringName) -> UpgradeData:
	for upgrade: UpgradeData in upgrades:
		if upgrade != null and upgrade.id == upgrade_id:
			return upgrade
	return null
