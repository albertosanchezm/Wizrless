extends LimboState

var _p: CharacterBody2D


func _setup() -> void:
	_p = agent as CharacterBody2D


func _enter() -> void:
	_p.velocity     = Vector2.ZERO
	_p.skip_gravity = true
	_p.set_physics_process(false)
	_p.anim.play("death")
	_p.anim.animation_finished.connect(_on_death_finished, CONNECT_ONE_SHOT)


func _exit() -> void:
	_p.skip_gravity = false
	_p.set_physics_process(true)


func _on_death_finished() -> void:
	await _p.get_tree().create_timer(1.0).timeout

	if not GameManager.respawn_scene.is_empty():
		# Cargar el room de respawn (hace fade + reposiciona al player)
		await SceneManager.change_room(GameManager.respawn_scene)
	else:
		# Fallback: solo reposicionar en el room actual
		_p.global_position = GameManager.respawn_position
		_p.velocity        = Vector2.ZERO

	GameManager.reset_health()
	dispatch(&"land")
