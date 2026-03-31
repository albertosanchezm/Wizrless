extends LimboState
## Lanza una bola de hielo en línea recta hacia el player.

var _d: Devium
var _timer   := 0.0
var _fired   := false

const WINDUP   := 0.6   # segundos de preparación antes de disparar
const DURATION := 1.2   # duración total del estado


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_timer = 0.0
	_fired = false
	_d.velocity = Vector2.ZERO
	_d.face_player()
	# TODO: reproducir animación ataque bola de hielo


func _update(delta: float) -> void:
	_timer += delta

	if not _fired and _timer >= WINDUP:
		_fire()
		_fired = true

	if _timer >= DURATION:
		dispatch(&"end_attack")


func _fire() -> void:
	if not _d.player:
		return
	var dir := (_d.player.global_position - _d.global_position).normalized()
	# TODO: instanciar proyectil de bola de hielo
	# Ejemplo:
	# var proj = ICE_BALL_SCENE.instantiate()
	# proj.global_position = _d.global_position
	# proj.direction = dir
	# _d.get_parent().add_child(proj)
	pass
