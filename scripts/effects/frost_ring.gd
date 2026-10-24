extends Node2D

@export var radius: float = 150.0
@export var duration: float = 0.5
var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	var current_radius := lerpf(16.0, radius, progress)
	var color := Color(0.6, 0.88, 1.0, 1.0 - progress)
	draw_circle(Vector2.ZERO, current_radius, Color(0.45, 0.8, 1.0, (1.0 - progress) * 0.06))
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 96, color, 3.0, true)
	draw_arc(Vector2.ZERO, current_radius * 0.86, 0.0, TAU, 96, Color(color, color.a * 0.4), 1.0, true)
	for index in range(12):
		var axis := Vector2.RIGHT.rotated(float(index) * TAU / 12.0)
		draw_line(axis * current_radius * 0.88, axis * current_radius, color, 2.0, true)
