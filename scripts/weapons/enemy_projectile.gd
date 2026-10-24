extends CharacterBody2D

const PlayerScript = preload("res://scripts/player/player.gd")
@export var damage: float = 12.0
@export var speed: float = 160.0
@export var lifetime: float = 6.0
var direction := Vector2.RIGHT
var _age: float = 0.0
@onready var player: PlayerScript = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime or not is_instance_valid(player) or player.is_dead or player.run_finished:
		queue_free()
		return
	var motion := direction.normalized() * speed * delta
	var steps := maxi(1, ceili(motion.length() / 12.0))
	for index in range(steps):
		var collision := move_and_collide(motion / float(steps))
		if collision != null:
			var hit_player := collision.get_collider() as PlayerScript
			if hit_player != null:
				hit_player.take_damage(damage)
			queue_free()
			return


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color(0.66, 0.45, 1.0, 0.12))
	draw_circle(Vector2.ZERO, 6.0, Color(0.7, 0.58, 0.95))
	draw_circle(Vector2(-1, -1), 2.5, Color(0.94, 0.88, 1.0))
