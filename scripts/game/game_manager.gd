extends Node2D
## Coordinates death, XP, and one upgrade selection per earned level.

enum State { PLAYING, GAME_OVER, LEVEL_UP, PAUSED, VICTORY }

const PlayerScript = preload("res://scripts/player/player.gd")
const SpawnScript = preload("res://scripts/game/spawn_manager.gd")
const ExperienceScript = preload("res://scripts/progression/experience_manager.gd")
const UpgradeScript = preload("res://scripts/progression/upgrade_manager.gd")
const ShardScene = preload("res://scenes/pickups/light_shard.tscn")

var state: State = State.PLAYING
var pending_levels: Array[int] = []
@export var run_duration: float = 600.0
@export var boss_spawn_time: float = 480.0
var kills: int = 0
var boss_spawned: bool = false
var boss_defeated: bool = false
var boss: CharacterBody2D
var _shake_left: float = 0.0
var _changing_scene: bool = false

@onready var player: PlayerScript = $World/Environment/Player
@onready var spawner: SpawnScript = $SpawnManager
@onready var health_bar: ProgressBar = $HUD/Layout/HealthBar
@onready var health_label: Label = $HUD/Layout/HealthLabel
@onready var death_overlay: Control = $HUD/Layout/DeathOverlay
@onready var retry_button: Button = $HUD/Layout/DeathOverlay/Center/Content/Retry
@onready var experience: ExperienceScript = $ExperienceManager
@onready var upgrades: UpgradeScript = $UpgradeManager
@onready var upgrade_menu = $HUD/Layout/UpgradeMenu
@onready var difficulty = $DifficultyManager
@onready var pause_menu = $HUD/Layout/PauseMenu


func _ready() -> void:
	player.health_changed.connect(_update_health)
	player.player_died.connect(_on_player_died)
	player.damaged.connect(_on_player_damaged)
	retry_button.pressed.connect(_restart)
	$HUD/Layout/DeathOverlay/Center/Content/MainMenu.pressed.connect(_to_main_menu)
	pause_menu.pause_requested.connect(_toggle_pause)
	pause_menu.menu_requested.connect(_to_main_menu)
	_update_health(player.current_health, player.max_health)
	spawner.enemy_spawned.connect(_track_enemy)
	experience.experience_changed.connect(_update_experience)
	experience.level_up.connect(_on_level_up)
	upgrade_menu.upgrade_chosen.connect(_on_upgrade_chosen)
	_update_experience(experience.level, experience.experience, experience.required_experience())
	difficulty.difficulty_changed.connect(_update_difficulty)
	_update_difficulty(difficulty.stage_name, int(difficulty.elapsed_time))
	create_tween().tween_property($HUD/Layout/Fade, "color:a", 0.0, 0.4)


func _process(delta: float) -> void:
	_shake_left = maxf(0.0, _shake_left - delta)
	var shake := Vector2(sin(_shake_left * 90.0), cos(_shake_left * 110.0)) * _shake_left * 28.0
	player.get_node("Camera2D").offset = shake if _shake_left > 0.0 else Vector2.ZERO


func _on_player_damaged(_amount: float) -> void:
	_shake_left = 0.18
	$HUD/Layout/DamageFlash.color.a = 0.15
	create_tween().tween_property($HUD/Layout/DamageFlash, "color:a", 0.0, 0.25)
	get_tree().call_group("game_audio", "play_sound", &"player_damage")


func _toggle_pause() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
		get_tree().paused = true
		pause_menu.open()
	elif state == State.PAUSED:
		pause_menu.hide()
		state = State.PLAYING if pending_levels.is_empty() else State.LEVEL_UP
		get_tree().paused = state == State.LEVEL_UP
		if state == State.LEVEL_UP:
			_show_next_upgrade.call_deferred()
	else:
		return
	get_tree().call_group("game_audio", "play_sound", &"ui_select")


func _update_difficulty(stage: String, seconds: int) -> void:
	if state == State.GAME_OVER or state == State.VICTORY:
		return
	$HUD/Layout/SurvivalTimer.text = "%02d:%02d" % [floori(float(seconds) / 60.0), seconds % 60]
	$HUD/Layout/PressureLabel.text = stage
	if state != State.PLAYING:
		return
	if float(seconds) >= run_duration:
		_finish_run(true)
	elif float(seconds) >= boss_spawn_time and not boss_spawned:
		_spawn_boss()


func _spawn_boss() -> void:
	var spawned = spawner.spawn_boss()
	if spawned == null:
		return
	boss = spawned
	boss_spawned = true
	boss.health_changed.connect(_update_boss_health)
	boss.enemy_died.connect(_on_boss_died)
	$HUD/Layout/BossPanel.show()
	_update_boss_health(boss.current_health, boss.max_health)
	$HUD/Layout/BossNotice.show()
	get_tree().create_timer(3.0, false).timeout.connect($HUD/Layout/BossNotice.hide)
	get_tree().call_group("game_audio", "play_sound", &"boss_arrival")


