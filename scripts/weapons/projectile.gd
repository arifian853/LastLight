extends CharacterBody2D
## Short swept steps keep the first collision reliable even at high speed.

const EnemyScript = preload("res://scripts/enemies/enemy_base.gd")

@export var damage: float = 15.0
@export var speed: float = 500.0
@export var lifetime: float = 2.5

var direction: Vector2 = Vector2.RIGHT
var _age: float = 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	rotation = direction.angle()
	var motion := direction.normalized() * speed * delta
	# Long native motion queries can skip the first of several small bodies.
	# Twelve pixels is smaller than an enemy's diameter; normal shots use one step.
	var steps := maxi(1, ceili(motion.length() / 12.0))
	for step in range(steps):
		var collision := move_and_collide(motion / float(steps))
		if collision != null:
			var enemy := collision.get_collider() as EnemyScript
			if enemy != null:
				enemy.take_damage(damage)
			# One impact per shot, including impacts against the arena walls.
			queue_free()
			return


func _draw() -> void:
	draw_line(Vector2(-22.0, 0.0), Vector2.ZERO, Color(1.0, 0.8, 0.4, 0.25), 5.0, true)
	draw_line(Vector2(-12.0, 0.0), Vector2.ZERO, Color(1.0, 0.9, 0.65, 0.8), 2.0, true)
