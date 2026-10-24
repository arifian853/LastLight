extends Node2D
## A rotating light ring with periodic, per-enemy area damage.

const PlayerScript = preload("res://scripts/player/player.gd")
const EnemyScript = preload("res://scripts/enemies/enemy_base.gd")

@export var damage: float = 6.0
@export var radius: float = 60.0
@export var cooldown: float = 0.65
var enabled: bool = true
var _cooldown_left: float = 0.0
var _phase: float = 0.0
@onready var player: PlayerScript = get_parent().get_parent()


func _physics_process(delta: float) -> void:
	visible = enabled and not player.is_dead
	if not visible:
		return
	_phase += delta * 1.8
	queue_redraw()
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _cooldown_left <= 0.0:
		_cooldown_left = cooldown
		damage_tick()


func damage_tick() -> int:
	if not enabled or player.is_dead or get_tree().paused:
		return 0
	var hits: int = 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyScript
		if enemy != null and not enemy.is_dead and global_position.distance_squared_to(enemy.global_position) <= radius * radius:
			if enemy.take_damage(damage):
				hits += 1
	return hits


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.95, 0.78, 0.4, 0.025))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(0.92, 0.78, 0.46, 0.22), 1.0, true)
	for index in range(3):
		var angle := _phase + float(index) * TAU / 3.0
		draw_arc(Vector2.ZERO, radius, angle, angle + 0.65, 18, Color(1.0, 0.86, 0.52, 0.8), 2.0, true)
		draw_circle(Vector2.RIGHT.rotated(angle) * radius, 3.0, Color(1.0, 0.94, 0.7))
