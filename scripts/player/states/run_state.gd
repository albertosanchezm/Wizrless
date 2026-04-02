extends LimboState

var _p: CharacterBody2D


func _setup() -> void:
	_p = agent as CharacterBody2D


func _enter() -> void:
	_p.anim.play("run")
	_p.reset_air_moves()
	_p.anim.frame_changed.connect(_on_frame_changed)


func _exit() -> void:
	if _p.anim.frame_changed.is_connected(_on_frame_changed):
		_p.anim.frame_changed.disconnect(_on_frame_changed)


func _on_frame_changed() -> void:
	if _p.anim.frame == 0 or _p.anim.frame == 3:
		_p.step_sfx.play()


func _update(_delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	_p.velocity.x = dir * _p.SPEED
	_p.flip_toward(dir)

	if not _p.is_on_floor():
		dispatch(&"fall")
		return

	if _p.jump_buffer > 0.0:
		dispatch(&"jump")
		return

	if _p.wants_dash():
		dispatch(&"dash")
		return

	if _p.wants_attack():
		dispatch(&"attack")
		return

	if abs(dir) < 0.1:
		dispatch(&"stop")
