extends Node
## UI motion (G12 feel pass): every button breathes under the cursor and squashes on press,
## logos drift, and menus slide in. Pure presentation: no gameplay state, tree-wide via
## node_added like the Sfx hook. Autoloaded as `Juice`.

const HOVER_SCALE := Vector2(1.04, 1.04)
const PRESS_SCALE := Vector2(0.96, 0.96)
const HOVER_TIME := 0.12
const PRESS_TIME := 0.08
const BREATHE_SCALE := Vector2(1.03, 1.03)
const BREATHE_TIME := 2.4
const SLIDE_PX := 40.0
const SLIDE_TIME := 0.35
const SLIDE_STAGGER := 0.06


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # menus animate while the tree is paused
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node)


func _hook_button(b: BaseButton) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func(): _scale(b, HOVER_SCALE, HOVER_TIME))
	b.mouse_exited.connect(func(): _scale(b, Vector2.ONE, HOVER_TIME))
	b.button_down.connect(func(): _scale(b, PRESS_SCALE, PRESS_TIME))
	b.button_up.connect(func(): _scale(b, HOVER_SCALE if b.is_hovered() else Vector2.ONE, PRESS_TIME))


func _scale(c: Control, target: Vector2, seconds: float) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	var t := c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", target, seconds)


## Slow scale breathing for a logo or emblem; runs until the node leaves the tree.
func breathe(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var t := c.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(c, "scale", BREATHE_SCALE, BREATHE_TIME)
	t.tween_property(c, "scale", Vector2.ONE, BREATHE_TIME)


## Menu entrance: the column itself slides in from the left (containers own their children's
## positions, so only the column's own position is animated) while its rows fade in staggered.
func slide_in(column: Control, rows: Array) -> void:
	var rest := column.position.x
	column.position.x = rest - SLIDE_PX
	var slide := column.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(column, "position:x", rest, SLIDE_TIME)
	var delay := 0.0
	for item in rows:
		if not (item is Control):
			continue
		var c: Control = item
		c.modulate.a = 0.0
		var t := c.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(c, "modulate:a", 1.0, SLIDE_TIME).set_delay(delay)
		delay += SLIDE_STAGGER


## Spawn pop for a sprite: from a small scale to `final` with overshoot.
func pop(sprite: Node2D, final: Vector2, seconds: float = 0.25) -> void:
	if not is_instance_valid(sprite) or not sprite.is_inside_tree():
		return
	sprite.scale = final * 0.4
	var t := sprite.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "scale", final, seconds)
