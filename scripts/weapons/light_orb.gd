extends Node2D
## Queries targets only when firing; shots travel in a fixed direction.

signal shot_fired(target: Node2D)

const PlayerScript = preload("res://scripts/player/player.gd")
const EnemyScript = preload("res://scripts/enemies/enemy_base.gd")
const ProjectileScene = preload("res://scenes/weapons/light_projectile.tscn")

@export var damage: float = 15.0
@export var cooldown: float = 0.8
@export var projectile_speed: float = 500.0
@export var targeting_range: float = 650.0
@export var projectile_count: int = 1

var enabled: bool = true
var _cooldown_left: float = 0.0

@onready var player: PlayerScript = get_parent().get_parent()
@onready var projectile_container: Node2D = get_tree().get_first_node_in_group("projectile_container")


func _physics_process(delta: float) -> void:
	if not enabled or player.is_dead:
		return
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _cooldown_left <= 0.0:
		_cooldown_left = cooldown
		fire()


func find_target() -> EnemyScript:
	var nearest: EnemyScript = null
	var nearest_distance_squared: float = targeting_range * targeting_range
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as EnemyScript
		if enemy == null or enemy.is_dead or enemy.is_queued_for_deletion():
			continue
		var distance_squared := player.global_position.distance_squared_to(enemy.global_position)
		if distance_squared <= nearest_distance_squared:
			nearest = enemy
			nearest_distance_squared = distance_squared
	return nearest


func fire() -> bool:
	if not enabled or player.is_dead or get_tree().paused or not is_instance_valid(projectile_container):
		return false
	var target := find_target()
	if target == null:
		return false
	var direction := global_position.direction_to(target.global_position)
	var perpendicular := Vector2(-direction.y, direction.x)
	for index in range(projectile_count):
		var lane := ceilf(float(index) / 2.0) * (1.0 if index % 2 == 0 else -1.0)
		var projectile = ProjectileScene.instantiate()
		projectile.direction = direction
		projectile.damage = damage
		projectile.speed = projectile_speed
		projectile.position = projectile_container.to_local(global_position + perpendicular * lane * 6.0)
		projectile_container.add_child(projectile)
	shot_fired.emit(target)
	get_tree().call_group("game_audio", "play_sound", &"projectile")
	return true
