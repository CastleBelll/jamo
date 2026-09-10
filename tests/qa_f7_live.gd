extends Node

## Boots the real title screen and prints the focus owner every time it changes,
## so a live keyboard run shows where the arrow keys actually land. Read-only:
## it never writes or deletes a save. Run through the editor Game tab, or:
##   godot --path . res://tests/qa_f7_live.tscn

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

var _title: Control
var _last: String = ""


func _ready() -> void:
	_title = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(_title)


func _process(_delta: float) -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	var focus_name: String = String(focused.name) if focused != null else "<none>"
	var settings: Control = _title.get_node("%Settings")
	var outside: String = ""
	if focused != null and settings.visible and not settings.is_ancestor_of(focused):
		outside = "  <== ESCAPED THE PANEL"
	if focus_name != _last:
		_last = focus_name
		print("focus -> %s%s" % [focus_name, outside])
	if Engine.get_process_frames() % 90 == 0:
		print("  sfx=%d%% bgm=%d%% master=%d%% settings_open=%s" % [
			roundi(settings.get_node("%SfxSlider").value * 100.0),
			roundi(settings.get_node("%BgmSlider").value * 100.0),
			roundi(settings.get_node("%MasterSlider").value * 100.0),
			str(settings.visible),
		])
