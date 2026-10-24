extends Node
## Spawn outside the actual camera view, including near the arena's edges.

signal enemy_spawned(enemy: CharacterBody2D)

const PlayerScript = preload("res://scripts/player/player.gd")
const EnemyScript = preload("res://scripts/enemies/enemy_base.gd")
const ArenaScript = preload("res://scripts/world/winter_arena.gd")
const BossScene = preload("res://scenes/enemies/pale_one.tscn")
const ENEMY_SCENES: Array[PackedScene] = [
	preload("res://scenes/enemies/wraith.tscn"),
	preload("res://scenes/enemies/crawler.tscn"),
	preload("res://scenes/enemies/watcher.tscn"),
]

@export var spawn_interval: float = 2.4
@export var max_enemies: int = 45
@export var enemy_weights: Vector3 = Vector3(1, 0, 0)
var health_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var damage_multiplier: float = 1.0
@export var spawn_margin: float = 100.0
@export var player_path: NodePath = ^"../World/Environment/Player"
@export var enemy_container_path: NodePath = ^"../World/Environment/EnemyContainer"

var enabled: bool = true
var _elapsed: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var player: PlayerScript = get_node(player_path)
@onready var enemy_container: Node2D = get_node(enemy_container_path)


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(player) or player.is_dead:
		return
	_elapsed += delta
	if _elapsed >= spawn_interval:
		_elapsed = 0.0
		spawn_enemy()


func visible_world_rect() -> Rect2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()


func spawn_enemy(variant_index: int = -1) -> EnemyScript:
	if not enabled or not is_instance_valid(player) or player.is_dead:
		return null
	if enemy_container.get_child_count() >= max_enemies:
		return null
	var chosen: int = _choose_variant() if variant_index < 0 else variant_index
	if chosen < 0 or chosen >= ENEMY_SCENES.size():
		return null
	return _spawn_scene(ENEMY_SCENES[chosen], false)


func spawn_boss() -> EnemyScript:
	# The boss gets a reserved slot even when ordinary spawns reach their cap.
	return _spawn_scene(BossScene, true)


func _spawn_scene(scene: PackedScene, is_boss: bool) -> EnemyScript:
	if not enabled or not is_instance_valid(player) or player.is_dead or player.run_finished:
		return null
	var margin: float = spawn_margin + 180.0 if is_boss else spawn_margin
	var clearance: float = 80.0 if is_boss else 28.0
	var visible := visible_world_rect().grow(margin)
	var inset := Vector2.ONE * clearance
	var arena := Rect2(-ArenaScript.ARENA_HALF_SIZE + inset, ArenaScript.ARENA_HALF_SIZE * 2.0 - inset * 2.0)
	for attempt in range(48):
		# First try the camera perimeter; fall back to the arena perimeter.
		# Reject invalid candidates rather than clamping them into the screen.
		var perimeter: Rect2 = visible.grow(1.0) if attempt < 32 else arena
		var point := _point_on_perimeter(perimeter)
		if not arena.has_point(point) or visible.has_point(point):
			continue
		var enemy: EnemyScript = scene.instantiate()
		enemy.target = player
		if not is_boss:
			enemy.max_health *= health_multiplier
			enemy.movement_speed *= speed_multiplier
			enemy.contact_damage *= damage_multiplier
		enemy.position = enemy_container.to_local(point)
		enemy_container.add_child(enemy)
		enemy_spawned.emit(enemy)
		return enemy
	# If a huge viewport covers the arena, skip instead of spawning on-screen.
	return null


func _choose_variant() -> int:
	var total := enemy_weights.x + enemy_weights.y + enemy_weights.z
	if total <= 0.0:
		return 0
	var roll := _rng.randf() * total
	for index in range(3):
		roll -= enemy_weights[index]
		if roll < 0.0:
			return index
	return 2


func _point_on_perimeter(rect: Rect2) -> Vector2:
	var point := rect.position + Vector2(_rng.randf() * rect.size.x, _rng.randf() * rect.size.y)
	match _rng.randi_range(0, 3):
		0: point.x = rect.position.x
		1: point.x = rect.end.x - 0.01
		2: point.y = rect.position.y
		3: point.y = rect.end.y - 0.01
	return point
