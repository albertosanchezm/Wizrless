extends LimboState

var _p: CharacterBody2D


func _setup() -> void:
	_p = agent as CharacterBody2D


func _enter() -> void:
	_p.anim.play("idle")
	_p.velocity.x = 0.0
	_p.reset_air_moves()


func _update(_delta: float) -> void:
	# Sin movimiento horizontal en idle
	_p.velocity.x = 0.0

	if not _p.is_on_floor():
		dispatch(&"fall")
		return

	if _p.jump_buffer > 0.0:
		dispatch(&"jump")
		return

	if _p.wants_dash():
		dispatch(&"dash")
		return

	var dir := Input.get_axis("move_left", "move_right")
	if abs(dir) > 0.1:
		dispatch(&"move")
