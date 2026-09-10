extends RefCounted

## The Main Hub's plate buttons, read off the scene instead of written down.
##
## Every F7-F9 harness used to carry its own hardcoded four-name list
## (NewGameButton / ContinueButton / SettingsButton / QuitButton), so the three
## rows doc v0.4 section 27 added in P0 - 영구 업그레이드 / 단어 도감 / 기록 -
## were checked by nothing, and "exactly one bright plate" was being asserted
## over a subset of the menu. The menu grows again every phase, so the list is
## derived here once and shared: a row the hub draws is covered the moment it
## exists.
##
## Used as `const HubPlates := preload("res://tests/hub_plates.gd")`; there is
## no class_name on purpose, so nothing in the game can reach a test helper.

const COLUMN_PATH := "Safe/Content/Box"
## The hub had seven rows when this was written. The menu only ever grows, so a
## smaller count means the derivation broke rather than the menu shrinking, and
## every caller asserts it instead of quietly testing a subset.
const EXPECTED_MINIMUM := 7


## Every plate in column order, hidden rows included. `title` is an instanced
## scenes/ui/title_screen.tscn.
static func all(title: Node) -> Array[String]:
	var names: Array[String] = []
	for child: Node in title.get_node(COLUMN_PATH).get_children():
		if child is Button:
			names.append(String(child.name))
	return names


## The plates a player can reach right now: on screen and focusable.
static func interactive(title: Node) -> Array[String]:
	var names: Array[String] = []
	var column: Node = title.get_node(COLUMN_PATH)
	for name: String in all(title):
		var button: Button = column.get_node(name) as Button
		if button.visible and button.focus_mode != Control.FOCUS_NONE:
			names.append(name)
	return names


## Empty when the derived list is plausible, otherwise the reason it is not.
## Callers turn this into their own FAIL so a broken derivation can never read
## as a pass.
static func problem(title: Node) -> String:
	var names: Array[String] = all(title)
	if names.size() < EXPECTED_MINIMUM:
		return "found only %d hub plates under %s (%s), want at least %d" % [
			names.size(), COLUMN_PATH, ", ".join(names), EXPECTED_MINIMUM
		]
	return ""
