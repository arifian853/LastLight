extends SceneTree
## Run with the editor's --main-pack <LastLight.exe>, from an empty directory.

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)


func _run() -> void:
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "Distribution uses Compatibility rendering")
	_check(ProjectSettings.get_setting("application/config/version") == "0.1.2", "Release version is embedded")
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main/main_menu.tscn", "Release boots the main menu")
	_check(not ProjectSettings.has_setting("autoload/_mcp_game_helper") and root.get_node_or_null("_mcp_game_helper") == null, "MCP autoload is absent")
	for directory in ["addons", "tests", "tools", "build", "dist"]:
		_check(not DirAccess.dir_exists_absolute("res://" + directory), "Development directory absent: " + directory)
	_check(FileAccess.file_exists("res://licenses/GODOT_LICENSE.txt") and FileAccess.get_file_as_string("res://licenses/GODOT_LICENSE.txt").contains("Permission is hereby granted"), "Engine license is embedded")
	_check(FileAccess.file_exists("res://licenses/GODOT_COPYRIGHT.txt") and FileAccess.get_file_as_string("res://licenses/GODOT_COPYRIGHT.txt").length() > 10000, "Third-party notices are embedded")
	_check(ResourceLoader.exists("res://assets/sprites/app_icon.svg"), "Lantern icon is packaged")
	var upgrades = load("res://scripts/progression/upgrade_manager.gd")
	_check(upgrades.CATALOG.size() == 10, "All ten upgrade resources are packaged")
	for scene in ["res://scenes/main/main_menu.tscn", "res://scenes/main/game.tscn", "res://scenes/main/result_screen.tscn", "res://scenes/enemies/pale_one.tscn", "res://scenes/weapons/light_orb.tscn", "res://scenes/weapons/halo.tscn", "res://scenes/weapons/frost_pulse.tscn"]:
		_check(load(scene) is PackedScene, "Exported scene loads: " + scene)
	print("RELEASE PACKAGE: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