func _update_boss_health(current: float, maximum: float) -> void:
	$HUD/Layout/BossPanel/Health.max_value = maximum
	$HUD/Layout/BossPanel/Health.value = current


func _on_boss_died(_point: Vector2, _value: int) -> void:
	boss_defeated = true
	$HUD/Layout/BossPanel.hide()
	for projectile in $World/EnemyProjectileContainer.get_children():
		projectile.queue_free()


func _track_enemy(enemy: CharacterBody2D) -> void:
	enemy.enemy_died.connect(_on_enemy_died)


func _on_enemy_died(point: Vector2, value: int) -> void:
	if state == State.GAME_OVER or state == State.VICTORY:
		return
	kills += 1
	$HUD/Layout/KillCount.text = "SHADOWS BANISHED  %d" % kills
	_drop_shard.call_deferred(point, value)


func _drop_shard(point: Vector2, value: int) -> void:
	if state == State.GAME_OVER or state == State.VICTORY or value <= 0:
		return
	var container: Node2D = $World/PickupContainer
	var shard = ShardScene.instantiate()
	shard.experience_value = value
	shard.position = container.to_local(point)
	shard.collected.connect(experience.add_experience)
	container.add_child(shard)


func _update_experience(level: int, amount: int, required: int) -> void:
	$HUD/Layout/ExperienceBar.max_value = required
	$HUD/Layout/ExperienceBar.value = amount
	$HUD/Layout/ExperienceLabel.text = "LEVEL %d    LIGHT SHARDS  %d / %d" % [level, amount, required]


func _on_level_up(new_level: int) -> void:
	if state == State.GAME_OVER or state == State.VICTORY:
		return
	pending_levels.append(new_level)
	get_tree().call_group("game_audio", "play_sound", &"level_up")
	if state == State.PLAYING:
		state = State.LEVEL_UP
		get_tree().paused = true
		_show_next_upgrade.call_deferred()


func _show_next_upgrade() -> void:
	if state == State.LEVEL_UP and not pending_levels.is_empty():
		upgrade_menu.show_choices(upgrades.roll_choices(), upgrades.ranks, pending_levels[0])


func _on_upgrade_chosen(id: StringName) -> void:
	if state != State.LEVEL_UP or not upgrades.choose_upgrade(id):
		return
	get_tree().call_group("game_audio", "play_sound", &"ui_select")
	pending_levels.pop_front()
	upgrade_menu.hide()
	if pending_levels.is_empty():
		state = State.PLAYING
		get_tree().paused = false
	else:
		_show_next_upgrade.call_deferred()


func _exit_tree() -> void:
	if state == State.LEVEL_UP or state == State.PAUSED:
		get_tree().paused = false


func _update_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "LANTERN KEEPER   %d / %d" % [ceili(current), ceili(maximum)]


func _on_player_died() -> void:
	_finish_run(false)


func _finish_run(victory: bool) -> void:
	if state == State.GAME_OVER or state == State.VICTORY:
		return
	state = State.VICTORY if victory else State.GAME_OVER
	player.run_finished = true
	player.velocity = Vector2.ZERO
	_shake_left = 0.0
	difficulty.set_physics_process(false)
	experience.enabled = false
	pending_levels.clear()
	upgrade_menu.hide()
	pause_menu.hide()
	get_tree().paused = false
	spawner.enabled = false
	for container in [$World/ProjectileContainer, $World/EnemyProjectileContainer]:
		for projectile in container.get_children():
			projectile.queue_free()
	for enemy in spawner.enemy_container.get_children():
		enemy.velocity = Vector2.ZERO
		enemy.set_physics_process(false)
	for weapon in player.get_node("WeaponPivot").get_children():
		weapon.enabled = false
		weapon.hide()
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		run_state.last_run_time = difficulty.elapsed_time
		run_state.last_run_kills = kills
		run_state.last_run_level = experience.level
		run_state.last_run_result = "victory" if victory else "death"
		run_state.boss_defeated = boss_defeated
	death_overlay.show_result(victory, difficulty.elapsed_time, kills, experience.level)
	get_tree().call_group("game_audio", "play_sound", &"victory" if victory else &"death")
	if victory:
		create_tween().tween_property($World/CanvasModulate, "color", Color(0.95, 0.87, 0.72), 1.2)
		player.lantern.energy = 2.0


func _restart() -> void:
	if state == State.GAME_OVER or state == State.VICTORY:
		get_tree().paused = false
		get_tree().reload_current_scene()


func _to_main_menu() -> void:
	if _changing_scene:
		return
	_changing_scene = true
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/main/main_menu.tscn")
