extends "res://scripts/enemies/enemy_base.gd"

signal health_changed(current: float, maximum: float)

const EnemyProjectile = preload("res://scenes/weapons/enemy_projectile.tscn")
@export var attack_interval: float = 4.0
@export var windup_duration: float = 0.8
@export var projectile_count: int = 12
var _attack_left: float = 3.2
var _warning_left: float = 0.0
var _volley: int = 0


func _physics_process(delta: float) -> void:
	super(delta)
	if is_dead or not is_instance_valid(target) or target.is_dead or target.run_finished:
		return
	if _warning_left > 0.0:
		_warning_left = maxf(0.0, _warning_left - delta)
		sprite.self_modulate = Color(1.3, 0.85, 1.35)
		if _warning_left <= 0.0:
			fire_radial()
			_attack_left = attack_interval
	else:
		_attack_left -= delta
		if _attack_left <= 0.0:
			_warning_left = windup_duration
	queue_redraw()


func fire_radial() -> int:
	if is_dead or not is_instance_valid(target) or target.is_dead or target.run_finished or get_tree().paused:
		return 0
	var container := get_tree().get_first_node_in_group("enemy_projectile_container") as Node2D
	if container == null:
		return 0
	for index in range(projectile_count):
		var bullet = EnemyProjectile.instantiate()
		bullet.direction = Vector2.RIGHT.rotated(float(index) * TAU / float(projectile_count) + float(_volley) * 0.12)
		bullet.position = container.to_local(global_position + bullet.direction * 44.0)
		container.add_child(bullet)
	_volley += 1
	get_tree().call_group("game_audio", "play_sound", &"boss_shot")
	return projectile_count


func take_damage(amount: float) -> bool:
	var accepted := super(amount)
	if accepted:
		health_changed.emit(current_health, max_health)
	return accepted


func _draw() -> void:
	super()
	draw_set_transform(Vector2.ZERO)
	if _warning_left > 0.0:
		var radius := 60.0 + sin(_warning_left * 24.0) * 5.0
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(0.85, 0.7, 1.0, 0.85), 3.0, true)
		for index in range(projectile_count):
			var direction := Vector2.RIGHT.rotated(float(index) * TAU / float(projectile_count) + float(_volley) * 0.12)
			draw_line(direction * 44.0, direction * radius, Color(0.8, 0.65, 1.0, 0.8), 2.0, true)
