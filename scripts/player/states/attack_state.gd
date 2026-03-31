extends LimboState

signal attack_fired(position: Vector2, direction: Vector2)

var _p: CharacterBody2D
var _fired := false


func _setup() -> void:
	_p = agent as CharacterBody2D


func _enter() -> void:
	_p.velocity.x = 0.0
	_p.anim.play("attack")
	_fired = false


func _update(_delta: float) -> void:
	_p.velocity.x = 0.0

	if _p.anim.is_playing():
		if not _fired and _p.anim.frame >= 4:
			_fire()
			_fired = true
		return

	if _p.is_on_floor():
		var dir := Input.get_axis("move_left", "move_right")
		dispatch(&"stop" if abs(dir) < 0.1 else &"move")
	else:
		dispatch(&"fall")


func _fire() -> void:
	var dir := Vector2(-1.0 if _p.anim.flip_h else 1.0, 0.0)
	attack_fired.emit(_p.global_position, dir)
