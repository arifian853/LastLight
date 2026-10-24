extends Node
## Only the last result and audio preference survive scene changes.

var last_run_time: float = 0.0
var last_run_kills: int = 0
var last_run_level: int = 1
var last_run_result: String = ""
var boss_defeated: bool = false
var master_volume: float = 0.65
