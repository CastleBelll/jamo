extends Node

## QA negative control for tests/hub_plates.gd.
##
## The P0 MEDIUM was a hardcoded four-name plate list, and the fix replaced it
## with a scene-derived one. A derived list that happens to return the right
## seven names today proves nothing on its own - a hardcoded list would too. So
## this harness changes the hub at runtime and checks the answer changes with
## it: add a row and it has to appear, hide a row and it has to leave the
## interactive set, take rows away and the guard has to fire.
##
## Runs windowed or headless - it never waits on a drawn frame and never writes
## to user://:
##   godot --headless --path . res://tests/qa2_hub_plates_derivation.tscn

const HubPlates := preload("res://tests/hub_plates.gd")
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const COLUMN_PATH := "Safe/Content/Box"
## A name no harness could have been written against.
const INJECTED_PLATE := "QaFuturePhaseButton"

var _failures: int = 0


func _ready() -> void:
	var title: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(title)
	await get_tree().process_frame

	var authored: Array[String] = HubPlates.all(title)
	print("authored plates: %s" % ", ".join(authored))
	_check(authored.size() >= HubPlates.EXPECTED_MINIMUM,
		"the hub draws at least %d plates, got %d" % [HubPlates.EXPECTED_MINIMUM, authored.size()])
	_check(HubPlates.problem(title).is_empty(),
		"the authored hub is not reported as a problem: %s" % HubPlates.problem(title))

	# 1. A row a later phase might add has to show up without touching a harness.
	var column: VBoxContainer = title.get_node(COLUMN_PATH)
	var extra := Button.new()
	extra.name = INJECTED_PLATE
	extra.text = "미래 Phase"
	column.add_child(extra)
	await get_tree().process_frame
	var grown: Array[String] = HubPlates.all(title)
	print("after adding one row: %s" % ", ".join(grown))
	_check(grown.has(INJECTED_PLATE),
		"a plate added to the column is derived, so the list is not hardcoded")
	_check(grown.size() == authored.size() + 1,
		"exactly one plate was added, got %d -> %d" % [authored.size(), grown.size()])
	_check(grown[grown.size() - 1] == INJECTED_PLATE,
		"the derived list keeps column order, last is %s" % grown[grown.size() - 1])
	_check(HubPlates.interactive(title).has(INJECTED_PLATE),
		"a visible focusable new plate counts as interactive")

	# 2. A hidden or unfocusable row is drawn-but-not-reachable, and interactive()
	#    has to say so while all() still lists it.
	extra.visible = false
	await get_tree().process_frame
	_check(HubPlates.all(title).has(INJECTED_PLATE),
		"a hidden plate is still part of the column")
	_check(not HubPlates.interactive(title).has(INJECTED_PLATE),
		"a hidden plate is not interactive")
	extra.visible = true
	extra.focus_mode = Control.FOCUS_NONE
	await get_tree().process_frame
	_check(not HubPlates.interactive(title).has(INJECTED_PLATE),
		"an unfocusable plate is not interactive")
	column.remove_child(extra)
	extra.queue_free()
	await get_tree().process_frame

	# 3. The guard: if the derivation ever breaks and returns a subset, callers
	#    have to be told rather than quietly testing fewer plates.
	var parked: Array[Node] = []
	while HubPlates.all(title).size() >= HubPlates.EXPECTED_MINIMUM:
		var last: Node = null
		for child: Node in column.get_children():
			if child is Button:
				last = child
		if last == null:
			break
		column.remove_child(last)
		parked.append(last)
	await get_tree().process_frame
	var problem: String = HubPlates.problem(title)
	print("with %d plate(s) removed: %s" % [parked.size(), problem])
	_check(not problem.is_empty(),
		"a short plate list is reported as a problem instead of passing quietly")
	for node: Node in parked:
		column.add_child(node)
	await get_tree().process_frame
	_check(HubPlates.all(title) == authored,
		"the hub is back to the plates it was authored with")

	title.queue_free()
	await get_tree().process_frame
	if _failures == 0:
		print("OK - the plate list follows the scene, and a short list fails loudly.")
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _check(passed: bool, message: String) -> void:
	if passed:
		return
	_failures += 1
	printerr("  FAIL: %s" % message)
