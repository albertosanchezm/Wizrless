extends LimboState

var _p: CharacterBody2D


func _setup() -> void:
	_p = agent as CharacterBody2D


func _enter() -> void:
	_p.velocity        = Vector2.ZERO
	_p.skip_gravity    = true
	_p.set_physics_process(false)
	_p.anim.play("death")
	_p.anim.animation_finished.connect(_on_death_finished, CONNECT_ONE_SHOT)


func _exit() -> void:
	_p.skip_gravity = false
	_p.set_physics_process(true)


func _on_death_finished() -> void:
	# Aquí puedes emitir una señal a la UI, recargar la sala, etc.
	# Por ahora esperamos un segundo y respawneamos desde GameManager.
	await _p.get_tree().create_timer(1.0).timeout
	_p.global_position = GameManager.respawn_position
	GameManager.reset_health()
	_p.set_physics_process(true)
	_p.skip_gravity = false
	dispatch(&"land")  # vuelve a idle
