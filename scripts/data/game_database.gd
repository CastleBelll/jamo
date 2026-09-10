@tool
class_name GameDatabase
extends Resource

## Single entry point for every piece of tunable game data.
## Edit res://resources/balance/game_database.tres in the Inspector to add
## words or upgrades - no script change needed. Doc v0.4 section 46.

@export var balance: GameBalance

## Every craftable word. The codex counts this list as its total.
@export var words: Array[WordData] = []

## Every permanent gold upgrade track, in the order the shop lists them.
@export var upgrades: Array[UpgradeData] = []

## Extra jamo that may appear on the slot board even when no craftable word
## needs them. Leave empty to guarantee every draw is useful. The board that
## reads this is Phase 2. Doc v0.4 section 9.2.
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
