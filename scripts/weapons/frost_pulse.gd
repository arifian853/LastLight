extends Node2D

const PlayerScript = preload("res://scripts/player/player.gd")
const EnemyScript = preload("res://scripts/enemies/enemy_base.gd")
const RingScene = preload("res://scenes/effects/frost_ring.tscn")

@export var damage: float = 12.0
@export var radius: float = 150.0
@export var cooldown: float = 4.0
@export var slow_multiplier: float = 0.5
@export var slow_duration: float = 1.5
var enabled: bool = true
var _cooldown_left: float = 4.0
@onready var player: PlayerScript = get_parent().get_parent()


func _ready() -> void:
	_cooldown_left = cooldown


func _physics_process(delta: float) -> void:
	if not enabled or player.is_dead:
		return
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _cooldown_left <= 0.0:
		_cooldown_left = cooldown
		trigger()


func trigger() -> int:
	if not enabled or player.is_dead or get_tree().paused:
		return 0
	get_tree().call_group("game_audio", "play_sound", &"pulse")
	var container := get_tree().get_first_node_in_group("effect_container") as Node2D
	if container != null:
		var ring = RingScene.instantiate()
		ring.radius = radius
		ring.position = container.to_local(global_position)
		container.add_child(ring)
	var hits: int = 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyScript
		if enemy != null and not enemy.is_dead and global_position.distance_squared_to(enemy.global_position) <= radius * radius:
			if enemy.take_damage(damage):
				hits += 1
				if not enemy.is_dead:
					enemy.apply_slow(slow_multiplier, slow_duration)
	return hits
