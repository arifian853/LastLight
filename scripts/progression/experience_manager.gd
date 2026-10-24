extends Node
## Run-local XP; overflow survives each level threshold.

signal experience_changed(level: int, experience: int, required: int)
signal level_up(level: int)

@export var base_experience: int = 4
@export var growth: int = 2

var level: int = 1
var experience: int = 0
var enabled: bool = true


func required_experience() -> int:
	return maxi(1, base_experience + level * growth)


func add_experience(amount: int) -> void:
	if not enabled or amount <= 0:
		return
	experience += amount
	while experience >= required_experience():
		experience -= required_experience()
		level += 1
		level_up.emit(level)
	experience_changed.emit(level, experience, required_experience())
