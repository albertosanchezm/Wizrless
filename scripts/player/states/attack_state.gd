extends LimboState

signal attack_fired(position: Vector2, direction: Vector2)

var _p: CharacterBody2D
var _finished := false


func _setup() -> void:
	_p = agent as CharacterBody2D


func _enter() -> void:
	_finished = false
	_p.velocity.x = 0.0
	_p.anim.play("attack")
	# Disparar al inicio de la animación (frame 0)
	_fire()
	_p.anim.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)


func _exit() -> void:
	# Desconectar por si salimos antes de que termine (poco probable, pero seguro)
	if _p.anim.animation_finished.is_connected(_on_anim_finished):
		_p.anim.animation_finished.disconnect(_on_anim_finished)


func _update(_delta: float) -> void:
	# Inmovilizamos X durante el ataque
	_p.velocity.x = 0.0

	if _finished:
		if _p.is_on_floor():
			var dir := Input.get_axis("move_left", "move_right")
			dispatch(&"stop" if abs(dir) < 0.1 else &"move")
		else:
			dispatch(&"fall")


func _fire() -> void:
	var dir := Vector2(-1.0 if _p.anim.flip_h else 1.0, 0.0)
	attack_fired.emit(_p.global_position, dir)


func _on_anim_finished() -> void:
	_finished = true
