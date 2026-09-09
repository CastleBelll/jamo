class_name UpgradeRow
extends PanelContainer

## One gold upgrade line in the shop. Assign `upgrade` in the Inspector - the
## row reads every number from that .tres, so prices are never in code.

signal purchased(upgrade: UpgradeData)

## The upgrade track this row displays.
@export var upgrade: UpgradeData

@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel
@onready var _cost_label: Label = %CostLabel
@onready var _buy_button: Button = %BuyButton


func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_pressed)


func refresh() -> void:
	if upgrade == null:
		visible = false
		return
	visible = UpgradeManager.is_visible(upgrade)
	if not visible:
		return

	var level := GameState.get_upgrade_level(upgrade.id)
	var base := _base_value_for(upgrade.id)
	_name_label.text = "%s  Lv.%d" % [upgrade.display_name, level]

	var availability := UpgradeManager.get_availability(upgrade)
	if availability == UpgradeManager.Availability.MAXED:
		_value_label.text = upgrade.format_value(level, base)
		_cost_label.text = "최대"
		_buy_button.disabled = true
		_buy_button.text = "완료"
		return

	_value_label.text = "%s → %s" % [
		upgrade.format_value(level, base),
		upgrade.format_value(level + 1, base),
	]
	var cost := upgrade.cost_for_next(level)
	_buy_button.text = "구매"
	if availability == UpgradeManager.Availability.TOO_EXPENSIVE:
		_cost_label.text = "보유 %d G / 필요 %d G" % [int(GameState.gold), cost]
		_buy_button.disabled = true
	else:
		_cost_label.text = "%d G" % cost
		_buy_button.disabled = false


## Level 0 of each track shows the game base value, which lives in GameBalance.
func _base_value_for(upgrade_id: StringName) -> float:
	match upgrade_id:
		GameState.UPGRADE_MAX_ENERGY:
			return float(GameState.balance.start_max_energy)
		GameState.UPGRADE_CLICK_DAMAGE:
			return GameState.balance.base_click_damage
		GameState.UPGRADE_MONSTER_CAPACITY:
			return float(GameState.balance.base_monster_capacity)
		_:
			return 0.0


func _on_buy_pressed() -> void:
	if UpgradeManager.purchase(upgrade):
		purchased.emit(upgrade)
