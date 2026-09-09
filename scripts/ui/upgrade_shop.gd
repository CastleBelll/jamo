extends Control

## Gold upgrade shop, shown between days. Doc v0.3: upgrades are never on the
## play HUD; they are bought here after the day ends.

signal closed()

@onready var _rows: Array[UpgradeRow] = [
	%RowEnergy, %RowDamage, %RowCritical, %RowGold, %RowCapacity, %RowReroll,
]
@onready var _gold_label: Label = %ShopGoldLabel


func _ready() -> void:
	hide()
	for row: UpgradeRow in _rows:
		row.purchased.connect(_on_row_purchased)
	%NextDayButton.pressed.connect(_on_next_day_pressed)


func open() -> void:
	_refresh()
	show()
	%NextDayButton.grab_focus()


func _refresh() -> void:
	_gold_label.text = "보유 골드  %d G" % int(GameState.gold)
	for row: UpgradeRow in _rows:
		row.refresh()


func _on_row_purchased(_upgrade: UpgradeData) -> void:
	# Buying one upgrade can make another unaffordable, so refresh them all.
	_refresh()


func _on_next_day_pressed() -> void:
	hide()
	closed.emit()
