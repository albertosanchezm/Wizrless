extends LimboState

var _d: Devium


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_d.velocity = Vector2.ZERO
	_d.set_physics_process(false)
	_d.hitbox.set_deferred(&"monitoring", false)
	# TODO: reproducir animación de muerte
	_die()


func _die() -> void:
	await _d.get_tree().create_timer(2.0).timeout
	_d.died.emit()
	_d.queue_free()
