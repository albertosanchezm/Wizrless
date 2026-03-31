extends LimboState

var _p: CharacterBody2D


func _setup() -> void:
	_p = agent as CharacterBody2D


func _enter() -> void:
	_p.anim.play("fall")


func _update(_delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	_p.velocity.x = dir * _p.SPEED
	_p.flip_toward(dir)

	# Aterrizado
	if _p.is_on_floor():
		dispatch(&"land")
		return

	# Salto con coyote time o doble salto
	if _p.jump_buffer > 0.0:
		if _p.can_jump():
			# Coyote jump
			dispatch(&"jump")
			return
		if _p.jumps_left > 0 and GameManager.has_ability("double_jump"):
			_p.jumps_left -= 1
			dispatch(&"jump")
			return

	# Doble salto con pulsación directa (sin buffer)
	if Input.is_action_just_pressed("jump") \
			and _p.jumps_left > 0 \
			and GameManager.has_ability("double_jump"):
		_p.jumps_left -= 1
		_p.jump_buffer = 0.0
		dispatch(&"jump")
		return

	if _p.wants_dash():
		dispatch(&"dash")
		return

	if Input.is_action_just_pressed("attack"):
		dispatch(&"attack")
		return
