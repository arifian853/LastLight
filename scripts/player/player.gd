extends CharacterBody2D
## Movement, contact damage protection, and the player's death state.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal player_died

@export var movement_speed: float = 240.0
@export var max_health: float = 100.0
@export var invulnerability_duration: float = 0.8
@export var pickup_radius: float = 96.0

var current_health: float = 100.0
var is_dead: bool = false
var run_finished: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var lantern: PointLight2D = $PointLight2D

var _elapsed: float = 0.0
var _walk_time: float = 0.0
var _invulnerability_left: float = 0.0
var _hit_tween: Tween


func _ready() -> void:
	current_health = max_health
	var pickup_shape := $PickupArea/CollisionShape2D.shape.duplicate() as CircleShape2D
	pickup_shape.radius = pickup_radius
	$PickupArea/CollisionShape2D.shape = pickup_shape
	$PickupArea.area_entered.connect(_on_pickup_entered)


func _on_pickup_entered(area: Area2D) -> void:
	if area.has_method("attract"):
		area.call("attract", self)


func set_pickup_radius(value: float) -> void:
	pickup_radius = value
	$PickupArea/CollisionShape2D.shape.set_deferred("radius", pickup_radius)


func _physics_process(delta: float) -> void:
	if is_dead or run_finished:
		return
	_invulnerability_left = maxf(0.0, _invulnerability_left - delta)
	sprite.visible = _invulnerability_left <= 0.0 or fmod(_invulnerability_left, 0.16) > 0.05
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * movement_speed
	move_and_slide()
	_elapsed += delta
	if not direction.is_zero_approx():
		_walk_time += delta * 12.0
	if not is_zero_approx(direction.x):
		sprite.flip_h = direction.x < 0.0
	var bob: float = sin(_walk_time) * 1.5 if not direction.is_zero_approx() else 0.0
	sprite.position.y = -24.0 + bob
	lantern.position = Vector2(-16.0 if sprite.flip_h else 16.0, -12.0 + bob)
	lantern.energy = 1.35 + sin(_elapsed * 4.2) * 0.06 + sin(_elapsed * 9.1) * 0.03


func take_damage(amount: float) -> bool:
	if is_dead or run_finished or get_tree().paused or amount <= 0.0 or _invulnerability_left > 0.0:
		return false
	current_health = maxf(0.0, current_health - amount)
	_invulnerability_left = invulnerability_duration
	health_changed.emit(current_health, max_health)
	damaged.emit(amount)
	if _hit_tween != null:
		_hit_tween.kill()
	sprite.modulate = Color(2.0, 0.65, 0.5)
	_hit_tween = create_tween()
	_hit_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	if current_health <= 0.0:
		_die()
	return true


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	sprite.visible = true
	_hit_tween.kill()
	var death_tween := create_tween().set_parallel(true)
	death_tween.tween_property(sprite, "modulate", Color(0.4, 0.47, 0.54), 0.6)
	death_tween.tween_property(sprite, "rotation", -0.4, 0.6)
	death_tween.tween_property(lantern, "energy", 0.12, 0.8)
	player_died.emit()


func _draw() -> void:
	draw_set_transform(Vector2(0.0, 3.0), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 19.0, Color(0.025, 0.05, 0.08, 0.5))
