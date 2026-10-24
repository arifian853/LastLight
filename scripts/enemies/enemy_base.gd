extends CharacterBody2D
## Shared chase, contact damage, health, and death; variants supply stats/art.

signal damaged(amount: float)
signal enemy_died(world_position: Vector2, experience: int)

const PlayerScript = preload("res://scripts/player/player.gd")
const HitEffect = preload("res://scenes/effects/hit_effect.tscn")
const DeathEffect = preload("res://scenes/effects/death_effect.tscn")

@export var display_name: String = "Wraith"
@export var max_health: float = 20.0
@export var movement_speed: float = 90.0
@export var contact_damage: float = 10.0
@export var experience_value: int = 1

var current_health: float
var target: PlayerScript
var is_dead: bool = false
var slow_multiplier: float = 1.0
var _slow_remaining: float = 0.0
var _hit_tween: Tween

@onready var sprite: Sprite2D = $Sprite2D
@onready var contact_area: Area2D = $ContactArea


func _ready() -> void:
	current_health = max_health
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as PlayerScript


func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(target) or target.is_dead or target.run_finished:
		velocity = Vector2.ZERO
		return
	_slow_remaining = maxf(0.0, _slow_remaining - delta)
	if _slow_remaining <= 0.0:
		slow_multiplier = 1.0
	sprite.self_modulate = Color(0.6, 0.85, 1.0) if slow_multiplier < 1.0 else Color.WHITE
	velocity = global_position.direction_to(target.global_position) * movement_speed * slow_multiplier
	move_and_slide()
	if not is_zero_approx(velocity.x):
		sprite.flip_h = velocity.x < 0.0
	# The larger attack area reaches the hurtbox before solid bodies overlap.
	# Checking ongoing overlaps also handles a player standing in the crowd.
	for area in contact_area.get_overlapping_areas():
		if area.get_parent() == target:
			target.take_damage(contact_damage)


func apply_slow(multiplier: float, duration: float) -> void:
	if is_dead or duration <= 0.0:
		return
	slow_multiplier = minf(slow_multiplier, clampf(multiplier, 0.1, 1.0))
	_slow_remaining = maxf(_slow_remaining, duration)


func take_damage(amount: float) -> bool:
	if is_dead or amount <= 0.0:
		return false
	current_health = maxf(0.0, current_health - amount)
	damaged.emit(amount)
	get_tree().call_group("game_audio", "play_sound", &"hit")
	_spawn_effect(HitEffect)
	if current_health <= 0.0:
		_die()
	else:
		if _hit_tween != null:
			_hit_tween.kill()
		sprite.modulate = Color(3.0, 3.0, 2.0)
		_hit_tween = create_tween()
		_hit_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	return true


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	remove_from_group("enemies")
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	contact_area.set_deferred("monitoring", false)
	_spawn_effect(DeathEffect)
	enemy_died.emit(global_position, experience_value)
	get_tree().call_group("game_audio", "play_sound", &"enemy_death")
	hide()
	queue_free()


func _spawn_effect(scene: PackedScene) -> void:
	var container := get_tree().get_first_node_in_group("effect_container") as Node2D
	if container != null:
		var effect := scene.instantiate() as Node2D
		effect.position = container.to_local(global_position + Vector2(0, -12))
		container.add_child(effect)


func _draw() -> void:
	draw_set_transform(Vector2(0.0, 3.0), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 18.0, Color(0.02, 0.04, 0.07, 0.45))
