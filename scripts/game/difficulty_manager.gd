extends Node
## Survival time advances only during gameplay. Scaling affects new spawns.

signal difficulty_changed(stage: String, seconds: int)

const PlayerScript = preload("res://scripts/player/player.gd")
const SpawnScript = preload("res://scripts/game/spawn_manager.gd")

var elapsed_time: float = 0.0
var stage_name: String = "FIRST SHADOWS"
var _last_second: int = -1
@onready var player: PlayerScript = $"../World/Environment/Player"
@onready var spawner: SpawnScript = $"../SpawnManager"


func _ready() -> void:
	set_elapsed_time(0.0)


func _physics_process(delta: float) -> void:
	if player.is_dead or player.run_finished:
		return
	elapsed_time += delta
	if int(elapsed_time) != _last_second:
		_apply_difficulty()


func set_elapsed_time(seconds: float) -> void:
	elapsed_time = maxf(0.0, seconds)
	_apply_difficulty()


func _apply_difficulty() -> void:
	_last_second = int(elapsed_time)
	var progress := clampf(elapsed_time / 600.0, 0.0, 1.0)
	spawner.spawn_interval = lerpf(1.8, 0.32, progress)
	spawner.max_enemies = roundi(lerpf(36.0, 150.0, progress))
	spawner.health_multiplier = 1.0 + progress * 1.4
	spawner.speed_multiplier = 1.0 + progress * 0.25
	spawner.damage_multiplier = 1.0 + progress * 0.5
	if elapsed_time < 120.0:
		stage_name = "FIRST SHADOWS"
		spawner.enemy_weights = Vector3(1, 0, 0)
	elif elapsed_time < 240.0:
		stage_name = "RESTLESS DARK"
		spawner.enemy_weights = Vector3(0.7, 0.3, 0)
	elif elapsed_time < 360.0:
		stage_name = "WATCHFUL NIGHT"
		spawner.enemy_weights = Vector3(0.5, 0.3, 0.2)
	elif elapsed_time < 480.0:
		stage_name = "DEEP WINTER"
		spawner.enemy_weights = Vector3(0.4, 0.35, 0.25)
	else:
		stage_name = "LAST LIGHT"
		spawner.enemy_weights = Vector3(0.35, 0.4, 0.25)
	difficulty_changed.emit(stage_name, _last_second)
