extends CPUParticles2D
## Burst scenes own their cleanup, including when their source has died.


func _ready() -> void:
	finished.connect(queue_free)
	emitting = true
