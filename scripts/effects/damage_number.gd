extends Label
## Floating damage number (G12): rises 0.45s then frees itself. White for normal hits,
## gold for crits; the caller decides.

const RISE_PX := 40.0
const LIFETIME := 0.45


func show_value(value: float, crit: bool) -> void:
	text = ("%.1f" % value) + ("*" if crit else "")
	modulate = Color(1.0, 0.85, 0.3) if crit else Color.WHITE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE_PX, LIFETIME)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME).set_delay(LIFETIME * 0.4)
	tween.chain().tween_callback(queue_free)
