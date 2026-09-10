extends Control

## A hub screen that exists so the menu entry works, with nothing behind it yet.
##
## Doc v0.4 sections 29 and 27: 단어 도감 and 기록 are real screens, but their
## contents are Phase 4 and Phase 5 work. Giving them an honest placeholder now
## is the only way the hub menu can be finished without faking data, and the
## panel reports which phase fills it in rather than looking broken.
##
## Title and body are Inspector fields so a second placeholder needs no script.

signal closed()

## Heading shown at the top of the panel.
@export var title_text: String = "준비 중"
## What the screen will hold, and which phase adds it.
@export_multiline var body_text: String = ""

@onready var _title_label: Label = %PlaceholderTitleLabel
@onready var _body_label: Label = %PlaceholderBodyLabel
@onready var _close_button: Button = %PlaceholderCloseButton


func _ready() -> void:
	hide()
	_close_button.pressed.connect(_on_close_pressed)
	_title_label.text = title_text
	_body_label.text = body_text


func open() -> void:
	# Re-read the exported text so an Inspector change is visible without a
	# restart while the screen is still being authored.
	_title_label.text = title_text
	_body_label.text = body_text
	show()
	_close_button.grab_focus()


func _on_close_pressed() -> void:
	hide()
	closed.emit()
