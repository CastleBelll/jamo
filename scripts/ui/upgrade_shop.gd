extends Control

## Permanent gold upgrade shop. Doc v0.4 sections 13 and 28: this panel lives in
## the Main Hub and is deliberately unreachable during a run, so a wave can
## never be rescued by opening the shop mid-fight.

signal closed()

@onready var _rows: Array[UpgradeRow] = [
	%RowEnergy, %RowDamage, %RowCritical, %RowGold, %RowCapacity, %RowReroll,
]
@onready var _gold_label: Label = %ShopGoldLabel


func _ready() -> void:
	hide()
	for row: UpgradeRow in _rows:
		row.purchased.connect(_on_row_purchased)
	%CloseButton.pressed.connect(_on_close_pressed)


func open() -> void:
	_refresh()
	show()
	%CloseButton.grab_focus()


func _refresh() -> void:
	_gold_label.text = "보유 골드  %d G" % int(MetaState.gold)
	for row: UpgradeRow in _rows:
		row.refresh()


func _on_row_purchased(_upgrade: UpgradeData) -> void:
	# Buying one upgrade can make another unaffordable, so refresh them all.
	_refresh()


func _on_close_pressed() -> void:
	hide()
	closed.emit()
