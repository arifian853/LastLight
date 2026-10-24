extends Area2D

signal collected(amount: int)

const PlayerScript = preload("res://scripts/player/player.gd")

@export var experience_value: int = 1
var target: PlayerScript
var _collected: bool = false
var _elapsed: float = 0.0
var _speed: float = 140.0


func attract(collector: PlayerScript) -> void:
	if not _collected and not collector.is_dead:
		target = collector


func _physics_process(delta: float) -> void:
	_elapsed += delta
	$Sprite2D.position.y = -6.0 + sin(_elapsed * 3.0) * 2.0
	if _collected or not is_instance_valid(target) or target.is_dead:
		return
	_speed = minf(600.0, _speed + 1000.0 * delta)
	global_position = global_position.move_toward(target.global_position, _speed * delta)
	if global_position.distance_squared_to(target.global_position) <= 256.0:
		_collected = true
		set_deferred("collision_layer", 0)
		collected.emit(experience_value)
		get_tree().call_group("game_audio", "play_sound", &"pickup")
		queue_free()
