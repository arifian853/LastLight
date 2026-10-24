extends SceneTree
## Deterministic ten-minute bot run. No invulnerability, stat cheats, or time jumps.
## Godot --headless --fixed-fps 60 --path . --script tests/day5_endurance.gd

const GameScene = preload("res://scenes/main/game.tscn")
var _kills: int = 0
var _game


func _initialize() -> void:
	_run.call_deferred()


func _track_enemy(enemy: CharacterBody2D) -> void:
	enemy.enemy_died.connect(_on_death)


func _on_death(_point: Vector2, _value: int) -> void:
	_kills += 1


func _select_upgrade() -> void:
	var best: int = 0
	var best_score: float = -1.0
	for index in range(_game.upgrades.current_offers.size()):
		var id: StringName = _game.upgrades.current_offers[index].id
		var scores: Dictionary = {&"pale_flame": 6.0, &"quickening": 6.0, &"twin_flame": 8.0, &"searing_halo": 5.0, &"winter_crown": 5.0, &"deep_freeze": 4.0, &"frozen_horizon": 3.0, &"winter_stride": 2.0, &"steadfast": 2.0, &"moons_reach": 3.0}
		if _game.player.current_health < _game.player.max_health * 0.7:
			scores[&"steadfast"] = 10.0
		if int(_game.upgrades.ranks.get(&"moons_reach", 0)) < 2:
			scores[&"moons_reach"] = 7.0
		if float(scores[id]) > best_score:
			best_score = scores[id]
			best = index
	_game.upgrade_menu.cards[best].pressed.emit()


func _steer(seconds: float) -> void:
	var point: Vector2 = _game.player.global_position
	var destination := Vector2(cos(seconds * 0.12) * 900.0, sin(seconds * 0.12) * 600.0)
	var nearest_distance: float = 350.0 * 350.0
	for shard in _game.get_node("World/PickupContainer").get_children():
		var distance := point.distance_squared_to(shard.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			destination = shard.global_position
	var avoidance := Vector2.ZERO
	for enemy in _game.spawner.enemy_container.get_children():
		if enemy.is_dead:
			continue
		var offset: Vector2 = point - enemy.global_position
		var distance := offset.length()
		if distance < 170.0:
			avoidance += offset.normalized() * (170.0 - distance) / 100.0
	var direction := (point.direction_to(destination) + avoidance * 2.0).normalized()
	for entry in [["move_left", -direction.x], ["move_right", direction.x], ["move_up", -direction.y], ["move_down", direction.y]]:
		if entry[1] > 0.0:
			Input.action_press(entry[0], entry[1])
		else:
			Input.action_release(entry[0])


func _run() -> void:
	var run_seed: int = 7319
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			run_seed = int(argument.trim_prefix("--seed="))
	seed(run_seed)
	root.size = Vector2i(1280, 720)
	_game = GameScene.instantiate()
	root.add_child(_game)
	current_scene = _game
	_game.spawner._rng.seed = run_seed
	_game.spawner.enemy_spawned.connect(_track_enemy)
	var next_report: int = 120
	for frame in range(40000):
		await process_frame
		if _game.player.is_dead or _game.difficulty.elapsed_time >= 600.0:
			break
		if _game.state == _game.State.LEVEL_UP:
			if _game.upgrade_menu.visible:
				_select_upgrade()
			continue
		_steer(_game.difficulty.elapsed_time)
		if _game.difficulty.elapsed_time >= next_report:
			print("ENDURANCE CHECKPOINT ", JSON.stringify({"seconds": next_report, "level": _game.experience.level, "hp": _game.player.current_health, "kills": _kills, "enemies": _game.spawner.enemy_container.get_child_count()}))
			next_report += 120
	print("ENDURANCE RESULT ", JSON.stringify({"seconds": snappedf(_game.difficulty.elapsed_time, 0.1), "alive": not _game.player.is_dead, "level": _game.experience.level, "hp": _game.player.current_health, "kills": _kills, "ranks": _game.upgrades.ranks, "boss_spawned": _game.boss_spawned, "boss_defeated": _game.boss_defeated, "result": root.get_node("RunState").last_run_result}))
	call_group("game_audio", "stop_all")
	OS.delay_msec(100)
	quit()
